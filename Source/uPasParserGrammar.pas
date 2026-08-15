unit uPasParserGrammar;

interface

uses
  System.SysUtils,
  uPasParserTypes, uPasLexerTypes;

type
  TBaseLexemeNode = class;

  TStatesRecord = record
  private
    FLexemeOwner: TBaseLexemeNode;
    FParserStates: PLexerStateArray;
    FStartIndex: Integer;
    FCount: Integer;
    FCurrentIndex: Integer;

    function GetCurrentToken: TTokenKind;
    function GetCurrentTokenString: string;
  public
    procedure Init(AOwner: TBaseLexemeNode; AParserStates: PLexerStateArray; AStartIndex, ACount: Integer);

    procedure SkipUnsignificantTokens;
    function GetNextSignificantToken: Boolean;
    function GetNextToken: Boolean;

    procedure GetNextSignificantTokenOrRaise;
    procedure CheckForTokenOrRaise(AToken: TTokenKind);

    property ParserStates: PLexerStateArray read FParserStates;
    property StartIndex: Integer read FStartIndex;
    property Count: Integer read FCount;
    property CurrentToken: TTokenKind read GetCurrentToken;
    property CurrentTokenString: string read GetCurrentTokenString;
  end;

  TBaseLexemeNode = class abstract(TObject)
  private
    FParentNode: TBaseLexemeNode;
    FParserStateRecord: TStatesRecord;
    FChildNodes: TArray<TBaseLexemeNode>;
    FParentChildIndex: Integer;
  protected
    // Node adds itself to parent childs. Method will be called in node constructor for parent node.
    function AddChildNode(ANode: TBaseLexemeNode): Integer;
    procedure RemoveChildNode(ANode: TBaseLexemeNode);

    function GetNextChildNodeForIndex(AFromIndex: Integer): TBaseLexemeNode;
    function GetPrevChildNodeForIndex(AFromIndex: Integer): TBaseLexemeNode;

    procedure InternalParseItself; virtual; abstract;
    procedure FinalyzeNodeEnd; virtual;

    function GetFirstChild: TBaseLexemeNode;
    function GetLastChild: TBaseLexemeNode;
    function GetNextTraversal: TBaseLexemeNode;
    function GetPrevTraversal: TBaseLexemeNode;
    function GetNextSibling: TBaseLexemeNode;
    function GetPrevSibling: TBaseLexemeNode;
    function GetStatesStartIndex: Integer; inline;
    function GetStatesCount: Integer; inline;
    function GetStatesCurrentIndexLineNumber: Integer; inline;
    function GetStatesCurrentIndexLineCharIndex: Integer; inline;
    function GetStatesCurrentIndexToken: TTokenKind; inline;
    function GetStatesCurrentTokenString: string; inline;

    function GetNodeType: TLexemeType; virtual; abstract;
  public
    constructor Create(AParent: TBaseLexemeNode; AParserStates: PLexerStateArray; AStartIndex, AStatesCount: Integer); overload;
    constructor Create(AParent: TBaseLexemeNode; const AParentStateRecord: TStatesRecord); overload;
    destructor Destroy; override;

    procedure ParseItself; virtual;
    function GetLexemeLog: string; virtual;

    property ParentNode: TBaseLexemeNode read FParentNode;
    property FirstChild: TBaseLexemeNode read GetFirstChild;
    property LastChild: TBaseLexemeNode read GetLastChild;
    property NextTraversal: TBaseLexemeNode read GetNextTraversal;
    property PrevTraversal: TBaseLexemeNode read GetPrevTraversal;
    property NextSibling: TBaseLexemeNode read GetNextSibling;
    property PrevSibling: TBaseLexemeNode read GetPrevSibling;
    property NodeType: TLexemeType read GetNodeType;

    property StatesStartIndex: Integer read GetStatesStartIndex;
    property StatesCount: Integer read GetStatesCount;
    property StatesCurrentIndexLineNumber: Integer read GetStatesCurrentIndexLineNumber;
    property StatesCurrentIndexLineCharIndex: Integer read GetStatesCurrentIndexLineCharIndex;
    property StatesCurrentIndexToken: TTokenKind read GetStatesCurrentIndexToken;
    property StatesCurrentTokenString: string read GetStatesCurrentTokenString;
  end;

  TRootLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TProgramLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TUnitLexemeNode = class(TBaseLexemeNode)
  private
    FUnitName: string;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  public
    function GetLexemeLog: string; override;
  end;

  TPackageLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TLibraryLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
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

  TUsesClauseLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TBeginEndBlockLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TConstBlockLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TTypeSectionLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TVarSectionLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TConstDeclarationLexemeNode = class(TBaseLexemeNode)
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  end;

  TIdentifierLexemeNode = class(TBaseLexemeNode)
  private
    FIdentifierString: string;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  public
    function GetLexemeLog: string; override;
  end;

  TTypeIdentifierLexemeNode = class(TBaseLexemeNode)
  private
    FTypeIdentifierString: string;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  public
    function GetLexemeLog: string; override;
  end;

  TConstValueLexemeNode = class(TBaseLexemeNode)
  private
    FConstValueString: string;
  protected
    function GetNodeType: TLexemeType; override;
    procedure InternalParseItself; override;
  public
    function GetLexemeLog: string; override;
  end;

