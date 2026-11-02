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
*  Author: Pervov Evgeny                                                       *
*  Created: 11.05.2025                                                         *
*  Description: Various types for pascal parser TPasParser                     *
*  Version: 0.2                                                                *
*  Last modified: 02.11.2026                                                   *
*  Contributor(s):                                                             *
*    Pervov Evgeny <operationm@list.ru>                                        *
*******************************************************************************)

unit uPasParserTypes;

interface

uses
  uPasLexer, uPasLexerTypes;

type
  // Kinds of the nodes of the lexeme tree built by TPasParser
  TLexemeType = (
    ltRoot, // always at top
    // Modules and their sections
    ltUnit,
    ltProgram,
    ltPackage,
    ltLibrary,
    ltInterface,
    ltImplementation,
    ltInitialization,
    ltFinalization,
    ltUses,
    ltUsesItem,
    ltRequires,
    ltContains,
    // Declaration sections and declarations
    ltLabelSection,
    ltConstSection,
    ltResourceStringSection,
    ltTypeSection,
    ltVarSection,
    ltThreadVarSection,
    ltExports,
    ltExportsItem,
    ltConstDeclaration,
    ltTypeDeclaration,
    ltVarDeclaration,
    ltFieldDeclaration,
    ltIdentifier,
    ltAttributeList,
    ltAttribute,
    ltGenericParameters,
    ltGenericArguments,
    // Routines
    ltRoutine,
    ltRoutineHeading,
    ltFormalParameters,
    ltParameter,
    ltRoutineDirective,
    // Types
    ltTypeIdentifier,
    ltSubrangeType,
    ltEnumType,
    ltEnumElement,
    ltSetType,
    ltArrayType,
    ltFileType,
    ltPointerType,
    ltProceduralType,
    ltClassType,
    ltClassReferenceType,
    ltRecordType,
    ltObjectType,
    ltInterfaceType,
    ltVisibilitySection,
    ltProperty,
    ltInterfaceGuid,
    ltVariantPart,
    ltVariant,
    // Statements
    ltBeginEnd,
    ltAssignment,
    ltCallStatement,
    ltLabeledStatement,
    ltGotoStatement,
    ltIfStatement,
    ltCaseStatement,
    ltCaseItem,
    ltElseBlock,
    ltRepeatStatement,
    ltWhileStatement,
    ltForStatement,
    ltForInStatement,
    ltWithStatement,
    ltTryStatement,
    ltExceptBlock,
    ltExceptionHandler,
    ltFinallyBlock,
    ltRaiseStatement,
    ltAsmStatement,
    ltInlineVarDeclaration,
    ltInlineConstDeclaration,
    // Expressions
    ltBinaryExpression,
    ltUnaryExpression,
    ltParenthesizedExpression,
    ltDesignator,
    ltLiteral,
    ltSetConstructor,
    ltRange,
    ltArgumentList,
    ltIndexList,
    ltAnonymousMethod,
    ltInheritedExpression,
    ltArrayConstant,
    ltRecordConstant,
    ltRecordConstantField
  );

  TLexemeTypeSet = set of TLexemeType;

  TParserErrorSeverity = (
    pesHint,
    pesWarning,
    pesError
  );

  TParseErrorItem = record
    LineNumber: Integer;
    LinePosition: Integer;
    ErrorSeverity: TParserErrorSeverity;
    Message: string;
  end;

  // A token of the source as TPasParser keeps it. The lexer fills the position and the kind, the parser fills the layout
  // fields, which are computed from the full source text, so that code style checks see the real spacing even around
  // the removed compiler directives.
  TPasLexerMinimalState = record
    // Offset of the first character of the token in the source string, 0-based
    CurrentIndex: Cardinal;
    // Line of the first character of the token, 1-based
    CurrentLine: Cardinal;
    // Offset of the first character of the line in the source string, 0-based
    CurrentLineStartPos: Cardinal;
    CurrentToken: TTokenKind;
    TokenString: string;
    // Index of the token in TPasParser.SourceTokenItem
    SourceTokenIndex: Integer;
    // Count of the whitespace characters right before the token; for the first token on a line it is the indentation
    SpaceBefore: Integer;
    // Count of the whitespace characters right after the token, 0 before a line break
    SpaceAfter: Integer;
    // No token except whitespace precedes the token on its line
    IsFirstOnLine: Boolean;
    // No token except whitespace and the line break follows the token on its line
    IsLastOnLine: Boolean;

    procedure FillFromLexer(const ALexer: TPasLexer);
    function GetColumn: Integer;
    function GetTokenLength: Integer;

    // Column of the first character of the token, 1-based; a tab counts as one character
    property Column: Integer read GetColumn;
    // Length of the token text in characters
    property TokenLength: Integer read GetTokenLength;
  end;

  PPasLexerMinimalState = ^TPasLexerMinimalState;
  TLexerStateArray = TArray<TPasLexerMinimalState>;
  PLexerStateArray = ^TLexerStateArray;

  // A line of the source text
  TPasLineInfo = record
    // Offset of the first character of the line in the source string, 0-based
    StartPos: Integer;
    // Length of the line without the line break
    LineLength: Integer;
    // Count of the leading whitespace characters
    Indent: Integer;
    // Index of the first source token that starts on the line, -1 if none (a line inside a multi-line directive)
    FirstTokenIndex: Integer;
    // The line contains only whitespace
    IsBlank: Boolean;
  end;

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
    'ltUsesItem',
    'ltRequires',
    'ltContains',
    'ltLabelSection',
    'ltConstSection',
    'ltResourceStringSection',
    'ltTypeSection',
    'ltVarSection',
    'ltThreadVarSection',
    'ltExports',
    'ltExportsItem',
    'ltConstDeclaration',
    'ltTypeDeclaration',
    'ltVarDeclaration',
    'ltFieldDeclaration',
    'ltIdentifier',
    'ltAttributeList',
    'ltAttribute',
    'ltGenericParameters',
    'ltGenericArguments',
    'ltRoutine',
    'ltRoutineHeading',
    'ltFormalParameters',
    'ltParameter',
    'ltRoutineDirective',
    'ltTypeIdentifier',
    'ltSubrangeType',
    'ltEnumType',
    'ltEnumElement',
    'ltSetType',
    'ltArrayType',
    'ltFileType',
    'ltPointerType',
    'ltProceduralType',
    'ltClassType',
    'ltClassReferenceType',
    'ltRecordType',
    'ltObjectType',
    'ltInterfaceType',
    'ltVisibilitySection',
    'ltProperty',
    'ltInterfaceGuid',
    'ltVariantPart',
    'ltVariant',
    'ltBeginEnd',
    'ltAssignment',
    'ltCallStatement',
    'ltLabeledStatement',
    'ltGotoStatement',
    'ltIfStatement',
    'ltCaseStatement',
    'ltCaseItem',
    'ltElseBlock',
    'ltRepeatStatement',
    'ltWhileStatement',
    'ltForStatement',
    'ltForInStatement',
    'ltWithStatement',
    'ltTryStatement',
    'ltExceptBlock',
    'ltExceptionHandler',
    'ltFinallyBlock',
    'ltRaiseStatement',
    'ltAsmStatement',
    'ltInlineVarDeclaration',
    'ltInlineConstDeclaration',
    'ltBinaryExpression',
    'ltUnaryExpression',
    'ltParenthesizedExpression',
    'ltDesignator',
    'ltLiteral',
    'ltSetConstructor',
    'ltRange',
    'ltArgumentList',
    'ltIndexList',
    'ltAnonymousMethod',
    'ltInheritedExpression',
    'ltArrayConstant',
    'ltRecordConstant',
    'ltRecordConstantField'
  );

  // Node kinds grouped for code style checks
  MODULE_LEXEMES: TLexemeTypeSet = [ltUnit, ltProgram, ltPackage, ltLibrary];
  DECLARATION_SECTION_LEXEMES: TLexemeTypeSet = [ltLabelSection, ltConstSection, ltResourceStringSection, ltTypeSection,
      ltVarSection, ltThreadVarSection, ltExports];
  TYPE_LEXEMES: TLexemeTypeSet = [ltTypeIdentifier, ltSubrangeType, ltEnumType, ltSetType, ltArrayType, ltFileType,
      ltPointerType, ltProceduralType, ltClassType, ltClassReferenceType, ltRecordType, ltObjectType, ltInterfaceType];
  STRUCTURED_TYPE_LEXEMES: TLexemeTypeSet = [ltClassType, ltRecordType, ltObjectType, ltInterfaceType];
  STATEMENT_LEXEMES: TLexemeTypeSet = [ltBeginEnd, ltAssignment, ltCallStatement, ltLabeledStatement, ltGotoStatement,
      ltIfStatement, ltCaseStatement, ltRepeatStatement, ltWhileStatement, ltForStatement, ltForInStatement,
      ltWithStatement, ltTryStatement, ltRaiseStatement, ltAsmStatement, ltInlineVarDeclaration, ltInlineConstDeclaration];
  EXPRESSION_LEXEMES: TLexemeTypeSet = [ltBinaryExpression, ltUnaryExpression, ltParenthesizedExpression, ltDesignator,
      ltLiteral, ltSetConstructor, ltRange, ltAnonymousMethod, ltInheritedExpression, ltArrayConstant, ltRecordConstant];

implementation

{ TPasLexerMinimalState }

procedure TPasLexerMinimalState.FillFromLexer(const ALexer: TPasLexer);
begin
  CurrentIndex := ALexer.LexerState.CurrentTokenPos;
  CurrentLine := ALexer.LexerState.CurrentLine;
  CurrentLineStartPos := ALexer.LexerState.CurrentLineStartPos;
  CurrentToken := ALexer.LexerState.CurrentToken;
  TokenString := ALexer.TokenString;
  SourceTokenIndex := -1;
  SpaceBefore := 0;
  SpaceAfter := 0;
  IsFirstOnLine := False;
  IsLastOnLine := False;
end;

function TPasLexerMinimalState.GetColumn: Integer;
begin
  Result := Integer(CurrentIndex - CurrentLineStartPos) + 1;
end;

function TPasLexerMinimalState.GetTokenLength: Integer;
begin
  Result := Length(TokenString);
end;

end.
