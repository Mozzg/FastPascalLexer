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
*  Created: 08.08.2026                                                         *
*  Classes: TLexemeCursor, TBaseLexemeNode and the lexeme nodes                *
*  Description: Delphi language grammar for pascal parser TPasParser           *
*  Version: 0.1                                                                *
*  Last modified: 02.11.2026                                                   *
*  Contributor(s):                                                             *
*    Pervov Evgeny <operationm@list.ru>                                        *
*******************************************************************************)

unit uPasParserGrammar;

{
  Grammar of the Delphi language for TPasParser.

  The parser builds a tree of lexeme nodes. Every node covers a continuous range of the parsed states (tokens) of
  TPasParser: from its first to its last significant token, including the whitespace and the comments between them.
  The significant tokens of a node that are not covered by its children are its own tokens: keywords, operators and
  punctuation (GetOwnTokenIndexes, FindOwnToken). Together with the layout fields of the tokens (Column, SpaceBefore,
  SpaceAfter, IsFirstOnLine, IsLastOnLine) and the node level this gives code style checks all they need to check
  spacing and indentation.

  Parsing is a recursive descent. A node is created at the current position of the cursor shared by the whole tree,
  parses itself in InternalParseItself (creating its children the same way) and leaves the cursor at the first
  significant token after itself. A syntax error raises EPasGrammarParserException.
}

interface

uses
  System.SysUtils,
  uPasParserTypes, uPasLexerTypes;

const
  // Reserved words: they can not be used as identifiers unless escaped with '&'
  RESERVED_WORD_TOKENS = [tkAnd, tkArray, tkAs, tkAsm, tkBegin, tkCase, tkClass, tkConst, tkConstructor, tkDestructor,
      tkDispinterface, tkDiv, tkDo, tkDownto, tkElse, tkEnd, tkExcept, tkExports, tkFile, tkFinalization, tkFinally,
      tkFor, tkFunction, tkGoto, tkIf, tkImplementation, tkIn, tkInherited, tkInitialization, tkInline, tkInterface,
      tkIs, tkLabel, tkLibrary, tkMod, tkNil, tkNot, tkObject, tkOf, tkOr, tkPacked, tkProcedure, tkProgram,
      tkProperty, tkRaise, tkRecord, tkRepeat, tkResourcestring, tkSet, tkShl, tkShr, tkString, tkThen, tkThreadvar,
      tkTo, tkTry, tkType, tkUnit, tkUntil, tkUses, tkVar, tkWhile, tkWith, tkXor];
  // Tokens that are identifiers for the parser: directives and the other words that are not reserved can be names
  IDENTIFIER_TOKENS = [tkIdentifier, tkAbsolute, tkAbstract, tkAssembler, tkAutomated, tkCdecl, tkContains, tkDefault,
      tkDelayed, tkDeprecated, tkDispid, tkDynamic, tkExperimental, tkExport, tkExternal, tkFar, tkFinal, tkForward,
      tkHelper, tkImplements, tkIndex, tkLocal, tkMessage, tkName, tkNear, tkNodefault, tkOperator, tkOut, tkOverload,
      tkOverride, tkPackage, tkPascal, tkPlatform, tkPrivate, tkProtected, tkPublic, tkPublished, tkRead, tkReadonly,
      tkReference, tkRegister, tkReintroduce, tkRequires, tkResident, tkSafecall, tkSealed, tkStatic, tkStdcall,
      tkStrict, tkStored, tkUnsafe, tkVarargs, tkVirtual, tkWinapi, tkWrite, tkWriteonly, tkAbort, tkBreak,
      tkContinue, tkExit, tkHalt, tkRunError, tkTrue, tkFalse, tkOn, tkAt, tkIfDefDirective, tkIfNDefDirective,
      tkIfOptDirective, tkElseIfDirective, tkEndIfDirective, tkIfEndDirective];
  // Tokens that are words: allowed after '&' and as member names after a point
  WORD_TOKENS = RESERVED_WORD_TOKENS + IDENTIFIER_TOKENS;
  VISIBILITY_TOKENS = [tkPrivate, tkProtected, tkPublic, tkPublished, tkAutomated];
  // Directives of procedures and functions
  ROUTINE_DIRECTIVE_TOKENS = [tkAbstract, tkAssembler, tkCdecl, tkDelayed, tkDeprecated, tkDispid, tkDynamic,
      tkExperimental, tkExport, tkExternal, tkFar, tkFinal, tkForward, tkInline, tkLibrary, tkLocal, tkMessage, tkNear,
      tkOverload, tkOverride, tkPascal, tkPlatform, tkRegister, tkReintroduce, tkSafecall, tkStatic, tkStdcall,
      tkUnsafe, tkVarargs, tkVirtual, tkWinapi];
  // Directives of procedural types
  PROCEDURAL_DIRECTIVE_TOKENS = [tkCdecl, tkPascal, tkRegister, tkSafecall, tkStdcall, tkWinapi, tkVarargs];
  PORTABILITY_DIRECTIVE_TOKENS = [tkDeprecated, tkPlatform, tkExperimental, tkLibrary];
  RELATIONAL_OPERATOR_TOKENS = [tkEqual, tkNotEqual, tkLower, tkGreater, tkLowerEqual, tkGreaterEqual, tkIn, tkIs];
  ADDITIVE_OPERATOR_TOKENS = [tkPlus, tkMinus, tkOr, tkXor];
  MULTIPLICATIVE_OPERATOR_TOKENS = [tkStar, tkSlash, tkDiv, tkMod, tkAnd, tkShl, tkShr, tkAs];
  BINARY_OPERATOR_TOKENS = RELATIONAL_OPERATOR_TOKENS + ADDITIVE_OPERATOR_TOKENS + MULTIPLICATIVE_OPERATOR_TOKENS;
  UNARY_OPERATOR_TOKENS = [tkNot, tkMinus, tkPlus, tkAddressSymbol];