implementation

uses
  uPasExceptions; // +++ лишние модули

{ TStatesRecord }

function TStatesRecord.GetCurrentToken: TTokenKind;
begin
  Result := FParserStates^[FCurrentIndex].CurrentToken; // +++ проверить что нельзя уйти за границы
end;

function TStatesRecord.GetCurrentTokenString: string;
begin
  Result := FParserStates^[FCurrentIndex].TokenString; // +++ проверить что нельзя уйти за границы
end;

procedure TStatesRecord.Init(AOwner: TBaseLexemeNode; AParserStates: PLexerStateArray; AStartIndex, ACount: Integer);
begin
  FLexemeOwner := AOwner;
  FParserStates := AParserStates;
  FStartIndex := AStartIndex;
  FCount := ACount;
  FCurrentIndex := FStartIndex;
end;

procedure TStatesRecord.SkipUnsignificantTokens;
begin
  while CurrentToken in UNSIGNIFICANT_TOKENS do
    if not GetNextToken then Exit;
end;

function TStatesRecord.GetNextSignificantToken: Boolean;
begin
  while GetNextToken do
    if not(CurrentToken in UNSIGNIFICANT_TOKENS) then
      Exit(True);

  Result := False;
end;

function TStatesRecord.GetNextToken: Boolean;
begin
  Inc(FCurrentIndex);
  Result := FCurrentIndex < (FStartIndex + FCount);
  if not Result then
    Dec(FCurrentIndex);
end;

procedure TStatesRecord.GetNextSignificantTokenOrRaise;
begin
  if not GetNextSignificantToken then
    raise EPasGrammarParserException.CreateFmt(EMESSAGE_GRAMMAR_UNEXPECTED_ENDOFBLOCK, [FLexemeOwner.ClassName], FLexemeOwner);
end;

procedure TStatesRecord.CheckForTokenOrRaise(AToken: TTokenKind);
begin
  if CurrentToken <> AToken then
    raise EPasGrammarParserException.CreateFmt(EMESSAGE_GRAMMAR_UNEXPECTED_TOKEN,
        [TOKEN_NAMES[AToken], TOKEN_NAMES[CurrentToken]], FLexemeOwner);
end;

{ TBaseLexemeNode }

constructor TBaseLexemeNode.Create(AParent: TBaseLexemeNode; AParserStates: PLexerStateArray; AStartIndex, AStatesCount: Integer);
begin
  inherited Create;

  FParentNode := AParent;
  FParserStateRecord.Init(Self, AParserStates, AStartIndex, AStatesCount);

  if Assigned(FParentNode) then
    FParentChildIndex := FParentNode.AddChildNode(Self)
  else
    FParentChildIndex := -1;
end;

constructor TBaseLexemeNode.Create(AParent: TBaseLexemeNode; const AParentStateRecord: TStatesRecord);
begin
  Create(AParent, AParentStateRecord.ParserStates, AParentStateRecord.FCurrentIndex,
      AParentStateRecord.Count - (AParentStateRecord.FCurrentIndex - AParentStateRecord.StartIndex));
end;

destructor TBaseLexemeNode.Destroy;
var
  CurrentChild: TBaseLexemeNode;
begin
  for CurrentChild in FChildNodes do
    CurrentChild.Free;
  SetLength(FChildNodes, 0);

  inherited Destroy;
