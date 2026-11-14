// Code style profile: the levels and the option values of all rules of the catalog (uCodeStyleProfileCatalog), read
// from and written to XML: the node of the feature settings or a profile file that can be shared. A new profile holds
// the default style. The check does not use the profile yet. Does not depend on the IDE.
unit uCodeStyleProfile;

interface

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections, Xml.XMLIntf, Xml.XMLDoc,
  uCodeStyleConsts, uCodeStyleProfileCatalog;

type
  ECodeStyleProfileError = class(Exception);

  // Value of one option of a profile rule. The value is kept as it is stored in XML.
  TCodeStyleProfileOption = class(TObject)
  private
    FInfo: TCodeStyleOptionInfo;
    // Identifier of the rule, for the error messages
    FRuleId: string;
    FValue: string;
    // Default value for the rule of the option: Info.DefaultValue or a value of CODE_STYLE_DEFAULTS, normalized
    FDefaultValue: string;
    // Values and captions of a cokChoice option
    FChoiceValues: TArray<string>;
    FChoiceCaptions: TArray<string>;

    procedure ParseChoices;
    // Returns True and the value in its stored form when AValue is valid for the option
    function TryNormalizeValue(const AValue: string; out ANormalizedValue: string): Boolean;
    function GetName: string;
    procedure SetValue(const Value: string);
    function GetAsBoolean: Boolean;
    procedure SetAsBoolean(Value: Boolean);
    function GetAsInteger: Integer;
    procedure SetAsInteger(Value: Integer);
    function GetItems: TArray<string>;
    procedure SetItems(const Value: TArray<string>);
    function GetChoiceCount: Integer;
    function GetChoiceValue(AIndex: Integer): string;
    function GetChoiceCaption(AIndex: Integer): string;
    function GetChoiceIndex: Integer;
    procedure SetChoiceIndex(Value: Integer);
    // Splits a cokQuantity value into its mode and count; False when the value is not valid
    function TryParseQuantity(const AValue: string; out AMode: TCodeStyleQuantityMode; out ACount: Integer): Boolean;
    function GetQuantityMode: TCodeStyleQuantityMode;
    function GetQuantityCount: Integer;
  public
    constructor Create(const ARuleId: string; const AInfo: TCodeStyleOptionInfo);

    // Changes the default value of the option for its rule (CODE_STYLE_DEFAULTS) and resets the value to it
    procedure SetDefaultValue(const AValue: string);
    function IsValidValue(const AValue: string): Boolean;
    function IsDefault: Boolean;
    procedure Reset;
    // Sets a cokQuantity value; ACount is ignored for cqmAny
    procedure SetQuantity(AMode: TCodeStyleQuantityMode; ACount: Integer);

    property Info: TCodeStyleOptionInfo read FInfo;
    property Name: string read GetName;
    // Value as it is stored; an invalid value raises ECodeStyleProfileError
    property Value: string read FValue write SetValue;
    property DefaultValue: string read FDefaultValue;
    property AsBoolean: Boolean read GetAsBoolean write SetAsBoolean;
    property AsInteger: Integer read GetAsInteger write SetAsInteger;
    // Items of a cokTextList value, without empty items
    property Items: TArray<string> read GetItems write SetItems;
    property ChoiceCount: Integer read GetChoiceCount;
    property ChoiceValues[AIndex: Integer]: string read GetChoiceValue;
    property ChoiceCaptions[AIndex: Integer]: string read GetChoiceCaption;
    // Index of the value of a cokChoice option
    property ChoiceIndex: Integer read GetChoiceIndex write SetChoiceIndex;
    // Mode and count of a cokQuantity value; the count is 0 for cqmAny
    property QuantityMode: TCodeStyleQuantityMode read GetQuantityMode;
    property QuantityCount: Integer read GetQuantityCount;
  end;

  // Level and options of one rule of the profile
  TCodeStyleProfileRule = class(TObject)
  private
    FInfo: TCodeStyleRuleInfo;
    // Index of the category of the rule in CODE_STYLE_CATEGORIES
    FCategoryIndex: Integer;
    FLevel: TCodeStyleLevel;
    FOptions: TObjectList<TCodeStyleProfileOption>;

    function GetId: string;
    function GetOptionCount: Integer;
    function GetOption(AIndex: Integer): TCodeStyleProfileOption;
  public
    constructor Create(const AInfo: TCodeStyleRuleInfo);
    destructor Destroy; override;

    // Adds an option of the catalog with its default value
    procedure AddOption(const AInfo: TCodeStyleOptionInfo);
    function FindOption(const AName: string): TCodeStyleProfileOption;
    // Like FindOption, but raises ECodeStyleProfileError when the rule has no such option
    function OptionByName(const AName: string): TCodeStyleProfileOption;
    // Copies the level and the values of a rule with the same Id
    procedure Assign(ASource: TCodeStyleProfileRule);
    // True when the level and all values are the default ones
    function IsDefault: Boolean;
    procedure Reset;
    // ARuleSettings is the node of the rule; nil or missing attributes give the default values, invalid values
    // are ignored
    procedure ReadSettings(ARuleSettings: IXMLNode);
    procedure WriteSettings(ARuleSettings: IXMLNode);

    property Info: TCodeStyleRuleInfo read FInfo;
    property Id: string read GetId;
    property CategoryIndex: Integer read FCategoryIndex;
    // Level of the rule; always cslOff for a group of general settings (Info.WithoutLevel)
    property Level: TCodeStyleLevel read FLevel write FLevel;
    property OptionCount: Integer read GetOptionCount;
    property Options[AIndex: Integer]: TCodeStyleProfileOption read GetOption;
  end;

  // All rules of the catalog, in the order of the catalog
  TCodeStyleProfile = class(TObject)
  private
    FRules: TObjectList<TCodeStyleProfileRule>;

    function GetName: string;
    function GetRuleCount: Integer;
    function GetRule(AIndex: Integer): TCodeStyleProfileRule;
  public
    // Creates the profile with the default values: the rules of the catalog with their own options and the options of
    // their templates, then the default values of CODE_STYLE_DEFAULTS
    constructor Create;
    destructor Destroy; override;

    procedure Assign(ASource: TCodeStyleProfile);
    function FindRule(const AId: string): TCodeStyleProfileRule;
    // Like FindRule, but raises ECodeStyleProfileError when the profile has no such rule
    function RuleById(const AId: string): TCodeStyleProfileRule;
    // Numbers of the rules that have a level (not the groups of general settings)
    function GetCheckRuleCount: Integer;
    function GetEnabledRuleCount: Integer;
    // Number of the rules and groups that differ from the default values
    function GetChangedRuleCount: Integer;
    // Returns to the default values
    procedure Reset;
    // Switches off all rules, the options keep their values
    procedure SwitchOffAll;

    // AProfileSettings holds one node per category with one node per rule; nil gives the default values
    procedure ReadSettings(AProfileSettings: IXMLNode);
    procedure WriteSettings(AProfileSettings: IXMLNode);
    // A profile file has the root node CodeStyleProfile with the nodes of ReadSettings
    procedure LoadFromFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string);

    property Name: string read GetName;
    property RuleCount: Integer read GetRuleCount;
    property Rules[AIndex: Integer]: TCodeStyleProfileRule read GetRule; default;
  end;

