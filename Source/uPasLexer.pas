(*******************************************************************************
*  Copyright © 2025 Pervov Evgeny                                              *
*                                                                              *
*  Licensed under the Apache License, Version 2.0 (the "License");             *
*  you may not use this file except in compliance with the License.            *
*  You may obtain a copy of the License at                                     *
*                                                                              *
*      http://www.apache.org/licenses/LICENSE-2.0                              *
*                                                                              *
*  Unless required by applicable law or agreed to in writing, software         *
*  distributed under the License is distributed on an "AS IS" BASIS,           *
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.    *
*  See the License for the specific language governing permissions and         *
*  limitations under the License.                                              *
*                                                                              *
*  Inspired by tokenizer TmwPasLex by Martin Waldenburg,                       *
*  Copyright © 1998, 1999 Martin Waldenburg                                    *
*  All rights reserved.                                                        *
*                                                                              *
*  Author: Pervov Evgeny                                                       *
*  Created: 16.03.2025                                                         *
*  Class: TPasLexer                                                            *
*  Description: Very fast pascal tokenizer/lexer                               *
*  Version: 0.2                                                                *
*  Last modified: 10.05.2025                                                   *
*  Contributor(s):                                                             *
*    Pervov Evgeny <operationm@list.ru>                                        *
*******************************************************************************)

unit uPasLexer;

interface

uses
  System.SysUtils, System.Character,
  uPasLexerTypes;