end;

function TBaseLexemeNode.AddChildNode(ANode: TBaseLexemeNode): Integer;
begin
  Result := Length(FChildNodes);
  SetLength(FChildNodes, Result + 1);
  FChildNodes[Result] := ANode;
end;

procedure TBaseLexemeNode.RemoveChildNode(ANode: TBaseLexemeNode);
var
  i: Integer;
begin
  for i := Low(FChildNodes) to High(FChildNodes) do
    if FChildNodes[i] = ANode then
    begin
      if i < High(FChildNodes) then
        Move(FChildNodes[i + 1], FChildNodes[i], SizeOf(TBaseLexemeNode));
      SetLength(FChildNodes, Length(FChildNodes) - 1);
      Break;
    end;
end;

function TBaseLexemeNode.GetNextChildNodeForIndex(AFromIndex: Integer): TBaseLexemeNode;
begin
  Inc(AFromIndex);
  if High(FChildNodes) < AFromIndex then
    Result := nil
  else
    Result := FChildNodes[AFromIndex];
end;

function TBaseLexemeNode.GetPrevChildNodeForIndex(AFromIndex: Integer): TBaseLexemeNode;
begin
  Dec(AFromIndex);
  if Low(FChildNodes) > AFromIndex then
    Result := nil
  else
    Result := FChildNodes[AFromIndex];
end;

procedure TBaseLexemeNode.FinalyzeNodeEnd;
begin
  FParserStateRecord.FCount := FParserStateRecord.FCurrentIndex - FParserStateRecord.StartIndex;
  if Assigned(FParentNode) then
    FParentNode.FParserStateRecord.FCurrentIndex := StatesStartIndex + StatesCount;
end;

function TBaseLexemeNode.GetFirstChild: TBaseLexemeNode;
begin
  if Length(FChildNodes) > 0 then
    Result := FChildNodes[0]
  else
    Result := nil;
end;

function TBaseLexemeNode.GetLastChild: TBaseLexemeNode;
begin
  if Length(FChildNodes) > 0 then
    Result := FChildNodes[High(FChildNodes)]
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
      Exit(TempNode)
    else
      Result := Result.ParentNode;
  end;
end;

function TBaseLexemeNode.GetPrevTraversal: TBaseLexemeNode;
var
  TempNode: TBaseLexemeNode;
begin
  Result := GetPrevSibling;
  if not Assigned(Result) then Exit(ParentNode);

  TempNode := Result.GetLastChild;
  while TempNode <> nil do
  begin
    Result := TempNode;
    TempNode := Result.GetLastChild;
  end;
  // +++ проверить
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

function TBaseLexemeNode.GetStatesStartIndex: Integer;
begin
  Result := FParserStateRecord.StartIndex;
end;

function TBaseLexemeNode.GetStatesCount: Integer;
begin
  Result := FParserStateRecord.Count;
end;

function TBaseLexemeNode.GetStatesCurrentIndexLineNumber: Integer;
begin
  Result := FParserStateRecord.FParserStates^[FParserStateRecord.FCurrentIndex].CurrentLine;
end;

function TBaseLexemeNode.GetStatesCurrentIndexLineCharIndex: Integer;
begin
  Result := FParserStateRecord.FParserStates^[FParserStateRecord.FCurrentIndex].CurrentIndex
      - FParserStateRecord.FParserStates^[FParserStateRecord.FCurrentIndex].CurrentLineStartPos + 1;
end;

function TBaseLexemeNode.GetStatesCurrentIndexToken: TTokenKind;
begin
  Result := FParserStateRecord.FParserStates^[FParserStateRecord.FCurrentIndex].CurrentToken;
end;

function TBaseLexemeNode.GetStatesCurrentTokenString: string;
begin
  Result := FParserStateRecord.FParserStates^[FParserStateRecord.FCurrentIndex].TokenString;
end;

procedure TBaseLexemeNode.ParseItself;
begin
  InternalParseItself;
  FinalyzeNodeEnd;
end;

function TBaseLexemeNode.GetLexemeLog: string;
begin
  Result := LEXEME_NAMES[NodeType] + '(Start: ' + IntToStr(Self.StatesStartIndex)
      + ', Count: ' + IntToStr(Self.StatesCount) + ')';
end;

{ TRootLexemeNode }

function TRootLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltRoot;
end;

procedure TRootLexemeNode.InternalParseItself;
var
  NewNode: TBaseLexemeNode;
begin
  FParserStateRecord.SkipUnsignificantTokens;

  case StatesCurrentIndexToken of
    tkProgram: NewNode := TProgramLexemeNode.Create(Self, FParserStateRecord);
    tkPackage: NewNode := TPackageLexemeNode.Create(Self, FParserStateRecord);
    tkLibrary: NewNode := TLibraryLexemeNode.Create(Self, FParserStateRecord);
    tkUnit: NewNode := TUnitLexemeNode.Create(Self, FParserStateRecord);
  else
    raise EPasGrammarParserException.CreateFmt(EMESSAGE_GRAMMAR_UNEXPECTED_TOKEN,
        [GetTokenSetStringForOR([tkProgram, tkPackage, tkLibrary, tkUnit]),
        TOKEN_NAMES[StatesCurrentIndexToken]], Self);
  end;

  NewNode.ParseItself;
  FParserStateRecord.FCount := NewNode.StatesCount;

  if Length(FParserStateRecord.FParserStates^) > (FParserStateRecord.FCurrentIndex + 1) then
  begin
    while Length(FParserStateRecord.FParserStates^) > (FParserStateRecord.FCurrentIndex + 1) do
    begin
      Inc(FParserStateRecord.FCurrentIndex);
      if not(StatesCurrentIndexToken in DIRECTIVE_UNSIGNIFICANT_TOKENS) then
        raise EPasGrammarParserException.CreateFmt(EMESSAGE_GRAMMAR_UNEXPECTED_TOKEN,
            [TOKEN_NAMES[tkUnknown], TOKEN_NAMES[StatesCurrentIndexToken]], Self);
    end;
  end;
end;

{ TProgramLexemeNode }

function TProgramLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltProgram;
end;

procedure TProgramLexemeNode.InternalParseItself;
begin

end;

{ TUnitLexemeNode }

function TUnitLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltUnit;
end;

procedure TUnitLexemeNode.InternalParseItself;
var
  NewNode: TBaseLexemeNode;
begin
  FParserStateRecord.GetNextSignificantTokenOrRaise; // unit name
  FUnitName := StatesCurrentTokenString;
  FParserStateRecord.GetNextSignificantTokenOrRaise;  // semicolon
  FParserStateRecord.GetNextSignificantTokenOrRaise;  // interface

  // +++ добавить обработку PortabilityDirective

  FParserStateRecord.CheckForTokenOrRaise(tkInterface);
  NewNode := TInterfaceSectionLexemeNode.Create(Self, FParserStateRecord);
  NewNode.ParseItself;

  FParserStateRecord.CheckForTokenOrRaise(tkImplementation);
  NewNode := TImplementationSectionLexemeNode.Create(Self, FParserStateRecord);
  NewNode.ParseItself;

  // Check for other sections
  FParserStateRecord.SkipUnsignificantTokens;
  case StatesCurrentIndexToken of
    tkInitialization:
    begin
      NewNode := TInitializationSectionLexemeNode.Create(Self, FParserStateRecord);
      NewNode.ParseItself;

      // Check for finalization
      FParserStateRecord.SkipUnsignificantTokens;
      if StatesCurrentIndexToken = tkFinalization then
      begin
        NewNode := TFinalizationSectionLexemeNode.Create(Self, FParserStateRecord);
        NewNode.ParseItself;
      end;

      FParserStateRecord.SkipUnsignificantTokens;
    end;
    tkFinalization:
    begin
      NewNode := TFinalizationSectionLexemeNode.Create(Self, FParserStateRecord);
      NewNode.ParseItself;

      FParserStateRecord.SkipUnsignificantTokens;
    end;
    tkBegin:
    begin
      NewNode := TBeginEndBlockLexemeNode.Create(Self, FParserStateRecord);
      NewNode.ParseItself;

      FParserStateRecord.SkipUnsignificantTokens;
    end;
  end;

  // +++ переделать, чтобы определить точку в конце
  FParserStateRecord.CheckForTokenOrRaise(tkUnitEnd);
  //FinalyzeNodeEnd;
  Inc(FParserStateRecord.FCurrentIndex);
end;