implementation

{ }

// Returns the child node, creating it when it does not exist, independently of doNodeAutoCreate
function GetOrAddChildNode(AParent: IXMLNode; const ANodeName: string): IXMLNode;
begin
  Result := AParent.ChildNodes.FindNode(ANodeName);
  if not Assigned(Result) then
    Result := AParent.AddChild(ANodeName);
end;

// Trims the items of a text list, drops the empty ones and the separators inside the items, joins the rest
function JoinListItems(const AItems: TArray<string>): string;
var
  Items: TArray<string>;
  Item: string;
  Count: Integer;
begin
  SetLength(Items, Length(AItems));
  Count := 0;
  for Item in AItems do
    if Trim(Item) <> '' then
    begin
      Items[Count] := Trim(Item).Replace(CODE_STYLE_LIST_SEPARATOR, '');
      Inc(Count);
    end;
  SetLength(Items, Count);
  Result := string.Join(CODE_STYLE_LIST_SEPARATOR, Items);
end;

function FindCategoryIndex(const ACategoryId: string): Integer;
var
  i: Integer;
begin
  for i := Low(CODE_STYLE_CATEGORIES) to High(CODE_STYLE_CATEGORIES) do
    if CODE_STYLE_CATEGORIES[i].Id = ACategoryId then
      Exit(i);
  Result := -1;
