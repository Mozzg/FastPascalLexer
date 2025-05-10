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
*  Created: 10.05.2025                                                         *
*  Description: Exceptons for TPasLexer and TPasParser classes                 *
*  Version: 0.1                                                                *
*  Last modified: 10.05.2025                                                   *
*  Contributor(s):                                                             *
*    Pervov Evgeny <operationm@list.ru>                                        *
*******************************************************************************)

unit uPasExceptions;

interface

uses
  System.SysUtils,
  uPasLexer, uPasLexerTypes, uPasParser;

type
  EPasBaseException = class(Exception);

  EPasLexerException = class(EPasBaseException)
  private
    FLineNumber: Cardinal;
    FLineCharIndex: Cardinal;
    FCurrentToken: TTokenKind;
  public
    constructor Create(const AMessage: string; ALexer: TPasLexer = nil);
    constructor CreateFmt(const Msg: string; const Args: array of const; ALexer: TPasLexer = nil);

    property LineNumber: Cardinal read FLineNumber;
    property LineCharIndex: Cardinal read FLineCharIndex;
    property CurrentToken: TTokenKind read FCurrentToken;
  end;

  EPasParserException = class(EPasBaseException)
  public
    constructor Create(const AMessage: string; ALexer: TPasParser = nil);
  end;

resourcestring
  EMESSAGE_TIMER_NOT_AVAILABLE = 'Error creating %s, high resolution timer is not available';
  EMESSAGE_TIMER_NOT_INITIALIZED = 'Error, high precision timer was not initialized';
  EMESSAGE_TIMER_WAIT_FAILED = 'Error, failed wait for waitable timer';

  EMESSAGE_UNEXPECTED_ELSE_DIRECTIVE = 'Unexpected ELSE or ELSEIF compiler directive';
  EMESSAGE_DIRECTIVE_STATE_COUNTER_MISMATCH = 'Directive states and counters arrays mismatch';
  EMESSAGE_DIRECTIVE_COUNTERS_MISMATCH_ELSE = 'Lexer counters mismatch at ELSE or ELSEIF directive';
  EMESSAGE_DIRECTIVE_COUNTERS_NOTFOUND_ON_RESTORE = 'Could not find saved counters data to restore at ELSE or ELSEIF directive';

implementation

{ EPasLexerException }

constructor EPasLexerException.Create(const AMessage: string; ALexer: TPasLexer = nil);
begin
  if not Assigned(ALexer) then
    FCurrentToken := tkUnknown
  else
  begin
    FLineNumber := ALexer.LexerState.CurrentLine;
    FLineCharIndex := ALexer.LexerState.CurrentTokenPos - ALexer.LexerState.CurrentLineStartPos + 1;
    FCurrentToken := ALexer.LexerState.CurrentToken;
  end;

  inherited Create(AMessage);
end;

constructor EPasLexerException.CreateFmt(const Msg: string; const Args: array of const; ALexer: TPasLexer = nil);
begin
  Create(Format(Msg, Args), ALexer);
end;

{ EPasParserException }

constructor EPasParserException.Create(const AMessage: string; ALexer: TPasParser = nil);
begin

end;

end.