function TUnitLexemeNode.GetLexemeLog: string;
begin
  Result := inherited GetLexemeLog + ' ' + FUnitName;
end;

{ TPackageLexemeNode }

function TPackageLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltPackage;
end;

procedure TPackageLexemeNode.InternalParseItself;
begin

end;

{ TLibraryLexemeNode }

function TLibraryLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltLibrary;
end;

procedure TLibraryLexemeNode.InternalParseItself;
begin

end;

{ TInterfaceSectionLexemeNode }

function TInterfaceSectionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltInterface;
end;

procedure TInterfaceSectionLexemeNode.InternalParseItself;
var
  NewNode: TBaseLexemeNode;
begin
  // Check for uses
  FParserStateRecord.GetNextSignificantTokenOrRaise;
  if StatesCurrentIndexToken = tkUses then
  begin
    NewNode := TUsesClauseLexemeNode.Create(Self, FParserStateRecord);
    NewNode.ParseItself;
  end;

  // Check for blocks
  FParserStateRecord.SkipUnsignificantTokens;
  while StatesCurrentIndexToken <> tkImplementation do
  begin
    NewNode := nil;
    case StatesCurrentIndexToken of
      tkConst: NewNode := TConstBlockLexemeNode.Create(Self, FParserStateRecord);
      tkResourcestring: FParserStateRecord.GetNextToken;
      tkType: NewNode := TTypeSectionLexemeNode.Create(Self, FParserStateRecord);
      tkVar: NewNode := TVarSectionLexemeNode.Create(Self, FParserStateRecord);
      tkThreadvar: FParserStateRecord.GetNextToken;
      tkProcedure: FParserStateRecord.GetNextToken;
      tkFunction: FParserStateRecord.GetNextToken;
      tkExports: FParserStateRecord.GetNextToken;
    else
      raise EPasGrammarParserException.CreateFmt(EMESSAGE_GRAMMAR_UNEXPECTED_TOKEN,
          [GetTokenSetStringForOR([tkConst, tkResourcestring, tkType, tkVar, tkThreadvar, tkProcedure, tkFunction, tkExports]),
          TOKEN_NAMES[StatesCurrentIndexToken]], Self);
    end;
    if Assigned(NewNode) then
      NewNode.ParseItself;
    FParserStateRecord.SkipUnsignificantTokens;
  end;
end;

{ TImplementationSectionLexemeNode }

function TImplementationSectionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltImplementation;
end;

procedure TImplementationSectionLexemeNode.InternalParseItself;
var
  NewNode: TBaseLexemeNode;
begin
  // Check for uses
  FParserStateRecord.GetNextSignificantTokenOrRaise;
  if StatesCurrentIndexToken = tkUses then
  begin
    NewNode := TUsesClauseLexemeNode.Create(Self, FParserStateRecord);
    NewNode.ParseItself;
  end;

  // Check for blocks
  FParserStateRecord.SkipUnsignificantTokens;
  while not(StatesCurrentIndexToken in [tkInitialization, tkFinalization, tkBegin, tkUnitEnd]) do
  begin
    NewNode := nil;
    case StatesCurrentIndexToken of
      tkLabel: FParserStateRecord.GetNextToken;
      tkConst: NewNode := TConstBlockLexemeNode.Create(Self, FParserStateRecord);
      tkResourcestring: FParserStateRecord.GetNextToken;
      tkType: NewNode := TTypeSectionLexemeNode.Create(Self, FParserStateRecord);
      tkVar: NewNode := TVarSectionLexemeNode.Create(Self, FParserStateRecord);
      tkThreadvar: FParserStateRecord.GetNextToken;
      tkProcedure: FParserStateRecord.GetNextToken;
      tkFunction: FParserStateRecord.GetNextToken;
      tkConstructor: FParserStateRecord.GetNextToken;
      tkDestructor: FParserStateRecord.GetNextToken;
      tkClass: FParserStateRecord.GetNextToken;
      tkExports: FParserStateRecord.GetNextToken;
    else
      raise EPasGrammarParserException.CreateFmt(EMESSAGE_GRAMMAR_UNEXPECTED_TOKEN,
          [GetTokenSetStringForOR([tkLabel, tkConst, tkResourcestring, tkType, tkVar, tkThreadvar, tkProcedure,
          tkFunction, tkConstructor, tkDestructor, tkClass, tkExports]),
          TOKEN_NAMES[StatesCurrentIndexToken]], Self);
    end;
    if Assigned(NewNode) then
      NewNode.ParseItself;
    FParserStateRecord.SkipUnsignificantTokens;
  end;
