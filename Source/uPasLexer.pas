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
*  Version: 0.1                                                                *
*  Last modified: 16.03.2025                                                   *
*  Contributor(s):                                                             *
*    Pervov Evgeny <operationm@list.ru>                                        *
*******************************************************************************)

unit uPasLexer;

interface

uses
  System.SysUtils,
  uPasLexerTypes;

type
  TRunProcedure = procedure of object;

  TPasLexerState = record
    CurrentIndex: Cardinal;
    MaxIndex: Cardinal;
    CurrentLine: Cardinal;
    CurrentLineStartPos: Cardinal;
    CurrentToken: TTokenKind;
    CurrentTokenPos: Cardinal;
    CommentState: TCommentState;
    RoundCount: Integer;
    SquareCount: Integer;
    BeginEndCount: Integer;
    IsProperty: Boolean;

    procedure Reset;
  end;

  TPasLexer = class(TObject)
  private
    FStartPtr: PChar;
    FEndPtr: PChar;
    FLexerState: TPasLexerState;
    FRunHandlers: array[#0..#127] of TRunProcedure;

    // Handlers
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
    procedure CurlyCloseHandler;
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

    procedure FillRunProcTable;

    procedure SetLexerState(const ANewState: TPasLexerState);
    function GetCurrentToken: string;
  public
    constructor Create;

    procedure SetData(var ADataString: string);
    procedure Reset;
    function NextToken: Boolean;

    property LexerState: TPasLexerState read FLexerState write SetLexerState;
    property TokenID: TTokenKind read FLexerState.CurrentToken;
    property TokenString: string read GetCurrentToken;
  end;

implementation

{ TPasLexerState }

procedure TPasLexerState.Reset;
begin
  CurrentIndex := 0;
  MaxIndex := 0;
  CurrentLine := 0;
  CurrentLineStartPos := 0;
  CurrentToken := tkUnknown;
  CurrentTokenPos := 0;
  CommentState := csNo;
  RoundCount := 0;
  SquareCount := 0;
  BeginEndCount := 0;
  IsProperty := False;
end;

{ TPasLexer }

constructor TPasLexer.Create;
begin
  inherited Create;

  Reset;
  FillRunProcTable;
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

end;

procedure TPasLexer.NumberHandler;
begin

end;

procedure TPasLexer.IdentifierHandler;
begin

end;

procedure TPasLexer.CurlyOpenHandler;
begin
  if FStartPtr[FLexerState.CurrentIndex + 1] = '$' then
    FLexerState.CurrentToken := tkCompilerDirective
  else
  begin
    FLexerState.CurrentToken := tkCurlyComment;
    FLexerState.CommentState := csCurly;
  end;

  Inc(FLexerState.CurrentIndex);

  while FLexerState.CurrentIndex < FLexerState.MaxIndex do
    case FStartPtr[FLexerState.CurrentIndex] of
      '}':
      begin
        FLexerState.CommentState := csNo;
        Inc(FLexerState.CurrentIndex);
        Break;
      end;
      #10, #13:
        Break;
    else
      Inc(FLexerState.CurrentIndex);
    end;
end;

procedure TPasLexer.CurlyCloseHandler;
begin

end;

procedure TPasLexer.RoundOpenHandler;
begin

end;

procedure TPasLexer.RoundCloseHandler;
begin

end;

procedure TPasLexer.StarHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkStar;
end;

procedure TPasLexer.SlashHandler;
begin

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

end;

procedure TPasLexer.ColonHandler;
begin

end;

procedure TPasLexer.SemiColonHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkSemiColon;
end;

procedure TPasLexer.LowerHandler;
begin

end;

procedure TPasLexer.EqualHandler;
begin
  Inc(FLexerState.CurrentIndex);
  FLexerState.CurrentToken := tkEqual;
end;

procedure TPasLexer.GreaterHandler;
begin

end;

procedure TPasLexer.AddressSymbolHandler;
begin

end;

procedure TPasLexer.SquareOpenHandler;
begin

end;

procedure TPasLexer.SquareCloseHandler;
begin

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
      #1..#9, #11, #12, #14..#32:
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
        FRunHandlers[Ch] := CurlyCloseHandler;
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

procedure TPasLexer.SetLexerState(const ANewState: TPasLexerState);
begin
  Move(ANewState, FLexerState, SizeOf(TPasLexerState));
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
  if FStartPtr <> @ADataString[1] then
  begin
    FStartPtr := @ADataString[1];
    FEndPtr := FStartPtr + Length(ADataString);
    Reset;
  end;
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
  FLexerState.CurrentTokenPos := FLexerState.CurrentIndex;
  // +++ comment state
  CurChar := FStartPtr[FLexerState.CurrentIndex];
  if CurChar <= High(FRunHandlers) then  // +++ проверить, правильно ли работает условие
    FRunHandlers[CurChar]
  else
    IdentifierHandler;

  Result := FLexerState.CurrentToken <> tkEOF;
end;

end.
