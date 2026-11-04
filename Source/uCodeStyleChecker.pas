// Code style check of one Pascal source: parses it with TPasParser and runs the enabled rules. Does not depend on the
// IDE, so it can also be used by unit tests and command line tools.
unit uCodeStyleChecker;

interface

uses
  System.SysUtils, System.Generics.Defaults,
  uPasParser, uPasParserTypes,
  uCodeStyleConsts, uCodeStyleRules;

type
  TCodeStyleChecker = class(TObject)
  private
    FParser: TPasParser;
    FRuleSet: TCodeStyleRuleSet;
    FIssueComparer: IComparer<TCodeStyleIssue>;
  public
    // The rule set is not owned
    constructor Create(ARuleSet: TCodeStyleRuleSet);
    destructor Destroy; override;

    // Parses ASource and checks it with the enabled rules; adds the issues to AIssues and sorts it by the position. A
    // source with a syntax error is not checked, the error is added as a hint.
    procedure CheckSource(const AFileName, ASource: string; AIssues: TCodeStyleIssueList);

    property RuleSet: TCodeStyleRuleSet read FRuleSet;
  end;

implementation

{ TCodeStyleChecker }

constructor TCodeStyleChecker.Create(ARuleSet: TCodeStyleRuleSet);
begin
  inherited Create;

  FParser := TPasParser.Create;
  FRuleSet := ARuleSet;
  FIssueComparer := TComparer<TCodeStyleIssue>.Construct(
    function(const ALeft, ARight: TCodeStyleIssue): Integer
    begin
      Result := ALeft.LineNumber - ARight.LineNumber;
      if Result = 0 then
        Result := ALeft.Column - ARight.Column;
      if Result = 0 then
        Result := CompareStr(ALeft.Code, ARight.Code);
    end
  );
end;

destructor TCodeStyleChecker.Destroy;
begin
  FIssueComparer := nil;
  FreeAndNil(FParser);

  inherited Destroy;
end;

procedure TCodeStyleChecker.CheckSource(const AFileName, ASource: string; AIssues: TCodeStyleIssueList);
var
  Context: TCodeStyleCheckContext;
  ParseError: TParseErrorItem;
  i: Integer;
begin
  Context := TCodeStyleCheckContext.Create(AFileName, FParser, AIssues);
  try
    try
      if FParser.ParseString(ASource) then
      begin
        for i := 0 to FRuleSet.Count - 1 do
          if FRuleSet[i].Enabled then
            FRuleSet[i].Check(Context);
      end
      else if FParser.ErrorCount > 0 then
      begin
        ParseError := FParser.ErrorItem[0];
        Context.AddIssue(CODE_PARSE_ERROR, cssHint, ParseError.LineNumber, ParseError.LinePosition,
            Format(MESSAGE_PARSE_ERROR, [ParseError.Message]));
      end;
    finally
      // The parser keeps a copy of the source and the tree, they are not needed until the next check
      FParser.Clear;
    end;
  finally
    Context.Free;
  end;

  AIssues.Sort(FIssueComparer);
end;

end.
