unit TestuPasParser;

{
  Tests for TPasParser and the lexeme tree of uPasParserGrammar: modules, declarations, types, statements and
  expressions of the Delphi language, syntax errors and the layout data used by code style checks.
}

interface

uses
  System.SysUtils, System.IOUtils, TestFramework,
  uPasLexerTypes, uPasExceptions, uPasParser, uPasParserTypes, uPasParserGrammar;

type
  TestTPasParser = class(TTestCase)
  private
    FParser: TPasParser;

    function GetTestDataFileName(const AFileName: string): string;
    // Wraps declarations into a unit: AInterface goes to the interface section, AImplementation to the implementation
    function MakeUnit(const AInterface, AImplementation: string): string;
    // Wraps statements into the body of a procedure of a unit
    function MakeStatements(const AStatements: string): string;
    // Parses ASource and fails the test with the first parser error when the source is not parsed
    procedure CheckParsed(const ASource: string; const AMessage: string = '');
    procedure CheckParsedFile(const AFileName: string);
    // Parses ASource and checks that it fails at the given position
    procedure CheckParseError(const ASource: string; ALineNumber, ALinePosition: Integer; const AMessage: string = '');
    // Returns the node of ALexemeType with the index AIndex among such nodes in the tree order; fails if there is none
    function FindNode(ALexemeType: TLexemeType; AIndex: Integer = 0): TBaseLexemeNode;
    function CountNodes(ALexemeType: TLexemeType): Integer;
    procedure CheckNodeType(AExpected: TLexemeType; ANode: TBaseLexemeNode; const AMessage: string = '');
    procedure CheckBinary(ANode: TBaseLexemeNode; AOperator: TTokenKind; const AMessage: string = '');
    // Checks the parent links, levels and token ranges of the subtree of ANode; returns the count of its nodes
    function CheckTreeInvariants(ANode: TBaseLexemeNode): Integer;
    // Index of the first parsed state with the text AText, -1 if there is none
    function FindStateIndex(const AText: string): Integer;
    function FindSourceTokenIndex(const AText: string): Integer;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestEmptyUnit;
    procedure TestTestDataUnits;
    // TestPasHi.pas is a test of a syntax highlighter and has syntax errors
    procedure TestSyntaxErrorInFile;
    procedure TestVirtualTrees;
    // The sources of this repository are valid Delphi code
    procedure TestRepositorySources;
    procedure TestProgramLibraryPackage;
    procedure TestUnitSections;
    procedure TestTypeDeclarations;
    procedure TestRecordVariantPart;
    procedure TestClassMembers;
    procedure TestRecordOperators;
    procedure TestAttributes;
    procedure TestRoutines;
    procedure TestStatements;
    // An else belongs to the nearest if
    procedure TestDanglingElse;
    // An asm block ends at the first end that is not a label after '@'
    procedure TestAsmBlocks;
    procedure TestExpressionPrecedence;
    // '<' is a comparison or the start of generic arguments
    procedure TestGenericsInExpressions;
    procedure TestTypedConstants;
    procedure TestLiterals;
    procedure TestAnonymousMethods;
    // Directives and other words that are not reserved can be names, reserved words with '&'
    procedure TestDirectivesAsIdentifiers;
    // Only the first branch of a conditional directive is parsed, the directives are not parsed states
    procedure TestConditionalBranches;
    procedure TestLayout;
    // Lines and columns are counted from the text also after a directive that spans several lines
    procedure TestLayoutAfterMultiLineDirective;
    procedure TestOwnTokens;
    procedure TestTreeInvariants;
    procedure TestSyntaxErrors;
    // The compiler ignores the text after "end." of the module
    procedure TestTextAfterModuleEnd;
    procedure TestParseAgain;
  end;

implementation

{ TestTPasParser }

procedure TestTPasParser.SetUp;
begin
  FParser := TPasParser.Create;
end;

procedure TestTPasParser.TearDown;
begin
  FreeAndNil(FParser);
end;

function TestTPasParser.GetTestDataFileName(const AFileName: string): string;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\UnitTests\TestData\' + AFileName);
end;

function TestTPasParser.MakeUnit(const AInterface, AImplementation: string): string;
begin
  Result := 'unit TestUnit;' + sLineBreak
      + 'interface' + sLineBreak
      + AInterface + sLineBreak
      + 'implementation' + sLineBreak
      + AImplementation + sLineBreak
      + 'end.';
end;

function TestTPasParser.MakeStatements(const AStatements: string): string;
begin
  Result := MakeUnit('', 'procedure Test;' + sLineBreak + 'begin' + sLineBreak + AStatements + sLineBreak + 'end;');
end;

procedure TestTPasParser.CheckParsed(const ASource: string; const AMessage: string = '');
begin
  if not FParser.ParseString(ASource) then
    Fail(Format('%s: line %d, column %d: %s', [AMessage, FParser.ErrorItem[0].LineNumber,
        FParser.ErrorItem[0].LinePosition, FParser.ErrorItem[0].Message]));
  CheckEquals(0, FParser.ErrorCount, AMessage + ': error count');
  CheckNotNull(FParser.RootLexeme, AMessage + ': root lexeme');
end;

procedure TestTPasParser.CheckParsedFile(const AFileName: string);
begin
  if not FParser.ParseFile(AFileName) then
    Fail(Format('%s: line %d, column %d: %s', [AFileName, FParser.ErrorItem[0].LineNumber,
        FParser.ErrorItem[0].LinePosition, FParser.ErrorItem[0].Message]));
end;

procedure TestTPasParser.CheckParseError(const ASource: string; ALineNumber, ALinePosition: Integer;
    const AMessage: string = '');
begin
  CheckFalse(FParser.ParseString(ASource), AMessage + ': parsed without errors');
  CheckEquals(1, FParser.ErrorCount, AMessage + ': error count');
  CheckNull(FParser.RootLexeme, AMessage + ': root lexeme after an error');
  CheckEquals(ALineNumber, FParser.ErrorItem[0].LineNumber, AMessage + ': error line');
  CheckEquals(ALinePosition, FParser.ErrorItem[0].LinePosition, AMessage + ': error column');
end;

function TestTPasParser.FindNode(ALexemeType: TLexemeType; AIndex: Integer = 0): TBaseLexemeNode;
var
  FoundCount: Integer;
begin
  FoundCount := 0;
  Result := FParser.RootLexeme;
  while Assigned(Result) do
  begin
    if Result.NodeType = ALexemeType then
    begin
      if FoundCount = AIndex then
        Exit;
      Inc(FoundCount);
    end;
    Result := Result.NextTraversal;
  end;
  Fail(Format('Node %s with index %d was not found', [LEXEME_NAMES[ALexemeType], AIndex]));
end;

function TestTPasParser.CountNodes(ALexemeType: TLexemeType): Integer;
var
  Node: TBaseLexemeNode;
begin
  Result := 0;
  Node := FParser.RootLexeme;
  while Assigned(Node) do
  begin
    if Node.NodeType = ALexemeType then
      Inc(Result);
    Node := Node.NextTraversal;
  end;
end;

procedure TestTPasParser.CheckNodeType(AExpected: TLexemeType; ANode: TBaseLexemeNode; const AMessage: string = '');
begin
  if not Assigned(ANode) then
    Fail(Format('%s: expected %s, actual nil', [AMessage, LEXEME_NAMES[AExpected]]));
  CheckEquals(LEXEME_NAMES[AExpected], LEXEME_NAMES[ANode.NodeType], AMessage);
end;

procedure TestTPasParser.CheckBinary(ANode: TBaseLexemeNode; AOperator: TTokenKind; const AMessage: string = '');
begin
  CheckNodeType(ltBinaryExpression, ANode, AMessage);
  CheckEquals(TOKEN_NAMES[AOperator], TOKEN_NAMES[TBinaryExpressionLexemeNode(ANode).OperatorToken], AMessage + ': operator');
  CheckEquals(2, ANode.ChildCount, AMessage + ': operands');
end;

function TestTPasParser.CheckTreeInvariants(ANode: TBaseLexemeNode): Integer;
var
  i, PreviousEndIndex: Integer;
  Child: TBaseLexemeNode;
