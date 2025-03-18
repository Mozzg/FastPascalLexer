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
  uPasLexerTypes;

type
  TRunProcedure = procedure of object;

  TPasLexerState = record
    CurrentIndex: Cardinal;
    MaxIndex: Cardinal;
    CurrentLine: Cardinal;
    CurrentLinePos: Cardinal;
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
    procedure CaretHandler;
    procedure SymbolHandler;
    procedure UnknownHandler;

    procedure FillRunProcTable;

    procedure SetLexerState(const ANewState: TPasLexerState);
  public
    constructor Create;

    procedure SetData(var ADataString: string);
    procedure Reset;
    function NextToken: Boolean;

    property LexerState: TPasLexerState read FLexerState write SetLexerState;
    property TokenID: TTokenKind read FLexerState.CurrentToken;
  end;

implementation

{ TPasLexerState }

procedure TPasLexerState.Reset;
begin
  CurrentIndex := 0;
  MaxIndex := 0;
  CurrentLine := 0;
  CurrentLinePos := 0;
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

end;

procedure TPasLexer.LFHandler;
begin

end;

procedure TPasLexer.CRHandler;
begin

end;

procedure TPasLexer.SpaceHandler;
begin

end;

procedure TPasLexer.AsciiCharHandler;
begin

end;

procedure TPasLexer.HexNumberHandler;
begin

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

end;

procedure TPasLexer.SlashHandler;
begin

end;

procedure TPasLexer.PlusHandler;
begin

end;

procedure TPasLexer.MinusHandler;
begin

end;

procedure TPasLexer.CommaHandler;
begin

end;

procedure TPasLexer.PointHandler;
begin

end;

procedure TPasLexer.ColonHandler;
begin

end;

procedure TPasLexer.SemiColonHandler;
begin

end;

procedure TPasLexer.LowerHandler;
begin

end;

procedure TPasLexer.EqualHandler;
begin

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

procedure TPasLexer.CaretHandler;
begin

end;

procedure TPasLexer.SymbolHandler;
begin

end;

procedure TPasLexer.UnknownHandler;
begin

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
          '^': FRunHandlers[Ch] := CaretHandler;
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
    FLexerState.MaxIndex := FEndPtr - FStartPtr;
end;

function TPasLexer.NextToken: Boolean;
var
  CurChar: Char;
begin
  CurChar := FStartPtr[FLexerState.CurrentIndex];
  if CurChar <= High(FRunHandlers) then  // +++ проверить, правильно ли работает условие
    FRunHandlers[CurChar]
  else
    IdentifierHandler;
end;

end.