end;

{ TInitializationSectionLexemeNode }

function TInitializationSectionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltInitialization;
end;

procedure TInitializationSectionLexemeNode.InternalParseItself;
begin
  FParserStateRecord.GetNextToken;
end;

{ TFinalizationSectionLexemeNode }

function TFinalizationSectionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltFinalization;
end;

procedure TFinalizationSectionLexemeNode.InternalParseItself;
begin
  FParserStateRecord.GetNextToken;
end;

{ TUsesClauseLexemeNode }

function TUsesClauseLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltUses;
end;

procedure TUsesClauseLexemeNode.InternalParseItself;
var
  NewNode: TBaseLexemeNode;
begin
  FParserStateRecord.GetNextSignificantTokenOrRaise;

  while StatesCurrentIndexToken <> tkSemiColon do
  begin
    case StatesCurrentIndexToken of
      tkIdentifier:
      begin
        NewNode := TIdentifierLexemeNode.Create(Self, FParserStateRecord);
        NewNode.ParseItself;
      end;
      tkComma:
        FParserStateRecord.GetNextSignificantTokenOrRaise;
    else
      raise EPasGrammarParserException.CreateFmt(EMESSAGE_GRAMMAR_UNEXPECTED_TOKEN,
          [GetTokenSetStringForOR([tkIdentifier, tkComma]),
          TOKEN_NAMES[StatesCurrentIndexToken]], Self);
    end;
  end;

  if not FParserStateRecord.GetNextToken then
    raise EPasGrammarParserException.CreateFmt(EMESSAGE_GRAMMAR_UNEXPECTED_ENDOFBLOCK, [Self.ClassName], Self);
end;

{ TBeginEndBlockLexemeNode }

function TBeginEndBlockLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltBeginEnd;
end;

procedure TBeginEndBlockLexemeNode.InternalParseItself;
begin
  FParserStateRecord.GetNextToken;

  // +++ учесть, что в конце может быть UnitEnd, а не просто end
end;

{ TConstBlockLexemeNode }

function TConstBlockLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltConstSection;
end;

procedure TConstBlockLexemeNode.InternalParseItself;
var
  SavedIndex: Integer;
  NewNode: TBaseLexemeNode;
begin
  FParserStateRecord.GetNextSignificantTokenOrRaise;
  FParserStateRecord.CheckForTokenOrRaise(tkIdentifier);

  SavedIndex := FParserStateRecord.FCurrentIndex;
  while StatesCurrentIndexToken = tkIdentifier do
  begin
    NewNode := TConstDeclarationLexemeNode.Create(Self, FParserStateRecord);
    NewNode.ParseItself;

    SavedIndex := FParserStateRecord.FCurrentIndex;
    FParserStateRecord.GetNextSignificantTokenOrRaise;
  end;

  FParserStateRecord.FCurrentIndex := SavedIndex;
end;

{ TTypeSectionLexemeNode }

function TTypeSectionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltTypeSection;
end;

procedure TTypeSectionLexemeNode.InternalParseItself;
begin
  FParserStateRecord.GetNextToken;
end;

{ TVarSectionLexemeNode }

function TVarSectionLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltVarSection;
end;

procedure TVarSectionLexemeNode.InternalParseItself;
begin
  FParserStateRecord.GetNextToken;
end;

{ TConstDeclarationLexemeNode }

function TConstDeclarationLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltConstDeclaration;
end;

procedure TConstDeclarationLexemeNode.InternalParseItself;
var
  NewNode: TBaseLexemeNode;
