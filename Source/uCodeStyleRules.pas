// Base of the code style rules: the found issues, the context of a check, the base rule class and the set of the
// registered rules. Does not depend on the IDE.
unit uCodeStyleRules;

interface

uses
  System.SysUtils, System.Classes, System.Contnrs, System.Variants, System.Generics.Collections, Xml.XMLIntf,
  uPasParser,
  uCodeStyleConsts;

type
  TCodeStyleSeverity = (
    cssHint,
    cssWarning
  );

  // An issue found in a source
  TCodeStyleIssue = record
    // Code of the rule or of the message, like CS1001
    Code: string;
    Severity: TCodeStyleSeverity;
    // Position of the issue, both 1-based
    LineNumber: Integer;
    Column: Integer;
    Message: string;
  end;

  TCodeStyleIssueList = TList<TCodeStyleIssue>;

  // Data of one check: the parsed source and the list of the found issues
  TCodeStyleCheckContext = class(TObject)
  private
    FFileName: string;
    FParser: TPasParser;
    FIssues: TCodeStyleIssueList;
  public
    constructor Create(const AFileName: string; AParser: TPasParser; AIssues: TCodeStyleIssueList);

    procedure AddIssue(const ACode: string; ASeverity: TCodeStyleSeverity; ALineNumber, AColumn: Integer;
        const AMessage: string);

    property FileName: string read FFileName;
    // Parsed source with the lexeme tree: sources with a syntax error are not passed to the rules
    property Parser: TPasParser read FParser;
    property Issues: TCodeStyleIssueList read FIssues;
  end;

  // Base class of the code style rules. A rule class is registered with TCodeStyleRuleSet.RegisterRule in the
  // initialization section of its unit; every TCodeStyleRuleSet creates one object of every registered rule.
  TCodeStyleRule = class(TObject)
  private
    FEnabled: Boolean;
  protected
    // Adds an issue with the code and the severity of the rule
    procedure AddIssue(AContext: TCodeStyleCheckContext; ALineNumber, AColumn: Integer; const AMessage: string);
  public
    constructor Create; virtual;

    // Unique code of the rule, shown in the messages and used as the name of its settings node: CS1001
    class function GetCode: string; virtual; abstract;
    // Short description shown in the settings
    class function GetDescription: string; virtual; abstract;
    class function GetSeverity: TCodeStyleSeverity; virtual;

    // Checks the parsed source and adds the found issues to AContext
    procedure Check(AContext: TCodeStyleCheckContext); virtual; abstract;
    // Reads and writes the settings of the rule, ARuleSettings is the node of the rule
    procedure ReadSettings(ARuleSettings: IXMLNode); virtual;
    procedure WriteSettings(ARuleSettings: IXMLNode); virtual;

    property Enabled: Boolean read FEnabled write FEnabled;
  end;

  TCodeStyleRuleClass = class of TCodeStyleRule;

  // Objects of all registered rules, in the order of the registration
  TCodeStyleRuleSet = class(TObject)
  private
    class var FRuleClassList: TClassList;
  private
    FRules: TObjectList<TCodeStyleRule>;

    function GetCount: Integer;
    function GetRule(AIndex: Integer): TCodeStyleRule;
  public
    constructor Create;
    destructor Destroy; override;

    class procedure RegisterRule(ARuleClass: TCodeStyleRuleClass);

    // ARulesSettings holds one child node per rule, named by the rule code
    procedure ReadSettings(ARulesSettings: IXMLNode);
    procedure WriteSettings(ARulesSettings: IXMLNode);

    property Count: Integer read GetCount;
    property Rules[AIndex: Integer]: TCodeStyleRule read GetRule; default;
  end;

implementation

{ TCodeStyleCheckContext }

constructor TCodeStyleCheckContext.Create(const AFileName: string; AParser: TPasParser; AIssues: TCodeStyleIssueList);
begin
  inherited Create;

  FFileName := AFileName;
  FParser := AParser;
  FIssues := AIssues;
end;

procedure TCodeStyleCheckContext.AddIssue(const ACode: string; ASeverity: TCodeStyleSeverity; ALineNumber, AColumn: Integer;
    const AMessage: string);
var
  Issue: TCodeStyleIssue;
begin
  Issue.Code := ACode;
  Issue.Severity := ASeverity;
  Issue.LineNumber := ALineNumber;
  Issue.Column := AColumn;
  Issue.Message := AMessage;
  FIssues.Add(Issue);
end;

{ TCodeStyleRule }

constructor TCodeStyleRule.Create;
begin
  inherited Create;

  FEnabled := True;
end;

procedure TCodeStyleRule.AddIssue(AContext: TCodeStyleCheckContext; ALineNumber, AColumn: Integer; const AMessage: string);
begin
  AContext.AddIssue(GetCode, GetSeverity, ALineNumber, AColumn, AMessage);
end;

class function TCodeStyleRule.GetSeverity: TCodeStyleSeverity;
begin
  Result := cssWarning;
end;

procedure TCodeStyleRule.ReadSettings(ARuleSettings: IXMLNode);
var
  EnabledSetting: OleVariant;
begin
  EnabledSetting := ARuleSettings.Attributes[SETTINGS_ATTRIBUTE_ENABLED];
  if not VarIsNull(EnabledSetting) then
    FEnabled := EnabledSetting;
end;

procedure TCodeStyleRule.WriteSettings(ARuleSettings: IXMLNode);
begin
  ARuleSettings.Attributes[SETTINGS_ATTRIBUTE_ENABLED] := FEnabled;
end;

{ TCodeStyleRuleSet }

constructor TCodeStyleRuleSet.Create;
var
  RuleClass: TClass;
begin
  inherited Create;

  FRules := TObjectList<TCodeStyleRule>.Create(True);
  for RuleClass in FRuleClassList do
    FRules.Add(TCodeStyleRuleClass(RuleClass).Create);
end;

destructor TCodeStyleRuleSet.Destroy;
begin
  FreeAndNil(FRules);

  inherited Destroy;
end;

function TCodeStyleRuleSet.GetCount: Integer;
begin
  Result := FRules.Count;
end;

function TCodeStyleRuleSet.GetRule(AIndex: Integer): TCodeStyleRule;
begin
  Result := FRules[AIndex];
end;

class procedure TCodeStyleRuleSet.RegisterRule(ARuleClass: TCodeStyleRuleClass);
begin
  FRuleClassList.Add(ARuleClass);
end;

procedure TCodeStyleRuleSet.ReadSettings(ARulesSettings: IXMLNode);
var
  Rule: TCodeStyleRule;
begin
  for Rule in FRules do
    Rule.ReadSettings(ARulesSettings.ChildNodes[Rule.GetCode]);
end;

procedure TCodeStyleRuleSet.WriteSettings(ARulesSettings: IXMLNode);
var
  Rule: TCodeStyleRule;
begin
  for Rule in FRules do
    Rule.WriteSettings(ARulesSettings.ChildNodes[Rule.GetCode]);
end;

initialization
  TCodeStyleRuleSet.FRuleClassList := TClassList.Create;

finalization
  FreeAndNil(TCodeStyleRuleSet.FRuleClassList);

end.