type
  TRunProcedure = procedure of object;
  TPostIdentifierProcedure = procedure(var AToken: TTokenKind) of object;

  // We need packed, because CopyFrom uses pointer offsets for record fields
  TPasLexerState = packed record
    CurrentIndex: Cardinal;
    MaxIndex: Cardinal;
    CurrentLine: Cardinal;
    CurrentLineStartPos: Cardinal;
    CurrentTokenPos: Cardinal;
    LastSignificantTokenPos: Cardinal;
    Counters: TPasLexerStateCounters;
    CurrentToken: TTokenKind;
    LastSignificantToken: TTokenKind;
    CommentState: TCommentState;
    IsProperty: Boolean;
    IsCompilerDirective: Boolean;
    IgnoreCompilerDirectiveChecks: Boolean;
    IfDirectiveStateArray: TArray<TIfDirectiveState>;
    IfDirectiveSavedCountersArray: TArray<TPasLexerSavedCounters>;

    procedure Reset;
    procedure CopyFrom(const ASource: TPasLexerState); {$IFDEF RELEASE} inline;{$ENDIF}
  end;

  TPasLexer = class(TObject)
  private
    class var FPrefixTreeRoot: PPrefixTreeNode;
    class var FCharHashTable: array[#0..#127] of Integer;  // Integer for align
  private
    FStartPtr: PChar;
    FEndPtr: PChar;
    FLexerState: TPasLexerState;
    FRunHandlers: array[#0..#127] of TRunProcedure;
    FPostIdentifierHandlers: array[TTokenKind] of TPostIdentifierProcedure;

    // RunHandlers
    procedure CommentHandler;
    procedure NullHandler;
    procedure LFHandler;
    procedure CRHandler;
    procedure SpaceHandler;
    procedure AsciiCharHandler;
    procedure HexNumberHandler;
    procedure StringHandler;
    procedure NumberHandler;
    procedure IdentifierHandler;
    procedure CurlyOpenHandler;
    procedure RoundOpenHandler;
    procedure RoundCloseHandler;
    procedure StarHandler;
    procedure SlashHandler;
    procedure PlusHandler;
    procedure MinusHandler;
    procedure CommaHandler;
    procedure PointHandler;
    procedure ColonHandler;
    procedure SemiColonHandler;
    procedure LowerHandler;
    procedure EqualHandler;
    procedure GreaterHandler;
    procedure AddressSymbolHandler;
    procedure SquareOpenHandler;
    procedure SquareCloseHandler;
    procedure PointerSymbolHandler;
    procedure SymbolHandler;
    procedure UnknownHandler;
    // PostIdentifierHandlers
    procedure PropertyPostHandler(var AToken: TTokenKind);
    procedure PropertyDirectivePostHandler(var AToken: TTokenKind);
    procedure EndPostHandler(var AToken: TTokenKind);
    procedure BlankPostHandler(var AToken: TTokenKind);

    function GetIdentifierKindWithTree: TTokenKind;
    procedure SkipToIdentifierEnd(var ACurrentPtr: PChar);

    //function TestNextTokenSequence(const AExpectedTokens: array of TTokenKind): Boolean;

    procedure RaiseCompilerDirectiveException(const AMessage: string);

    procedure FillRunProcTable;
    procedure FillPostIdentifierTable;
    class procedure InitCharHashTable;
    class procedure InitPrefixTree;
    class procedure FreePrefixTree(const ANode: PPrefixTreeNode);

    procedure SetLexerState(ANewState: TPasLexerState);
    function GetCurrentToken: string;
  public
    // +++ попробовать найти причину спайка в скорости парсинга при первом запуске теста скорости для нового лексера
    class constructor ClassCreate;
    class destructor ClassDestroy;

    constructor Create;

    procedure SetData(var ADataString: string);
    procedure Reset;
    function NextToken: Boolean;
    function NextTokenNoJunk: Boolean;
    function NextTokenNoDirectiveBranching: Boolean;
    function NextTokenWithKind(ATokenKind: TTokenKind): Boolean;

    property LexerState: TPasLexerState read FLexerState write SetLexerState;
    property TokenID: TTokenKind read FLexerState.CurrentToken;
    property TokenString: string read GetCurrentToken;
  end;

implementation

uses
  uPasExceptions;

{ TPasLexerState }

procedure TPasLexerState.Reset;
begin
  // First clear arrays to not leak memory
  SetLength(IfDirectiveStateArray, 0);
  SetLength(IfDirectiveSavedCountersArray, 0);
  FillChar(Self, SizeOf(TPasLexerState), 0);

  CurrentLine := 1;
  CommentState := csNo;
  CurrentToken := tkUnknown;
  LastSignificantToken := tkUnknown;
end;

procedure TPasLexerState.CopyFrom(const ASource: TPasLexerState);
var
  LenDirectiveState, LenSavedState: Integer;
begin
  Move(ASource, Self, NativeInt(@ASource.IfDirectiveStateArray) - NativeInt(@ASource));

  LenDirectiveState := Length(ASource.IfDirectiveStateArray);
  SetLength(Self.IfDirectiveStateArray, LenDirectiveState);
  if LenDirectiveState > 0 then
    Move(ASource.IfDirectiveStateArray[0], Self.IfDirectiveStateArray[0], SizeOf(TIfDirectiveState) * LenDirectiveState);

  LenSavedState := Length(ASource.IfDirectiveSavedCountersArray);
  SetLength(Self.IfDirectiveSavedCountersArray, LenSavedState);
  if LenSavedState > 0 then
    Move(ASource.IfDirectiveSavedCountersArray[0], Self.IfDirectiveSavedCountersArray[0], SizeOf(TPasLexerSavedCounters) * LenSavedState);
end;

{ TPasLexer }

class constructor TPasLexer.ClassCreate;
begin
  TPasLexer.InitCharHashTable;
  TPasLexer.InitPrefixTree;
end;

class destructor TPasLexer.ClassDestroy;
begin
  TPasLexer.FreePrefixTree(TPasLexer.FPrefixTreeRoot);
end;

constructor TPasLexer.Create;
begin
  inherited Create;

  Reset;
  FillRunProcTable;
  FillPostIdentifierTable;
end;

procedure TPasLexer.CommentHandler;
begin
  FLexerState.CurrentToken := COMMENT_TOKENS[FLexerState.CommentState];

  while True do
  begin
    case FStartPtr[FLexerState.CurrentIndex] of
      #0:
      begin
        if FLexerState.CurrentTokenPos <> FLexerState.CurrentIndex then Exit;
        NullHandler;
        Break;
      end;
      #10:
      begin
        if FLexerState.CurrentTokenPos <> FLexerState.CurrentIndex then Exit;
        LFHandler;
        Break;
      end;
      #13:
      begin
        if FLexerState.CurrentTokenPos <> FLexerState.CurrentIndex then Exit;
        CRHandler;
        Break;
      end;
      '}':
        if FLexerState.CommentState = csCurly then
        begin
          FLexerState.CommentState := csNo;
          Inc(FLexerState.CurrentIndex);
          Break;
        end;
      '*':
        if (FLexerState.CommentState = csStarParen) and (FStartPtr[FLexerState.CurrentIndex + 1] = ')') then
        begin
          FLexerState.CommentState := csNo;
          Inc(FLexerState.CurrentIndex, 2);
          Break;
        end;
    end;
    Inc(FLexerState.CurrentIndex);
  end;
end;

procedure TPasLexer.NullHandler;
begin
  FLexerState.CurrentToken := tkEOF;
end;

procedure TPasLexer.LFHandler;
begin
  if FLexerState.CommentState in [csCurly, csStarParen] then
    FLexerState.CurrentToken := tkCRLFComment
  else
    FLexerState.CurrentToken := tkCRLF;

  Inc(FLexerState.CurrentIndex);
  Inc(FLexerState.CurrentLine);
  FLexerState.CurrentLineStartPos := FLexerState.CurrentIndex;
end;

procedure TPasLexer.CRHandler;
begin
  if FLexerState.CommentState in [csCurly, csStarParen] then
    FLexerState.CurrentToken := tkCRLFComment
  else
    FLexerState.CurrentToken := tkCRLF;

  if FStartPtr[FLexerState.CurrentIndex + 1] = #10 then
    Inc(FLexerState.CurrentIndex, 2)
  else
    Inc(FLexerState.CurrentIndex);
  Inc(FLexerState.CurrentLine);
  FLexerState.CurrentLineStartPos := FLexerState.CurrentIndex;
end;

procedure TPasLexer.SpaceHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkSpace;
  while CharInSet(FStartPtr[FLexerState.CurrentIndex], [#1..#9, #11..#12, #14..#32]) do
    Inc(FLexerState.CurrentIndex);
end;

procedure TPasLexer.AsciiCharHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkAsciiChar;

  if FStartPtr[FLexerState.CurrentIndex] = '$' then
  begin
    Inc(FLexerState.CurrentIndex);
    while CharInSet(FStartPtr[FLexerState.CurrentIndex], ['0'..'9', 'A'..'F', 'a'..'f']) do
      Inc(FLexerState.CurrentIndex);
  end
  else
    while FStartPtr[FLexerState.CurrentIndex].IsDigit do
      Inc(FLexerState.CurrentIndex);
end;

procedure TPasLexer.HexNumberHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkInteger;
  while CharInSet(FStartPtr[FLexerState.CurrentIndex], ['0'..'9', 'A'..'F', 'a'..'f']) do
    Inc(FLexerState.CurrentIndex);
end;

procedure TPasLexer.StringHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkString;

  while True do
  begin
    case FStartPtr[FLexerState.CurrentIndex] of
      '''':
      begin
        if FStartPtr[FLexerState.CurrentIndex + 1] = '''' then
          Inc(FLexerState.CurrentIndex)
        else
        begin
          Inc(FLexerState.CurrentIndex);
          Break;
        end;
      end;
      #0, #10, #13:
      begin
        FLexerState.CurrentToken := tkUnterminatedString;
        Break;
      end;
    end;
    Inc(FLexerState.CurrentIndex);
  end;
end;

procedure TPasLexer.NumberHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkNumber;

  // +++ проверить правильность
  while True do
  begin
    case FStartPtr[FLexerState.CurrentIndex] of
      '0'..'9':
        Inc(FLexerState.CurrentIndex);
      'e', 'E':
      begin
        FLexerState.CurrentToken := tkFloat;
        Inc(FLexerState.CurrentIndex);
        if CharInSet(FStartPtr[FLexerState.CurrentIndex], ['-', '+']) then
          Inc(FLexerState.CurrentIndex);
      end;
      '.':
        if (FStartPtr[FLexerState.CurrentIndex + 1] = '.') or (FStartPtr[FLexerState.CurrentIndex + 1] = ')') then
          Break
        else
        begin
          FLexerState.CurrentToken := tkFloat;
          Inc(FLexerState.CurrentIndex);
        end;
    else
      Break;
    end;
  end;
end;

procedure TPasLexer.IdentifierHandler;
begin
  // Current position changes inside function
  FLexerState.CurrentToken := GetIdentifierKindWithTree;

  FPostIdentifierHandlers[FLexerState.CurrentToken](FLexerState.CurrentToken);
end;

procedure TPasLexer.CurlyOpenHandler;
var
  CompilerToken: TTokenKind;
  DirectiveStateLength, DirectiveCountersLength, i, j: Integer;
  FoundCounters: Boolean;
begin
  // +++ проверить токены если директива компилятора на нескольких строках
  if FStartPtr[FLexerState.CurrentIndex + 1] = '$' then
  begin
    FLexerState.CurrentToken := tkCompilerDirective;
    Inc(FLexerState.CurrentIndex);
  end
  else
  begin
    FLexerState.CurrentToken := tkCurlyComment;
    FLexerState.CommentState := csCurly;
  end;

  Inc(FLexerState.CurrentIndex);
  if FLexerState.CurrentToken = tkCompilerDirective then
  begin
    FLexerState.IsCompilerDirective := True;
    CompilerToken := GetIdentifierKindWithTree;
    FLexerState.IsCompilerDirective := False;

    case CompilerToken of
      tkIfDefDirective, tkIfNDefDirective, tkIf, tkIfOptDirective:
      begin
        Inc(FLexerState.Counters.IfDirectiveCount);
        // Add indication to IfDirectiveStateArray
        SetLength(FLexerState.IfDirectiveStateArray, Length(FLexerState.IfDirectiveStateArray) + 1);
        FLexerState.IfDirectiveStateArray[High(FLexerState.IfDirectiveStateArray)] := idsIf;
        // Add current counters state as start of directive to IfDirectiveSavedCountersArray
        SetLength(FLexerState.IfDirectiveSavedCountersArray, Length(FLexerState.IfDirectiveSavedCountersArray) + 1);
        FLexerState.IfDirectiveSavedCountersArray[High(FLexerState.IfDirectiveSavedCountersArray)].StartCounters := FLexerState.Counters;
      end;
      tkElseIfDirective, tkElse:
      begin
        DirectiveStateLength := Length(FLexerState.IfDirectiveStateArray);
        DirectiveCountersLength := Length(FLexerState.IfDirectiveSavedCountersArray);

        if FLexerState.Counters.IfDirectiveCount <= 0 then
          RaiseCompilerDirectiveException(EMESSAGE_UNEXPECTED_ELSE_DIRECTIVE)
        else if (DirectiveStateLength <> DirectiveCountersLength) or (DirectiveStateLength = 0) or (DirectiveCountersLength = 0) then
          RaiseCompilerDirectiveException(EMESSAGE_DIRECTIVE_STATE_COUNTER_MISMATCH)
        else if FLexerState.IfDirectiveStateArray[DirectiveStateLength - 1] = idsElse then
          RaiseCompilerDirectiveException(EMESSAGE_UNEXPECTED_ELSE_DIRECTIVE);

        // Save counters at end of main if to compare to others later
        if FLexerState.IfDirectiveStateArray[DirectiveStateLength - 1] = idsIf then
          FLexerState.IfDirectiveSavedCountersArray[High(FLexerState.IfDirectiveSavedCountersArray)].EndCounters := FLexerState.Counters;

        FoundCounters := False;
        if CompilerToken = tkElseIfDirective then
        begin
          // Check if we need to compare counters
          if FLexerState.IfDirectiveStateArray[DirectiveStateLength - 1] <> idsIf then
            for i := High(FLexerState.IfDirectiveStateArray) downto Low(FLexerState.IfDirectiveStateArray) do
              if FLexerState.IfDirectiveStateArray[i] = idsIf then
              begin
                if not CompareMem(@FLexerState.Counters, @FLexerState.IfDirectiveSavedCountersArray[i].EndCounters, SizeOf(TPasLexerStateCounters)) then
                  RaiseCompilerDirectiveException(EMESSAGE_DIRECTIVE_COUNTERS_MISMATCH_ELSE);
                Break;
              end;

          SetLength(FLexerState.IfDirectiveStateArray, DirectiveStateLength + 1);
          SetLength(FLexerState.IfDirectiveSavedCountersArray, DirectiveCountersLength + 1);
          Inc(DirectiveStateLength);

          FLexerState.IfDirectiveStateArray[DirectiveStateLength - 1] := idsElseIf;

          // Restore counters like at the start of if directive
          for i := High(FLexerState.IfDirectiveStateArray) downto Low(FLexerState.IfDirectiveStateArray) do
            if FLexerState.IfDirectiveStateArray[i] = idsIf then
            begin
              FLexerState.Counters := FLexerState.IfDirectiveSavedCountersArray[i].StartCounters;
              FoundCounters := True;
              Break;
            end;
        end
        else  // CompilerToken = tkElse
        begin
          // Restore counters like at the start of if directive
          for i := High(FLexerState.IfDirectiveStateArray) downto Low(FLexerState.IfDirectiveStateArray) do
            if FLexerState.IfDirectiveStateArray[i] = idsIf then
            begin
              FLexerState.Counters := FLexerState.IfDirectiveSavedCountersArray[i].StartCounters;
              FoundCounters := True;
              Break;
            end;

          if FLexerState.IfDirectiveStateArray[DirectiveStateLength - 1] = idsElseIf then
          begin
            SetLength(FLexerState.IfDirectiveStateArray, DirectiveStateLength + 1);
            SetLength(FLexerState.IfDirectiveSavedCountersArray, DirectiveCountersLength + 1);
            Inc(DirectiveStateLength);
          end;
          FLexerState.IfDirectiveStateArray[DirectiveStateLength - 1] := idsElse;
        end;

        if not FoundCounters then
          RaiseCompilerDirectiveException(EMESSAGE_DIRECTIVE_COUNTERS_NOTFOUND_ON_RESTORE);
      end;
      tkEndIfDirective, tkIfEndDirective:
      begin
        //FLexerState.ElseDirectiveCount := FLexerState.IfDirectiveCount;
        DirectiveStateLength := Length(FLexerState.IfDirectiveStateArray);
        DirectiveCountersLength := Length(FLexerState.IfDirectiveSavedCountersArray);

        if (DirectiveStateLength <> DirectiveCountersLength) or (DirectiveStateLength = 0) or (DirectiveCountersLength = 0) then
          RaiseCompilerDirectiveException(EMESSAGE_DIRECTIVE_STATE_COUNTER_MISMATCH);

        // Search for last if directive counters and compare to current. Also decrease state arrays.
        if FLexerState.IfDirectiveStateArray[DirectiveStateLength - 1] = idsIf then
        begin
          // Decrease arrays
          SetLength(FLexerState.IfDirectiveStateArray, DirectiveStateLength - 1);
          SetLength(FLexerState.IfDirectiveSavedCountersArray, DirectiveCountersLength - 1);
          Dec(DirectiveStateLength);
          Dec(DirectiveCountersLength);
        end
        else
        begin
          FoundCounters := False;
          j := DirectiveStateLength - 1;
          if FLexerState.IfDirectiveStateArray[j] <> idsElseIf then
          begin
            Dec(j);
            if (j < 0) or ((j >= 0) and (FLexerState.IfDirectiveStateArray[j] <> idsElseIf)) then
            begin
              FoundCounters := True;
              Inc(j);
            end;
          end;

          if not FoundCounters then
            for i := j downto Low(FLexerState.IfDirectiveStateArray) do
              if FLexerState.IfDirectiveStateArray[i] <> idsElseIf then
              begin
                j := i;
                FoundCounters := True;
              end;

          if not FoundCounters then
            RaiseCompilerDirectiveException(EMESSAGE_DIRECTIVE_COUNTERS_NOTFOUND_ON_RESTORE);

          // Compare counters
          if not CompareMem(@FLexerState.Counters, @FLexerState.IfDirectiveSavedCountersArray[j].EndCounters, SizeOf(TPasLexerStateCounters)) then
            RaiseCompilerDirectiveException(EMESSAGE_DIRECTIVE_COUNTERS_MISMATCH_ELSE);
          // Decrease arrays
          SetLength(FLexerState.IfDirectiveStateArray, j);
          SetLength(FLexerState.IfDirectiveSavedCountersArray, j);
          DirectiveStateLength := j;
          DirectiveCountersLength := j;
        end;

        Dec(FLexerState.Counters.IfDirectiveCount);

        // Compare directive counter and array length, they must be equal at end directive
        if (FLexerState.Counters.IfDirectiveCount <> DirectiveStateLength) or (FLexerState.Counters.IfDirectiveCount <> DirectiveCountersLength) then
          RaiseCompilerDirectiveException(EMESSAGE_DIRECTIVE_STATE_COUNTER_MISMATCH);
      end;
    end;
  end;

  while FLexerState.CurrentIndex < FLexerState.MaxIndex do
    case FStartPtr[FLexerState.CurrentIndex] of
      '}':
      begin
        FLexerState.CommentState := csNo;
        Inc(FLexerState.CurrentIndex);
        Break;
      end;
      #10:
        if FLexerState.CurrentToken = tkCompilerDirective then
        begin
          Inc(FLexerState.CurrentIndex);
          Inc(FLexerState.CurrentLine);
          FLexerState.CurrentLineStartPos := FLexerState.CurrentIndex;
        end
        else
          Break;
      #13:
        if FLexerState.CurrentToken = tkCompilerDirective then
        begin
          if FStartPtr[FLexerState.CurrentIndex + 1] = #10 then
            Inc(FLexerState.CurrentIndex, 2)
          else
            Inc(FLexerState.CurrentIndex);
          Inc(FLexerState.CurrentLine);
          FLexerState.CurrentLineStartPos := FLexerState.CurrentIndex;
        end
        else
          Break;
    else
      Inc(FLexerState.CurrentIndex);
    end;
end;

procedure TPasLexer.RoundOpenHandler;
begin
  Inc(FLexerState.CurrentIndex);

  case FStartPtr[FLexerState.CurrentIndex] of
    '*':
    begin
      FLexerState.CurrentToken := tkStarParenComment;
      if FStartPtr[FLexerState.CurrentIndex + 1] = '$' then
        FLexerState.CurrentToken := tkCompilerDirective
      else
        FLexerState.CommentState := csStarParen;

      Inc(FLexerState.CurrentIndex);
      while True do
      begin
        case FStartPtr[FLexerState.CurrentIndex] of
          '*':
            if FStartPtr[FLexerState.CurrentIndex + 1] = ')' then
            begin
              FLexerState.CommentState := csNo;
              Inc(FLexerState.CurrentIndex, 2);
              Break;
            end;
          #0, #10, #13: Break;
        end;
        Inc(FLexerState.CurrentIndex);
      end;
    end;
    '.':
    begin
      Inc(FLexerState.CurrentIndex);
      FLexerState.CurrentToken := tkSquareOpen;
      Inc(FLexerState.Counters.SquareCount);
    end;
  else
    begin
      FLexerState.CurrentToken := tkRoundOpen;
      Inc(FLexerState.Counters.RoundCount);
    end;
  end;
end;

procedure TPasLexer.RoundCloseHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkRoundClose;
  Dec(FLexerState.Counters.RoundCount);
end;

procedure TPasLexer.StarHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkStar;
end;

procedure TPasLexer.SlashHandler;
begin
  case FStartPtr[FLexerState.CurrentIndex + 1] of
    '/':
    begin
      Inc(FLexerState.CurrentIndex, 2);
      FLexerState.CurrentToken := tkSingleLineComment;

      while True do
      begin
        case FStartPtr[FLexerState.CurrentIndex] of
          #0, #10, #13: Break;
        end;
        Inc(FLexerState.CurrentIndex);
      end;
    end;
  else
    begin
      Inc(FLexerState.CurrentIndex);
      FLexerState.CurrentToken := tkSlash;
    end;
  end;
end;

procedure TPasLexer.PlusHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkPlus;
end;

procedure TPasLexer.MinusHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkMinus;
end;

procedure TPasLexer.CommaHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkComma;
end;

procedure TPasLexer.PointHandler;
begin
  case FStartPtr[FLexerState.CurrentIndex + 1] of
    '.':
    begin
      Inc(FLexerState.CurrentIndex, 2);
      FLexerState.CurrentToken := tkDotDot;
    end;
    ')':
    begin
      Inc(FLexerState.CurrentIndex, 2);
      FLexerState.CurrentToken := tkSquareClose;
      Dec(FLexerState.Counters.SquareCount);
    end;
  else
    begin
      Inc(FLexerState.CurrentIndex);
      FLexerState.CurrentToken := tkPoint;
    end;
  end;
end;

procedure TPasLexer.ColonHandler;
begin
  if FStartPtr[FLexerState.CurrentIndex + 1] = '=' then
  begin
    Inc(FLexerState.CurrentIndex, 2);
    FLexerState.CurrentToken := tkAssign;
  end
  else
  begin
    Inc(FLexerState.CurrentIndex);
    FLexerState.CurrentToken := tkColon;
  end;
end;

procedure TPasLexer.SemiColonHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkSemiColon;
  FLexerState.IsProperty := False;
end;

procedure TPasLexer.LowerHandler;
begin
  case FStartPtr[FLexerState.CurrentIndex + 1] of
    '=':
    begin
      Inc(FLexerState.CurrentIndex, 2);
      FLexerState.CurrentToken := tkLowerEqual;
    end;
    '>':
    begin
      Inc(FLexerState.CurrentIndex, 2);
      FLexerState.CurrentToken := tkNotEqual;
    end
  else
    begin
      Inc(FLexerState.CurrentIndex);
      FLexerState.CurrentToken := tkLower;
    end;
  end;
end;

procedure TPasLexer.EqualHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkEqual;
end;

procedure TPasLexer.GreaterHandler;
begin
  if FStartPtr[FLexerState.CurrentIndex + 1] = '=' then
  begin
    Inc(FLexerState.CurrentIndex, 2);
    FLexerState.CurrentToken := tkGreaterEqual;
  end
  else
  begin
    Inc(FLexerState.CurrentIndex);
    FLexerState.CurrentToken := tkGreater;
  end;
end;

procedure TPasLexer.AddressSymbolHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkAddressSymbol;
end;

procedure TPasLexer.SquareOpenHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkSquareOpen;
  Inc(FLexerState.Counters.SquareCount);
end;

procedure TPasLexer.SquareCloseHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkSquareClose;
  Dec(FLexerState.Counters.SquareCount);
end;

procedure TPasLexer.PointerSymbolHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkPointerSymbol;
end;

procedure TPasLexer.SymbolHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkSymbol;
end;

procedure TPasLexer.UnknownHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkUnknown;
end;

procedure TPasLexer.PropertyPostHandler(var AToken: TTokenKind);
begin
  FLexerState.IsProperty := True;
end;

procedure TPasLexer.PropertyDirectivePostHandler(var AToken: TTokenKind);
begin
  if not FLexerState.IsProperty then
    AToken := tkIdentifier;
end;

procedure TPasLexer.EndPostHandler(var AToken: TTokenKind);
begin
  if FStartPtr[FLexerState.CurrentIndex] = '.' then
  begin
    Inc(FLexerState.CurrentIndex);
    AToken := tkUnitEnd
  end;
end;

procedure TPasLexer.BlankPostHandler(var AToken: TTokenKind);
begin
  // do nothing
end;

function TPasLexer.GetIdentifierKindWithTree: TTokenKind;
var
  Temp: PChar;
  CurrentNode, NextNode: PPrefixTreeNode;
begin
  Temp := FStartPtr + FLexerState.CurrentIndex;
  CurrentNode := TPasLexer.FPrefixTreeRoot;
  while CharInSet(Temp^, ['a'..'z', 'A'..'Z']) do
  begin
    NextNode := CurrentNode^.NextCharPointers[TPasLexer.FCharHashTable[Temp^]];

    if not Assigned(NextNode) then
    begin
      CurrentNode := nil;
      SkipToIdentifierEnd(Temp);
      Break;
    end;

    CurrentNode := NextNode;
    Inc(Temp);
  end;
  if (Ord(Temp^) > 127) or CharInSet(Temp^, ['_', '0'..'9']) then
  begin
    Result := tkIdentifier;
    while (Ord(Temp^) > 127) or CharInSet(Temp^, ['_', '0'..'9', 'a'..'z', 'A'..'Z']) do
      Inc(Temp);
  end
  else if Assigned(CurrentNode) then
    Result := CurrentNode^.CurrentTokenKind
  // +++ посмотреть это условие, поидее можно убрать но надо проверять
  //else if (not FLexerState.IsCompilerDirective) and (FLexerState.CurrentToken in CONDITIONAL_COMPILER_TOKENS) then
  //  Result := tkIdentifier
  else
    Result := tkIdentifier;

  FLexerState.CurrentIndex := Temp - FStartPtr;
end;

procedure TPasLexer.SkipToIdentifierEnd(var ACurrentPtr: PChar);
begin
  while CharInSet(ACurrentPtr^, ['a'..'z', 'A'..'Z']) do
    Inc(ACurrentPtr);
end;

{function TPasLexer.TestNextTokenSequence(const AExpectedTokens: array of TTokenKind): Boolean;
var
  i: Integer;
begin
  Result := True;

  for i := Low(AExpectedTokens) to High(AExpectedTokens) do
  begin
    NextTokenNoJunk;
    if FLexerState.CurrentToken <> AExpectedTokens[i] then
      Exit(False);
  end;
end;}

procedure TPasLexer.RaiseCompilerDirectiveException(const AMessage: string);
begin
  if not FLexerState.IgnoreCompilerDirectiveChecks then
    raise EPasLexerException.Create(AMessage, Self);
end;

procedure TPasLexer.FillRunProcTable;
var
  Ch: Char;
begin
  for Ch := Low(FRunHandlers) to High(FRunHandlers) do
    case Ch of
      #0:
        FRunHandlers[Ch] := NullHandler;
      #10:
        FRunHandlers[Ch] := LFHandler;
      #13:
        FRunHandlers[Ch] := CRHandler;
      #1..#9, #11..#12, #14..#32:
        FRunHandlers[Ch] := SpaceHandler;
      '#':
        FRunHandlers[Ch] := AsciiCharHandler;
      '$':
        FRunHandlers[Ch] := HexNumberHandler;
      '''':
        FRunHandlers[Ch] := StringHandler;
      '0'..'9':
        FRunHandlers[Ch] := NumberHandler;
      'A'..'Z', 'a'..'z', '_':
        FRunHandlers[Ch] := IdentifierHandler;
      '{':
        FRunHandlers[Ch] := CurlyOpenHandler;
      '}':
        FRunHandlers[Ch] := UnknownHandler;  // lexer should handle all comments in Next method
      '!', '"', '%', '&', '('..'/', ':'..'@', '['..'^', '`', '~':
      begin
        case Ch of
          '(': FRunHandlers[Ch] := RoundOpenHandler;
          ')': FRunHandlers[Ch] := RoundCloseHandler;
          '*': FRunHandlers[Ch] := StarHandler;
          '/': FRunHandlers[Ch] := SlashHandler;
          '+': FRunHandlers[Ch] := PlusHandler;
          '-': FRunHandlers[Ch] := MinusHandler;
          ',': FRunHandlers[Ch] := CommaHandler;
          '.': FRunHandlers[Ch] := PointHandler;
          ':': FRunHandlers[Ch] := ColonHandler;
          ';': FRunHandlers[Ch] := SemiColonHandler;
          '<': FRunHandlers[Ch] := LowerHandler;
          '=': FRunHandlers[Ch] := EqualHandler;
          '>': FRunHandlers[Ch] := GreaterHandler;
          '@': FRunHandlers[Ch] := AddressSymbolHandler;
          '[': FRunHandlers[Ch] := SquareOpenHandler;
          ']': FRunHandlers[Ch] := SquareCloseHandler;
          '^': FRunHandlers[Ch] := PointerSymbolHandler;
        else
          FRunHandlers[Ch] := SymbolHandler;
        end;
      end;
    else
      FRunHandlers[Ch] := UnknownHandler;
    end;
end;

procedure TPasLexer.FillPostIdentifierTable;
var
  TokenKind: TTokenKind;
begin
  for TokenKind := Low(TTokenKind) to High(TTokenKind) do
    case TokenKind of
      tkProperty:
        FPostIdentifierHandlers[TokenKind] := PropertyPostHandler;
      tkRead, tkWrite, tkIndex, tkStored, tkDefault, tkNodefault:
        FPostIdentifierHandlers[TokenKind] := PropertyDirectivePostHandler;
      tkEnd:
        FPostIdentifierHandlers[TokenKind] := EndPostHandler;
    else
      FPostIdentifierHandlers[TokenKind] := BlankPostHandler;
    end;
end;

class procedure TPasLexer.InitCharHashTable;
var
  Ch: Char;
begin
  for Ch := #0 to #127 do
  begin
    // Hash for lowercase converted to uppercase
    case Ch of
      'a'..'z': FCharHashTable[Ch] := (Word(Ch) xor $0020) - 64;
      'A'..'Z', '_': FCharHashTable[Ch] := Ord(Ch) - 64;
    else
      FCharHashTable[Ch] := 0;
    end;
  end;
end;

class procedure TPasLexer.InitPrefixTree;
var
  KeywordIndex, CharIndex, LastIndex, CharHash: Integer;
  CurrentNode: PPrefixTreeNode;
begin
  if Assigned(FPrefixTreeRoot) then Exit;

  FPrefixTreeRoot := AllocMem(PREFIX_TREE_NODE_SIZE);
  FPrefixTreeRoot^.CurrentTokenKind := tkIdentifier;

  for KeywordIndex := Low(DELPHI_KEYWORDS) to High(DELPHI_KEYWORDS) do
  begin
    CurrentNode := FPrefixTreeRoot;

    LastIndex := High(DELPHI_KEYWORDS[KeywordIndex].Word);
    for CharIndex := Low(DELPHI_KEYWORDS[KeywordIndex].Word) to LastIndex do
    begin
      CharHash := FCharHashTable[DELPHI_KEYWORDS[KeywordIndex].Word[CharIndex]];
      if not Assigned(CurrentNode^.NextCharPointers[CharHash]) then
      begin
        CurrentNode^.NextCharPointers[CharHash] := AllocMem(PREFIX_TREE_NODE_SIZE);
        CurrentNode^.NextCharPointers[CharHash]^.CurrentTokenKind := tkIdentifier;
      end;
      CurrentNode := CurrentNode^.NextCharPointers[CharHash];

      if CharIndex >= LastIndex then
        CurrentNode^.CurrentTokenKind := DELPHI_KEYWORDS[KeywordIndex].Token;
    end;
  end;
end;

class procedure TPasLexer.FreePrefixTree(const ANode: PPrefixTreeNode);
var
  i: Byte;
begin
  if not Assigned(ANode) then Exit;

  for i := Low(ANode^.NextCharPointers) to High(ANode^.NextCharPointers) do
    if Assigned(ANode^.NextCharPointers[i]) then
      FreePrefixTree(ANode^.NextCharPointers[i]);

  FreeMem(ANode);
end;

procedure TPasLexer.SetLexerState(ANewState: TPasLexerState);
begin
  FLexerState.CopyFrom(ANewState);
end;

function TPasLexer.GetCurrentToken: string;
var
  Len: Integer;
begin
  Len := FLexerState.CurrentIndex - FLexerState.CurrentTokenPos;
  SetString(Result, FStartPtr + FLexerState.CurrentTokenPos, Len);
end;

procedure TPasLexer.SetData(var ADataString: string);
begin
  FStartPtr := @ADataString[1];
  FEndPtr := FStartPtr + Length(ADataString);
  Reset;
end;

procedure TPasLexer.Reset;
begin
  FLexerState.Reset;
  if FStartPtr <> nil then
  begin
    FLexerState.MaxIndex := FEndPtr - FStartPtr;
    NextToken;
  end;
end;

function TPasLexer.NextToken: Boolean;
var
  CurChar: Char;
begin
  if not(FLexerState.CurrentToken in [tkCurlyComment, tkSingleLineComment, tkStarParenComment, tkCompilerDirective, tkCRLF, tkCRLFComment, tkSpace]) then
  begin
    FLexerState.LastSignificantToken := FLexerState.CurrentToken;
    FLexerState.LastSignificantTokenPos := FLexerState.CurrentTokenPos;
  end;

  FLexerState.CurrentTokenPos := FLexerState.CurrentIndex;

  case FLexerState.CommentState of
    csNo:
    begin
      CurChar := FStartPtr[FLexerState.CurrentIndex];
      if CurChar <= High(FRunHandlers) then
        FRunHandlers[CurChar]
      else
        IdentifierHandler;
    end;
    csCurly, csStarParen:
      CommentHandler;
  end;

  Result := FLexerState.CurrentToken <> tkEOF;
end;

function TPasLexer.NextTokenNoJunk: Boolean;
begin
  repeat
    Result := NextToken;
  until Result and not(FLexerState.CurrentToken in [tkSingleLineComment, tkCurlyComment, tkStarParenComment, tkCompilerDirective,
      tkCRLF, tkCRLFComment, tkSpace]);
end;

function TPasLexer.NextTokenNoDirectiveBranching: Boolean;
var
  SavedDirectiveState: TIfDirectiveState;
  SavedDirectiveLength: Integer;
  SameDirectiveLevel: Boolean;
begin
  SavedDirectiveLength := Length(FLexerState.IfDirectiveStateArray);
  if SavedDirectiveLength > 0 then
    SavedDirectiveState := FLexerState.IfDirectiveStateArray[High(FLexerState.IfDirectiveStateArray)]
  else
    SavedDirectiveState := idsNone;

  repeat
    Result := NextTokenNoJunk;
    SameDirectiveLevel := ((SavedDirectiveLength = 0) and (Length(FLexerState.IfDirectiveStateArray) = 0))
        or ((SavedDirectiveLength > 0) and ((Length(FLexerState.IfDirectiveStateArray) < SavedDirectiveLength)
        or ((Length(FLexerState.IfDirectiveStateArray) = SavedDirectiveLength) and (FLexerState.IfDirectiveStateArray[High(FLexerState.IfDirectiveStateArray)] = SavedDirectiveState))));
  until Result and SameDirectiveLevel;
end;

function TPasLexer.NextTokenWithKind(ATokenKind: TTokenKind): Boolean;
begin
  repeat
    Result := NextTokenNoJunk;
  until Result and (FLexerState.CurrentToken = ATokenKind);
end;

end.
