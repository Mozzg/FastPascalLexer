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
*  Created: 16.03.2025                                                         *
*  Description: Various types for pascal tokenizer/lexer TPasLexer             *
*  Version: 0.1                                                                *
*  Last modified: 16.03.2025                                                   *
*  Contributor(s):                                                             *
*    Pervov Evgeny <operationm@list.ru>                                        *
*******************************************************************************)

unit uPasLexerTypes;

interface

// +++ проверить, что для этих токенов создаются ноды в дереве
// Abort
// Break
// Continue
// Exit
// Halt
// RunError

// +++ true/false добавить. Токены нужны, т.к. потом можно проверять отдельные условия по ним, типа пишутся ли с большой буквы

type
  TTokenKind = (
    tkAbort,
    tkAbsolute,
    tkAbstract,
    tkAddressOp,
    tkAnd,
    tkArray,
    tkAs,
    tkAsciiChar,
    tkAsm,
    tkAssembler,
    tkAssign,
    tkAt,
    tkAutomated,
    tkBegin,
    tkBadString,
    tkBreak,
    tkCase,
    tkCdecl,
    tkClass,
    tkColon,
    tkComma,
    tkCompilerDirective,
    tkConst,
    tkConstructor,
    tkContains,
    tkContinue,
    tkCRLF,
    tkCRLFCo,
    tkCurlyComment,
    tkDefault,
    tkDelayed,
    tkDeprecated,
    tkDestructor,
    tkDispid,
    tkDispinterface,
    tkDiv,
    tkDo,
    tkDotDot,
    tkDoubleAddressOp,
    tkDownto,
    tkDynamic,
    tkElse,
    tkEnd,
    tkEOF,
    tkEqual,
    tkError,
    tkExcept,
    tkExit,
    tkExperimental,
    tkExport,
    tkExports,
    tkExternal,
    tkFalse,
    tkFar,
    tkFile,
    tkFinal,
    tkFinalization,
    tkFinally,
    tkFloat,
    tkFor,
    tkForward,
    tkFunction,
    tkGoto,
    tkGreater,
    tkGreaterEqual,
    tkHalt,
    tkHelper,
    tkIdentifier,
    tkIf,
    tkImplementation,
    tkImplements,
    tkIn,
    tkIndex,
    tkInherited,
    tkInitialization,
    tkInline,
    tkInteger,
    tkInterface,
    tkIs,
    tkKeyString,
    tkLabel,
    tkLibrary,
    tkLocal,
    tkLower,
    tkLowerEqual,
    tkMessage,
    tkMinus,
    tkMod,
    tkName,
    tkNear,
    tkNil,
    tkNodefault,
    tkNone,
    tkNot,
    tkNotEqual,
    tkNumber,
    tkObject,
    tkOf,
    tkOn,
    tkOperator,
    tkOr,
    tkOut,
    tkOverload,
    tkOverride,
    tkPackage,
    tkPacked,
    tkPascal,
    tkPlatform,
    tkPlus,
    tkPoint,
    tkPointerSymbol,
    tkPrivate,
    tkProcedure,
    tkProgram,
    tkProperty,
    tkProtected,
    tkPublic,
    tkPublished,
    tkRaise,
    tkRead,
    tkReadonly,
    tkRecord,
    tkReference,
    tkRegister,
    tkReintroduce,
    tkRepeat,
    tkRequires,
    tkResident,
    tkResourcestring,
    tkRoundClose,
    tkRoundOpen,
    tkRunError,
    tkSafecall,
    tkSealed,
    tkSemiColon,
    tkSet,
    tkShl,
    tkShr,
    tkSingleLineComment,
    tkSlash,
    tkSpace,
    tkSquareClose,
    tkSquareOpen,
    tkStar,
    tkStarParenComment,
    tkStatic,
    tkStdcall,
    tkStored,
    tkStrict,
    tkString,
    tkStringresource,
    tkSymbol,
    tkThen,
    tkThreadvar,
    tkTo,
    tkTrue,
    tkTry,
    tkType,
    tkUnit,
    tkUnknown,
    tkUnsafe,
    tkUntil,
    tkUses,
    tkVar,
    tkVarargs,
    tkVirtual,
    tkWhile,
    tkWinapi,
    tkWith,
    tkWrite,
    tkWriteonly,
    tkXor
  );

  TTokenKindSet = set of TTokenKind;
  TCommentState = (
    csNo,
    csCurly,
    csStarParen,
    csSingleLine
  );

  TKeywordRec = record
    Word: string;
    Token: TTokenKind;
  end;

  PPrefixTreeNode = ^TPrefixTreeNode;
  TPrefixTreeNode = record
    CurrentTokenKind: TTokenKind;
    NextCharPointers: array[0..26] of PPrefixTreeNode;
  end;

