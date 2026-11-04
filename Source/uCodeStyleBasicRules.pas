// Sample code style rules, one of every kind: a rule over the lines (TLineLengthRule), over the lexeme tree
// (TWithStatementRule) and over the tokens (TReservedWordCaseRule). Does not depend on the IDE.
unit uCodeStyleBasicRules;

interface

uses
  System.SysUtils, System.Variants, Xml.XMLIntf,
  uPasParser, uPasParserTypes, uPasParserGrammar, uPasLexerTypes,
  uCodeStyleConsts, uCodeStyleRules;

type
  // A line must not be longer than MaxLength characters
  TLineLengthRule = class(TCodeStyleRule)
  private
    FMaxLength: Integer;
  public
    constructor Create; override;

    class function GetCode: string; override;
    class function GetDescription: string; override;

    procedure Check(AContext: TCodeStyleCheckContext); override;
    procedure ReadSettings(ARuleSettings: IXMLNode); override;
    procedure WriteSettings(ARuleSettings: IXMLNode); override;

    property MaxLength: Integer read FMaxLength write FMaxLength;
  end;

  // The with statement is forbidden
  TWithStatementRule = class(TCodeStyleRule)
  public
    class function GetCode: string; override;
    class function GetDescription: string; override;

    procedure Check(AContext: TCodeStyleCheckContext); override;
  end;

  // Reserved words are written in lowercase. Asm blocks are not checked: BASM instructions like AND EAX, EDX are
  // reserved words for the lexer.
  TReservedWordCaseRule = class(TCodeStyleRule)
  private
    class var FReservedWords: TTokenKindSet;
  private
    // Flags of the parsed states inside the asm statements, without the asm and end of the statement
    function GetAsmFlags(AParser: TPasParser): TArray<Boolean>;
    // True when the parsed state at AIndex is a keyword escaped with '&', like &Type
    function IsEscapedWord(AParser: TPasParser; AIndex: Integer): Boolean;
  public
    class constructor ClassCreate;

    class function GetCode: string; override;
    class function GetDescription: string; override;

    procedure Check(AContext: TCodeStyleCheckContext); override;
  end;

implementation

{ TLineLengthRule }

constructor TLineLengthRule.Create;
begin
  inherited Create;

  FMaxLength := DEFAULT_MAX_LINE_LENGTH;
end;

class function TLineLengthRule.GetCode: string;
begin
  Result := CODE_LINE_LENGTH;
end;

class function TLineLengthRule.GetDescription: string;
begin
  Result := RULE_LINE_LENGTH_DESCRIPTION;
end;

procedure TLineLengthRule.Check(AContext: TCodeStyleCheckContext);
var
  LineNumber, LineLength: Integer;
begin
  for LineNumber := 1 to AContext.Parser.LineCount do
  begin
    LineLength := AContext.Parser.LineItem[LineNumber].LineLength;
    if LineLength > FMaxLength then
      AddIssue(AContext, LineNumber, FMaxLength + 1, Format(RULE_LINE_LENGTH_MESSAGE, [LineLength, FMaxLength]));
  end;
end;

procedure TLineLengthRule.ReadSettings(ARuleSettings: IXMLNode);
var
  MaxLengthSetting: OleVariant;
begin
  inherited ReadSettings(ARuleSettings);

  MaxLengthSetting := ARuleSettings.Attributes[SETTINGS_ATTRIBUTE_MAX_LENGTH];
  if not VarIsNull(MaxLengthSetting) then
    FMaxLength := MaxLengthSetting;
  if FMaxLength <= 0 then
    FMaxLength := DEFAULT_MAX_LINE_LENGTH;
end;

procedure TLineLengthRule.WriteSettings(ARuleSettings: IXMLNode);
begin
  inherited WriteSettings(ARuleSettings);

  ARuleSettings.Attributes[SETTINGS_ATTRIBUTE_MAX_LENGTH] := FMaxLength;