end;

function TryLevelFromName(const AName: string; out ALevel: TCodeStyleLevel): Boolean;
var
  Level: TCodeStyleLevel;
begin
  for Level := Low(TCodeStyleLevel) to High(TCodeStyleLevel) do
    if SameText(CODE_STYLE_LEVEL_NAMES[Level], AName) then
    begin
      ALevel := Level;
      Exit(True);
    end;
  Result := False;
end;

{ TCodeStyleProfileOption }

constructor TCodeStyleProfileOption.Create(const ARuleId: string; const AInfo: TCodeStyleOptionInfo);
begin
  inherited Create;

  FRuleId := ARuleId;
  FInfo := AInfo;
  if FInfo.Kind = cokChoice then
    ParseChoices;
  SetDefaultValue(FInfo.DefaultValue);
end;

procedure TCodeStyleProfileOption.ParseChoices;
var
  Choices: TArray<string>;
  SeparatorPos, i: Integer;
begin
  Choices := FInfo.Choices.Split([CODE_STYLE_CHOICE_SEPARATOR]);
  SetLength(FChoiceValues, Length(Choices));
  SetLength(FChoiceCaptions, Length(Choices));
  for i := 0 to High(Choices) do
  begin
    // 'Value=Caption'; a choice without a caption shows its value
    SeparatorPos := Pos(CODE_STYLE_CHOICE_VALUE_SEPARATOR, Choices[i]);
    if SeparatorPos > 0 then
    begin
      FChoiceValues[i] := Copy(Choices[i], 1, SeparatorPos - 1);
      FChoiceCaptions[i] := Copy(Choices[i], SeparatorPos + 1, MaxInt);
    end
    else
    begin
      FChoiceValues[i] := Choices[i];
      FChoiceCaptions[i] := Choices[i];
    end;
  end;
end;

function TCodeStyleProfileOption.TryNormalizeValue(const AValue: string; out ANormalizedValue: string): Boolean;
var
  IntegerValue, i: Integer;
  Mode: TCodeStyleQuantityMode;
begin
  Result := False;
  case FInfo.Kind of
    cokBoolean:
      if SameText(AValue, CODE_STYLE_TRUE) then
      begin
        ANormalizedValue := CODE_STYLE_TRUE;
        Result := True;
      end
      else if SameText(AValue, CODE_STYLE_FALSE) then
      begin
        ANormalizedValue := CODE_STYLE_FALSE;
        Result := True;
      end;
    cokInteger:
      if TryStrToInt(Trim(AValue), IntegerValue) and (IntegerValue >= FInfo.MinValue)
          and (IntegerValue <= FInfo.MaxValue)
      then
      begin
        ANormalizedValue := IntToStr(IntegerValue);
        Result := True;
      end;
    cokText:
    begin
      ANormalizedValue := AValue;
      Result := True;
    end;
    cokTextList:
    begin
      ANormalizedValue := JoinListItems(AValue.Split([CODE_STYLE_LIST_SEPARATOR]));
      Result := True;
    end;
    cokChoice:
      for i := 0 to High(FChoiceValues) do
        if SameText(AValue, FChoiceValues[i]) then
        begin
          ANormalizedValue := FChoiceValues[i];
          Exit(True);
        end;
    cokQuantity:
      if TryParseQuantity(AValue, Mode, IntegerValue) then
      begin
        if Mode = cqmAny then
          ANormalizedValue := CODE_STYLE_QUANTITY_NAMES[Mode]
        else
          ANormalizedValue := CODE_STYLE_QUANTITY_NAMES[Mode] + CODE_STYLE_QUANTITY_SEPARATOR + IntToStr(IntegerValue);
        Result := True;
      end;
  end;