type
  TBaseLexemeNode = class;
  TBaseLexemeNodeClass = class of TBaseLexemeNode;
  TIdentifierLexemeNode = class;

  // Binding strength of the binary operators, from the weakest to the strongest
  TExpressionPrecedence = (epRelational, epAdditive, epMultiplicative);

  // Kind of the structured type whose members are parsed
  TStructureKind = (skClass, skRecord, skObject, skInterface);

  // Place of the declarations: it defines which declaration sections are allowed
  TDeclarationContext = (dcInterface, dcImplementation, dcLocal);

  // Cursor over the significant tokens (not whitespace and not comments) of the parsed states. One cursor is shared by
  // all nodes of a lexeme tree.
  TLexemeCursor = class(TObject)
  private
    FStates: PLexerStateArray;
    FStatesCount: Integer;
    // Indexes of the significant tokens in the parsed states
    FSignificantIndexes: TArray<Integer>;
    FSignificantCount: Integer;
    // Current position in FSignificantIndexes, FSignificantCount at the end of data
    FPosition: Integer;
    // Index in the parsed states of the last significant token passed by MoveNext, -1 before the first one
    FLastStateIndex: Integer;
  public
    constructor Create(AStates: PLexerStateArray; AStatesCount: Integer);

    // Index in the parsed states of the significant token AOffset positions after the current one; StatesCount
    // beyond the end of data
    function GetStateIndex(AOffset: Integer = 0): Integer;
    // Kind of the significant token AOffset positions after the current one; tkEOF beyond the end of data
    function GetToken(AOffset: Integer = 0): TTokenKind;
    // Text of the significant token AOffset positions after the current one; empty beyond the end of data
    function GetTokenString(AOffset: Integer = 0): string;
    procedure MoveNext;

    property States: PLexerStateArray read FStates;
    property StatesCount: Integer read FStatesCount;
    property LastStateIndex: Integer read FLastStateIndex;
  end;

  // Base class of the lexeme tree nodes. The protected part is the parsing toolkit used by the descendants: token
  // access, lookahead and the parsing of the grammar parts shared by several nodes.
  TBaseLexemeNode = class abstract(TObject)
  private
    // Spelling of the keyword tokens, used to recognize the words that the lexer returns as identifiers
    class var FTokenWords: array[TTokenKind] of string;
  private
    FParentNode: TBaseLexemeNode;
    FCursor: TLexemeCursor;
    FStartIndex: Integer;
    FCount: Integer;
    FChildNodes: TArray<TBaseLexemeNode>;
    FChildCount: Integer;
    FParentChildIndex: Integer;

    function GetChildNode(AIndex: Integer): TBaseLexemeNode;
    function GetLevel: Integer;
    function GetStatesEndIndex: Integer;
    function GetFirstState: TPasLexerMinimalState;
    function GetLastState: TPasLexerMinimalState;
    // Index of the state to report a syntax error at: the current token, or the last one at the end of data
    function GetErrorStateIndex: Integer;
    // True when the parentheses at the current token hold an array constant and not an expression: (1, 2, 3)
    function IsArrayConstantAhead: Boolean;
  protected
    // Node adds itself to parent childs. Method will be called in node constructor for parent node.
    function AddChildNode(ANode: TBaseLexemeNode): Integer;
    procedure RemoveChildNode(ANode: TBaseLexemeNode);

    function GetNextChildNodeForIndex(AFromIndex: Integer): TBaseLexemeNode;
    function GetPrevChildNodeForIndex(AFromIndex: Integer): TBaseLexemeNode;

    procedure InternalParseItself; virtual; abstract;
    procedure FinalizeNodeEnd; virtual;

    function GetFirstChild: TBaseLexemeNode;
    function GetLastChild: TBaseLexemeNode;
    function GetNextTraversal: TBaseLexemeNode;
    function GetPrevTraversal: TBaseLexemeNode;
    function GetNextSibling: TBaseLexemeNode;
    function GetPrevSibling: TBaseLexemeNode;
    function GetStatesCurrentIndexLineNumber: Integer;
    function GetStatesCurrentIndexLineCharIndex: Integer;
    function GetStatesCurrentIndexToken: TTokenKind;
    function GetStatesCurrentTokenString: string;

    function GetNodeType: TLexemeType; virtual; abstract;
    // Text added to the lexeme log after the common part, like the name of a declaration
    function GetLexemeDetails: string; virtual;

    // Kind of the significant token AOffset positions after the current one
    function PeekToken(AOffset: Integer = 0): TTokenKind;
    function PeekTokenString(AOffset: Integer = 0): string;
    // True when the token at AOffset is AToken or an identifier spelled as the word of AToken: the lexer recognizes
    // some directives (read, write, default...) only in their context
    function IsWord(AToken: TTokenKind; AOffset: Integer = 0): Boolean;
    // Same as IsWord for any of ATokens
    function IsWordIn(ATokens: TTokenKindSet; AOffset: Integer = 0): Boolean;
    // True when the token at AOffset is an identifier spelled as AWord (for the words unknown to the lexer: on, at)
    function IsText(const AWord: string; AOffset: Integer = 0): Boolean;
    // tkString is both a string literal and the keyword string: True for a literal
    function IsStringLiteral(AOffset: Integer = 0): Boolean;
    function IsWordToken(AOffset: Integer = 0): Boolean;
    // True when a number escaped with '&' starts at the current token (&17 is the decimal 17): the lexer returns '&' as
    // a symbol
    function IsEscapedNumberAhead: Boolean;
    // True when an identifier starts at AOffset, also a keyword escaped by '&'
    function IsIdentifier(AOffset: Integer = 0): Boolean;
    // Offset of the token that follows the identifier starting at AOffset
    function GetIdentifierEndOffset(AOffset: Integer = 0): Integer;
    // Offset of the token that follows the bracket group opened at AOffset, -1 when the group is not closed
    function SkipBracketsOffset(AOffset: Integer): Integer;
    // Offset of the token that follows the attribute lists starting at AOffset, AOffset when there are none
    function SkipAttributesOffset(AOffset: Integer = 0): Integer;
    // True when a declaration starts at the current token: optional attributes, an identifier and one of AFollowTokens
    function IsDeclarationAhead(AFollowTokens: TTokenKindSet): Boolean;
    // True when the type that starts at the current token is a subrange: 0..9, Low(Byte)..High(Byte)
    function IsSubrangeAhead: Boolean;
    // True when '<' at the current token opens generic arguments and not a comparison: TList<Integer>.Create
    function IsGenericArgumentsAhead: Boolean;
    function IsVisibilityAhead: Boolean;
    // True when one of ADirectives at AOffset is a directive and not a name, like in Message: string
    function IsDirectiveAhead(ADirectives: TTokenKindSet; AOffset: Integer = 0): Boolean;

    procedure NextToken;
    // Moves to the next token when the current one is AToken
    function AcceptToken(AToken: TTokenKind): Boolean;
    procedure ExpectToken(AToken: TTokenKind);
    // Reads an identifier, with AAllowKeywords also a keyword, and returns its text without the escaping '&'
    function ExpectIdentifier(AAllowKeywords: Boolean = False): string;
    // Creates the exception about an unexpected token at the current position; AExpected describes what was expected
    function CreateUnexpectedError(const AExpected: string): Exception;

    // Creates a child node of ANodeClass at the current position and parses it
    function ParseChild(ANodeClass: TBaseLexemeNodeClass): TBaseLexemeNode;
    function ParseIdentifier(AQualified: Boolean; AAllowKeywords: Boolean = False): TIdentifierLexemeNode;
    // Parses an expression with the binary operators of APrecedence and stronger ones
    function ParseExpression(APrecedence: TExpressionPrecedence = epRelational): TBaseLexemeNode;
    // Parses an operand of a binary operator: unary operation, literal, designator, set constructor...
    function ParseFactor: TBaseLexemeNode;
    // Parses an expression or a range of two expressions: case labels and set elements
    function ParseExpressionOrRange: TBaseLexemeNode;
    // Parses the value of a typed constant: an expression, an array constant or a record constant
    function ParseTypedConstant: TBaseLexemeNode;
    function ParseType: TBaseLexemeNode;
    // Parses a statement; returns nil for an empty statement
    function ParseStatement: TBaseLexemeNode;
    // Parses statements separated by semicolons up to one of ATerminators, which is not consumed
    procedure ParseStatementList(ATerminators: TTokenKindSet);
    procedure ParseAttributes;
    procedure ParsePortabilityDirectives;
    // Parses declaration sections and routines allowed in AContext while they follow
    procedure ParseDeclarations(AContext: TDeclarationContext);
    // Parses one member of a structured type: field, method, property, nested section; False if no member follows
    function ParseStructureMember(AStructureKind: TStructureKind): Boolean;
    // Parses the main block of a program, library or unit, which ends with "end."
    procedure ParseMainBlock;
    procedure ParseModuleEnd;
  public
    class constructor ClassCreate;

    constructor Create(AParent: TBaseLexemeNode); virtual;
    destructor Destroy; override;

    // Creates the node around AFirstChild, the last child of its parent: the node takes the place of AFirstChild in the
    // parent and AFirstChild becomes the first child of the node. Used for the nodes recognized after their first
    // part, like binary expressions.
    class function CreateWrapping(AFirstChild: TBaseLexemeNode): TBaseLexemeNode;

    procedure ParseItself; virtual;
    function GetLexemeLog: string; virtual;
    // Indexes in the parsed states of the significant tokens of the node not covered by its children
    function GetOwnTokenIndexes: TArray<Integer>;
    // Index in the parsed states of the first own token of AToken kind, -1 if there is none
    function FindOwnToken(AToken: TTokenKind): Integer;

    property ParentNode: TBaseLexemeNode read FParentNode;
    property ChildCount: Integer read FChildCount;
    property Children[AIndex: Integer]: TBaseLexemeNode read GetChildNode;
    property FirstChild: TBaseLexemeNode read GetFirstChild;
    property LastChild: TBaseLexemeNode read GetLastChild;
    property NextTraversal: TBaseLexemeNode read GetNextTraversal;
    property PrevTraversal: TBaseLexemeNode read GetPrevTraversal;
    property NextSibling: TBaseLexemeNode read GetNextSibling;
    property PrevSibling: TBaseLexemeNode read GetPrevSibling;
    property NodeType: TLexemeType read GetNodeType;
    // Depth of the node in the tree, 0 for the root
    property Level: Integer read GetLevel;

    // Range of the node in the parsed states: from its first to its last significant token
    property StatesStartIndex: Integer read FStartIndex;
    property StatesCount: Integer read FCount;
    property StatesEndIndex: Integer read GetStatesEndIndex;
    property FirstState: TPasLexerMinimalState read GetFirstState;
    property LastState: TPasLexerMinimalState read GetLastState;
    // Current token of the parsing, used for the position of the syntax errors
    property StatesCurrentIndexLineNumber: Integer read GetStatesCurrentIndexLineNumber;
    property StatesCurrentIndexLineCharIndex: Integer read GetStatesCurrentIndexLineCharIndex;
    property StatesCurrentIndexToken: TTokenKind read GetStatesCurrentIndexToken;
    property StatesCurrentTokenString: string read GetStatesCurrentTokenString;
  end;

  { Common parts }

  // Identifier, or a qualified identifier of a unit: System.SysUtils
  TIdentifierLexemeNode = class(TBaseLexemeNode)
  private
    FName: string;
    FIsQualified: Boolean;
    FAllowKeywords: Boolean;
  protected
    function GetNodeType: TLexemeType; override;
    function GetLexemeDetails: string; override;
    procedure InternalParseItself; override;
  public
    // Name without the escaping '&', the parts of a qualified name are separated by points
    property Name: string read FName;
  end;

  // Attributes in brackets: [Weak], [TestCase('A', '1')]
  TAttributeListLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TAttributeLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Parameters of a generic type or method declaration: <T: class, constructor; K>
  TGenericParametersLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Arguments of a generic type or method: <Integer, string>
  TGenericArgumentsLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  { Expressions }

  TBinaryExpressionLexemeNode = class(TBaseLexemeNode)
  private
    FPrecedence: TExpressionPrecedence;
    FOperatorToken: TTokenKind;
    FOperatorIndex: Integer;
  protected
    function GetNodeType: TLexemeType; override;
    function GetLexemeDetails: string; override;
    procedure InternalParseItself; override;
  public
    property OperatorToken: TTokenKind read FOperatorToken;
    // Index of the operator in the parsed states
    property OperatorIndex: Integer read FOperatorIndex;
  end;

  // Operation with one operand: not, -, +, @
  TUnaryExpressionLexemeNode = class(TBaseLexemeNode)
  private
    FOperatorToken: TTokenKind;
    FOperatorIndex: Integer;
  protected
    function GetNodeType: TLexemeType; override;
    function GetLexemeDetails: string; override;
    procedure InternalParseItself; override;
  public
    property OperatorToken: TTokenKind read FOperatorToken;
    // Index of the operator in the parsed states
    property OperatorIndex: Integer read FOperatorIndex;
  end;

  TParenthesizedExpressionLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Reference to a variable, a constant, a routine or a type with the selectors: Foo.Bar[1]^.Baz(2)
  TDesignatorLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Number, character string (#13#10'Text'), nil or control character (^M)
  TLiteralLexemeNode = class(TBaseLexemeNode)
  private
    FLiteralToken: TTokenKind;
  protected
    function GetNodeType: TLexemeType; override;
    function GetLexemeDetails: string; override;
    procedure InternalParseItself; override;
  public
    // Token of the first part of the literal
    property LiteralToken: TTokenKind read FLiteralToken;
  end;

  // Set constructor: [1, 3..5]
  TSetConstructorLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Range of two expressions in case labels and set constructors: 'a'..'z'
  TRangeLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Arguments of a call or a typecast in parentheses
  TArgumentListLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Indexes of an array or of an indexed property in brackets
  TIndexListLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TAnonymousMethodLexemeNode = class(TBaseLexemeNode)
  private
    FRoutineKind: TTokenKind;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  public
    // tkProcedure or tkFunction
    property RoutineKind: TTokenKind read FRoutineKind;
  end;

  // Call of an inherited method: inherited, inherited Create(AOwner)
  TInheritedExpressionLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Value of a typed constant of an array type: (1, 2, 3)
  TArrayConstantLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Value of a typed constant of a record type: (X: 1; Y: 2)
  TRecordConstantLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TRecordConstantFieldLexemeNode = class(TBaseLexemeNode)
  private
    FName: string;
  protected
    function GetNodeType: TLexemeType; override;
    function GetLexemeDetails: string; override;
    procedure InternalParseItself; override;
  public
    property Name: string read FName;
  end;

  { Types }

  // Reference to a named type: Integer, System.Classes.TList<Integer>, string[20], type TFoo
  TTypeIdentifierLexemeNode = class(TBaseLexemeNode)
  private
    FTypeName: string;
    FIsDistinct: Boolean;
  protected
    function GetNodeType: TLexemeType; override;
    function GetLexemeDetails: string; override;
    procedure InternalParseItself; override;
  public
    property TypeName: string read FTypeName;
    // The type is declared as a new distinct type: type Integer
    property IsDistinct: Boolean read FIsDistinct;
  end;

  TSubrangeTypeLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TEnumTypeLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TEnumElementLexemeNode = class(TBaseLexemeNode)
  private
    FName: string;
  protected
    function GetNodeType: TLexemeType; override;
    function GetLexemeDetails: string; override;
    procedure InternalParseItself; override;
  public
    property Name: string read FName;
  end;

  TSetTypeLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TArrayTypeLexemeNode = class(TBaseLexemeNode)
  private
    FIsPacked: Boolean;
    FIsArrayOfConst: Boolean;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  public
    property IsPacked: Boolean read FIsPacked;
    property IsArrayOfConst: Boolean read FIsArrayOfConst;
  end;

  TFileTypeLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TPointerTypeLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Procedural type: procedure of object, function(A: Integer): Boolean, reference to procedure
  TProceduralTypeLexemeNode = class(TBaseLexemeNode)
  private
    FRoutineKind: TTokenKind;
    FIsMethodPointer: Boolean;
    FIsReference: Boolean;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  public
    // tkProcedure or tkFunction
    property RoutineKind: TTokenKind read FRoutineKind;
    // Declared with "of object"
    property IsMethodPointer: Boolean read FIsMethodPointer;
    // Declared with "reference to"
    property IsReference: Boolean read FIsReference;
  end;

  // Base class of the types with members: classes, records, objects and interfaces
  TStructuredTypeLexemeNode = class abstract(TBaseLexemeNode)
  private
    FIsPacked: Boolean;
    FIsHelper: Boolean;
    FIsForward: Boolean;
  protected
    // Parses the members and the visibility sections up to the end of the type
    procedure ParseMembers(AStructureKind: TStructureKind);
    // Parses the ancestors in parentheses: (TInterfacedObject, IFoo)
    procedure ParseAncestors;
  public
    property IsPacked: Boolean read FIsPacked;
    property IsHelper: Boolean read FIsHelper;
    // Forward declaration without members: TFoo = class;
    property IsForward: Boolean read FIsForward;
  end;

  TClassTypeLexemeNode = class(TStructuredTypeLexemeNode)
  private
    // tkAbstract, tkSealed or tkUnknown
    FModifier: TTokenKind;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  public
    // tkAbstract or tkSealed for "class abstract" and "class sealed", tkUnknown otherwise
    property Modifier: TTokenKind read FModifier;
  end;

  // Class reference type: class of TFoo
  TClassReferenceTypeLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TRecordTypeLexemeNode = class(TStructuredTypeLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Old style object type
  TObjectTypeLexemeNode = class(TStructuredTypeLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TInterfaceTypeLexemeNode = class(TStructuredTypeLexemeNode)
  private
    FIsDispInterface: Boolean;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  public
    property IsDispInterface: Boolean read FIsDispInterface;
  end;

  // Members of a structured type after a visibility specifier: private, strict protected, public...
  TVisibilitySectionLexemeNode = class(TBaseLexemeNode)
  private
    FStructureKind: TStructureKind;
    FVisibility: TTokenKind;
    FIsStrict: Boolean;
  protected
    function GetNodeType: TLexemeType; override;
    function GetLexemeDetails: string; override;
    procedure InternalParseItself; override;
  public
    // tkPrivate, tkProtected, tkPublic, tkPublished or tkAutomated
    property Visibility: TTokenKind read FVisibility;
    property IsStrict: Boolean read FIsStrict;
  end;

  TPropertyLexemeNode = class(TBaseLexemeNode)
  private
    FName: string;
    FIsClassProperty: Boolean;
    FIsDefault: Boolean;
  protected
    function GetNodeType: TLexemeType; override;
    function GetLexemeDetails: string; override;
    procedure InternalParseItself; override;
  public
    property Name: string read FName;
    property IsClassProperty: Boolean read FIsClassProperty;
    // Default array property: property Items[Index: Integer]: TItem read GetItem; default;
    property IsDefault: Boolean read FIsDefault;
  end;

  // GUID of an interface: ['{00000000-0000-0000-C000-000000000046}']
  TInterfaceGuidLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Variant part of a record: case Integer of 0: (...); 1: (...)
  TVariantPartLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TVariantLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  { Routines }

  // Parameters of a routine in parentheses or of an array property in brackets
  TFormalParametersLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Parameters of one kind and type: const AFirst, ASecond: Integer = 0
  TParameterLexemeNode = class(TBaseLexemeNode)
  private
    FModifier: TTokenKind;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  public
    // tkVar, tkConst, tkOut or tkUnknown
    property Modifier: TTokenKind read FModifier;
  end;

  // Directive of a routine with its arguments: overload, external 'user32.dll' name 'MessageBoxW', message WM_SIZE
  TRoutineDirectiveLexemeNode = class(TBaseLexemeNode)
  private
    FDirective: TTokenKind;
  protected
    function GetNodeType: TLexemeType; override;
    function GetLexemeDetails: string; override;
    procedure InternalParseItself; override;
  public
    property Directive: TTokenKind read FDirective;
  end;

  // Heading of a procedure, function, constructor, destructor or operator with its directives. Alone it is a
  // declaration (interface section, class member, forward or external routine), in TRoutineLexemeNode it is the
  // heading of an implementation.
  TRoutineHeadingLexemeNode = class(TBaseLexemeNode)
  private
    FRoutineKind: TTokenKind;
    FName: string;
    FIsClassMethod: Boolean;
    FIsForward: Boolean;
    FIsExternal: Boolean;
    FIsMethodResolution: Boolean;

    procedure ParseName;
  protected
    function GetNodeType: TLexemeType; override;
    function GetLexemeDetails: string; override;
    procedure InternalParseItself; override;
  public
    // tkProcedure, tkFunction, tkConstructor, tkDestructor or tkOperator
    property RoutineKind: TTokenKind read FRoutineKind;
    // Name with the qualifiers of the implementation: TFoo.Bar
    property Name: string read FName;
    property IsClassMethod: Boolean read FIsClassMethod;
    property IsForward: Boolean read FIsForward;
    property IsExternal: Boolean read FIsExternal;
    // Method resolution clause of a class: procedure IFoo.Bar = DoBar;
    property IsMethodResolution: Boolean read FIsMethodResolution;
  end;

  // Routine of an implementation section or a nested routine: heading, local declarations and body
  TRoutineLexemeNode = class(TBaseLexemeNode)
  private
    FHeading: TRoutineHeadingLexemeNode;
    FBody: TBaseLexemeNode;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  public
    property Heading: TRoutineHeadingLexemeNode read FHeading;
    // Block begin..end or asm..end; nil for forward and external routines
    property Body: TBaseLexemeNode read FBody;
  end;

  { Declarations }

  TLabelSectionLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Section of constants or of resource strings
  TConstSectionLexemeNode = class(TBaseLexemeNode)
  private
    FKeyword: TTokenKind;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TTypeSectionLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Section of variables, thread variables or fields (var and class var in structured types)
  TVarSectionLexemeNode = class(TBaseLexemeNode)
  private
    FKeyword: TTokenKind;
    FIsClassVar: Boolean;
    FIsFieldSection: Boolean;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  public
    property IsClassVar: Boolean read FIsClassVar;
  end;

  TExportsLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TExportsItemLexemeNode = class(TBaseLexemeNode)
  private
    FName: string;
  protected
    function GetNodeType: TLexemeType; override;
    function GetLexemeDetails: string; override;
    procedure InternalParseItself; override;
  public
    property Name: string read FName;
  end;

  TConstDeclarationLexemeNode = class(TBaseLexemeNode)
  private
    FName: string;
  protected
    function GetNodeType: TLexemeType; override;
    function GetLexemeDetails: string; override;
    procedure InternalParseItself; override;
  public
    property Name: string read FName;
  end;

  TTypeDeclarationLexemeNode = class(TBaseLexemeNode)
  private
    FName: string;
  protected
    function GetNodeType: TLexemeType; override;
    function GetLexemeDetails: string; override;
    procedure InternalParseItself; override;
  public
    property Name: string read FName;
  end;

  // Variables of one type; the names are the ltIdentifier children
  TVarDeclarationLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
    // Parses the semicolon that ends the declaration
    procedure ParseDeclarationEnd; virtual;
  end;

  // Fields of one type in a structured type
  TFieldDeclarationLexemeNode = class(TVarDeclarationLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure ParseDeclarationEnd; override;
  end;

  { Statements }

  // Compound statement begin..end; also the main block of a program or a unit
  TBeginEndBlockLexemeNode = class(TBaseLexemeNode)
  private
    FIsMainBlock: Boolean;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  public
    // Main block of a module, it ends with "end."
    property IsMainBlock: Boolean read FIsMainBlock;
  end;

  // Assignment or a call of a procedure
  TSimpleStatementLexemeNode = class(TBaseLexemeNode)
  private
    FIsAssignment: Boolean;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TLabeledStatementLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TGotoStatementLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TIfStatementLexemeNode = class(TBaseLexemeNode)
  private
    FCondition: TBaseLexemeNode;
    FThenStatement: TBaseLexemeNode;
    FElseStatement: TBaseLexemeNode;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  public
    property Condition: TBaseLexemeNode read FCondition;
    // nil for an empty statement
    property ThenStatement: TBaseLexemeNode read FThenStatement;
    // nil without else or for an empty statement
    property ElseStatement: TBaseLexemeNode read FElseStatement;
  end;

  TCaseStatementLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Labels of a case statement with their statement: 1, 3..5: DoSomething
  TCaseItemLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Statements after else of a case statement or of an exception block
  TElseBlockLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TRepeatStatementLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TWhileStatementLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Statement for..to, for..downto or for..in
  TForStatementLexemeNode = class(TBaseLexemeNode)
  private
    FIsForIn: Boolean;
    FIsDownto: Boolean;
    FIsInlineVar: Boolean;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  public
    property IsDownto: Boolean read FIsDownto;
    // The control variable is declared in the statement: for var I := ...
    property IsInlineVar: Boolean read FIsInlineVar;
  end;

  TWithStatementLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Statement try with its statements followed by an except block or a finally block
  TTryStatementLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Block except with statements or with exception handlers and an optional else block
  TExceptBlockLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Exception handler: on E: Exception do Statement
  TExceptionHandlerLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TFinallyBlockLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TRaiseStatementLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Assembler block asm..end, its instructions are not parsed
  TAsmStatementLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Inline variable declaration: var I: Integer := 0
  TInlineVarDeclarationLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Inline constant declaration: const Count = 10
  TInlineConstDeclarationLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  { Modules and sections }

  // Clause uses, or requires and contains of a package
  TUsesClauseLexemeNode = class(TBaseLexemeNode)
  private
    FKeyword: TTokenKind;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Unit in a uses clause: System.SysUtils, uMain in 'uMain.pas'
  TUsesItemLexemeNode = class(TBaseLexemeNode)
  private
    FModuleName: string;
    FFileName: string;
  protected
    function GetNodeType: TLexemeType; override;
    function GetLexemeDetails: string; override;
    procedure InternalParseItself; override;
  public
    property ModuleName: string read FModuleName;
    // File name after "in" with the quotes, empty without it
    property FileName: string read FFileName;
  end;

  TInterfaceSectionLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TImplementationSectionLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TInitializationSectionLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TFinalizationSectionLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Base class of the modules: units, programs, libraries and packages
  TModuleLexemeNode = class abstract(TBaseLexemeNode)
  private
    FModuleName: string;
  protected
    function GetLexemeDetails: string; override;
  public
    property ModuleName: string read FModuleName;
  end;

  TUnitLexemeNode = class(TModuleLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Program, also the base of a library that has the same structure
  TProgramLexemeNode = class(TModuleLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TLibraryLexemeNode = class(TProgramLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
  end;

  TPackageLexemeNode = class(TModuleLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  // Root of the lexeme tree. It owns the cursor and covers all parsed states, also those after the end of the module.
  TRootLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
    procedure FinalizeNodeEnd; override;
  public
    constructor Create(AStates: PLexerStateArray; AStatesCount: Integer); reintroduce;
    destructor Destroy; override;
  end;

implementation

uses
  System.Math,
  uPasExceptions;

const
  CHILD_NODES_MIN_CAPACITY = 4;
  AMPERSAND_SYMBOL = '&';
  QUOTE_CHAR = '''';
  NAME_SEPARATOR = '.';
  // Words that the lexer does not know
  ON_WORD = 'on';
  AT_WORD = 'at';
  ALIGN_WORD = 'align';
  DEPENDENCY_WORD = 'dependency';
  LEXEME_LOG_FORMAT = '%s (Line: %d, Column: %d, Start: %d, Count: %d)';
  LEXEME_DETAILS_FORMAT = '%s %s';
  ROUTINE_DETAILS_FORMAT = '%s %s';

  // Tokens that end a statement
  STATEMENT_END_TOKENS = [tkSemiColon, tkEnd, tkUnitEnd, tkElse, tkUntil, tkExcept, tkFinally, tkEOF];
  // Tokens that continue a designator after a literal or a parenthesized expression
  DESIGNATOR_SELECTOR_TOKENS = [tkPoint, tkSquareOpen, tkRoundOpen, tkPointerSymbol];
  // Tokens that can make up the bound of a subrange type
  SUBRANGE_BOUND_TOKENS = IDENTIFIER_TOKENS + [tkNumber, tkInteger, tkFloat, tkString, tkAsciiChar, tkPoint, tkPlus,
      tkMinus, tkStar, tkSlash, tkDiv, tkMod, tkShl, tkShr, tkAnd, tkOr, tkXor, tkNot];
  // Tokens that can make up the generic arguments
  GENERIC_ARGUMENT_TOKENS = IDENTIFIER_TOKENS + [tkString, tkPoint, tkComma, tkLower, tkGreater, tkArray, tkOf];
  // Tokens that can follow the generic arguments in an expression: the binary operators except the ones that can start
  // an operand of a comparison (A < B, C > -D)
  GENERIC_FOLLOW_TOKENS = [tkPoint, tkRoundOpen, tkRoundClose, tkSquareOpen, tkSquareClose, tkSemiColon, tkComma,
      tkColon, tkAssign, tkEnd, tkUnitEnd, tkThen, tkDo, tkOf, tkTo, tkDownto, tkElse, tkUntil, tkEOF]
      + BINARY_OPERATOR_TOKENS - [tkLower, tkGreater, tkPlus, tkMinus];
  // Calling conventions of a procedural type and the tokens that can follow them after a semicolon:
  // TCallback = function(A: Integer): Integer; cdecl varargs; FProc: procedure; stdcall = nil;
  PROCEDURAL_DIRECTIVE_FOLLOW_TOKENS = PROCEDURAL_DIRECTIVE_TOKENS + [tkSemiColon, tkEqual];

  BINARY_OPERATORS_BY_PRECEDENCE: array[TExpressionPrecedence] of TTokenKindSet = (
    RELATIONAL_OPERATOR_TOKENS,
    ADDITIVE_OPERATOR_TOKENS,
    MULTIPLICATIVE_OPERATOR_TOKENS
  );

  DECLARATION_SECTION_TOKENS: array[TDeclarationContext] of TTokenKindSet = (
    [tkConst, tkResourcestring, tkType, tkVar, tkThreadvar, tkExports],
    [tkLabel, tkConst, tkResourcestring, tkType, tkVar, tkThreadvar, tkExports],
    [tkLabel, tkConst, tkType, tkVar]
  );

{ TLexemeCursor }

constructor TLexemeCursor.Create(AStates: PLexerStateArray; AStatesCount: Integer);
var
  i: Integer;
begin
  inherited Create;

  FStates := AStates;
  FStatesCount := AStatesCount;
  FLastStateIndex := -1;

  SetLength(FSignificantIndexes, FStatesCount);
  FSignificantCount := 0;
  for i := 0 to FStatesCount - 1 do
    if not (FStates^[i].CurrentToken in DIRECTIVE_INSIGNIFICANT_TOKENS) then
    begin
      FSignificantIndexes[FSignificantCount] := i;
      Inc(FSignificantCount);
    end;
  SetLength(FSignificantIndexes, FSignificantCount);
end;

function TLexemeCursor.GetStateIndex(AOffset: Integer = 0): Integer;
var
  Position: Integer;
begin
  Position := FPosition + AOffset;
  if (Position >= 0) and (Position < FSignificantCount) then
    Result := FSignificantIndexes[Position]
  else
    Result := FStatesCount;
end;

function TLexemeCursor.GetToken(AOffset: Integer = 0): TTokenKind;
var
  Position: Integer;
begin
  Position := FPosition + AOffset;
  if (Position >= 0) and (Position < FSignificantCount) then
    Result := FStates^[FSignificantIndexes[Position]].CurrentToken
  else
    Result := tkEOF;
end;

function TLexemeCursor.GetTokenString(AOffset: Integer = 0): string;
var
  Position: Integer;
begin
  Position := FPosition + AOffset;
  if (Position >= 0) and (Position < FSignificantCount) then
    Result := FStates^[FSignificantIndexes[Position]].TokenString
  else
    Result := EmptyStr;
end;

procedure TLexemeCursor.MoveNext;
begin
  if FPosition < FSignificantCount then
  begin
    FLastStateIndex := FSignificantIndexes[FPosition];
    Inc(FPosition);
  end;
end;

{ TBaseLexemeNode }

class constructor TBaseLexemeNode.ClassCreate;
var
  i: Integer;
begin
  for i := Low(DELPHI_KEYWORDS) to High(DELPHI_KEYWORDS) do
    FTokenWords[DELPHI_KEYWORDS[i].Token] := DELPHI_KEYWORDS[i].Word;
end;

constructor TBaseLexemeNode.Create(AParent: TBaseLexemeNode);
begin
  inherited Create;

  FParentNode := AParent;
  FParentChildIndex := -1;
  if Assigned(FParentNode) then
  begin
    FCursor := FParentNode.FCursor;
    FStartIndex := FCursor.GetStateIndex;
    FParentChildIndex := FParentNode.AddChildNode(Self);
  end;
end;

destructor TBaseLexemeNode.Destroy;
var
  i: Integer;
begin
  for i := 0 to FChildCount - 1 do
    FChildNodes[i].Free;
  FChildNodes := nil;
  FChildCount := 0;

  inherited Destroy;
end;

class function TBaseLexemeNode.CreateWrapping(AFirstChild: TBaseLexemeNode): TBaseLexemeNode;
var
  Parent: TBaseLexemeNode;
begin
  Parent := AFirstChild.FParentNode;
  Result := Create(Parent);

  Result.FStartIndex := AFirstChild.FStartIndex;
  Parent.RemoveChildNode(AFirstChild);
  AFirstChild.FParentNode := Result;
  AFirstChild.FParentChildIndex := Result.AddChildNode(AFirstChild);
end;

function TBaseLexemeNode.GetChildNode(AIndex: Integer): TBaseLexemeNode;
begin
  if (AIndex < 0) or (AIndex >= FChildCount) then
    raise EPasParserException.CreateFmt(EMESSAGE_GET_INDEX_OUT_OF_RANGE, [AIndex]);

  Result := FChildNodes[AIndex];
end;

function TBaseLexemeNode.GetLevel: Integer;
var
  Node: TBaseLexemeNode;
begin
  Result := 0;
  Node := FParentNode;
  while Assigned(Node) do
  begin
    Inc(Result);
    Node := Node.FParentNode;
  end;
end;

function TBaseLexemeNode.GetStatesEndIndex: Integer;
begin
  Result := FStartIndex + FCount - 1;
end;

function TBaseLexemeNode.GetFirstState: TPasLexerMinimalState;
begin
  if (FStartIndex >= 0) and (FStartIndex < FCursor.StatesCount) then
    Result := FCursor.States^[FStartIndex]
  else
    Result := Default(TPasLexerMinimalState);
end;

function TBaseLexemeNode.GetLastState: TPasLexerMinimalState;
var
  EndIndex: Integer;
begin
  EndIndex := GetStatesEndIndex;
  if (EndIndex >= 0) and (EndIndex < FCursor.StatesCount) then
    Result := FCursor.States^[EndIndex]
  else
    Result := Default(TPasLexerMinimalState);
end;

function TBaseLexemeNode.GetErrorStateIndex: Integer;
begin
  Result := FCursor.GetStateIndex;
  if Result >= FCursor.StatesCount then
    Result := FCursor.StatesCount - 1;
end;

function TBaseLexemeNode.IsArrayConstantAhead: Boolean;
var
  Offset, Depth: Integer;
begin
  // The current token is '('. A comma at the top level separates the elements of an array constant.
  Depth := 0;
  Offset := 1;
  while True do
  begin
    case PeekToken(Offset) of
      tkRoundOpen, tkSquareOpen:
        Inc(Depth);
      tkRoundClose, tkSquareClose:
      begin
        if Depth = 0 then
          Break;
        Dec(Depth);
      end;
      tkComma:
        if Depth = 0 then
          Exit(True);
      tkEOF:
        Exit(False);
    end;
    Inc(Offset);
  end;

  // A single element is an array constant only when it is an aggregate itself and the parentheses are not an operand:
  // ((1, 2)) is an array constant, (A + B) * C is an expression
  Result := (PeekToken(1) = tkRoundOpen)
      and not (PeekToken(Offset + 1) in BINARY_OPERATOR_TOKENS + DESIGNATOR_SELECTOR_TOKENS);
end;

function TBaseLexemeNode.AddChildNode(ANode: TBaseLexemeNode): Integer;
begin
  if FChildCount >= Length(FChildNodes) then
    SetLength(FChildNodes, Max(CHILD_NODES_MIN_CAPACITY, FChildCount * 2));

  Result := FChildCount;
  FChildNodes[Result] := ANode;
  Inc(FChildCount);
end;

procedure TBaseLexemeNode.RemoveChildNode(ANode: TBaseLexemeNode);
var
  i, j: Integer;
begin
  for i := FChildCount - 1 downto 0 do
    if FChildNodes[i] = ANode then
    begin
      for j := i to FChildCount - 2 do
      begin
        FChildNodes[j] := FChildNodes[j + 1];
        FChildNodes[j].FParentChildIndex := j;
      end;
      Dec(FChildCount);
      FChildNodes[FChildCount] := nil;
      ANode.FParentChildIndex := -1;
      Break;
    end;
end;

function TBaseLexemeNode.GetNextChildNodeForIndex(AFromIndex: Integer): TBaseLexemeNode;
begin
  Inc(AFromIndex);
  if (AFromIndex >= 0) and (AFromIndex < FChildCount) then
    Result := FChildNodes[AFromIndex]
  else
    Result := nil;
end;

function TBaseLexemeNode.GetPrevChildNodeForIndex(AFromIndex: Integer): TBaseLexemeNode;
begin
  Dec(AFromIndex);
  if (AFromIndex >= 0) and (AFromIndex < FChildCount) then
    Result := FChildNodes[AFromIndex]
  else
    Result := nil;
end;

procedure TBaseLexemeNode.FinalizeNodeEnd;
begin
  if FCursor.LastStateIndex >= FStartIndex then
    FCount := FCursor.LastStateIndex - FStartIndex + 1
  else
    FCount := 0;
end;

function TBaseLexemeNode.GetFirstChild: TBaseLexemeNode;
begin
  if FChildCount > 0 then
    Result := FChildNodes[0]
  else
    Result := nil;
end;

function TBaseLexemeNode.GetLastChild: TBaseLexemeNode;
begin
  if FChildCount > 0 then
    Result := FChildNodes[FChildCount - 1]
  else
    Result := nil;
end;

function TBaseLexemeNode.GetNextTraversal: TBaseLexemeNode;
var
  TempNode: TBaseLexemeNode;
begin
  Result := GetFirstChild;
  if Assigned(Result) then Exit;

  Result := GetNextSibling;
  if Assigned(Result) then Exit;

  Result := FParentNode;
  while Result <> nil do
  begin
    TempNode := Result.GetNextSibling;
    if Assigned(TempNode) then
      Exit(TempNode);
    Result := Result.ParentNode;
  end;
end;

function TBaseLexemeNode.GetPrevTraversal: TBaseLexemeNode;
var
  TempNode: TBaseLexemeNode;
begin
  Result := GetPrevSibling;
  if not Assigned(Result) then Exit(ParentNode);

  // The deepest last descendant of the previous sibling
  TempNode := Result.GetLastChild;
  while TempNode <> nil do
  begin
    Result := TempNode;
    TempNode := Result.GetLastChild;
  end;
end;

function TBaseLexemeNode.GetNextSibling: TBaseLexemeNode;
begin
  if (not Assigned(FParentNode)) or (FParentChildIndex = -1) then
    Result := nil
  else
    Result := FParentNode.GetNextChildNodeForIndex(FParentChildIndex);
end;

function TBaseLexemeNode.GetPrevSibling: TBaseLexemeNode;
begin
  if (not Assigned(FParentNode)) or (FParentChildIndex = -1) then
    Result := nil
  else
    Result := FParentNode.GetPrevChildNodeForIndex(FParentChildIndex);
end;

function TBaseLexemeNode.GetStatesCurrentIndexLineNumber: Integer;
var
  StateIndex: Integer;
begin
  StateIndex := GetErrorStateIndex;
  if StateIndex < 0 then
    Result := 0
  else
    Result := FCursor.States^[StateIndex].CurrentLine;
end;

function TBaseLexemeNode.GetStatesCurrentIndexLineCharIndex: Integer;
var
  StateIndex: Integer;
begin
  StateIndex := GetErrorStateIndex;
  if StateIndex < 0 then
    Result := 0
  else
    Result := FCursor.States^[StateIndex].Column;
end;

function TBaseLexemeNode.GetStatesCurrentIndexToken: TTokenKind;
begin
  Result := FCursor.GetToken;
end;

function TBaseLexemeNode.GetStatesCurrentTokenString: string;
begin
  Result := FCursor.GetTokenString;
end;

function TBaseLexemeNode.GetLexemeDetails: string;
begin
  Result := EmptyStr;
end;

function TBaseLexemeNode.PeekToken(AOffset: Integer = 0): TTokenKind;
begin
  Result := FCursor.GetToken(AOffset);
end;

function TBaseLexemeNode.PeekTokenString(AOffset: Integer = 0): string;
begin
  Result := FCursor.GetTokenString(AOffset);
end;

function TBaseLexemeNode.IsWord(AToken: TTokenKind; AOffset: Integer = 0): Boolean;
var
  Token: TTokenKind;
begin
  Token := PeekToken(AOffset);
  Result := (Token = AToken) or ((Token = tkIdentifier) and SameText(PeekTokenString(AOffset), FTokenWords[AToken]));
end;

function TBaseLexemeNode.IsWordIn(ATokens: TTokenKindSet; AOffset: Integer = 0): Boolean;
var
  Token: TTokenKind;
  Text: string;
begin
  Token := PeekToken(AOffset);
  if Token in ATokens then
    Exit(True);
  if Token <> tkIdentifier then
    Exit(False);

  Text := PeekTokenString(AOffset);
  for Token in ATokens do
    if SameText(Text, FTokenWords[Token]) then
      Exit(True);
  Result := False;
end;

function TBaseLexemeNode.IsText(const AWord: string; AOffset: Integer = 0): Boolean;
begin
  Result := (PeekToken(AOffset) in IDENTIFIER_TOKENS) and SameText(PeekTokenString(AOffset), AWord);
end;

function TBaseLexemeNode.IsStringLiteral(AOffset: Integer = 0): Boolean;
var
  Text: string;
begin
  if PeekToken(AOffset) <> tkString then
    Exit(False);

  Text := PeekTokenString(AOffset);
  Result := (Text <> EmptyStr) and (Text[1] = QUOTE_CHAR);
end;

function TBaseLexemeNode.IsWordToken(AOffset: Integer = 0): Boolean;
begin
  Result := (PeekToken(AOffset) in WORD_TOKENS) and not IsStringLiteral(AOffset);
end;

function TBaseLexemeNode.IsEscapedNumberAhead: Boolean;
begin
  Result := (PeekToken = tkSymbol)
      and (PeekTokenString = AMPERSAND_SYMBOL)
      and (PeekToken(1) in [tkNumber, tkInteger])
      and (FCursor.GetStateIndex(1) = FCursor.GetStateIndex + 1);
end;

function TBaseLexemeNode.IsIdentifier(AOffset: Integer = 0): Boolean;
var
  Token: TTokenKind;
begin
  Token := PeekToken(AOffset);
  Result := (Token in IDENTIFIER_TOKENS)
      or ((Token = tkSymbol) and (PeekTokenString(AOffset) = AMPERSAND_SYMBOL) and IsWordToken(AOffset + 1));
end;

function TBaseLexemeNode.GetIdentifierEndOffset(AOffset: Integer = 0): Integer;
begin
  if PeekToken(AOffset) = tkSymbol then
    Result := AOffset + 2
  else
    Result := AOffset + 1;
end;

function TBaseLexemeNode.SkipBracketsOffset(AOffset: Integer): Integer;
var
  Depth: Integer;
begin
  Depth := 0;
  Result := AOffset;
  repeat
    case PeekToken(Result) of
      tkRoundOpen, tkSquareOpen:
        Inc(Depth);
      tkRoundClose, tkSquareClose:
        Dec(Depth);
      tkEOF:
        Exit(-1);
    end;
    Inc(Result);
  until Depth <= 0;
end;

function TBaseLexemeNode.SkipAttributesOffset(AOffset: Integer = 0): Integer;
var
  Offset: Integer;
begin
  Result := AOffset;
  while PeekToken(Result) = tkSquareOpen do
  begin
    Offset := SkipBracketsOffset(Result);
    if Offset < 0 then
      Exit;
    Result := Offset;
  end;
end;

function TBaseLexemeNode.IsDeclarationAhead(AFollowTokens: TTokenKindSet): Boolean;
var
  Offset: Integer;
begin
  Offset := SkipAttributesOffset;
  Result := IsIdentifier(Offset) and (PeekToken(GetIdentifierEndOffset(Offset)) in AFollowTokens);
end;

function TBaseLexemeNode.IsSubrangeAhead: Boolean;
var
  Offset, Depth: Integer;
  Token: TTokenKind;
begin
  // Looks for '..' at the top level while the tokens can make up a constant expression
  Depth := 0;
  Offset := 0;
  while True do
  begin
    Token := PeekToken(Offset);
    case Token of
      tkDotDot:
        if Depth = 0 then
          Exit(True);
      tkRoundOpen, tkSquareOpen:
        Inc(Depth);
      tkRoundClose, tkSquareClose:
      begin
        if Depth = 0 then
          Exit(False);
        Dec(Depth);
      end;
      tkComma:
        if Depth = 0 then
          Exit(False);
    else
      if not (Token in SUBRANGE_BOUND_TOKENS) then
        Exit(False);
    end;
    Inc(Offset);
  end;
end;

function TBaseLexemeNode.IsGenericArgumentsAhead: Boolean;
var
  Offset, Depth: Integer;
  Token: TTokenKind;
begin
  // The arguments may contain only type names, and the closing '>' must be followed by a token that can not start an
  // operand of a comparison
  Depth := 0;
  Offset := 0;
  repeat
    Token := PeekToken(Offset);
    if not (Token in GENERIC_ARGUMENT_TOKENS) or ((Token = tkString) and IsStringLiteral(Offset)) then
      Exit(False);
    case Token of
      tkLower:
        Inc(Depth);
      tkGreater:
        Dec(Depth);
    end;
    Inc(Offset);
  until Depth = 0;

  Result := PeekToken(Offset) in GENERIC_FOLLOW_TOKENS;
end;

function TBaseLexemeNode.IsVisibilityAhead: Boolean;
var
  Token: TTokenKind;
begin
  Token := PeekToken;
  if Token = tkStrict then
    Result := PeekToken(1) in [tkPrivate, tkProtected]
  else
    Result := (Token in VISIBILITY_TOKENS) and not (PeekToken(1) in [tkColon, tkComma]);
end;

function TBaseLexemeNode.IsDirectiveAhead(ADirectives: TTokenKindSet; AOffset: Integer = 0): Boolean;
begin
  Result := (PeekToken(AOffset) in ADirectives)
      and not (PeekToken(AOffset + 1) in [tkColon, tkComma, tkEqual, tkAssign, tkPoint]);
end;

procedure TBaseLexemeNode.NextToken;
begin
  FCursor.MoveNext;
end;

function TBaseLexemeNode.AcceptToken(AToken: TTokenKind): Boolean;
begin
  Result := PeekToken = AToken;
  if Result then
    NextToken;
end;

procedure TBaseLexemeNode.ExpectToken(AToken: TTokenKind);
begin
  if PeekToken <> AToken then
    raise CreateUnexpectedError(TOKEN_NAMES[AToken]);
  NextToken;
end;

function TBaseLexemeNode.ExpectIdentifier(AAllowKeywords: Boolean = False): string;
begin
  if (PeekToken = tkSymbol) and IsIdentifier then
    NextToken // the escaping '&'
  else if not ((PeekToken in IDENTIFIER_TOKENS) or (AAllowKeywords and IsWordToken)) then
    raise CreateUnexpectedError(EMESSAGE_EXPECTED_IDENTIFIER);

  Result := PeekTokenString;
  NextToken;
end;

function TBaseLexemeNode.CreateUnexpectedError(const AExpected: string): Exception;
begin
  if PeekToken = tkEOF then
    Result := EPasGrammarParserException.CreateFmt(EMESSAGE_GRAMMAR_UNEXPECTED_ENDOFFILE, [AExpected], Self)
  else
    Result := EPasGrammarParserException.CreateFmt(EMESSAGE_GRAMMAR_UNEXPECTED_TOKEN,
        [AExpected, Format(EMESSAGE_GRAMMAR_TOKEN_DESCRIPTION, [TOKEN_NAMES[PeekToken], PeekTokenString])], Self);
end;

function TBaseLexemeNode.ParseChild(ANodeClass: TBaseLexemeNodeClass): TBaseLexemeNode;
begin
  Result := ANodeClass.Create(Self);
  Result.ParseItself;
end;

function TBaseLexemeNode.ParseIdentifier(AQualified: Boolean; AAllowKeywords: Boolean = False): TIdentifierLexemeNode;
begin
  Result := TIdentifierLexemeNode.Create(Self);
  Result.FIsQualified := AQualified;
  Result.FAllowKeywords := AAllowKeywords;
  Result.ParseItself;
end;

function TBaseLexemeNode.ParseExpression(APrecedence: TExpressionPrecedence = epRelational): TBaseLexemeNode;
var
  BinaryNode: TBinaryExpressionLexemeNode;
begin
  if APrecedence = High(TExpressionPrecedence) then
    Result := ParseFactor
  else
    Result := ParseExpression(Succ(APrecedence));

  // The operators of one precedence are left associative: A - B - C is (A - B) - C
  while PeekToken in BINARY_OPERATORS_BY_PRECEDENCE[APrecedence] do
  begin
    BinaryNode := TBinaryExpressionLexemeNode(TBinaryExpressionLexemeNode.CreateWrapping(Result));
    BinaryNode.FPrecedence := APrecedence;
    BinaryNode.ParseItself;
    Result := BinaryNode;
  end;
end;

function TBaseLexemeNode.ParseFactor: TBaseLexemeNode;
begin
  case PeekToken of
    tkNot, tkMinus, tkPlus, tkAddressSymbol:
      Result := ParseChild(TUnaryExpressionLexemeNode);
    tkNumber, tkInteger, tkFloat, tkAsciiChar, tkNil, tkPointerSymbol:
      Result := ParseChild(TLiteralLexemeNode);
    tkRoundOpen:
      Result := ParseChild(TParenthesizedExpressionLexemeNode);
    tkSquareOpen:
      Result := ParseChild(TSetConstructorLexemeNode);
    tkInherited:
      Result := ParseChild(TInheritedExpressionLexemeNode);
    tkProcedure, tkFunction:
      Result := ParseChild(TAnonymousMethodLexemeNode);
    tkString:
      if IsStringLiteral then
        Result := ParseChild(TLiteralLexemeNode)
      else
        Result := ParseChild(TDesignatorLexemeNode);
  else
    if IsEscapedNumberAhead then
      Result := ParseChild(TLiteralLexemeNode)
    else if IsIdentifier then
      Result := ParseChild(TDesignatorLexemeNode)
    else
      raise CreateUnexpectedError(EMESSAGE_EXPECTED_EXPRESSION);
  end;

  // Selectors after a literal, a parenthesized expression or an inherited call: 'abc'[1], (Sender as TButton).Caption,
  // (P)^, inherited.AsExtended
  if (Result.NodeType in [ltLiteral, ltParenthesizedExpression, ltInheritedExpression])
      and (PeekToken in DESIGNATOR_SELECTOR_TOKENS)
  then
  begin
    Result := TDesignatorLexemeNode.CreateWrapping(Result);
    Result.ParseItself;
  end;
end;

function TBaseLexemeNode.ParseExpressionOrRange: TBaseLexemeNode;
begin
  Result := ParseExpression;
  if PeekToken = tkDotDot then
  begin
    Result := TRangeLexemeNode.CreateWrapping(Result);
    Result.ParseItself;
  end;
end;

function TBaseLexemeNode.ParseTypedConstant: TBaseLexemeNode;
begin
  if PeekToken = tkRoundOpen then
  begin
    if (PeekToken(1) = tkRoundClose) or (IsIdentifier(1) and (PeekToken(GetIdentifierEndOffset(1)) = tkColon)) then
      Exit(ParseChild(TRecordConstantLexemeNode));
    if IsArrayConstantAhead then
      Exit(ParseChild(TArrayConstantLexemeNode));
  end;
  Result := ParseExpression;
end;

function TBaseLexemeNode.ParseType: TBaseLexemeNode;
var
  Token: TTokenKind;
begin
  Token := PeekToken;
  if Token = tkPacked then
    Token := PeekToken(1);

  case Token of
    tkRecord:
      Result := ParseChild(TRecordTypeLexemeNode);
    tkClass:
      if PeekToken(1) = tkOf then
        Result := ParseChild(TClassReferenceTypeLexemeNode)
      else
        Result := ParseChild(TClassTypeLexemeNode);
    tkObject:
      Result := ParseChild(TObjectTypeLexemeNode);
    tkInterface, tkDispinterface:
      Result := ParseChild(TInterfaceTypeLexemeNode);
    tkArray:
      Result := ParseChild(TArrayTypeLexemeNode);
    tkSet:
      Result := ParseChild(TSetTypeLexemeNode);
    tkFile:
      Result := ParseChild(TFileTypeLexemeNode);
    tkPointerSymbol:
      Result := ParseChild(TPointerTypeLexemeNode);
    tkRoundOpen:
      Result := ParseChild(TEnumTypeLexemeNode);
    tkProcedure, tkFunction:
      Result := ParseChild(TProceduralTypeLexemeNode);
    tkType:
      Result := ParseChild(TTypeIdentifierLexemeNode);
  else
    if (Token = tkReference) and (PeekToken(1) = tkTo) then
      Result := ParseChild(TProceduralTypeLexemeNode)
    else if (Token = tkString) and not IsStringLiteral then
      Result := ParseChild(TTypeIdentifierLexemeNode)
    else if IsSubrangeAhead then
      Result := ParseChild(TSubrangeTypeLexemeNode)
    else if IsIdentifier then
      Result := ParseChild(TTypeIdentifierLexemeNode)
    else
      raise CreateUnexpectedError(EMESSAGE_EXPECTED_TYPE);
  end;
end;

function TBaseLexemeNode.ParseStatement: TBaseLexemeNode;
begin
  case PeekToken of
    tkSemiColon, tkEnd, tkUnitEnd, tkElse, tkUntil, tkExcept, tkFinally, tkEOF:
      Result := nil; // empty statement
    tkBegin:
      Result := ParseChild(TBeginEndBlockLexemeNode);
    tkIf:
      Result := ParseChild(TIfStatementLexemeNode);
    tkCase:
      Result := ParseChild(TCaseStatementLexemeNode);
    tkRepeat:
      Result := ParseChild(TRepeatStatementLexemeNode);
    tkWhile:
      Result := ParseChild(TWhileStatementLexemeNode);
    tkFor:
      Result := ParseChild(TForStatementLexemeNode);
    tkWith:
      Result := ParseChild(TWithStatementLexemeNode);
    tkTry:
      Result := ParseChild(TTryStatementLexemeNode);
    tkRaise:
      Result := ParseChild(TRaiseStatementLexemeNode);
    tkGoto:
      Result := ParseChild(TGotoStatementLexemeNode);
    tkAsm:
      Result := ParseChild(TAsmStatementLexemeNode);
    tkVar:
      Result := ParseChild(TInlineVarDeclarationLexemeNode);
    tkConst:
      Result := ParseChild(TInlineConstDeclarationLexemeNode);
  else
    if ((PeekToken in [tkNumber, tkInteger]) and (PeekToken(1) = tkColon))
        or (IsIdentifier and (PeekToken(GetIdentifierEndOffset) = tkColon))
    then
      Result := ParseChild(TLabeledStatementLexemeNode)
    else
      Result := ParseChild(TSimpleStatementLexemeNode);
  end;
end;

procedure TBaseLexemeNode.ParseStatementList(ATerminators: TTokenKindSet);
begin
  while not (PeekToken in ATerminators) do
  begin
    ParseStatement;
    if not AcceptToken(tkSemiColon) and not (PeekToken in ATerminators) then
      raise CreateUnexpectedError(TOKEN_NAMES[tkSemiColon]);
  end;
end;

procedure TBaseLexemeNode.ParseAttributes;
begin
  while PeekToken = tkSquareOpen do
    ParseChild(TAttributeListLexemeNode);
end;

procedure TBaseLexemeNode.ParsePortabilityDirectives;
begin
  while PeekToken in PORTABILITY_DIRECTIVE_TOKENS do
    ParseChild(TRoutineDirectiveLexemeNode);
end;

procedure TBaseLexemeNode.ParseDeclarations(AContext: TDeclarationContext);
var
  Offset: Integer;
  Token: TTokenKind;
begin
  while True do
  begin
    Offset := SkipAttributesOffset;
    Token := PeekToken(Offset);
    if (Token in METHOD_TOKENS) or ((Token = tkClass) and (PeekToken(Offset + 1) in METHOD_TOKENS)) then
    begin
      if AContext = dcInterface then
        ParseChild(TRoutineHeadingLexemeNode)
      else
        ParseChild(TRoutineLexemeNode);
      Continue;
    end;

    if not (PeekToken in DECLARATION_SECTION_TOKENS[AContext]) then
      Break;
    case PeekToken of
      tkLabel:
        ParseChild(TLabelSectionLexemeNode);
      tkConst, tkResourcestring:
        ParseChild(TConstSectionLexemeNode);
      tkType:
        ParseChild(TTypeSectionLexemeNode);
      tkVar, tkThreadvar:
        ParseChild(TVarSectionLexemeNode);
      tkExports:
        ParseChild(TExportsLexemeNode);
    end;
  end;
end;

function TBaseLexemeNode.ParseStructureMember(AStructureKind: TStructureKind): Boolean;
var
  Offset: Integer;
  Token: TTokenKind;
  FieldSection: TVarSectionLexemeNode;
begin
  Result := True;
  Offset := SkipAttributesOffset;
  Token := PeekToken(Offset);
  if Token = tkClass then
    Token := PeekToken(Offset + 1);

  case Token of
    tkProcedure, tkFunction, tkConstructor, tkDestructor:
      ParseChild(TRoutineHeadingLexemeNode);
    tkProperty:
      ParseChild(TPropertyLexemeNode);
    tkConst:
      ParseChild(TConstSectionLexemeNode);
    tkType:
      ParseChild(TTypeSectionLexemeNode);
    tkVar, tkThreadvar:
    begin
      FieldSection := TVarSectionLexemeNode.Create(Self);
      FieldSection.FIsFieldSection := True;
      FieldSection.ParseItself;
    end;
    tkCase:
      ParseChild(TVariantPartLexemeNode);
  else
    // Operators are always class operators; "Operator" alone is a field name
    if (Token = tkOperator) and (PeekToken(Offset) = tkClass) then
      ParseChild(TRoutineHeadingLexemeNode)
    else if (PeekToken(Offset) <> tkClass) and IsIdentifier(Offset)
        and (PeekToken(GetIdentifierEndOffset(Offset)) in [tkColon, tkComma])
    then
      ParseChild(TFieldDeclarationLexemeNode)
    else
      Result := False;
  end;
end;

procedure TBaseLexemeNode.ParseMainBlock;
var
  Block: TBeginEndBlockLexemeNode;
begin
  Block := TBeginEndBlockLexemeNode.Create(Self);
  Block.FIsMainBlock := True;
  Block.ParseItself;
end;

procedure TBaseLexemeNode.ParseModuleEnd;
begin
  if AcceptToken(tkUnitEnd) then
    Exit;

  ExpectToken(tkEnd);
  ExpectToken(tkPoint);
end;

procedure TBaseLexemeNode.ParseItself;
begin
  InternalParseItself;
  FinalizeNodeEnd;
end;

function TBaseLexemeNode.GetLexemeLog: string;
var
  State: TPasLexerMinimalState;
  Details: string;
begin
  State := GetFirstState;
  Result := Format(LEXEME_LOG_FORMAT, [LEXEME_NAMES[NodeType], State.CurrentLine, State.Column, FStartIndex, FCount]);

  Details := GetLexemeDetails;
  if Details <> EmptyStr then
    Result := Format(LEXEME_DETAILS_FORMAT, [Result, Details]);
end;

function TBaseLexemeNode.GetOwnTokenIndexes: TArray<Integer>;
var
  StateIndex, EndIndex, ChildIndex, ResultCount: Integer;
  Child: TBaseLexemeNode;
begin
  SetLength(Result, FCount);
  ResultCount := 0;
  ChildIndex := 0;
  StateIndex := FStartIndex;
  EndIndex := GetStatesEndIndex;
  while StateIndex <= EndIndex do
  begin
    // The children are ordered by position and do not overlap: skip the range of the next child
    if ChildIndex < FChildCount then
    begin
      Child := FChildNodes[ChildIndex];
      if StateIndex >= Child.FStartIndex then
      begin
        StateIndex := Max(StateIndex, Child.FStartIndex + Child.FCount);
        Inc(ChildIndex);
        Continue;
      end;
    end;

    if not (FCursor.States^[StateIndex].CurrentToken in DIRECTIVE_INSIGNIFICANT_TOKENS) then
    begin
      Result[ResultCount] := StateIndex;
      Inc(ResultCount);
    end;
    Inc(StateIndex);
  end;
  SetLength(Result, ResultCount);
end;

function TBaseLexemeNode.FindOwnToken(AToken: TTokenKind): Integer;
var
  StateIndex: Integer;
begin
  for StateIndex in GetOwnTokenIndexes do
    if FCursor.States^[StateIndex].CurrentToken = AToken then
      Exit(StateIndex);
  Result := -1;
end;

{ TIdentifierLexemeNode }

function TIdentifierLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltIdentifier;
end;

function TIdentifierLexemeNode.GetLexemeDetails: string;
begin
  Result := FName;
end;

procedure TIdentifierLexemeNode.InternalParseItself;
begin
  FName := ExpectIdentifier(FAllowKeywords);
  if FIsQualified then
    while (PeekToken = tkPoint) and (IsIdentifier(1) or IsWordToken(1)) do
    begin
      NextToken;
      FName := FName + NAME_SEPARATOR + ExpectIdentifier(True);
    end;
end;

{ TAttributeListLexemeNode }

function TAttributeListLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltAttributeList;
end;

procedure TAttributeListLexemeNode.InternalParseItself;
begin
  ExpectToken(tkSquareOpen);
  repeat
    ParseChild(TAttributeLexemeNode);
  until not AcceptToken(tkComma);
  ExpectToken(tkSquareClose);
end;

{ TAttributeLexemeNode }

function TAttributeLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltAttribute;
end;

procedure TAttributeLexemeNode.InternalParseItself;
begin
  // Target of the attribute: [Result: Unsafe]
  if IsIdentifier and (PeekToken(GetIdentifierEndOffset) = tkColon) then
  begin
    ParseIdentifier(False);
    ExpectToken(tkColon);
  end;

  // Names of some attributes are keywords: [in]
  ParseIdentifier(True, True);
  if PeekToken = tkRoundOpen then
    ParseChild(TArgumentListLexemeNode);
end;

{ TGenericParametersLexemeNode }

function TGenericParametersLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltGenericParameters;
end;

procedure TGenericParametersLexemeNode.InternalParseItself;
begin
  ExpectToken(tkLower);
  repeat
    ParseAttributes;
    ParseIdentifier(False);
    // Constraints are separated by commas, the parameters with constraints by semicolons
    if AcceptToken(tkColon) then
      repeat
        if PeekToken in [tkClass, tkRecord, tkConstructor] then
          NextToken
        else
          ParseType;
      until not AcceptToken(tkComma);
  until not (AcceptToken(tkComma) or AcceptToken(tkSemiColon));
  ExpectToken(tkGreater);
end;

{ TGenericArgumentsLexemeNode }

function TGenericArgumentsLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltGenericArguments;
end;

procedure TGenericArgumentsLexemeNode.InternalParseItself;
begin
  ExpectToken(tkLower);
  repeat
    ParseType;
  until not AcceptToken(tkComma);
  ExpectToken(tkGreater);
end;

{ TBinaryExpressionLexemeNode }

function TBinaryExpressionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltBinaryExpression;
end;

function TBinaryExpressionLexemeNode.GetLexemeDetails: string;
begin
  Result := FCursor.States^[FOperatorIndex].TokenString;
end;

procedure TBinaryExpressionLexemeNode.InternalParseItself;
begin
  // The left operand is already the first child, see TBaseLexemeNode.ParseExpression
  FOperatorToken := PeekToken;
  FOperatorIndex := FCursor.GetStateIndex;
  NextToken;
  if FPrecedence = High(TExpressionPrecedence) then
    ParseFactor
  else
    ParseExpression(Succ(FPrecedence));
end;

{ TUnaryExpressionLexemeNode }

function TUnaryExpressionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltUnaryExpression;
end;

function TUnaryExpressionLexemeNode.GetLexemeDetails: string;
begin
  Result := FCursor.States^[FOperatorIndex].TokenString;
end;

procedure TUnaryExpressionLexemeNode.InternalParseItself;
begin
  FOperatorToken := PeekToken;
  FOperatorIndex := FCursor.GetStateIndex;
  NextToken;
  ParseFactor;
end;

{ TParenthesizedExpressionLexemeNode }

function TParenthesizedExpressionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltParenthesizedExpression;
end;

procedure TParenthesizedExpressionLexemeNode.InternalParseItself;
begin
  ExpectToken(tkRoundOpen);
  ParseExpression;
  ExpectToken(tkRoundClose);
end;

{ TDesignatorLexemeNode }

function TDesignatorLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltDesignator;
end;

procedure TDesignatorLexemeNode.InternalParseItself;
var
  AfterName: Boolean;
begin
  // A wrapping designator already has its first part: a literal or a parenthesized expression
  AfterName := False;
  if FChildCount = 0 then
  begin
    if PeekToken = tkString then
      NextToken // keyword string in a typecast: string(P)
    else
      ParseIdentifier(False);
    AfterName := True;
  end;

  while True do
  begin
    case PeekToken of
      tkPoint:
      begin
        NextToken;
        ParseIdentifier(False, True);
        AfterName := True;
        Continue;
      end;
      tkSquareOpen:
        ParseChild(TIndexListLexemeNode);
      tkRoundOpen:
        ParseChild(TArgumentListLexemeNode);
      tkPointerSymbol:
        NextToken;
      tkLower:
        if AfterName and IsGenericArgumentsAhead then
          ParseChild(TGenericArgumentsLexemeNode)
        else
          Break;
    else
      Break;
    end;
    AfterName := False;
  end;
end;

{ TLiteralLexemeNode }

function TLiteralLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltLiteral;
end;

function TLiteralLexemeNode.GetLexemeDetails: string;
begin
  Result := GetFirstState.TokenString;
end;

procedure TLiteralLexemeNode.InternalParseItself;
begin
  FLiteralToken := PeekToken;
  case FLiteralToken of
    tkString, tkAsciiChar:
    begin
      // Quoted strings and control characters written together make up one character string: #13#10'Text'#0
      NextToken;
      while ((PeekToken = tkAsciiChar) or IsStringLiteral) and (FCursor.GetStateIndex = FCursor.LastStateIndex + 1) do
        NextToken;
    end;
    tkPointerSymbol, tkSymbol:
    begin
      // Control character written with a caret (^M) or a number escaped with '&' (&17)
      NextToken;
      NextToken;
    end;
  else
    NextToken;
  end;
end;

{ TSetConstructorLexemeNode }

function TSetConstructorLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltSetConstructor;
end;

procedure TSetConstructorLexemeNode.InternalParseItself;
begin
  ExpectToken(tkSquareOpen);
  if PeekToken <> tkSquareClose then
    repeat
      ParseExpressionOrRange;
    until not AcceptToken(tkComma);
  ExpectToken(tkSquareClose);
end;

{ TRangeLexemeNode }

function TRangeLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltRange;
end;

procedure TRangeLexemeNode.InternalParseItself;
begin
  // The low bound is already the first child, see TBaseLexemeNode.ParseExpressionOrRange
  ExpectToken(tkDotDot);
  ParseExpression;
end;

{ TArgumentListLexemeNode }

function TArgumentListLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltArgumentList;
end;

procedure TArgumentListLexemeNode.InternalParseItself;
begin
  ExpectToken(tkRoundOpen);
  if PeekToken <> tkRoundClose then
    repeat
      ParseExpression;
      // Width and precision of the arguments of Write and Str: Str(Value:10:2, S)
      while AcceptToken(tkColon) do
        ParseExpression;
    until not AcceptToken(tkComma);
  ExpectToken(tkRoundClose);
end;

{ TIndexListLexemeNode }

function TIndexListLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltIndexList;
end;

procedure TIndexListLexemeNode.InternalParseItself;
begin
  ExpectToken(tkSquareOpen);
  repeat
    ParseExpression;
  until not AcceptToken(tkComma);
  ExpectToken(tkSquareClose);
end;

{ TAnonymousMethodLexemeNode }

function TAnonymousMethodLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltAnonymousMethod;
end;

procedure TAnonymousMethodLexemeNode.InternalParseItself;
begin
  FRoutineKind := PeekToken;
  NextToken;
  if PeekToken = tkRoundOpen then
    ParseChild(TFormalParametersLexemeNode);
  if AcceptToken(tkColon) then
    ParseType;
  // Calling convention: function(const AValue: T): HResult stdcall
  while IsDirectiveAhead(PROCEDURAL_DIRECTIVE_TOKENS) do
    ParseChild(TRoutineDirectiveLexemeNode);

  ParseDeclarations(dcLocal);
  if PeekToken = tkAsm then
    ParseChild(TAsmStatementLexemeNode)
  else
    ParseChild(TBeginEndBlockLexemeNode);
end;

{ TInheritedExpressionLexemeNode }

function TInheritedExpressionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltInheritedExpression;
end;

procedure TInheritedExpressionLexemeNode.InternalParseItself;
begin
  ExpectToken(tkInherited);
  if IsIdentifier then
    ParseChild(TDesignatorLexemeNode);
end;

{ TArrayConstantLexemeNode }

function TArrayConstantLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltArrayConstant;
end;

procedure TArrayConstantLexemeNode.InternalParseItself;
begin
  ExpectToken(tkRoundOpen);
  repeat
    ParseTypedConstant;
  until not AcceptToken(tkComma);
  ExpectToken(tkRoundClose);
end;

{ TRecordConstantLexemeNode }

function TRecordConstantLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltRecordConstant;
end;

procedure TRecordConstantLexemeNode.InternalParseItself;
begin
  ExpectToken(tkRoundOpen);
  while PeekToken <> tkRoundClose do
  begin
    ParseChild(TRecordConstantFieldLexemeNode);
    if not AcceptToken(tkSemiColon) then
      Break;
  end;
  ExpectToken(tkRoundClose);
end;

{ TRecordConstantFieldLexemeNode }

function TRecordConstantFieldLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltRecordConstantField;
end;

function TRecordConstantFieldLexemeNode.GetLexemeDetails: string;
begin
  Result := FName;
end;

procedure TRecordConstantFieldLexemeNode.InternalParseItself;
begin
  FName := ParseIdentifier(False).Name;
  ExpectToken(tkColon);
  ParseTypedConstant;
end;

{ TTypeIdentifierLexemeNode }

function TTypeIdentifierLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltTypeIdentifier;
end;

function TTypeIdentifierLexemeNode.GetLexemeDetails: string;
begin
  Result := FTypeName;
end;

procedure TTypeIdentifierLexemeNode.InternalParseItself;
begin
  FIsDistinct := AcceptToken(tkType);
  if (PeekToken = tkString) and not IsStringLiteral then
  begin
    FTypeName := PeekTokenString;
    NextToken;
    // Short string of the given length: string[20]
    if AcceptToken(tkSquareOpen) then
    begin
      ParseExpression;
      ExpectToken(tkSquareClose);
    end;
    Exit;
  end;

  FTypeName := ExpectIdentifier;
  if PeekToken = tkLower then
    ParseChild(TGenericArgumentsLexemeNode);
  while PeekToken = tkPoint do
  begin
    NextToken;
    FTypeName := FTypeName + NAME_SEPARATOR + ExpectIdentifier(True);
    if PeekToken = tkLower then
      ParseChild(TGenericArgumentsLexemeNode);
  end;

  // Code page of an ANSI string type: type AnsiString(1251)
  if FIsDistinct and AcceptToken(tkRoundOpen) then
  begin
    ParseExpression;
    ExpectToken(tkRoundClose);
  end;
end;

{ TSubrangeTypeLexemeNode }

function TSubrangeTypeLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltSubrangeType;
end;

procedure TSubrangeTypeLexemeNode.InternalParseItself;
begin
  ParseExpression;
  ExpectToken(tkDotDot);
  ParseExpression;
end;

{ TEnumTypeLexemeNode }

function TEnumTypeLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltEnumType;
end;

procedure TEnumTypeLexemeNode.InternalParseItself;
begin
  ExpectToken(tkRoundOpen);
  repeat
    ParseChild(TEnumElementLexemeNode);
  until not AcceptToken(tkComma);
  ExpectToken(tkRoundClose);
end;

{ TEnumElementLexemeNode }

function TEnumElementLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltEnumElement;
end;

function TEnumElementLexemeNode.GetLexemeDetails: string;
begin
  Result := FName;
end;

procedure TEnumElementLexemeNode.InternalParseItself;
begin
  FName := ParseIdentifier(False).Name;
  if AcceptToken(tkEqual) then
    ParseExpression;
end;

{ TSetTypeLexemeNode }

function TSetTypeLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltSetType;
end;

procedure TSetTypeLexemeNode.InternalParseItself;
begin
  AcceptToken(tkPacked);
  ExpectToken(tkSet);
  ExpectToken(tkOf);
  ParseType;
end;

{ TArrayTypeLexemeNode }

function TArrayTypeLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltArrayType;
end;

procedure TArrayTypeLexemeNode.InternalParseItself;
begin
  FIsPacked := AcceptToken(tkPacked);
  ExpectToken(tkArray);
  // Index types of a static array: array[0..9, Boolean] of
  if AcceptToken(tkSquareOpen) then
  begin
    repeat
      ParseType;
    until not AcceptToken(tkComma);
    ExpectToken(tkSquareClose);
  end;
  ExpectToken(tkOf);

  FIsArrayOfConst := AcceptToken(tkConst);
  if not FIsArrayOfConst then
    ParseType;
end;

{ TFileTypeLexemeNode }

function TFileTypeLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltFileType;
end;

procedure TFileTypeLexemeNode.InternalParseItself;
begin
  AcceptToken(tkPacked);
  ExpectToken(tkFile);
  if AcceptToken(tkOf) then
    ParseType;
end;

{ TPointerTypeLexemeNode }

function TPointerTypeLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltPointerType;
end;

procedure TPointerTypeLexemeNode.InternalParseItself;
begin
  ExpectToken(tkPointerSymbol);
  ParseType;
end;

{ TProceduralTypeLexemeNode }

function TProceduralTypeLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltProceduralType;
end;

procedure TProceduralTypeLexemeNode.InternalParseItself;
begin
  if IsWord(tkReference) then
  begin
    FIsReference := True;
    NextToken;
    ExpectToken(tkTo);
  end;

  if not (PeekToken in [tkProcedure, tkFunction]) then
    raise CreateUnexpectedError(EMESSAGE_EXPECTED_ROUTINE);
  FRoutineKind := PeekToken;
  NextToken;

  if PeekToken = tkRoundOpen then
    ParseChild(TFormalParametersLexemeNode);
  if AcceptToken(tkColon) then
  begin
    ParseAttributes;
    ParseType;
  end;

  while True do
  begin
    if (PeekToken = tkOf) and (PeekToken(1) = tkObject) then
    begin
      FIsMethodPointer := True;
      NextToken;
      NextToken;
    end
    else if IsDirectiveAhead(PROCEDURAL_DIRECTIVE_TOKENS) then
      ParseChild(TRoutineDirectiveLexemeNode)
    else if (PeekToken = tkSemiColon) and (PeekToken(1) in PROCEDURAL_DIRECTIVE_TOKENS)
        and (PeekToken(2) in PROCEDURAL_DIRECTIVE_FOLLOW_TOKENS)
    then
    begin
      // A calling convention may follow a semicolon: TCallback = procedure(AValue: Integer); stdcall;
      NextToken;
      ParseChild(TRoutineDirectiveLexemeNode);
    end
    else
      Break;
  end;
end;

{ TStructuredTypeLexemeNode }

procedure TStructuredTypeLexemeNode.ParseMembers(AStructureKind: TStructureKind);
var
  Section: TVisibilitySectionLexemeNode;
begin
  while True do
    if IsVisibilityAhead then
    begin
      Section := TVisibilitySectionLexemeNode.Create(Self);
      Section.FStructureKind := AStructureKind;
      Section.ParseItself;
    end
    else if not ParseStructureMember(AStructureKind) then
      Break;
end;

procedure TStructuredTypeLexemeNode.ParseAncestors;
begin
  ExpectToken(tkRoundOpen);
  repeat
    ParseType;
  until not AcceptToken(tkComma);
  ExpectToken(tkRoundClose);
end;

{ TClassTypeLexemeNode }

function TClassTypeLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltClassType;
end;

procedure TClassTypeLexemeNode.InternalParseItself;
begin
  FModifier := tkUnknown;
  FIsPacked := AcceptToken(tkPacked);
  ExpectToken(tkClass);
  if PeekToken = tkSemiColon then
  begin
    FIsForward := True;
    Exit;
  end;

  if PeekToken in [tkAbstract, tkSealed] then
  begin
    FModifier := PeekToken;
    NextToken;
  end;

  if IsWord(tkHelper) then
  begin
    FIsHelper := True;
    NextToken;
    if PeekToken = tkRoundOpen then
      ParseAncestors;
    ExpectToken(tkFor);
    ParseType;
  end
  else if PeekToken = tkRoundOpen then
    ParseAncestors;

  // A class without members: TFoo = class(TBar);
  if PeekToken = tkSemiColon then
    Exit;

  ParseMembers(skClass);
  ExpectToken(tkEnd);
end;

{ TClassReferenceTypeLexemeNode }

function TClassReferenceTypeLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltClassReferenceType;
end;

procedure TClassReferenceTypeLexemeNode.InternalParseItself;
begin
  ExpectToken(tkClass);
  ExpectToken(tkOf);
  ParseType;
end;

{ TRecordTypeLexemeNode }

function TRecordTypeLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltRecordType;
end;

procedure TRecordTypeLexemeNode.InternalParseItself;
begin
  FIsPacked := AcceptToken(tkPacked);
  ExpectToken(tkRecord);
  if IsWord(tkHelper) and (PeekToken(1) = tkFor) then
  begin
    FIsHelper := True;
    NextToken;
    NextToken;
    ParseType;
  end;

  ParseMembers(skRecord);
  ExpectToken(tkEnd);
  // Alignment of the record: end align 8
  if IsText(ALIGN_WORD) then
  begin
    NextToken;
    ParseExpression;
  end;
end;

{ TObjectTypeLexemeNode }

function TObjectTypeLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltObjectType;
end;

procedure TObjectTypeLexemeNode.InternalParseItself;
begin
  FIsPacked := AcceptToken(tkPacked);
  ExpectToken(tkObject);
  if PeekToken = tkRoundOpen then
    ParseAncestors;

  ParseMembers(skObject);
  ExpectToken(tkEnd);
end;

{ TInterfaceTypeLexemeNode }

function TInterfaceTypeLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltInterfaceType;
end;

procedure TInterfaceTypeLexemeNode.InternalParseItself;
begin
  FIsDispInterface := PeekToken = tkDispinterface;
  if not AcceptToken(tkDispinterface) then
    ExpectToken(tkInterface);
  if PeekToken = tkSemiColon then
  begin
    FIsForward := True;
    Exit;
  end;

  if PeekToken = tkRoundOpen then
    ParseAncestors;
  if PeekToken = tkSquareOpen then
    ParseChild(TInterfaceGuidLexemeNode);

  ParseMembers(skInterface);
  ExpectToken(tkEnd);
end;

{ TVisibilitySectionLexemeNode }

function TVisibilitySectionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltVisibilitySection;
end;

function TVisibilitySectionLexemeNode.GetLexemeDetails: string;
begin
  Result := FTokenWords[FVisibility];
end;

procedure TVisibilitySectionLexemeNode.InternalParseItself;
begin
  FIsStrict := AcceptToken(tkStrict);
  if not (PeekToken in VISIBILITY_TOKENS) then
    raise CreateUnexpectedError(EMESSAGE_EXPECTED_VISIBILITY);
  FVisibility := PeekToken;
  NextToken;

  while not IsVisibilityAhead do
    if not ParseStructureMember(FStructureKind) then
      Break;
end;

{ TPropertyLexemeNode }

function TPropertyLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltProperty;
end;

function TPropertyLexemeNode.GetLexemeDetails: string;
begin
  Result := FName;
end;

procedure TPropertyLexemeNode.InternalParseItself;
begin
  ParseAttributes;
  FIsClassProperty := AcceptToken(tkClass);
  ExpectToken(tkProperty);
  FName := ParseIdentifier(False).Name;
  if PeekToken = tkSquareOpen then
    ParseChild(TFormalParametersLexemeNode);
  if AcceptToken(tkColon) then
    ParseType;

  // Specifiers are recognized by the text: the lexer resets the property state at the semicolons of the parameters
  while True do
    if IsWordIn([tkIndex, tkRead, tkWrite, tkStored, tkDefault, tkDispid]) then
    begin
      NextToken;
      ParseExpression;
    end
    else if IsWordIn([tkNodefault, tkReadonly, tkWriteonly]) then
      NextToken
    else if IsWord(tkImplements) then
    begin
      NextToken;
      repeat
        ParseType;
      until not AcceptToken(tkComma);
    end
    else
      Break;

  if PeekToken <> tkEnd then
    ExpectToken(tkSemiColon);
  // Default array property: property Items[Index: Integer]: TItem read GetItem; default;
  if IsWord(tkDefault) and (PeekToken(1) = tkSemiColon) then
  begin
    FIsDefault := True;
    NextToken;
    NextToken;
  end;
end;

{ TInterfaceGuidLexemeNode }

function TInterfaceGuidLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltInterfaceGuid;
end;

procedure TInterfaceGuidLexemeNode.InternalParseItself;
begin
  ExpectToken(tkSquareOpen);
  ParseExpression;
  ExpectToken(tkSquareClose);
end;

{ TVariantPartLexemeNode }

function TVariantPartLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltVariantPart;
end;

procedure TVariantPartLexemeNode.InternalParseItself;
begin
  ExpectToken(tkCase);
  // Tag field: case Kind: TKind of
  if IsIdentifier and (PeekToken(GetIdentifierEndOffset) = tkColon) then
  begin
    ParseIdentifier(False);
    ExpectToken(tkColon);
  end;
  ParseType;
  ExpectToken(tkOf);

  repeat
    ParseChild(TVariantLexemeNode);
  until PeekToken in [tkEnd, tkRoundClose, tkEOF];
end;

{ TVariantLexemeNode }

function TVariantLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltVariant;
end;

procedure TVariantLexemeNode.InternalParseItself;
begin
  repeat
    ParseExpression;
  until not AcceptToken(tkComma);
  ExpectToken(tkColon);

  ExpectToken(tkRoundOpen);
  while PeekToken <> tkRoundClose do
    if PeekToken = tkCase then
      ParseChild(TVariantPartLexemeNode)
    else
      ParseChild(TFieldDeclarationLexemeNode);
  ExpectToken(tkRoundClose);
  AcceptToken(tkSemiColon);
end;

{ TFormalParametersLexemeNode }

function TFormalParametersLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltFormalParameters;
end;

procedure TFormalParametersLexemeNode.InternalParseItself;
var
  ClosingToken: TTokenKind;
begin
  if PeekToken = tkSquareOpen then
    ClosingToken := tkSquareClose
  else
  begin
    ClosingToken := tkRoundClose;
    if PeekToken <> tkRoundOpen then
      raise CreateUnexpectedError(TOKEN_NAMES[tkRoundOpen]);
  end;
  NextToken;

  if PeekToken <> ClosingToken then
    repeat
      ParseChild(TParameterLexemeNode);
    until not AcceptToken(tkSemiColon);
  ExpectToken(ClosingToken);
end;

{ TParameterLexemeNode }

function TParameterLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltParameter;
end;

procedure TParameterLexemeNode.InternalParseItself;
begin
  FModifier := tkUnknown;
  ParseAttributes;
  if (PeekToken in [tkVar, tkConst]) or (IsWord(tkOut) and IsIdentifier(1)) then
  begin
    FModifier := PeekToken;
    NextToken;
  end;

  repeat
    // Attribute of a parameter after the modifier: const [Ref] AFirst, [Ref] ASecond: TGUID
    ParseAttributes;
    ParseIdentifier(False);
  until not AcceptToken(tkComma);
  // Untyped parameters have no type: var ABuffer
  if AcceptToken(tkColon) then
    ParseType;
  if AcceptToken(tkEqual) then
    ParseExpression;
end;

{ TRoutineDirectiveLexemeNode }

function TRoutineDirectiveLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltRoutineDirective;
end;

function TRoutineDirectiveLexemeNode.GetLexemeDetails: string;
begin
  Result := FTokenWords[FDirective];
end;

procedure TRoutineDirectiveLexemeNode.InternalParseItself;
begin
  FDirective := PeekToken;
  NextToken;
  case FDirective of
    tkExternal:
    begin
      // external [Library] [name Name] [index Index] [delayed] [dependency Library, ...]
      if not ((PeekToken = tkSemiColon) or IsWordIn([tkName, tkIndex, tkDelayed]) or IsText(DEPENDENCY_WORD)) then
        ParseExpression;
      while True do
        if IsWordIn([tkName, tkIndex]) then
        begin
          NextToken;
          ParseExpression;
        end
        else if IsText(DEPENDENCY_WORD) then
        begin
          NextToken;
          repeat
            ParseExpression;
          until not AcceptToken(tkComma);
        end
        else if IsWord(tkDelayed) then
          NextToken
        else
          Break;
    end;
    tkMessage, tkDispid:
      ParseExpression;
    tkDeprecated:
      if IsStringLiteral then
        ParseExpression;
  end;
end;

{ TRoutineHeadingLexemeNode }

procedure TRoutineHeadingLexemeNode.ParseName;
begin
  // Names of operators are keywords sometimes: class operator In(...)
  FName := ExpectIdentifier(FRoutineKind = tkOperator);
  if PeekToken = tkLower then
    ParseChild(TGenericParametersLexemeNode);
  // Qualified name of an implementation: TFoo<T>.TBar.Baz
  while PeekToken = tkPoint do
  begin
    NextToken;
    FName := FName + NAME_SEPARATOR + ExpectIdentifier(True);
    if PeekToken = tkLower then
      ParseChild(TGenericParametersLexemeNode);
  end;
end;

function TRoutineHeadingLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltRoutineHeading;
end;

function TRoutineHeadingLexemeNode.GetLexemeDetails: string;
begin
  Result := Format(ROUTINE_DETAILS_FORMAT, [FTokenWords[FRoutineKind], FName]);
end;

procedure TRoutineHeadingLexemeNode.InternalParseItself;
var
  Directive: TRoutineDirectiveLexemeNode;
begin
  ParseAttributes;
  FIsClassMethod := AcceptToken(tkClass);
  if not (PeekToken in METHOD_TOKENS) then
    raise CreateUnexpectedError(EMESSAGE_EXPECTED_ROUTINE);
  FRoutineKind := PeekToken;
  NextToken;
  ParseName;

  // Method resolution clause: procedure IFoo.Bar = DoBar;
  if AcceptToken(tkEqual) then
  begin
    FIsMethodResolution := True;
    ParseIdentifier(False);
    ExpectToken(tkSemiColon);
    Exit;
  end;

  if PeekToken = tkRoundOpen then
    ParseChild(TFormalParametersLexemeNode);
  if AcceptToken(tkColon) then
  begin
    ParseAttributes;
    ParseType;
  end;

  if not AcceptToken(tkSemiColon) and not IsDirectiveAhead(ROUTINE_DIRECTIVE_TOKENS) then
    raise CreateUnexpectedError(TOKEN_NAMES[tkSemiColon]);
  while IsDirectiveAhead(ROUTINE_DIRECTIVE_TOKENS) do
  begin
    Directive := TRoutineDirectiveLexemeNode(ParseChild(TRoutineDirectiveLexemeNode));
    case Directive.Directive of
      tkForward:
        FIsForward := True;
      tkExternal:
        FIsExternal := True;
    end;
    // The compiler accepts the last directive without the semicolon: function Foo: Integer; inline
    AcceptToken(tkSemiColon);
  end;
end;

{ TRoutineLexemeNode }

function TRoutineLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltRoutine;
end;

procedure TRoutineLexemeNode.InternalParseItself;
begin
  FHeading := TRoutineHeadingLexemeNode(ParseChild(TRoutineHeadingLexemeNode));
  if FHeading.IsForward or FHeading.IsExternal or FHeading.IsMethodResolution then
    Exit;

  ParseDeclarations(dcLocal);
  if PeekToken = tkAsm then
    FBody := ParseChild(TAsmStatementLexemeNode)
  else
    FBody := ParseChild(TBeginEndBlockLexemeNode);
  ExpectToken(tkSemiColon);
end;

{ TLabelSectionLexemeNode }

function TLabelSectionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltLabelSection;
end;

procedure TLabelSectionLexemeNode.InternalParseItself;
begin
  ExpectToken(tkLabel);
  repeat
    if PeekToken in [tkNumber, tkInteger] then
      NextToken
    else
      ParseIdentifier(False);
  until not AcceptToken(tkComma);
  ExpectToken(tkSemiColon);
end;

{ TConstSectionLexemeNode }

function TConstSectionLexemeNode.GetNodeType: TLexemeType;
begin
  if FKeyword = tkResourcestring then
    Result := ltResourceStringSection
  else
    Result := ltConstSection;
end;

procedure TConstSectionLexemeNode.InternalParseItself;
begin
  FKeyword := PeekToken;
  if not AcceptToken(tkResourcestring) then
    ExpectToken(tkConst);

  repeat
    ParseChild(TConstDeclarationLexemeNode);
  until not IsDeclarationAhead([tkEqual, tkColon]);
end;

{ TTypeSectionLexemeNode }

function TTypeSectionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltTypeSection;
end;

procedure TTypeSectionLexemeNode.InternalParseItself;
begin
  ExpectToken(tkType);
  repeat
    ParseChild(TTypeDeclarationLexemeNode);
  until not IsDeclarationAhead([tkEqual, tkLower]);
end;

{ TVarSectionLexemeNode }

function TVarSectionLexemeNode.GetNodeType: TLexemeType;
begin
  if FKeyword = tkThreadvar then
    Result := ltThreadVarSection
  else
    Result := ltVarSection;
end;

procedure TVarSectionLexemeNode.InternalParseItself;
begin
  FIsClassVar := AcceptToken(tkClass);
  FKeyword := PeekToken;
  if not AcceptToken(tkThreadvar) then
    ExpectToken(tkVar);

  // The compiler accepts an empty section in a structured type: private class var class var FInstance: TFoo;
  while IsDeclarationAhead([tkColon, tkComma]) do
    if FIsFieldSection then
      ParseChild(TFieldDeclarationLexemeNode)
    else
      ParseChild(TVarDeclarationLexemeNode);
end;

{ TExportsLexemeNode }

function TExportsLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltExports;
end;

procedure TExportsLexemeNode.InternalParseItself;
begin
  ExpectToken(tkExports);
  repeat
    ParseChild(TExportsItemLexemeNode);
  until not AcceptToken(tkComma);
  ExpectToken(tkSemiColon);
end;

{ TExportsItemLexemeNode }

function TExportsItemLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltExportsItem;
end;

function TExportsItemLexemeNode.GetLexemeDetails: string;
begin
  Result := FName;
end;

procedure TExportsItemLexemeNode.InternalParseItself;
begin
  FName := ParseIdentifier(True).Name;
  // Parameters of an overloaded routine
  if PeekToken = tkRoundOpen then
    ParseChild(TFormalParametersLexemeNode);

  while True do
    if IsWordIn([tkIndex, tkName]) then
    begin
      NextToken;
      ParseExpression;
    end
    else if IsWord(tkResident) then
      NextToken
    else
      Break;
end;

{ TConstDeclarationLexemeNode }

function TConstDeclarationLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltConstDeclaration;
end;

function TConstDeclarationLexemeNode.GetLexemeDetails: string;
begin
  Result := FName;
end;

procedure TConstDeclarationLexemeNode.InternalParseItself;
begin
  ParseAttributes;
  FName := ParseIdentifier(False).Name;
  if AcceptToken(tkColon) then
  begin
    ParseType;
    ExpectToken(tkEqual);
    ParseTypedConstant;
  end
  else
  begin
    ExpectToken(tkEqual);
    ParseExpression;
  end;

  ParsePortabilityDirectives;
  ExpectToken(tkSemiColon);
end;

{ TTypeDeclarationLexemeNode }

function TTypeDeclarationLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltTypeDeclaration;
end;

function TTypeDeclarationLexemeNode.GetLexemeDetails: string;
begin
  Result := FName;
end;

procedure TTypeDeclarationLexemeNode.InternalParseItself;
begin
  ParseAttributes;
  FName := ParseIdentifier(False).Name;
  if PeekToken = tkLower then
    ParseChild(TGenericParametersLexemeNode);
  ExpectToken(tkEqual);
  ParseType;

  ParsePortabilityDirectives;
  ExpectToken(tkSemiColon);
end;

{ TVarDeclarationLexemeNode }

function TVarDeclarationLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltVarDeclaration;
end;

procedure TVarDeclarationLexemeNode.InternalParseItself;
begin
  ParseAttributes;
  repeat
    ParseIdentifier(False);
  until not AcceptToken(tkComma);
  ExpectToken(tkColon);
  ParseType;

  // Variable at the address of another one, or an initialized global variable
  if IsWord(tkAbsolute) then
  begin
    NextToken;
    ParseExpression;
  end
  else if AcceptToken(tkEqual) then
    ParseTypedConstant;

  ParsePortabilityDirectives;
  ParseDeclarationEnd;
end;

procedure TVarDeclarationLexemeNode.ParseDeclarationEnd;
begin
  ExpectToken(tkSemiColon);
end;

{ TFieldDeclarationLexemeNode }

function TFieldDeclarationLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltFieldDeclaration;
end;

procedure TFieldDeclarationLexemeNode.ParseDeclarationEnd;
begin
  // The semicolon is optional after the last field of a record or of a variant
  if not (PeekToken in [tkEnd, tkRoundClose]) then
    ExpectToken(tkSemiColon);
end;

{ TBeginEndBlockLexemeNode }

function TBeginEndBlockLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltBeginEnd;
end;

procedure TBeginEndBlockLexemeNode.InternalParseItself;
begin
  ExpectToken(tkBegin);
  if FIsMainBlock then
  begin
    ParseStatementList([tkEnd, tkUnitEnd]);
    ParseModuleEnd;
  end
  else
  begin
    ParseStatementList([tkEnd]);
    ExpectToken(tkEnd);
  end;
end;

{ TSimpleStatementLexemeNode }

function TSimpleStatementLexemeNode.GetNodeType: TLexemeType;
begin
  if FIsAssignment then
    Result := ltAssignment
  else
    Result := ltCallStatement;
end;

procedure TSimpleStatementLexemeNode.InternalParseItself;
begin
  ParseExpression;
  FIsAssignment := AcceptToken(tkAssign);
  if FIsAssignment then
    ParseExpression;
end;

{ TLabeledStatementLexemeNode }

function TLabeledStatementLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltLabeledStatement;
end;

procedure TLabeledStatementLexemeNode.InternalParseItself;
begin
  if PeekToken in [tkNumber, tkInteger] then
    NextToken
  else
    ParseIdentifier(False);
  ExpectToken(tkColon);
  ParseStatement;
end;

{ TGotoStatementLexemeNode }

function TGotoStatementLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltGotoStatement;
end;

procedure TGotoStatementLexemeNode.InternalParseItself;
begin
  ExpectToken(tkGoto);
  if PeekToken in [tkNumber, tkInteger] then
    NextToken
  else if IsIdentifier then
    ParseIdentifier(False)
  else
    raise CreateUnexpectedError(EMESSAGE_EXPECTED_LABEL);
end;

{ TIfStatementLexemeNode }

function TIfStatementLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltIfStatement;
end;

procedure TIfStatementLexemeNode.InternalParseItself;
begin
  ExpectToken(tkIf);
  FCondition := ParseExpression;
  ExpectToken(tkThen);
  FThenStatement := ParseStatement;
  if AcceptToken(tkElse) then
    FElseStatement := ParseStatement;
end;

{ TCaseStatementLexemeNode }

function TCaseStatementLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltCaseStatement;
end;

procedure TCaseStatementLexemeNode.InternalParseItself;
begin
  ExpectToken(tkCase);
  ParseExpression;
  ExpectToken(tkOf);

  while not (PeekToken in [tkElse, tkEnd]) do
  begin
    ParseChild(TCaseItemLexemeNode);
    if not AcceptToken(tkSemiColon) and not (PeekToken in [tkElse, tkEnd]) then
      raise CreateUnexpectedError(TOKEN_NAMES[tkSemiColon]);
  end;

  if PeekToken = tkElse then
    ParseChild(TElseBlockLexemeNode);
  ExpectToken(tkEnd);
end;

{ TCaseItemLexemeNode }

function TCaseItemLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltCaseItem;
end;

procedure TCaseItemLexemeNode.InternalParseItself;
begin
  repeat
    ParseExpressionOrRange;
  until not AcceptToken(tkComma);
  ExpectToken(tkColon);
  ParseStatement;
end;

{ TElseBlockLexemeNode }

function TElseBlockLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltElseBlock;
end;

procedure TElseBlockLexemeNode.InternalParseItself;
begin
  ExpectToken(tkElse);
  ParseStatementList([tkEnd]);
end;

{ TRepeatStatementLexemeNode }

function TRepeatStatementLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltRepeatStatement;
end;

procedure TRepeatStatementLexemeNode.InternalParseItself;
begin
  ExpectToken(tkRepeat);
  ParseStatementList([tkUntil]);
  ExpectToken(tkUntil);
  ParseExpression;
end;

{ TWhileStatementLexemeNode }

function TWhileStatementLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltWhileStatement;
end;

procedure TWhileStatementLexemeNode.InternalParseItself;
begin
  ExpectToken(tkWhile);
  ParseExpression;
  ExpectToken(tkDo);
  ParseStatement;
end;

{ TForStatementLexemeNode }

function TForStatementLexemeNode.GetNodeType: TLexemeType;
begin
  if FIsForIn then
    Result := ltForInStatement
  else
    Result := ltForStatement;
end;

procedure TForStatementLexemeNode.InternalParseItself;
begin
  ExpectToken(tkFor);
  FIsInlineVar := AcceptToken(tkVar);
  ParseIdentifier(False);
  if FIsInlineVar and AcceptToken(tkColon) then
    ParseType;

  FIsForIn := AcceptToken(tkIn);
  if FIsForIn then
    ParseExpression
  else
  begin
    ExpectToken(tkAssign);
    ParseExpression;
    FIsDownto := AcceptToken(tkDownto);
    if not FIsDownto then
      ExpectToken(tkTo);
    ParseExpression;
  end;

  ExpectToken(tkDo);
  ParseStatement;
end;

{ TWithStatementLexemeNode }

function TWithStatementLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltWithStatement;
end;

procedure TWithStatementLexemeNode.InternalParseItself;
begin
  ExpectToken(tkWith);
  repeat
    ParseExpression;
  until not AcceptToken(tkComma);
  ExpectToken(tkDo);
  ParseStatement;
end;

{ TTryStatementLexemeNode }

function TTryStatementLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltTryStatement;
end;

procedure TTryStatementLexemeNode.InternalParseItself;
begin
  ExpectToken(tkTry);
  ParseStatementList([tkExcept, tkFinally]);
  case PeekToken of
    tkExcept:
      ParseChild(TExceptBlockLexemeNode);
    tkFinally:
      ParseChild(TFinallyBlockLexemeNode);
  else
    raise CreateUnexpectedError(EMESSAGE_EXPECTED_EXCEPT_OR_FINALLY);
  end;
  ExpectToken(tkEnd);
end;

{ TExceptBlockLexemeNode }

function TExceptBlockLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltExceptBlock;
end;

procedure TExceptBlockLexemeNode.InternalParseItself;
begin
  ExpectToken(tkExcept);
  if not (IsText(ON_WORD) and IsIdentifier(1)) then
  begin
    ParseStatementList([tkEnd]);
    Exit;
  end;

  while IsText(ON_WORD) and IsIdentifier(1) do
  begin
    ParseChild(TExceptionHandlerLexemeNode);
    if not AcceptToken(tkSemiColon) and not (PeekToken in [tkElse, tkEnd]) then
      raise CreateUnexpectedError(TOKEN_NAMES[tkSemiColon]);
  end;
  if PeekToken = tkElse then
    ParseChild(TElseBlockLexemeNode);
end;

{ TExceptionHandlerLexemeNode }

function TExceptionHandlerLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltExceptionHandler;
end;

procedure TExceptionHandlerLexemeNode.InternalParseItself;
begin
  NextToken; // on
  if IsIdentifier and (PeekToken(GetIdentifierEndOffset) = tkColon) then
  begin
    ParseIdentifier(False);
    ExpectToken(tkColon);
  end;
  ParseType;
  ExpectToken(tkDo);
  ParseStatement;
end;

{ TFinallyBlockLexemeNode }

function TFinallyBlockLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltFinallyBlock;
end;

procedure TFinallyBlockLexemeNode.InternalParseItself;
begin
  ExpectToken(tkFinally);
  ParseStatementList([tkEnd]);
end;

{ TRaiseStatementLexemeNode }

function TRaiseStatementLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltRaiseStatement;
end;

procedure TRaiseStatementLexemeNode.InternalParseItself;
begin
  ExpectToken(tkRaise);
  if PeekToken in STATEMENT_END_TOKENS then
    Exit;

  ParseExpression;
  // Address of the exception: raise E at ReturnAddress
  if IsText(AT_WORD) then
  begin
    NextToken;
    ParseExpression;
  end;
end;

{ TAsmStatementLexemeNode }

function TAsmStatementLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltAsmStatement;
end;

procedure TAsmStatementLexemeNode.InternalParseItself;
begin
  ExpectToken(tkAsm);
  // The block ends at the first word end that is not a label after '@': JMP @@End ... @@End: RET
  while (PeekToken <> tkEOF)
      and ((PeekToken <> tkEnd) or (FCursor.States^[FCursor.LastStateIndex].CurrentToken = tkAddressSymbol))
  do
    NextToken;
  ExpectToken(tkEnd);
end;

{ TInlineVarDeclarationLexemeNode }

function TInlineVarDeclarationLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltInlineVarDeclaration;
end;

procedure TInlineVarDeclarationLexemeNode.InternalParseItself;
begin
  ExpectToken(tkVar);
  repeat
    ParseIdentifier(False);
  until not AcceptToken(tkComma);
  if AcceptToken(tkColon) then
    ParseType;
  if AcceptToken(tkAssign) then
    ParseExpression;
end;

{ TInlineConstDeclarationLexemeNode }

function TInlineConstDeclarationLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltInlineConstDeclaration;
end;

procedure TInlineConstDeclarationLexemeNode.InternalParseItself;
begin
  ExpectToken(tkConst);
  ParseIdentifier(False);
  if AcceptToken(tkColon) then
    ParseType;
  ExpectToken(tkEqual);
  ParseExpression;
end;

{ TUsesClauseLexemeNode }

function TUsesClauseLexemeNode.GetNodeType: TLexemeType;
begin
  case FKeyword of
    tkRequires:
      Result := ltRequires;
    tkContains:
      Result := ltContains;
  else
    Result := ltUses;
  end;
end;

procedure TUsesClauseLexemeNode.InternalParseItself;
begin
  if IsWord(tkRequires) then
    FKeyword := tkRequires
  else if IsWord(tkContains) then
    FKeyword := tkContains
  else if PeekToken = tkUses then
    FKeyword := tkUses
  else
    raise CreateUnexpectedError(TOKEN_NAMES[tkUses]);
  NextToken;

  repeat
    ParseChild(TUsesItemLexemeNode);
  until not AcceptToken(tkComma);
  ExpectToken(tkSemiColon);
end;

{ TUsesItemLexemeNode }

function TUsesItemLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltUsesItem;
end;

function TUsesItemLexemeNode.GetLexemeDetails: string;
begin
  Result := FModuleName;
end;

procedure TUsesItemLexemeNode.InternalParseItself;
begin
  FModuleName := ParseIdentifier(True).Name;
  if AcceptToken(tkIn) then
  begin
    if not IsStringLiteral then
      raise CreateUnexpectedError(TOKEN_NAMES[tkString]);
    FFileName := PeekTokenString;
    ParseChild(TLiteralLexemeNode);
  end;
end;

{ TInterfaceSectionLexemeNode }

function TInterfaceSectionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltInterface;
end;

procedure TInterfaceSectionLexemeNode.InternalParseItself;
begin
  ExpectToken(tkInterface);
  if PeekToken = tkUses then
    ParseChild(TUsesClauseLexemeNode);

  ParseDeclarations(dcInterface);
  if PeekToken <> tkImplementation then
    raise CreateUnexpectedError(EMESSAGE_EXPECTED_DECLARATION);
end;

{ TImplementationSectionLexemeNode }

function TImplementationSectionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltImplementation;
end;

procedure TImplementationSectionLexemeNode.InternalParseItself;
begin
  ExpectToken(tkImplementation);
  if PeekToken = tkUses then
    ParseChild(TUsesClauseLexemeNode);

  ParseDeclarations(dcImplementation);
  if not (PeekToken in [tkInitialization, tkFinalization, tkBegin, tkEnd, tkUnitEnd]) then
    raise CreateUnexpectedError(EMESSAGE_EXPECTED_DECLARATION);
end;

{ TInitializationSectionLexemeNode }

function TInitializationSectionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltInitialization;
end;

procedure TInitializationSectionLexemeNode.InternalParseItself;
begin
  ExpectToken(tkInitialization);
  ParseStatementList([tkFinalization, tkEnd, tkUnitEnd]);
end;

{ TFinalizationSectionLexemeNode }

function TFinalizationSectionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltFinalization;
end;

procedure TFinalizationSectionLexemeNode.InternalParseItself;
begin
  ExpectToken(tkFinalization);
  ParseStatementList([tkEnd, tkUnitEnd]);
end;

{ TModuleLexemeNode }

function TModuleLexemeNode.GetLexemeDetails: string;
begin
  Result := FModuleName;
end;

{ TUnitLexemeNode }

function TUnitLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltUnit;
end;

procedure TUnitLexemeNode.InternalParseItself;
begin
  ExpectToken(tkUnit);
  FModuleName := ParseIdentifier(True).Name;
  ParsePortabilityDirectives;
  ExpectToken(tkSemiColon);

  ParseChild(TInterfaceSectionLexemeNode);
  ParseChild(TImplementationSectionLexemeNode);

  case PeekToken of
    tkInitialization:
    begin
      ParseChild(TInitializationSectionLexemeNode);
      if PeekToken = tkFinalization then
        ParseChild(TFinalizationSectionLexemeNode);
    end;
    tkFinalization:
      ParseChild(TFinalizationSectionLexemeNode);
    tkBegin:
    begin
      // Old style initialization: begin ... end.
      ParseMainBlock;
      Exit;
    end;
  end;
  ParseModuleEnd;
end;

{ TProgramLexemeNode }

function TProgramLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltProgram;
end;

procedure TProgramLexemeNode.InternalParseItself;
begin
  if not AcceptToken(tkLibrary) then
    ExpectToken(tkProgram);
  FModuleName := ParseIdentifier(True).Name;
  // Parameters of a program: program Foo(Input, Output);
  if AcceptToken(tkRoundOpen) then
  begin
    repeat
      ParseIdentifier(False);
    until not AcceptToken(tkComma);
    ExpectToken(tkRoundClose);
  end;
  ParsePortabilityDirectives;
  ExpectToken(tkSemiColon);

  if PeekToken = tkUses then
    ParseChild(TUsesClauseLexemeNode);
  ParseDeclarations(dcImplementation);

  case PeekToken of
    tkBegin:
      ParseMainBlock;
    tkEnd, tkUnitEnd:
      ParseModuleEnd;
  else
    raise CreateUnexpectedError(EMESSAGE_EXPECTED_DECLARATION);
  end;
end;

{ TLibraryLexemeNode }

function TLibraryLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltLibrary;
end;

{ TPackageLexemeNode }

function TPackageLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltPackage;
end;

procedure TPackageLexemeNode.InternalParseItself;
begin
  ExpectToken(tkPackage);
  FModuleName := ParseIdentifier(True).Name;
  ExpectToken(tkSemiColon);

  if IsWord(tkRequires) then
    ParseChild(TUsesClauseLexemeNode);
  if IsWord(tkContains) then
    ParseChild(TUsesClauseLexemeNode);
  ParseModuleEnd;
end;

{ TRootLexemeNode }

constructor TRootLexemeNode.Create(AStates: PLexerStateArray; AStatesCount: Integer);
begin
  inherited Create(nil);

  FCursor := TLexemeCursor.Create(AStates, AStatesCount);
end;

destructor TRootLexemeNode.Destroy;
begin
  // The children do not use the cursor when they are destroyed
  FreeAndNil(FCursor);

  inherited Destroy;
end;

function TRootLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltRoot;
end;

procedure TRootLexemeNode.InternalParseItself;
begin
  // Everything after the end of the module is ignored, as the compiler does
  case PeekToken of
    tkUnit:
      ParseChild(TUnitLexemeNode);
    tkProgram:
      ParseChild(TProgramLexemeNode);
    tkLibrary:
      ParseChild(TLibraryLexemeNode);
    tkPackage:
      ParseChild(TPackageLexemeNode);
  else
    raise CreateUnexpectedError(EMESSAGE_EXPECTED_MODULE);
  end;
end;

procedure TRootLexemeNode.FinalizeNodeEnd;
begin
  FStartIndex := 0;
  FCount := FCursor.StatesCount;
end;

end.