begin
  Result := 1;
  PreviousEndIndex := ANode.StatesStartIndex - 1;
  for i := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.Children[i];
    if Child.ParentNode <> ANode then
      Fail('Wrong parent of ' + Child.GetLexemeLog);
    if Child.Level <> ANode.Level + 1 then
      Fail('Wrong level of ' + Child.GetLexemeLog);
    if Child.StatesCount <= 0 then
      Fail('Empty node ' + Child.GetLexemeLog);
    if Child.StatesStartIndex <= PreviousEndIndex then
      Fail('Node overlaps the previous sibling: ' + Child.GetLexemeLog);
    if Child.StatesEndIndex > ANode.StatesEndIndex then
      Fail('Node is outside of its parent: ' + Child.GetLexemeLog);
    if (Child.FirstState.CurrentToken in DIRECTIVE_INSIGNIFICANT_TOKENS)
        or (Child.LastState.CurrentToken in DIRECTIVE_INSIGNIFICANT_TOKENS)
    then
      Fail('Node does not start or end with a significant token: ' + Child.GetLexemeLog);
    if (i > 0) and (Child.PrevSibling <> ANode.Children[i - 1]) then
      Fail('Wrong previous sibling of ' + Child.GetLexemeLog);
    PreviousEndIndex := Child.StatesEndIndex;
    Result := Result + CheckTreeInvariants(Child);
  end;
end;

function TestTPasParser.FindStateIndex(const AText: string): Integer;
var
  i: Integer;
begin
  for i := 0 to FParser.ParsedStateCount - 1 do
    if FParser.ParsedStateItem[i].TokenString = AText then
      Exit(i);
  Result := -1;
end;

function TestTPasParser.FindSourceTokenIndex(const AText: string): Integer;
var
  i: Integer;
begin
  for i := 0 to FParser.SourceTokenCount - 1 do
    if FParser.SourceTokenItem[i].TokenString = AText then
      Exit(i);
  Result := -1;
end;

procedure TestTPasParser.TestEmptyUnit;
var
  UnitNode: TBaseLexemeNode;
begin
  CheckParsedFile(GetTestDataFileName('EmptyUnit.pas'));
  CheckEquals(1, FParser.RootLexeme.ChildCount, 'Root children');
  UnitNode := FParser.RootLexeme.FirstChild;
  CheckNodeType(ltUnit, UnitNode, 'Module');
  CheckEquals('EmptyUnit', TUnitLexemeNode(UnitNode).ModuleName, 'Unit name');
  CheckEquals(5, UnitNode.ChildCount, 'Unit name and sections');
  CheckNodeType(ltIdentifier, UnitNode.Children[0], 'Unit name');
  CheckNodeType(ltInterface, UnitNode.Children[1], 'Interface section');
  CheckNodeType(ltImplementation, UnitNode.Children[2], 'Implementation section');
  CheckNodeType(ltInitialization, UnitNode.Children[3], 'Initialization section');
  CheckNodeType(ltFinalization, UnitNode.Children[4], 'Finalization section');
  CheckEquals('unit', UnitNode.FirstState.TokenString, 'First token of the unit');
  CheckEquals('end.', UnitNode.LastState.TokenString, 'Last token of the unit');
end;

procedure TestTPasParser.TestTestDataUnits;
begin
  CheckParsedFile(GetTestDataFileName('testunit.pas'));
  CheckEquals(3, CountNodes(ltClassType), 'testunit.pas: classes');

  CheckParsedFile(GetTestDataFileName('BeginEndCountTestUnit1.pas'));
  CheckEquals(7, CountNodes(ltClassType), 'BeginEndCountTestUnit1.pas: classes');
  CheckEquals(6, CountNodes(ltInterfaceType), 'BeginEndCountTestUnit1.pas: interfaces');
  CheckEquals(3, CountNodes(ltObjectType), 'BeginEndCountTestUnit1.pas: objects');
  CheckEquals(3, CountNodes(ltRoutine), 'BeginEndCountTestUnit1.pas: routines');

  CheckParsedFile(GetTestDataFileName('BeginEndCountTestUnit2.pas'));
  CheckEquals(1, CountNodes(ltVariantPart), 'BeginEndCountTestUnit2.pas: variant parts');
  CheckEquals(2, CountNodes(ltVariant), 'BeginEndCountTestUnit2.pas: variants');
  CheckEquals(4, CountNodes(ltRoutine), 'BeginEndCountTestUnit2.pas: routines');
end;

procedure TestTPasParser.TestSyntaxErrorInFile;
begin
  CheckFalse(FParser.ParseFile(GetTestDataFileName('TestPasHi.pas')), 'TestPasHi.pas is parsed');
  CheckEquals(1, FParser.ErrorCount, 'Error count');
  CheckNull(FParser.RootLexeme, 'Root lexeme after an error');
  // F4 := 1. followed by F5 := ... on the next line: the semicolon is missing
  CheckEquals(109, FParser.ErrorItem[0].LineNumber, 'Error line');
  CheckEquals(3, FParser.ErrorItem[0].LinePosition, 'Error column');
  CheckTrue(Pos('"F5"', FParser.ErrorItem[0].Message) > 0, 'Error message: ' + FParser.ErrorItem[0].Message);
  CheckTrue(FParser.ParsedStateCount > 0, 'Tokens are available after an error');
end;

procedure TestTPasParser.TestVirtualTrees;
var
  FileName: string;
begin
  FileName := GetTestDataFileName('VirtualTrees.pas');
  if not FileExists(FileName) then
  begin
    Status('VirtualTrees.pas is missing in UnitTests\TestData, the test is skipped');
    Exit;
  end;

  CheckParsedFile(FileName);
  CheckTrue(CountNodes(ltRoutine) > 1000, 'Routines of VirtualTrees.pas');
end;

procedure TestTPasParser.TestRepositorySources;
const
  SOURCE_FOLDERS: array[0..3] of string = (
    'Source',
    'UnitTests',
    'TestApp',
    'Benchmark'
  );
var
  Folder, FileName, Extension: string;
  FileCount: Integer;