end;

function TCodeStyleProfileOption.GetName: string;
begin
  Result := FInfo.Name;
end;

procedure TCodeStyleProfileOption.SetValue(const Value: string);
var
  NormalizedValue: string;
begin
  if not TryNormalizeValue(Value, NormalizedValue) then
    raise ECodeStyleProfileError.CreateFmt(EMESSAGE_PROFILE_INVALID_VALUE, [Value, FInfo.Name, FRuleId]);
  FValue := NormalizedValue;
end;

function TCodeStyleProfileOption.GetAsBoolean: Boolean;
begin
  Result := FValue = CODE_STYLE_TRUE;
end;

procedure TCodeStyleProfileOption.SetAsBoolean(Value: Boolean);
begin
  if Value then
    SetValue(CODE_STYLE_TRUE)
  else
    SetValue(CODE_STYLE_FALSE);
end;

function TCodeStyleProfileOption.GetAsInteger: Integer;
begin
  Result := StrToIntDef(FValue, FInfo.MinValue);
end;

procedure TCodeStyleProfileOption.SetAsInteger(Value: Integer);
begin
  SetValue(IntToStr(Value));
end;

function TCodeStyleProfileOption.GetItems: TArray<string>;
begin
  Result := FValue.Split([CODE_STYLE_LIST_SEPARATOR], TStringSplitOptions.ExcludeEmpty);
end;

procedure TCodeStyleProfileOption.SetItems(const Value: TArray<string>);
begin
  // The separator cannot be a part of an item
  SetValue(JoinListItems(Value));
end;

function TCodeStyleProfileOption.GetChoiceCount: Integer;
begin
  Result := Length(FChoiceValues);
end;

function TCodeStyleProfileOption.GetChoiceValue(AIndex: Integer): string;
begin
  Result := FChoiceValues[AIndex];
end;

function TCodeStyleProfileOption.GetChoiceCaption(AIndex: Integer): string;
begin
  Result := FChoiceCaptions[AIndex];
end;

function TCodeStyleProfileOption.GetChoiceIndex: Integer;
var
  i: Integer;
begin
  for i := 0 to High(FChoiceValues) do
    if FChoiceValues[i] = FValue then
      Exit(i);
  Result := -1;
end;

procedure TCodeStyleProfileOption.SetChoiceIndex(Value: Integer);
begin
  SetValue(FChoiceValues[Value]);
end;

function TCodeStyleProfileOption.TryParseQuantity(const AValue: string; out AMode: TCodeStyleQuantityMode;
    out ACount: Integer): Boolean;
var
  Mode: TCodeStyleQuantityMode;
  ModeName, CountText: string;
  SeparatorPos: Integer;
begin
  AMode := cqmAny;
  ACount := 0;
  SeparatorPos := Pos(CODE_STYLE_QUANTITY_SEPARATOR, AValue);
  if SeparatorPos > 0 then
  begin
    ModeName := Trim(Copy(AValue, 1, SeparatorPos - 1));
    CountText := Trim(Copy(AValue, SeparatorPos + 1, MaxInt));
  end
  else
  begin
    ModeName := Trim(AValue);
    CountText := '';
  end;

  for Mode := Low(TCodeStyleQuantityMode) to High(TCodeStyleQuantityMode) do
    if SameText(ModeName, CODE_STYLE_QUANTITY_NAMES[Mode]) then
    begin
      AMode := Mode;
      // Any has no count, the other modes need one in the range of the option
      if Mode = cqmAny then
        Exit(CountText = '');
      Exit(TryStrToInt(CountText, ACount) and (ACount >= FInfo.MinValue) and (ACount <= FInfo.MaxValue));
    end;
  Result := False;
end;

function TCodeStyleProfileOption.GetQuantityMode: TCodeStyleQuantityMode;
var
  Count: Integer;