const
  PREFIX_TREE_NODE_SIZE = SizeOf(TPrefixTreeNode);

  METHOD_TOKENS: TTokenKindSet = [tkProcedure, tkFunction, tkConstructor, tkDestructor, tkOperator];

  DELPHI_KEYWORDS: array[0..128] of TKeywordRec = (
    (Word: 'and';            Token: tkAnd), // reserve words start
    (Word: 'array';          Token: tkArray),
    (Word: 'as';             Token: tkAs),
    (Word: 'asm';            Token: tkAsm),
    (Word: 'begin';          Token: tkBegin),
    (Word: 'case';           Token: tkCase),
    (Word: 'class';          Token: tkClass),
    (Word: 'const';          Token: tkConst),
    (Word: 'constructor';    Token: tkConstructor),
    (Word: 'destructor';     Token: tkDestructor),
    (Word: 'dispinterface';  Token: tkDispinterface),
    (Word: 'div';            Token: tkDiv),
    (Word: 'do';             Token: tkDo),
    (Word: 'downto';         Token: tkDownto),
    (Word: 'else';           Token: tkElse),
    (Word: 'end';            Token: tkEnd),
    (Word: 'except';         Token: tkExcept),
    (Word: 'exports';        Token: tkExports),
    (Word: 'file';           Token: tkFile),
    (Word: 'finalization';   Token: tkFinalization),
    (Word: 'finally';        Token: tkFinally),
    (Word: 'for';            Token: tkFor),
    (Word: 'function';       Token: tkFunction),
    (Word: 'goto';           Token: tkGoto),
    (Word: 'if';             Token: tkIf),
    (Word: 'implementation'; Token: tkImplementation),
    (Word: 'in';             Token: tkIn),
    (Word: 'inherited';      Token: tkInherited),
    (Word: 'initialization'; Token: tkInitialization),
    (Word: 'inline';         Token: tkInline),
    (Word: 'interface';      Token: tkInterface),
    (Word: 'is';             Token: tkIs),
    (Word: 'label';          Token: tkLabel),
    (Word: 'library';        Token: tkLibrary),
    (Word: 'mod';            Token: tkMod),
    (Word: 'nil';            Token: tkNil),
    (Word: 'not';            Token: tkNot),
    (Word: 'object';         Token: tkObject),
    (Word: 'of';             Token: tkOf),
    (Word: 'or';             Token: tkOr),
    (Word: 'packed';         Token: tkPacked),
    (Word: 'procedure';      Token: tkProcedure),
    (Word: 'program';        Token: tkProgram),
    (Word: 'property';       Token: tkProperty),
    (Word: 'raise';          Token: tkRaise),
    (Word: 'record';         Token: tkRecord),
    (Word: 'repeat';         Token: tkRepeat),
    (Word: 'resourcestring'; Token: tkResourcestring),
    (Word: 'set';            Token: tkSet),
    (Word: 'shl';            Token: tkShl),
    (Word: 'shr';            Token: tkShr),
    (Word: 'string';         Token: tkString),
    (Word: 'then';           Token: tkThen),
    (Word: 'threadvar';      Token: tkThreadvar),
    (Word: 'to';             Token: tkTo),
    (Word: 'try';            Token: tkTry),
    (Word: 'type';           Token: tkType),
    (Word: 'unit';           Token: tkUnit),
    (Word: 'until';          Token: tkUntil),
    (Word: 'uses';           Token: tkUses),
    (Word: 'var';            Token: tkVar),
    (Word: 'while';          Token: tkWhile),
    (Word: 'with';           Token: tkWith),
    (Word: 'xor';            Token: tkXor), // reserve words end
    (Word: 'absolute';       Token: tkAbsolute), // directives start
    (Word: 'abstract';       Token: tkAbstract),
    (Word: 'assembler';      Token: tkAssembler),
    (Word: 'automated';      Token: tkAutomated),
    (Word: 'cdecl';          Token: tkCdecl),
    (Word: 'contains';       Token: tkContains),
    (Word: 'default';        Token: tkDefault),
    (Word: 'delayed';        Token: tkDelayed),
    (Word: 'deprecated';     Token: tkDeprecated),
    (Word: 'dispid';         Token: tkDispid),
    (Word: 'dynamic';        Token: tkDynamic),
    (Word: 'experimental';   Token: tkExperimental),
    (Word: 'export';         Token: tkExport),
    (Word: 'external';       Token: tkExternal),
    (Word: 'far';            Token: tkFar),
    (Word: 'final';          Token: tkFinal),
    (Word: 'forward';        Token: tkForward),
    (Word: 'helper';         Token: tkHelper),
    (Word: 'implements';     Token: tkImplements),
    (Word: 'index';          Token: tkIndex),
    (Word: 'inline';         Token: tkInline),
    (Word: 'library';        Token: tkLibrary),
    (Word: 'local';          Token: tkLocal),
    (Word: 'message';        Token: tkMessage),
    (Word: 'name';           Token: tkName),
    (Word: 'near';           Token: tkNear),
    (Word: 'nodefault';      Token: tkNodefault),
    (Word: 'operator';       Token: tkOperator),
    (Word: 'out';            Token: tkOut),
    (Word: 'overload';       Token: tkOverload),
    (Word: 'override';       Token: tkOverride),
    (Word: 'package';        Token: tkPackage),
    (Word: 'pascal';         Token: tkPascal),
    (Word: 'platform';       Token: tkPlatform),
    (Word: 'private';        Token: tkPrivate),
    (Word: 'protected';      Token: tkProtected),
    (Word: 'public';         Token: tkPublic),
    (Word: 'published';      Token: tkPublished),
    (Word: 'read';           Token: tkRead),
    (Word: 'readonly';       Token: tkReadonly),
    (Word: 'reference';      Token: tkReference),
    (Word: 'register';       Token: tkRegister),
    (Word: 'reintroduce';    Token: tkReintroduce),
    (Word: 'requires';       Token: tkRequires),
    (Word: 'resident';       Token: tkResident),
    (Word: 'safecall';       Token: tkSafecall),
    (Word: 'sealed';         Token: tkSealed),
    (Word: 'static';         Token: tkStatic),
    (Word: 'stdcall';        Token: tkStdcall),
    (Word: 'strict';         Token: tkStrict),
    (Word: 'stored';         Token: tkStored),
    (Word: 'unsafe';         Token: tkUnsafe),
    (Word: 'varargs';        Token: tkVarargs),
    (Word: 'virtual';        Token: tkVirtual),
    (Word: 'winapi';         Token: tkWinapi),
    (Word: 'write';          Token: tkWrite),
    (Word: 'writeonly';      Token: tkWriteonly), // directives end
    (Word: 'abort';          Token: tkAbort), // others start
    (Word: 'break';          Token: tkBreak),
    (Word: 'continue';       Token: tkContinue),
    (Word: 'exit';           Token: tkExit),
    (Word: 'halt';           Token: tkHalt),
    (Word: 'runerror';       Token: tkRunError),
    (Word: 'true';           Token: tkTrue),
    (Word: 'false';          Token: tkFalse) // others end
  );

implementation

end.
