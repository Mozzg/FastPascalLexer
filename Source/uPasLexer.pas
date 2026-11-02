(*******************************************************************************
*  Copyright © 2025 - 2026 Pervov Evgeny                                       *
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
*  Version: 0.4                                                                *
*  Last modified: 02.11.2026                                                   *
*  Contributor(s):                                                             *
*    Pervov Evgeny <operationm@list.ru>                                        *
*******************************************************************************)

unit uPasLexer;

// Every routine of the unit starts at a 16-byte boundary, as Win64 does by default (Win32 aligns to 4 bytes). The speed
// of the hot routines depends on their offset in a 64-byte block, so with 4-byte alignment any change of the code linked
// before them moved the benchmark by up to 8 %, with 16-byte alignment by about 2 %. 16 is the largest allowed value.
{$CODEALIGN 16}

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
    WasLineChange: Boolean;
    // True between 'asm' and the 'end' of its block: a double quote starts a BASM string there
    IsAsmBlock: Boolean;
    // Line breaks inside the current compiler directive token: the next NextToken adds them to CurrentLine instead of
    // one line for WasLineChange. Placed after the hot fields: moving those fields slows the lexer down.
    DirectiveLineBreakCount: Cardinal;
    // Start of the line after the last line break inside the current compiler directive token
    DirectiveLineStartPos: Cardinal;
    // Branches of the open conditional directives: every {$IF...} level starts with an idsIf entry, followed by an
    // idsElseIf or idsElse entry for every {$ELSEIF} or {$ELSE} branch met so far
    IfDirectiveStateArray: TArray<TIfDirectiveState>;
    // Parallel to IfDirectiveStateArray; only the entries at the idsIf indexes are used: the counters at the start of
    // the level and at the end of its first branch
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
    procedure BinaryNumberHandler;
    procedure StringHandler;
    // A string in double quotes inside an asm block, a symbol elsewhere
    procedure DoubleQuoteHandler;
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
    // Reads a compiler directive after '{$' (ABracketKind = csCurly) or '(*$' (ABracketKind = csStarParen)
    procedure CompilerDirectiveHandler(ABracketKind: TCommentState);

    // Conditional directives, called by CompilerDirectiveHandler. Kept next to it on purpose: declared after
    // GetIdentifierKindWithTree, they moved its code off a 64-byte boundary and LexerBenchmark got ~6 % slower.

    // Index of the idsIf entry of the innermost open conditional level, -1 if there is none
    function FindIfDirectiveLevelStart: Integer;
    // {$IF}, {$IFDEF}, {$IFNDEF}, {$IFOPT}: opens a conditional level
    procedure OpenIfDirectiveLevel;
    // {$ELSEIF} (ABranchState = idsElseIf) or {$ELSE} (idsElse): ends the current branch and starts the next one.
    // Every branch must leave the bracket counters as the first one does.
    procedure StartElseDirectiveBranch(ABranchState: TIfDirectiveState);
    // {$ENDIF}, {$IFEND}: closes the innermost conditional level
    procedure CloseIfDirectiveLevel;

    // PostIdentifierHandlers
    procedure PropertyPostHandler(var AToken: TTokenKind);
    procedure PropertyDirectivePostHandler(var AToken: TTokenKind);
    procedure EndPostHandler(var AToken: TTokenKind);
    // Marks the start of an asm block for DoubleQuoteHandler
    procedure AsmPostHandler(var AToken: TTokenKind);
    procedure BlankPostHandler(var AToken: TTokenKind);

    function GetIdentifierKindWithTree: TTokenKind;
    procedure SkipToIdentifierEnd(var ACurrentPtr: PChar);

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
        if FLexerState.CurrentTokenPos <> FLexerState.CurrentIndex then
          Exit;
        NullHandler;
        Break;
      end;
      #10:
      begin
        if FLexerState.CurrentTokenPos <> FLexerState.CurrentIndex then
          Exit;
        LFHandler;
        Break;
      end;
      #13:
      begin
        if FLexerState.CurrentTokenPos <> FLexerState.CurrentIndex then
          Exit;
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
  FLexerState.WasLineChange := True;
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
  FLexerState.WasLineChange := True;
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

  // '_' is the digit separator of Delphi 11, allowed anywhere after '#' and '#$': #1_0, #$00_41
  if FStartPtr[FLexerState.CurrentIndex] = '$' then
  begin
    Inc(FLexerState.CurrentIndex);
    while CharInSet(FStartPtr[FLexerState.CurrentIndex], ['0'..'9', 'A'..'F', 'a'..'f', '_']) do
      Inc(FLexerState.CurrentIndex);
  end
  else
    while FStartPtr[FLexerState.CurrentIndex].IsDigit or (FStartPtr[FLexerState.CurrentIndex] = '_') do
      Inc(FLexerState.CurrentIndex);