begin
  if not TryParseQuantity(FValue, Result, Count) then
    Result := cqmAny;
end;

function TCodeStyleProfileOption.GetQuantityCount: Integer;
var
  Mode: TCodeStyleQuantityMode;
begin
  if not TryParseQuantity(FValue, Mode, Result) then
    Result := 0;
end;

procedure TCodeStyleProfileOption.SetDefaultValue(const AValue: string);
var
  NormalizedValue: string;
begin
  if not TryNormalizeValue(AValue, NormalizedValue) then
    raise ECodeStyleProfileError.CreateFmt(EMESSAGE_PROFILE_INVALID_VALUE, [AValue, FInfo.Name, FRuleId]);
  FDefaultValue := NormalizedValue;
  FValue := FDefaultValue;
end;

function TCodeStyleProfileOption.IsValidValue(const AValue: string): Boolean;
var
  NormalizedValue: string;
begin
  Result := TryNormalizeValue(AValue, NormalizedValue);
end;

function TCodeStyleProfileOption.IsDefault: Boolean;
begin
  Result := FValue = FDefaultValue;
end;

procedure TCodeStyleProfileOption.Reset;
begin
  FValue := FDefaultValue;
end;

procedure TCodeStyleProfileOption.SetQuantity(AMode: TCodeStyleQuantityMode; ACount: Integer);
begin
  if AMode = cqmAny then
    SetValue(CODE_STYLE_QUANTITY_NAMES[AMode])
  else
    SetValue(CODE_STYLE_QUANTITY_NAMES[AMode] + CODE_STYLE_QUANTITY_SEPARATOR + IntToStr(ACount));
end;

{ TCodeStyleProfileRule }

constructor TCodeStyleProfileRule.Create(const AInfo: TCodeStyleRuleInfo);
begin
  inherited Create;

  FInfo := AInfo;
  FCategoryIndex := FindCategoryIndex(FInfo.Category);
  if FCategoryIndex < 0 then
    raise ECodeStyleProfileError.CreateFmt(EMESSAGE_PROFILE_UNKNOWN_CATEGORY, [FInfo.Id, FInfo.Category]);
  FOptions := TObjectList<TCodeStyleProfileOption>.Create(True);
  FLevel := FInfo.Level;
end;

destructor TCodeStyleProfileRule.Destroy;
begin
  FreeAndNil(FOptions);

  inherited Destroy;
end;

function TCodeStyleProfileRule.GetId: string;
begin
  Result := FInfo.Id;
end;

function TCodeStyleProfileRule.GetOptionCount: Integer;
begin
  Result := FOptions.Count;
end;

function TCodeStyleProfileRule.GetOption(AIndex: Integer): TCodeStyleProfileOption;
begin
  Result := FOptions[AIndex];
end;

procedure TCodeStyleProfileRule.AddOption(const AInfo: TCodeStyleOptionInfo);
begin
  FOptions.Add(TCodeStyleProfileOption.Create(FInfo.Id, AInfo));
end;

function TCodeStyleProfileRule.FindOption(const AName: string): TCodeStyleProfileOption;
var
  Option: TCodeStyleProfileOption;
begin
  for Option in FOptions do
    if SameText(Option.Name, AName) then
      Exit(Option);
  Result := nil;
end;

function TCodeStyleProfileRule.OptionByName(const AName: string): TCodeStyleProfileOption;
begin
  Result := FindOption(AName);
  if not Assigned(Result) then
    raise ECodeStyleProfileError.CreateFmt(EMESSAGE_PROFILE_UNKNOWN_OPTION, [FInfo.Id, AName]);
end;

procedure TCodeStyleProfileRule.Assign(ASource: TCodeStyleProfileRule);
var
  i: Integer;
begin
  // Both rules are created from the same catalog entry, so their options go in the same order
  FLevel := ASource.Level;
  for i := 0 to FOptions.Count - 1 do
    FOptions[i].Value := ASource.Options[i].Value;
end;

function TCodeStyleProfileRule.IsDefault: Boolean;
var
  Option: TCodeStyleProfileOption;