begin
  NewNode := TIdentifierLexemeNode.Create(Self, FParserStateRecord);
  NewNode.ParseItself;
  FParserStateRecord.SkipUnsignificantTokens;

  case StatesCurrentIndexToken of
    tkColon:
    begin
      FParserStateRecord.GetNextSignificantTokenOrRaise;

      NewNode := TTypeIdentifierLexemeNode.Create(Self, FParserStateRecord);
      NewNode.ParseItself;
      FParserStateRecord.SkipUnsignificantTokens;

      FParserStateRecord.CheckForTokenOrRaise(tkEqual);
      FParserStateRecord.GetNextSignificantTokenOrRaise;
      NewNode := TConstValueLexemeNode.Create(Self, FParserStateRecord);
      NewNode.ParseItself;
    end;
    tkEqual:
    begin
      FParserStateRecord.GetNextSignificantTokenOrRaise;
      NewNode := TConstValueLexemeNode.Create(Self, FParserStateRecord);
      NewNode.ParseItself;
    end;
  else
    raise EPasGrammarParserException.CreateFmt(EMESSAGE_GRAMMAR_UNEXPECTED_TOKEN,
        [GetTokenSetStringForOR([tkColon, tkEqual]), TOKEN_NAMES[StatesCurrentIndexToken]], Self);
  end;

  FParserStateRecord.CheckForTokenOrRaise(tkSemicolon);
  if not FParserStateRecord.GetNextToken then
    raise EPasGrammarParserException.CreateFmt(EMESSAGE_GRAMMAR_UNEXPECTED_ENDOFBLOCK, [Self.ClassName], Self);
end;

{ TIdentifierLexemeNode }

function TIdentifierLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltIdentifier;
end;

procedure TIdentifierLexemeNode.InternalParseItself;
begin
  FIdentifierString := EmptyStr;

  while StatesCurrentIndexToken in [tkIdentifier, tkPoint] do
  begin
    FIdentifierString := FIdentifierString + StatesCurrentTokenString;
    FParserStateRecord.GetNextSignificantTokenOrRaise;
  end;
end;

function TIdentifierLexemeNode.GetLexemeLog: string;
begin
  Result := inherited GetLexemeLog + ' ' + FIdentifierString;
end;

{ TTypeIdentifierLexemeNode }

function TTypeIdentifierLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltTypeIdentifier;
end;

procedure TTypeIdentifierLexemeNode.InternalParseItself;
begin
  case StatesCurrentIndexToken of
    tkIdentifier:;
    tkArray:;
    tkClass:;
    tkFunction:;
    tkPacked:;
    tkProcedure:;
    tkRecord:;
    tkSet:;
    tkString: FTypeIdentifierString := FTypeIdentifierString + StatesCurrentTokenString;
  else
    raise EPasGrammarParserException.CreateFmt(EMESSAGE_GRAMMAR_UNEXPECTED_TOKEN,
        [GetTokenSetStringForOR([tkIdentifier, tkArray, tkClass, tkFunction, tkPacked, tkProcedure, tkRecord, tkSet, tkString]),
        TOKEN_NAMES[StatesCurrentIndexToken]], Self);
  end;

  FParserStateRecord.GetNextSignificantToken;
end;

function TTypeIdentifierLexemeNode.GetLexemeLog: string;
begin
  Result := inherited GetLexemeLog + ' ' + FTypeIdentifierString;
end;

{ TConstValueLexemeNode }

function TConstValueLexemeNode.GetNodeType: TLexemeType;
begin
  Result := ltConstValue;
end;

procedure TConstValueLexemeNode.InternalParseItself;
var
  RoundCount, SquareCount: Integer;
begin
  // +++ проверить что все варианты учитываются
  case StatesCurrentIndexToken of
    tkRoundOpen, tkSquareOpen:
    begin
      RoundCount := 0;
      SquareCount := 0;

      repeat
        if (RoundCount <= 0) and (SquareCount <= 0) and (FParserStateRecord.FCurrentIndex <> StatesStartIndex) then
          Break;

        case StatesCurrentIndexToken of
          tkRoundOpen: Inc(RoundCount);
          tkSquareOpen: Inc(SquareCount);
          tkRoundClose: Dec(RoundCount);
          tkSquareClose: Dec(SquareCount);
        end;

        FConstValueString := FConstValueString + StatesCurrentTokenString;
      until not FParserStateRecord.GetNextToken;
    end;
  else
    begin
      repeat
        if Self.StatesCurrentIndexToken = tkSemicolon then
          Break;

        FConstValueString := FConstValueString + StatesCurrentTokenString;
      until not FParserStateRecord.GetNextToken;
    end;
  end;
end;

function TConstValueLexemeNode.GetLexemeLog: string;
begin
  Result := inherited GetLexemeLog + ' ' + FConstValueString;
end;

end.