end;

procedure TPasLexer.HexNumberHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkInteger;
  // '_' is the digit separator of Delphi 11: $FFFF_FFFF
  while CharInSet(FStartPtr[FLexerState.CurrentIndex], ['0'..'9', 'A'..'F', 'a'..'f', '_']) do
    Inc(FLexerState.CurrentIndex);
end;

procedure TPasLexer.BinaryNumberHandler;
begin
  Inc(FLexerState.CurrentIndex);
  // A percent sign not followed by a binary digit or a digit separator is not a number
  if not CharInSet(FStartPtr[FLexerState.CurrentIndex], ['0', '1', '_']) then
  begin
    FLexerState.CurrentToken := tkSymbol;
    Exit;
  end;

  // Binary literal of Delphi 11: %1010_0101
  FLexerState.CurrentToken := tkInteger;
  repeat
    Inc(FLexerState.CurrentIndex);
  until not CharInSet(FStartPtr[FLexerState.CurrentIndex], ['0', '1', '_']);
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
        Inc(FLexerState.CurrentIndex);
        if FStartPtr[FLexerState.CurrentIndex] <> '''' then
          Break;
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

procedure TPasLexer.DoubleQuoteHandler;
begin
  Inc(FLexerState.CurrentIndex);
  // Like Delphi, a double quote is an illegal character outside asm blocks
  if not FLexerState.IsAsmBlock then
  begin
    FLexerState.CurrentToken := tkSymbol;
    Exit;
  end;

  // BASM string: no escapes, it ends at the next double quote or at the line end at the latest
  FLexerState.CurrentToken := tkString;
  while True do
  begin
    case FStartPtr[FLexerState.CurrentIndex] of
      '"':
      begin
        Inc(FLexerState.CurrentIndex);
        Break;
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
var
  WasExponent: Boolean;
  WasPoint: Boolean;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkNumber;
  WasExponent := False;
  WasPoint := False;

  while True do
  begin
    case FStartPtr[FLexerState.CurrentIndex] of
      // '_' is the digit separator of Delphi 11: 1_000, 1_000.000_1, 1e1_0
      '0'..'9', '_':
        Inc(FLexerState.CurrentIndex);
      'e', 'E':
      begin
        Inc(FLexerState.CurrentIndex);
        if CharInSet(FStartPtr[FLexerState.CurrentIndex], ['-', '+']) then
          Inc(FLexerState.CurrentIndex);
        // An exponent without digits ('1e-', '1E+') is not a float:
        // backtrack past the 'e' and the sign, so 'e' is lexed as an identifier.
        if not CharInSet(FStartPtr[FLexerState.CurrentIndex], ['0'..'9']) then
        begin
          Dec(FLexerState.CurrentIndex);
          if CharInSet(FStartPtr[FLexerState.CurrentIndex], ['-', '+']) then
            Dec(FLexerState.CurrentIndex);
          Break;
        end;
        FLexerState.CurrentToken := tkFloat;
        WasExponent := True;
      end;
      '.':
      begin
        // A dot after the fraction ('1.5.6') or the exponent ('1e33.3') is not part of the number. Like in Delphi, neither
        // is a dot followed by '.', ')', an ASCII letter or '_': 1..2, (.1.), 1.ToString, 1.e5 is 1 . e5.
        // Any other character after the dot ('1.', '1.&X', '1.Ä') makes a real number.
        if WasPoint or WasExponent
            or CharInSet(FStartPtr[FLexerState.CurrentIndex + 1], ['.', ')', 'A'..'Z', 'a'..'z', '_'])
        then
          Break;

        FLexerState.CurrentToken := tkFloat;
        WasPoint := True;
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
begin
  if FStartPtr[FLexerState.CurrentIndex + 1] = '$' then
  begin
    FLexerState.CurrentToken := tkCompilerDirective;
    Inc(FLexerState.CurrentIndex, 2);
    CompilerDirectiveHandler(csCurly);
    Exit;
  end;

  FLexerState.CurrentToken := tkCurlyComment;
  FLexerState.CommentState := csCurly;
  Inc(FLexerState.CurrentIndex);

  while FLexerState.CurrentIndex < FLexerState.MaxIndex do
    case FStartPtr[FLexerState.CurrentIndex] of
      '}':
      begin
        FLexerState.CommentState := csNo;
        Inc(FLexerState.CurrentIndex);
        Break;
      end;
      #0, #10, #13:
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
      if FStartPtr[FLexerState.CurrentIndex + 1] <> '$' then
        FLexerState.CommentState := csStarParen
      else
      begin
        FLexerState.CurrentToken := tkCompilerDirective;
        Inc(FLexerState.CurrentIndex, 2);
        CompilerDirectiveHandler(csStarParen);
        Exit;
      end;

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
          #0, #10, #13:
            Break;
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

procedure TPasLexer.CompilerDirectiveHandler(ABracketKind: TCommentState);
var
  CompilerToken: TTokenKind;
begin
  if FLexerState.CurrentToken = tkCompilerDirective then
  begin
    FLexerState.IsCompilerDirective := True;
    CompilerToken := GetIdentifierKindWithTree;
    FLexerState.IsCompilerDirective := False;

    case CompilerToken of
      tkIfDefDirective, tkIfNDefDirective, tkIf, tkIfOptDirective:
        OpenIfDirectiveLevel;
      tkElseIfDirective:
        StartElseDirectiveBranch(idsElseIf);
      tkElse:
        StartElseDirectiveBranch(idsElse);
      tkEndIfDirective, tkIfEndDirective:
        CloseIfDirectiveLevel;
    end;

    // Like Delphi, '{$' ends only at '}' and '(*$' only at '*)', quotes are not taken into account:
    // (*$HPPEMIT '{}'*) is one directive
    while FLexerState.CurrentIndex < FLexerState.MaxIndex do
      case FStartPtr[FLexerState.CurrentIndex] of
        '}':
        begin
          Inc(FLexerState.CurrentIndex);
          if ABracketKind = csCurly then
            Break;
        end;
        '*':
        begin
          Inc(FLexerState.CurrentIndex);
          if (ABracketKind = csStarParen) and (FStartPtr[FLexerState.CurrentIndex] = ')') then
          begin
            Inc(FLexerState.CurrentIndex);
            Break;
          end;
        end;
        #0:
          Break;
        // A directive is one token even across lines: count every line break for the line tracking in NextToken
        #10:
        begin
          Inc(FLexerState.CurrentIndex);
          Inc(FLexerState.DirectiveLineBreakCount);
          FLexerState.DirectiveLineStartPos := FLexerState.CurrentIndex;
          FLexerState.WasLineChange := True;
        end;
        #13:
        begin
          if FStartPtr[FLexerState.CurrentIndex + 1] = #10 then
            Inc(FLexerState.CurrentIndex, 2)
          else
            Inc(FLexerState.CurrentIndex);
          Inc(FLexerState.DirectiveLineBreakCount);
          FLexerState.DirectiveLineStartPos := FLexerState.CurrentIndex;
          FLexerState.WasLineChange := True;
        end
      else
        Inc(FLexerState.CurrentIndex);
      end;
  end;
end;

function TPasLexer.FindIfDirectiveLevelStart: Integer;
begin
  // The entries above the idsIf entry of a level are only its idsElseIf and idsElse entries
  Result := High(FLexerState.IfDirectiveStateArray);
  while (Result >= 0) and (FLexerState.IfDirectiveStateArray[Result] <> idsIf) do
    Dec(Result);
end;

procedure TPasLexer.OpenIfDirectiveLevel;
var
  LevelIndex: Integer;
begin
  Inc(FLexerState.Counters.IfDirectiveCount);
  LevelIndex := Length(FLexerState.IfDirectiveStateArray);
  SetLength(FLexerState.IfDirectiveStateArray, LevelIndex + 1);
  FLexerState.IfDirectiveStateArray[LevelIndex] := idsIf;
  SetLength(FLexerState.IfDirectiveSavedCountersArray, LevelIndex + 1);
  FLexerState.IfDirectiveSavedCountersArray[LevelIndex].StartCounters := FLexerState.Counters;
end;

procedure TPasLexer.StartElseDirectiveBranch(ABranchState: TIfDirectiveState);
var
  StateLength, LevelIndex: Integer;
begin
  // With IgnoreCompilerDirectiveChecks the exception is not raised: a directive that cannot be matched to an open
  // level is skipped, other errors do not stop the bookkeeping
  if FLexerState.Counters.IfDirectiveCount <= 0 then
  begin
    RaiseCompilerDirectiveException(EMESSAGE_UNEXPECTED_ELSE_DIRECTIVE);
    Exit;
  end;
  StateLength := Length(FLexerState.IfDirectiveStateArray);
  if (StateLength = 0) or (StateLength <> Length(FLexerState.IfDirectiveSavedCountersArray)) then
  begin
    RaiseCompilerDirectiveException(EMESSAGE_DIRECTIVE_STATE_COUNTER_MISMATCH);
    Exit;
  end;
  LevelIndex := FindIfDirectiveLevelStart;
  if LevelIndex < 0 then
  begin
    RaiseCompilerDirectiveException(EMESSAGE_DIRECTIVE_COUNTERS_NOTFOUND_ON_RESTORE);
    Exit;
  end;

  // Delphi accepts a repeated {$ELSE} (its branch is never compiled), but not {$ELSEIF} after {$ELSE} (E2029)
  if (ABranchState = idsElseIf) and (FLexerState.IfDirectiveStateArray[StateLength - 1] = idsElse) then
    RaiseCompilerDirectiveException(EMESSAGE_UNEXPECTED_ELSE_DIRECTIVE);

  // The end of the first branch is saved, the end of every other branch is compared to it
  if LevelIndex = StateLength - 1 then
    FLexerState.IfDirectiveSavedCountersArray[LevelIndex].EndCounters := FLexerState.Counters
  else if not CompareMem(@FLexerState.Counters, @FLexerState.IfDirectiveSavedCountersArray[LevelIndex].EndCounters,
      SizeOf(TPasLexerStateCounters))
  then
    RaiseCompilerDirectiveException(EMESSAGE_DIRECTIVE_COUNTERS_MISMATCH_ELSE);

  SetLength(FLexerState.IfDirectiveStateArray, StateLength + 1);
  FLexerState.IfDirectiveStateArray[StateLength] := ABranchState;
  SetLength(FLexerState.IfDirectiveSavedCountersArray, StateLength + 1);
  // Every branch starts with the counters of the start of the level
  FLexerState.Counters := FLexerState.IfDirectiveSavedCountersArray[LevelIndex].StartCounters;
end;

procedure TPasLexer.CloseIfDirectiveLevel;
var
  StateLength, LevelIndex: Integer;
begin
  // With IgnoreCompilerDirectiveChecks the exception is not raised: a directive that cannot be matched to an open
  // level is skipped, other errors do not stop the bookkeeping
  StateLength := Length(FLexerState.IfDirectiveStateArray);
  if (StateLength = 0) or (StateLength <> Length(FLexerState.IfDirectiveSavedCountersArray)) then
  begin
    RaiseCompilerDirectiveException(EMESSAGE_DIRECTIVE_STATE_COUNTER_MISMATCH);
    Exit;
  end;
  LevelIndex := FindIfDirectiveLevelStart;
  if LevelIndex < 0 then
  begin
    RaiseCompilerDirectiveException(EMESSAGE_DIRECTIVE_COUNTERS_NOTFOUND_ON_RESTORE);
    Exit;
  end;

  // A level without {$ELSEIF} and {$ELSE} has a single branch, there is nothing to compare it to
  if (LevelIndex < StateLength - 1)
      and not CompareMem(@FLexerState.Counters, @FLexerState.IfDirectiveSavedCountersArray[LevelIndex].EndCounters,
      SizeOf(TPasLexerStateCounters))
  then
    RaiseCompilerDirectiveException(EMESSAGE_DIRECTIVE_COUNTERS_MISMATCH_ELSE);
  // Inside a level the directive counter is the one saved at its start, unless the state was changed from outside
  if FLexerState.Counters.IfDirectiveCount <> FLexerState.IfDirectiveSavedCountersArray[LevelIndex].StartCounters.IfDirectiveCount then
    RaiseCompilerDirectiveException(EMESSAGE_DIRECTIVE_STATE_COUNTER_MISMATCH);

  SetLength(FLexerState.IfDirectiveStateArray, LevelIndex);
  SetLength(FLexerState.IfDirectiveSavedCountersArray, LevelIndex);
  Dec(FLexerState.Counters.IfDirectiveCount);
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
  // 'end' closes an asm block, a BASM label like @@end does not
  if FLexerState.LastSignificantToken <> tkAddressSymbol then
    FLexerState.IsAsmBlock := False;
  if FStartPtr[FLexerState.CurrentIndex] = '.' then
  begin
    Inc(FLexerState.CurrentIndex);
    AToken := tkUnitEnd
  end;
end;

procedure TPasLexer.AsmPostHandler(var AToken: TTokenKind);
begin
  // '&asm' is an identifier, not the start of an asm block
  if (FLexerState.CurrentTokenPos = 0) or (FStartPtr[FLexerState.CurrentTokenPos - 1] <> '&') then
    FLexerState.IsAsmBlock := True;
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
  else
    Result := tkIdentifier;

  FLexerState.CurrentIndex := Temp - FStartPtr;
end;

procedure TPasLexer.SkipToIdentifierEnd(var ACurrentPtr: PChar);
begin
  while CharInSet(ACurrentPtr^, ['a'..'z', 'A'..'Z']) do
    Inc(ACurrentPtr);
end;

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
      '%':
        FRunHandlers[Ch] := BinaryNumberHandler;
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
      '!', '"', '&', '('..'/', ':'..'@', '['..'^', '`', '~':
      begin
        case Ch of
          '"': FRunHandlers[Ch] := DoubleQuoteHandler;
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
      tkAsm:
        FPostIdentifierHandlers[TokenKind] := AsmPostHandler;
    else
      FPostIdentifierHandlers[TokenKind] := BlankPostHandler;
    end;
end;

class procedure TPasLexer.InitCharHashTable;
const
  HASH_OFFSET = 64;
var
  Ch: Char;
begin
  for Ch := #0 to #127 do
  begin
    // Hash for lowercase converted to uppercase
    case Ch of
      'a'..'z': FCharHashTable[Ch] := (Word(Ch) xor $0020) - HASH_OFFSET;
      'A'..'Z': FCharHashTable[Ch] := Ord(Ch) - HASH_OFFSET;
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

  // +++ проверить, нужно ли условие с Assigned ниже
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
  FStartPtr := Pointer(ADataString);
  FEndPtr := FStartPtr + Length(ADataString);
  Reset;
  if FStartPtr = nil then
    FLexerState.CurrentToken := tkEOF;
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
  if FStartPtr = nil then
  begin
    FLexerState.CurrentToken := tkEOF;
    Exit(False);
  end;
  if not (FLexerState.CurrentToken in DIRECTIVE_INSIGNIFICANT_TOKENS) then
  begin
    FLexerState.LastSignificantToken := FLexerState.CurrentToken;
    FLexerState.LastSignificantTokenPos := FLexerState.CurrentTokenPos;
  end;
  if FLexerState.WasLineChange then
  begin
    if FLexerState.DirectiveLineBreakCount = 0 then
    begin
      FLexerState.CurrentLineStartPos := FLexerState.CurrentIndex;
      Inc(FLexerState.CurrentLine);
    end
    else
    begin
      // The previous token is a compiler directive spanning several lines
      FLexerState.CurrentLineStartPos := FLexerState.DirectiveLineStartPos;
      Inc(FLexerState.CurrentLine, FLexerState.DirectiveLineBreakCount);
      FLexerState.DirectiveLineBreakCount := 0;
    end;
    FLexerState.WasLineChange := False;
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
  until (not Result) or not (FLexerState.CurrentToken in [tkSingleLineComment, tkCurlyComment, tkStarParenComment, tkCompilerDirective,
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
        or ((Length(FLexerState.IfDirectiveStateArray) = SavedDirectiveLength)
        and (FLexerState.IfDirectiveStateArray[High(FLexerState.IfDirectiveStateArray)] = SavedDirectiveState))));
  until (not Result) or SameDirectiveLevel;
end;

function TPasLexer.NextTokenWithKind(ATokenKind: TTokenKind): Boolean;
begin
  repeat
    Result := NextTokenNoJunk;
  until (not Result) or (FLexerState.CurrentToken = ATokenKind);
end;

end.