begin
  if FLevel <> FInfo.Level then
    Exit(False);
  for Option in FOptions do
    if not Option.IsDefault then
      Exit(False);
  Result := True;
end;

procedure TCodeStyleProfileRule.Reset;
var
  Option: TCodeStyleProfileOption;
begin
  FLevel := FInfo.Level;
  for Option in FOptions do
    Option.Reset;
end;

procedure TCodeStyleProfileRule.ReadSettings(ARuleSettings: IXMLNode);
var
  Option: TCodeStyleProfileOption;
  Level: TCodeStyleLevel;
  SettingValue: string;
begin
  Reset;
  if not Assigned(ARuleSettings) then
    Exit;

  if (not FInfo.WithoutLevel) and ARuleSettings.HasAttribute(PROFILE_ATTRIBUTE_LEVEL)
      and TryLevelFromName(VarToStr(ARuleSettings.Attributes[PROFILE_ATTRIBUTE_LEVEL]), Level)
  then
    FLevel := Level;

  for Option in FOptions do
    if ARuleSettings.HasAttribute(Option.Name) then
    begin
      // A value that is not valid any more (a changed catalog, a file edited by hand) keeps the default
      SettingValue := VarToStr(ARuleSettings.Attributes[Option.Name]);
      if Option.IsValidValue(SettingValue) then
        Option.Value := SettingValue;
    end;
end;

procedure TCodeStyleProfileRule.WriteSettings(ARuleSettings: IXMLNode);
var
  Option: TCodeStyleProfileOption;
begin
  if not FInfo.WithoutLevel then
    ARuleSettings.Attributes[PROFILE_ATTRIBUTE_LEVEL] := CODE_STYLE_LEVEL_NAMES[FLevel];
  for Option in FOptions do
    ARuleSettings.Attributes[Option.Name] := Option.Value;
end;

{ TCodeStyleProfile }

constructor TCodeStyleProfile.Create;
var
  RuleInfo: TCodeStyleRuleInfo;
  OptionInfo: TCodeStyleOptionInfo;
  DefaultInfo: TCodeStyleDefaultInfo;
  Rule: TCodeStyleProfileRule;
  TemplateName: string;
begin
  inherited Create;

  FRules := TObjectList<TCodeStyleProfileRule>.Create(True);
  for RuleInfo in CODE_STYLE_RULES do
    FRules.Add(TCodeStyleProfileRule.Create(RuleInfo));

  // The template options go first in the catalog, so they come before the own options of a rule
  for OptionInfo in CODE_STYLE_OPTIONS do
    if OptionInfo.Rule.StartsWith(CODE_STYLE_TEMPLATE_PREFIX) then
    begin
      TemplateName := Copy(OptionInfo.Rule, Length(CODE_STYLE_TEMPLATE_PREFIX) + 1, MaxInt);
      for Rule in FRules do
        if Rule.Info.Template = TemplateName then
          Rule.AddOption(OptionInfo);
    end
    else
      RuleById(OptionInfo.Rule).AddOption(OptionInfo);

  for DefaultInfo in CODE_STYLE_DEFAULTS do
    RuleById(DefaultInfo.Rule).OptionByName(DefaultInfo.Option).SetDefaultValue(DefaultInfo.Value);
end;

destructor TCodeStyleProfile.Destroy;
begin
  FreeAndNil(FRules);

  inherited Destroy;
end;

function TCodeStyleProfile.GetName: string;
begin
  Result := RuleById(PROFILE_RULE_PROFILE).OptionByName(PROFILE_OPTION_PROFILE_NAME).Value;
end;

function TCodeStyleProfile.GetRuleCount: Integer;
begin
  Result := FRules.Count;
end;

function TCodeStyleProfile.GetRule(AIndex: Integer): TCodeStyleProfileRule;
begin
  Result := FRules[AIndex];
end;

procedure TCodeStyleProfile.Assign(ASource: TCodeStyleProfile);
var
  i: Integer;
begin
  // Both profiles are created from the same catalog, so their rules go in the same order
  for i := 0 to FRules.Count - 1 do
    FRules[i].Assign(ASource.Rules[i]);