end;

{ TWithStatementRule }

class function TWithStatementRule.GetCode: string;
begin
  Result := CODE_WITH_STATEMENT;
end;

class function TWithStatementRule.GetDescription: string;
begin
  Result := RULE_WITH_STATEMENT_DESCRIPTION;
end;

procedure TWithStatementRule.Check(AContext: TCodeStyleCheckContext);
var
  Node: TBaseLexemeNode;
begin
  Node := AContext.Parser.RootLexeme;
  while Assigned(Node) do
  begin
    if Node.NodeType = ltWithStatement then
      AddIssue(AContext, Node.FirstState.CurrentLine, Node.FirstState.Column, RULE_WITH_STATEMENT_MESSAGE);
    Node := Node.NextTraversal;
  end;
end;

{ TReservedWordCaseRule }

class constructor TReservedWordCaseRule.ClassCreate;
var
  Keyword: TKeywordRec;
begin
  // The reserved words come first in DELPHI_KEYWORDS and end with xor, the directives follow them
  FReservedWords := [];
  for Keyword in DELPHI_KEYWORDS do
  begin
    Include(FReservedWords, Keyword.Token);
    if Keyword.Token = tkXor then
      Break;
  end;
end;

function TReservedWordCaseRule.GetAsmFlags(AParser: TPasParser): TArray<Boolean>;
var
  Node: TBaseLexemeNode;
  i: Integer;
begin
  SetLength(Result, AParser.ParsedStateCount);
  for i := 0 to High(Result) do
    Result[i] := False;

  Node := AParser.RootLexeme;
  while Assigned(Node) do
  begin
    if Node.NodeType = ltAsmStatement then
      for i := Node.StatesStartIndex + 1 to Node.StatesEndIndex - 1 do
        Result[i] := True;
    Node := Node.NextTraversal;
  end;
end;

function TReservedWordCaseRule.IsEscapedWord(AParser: TPasParser; AIndex: Integer): Boolean;
var
  PrevState: TPasLexerMinimalState;
begin
  if AIndex = 0 then
    Exit(False);

  PrevState := AParser.ParsedStateItem[AIndex - 1];
  Result := (PrevState.CurrentToken = tkSymbol) and (PrevState.TokenString = '&')
      and (PrevState.CurrentIndex + 1 = AParser.ParsedStateItem[AIndex].CurrentIndex);
end;

class function TReservedWordCaseRule.GetCode: string;
begin
  Result := CODE_RESERVED_WORD_CASE;
end;

class function TReservedWordCaseRule.GetDescription: string;
begin
  Result := RULE_RESERVED_WORD_CASE_DESCRIPTION;
end;

procedure TReservedWordCaseRule.Check(AContext: TCodeStyleCheckContext);
var
  AsmFlags: TArray<Boolean>;
  State: TPasLexerMinimalState;
  i: Integer;
begin
  AsmFlags := GetAsmFlags(AContext.Parser);
  for i := 0 to AContext.Parser.ParsedStateCount - 1 do
  begin
    if AsmFlags[i] then
      Continue;

    State := AContext.Parser.ParsedStateItem[i];
    // tkString is also a string literal, a word starts with a letter
    if (State.CurrentToken in FReservedWords) and (State.TokenString <> '')
        and CharInSet(State.TokenString[1], ['A'..'Z', 'a'..'z'])
        and (State.TokenString <> LowerCase(State.TokenString))
        and (not IsEscapedWord(AContext.Parser, i))
    then
      AddIssue(AContext, State.CurrentLine, State.Column, Format(RULE_RESERVED_WORD_CASE_MESSAGE, [State.TokenString]));
  end;
end;

initialization
  TCodeStyleRuleSet.RegisterRule(TLineLengthRule);
  TCodeStyleRuleSet.RegisterRule(TWithStatementRule);
  TCodeStyleRuleSet.RegisterRule(TReservedWordCaseRule);

end.
