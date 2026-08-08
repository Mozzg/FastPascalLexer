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
*  Author: Pervov Evgeny                                                       *
*  Created: 11.05.2025                                                         *
*  Description: Various types for pascal parser TPasParser                     *
*  Version: 0.1                                                                *
*  Last modified: 11.05.2025                                                   *
*  Contributor(s):                                                             *
*    Pervov Evgeny <operationm@list.ru>                                        *
*******************************************************************************)

unit uPasParserTypes;

interface

uses
  uPasLexer, uPasLexerTypes;

type
  TLexemeType = (
    ltRoot, // always at top
    ltUnit,
    ltProgram,
    ltPackage,
    ltLibrary,
    ltInterface,
    ltImplementation,
    ltInitialization,
    ltFinalization,
    ltUses,
    ltBeginEnd,
    ltConstSection,
    ltTypeSection,
    ltVarSection,
    ltConstDeclaration,
    ltIdentifier,
    ltTypeIdentifier,
    ltConstValue
  );

  TParserErrorSeverity = (
    pesHint,
    pesWarning,
    pesError
  );

  TParseErrorItem = record
    LineNumber: Integer;
    LinePosition: Integer;
    ErrorSeverity: TParserErrorSeverity;
  end;

  TPasLexerMinimalState = record
    CurrentIndex: Cardinal;
    CurrentLine: Cardinal;
    CurrentLineStartPos: Cardinal;
    CurrentToken: TTokenKind;
    TokenString: string;

    procedure FillFromLexer(const ALexer: TPasLexer);
  end;

  TLexerStateArray = TArray<TPasLexerMinimalState>;
  PLexerStateArray = ^TLexerStateArray;

const
  LEXEME_NAMES: array[TLexemeType] of string = (
    'ltRoot',
    'ltUnit',
    'ltProgram',
    'ltPackage',
    'ltLibrary',
    'ltInterface',
    'ltImplementation',
    'ltInitialization',
    'ltFinalization',
    'ltUses',
    'ltBeginEnd',
    'ltConstSection',
    'ltTypeSection',
    'ltVarSection',
    'ltConstDeclaration',
    'ltIdentifier',
    'ltTypeIdentifier',
    'ltConstValue'
  );

implementation

{ TPasLexerMinimalState }

procedure TPasLexerMinimalState.FillFromLexer(const ALexer: TPasLexer);
begin
  CurrentIndex := ALexer.LexerState.CurrentTokenPos;
  CurrentLine := ALexer.LexerState.CurrentLine;
  CurrentLineStartPos := ALexer.LexerState.CurrentLineStartPos;
  CurrentToken := ALexer.LexerState.CurrentToken;
  TokenString := ALexer.TokenString;
end;

end.