end;

function TCodeStyleProfile.FindRule(const AId: string): TCodeStyleProfileRule;
var
  Rule: TCodeStyleProfileRule;
begin
  for Rule in FRules do
    if SameText(Rule.Id, AId) then
      Exit(Rule);
  Result := nil;
end;

function TCodeStyleProfile.RuleById(const AId: string): TCodeStyleProfileRule;
begin
  Result := FindRule(AId);
  if not Assigned(Result) then
    raise ECodeStyleProfileError.CreateFmt(EMESSAGE_PROFILE_UNKNOWN_RULE, [AId]);
end;

function TCodeStyleProfile.GetCheckRuleCount: Integer;
var
  Rule: TCodeStyleProfileRule;
begin
  Result := 0;
  for Rule in FRules do
    if not Rule.Info.WithoutLevel then
      Inc(Result);
end;

function TCodeStyleProfile.GetEnabledRuleCount: Integer;
var
  Rule: TCodeStyleProfileRule;
begin
  Result := 0;
  for Rule in FRules do
    if (not Rule.Info.WithoutLevel) and (Rule.Level <> cslOff) then
      Inc(Result);
end;

function TCodeStyleProfile.GetChangedRuleCount: Integer;
var
  Rule: TCodeStyleProfileRule;
begin
  Result := 0;
  for Rule in FRules do
    if not Rule.IsDefault then
      Inc(Result);
end;

procedure TCodeStyleProfile.Reset;
var
  Rule: TCodeStyleProfileRule;
begin
  for Rule in FRules do
    Rule.Reset;
end;

procedure TCodeStyleProfile.SwitchOffAll;
var
  Rule: TCodeStyleProfileRule;
begin
  for Rule in FRules do
    Rule.Level := cslOff;
end;

procedure TCodeStyleProfile.ReadSettings(AProfileSettings: IXMLNode);
var
  Rule: TCodeStyleProfileRule;
  CategorySettings, RuleSettings: IXMLNode;
begin
  for Rule in FRules do
  begin
    RuleSettings := nil;
    if Assigned(AProfileSettings) then
    begin
      CategorySettings := AProfileSettings.ChildNodes.FindNode(Rule.Info.Category);
      if Assigned(CategorySettings) then
        RuleSettings := CategorySettings.ChildNodes.FindNode(Rule.Id);
    end;
    Rule.ReadSettings(RuleSettings);
  end;
end;

procedure TCodeStyleProfile.WriteSettings(AProfileSettings: IXMLNode);
var
  Rule: TCodeStyleProfileRule;
begin
  for Rule in FRules do
    Rule.WriteSettings(GetOrAddChildNode(GetOrAddChildNode(AProfileSettings, Rule.Info.Category), Rule.Id));
end;

procedure TCodeStyleProfile.LoadFromFile(const AFileName: string);
var
  Document: IXMLDocument;
  Root: IXMLNode;
  RootName: string;
begin
  Document := LoadXMLDocument(AFileName);
  Root := Document.DocumentElement;
  if Assigned(Root) then
    RootName := Root.NodeName
  else
    RootName := '';
  if RootName <> PROFILE_FILE_ROOT_NODE then
    raise ECodeStyleProfileError.CreateFmt(EMESSAGE_PROFILE_INVALID_FILE, [AFileName, RootName, PROFILE_FILE_ROOT_NODE]);

  ReadSettings(Root);
end;

procedure TCodeStyleProfile.SaveToFile(const AFileName: string);
var
  Document: IXMLDocument;
  Root: IXMLNode;
begin
  Document := NewXMLDocument;
  Document.Options := Document.Options + [doNodeAutoIndent];
  Document.Encoding := PROFILE_FILE_ENCODING;
  Root := Document.AddChild(PROFILE_FILE_ROOT_NODE);
  Root.Attributes[PROFILE_ATTRIBUTE_VERSION] := PROFILE_FILE_VERSION;
  WriteSettings(Root);
  Document.SaveToFile(AFileName);
end;

end.