begin
  FileCount := 0;
  for Folder in SOURCE_FOLDERS do
    for FileName in TDirectory.GetFiles(ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\' + Folder)) do
    begin
      Extension := ExtractFileExt(FileName);
      if SameText(Extension, '.pas') or SameText(Extension, '.dpr') then
      begin
        CheckParsedFile(FileName);
        Inc(FileCount);
      end;
    end;
  CheckTrue(FileCount >= 15, 'Count of the parsed source files: ' + IntToStr(FileCount));
end;

procedure TestTPasParser.TestProgramLibraryPackage;
var
  UsesItem: TUsesItemLexemeNode;
begin
  CheckParsed('program Test;' + sLineBreak
      + 'uses' + sLineBreak
      + '  System.SysUtils, uMain in ''uMain.pas'' {fmMain};' + sLineBreak
      + 'var' + sLineBreak
      + '  Count: Integer;' + sLineBreak
      + 'begin' + sLineBreak
      + '  Count := 1;' + sLineBreak
      + 'end.', 'Program');
  CheckNodeType(ltProgram, FParser.RootLexeme.FirstChild, 'Program');
  UsesItem := TUsesItemLexemeNode(FindNode(ltUsesItem, 1));
  CheckEquals('uMain', UsesItem.ModuleName, 'Used unit');
  CheckEquals('''uMain.pas''', UsesItem.FileName, 'File of the used unit');
  CheckEquals('System.SysUtils', TUsesItemLexemeNode(FindNode(ltUsesItem)).ModuleName, 'Qualified unit name');
  CheckTrue(TBeginEndBlockLexemeNode(FindNode(ltBeginEnd)).IsMainBlock, 'Main block');

  CheckParsed('library Test;' + sLineBreak
      + 'procedure Run; stdcall;' + sLineBreak
      + 'begin' + sLineBreak
      + 'end;' + sLineBreak
      + 'exports' + sLineBreak
      + '  Run index 1 name ''Run'', Run name ''RunAlias'' resident;' + sLineBreak
      + 'begin' + sLineBreak
      + 'end.', 'Library');
  CheckNodeType(ltLibrary, FParser.RootLexeme.FirstChild, 'Library');
  CheckEquals(2, CountNodes(ltExportsItem), 'Exported routines');

  CheckParsed('package Test;' + sLineBreak
      + 'requires' + sLineBreak
      + '  rtl, vcl;' + sLineBreak
      + 'contains' + sLineBreak
      + '  uFirst in ''uFirst.pas'', uSecond;' + sLineBreak
      + 'end.', 'Package');
  CheckNodeType(ltPackage, FParser.RootLexeme.FirstChild, 'Package');
  CheckEquals(2, FindNode(ltRequires).ChildCount, 'Required packages');
  CheckEquals(2, FindNode(ltContains).ChildCount, 'Contained units');
end;

procedure TestTPasParser.TestUnitSections;
begin
  CheckParsed(MakeUnit(
      'uses' + sLineBreak
      + '  System.SysUtils;' + sLineBreak
      + 'const' + sLineBreak
      + '  MAX_COUNT = 10;' + sLineBreak
      + '  NAMES: array[0..1] of string = (''A'', ''B'');' + sLineBreak
      + 'resourcestring' + sLineBreak
      + '  SHello = ''Hello'';' + sLineBreak
      + 'type' + sLineBreak
      + '  TCount = Integer;' + sLineBreak
      + 'var' + sLineBreak
      + '  GCount: TCount = 0;' + sLineBreak
      + '  GFirst, GSecond: Integer platform;' + sLineBreak
      + 'threadvar' + sLineBreak
      + '  GThreadCount: Integer;' + sLineBreak
      + 'procedure Run(ACount: Integer);' + sLineBreak
      + 'function Calculate: Integer; overload; inline;',
      'uses' + sLineBreak
      + '  System.Classes;' + sLineBreak
      + 'label' + sLineBreak
      + '  Retry, 10;' + sLineBreak
      + 'procedure Run(ACount: Integer);' + sLineBreak
      + 'begin' + sLineBreak
      + 'end;' + sLineBreak
      + 'function Calculate: Integer;' + sLineBreak
      + 'begin' + sLineBreak
      + '  Result := MAX_COUNT;' + sLineBreak
      + 'end;' + sLineBreak
      + 'initialization' + sLineBreak
      + '  Run(1);' + sLineBreak
      + 'finalization' + sLineBreak
      + '  Run(2);'), 'Unit sections');
  CheckEquals(2, CountNodes(ltUses), 'Uses clauses');
  CheckEquals(1, CountNodes(ltConstSection), 'Const sections');
  CheckEquals(3, CountNodes(ltConstDeclaration), 'Constants and resource strings');
  CheckEquals(1, CountNodes(ltResourceStringSection), 'Resource string sections');
  CheckEquals(1, CountNodes(ltTypeSection), 'Type sections');
  CheckEquals(1, CountNodes(ltVarSection), 'Var sections');
  CheckEquals(3, CountNodes(ltVarDeclaration), 'Variable declarations');
  CheckEquals(1, CountNodes(ltThreadVarSection), 'Threadvar sections');
  CheckEquals(1, CountNodes(ltLabelSection), 'Label sections');
  CheckEquals(4, CountNodes(ltRoutineHeading), 'Routine headings');
  CheckEquals(2, CountNodes(ltRoutine), 'Routines');
  CheckEquals(1, CountNodes(ltArrayConstant), 'Array constants');
  CheckEquals(1, CountNodes(ltInitialization), 'Initialization sections');
  CheckEquals(1, CountNodes(ltFinalization), 'Finalization sections');
  CheckNodeType(ltRoutineHeading, FindNode(ltInterface).Children[7], 'Routine heading in the interface section');

  // Old style initialization: begin ... end.
  CheckParsed(MakeUnit('', 'begin' + sLineBreak + '  Run;'), 'Initialization with begin');
  CheckTrue(TBeginEndBlockLexemeNode(FindNode(ltBeginEnd)).IsMainBlock, 'Main block of the unit');
end;

procedure TestTPasParser.TestTypeDeclarations;
const
  EXPECTED_TYPES: array[0..26] of TLexemeType = (
    ltEnumType,
    ltSubrangeType,
    ltSubrangeType,
    ltSubrangeType,
    ltSetType,
    ltArrayType,
    ltArrayType,
    ltFileType,
    ltPointerType,
    ltProceduralType,
    ltProceduralType,
    ltProceduralType,
    ltClassReferenceType,
    ltClassType,
    ltClassType,
    ltClassType,
    ltClassType,
    ltRecordType,
    ltRecordType,
    ltObjectType,
    ltInterfaceType,
    ltInterfaceType,
    ltTypeIdentifier,
    ltTypeIdentifier,
    ltClassType,
    ltTypeIdentifier,
    ltTypeIdentifier
  );
var
  i: Integer;
  Declaration, DeclaredType: TBaseLexemeNode;
begin
  CheckParsed(MakeUnit(
      'type' + sLineBreak
      + '  TEnum = (eFirst, eSecond = 5);' + sLineBreak
      + '  TRange = 0..9;' + sLineBreak
      + '  TCharRange = ''a''..''z'';' + sLineBreak
      + '  TBounds = Low(Integer) + 1..High(Integer);' + sLineBreak
      + '  TSet = set of TEnum;' + sLineBreak
      + '  TStatic = array[0..9, Boolean] of Integer;' + sLineBreak
      + '  TDynamic = array of string;' + sLineBreak
      + '  TFile = file of Byte;' + sLineBreak
      + '  TPointer = ^TRecord;' + sLineBreak
      + '  TMethod = procedure(ASender: TObject) of object;' + sLineBreak
      + '  TFunction = function(AValue: Integer): Boolean; stdcall;' + sLineBreak
      + '  TReference = reference to procedure;' + sLineBreak
      + '  TClassRef = class of TObject;' + sLineBreak
      + '  TForward = class;' + sLineBreak
      + '  TAncestorsOnly = class(TInterfacedObject, IInterface);' + sLineBreak
      + '  TAbstract = class abstract(TObject)' + sLineBreak
      + '  end;' + sLineBreak
      + '  THelper = class helper for TObject' + sLineBreak
      + '  end;' + sLineBreak
      + '  TRecord = packed record' + sLineBreak
      + '    Value: Integer' + sLineBreak
      + '  end;' + sLineBreak
      + '  TRecordHelper = record helper for string' + sLineBreak
      + '  end;' + sLineBreak
      + '  TObjectType = object' + sLineBreak
      + '  end;' + sLineBreak
      + '  IForward = interface;' + sLineBreak
      + '  IFoo = interface(IInterface)' + sLineBreak
      + '    [''{8F6C3B2A-1D4E-4F5A-9B6C-7D8E9F0A1B2C}'']' + sLineBreak
      + '  end;' + sLineBreak
      + '  TDistinct = type Integer;' + sLineBreak
      + '  TShortString = string[20];' + sLineBreak
      + '  TList<T: class, constructor; K> = class' + sLineBreak
      + '  end;' + sLineBreak
      + '  TAlias = System.Classes.TList deprecated ''Use TList<T>'';' + sLineBreak
      + '  TGeneric = TDictionary<string, TList<Integer>>;', ''), 'Type declarations');

  CheckEquals(Length(EXPECTED_TYPES), CountNodes(ltTypeDeclaration), 'Type declarations');
  for i := Low(EXPECTED_TYPES) to High(EXPECTED_TYPES) do
  begin
    Declaration := FindNode(ltTypeDeclaration, i);
    DeclaredType := Declaration.Children[1];
    if DeclaredType.NodeType = ltGenericParameters then
      DeclaredType := Declaration.Children[2];
    CheckNodeType(EXPECTED_TYPES[i], DeclaredType, TTypeDeclarationLexemeNode(Declaration).Name);
  end;

  CheckEquals(2, CountNodes(ltEnumElement), 'Enumeration elements');
  CheckTrue(TProceduralTypeLexemeNode(FindNode(ltProceduralType, 0)).IsMethodPointer, 'Method pointer');
  CheckNodeType(ltRoutineDirective, FindNode(ltProceduralType, 1).LastChild, 'Calling convention after a semicolon');
  CheckTrue(TProceduralTypeLexemeNode(FindNode(ltProceduralType, 2)).IsReference, 'Reference type');
  CheckTrue(TClassTypeLexemeNode(FindNode(ltClassType, 0)).IsForward, 'Forward class');
  CheckFalse(TClassTypeLexemeNode(FindNode(ltClassType, 1)).IsForward, 'Class with ancestors only');
  CheckEquals(TOKEN_NAMES[tkAbstract], TOKEN_NAMES[TClassTypeLexemeNode(FindNode(ltClassType, 2)).Modifier], 'Abstract class');
  CheckTrue(TClassTypeLexemeNode(FindNode(ltClassType, 3)).IsHelper, 'Class helper');
  CheckTrue(TRecordTypeLexemeNode(FindNode(ltRecordType, 0)).IsPacked, 'Packed record');
  CheckTrue(TRecordTypeLexemeNode(FindNode(ltRecordType, 1)).IsHelper, 'Record helper');
  CheckTrue(TInterfaceTypeLexemeNode(FindNode(ltInterfaceType, 0)).IsForward, 'Forward interface');
  CheckEquals(1, CountNodes(ltInterfaceGuid), 'Interface GUID');
  CheckTrue(TTypeIdentifierLexemeNode(FindNode(ltTypeDeclaration, 22).Children[1]).IsDistinct, 'Distinct type');
  CheckEquals('System.Classes.TList', TTypeIdentifierLexemeNode(FindNode(ltTypeDeclaration, 25).Children[1]).TypeName,
      'Qualified type name');
  CheckEquals(1, CountNodes(ltGenericParameters), 'Generic parameters');
  CheckEquals(2, CountNodes(ltGenericArguments), 'Generic arguments');
end;

procedure TestTPasParser.TestRecordVariantPart;
begin
  CheckParsed(MakeUnit(
      'type' + sLineBreak
      + '  TVariant = record' + sLineBreak
      + '    Kind: Integer;' + sLineBreak
      + '    case Tag: Integer of' + sLineBreak
      + '      0: (Left, Top: Integer);' + sLineBreak
      + '      1, 2: (Point: Int64;' + sLineBreak
      + '        case Boolean of' + sLineBreak
      + '          False: (A: Byte);' + sLineBreak
      + '          True: (B: Word));' + sLineBreak
      + '  end;' + sLineBreak
      + '  TAligned = record' + sLineBreak
      + '    X: Integer;' + sLineBreak
      + '  end align 8;', ''), 'Variant records');
  CheckEquals(2, CountNodes(ltVariantPart), 'Variant parts');
  CheckEquals(4, CountNodes(ltVariant), 'Variants');
  CheckEquals(6, CountNodes(ltFieldDeclaration), 'Fields');
end;

procedure TestTPasParser.TestClassMembers;
const
  EXPECTED_VISIBILITY: array[0..4] of TTokenKind = (
    tkPrivate,
    tkPrivate,
    tkProtected,
    tkPublic,
    tkPublished
  );
var
  i: Integer;
  Section: TVisibilitySectionLexemeNode;
begin
  CheckParsed(MakeUnit(
      'type' + sLineBreak
      + '  TFoo = class(TInterfacedObject, IFoo)' + sLineBreak
      + '    FImplicit: Integer;' + sLineBreak
      + '  strict private' + sLineBreak
      + '    FValue: Integer;' + sLineBreak
      + '    class var FCount: Integer;' + sLineBreak
      + '  private' + sLineBreak
      + '    type' + sLineBreak
      + '      TInner = record' + sLineBreak
      + '      end;' + sLineBreak
      + '    const' + sLineBreak
      + '      DEFAULT_VALUE = 1;' + sLineBreak
      + '    var' + sLineBreak
      + '      FItems: array of string;' + sLineBreak
      + '    function GetItem(AIndex: Integer): string;' + sLineBreak
      + '    procedure IFoo.Run = DoRun;' + sLineBreak
      + '  protected' + sLineBreak
      + '    procedure DoRun; virtual; abstract;' + sLineBreak
      + '    procedure WMSize(var AMessage: TWMSize); message WM_SIZE;' + sLineBreak
      + '  public' + sLineBreak
      + '    constructor Create(AOwner: TComponent); reintroduce; overload;' + sLineBreak
      + '    destructor Destroy; override;' + sLineBreak
      + '    class function New: TFoo; static;' + sLineBreak
      + '    property Items[AIndex: Integer]: string read GetItem; default;' + sLineBreak
      + '    property Value: Integer index 1 read FValue write FValue stored False default 0;' + sLineBreak
      + '    class property Count: Integer read FCount;' + sLineBreak
      + '    property Bar: IBar read FBar implements IBar;' + sLineBreak
      + '  published' + sLineBreak
      + '    property Tag;' + sLineBreak
      + '  end;', ''), 'Class members');

  CheckEquals(Length(EXPECTED_VISIBILITY), CountNodes(ltVisibilitySection), 'Visibility sections');
  for i := Low(EXPECTED_VISIBILITY) to High(EXPECTED_VISIBILITY) do
  begin
    Section := TVisibilitySectionLexemeNode(FindNode(ltVisibilitySection, i));
    CheckEquals(TOKEN_NAMES[EXPECTED_VISIBILITY[i]], TOKEN_NAMES[Section.Visibility], 'Visibility');
    CheckEquals(i = 0, Section.IsStrict, 'Strict visibility');
  end;
  // A member before the first visibility section is a direct child of the class
  CheckNodeType(ltFieldDeclaration, FindNode(ltClassType).Children[2], 'Member without a visibility section');

  CheckEquals(4, CountNodes(ltFieldDeclaration), 'Fields');
  CheckEquals(2, CountNodes(ltVarSection), 'Field sections');
  CheckTrue(TVarSectionLexemeNode(FindNode(ltVarSection, 0)).IsClassVar, 'Class var section');
  CheckEquals(7, CountNodes(ltRoutineHeading), 'Methods');
  CheckTrue(TRoutineHeadingLexemeNode(FindNode(ltRoutineHeading, 1)).IsMethodResolution, 'Method resolution clause');
  CheckEquals('IFoo.Run', TRoutineHeadingLexemeNode(FindNode(ltRoutineHeading, 1)).Name, 'Resolved method');
  CheckTrue(TRoutineHeadingLexemeNode(FindNode(ltRoutineHeading, 6)).IsClassMethod, 'Class method');
  CheckEquals(7, CountNodes(ltRoutineDirective), 'Method directives');
  CheckEquals(5, CountNodes(ltProperty), 'Properties');
  CheckTrue(TPropertyLexemeNode(FindNode(ltProperty, 0)).IsDefault, 'Default property');
  CheckTrue(TPropertyLexemeNode(FindNode(ltProperty, 2)).IsClassProperty, 'Class property');
  CheckEquals('Tag', TPropertyLexemeNode(FindNode(ltProperty, 4)).Name, 'Redeclared property');
end;

procedure TestTPasParser.TestRecordOperators;
begin
  CheckParsed(MakeUnit(
      'type' + sLineBreak
      + '  TPoint2 = record' + sLineBreak
      + '  private' + sLineBreak
      + '    FX: Integer;' + sLineBreak
      + '  public' + sLineBreak
      + '    constructor Create(AX: Integer);' + sLineBreak
      + '    class operator Add(const ALeft, ARight: TPoint2): TPoint2;' + sLineBreak
      + '    class operator In(const AValue: Integer; const APoint: TPoint2): Boolean;' + sLineBreak
      + '    property X: Integer read FX;' + sLineBreak
      + '  end;',
      'class operator TPoint2.Add(const ALeft, ARight: TPoint2): TPoint2;' + sLineBreak
      + 'begin' + sLineBreak
      + '  Result.FX := ALeft.FX + ARight.FX;' + sLineBreak
      + 'end;'), 'Record operators');
  CheckEquals(4, CountNodes(ltRoutineHeading), 'Methods and operators');
  CheckEquals(TOKEN_NAMES[tkOperator], TOKEN_NAMES[TRoutineHeadingLexemeNode(FindNode(ltRoutineHeading, 2)).RoutineKind],
      'Operator');
  CheckEquals('In', TRoutineHeadingLexemeNode(FindNode(ltRoutineHeading, 2)).Name, 'Operator named by a keyword');
  CheckEquals('TPoint2.Add', TRoutineLexemeNode(FindNode(ltRoutine)).Heading.Name, 'Implemented operator');
end;

procedure TestTPasParser.TestAttributes;
begin
  CheckParsed(MakeUnit(
      'type' + sLineBreak
      + '  [ComponentPlatforms(pidWin32 or pidWin64)]' + sLineBreak
      + '  TFoo = class' + sLineBreak
      + '  private' + sLineBreak
      + '    [Weak] FOwner: TObject;' + sLineBreak
      + '    [Result: Unsafe] function GetOwner: TObject;' + sLineBreak
      + '  public' + sLineBreak
      + '    [Test, TestCase(''A'', ''1'')]' + sLineBreak
      + '    procedure Run(const [Ref] AFirst, [Ref] ASecond: TGUID);' + sLineBreak
      + '  end;', ''), 'Attributes');
  CheckEquals(6, CountNodes(ltAttributeList), 'Attribute lists');
  CheckEquals(7, CountNodes(ltAttribute), 'Attributes');
  CheckNodeType(ltAttributeList, FindNode(ltTypeDeclaration).FirstChild, 'Attribute of a type');
  CheckNodeType(ltAttributeList, FindNode(ltFieldDeclaration).FirstChild, 'Attribute of a field');
end;

procedure TestTPasParser.TestRoutines;
var
  Routine: TRoutineLexemeNode;
  Parameter: TParameterLexemeNode;
begin
  CheckParsed(MakeUnit('',
      'procedure Outer(const AValue: Integer; var ABuffer; out AResult: string; AFlag: Boolean = False); forward;'
      + sLineBreak
      + 'function MessageBox(AWnd: HWND; AText: PChar): Integer; stdcall; external ''user32.dll'' name ''MessageBoxW'''
      + ' delayed;' + sLineBreak
      + 'procedure Outer(const AValue: Integer; var ABuffer; out AResult: string; AFlag: Boolean = False);' + sLineBreak
      + 'var' + sLineBreak
      + '  Count: Integer;' + sLineBreak
      + sLineBreak
      + '  procedure Inner;' + sLineBreak
      + '  begin' + sLineBreak
      + '    Inc(Count);' + sLineBreak
      + '  end;' + sLineBreak
      + sLineBreak
      + 'begin' + sLineBreak
      + '  Inner;' + sLineBreak
      + 'end;' + sLineBreak
      + 'function TFoo<T>.Bar<K>(const [Ref] AKey: K): T;' + sLineBreak
      + 'begin' + sLineBreak
      + '  Result := Default(T);' + sLineBreak
      + 'end;' + sLineBreak
      + 'class procedure TFoo.TInner.Run;' + sLineBreak
      + 'begin' + sLineBreak
      + 'end;' + sLineBreak
      + 'function Sum(A, B: Integer): Integer; assembler;' + sLineBreak
      + 'asm' + sLineBreak
      + '  MOV EAX, A' + sLineBreak
      + '  ADD EAX, B' + sLineBreak
      + 'end;' + sLineBreak
      + 'procedure Log(const AArgs: array of const);' + sLineBreak
      + 'begin' + sLineBreak
      + 'end;'), 'Routines');
  CheckEquals(8, CountNodes(ltRoutine), 'Routines');

  Routine := TRoutineLexemeNode(FindNode(ltRoutine, 0));
  CheckTrue(Routine.Heading.IsForward, 'Forward routine');
  CheckNull(Routine.Body, 'Body of a forward routine');
  Routine := TRoutineLexemeNode(FindNode(ltRoutine, 1));
  CheckTrue(Routine.Heading.IsExternal, 'External routine');
  CheckNull(Routine.Body, 'Body of an external routine');

  Routine := TRoutineLexemeNode(FindNode(ltRoutine, 2));
  CheckNodeType(ltBeginEnd, Routine.Body, 'Body of a routine');
  CheckTrue(FindNode(ltRoutine, 3).ParentNode = Routine, 'Nested routine');
  CheckEquals(13, CountNodes(ltParameter), 'Parameters');
  Parameter := TParameterLexemeNode(FindNode(ltParameter, 0));
  CheckEquals(TOKEN_NAMES[tkConst], TOKEN_NAMES[Parameter.Modifier], 'Constant parameter');
  CheckEquals(TOKEN_NAMES[tkVar], TOKEN_NAMES[TParameterLexemeNode(FindNode(ltParameter, 1)).Modifier], 'Var parameter');
  CheckEquals(1, FindNode(ltParameter, 1).ChildCount, 'Untyped parameter');
  CheckEquals(TOKEN_NAMES[tkOut], TOKEN_NAMES[TParameterLexemeNode(FindNode(ltParameter, 2)).Modifier], 'Out parameter');
  CheckEquals(TOKEN_NAMES[tkUnknown], TOKEN_NAMES[TParameterLexemeNode(FindNode(ltParameter, 3)).Modifier],
      'Parameter without a modifier');
  CheckEquals(3, FindNode(ltParameter, 3).ChildCount, 'Parameter with a default value');

  CheckEquals('TFoo.Bar', TRoutineLexemeNode(FindNode(ltRoutine, 4)).Heading.Name, 'Generic method');
  CheckEquals(2, CountNodes(ltGenericParameters), 'Generic parameters');
  CheckEquals('TFoo.TInner.Run', TRoutineLexemeNode(FindNode(ltRoutine, 5)).Heading.Name, 'Method of a nested type');
  CheckTrue(TRoutineLexemeNode(FindNode(ltRoutine, 5)).Heading.IsClassMethod, 'Class method');
  CheckNodeType(ltAsmStatement, TRoutineLexemeNode(FindNode(ltRoutine, 6)).Body, 'Assembler body');
  CheckTrue(TArrayTypeLexemeNode(FindNode(ltArrayType)).IsArrayOfConst, 'Array of const');
end;

procedure TestTPasParser.TestStatements;
var
  IfStatement: TIfStatementLexemeNode;
begin
  CheckParsed(MakeStatements(
      '  Value := 1;' + sLineBreak
      + '  Run;' + sLineBreak
      + '  Run(1, ''text'');' + sLineBreak
      + '  inherited;' + sLineBreak
      + '  inherited Create(nil);' + sLineBreak
      + '  if Value > 0 then' + sLineBreak
      + '    Value := 0' + sLineBreak
      + '  else if Value < 0 then' + sLineBreak
      + '    Value := 1' + sLineBreak
      + '  else' + sLineBreak
      + '    Exit;' + sLineBreak
      + '  case Value of' + sLineBreak
      + '    1, 3..5: Run;' + sLineBreak
      + '    10: ;' + sLineBreak
      + '  else' + sLineBreak
      + '    Run;' + sLineBreak
      + '    Value := 0;' + sLineBreak
      + '  end;' + sLineBreak
      + '  for Index := 0 to 9 do' + sLineBreak
      + '    Run;' + sLineBreak
      + '  for Index := 9 downto 0 do ;' + sLineBreak
      + '  for var Item in List do' + sLineBreak
      + '    Run(Item);' + sLineBreak
      + '  for var I: Integer := 1 to 2 do;' + sLineBreak
      + '  while Value > 0 do' + sLineBreak
      + '    Dec(Value);' + sLineBreak
      + '  repeat' + sLineBreak
      + '    Inc(Value);' + sLineBreak
      + '  until Value > 10;' + sLineBreak
      + '  with List do' + sLineBreak
      + '    Clear;' + sLineBreak
      + '  try' + sLineBreak
      + '    Run;' + sLineBreak
      + '  except' + sLineBreak
      + '    on E: EAbort do' + sLineBreak
      + '      Run;' + sLineBreak
      + '    on Exception do' + sLineBreak
      + '      raise;' + sLineBreak
      + '  else' + sLineBreak
      + '    raise Exception.Create(''Error'') at ReturnAddress;' + sLineBreak
      + '  end;' + sLineBreak
      + '  try' + sLineBreak
      + '    Run;' + sLineBreak
      + '  finally' + sLineBreak
      + '    Free;' + sLineBreak
      + '  end;' + sLineBreak
      + '  try' + sLineBreak
      + '    Run;' + sLineBreak
      + '  except' + sLineBreak
      + '    Value := 0;' + sLineBreak
      + '  end;' + sLineBreak
      + 'Retry:' + sLineBreak
      + '  goto Retry;' + sLineBreak
      + '  asm' + sLineBreak
      + '    NOP' + sLineBreak
      + '  end;' + sLineBreak
      + '  var Count: Integer := 0;' + sLineBreak
      + '  var Text := ''Inline'';' + sLineBreak
      + '  const LIMIT = 10;' + sLineBreak
      + '  begin' + sLineBreak
      + '    Run;' + sLineBreak
      + '  end;' + sLineBreak
      + '  ;'), 'Statements');

  CheckEquals(5, CountNodes(ltAssignment), 'Assignments');
  CheckEquals(2, CountNodes(ltIfStatement), 'If statements');
  CheckEquals(1, CountNodes(ltCaseStatement), 'Case statements');
  CheckEquals(2, CountNodes(ltCaseItem), 'Case items');
  CheckEquals(1, CountNodes(ltRange), 'Case ranges');
  CheckEquals(2, CountNodes(ltElseBlock), 'Else blocks of case and except');
  CheckEquals(3, CountNodes(ltForStatement), 'For statements');
  CheckTrue(TForStatementLexemeNode(FindNode(ltForStatement, 1)).IsDownto, 'For downto');
  CheckTrue(TForStatementLexemeNode(FindNode(ltForStatement, 2)).IsInlineVar, 'For with an inline variable');
  CheckEquals(1, CountNodes(ltForInStatement), 'For in statements');
  CheckEquals(1, CountNodes(ltWhileStatement), 'While statements');
  CheckEquals(1, CountNodes(ltRepeatStatement), 'Repeat statements');
  CheckEquals(1, CountNodes(ltWithStatement), 'With statements');
  CheckEquals(3, CountNodes(ltTryStatement), 'Try statements');
  CheckEquals(2, CountNodes(ltExceptBlock), 'Except blocks');
  CheckEquals(2, CountNodes(ltExceptionHandler), 'Exception handlers');
  CheckEquals(1, CountNodes(ltFinallyBlock), 'Finally blocks');
  CheckEquals(2, CountNodes(ltRaiseStatement), 'Raise statements');
  CheckEquals(1, CountNodes(ltLabeledStatement), 'Labeled statements');
  CheckEquals(1, CountNodes(ltGotoStatement), 'Goto statements');
  CheckEquals(1, CountNodes(ltAsmStatement), 'Asm statements');
  CheckEquals(2, CountNodes(ltInlineVarDeclaration), 'Inline variables');
  CheckEquals(1, CountNodes(ltInlineConstDeclaration), 'Inline constants');
  CheckEquals(2, CountNodes(ltBeginEnd), 'Compound statements');
  CheckEquals(2, CountNodes(ltInheritedExpression), 'Inherited calls');

  IfStatement := TIfStatementLexemeNode(FindNode(ltIfStatement));
  CheckBinary(IfStatement.Condition, tkGreater, 'Condition');
  CheckNodeType(ltAssignment, IfStatement.ThenStatement, 'Then statement');
  CheckNodeType(ltIfStatement, IfStatement.ElseStatement, 'Else if');
  CheckNodeType(ltCallStatement, TIfStatementLexemeNode(IfStatement.ElseStatement).ElseStatement, 'Last else');
end;

procedure TestTPasParser.TestDanglingElse;
var
  OuterIf, InnerIf: TIfStatementLexemeNode;
begin
  CheckParsed(MakeStatements('  if A then if B then X := 1 else X := 2;'), 'Dangling else');
  OuterIf := TIfStatementLexemeNode(FindNode(ltIfStatement, 0));
  InnerIf := TIfStatementLexemeNode(FindNode(ltIfStatement, 1));
  CheckTrue(OuterIf.ThenStatement = InnerIf, 'Inner if');
  CheckNull(OuterIf.ElseStatement, 'Else of the outer if');
  CheckNodeType(ltAssignment, InnerIf.ElseStatement, 'Else of the inner if');

  CheckParsed(MakeStatements('  if A then else X := 2;'), 'Empty then statement');
  CheckNull(TIfStatementLexemeNode(FindNode(ltIfStatement)).ThenStatement, 'Empty then statement');
end;

procedure TestTPasParser.TestAsmBlocks;
var
  AsmNode: TBaseLexemeNode;
begin
  CheckParsed(MakeUnit('',
      'function IsQuote(AValue: AnsiChar): Boolean;' + sLineBreak
      + 'asm' + sLineBreak
      + '  CMP AL, "''"' + sLineBreak
      + '  JE @@End' + sLineBreak
      + '  XOR EAX, EAX' + sLineBreak
      + '@@End:' + sLineBreak
      + 'end;' + sLineBreak
      + 'procedure Test;' + sLineBreak
      + 'begin' + sLineBreak
      + '  asm' + sLineBreak
      + '    NOP' + sLineBreak
      + '  end;' + sLineBreak
      + '  Run;' + sLineBreak
      + 'end;'), 'Asm blocks');
  CheckEquals(2, CountNodes(ltAsmStatement), 'Asm blocks');
  AsmNode := FindNode(ltAsmStatement);
  CheckEquals('asm', AsmNode.FirstState.TokenString, 'First token of the asm block');
  CheckEquals(11, Integer(AsmNode.LastState.CurrentLine), 'The label @@End does not end the asm block');
  CheckEquals(1, CountNodes(ltCallStatement), 'Statement after an asm statement');
end;

procedure TestTPasParser.TestExpressionPrecedence;
var
  Value: TBaseLexemeNode;
begin
  CheckParsed(MakeStatements('  Result := A + B * C - D;'), 'Arithmetic');
  Value := FindNode(ltAssignment).Children[1];
  CheckBinary(Value, tkMinus, 'A + B * C - D');
  CheckBinary(Value.Children[0], tkPlus, 'A + B * C');
  CheckBinary(Value.Children[0].Children[1], tkStar, 'B * C');

  CheckParsed(MakeStatements('  Result := not A and (B or C) = D;'), 'Logical');
  Value := FindNode(ltAssignment).Children[1];
  CheckBinary(Value, tkEqual, 'Relational operator is the weakest');
  CheckBinary(Value.Children[0], tkAnd, 'not A and (B or C)');
  CheckNodeType(ltUnaryExpression, Value.Children[0].Children[0], 'not A');
  CheckNodeType(ltParenthesizedExpression, Value.Children[0].Children[1], '(B or C)');

  CheckParsed(MakeStatements('  Result := -A * B;'), 'Unary minus');
  Value := FindNode(ltAssignment).Children[1];
  CheckBinary(Value, tkStar, '-A * B');
  CheckNodeType(ltUnaryExpression, Value.Children[0], '-A');

  CheckParsed(MakeStatements('  Result := X in [1, 3..5];'), 'Set');
  Value := FindNode(ltAssignment).Children[1];
  CheckBinary(Value, tkIn, 'X in [...]');
  CheckNodeType(ltSetConstructor, Value.Children[1], 'Set constructor');
  CheckNodeType(ltRange, Value.Children[1].Children[1], 'Range in a set');

  CheckParsed(MakeStatements(
      '  Result := P^.Items[I, J].Name;' + sLineBreak
      + '  Result := (Sender as TButton).Caption;' + sLineBreak
      + '  Result := @Proc;' + sLineBreak
      + '  Str(Value:10:2, Text);' + sLineBreak
      + '  Result := inherited GetValue + inherited.Count;'), 'Designators');
  Value := FindNode(ltAssignment, 0).Children[1];
  CheckNodeType(ltDesignator, Value, 'Designator with selectors');
  CheckNodeType(ltIndexList, Value.Children[2], 'Index list');
  CheckEquals(2, Value.Children[2].ChildCount, 'Indexes');
  CheckNodeType(ltDesignator, FindNode(ltAssignment, 1).Children[1], 'Designator after parentheses');
  CheckNodeType(ltParenthesizedExpression, FindNode(ltAssignment, 1).Children[1].FirstChild, 'Parenthesized object');
  CheckNodeType(ltUnaryExpression, FindNode(ltAssignment, 2).Children[1], 'Address operator');
  CheckEquals(4, FindNode(ltArgumentList).ChildCount, 'Argument with width and precision');
end;

procedure TestTPasParser.TestGenericsInExpressions;
begin
  CheckParsed(MakeStatements(
      '  List := TList<Integer>.Create;' + sLineBreak
      + '  Flag := A < B;' + sLineBreak
      + '  if A < B then' + sLineBreak
      + '    Flag := C > D;' + sLineBreak
      + '  Flag := Value.AsType<Integer> = 0;' + sLineBreak
      + '  Dictionary := TDictionary<string, TList<Integer>>.Create;' + sLineBreak
      + '  Flag := Min(A < B, C > D);'), 'Generics');
  CheckEquals(4, CountNodes(ltGenericArguments), 'Generic arguments');
  CheckBinary(FindNode(ltAssignment, 1).Children[1], tkLower, 'A < B');
  CheckBinary(FindNode(ltAssignment, 2).Children[1], tkGreater, 'C > D');
  CheckBinary(FindNode(ltAssignment, 3).Children[1], tkEqual, 'Value.AsType<Integer> = 0');
  CheckEquals(2, FindNode(ltArgumentList, 0).ChildCount, 'Comparisons as arguments');
end;

procedure TestTPasParser.TestTypedConstants;
begin
  CheckParsed(MakeUnit(
      'const' + sLineBreak
      + '  ARRAY_VALUE: array[0..2] of Integer = (1, 2, 3);' + sLineBreak
      + '  MATRIX: array[0..1, 0..1] of Integer = ((1, 2), (3, 4));' + sLineBreak
      + '  POINT: TPoint = (X: 1; Y: 2);' + sLineBreak
      + '  EMPTY: TRec = ();' + sLineBreak
      + '  EXPRESSION: Integer = (1 + 2) * 3;' + sLineBreak
      + '  NESTED: TLine = (Start: (X: 0; Y: 0); Finish: (X: 1; Y: 1););' + sLineBreak
      + '  SET_VALUE: TChars = [''a''..''z'', ''_''];', ''), 'Typed constants');
  CheckEquals(4, CountNodes(ltArrayConstant), 'Array constants');
  CheckEquals(5, CountNodes(ltRecordConstant), 'Record constants');
  CheckEquals(8, CountNodes(ltRecordConstantField), 'Fields of record constants');
  CheckEquals('Start', TRecordConstantFieldLexemeNode(FindNode(ltRecordConstantField, 2)).Name, 'Field name');
  CheckBinary(FindNode(ltConstDeclaration, 4).Children[2], tkStar, 'Expression as a typed constant');
  CheckEquals(1, CountNodes(ltSetConstructor), 'Set constants');
end;

procedure TestTPasParser.TestLiterals;
var
  Literal: TLiteralLexemeNode;
begin
  CheckParsed(MakeStatements(
      '  Text := #13#10''Line''#0;' + sLineBreak
      + '  Text := ''A'' + ''B'';' + sLineBreak
      + '  Value := &17 + %1010_0101 + $FF_FF + 1_000.5e3;' + sLineBreak
      + '  Ch := ^M;' + sLineBreak
      + '  Ptr := nil;' + sLineBreak
      + '  Text := 1.ToString + 1_000.ToString(10);'), 'Literals');
  Literal := TLiteralLexemeNode(FindNode(ltAssignment).Children[1]);
  CheckNodeType(ltLiteral, Literal, 'Character string');
  CheckEquals(TOKEN_NAMES[tkAsciiChar], TOKEN_NAMES[Literal.LiteralToken], 'First part of the character string');
  CheckEquals(4, Literal.StatesCount, 'Parts of the character string');
  CheckEquals(2, FindNode(ltLiteral, 3).StatesCount, 'Number escaped with &');
  CheckEquals(TOKEN_NAMES[tkInteger], TOKEN_NAMES[TLiteralLexemeNode(FindNode(ltLiteral, 4)).LiteralToken],
      'Binary number with digit separators');
  CheckEquals(12, CountNodes(ltLiteral), 'Literals');

  // A method of a number: the number is the first part of a designator
  CheckBinary(FindNode(ltAssignment, 5).Children[1], tkPlus, '1.ToString + 1_000.ToString(10)');
  CheckNodeType(ltDesignator, FindNode(ltAssignment, 5).Children[1].Children[0], '1.ToString');
  CheckNodeType(ltLiteral, FindNode(ltAssignment, 5).Children[1].Children[0].FirstChild, 'Number of 1.ToString');
  CheckNodeType(ltArgumentList, FindNode(ltAssignment, 5).Children[1].Children[1].LastChild, 'Arguments of ToString');
end;

procedure TestTPasParser.TestAnonymousMethods;
begin
  CheckParsed(MakeStatements(
      '  TThread.Queue(nil,' + sLineBreak
      + '    procedure' + sLineBreak
      + '    begin' + sLineBreak
      + '      Run;' + sLineBreak
      + '    end' + sLineBreak
      + '  );' + sLineBreak
      + '  Func := function(AValue: Integer): Boolean' + sLineBreak
      + '    var' + sLineBreak
      + '      Local: Integer;' + sLineBreak
      + '    begin' + sLineBreak
      + '      Result := AValue > Local;' + sLineBreak
      + '    end;'), 'Anonymous methods');
  CheckEquals(2, CountNodes(ltAnonymousMethod), 'Anonymous methods');
  CheckEquals(TOKEN_NAMES[tkFunction], TOKEN_NAMES[TAnonymousMethodLexemeNode(FindNode(ltAnonymousMethod, 1)).RoutineKind],
      'Anonymous function');
  CheckEquals(1, CountNodes(ltVarSection), 'Local variables of an anonymous method');
end;

procedure TestTPasParser.TestDirectivesAsIdentifiers;
begin
  CheckParsed(MakeUnit(
      'var' + sLineBreak
      + '  Index, Name, Message, Read, Default, Platform, Helper, Strict, Out, Operator: Integer;' + sLineBreak
      + '  &Type, &Begin: string;',
      'procedure Test;' + sLineBreak
      + 'begin' + sLineBreak
      + '  Index := Name + Message + Read + Default;' + sLineBreak
      + '  &Type := &Begin;' + sLineBreak
      + 'end;'), 'Directives as identifiers');
  CheckEquals(10, FindNode(ltVarDeclaration).ChildCount - 1, 'Variables named by directives');
  CheckEquals('Type', TIdentifierLexemeNode(FindNode(ltVarDeclaration, 1).Children[0]).Name, 'Escaped reserved word');
end;

procedure TestTPasParser.TestConditionalBranches;
var
  i, DirectiveCount: Integer;
begin
  CheckParsed(MakeStatements(
      '{$IFDEF FIRST}' + sLineBreak
      + '  Value := 1;' + sLineBreak
      + '{$ELSE}' + sLineBreak
      + '  Value := 2;' + sLineBreak
      + '{$ENDIF}' + sLineBreak
      + '  {$IFNDEF SECOND}Run;{$ENDIF}'), 'Conditional branches');
  CheckEquals(1, CountNodes(ltAssignment), 'Assignments of the first branch');
  CheckEquals(1, CountNodes(ltCallStatement), 'Call in a conditional branch');
  CheckTrue(FindStateIndex('1') >= 0, 'Token of the first branch');
  CheckEquals(-1, FindStateIndex('2'), 'Token of the else branch');
  for i := 0 to FParser.ParsedStateCount - 1 do
    CheckFalse(FParser.ParsedStateItem[i].CurrentToken = tkCompilerDirective, 'Directive in the parsed states');

  CheckTrue(FindSourceTokenIndex('2') >= 0, 'Source token of the else branch');
  DirectiveCount := 0;
  for i := 0 to FParser.SourceTokenCount - 1 do
    if FParser.SourceTokenItem[i].CurrentToken = tkCompilerDirective then
      Inc(DirectiveCount);
  CheckEquals(5, DirectiveCount, 'Directives in the source tokens');
end;

procedure TestTPasParser.TestLayout;
var
  Index: Integer;
  State: TPasLexerMinimalState;
begin
  CheckParsed('unit Layout;' + sLineBreak
      + 'interface' + sLineBreak
      + 'implementation' + sLineBreak
      + 'procedure Test;' + sLineBreak
      + 'begin' + sLineBreak
      + '  Value  :=Count; // comment' + sLineBreak
      + '    {$IFDEF X}' + sLineBreak
      + #9'Run;' + sLineBreak
      + '    {$ENDIF}' + sLineBreak
      + sLineBreak
      + 'end;' + sLineBreak
      + 'end.' + sLineBreak, 'Layout');

  State := FParser.ParsedStateItem[FindStateIndex('Value')];
  CheckEquals(6, Integer(State.CurrentLine), 'Value: line');
  CheckEquals(3, State.Column, 'Value: column');
  CheckEquals(2, State.SpaceBefore, 'Value: indentation');
  CheckEquals(2, State.SpaceAfter, 'Value: spaces after');
  CheckTrue(State.IsFirstOnLine, 'Value: first on the line');
  CheckFalse(State.IsLastOnLine, 'Value: last on the line');

  State := FParser.ParsedStateItem[FindStateIndex(':=')];
  CheckEquals(10, State.Column, ':=: column');
  CheckEquals(2, State.SpaceBefore, ':=: spaces before');
  CheckEquals(0, State.SpaceAfter, ':=: spaces after');
  CheckFalse(State.IsFirstOnLine, ':=: first on the line');

  Index := FindStateIndex('Count');
  CheckEquals(0, FParser.ParsedStateItem[Index].SpaceBefore, 'Count: spaces before');
  State := FParser.ParsedStateItem[Index + 1];
  CheckEquals(';', State.TokenString, 'Semicolon after Count');
  CheckEquals(1, State.SpaceAfter, 'Semicolon: spaces after');
  CheckFalse(State.IsLastOnLine, 'Semicolon before a comment is not last on the line');
  State := FParser.ParsedStateItem[FindStateIndex('// comment')];
  CheckTrue(State.IsLastOnLine, 'Comment is last on the line');

  // The directive line before Run is dropped from the parsed states, the layout comes from the source
  State := FParser.ParsedStateItem[FindStateIndex('Run')];
  CheckEquals(8, Integer(State.CurrentLine), 'Run: line');
  CheckEquals(2, State.Column, 'Run: column after a tab');
  CheckEquals(1, State.SpaceBefore, 'Run: indentation with a tab');
  CheckTrue(State.IsFirstOnLine, 'Run: first on the line');
  CheckEquals('Run', FParser.SourceTokenItem[State.SourceTokenIndex].TokenString, 'Source token of Run');

  CheckEquals(12, FParser.LineCount, 'Lines: the line break at the end does not start a line');
  CheckEquals(2, FParser.LineItem[6].Indent, 'Indentation of line 6');
  CheckEquals(Length('  Value  :=Count; // comment'), FParser.LineItem[6].LineLength, 'Length of line 6');
  CheckEquals(4, FParser.LineItem[7].Indent, 'Indentation of the directive line');
  CheckTrue(FParser.LineItem[10].IsBlank, 'Blank line');
  CheckEquals(0, FParser.LineItem[10].LineLength, 'Length of the blank line');
  CheckFalse(FParser.LineItem[11].IsBlank, 'Not blank line');
  CheckEquals('end', FParser.SourceTokenItem[FParser.LineItem[11].FirstTokenIndex].TokenString, 'First token of line 11');
end;

procedure TestTPasParser.TestLayoutAfterMultiLineDirective;
var
  State: TPasLexerMinimalState;
begin
  CheckParsed('unit Layout;' + sLineBreak
      + '{$DEFINE A' + sLineBreak
      + sLineBreak
      + '}interface' + sLineBreak
      + 'implementation' + sLineBreak
      + 'end.', 'Multi-line directive');
  State := FParser.ParsedStateItem[FindStateIndex('interface')];
  CheckEquals(4, Integer(State.CurrentLine), 'interface: line');
  CheckEquals(2, State.Column, 'interface: column');
  CheckFalse(State.IsFirstOnLine, 'interface: the directive is before it on the line');
  CheckEquals(5, Integer(FParser.ParsedStateItem[FindStateIndex('implementation')].CurrentLine), 'implementation: line');
  CheckEquals(-1, FParser.LineItem[3].FirstTokenIndex, 'Line inside the directive has no tokens');
end;

procedure TestTPasParser.TestOwnTokens;
var
  IfNode, Assignment, Binary: TBaseLexemeNode;
  ThenIndex, ElseIndex: Integer;
  OwnTokens: TArray<Integer>;
begin
  CheckParsed(MakeStatements(
      '  if Ready then' + sLineBreak
      + '    Run' + sLineBreak
      + '  else' + sLineBreak
      + '    Stop;' + sLineBreak
      + '  Value := A + B;'), 'Own tokens');

  IfNode := FindNode(ltIfStatement);
  CheckEquals('if', IfNode.FirstState.TokenString, 'First token of the if statement');
  CheckEquals('Stop', IfNode.LastState.TokenString, 'Last token of the if statement');
  ThenIndex := IfNode.FindOwnToken(tkThen);
  CheckEquals('then', FParser.ParsedStateItem[ThenIndex].TokenString, 'then');
  CheckTrue(FParser.ParsedStateItem[ThenIndex].IsLastOnLine, 'then ends the line');
  ElseIndex := IfNode.FindOwnToken(tkElse);
  CheckEquals('else', FParser.ParsedStateItem[ElseIndex].TokenString, 'else');
  CheckTrue(FParser.ParsedStateItem[ElseIndex].IsFirstOnLine, 'else starts the line');
  CheckEquals(3, FParser.ParsedStateItem[ElseIndex].Column, 'Column of else');
  CheckEquals(-1, IfNode.FindOwnToken(tkSemiColon), 'The semicolon belongs to the block');
  CheckEquals(3, Length(IfNode.GetOwnTokenIndexes), 'Own tokens of the if statement');

  Assignment := FindNode(ltAssignment);
  OwnTokens := Assignment.GetOwnTokenIndexes;
  CheckEquals(1, Length(OwnTokens), 'Own tokens of the assignment');
  CheckEquals(':=', FParser.ParsedStateItem[OwnTokens[0]].TokenString, 'Assignment operator');
  Binary := Assignment.Children[1];
  OwnTokens := Binary.GetOwnTokenIndexes;
  CheckEquals(1, Length(OwnTokens), 'Own tokens of the binary expression');
  CheckEquals(TBinaryExpressionLexemeNode(Binary).OperatorIndex, OwnTokens[0], 'Operator of the binary expression');
  CheckEquals(1, FParser.ParsedStateItem[OwnTokens[0]].SpaceBefore, 'Space before the operator');
  CheckEquals(1, FParser.ParsedStateItem[OwnTokens[0]].SpaceAfter, 'Space after the operator');
end;

procedure TestTPasParser.TestTreeInvariants;
const
  FILE_NAMES: array[0..3] of string = (
    'testunit.pas',
    'BeginEndCountTestUnit1.pas',
    'BeginEndCountTestUnit2.pas',
    'EmptyUnit.pas'
  );
var
  FileName: string;
  NodeCount, TraversalCount: Integer;
  Node, LastNode: TBaseLexemeNode;
begin
  for FileName in FILE_NAMES do
  begin
    CheckParsedFile(GetTestDataFileName(FileName));
    CheckEquals(0, FParser.RootLexeme.StatesStartIndex, FileName + ': start of the root');
    CheckEquals(FParser.ParsedStateCount, FParser.RootLexeme.StatesCount, FileName + ': root covers all states');
    CheckEquals(0, FParser.RootLexeme.Level, FileName + ': level of the root');
    NodeCount := CheckTreeInvariants(FParser.RootLexeme);

    TraversalCount := 0;
    LastNode := nil;
    Node := FParser.RootLexeme;
    while Assigned(Node) do
    begin
      Inc(TraversalCount);
      LastNode := Node;
      Node := Node.NextTraversal;
    end;
    CheckEquals(NodeCount, TraversalCount, FileName + ': forward traversal');

    TraversalCount := 0;
    Node := LastNode;
    while Assigned(Node) do
    begin
      Inc(TraversalCount);
      Node := Node.PrevTraversal;
    end;
    CheckEquals(NodeCount, TraversalCount, FileName + ': backward traversal');
  end;
end;

procedure TestTPasParser.TestSyntaxErrors;
begin
  CheckParseError('', 0, 0, 'Empty source');
  CheckTrue(Pos(EMESSAGE_EXPECTED_MODULE, FParser.ErrorItem[0].Message) > 0, 'Message for an empty source');

  CheckParseError('unit A;' + sLineBreak
      + 'interface' + sLineBreak
      + 'implementation' + sLineBreak
      + 'procedure X;' + sLineBreak
      + 'begin' + sLineBreak
      + 'end' + sLineBreak
      + 'end.', 7, 1, 'Missing semicolon after a routine');

  CheckParseError('unit A;' + sLineBreak
      + 'interface' + sLineBreak
      + 'implementation' + sLineBreak
      + 'procedure X;' + sLineBreak
      + 'begin' + sLineBreak
      + '  Run', 6, 3, 'Unexpected end of file');
  CheckTrue(Pos('end of file', FParser.ErrorItem[0].Message) > 0, 'Message for the end of file');

  CheckParseError('unit A;' + sLineBreak
      + 'interface' + sLineBreak
      + 'type' + sLineBreak
      + '  TFoo = class' + sLineBreak
      + '    procedure X' + sLineBreak
      + '  end;' + sLineBreak
      + 'implementation' + sLineBreak
      + 'end.', 6, 3, 'Missing semicolon after a method');

  CheckParseError('unit A;' + sLineBreak
      + 'interface' + sLineBreak
      + 'implementation' + sLineBreak
      + 'begin' + sLineBreak
      + '  X := ;' + sLineBreak
      + 'end.', 5, 8, 'Missing expression');

  // Unbalanced conditional directives are reported by the lexer
  CheckFalse(FParser.ParseString('unit A;' + sLineBreak + '{$ELSE}' + sLineBreak + 'interface implementation end.'),
      'Unexpected else directive');
  CheckEquals(1, FParser.ErrorCount, 'Error count for the unexpected else directive');
  CheckEquals(EMESSAGE_UNEXPECTED_ELSE_DIRECTIVE, FParser.ErrorItem[0].Message, 'Message for the unexpected else directive');
  CheckNull(FParser.RootLexeme, 'Root lexeme after a lexer error');
  CheckEquals(5, FParser.SourceTokenCount, 'Source tokens before the lexer error');
  CheckEquals(5, FParser.ParsedStateCount, 'Parsed states before the lexer error');
  CheckTrue(FParser.SourceTokenItem[2].SpaceBefore = 1, 'Layout of the tokens before the lexer error');
end;

procedure TestTPasParser.TestTextAfterModuleEnd;
begin
  CheckParsed('unit A;' + sLineBreak
      + 'interface' + sLineBreak
      + 'implementation' + sLineBreak
      + 'end.' + sLineBreak
      + 'Any text ''that is not code', 'Text after the end of the unit');
  CheckEquals('end.', FParser.RootLexeme.FirstChild.LastState.TokenString, 'Last token of the unit');
  CheckTrue(FParser.RootLexeme.StatesEndIndex > FParser.RootLexeme.FirstChild.StatesEndIndex,
      'The root covers the text after the unit');
end;

procedure TestTPasParser.TestParseAgain;
begin
  CheckFalse(FParser.ParseString('unit A; interface'), 'Source with an error');
  CheckEquals(1, FParser.ErrorCount, 'Error count');
  CheckParsed(MakeUnit('', ''), 'Valid source after an error');
  CheckEquals(0, FParser.ErrorCount, 'Errors are cleared');
  FParser.Clear;
  CheckNull(FParser.RootLexeme, 'Root lexeme after Clear');
  CheckEquals(0, FParser.ParsedStateCount, 'Parsed states after Clear');
  CheckEquals(0, FParser.SourceTokenCount, 'Source tokens after Clear');
  CheckEquals(0, FParser.LineCount, 'Lines after Clear');
end;

initialization
  // Register any test cases with the test runner
  RegisterTest(TestTPasParser.Suite);
end.
