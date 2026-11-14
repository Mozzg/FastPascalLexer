unit TestuCodeStyleProfile;

{
  Tests for the code style profile (uCodeStyleProfile) and the consistency of its catalog
  (uCodeStyleProfileCatalog): identifiers, templates, default values, values of the options and reading and writing
  XML settings and profile files.
}

interface

uses
  System.SysUtils, System.Variants, System.IOUtils, Winapi.ActiveX, Xml.XMLIntf, Xml.XMLDoc, TestFramework,
  uCodeStyleConsts, uCodeStyleProfileCatalog, uCodeStyleProfile;

type
  TestTCodeStyleProfile = class(TTestCase)
  private
    FProfile: TCodeStyleProfile;

    // True for a name that can be an XML node or attribute name: a Latin letter, then Latin letters and digits
    function IsXmlName(const AName: string): Boolean;
    function GetOption(const ARuleId, AOptionName: string): TCodeStyleProfileOption;
    // Changes rules of every kind of option, so a round trip has something to keep
    procedure ChangeProfile(AProfile: TCodeStyleProfile);
    procedure CheckProfilesEqual(AExpected, AActual: TCodeStyleProfile; const AMessage: string);
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestCatalogIdentifiers;
    // Every template is used and every rule with a template has its options
    procedure TestCatalogTemplates;
    procedure TestCatalogDefaults;
    // The default values of a new profile
    procedure TestDefaultStyle;
    procedure TestOptionValues;
    procedure TestQuantityValues;
    // A per-rule default value of a template option is the default of that rule only
    procedure TestRuleDefaults;
    // Rules whose options differ from their kind: only the options that can make sense, both directions of a style
    procedure TestRuleSpecificOptions;
    procedure TestAssignResetSwitchOff;
    procedure TestXmlRoundTrip;
    // Missing and invalid values in XML give the default values
    procedure TestXmlInvalidValues;
    procedure TestProfileFile;
  end;

implementation

const
  TEST_PROFILE_FILE_NAME = 'CodeStyleProfileTest.xml';

{ TestTCodeStyleProfile }

function TestTCodeStyleProfile.IsXmlName(const AName: string): Boolean;
var
  i: Integer;
begin
  Result := (AName <> '') and CharInSet(AName[1], ['A'..'Z', 'a'..'z']);
  for i := 2 to Length(AName) do
    Result := Result and CharInSet(AName[i], ['A'..'Z', 'a'..'z', '0'..'9']);
end;

function TestTCodeStyleProfile.GetOption(const ARuleId, AOptionName: string): TCodeStyleProfileOption;
begin
  Result := FProfile.RuleById(ARuleId).OptionByName(AOptionName);
end;

procedure TestTCodeStyleProfile.ChangeProfile(AProfile: TCodeStyleProfile);
begin
  AProfile.RuleById('Profile').OptionByName('ProfileName').Value := 'My style';
  AProfile.RuleById('LineLength').Level := cslError;
  AProfile.RuleById('LineLength').OptionByName('MaxLength').AsInteger := 100;
  AProfile.RuleById('TabsInsideLines').Level := cslHint;
  AProfile.RuleById('TabsInsideLines').OptionByName('AllowInComments').AsBoolean := False;
  AProfile.RuleById('ReservedWordCase').OptionByName('Case').Value := 'Upper';
  AProfile.RuleById('NamesParameters').OptionByName('AllowedNames').Items := TArray<string>.Create('Value', 'Sender',
      'Index');
  AProfile.RuleById('SpacesAssignment').OptionByName('SpacesAfter').SetQuantity(cqmExactly, 2);
end;

procedure TestTCodeStyleProfile.CheckProfilesEqual(AExpected, AActual: TCodeStyleProfile; const AMessage: string);
var
  ExpectedRule, ActualRule: TCodeStyleProfileRule;
  i, j: Integer;
begin
  CheckEquals(AExpected.RuleCount, AActual.RuleCount, AMessage + ': rule count');
  for i := 0 to AExpected.RuleCount - 1 do
  begin
    ExpectedRule := AExpected[i];
    ActualRule := AActual[i];
    CheckEquals(ExpectedRule.Id, ActualRule.Id, AMessage + ': rule order');
    CheckEquals(Ord(ExpectedRule.Level), Ord(ActualRule.Level), AMessage + ': level of ' + ExpectedRule.Id);
    for j := 0 to ExpectedRule.OptionCount - 1 do
      CheckEquals(ExpectedRule.Options[j].Value, ActualRule.Options[j].Value,
          AMessage + ': ' + ExpectedRule.Id + '.' + ExpectedRule.Options[j].Name);
  end;
end;

procedure TestTCodeStyleProfile.SetUp;
begin
  // MSXML, the DOM of TXMLDocument, needs COM
  CoInitialize(nil);
  FProfile := TCodeStyleProfile.Create;
end;

procedure TestTCodeStyleProfile.TearDown;
begin
  FreeAndNil(FProfile);
  CoUninitialize;
end;

procedure TestTCodeStyleProfile.TestCatalogIdentifiers;
var
  i, j: Integer;
  RuleCount: Integer;
  Rule: TCodeStyleProfileRule;
begin
  for i := Low(CODE_STYLE_CATEGORIES) to High(CODE_STYLE_CATEGORIES) do
  begin
    CheckTrue(IsXmlName(CODE_STYLE_CATEGORIES[i].Id), 'Category id ' + CODE_STYLE_CATEGORIES[i].Id);
    CheckNotEquals('', CODE_STYLE_CATEGORIES[i].Caption, 'Caption of category ' + CODE_STYLE_CATEGORIES[i].Id);
    for j := i + 1 to High(CODE_STYLE_CATEGORIES) do
      CheckFalse(SameText(CODE_STYLE_CATEGORIES[i].Id, CODE_STYLE_CATEGORIES[j].Id),
          'Duplicate category ' + CODE_STYLE_CATEGORIES[i].Id);

    RuleCount := 0;
    for j := 0 to FProfile.RuleCount - 1 do
      if FProfile[j].CategoryIndex = i then
        Inc(RuleCount);
    CheckTrue(RuleCount > 0, 'Category without rules ' + CODE_STYLE_CATEGORIES[i].Id);
  end;

  CheckEquals(Length(CODE_STYLE_RULES), FProfile.RuleCount, 'Rules of the profile');
  for i := 0 to FProfile.RuleCount - 1 do
  begin
    Rule := FProfile[i];
    CheckTrue(IsXmlName(Rule.Id), 'Rule id ' + Rule.Id);
    CheckNotEquals('', Rule.Info.Caption, 'Caption of rule ' + Rule.Id);
    CheckNotEquals('', Rule.Info.Description, 'Description of rule ' + Rule.Id);
    for j := i + 1 to FProfile.RuleCount - 1 do
      CheckFalse(SameText(Rule.Id, FProfile[j].Id), 'Duplicate rule ' + Rule.Id);
    // The rules of a category follow each other, the dialog shows them in the order of the catalog
    if i > 0 then
      CheckTrue(Rule.CategoryIndex >= FProfile[i - 1].CategoryIndex, 'Category order at rule ' + Rule.Id);
    if Rule.Info.WithoutLevel then
      CheckEquals(Ord(cslOff), Ord(Rule.Info.Level), 'Level of the general settings ' + Rule.Id);

    for j := 0 to Rule.OptionCount - 1 do
    begin
      CheckTrue(IsXmlName(Rule.Options[j].Name), 'Option name ' + Rule.Id + '.' + Rule.Options[j].Name);
      CheckFalse(SameText(Rule.Options[j].Name, PROFILE_ATTRIBUTE_LEVEL), 'Option named Level in rule ' + Rule.Id);
      CheckNotEquals('', Rule.Options[j].Info.Caption, 'Caption of option ' + Rule.Id + '.' + Rule.Options[j].Name);
      CheckSame(Rule.Options[j], Rule.FindOption(Rule.Options[j].Name),
          'Duplicate option ' + Rule.Id + '.' + Rule.Options[j].Name);
    end;
  end;
end;

procedure TestTCodeStyleProfile.TestCatalogTemplates;
var
  OptionInfo: TCodeStyleOptionInfo;
  Rule: TCodeStyleProfileRule;
  TemplateName: string;
  UseCount, i: Integer;
begin
  for OptionInfo in CODE_STYLE_OPTIONS do
    if OptionInfo.Rule.StartsWith(CODE_STYLE_TEMPLATE_PREFIX) then
    begin
      TemplateName := Copy(OptionInfo.Rule, 2, MaxInt);
      UseCount := 0;
      for i := 0 to FProfile.RuleCount - 1 do
        if FProfile[i].Info.Template = TemplateName then
        begin
          Inc(UseCount);
          CheckNotNull(FProfile[i].FindOption(OptionInfo.Name), 'Template option ' + OptionInfo.Name + ' of '
              + FProfile[i].Id);
        end;
      CheckTrue(UseCount > 0, 'Unused template option ' + OptionInfo.Rule + '.' + OptionInfo.Name);
    end;

  for i := 0 to FProfile.RuleCount - 1 do
  begin
    Rule := FProfile[i];
    if Rule.Info.Template <> '' then
    begin
      CheckTrue(Rule.OptionCount > 0, 'Rule with an unknown template ' + Rule.Id);
      // The template options come first
      CheckEquals(CODE_STYLE_TEMPLATE_PREFIX + Rule.Info.Template, Rule.Options[0].Info.Rule,
          'First option of ' + Rule.Id);
    end;
  end;
  CheckEquals('Case', FProfile.RuleById('NamesParameters').Options[0].Name, 'Options of the template first');
  CheckNotNull(FProfile.RuleById('NamesParameters').FindOption('SkipOverrides'), 'Own option after the template');
end;

procedure TestTCodeStyleProfile.TestCatalogDefaults;
var
  OptionCount, i, j, k: Integer;
  Rule: TCodeStyleProfileRule;
  Option: TCodeStyleProfileOption;
  OptionName: string;
  DefaultInfo: TCodeStyleDefaultInfo;
begin
  OptionCount := 0;
  for i := 0 to FProfile.RuleCount - 1 do
  begin
    Rule := FProfile[i];
    for j := 0 to Rule.OptionCount - 1 do
    begin
      Option := Rule.Options[j];
      OptionName := Rule.Id + '.' + Option.Name;
      CheckTrue(Option.IsValidValue(Option.Info.DefaultValue), 'Default value of ' + OptionName);
      CheckTrue(Option.IsValidValue(Option.DefaultValue), 'Default value for the rule of ' + OptionName);
      CheckTrue(Option.IsDefault, 'New option ' + OptionName);
      case Option.Info.Kind of
        cokInteger, cokQuantity:
          CheckTrue(Option.Info.MinValue <= Option.Info.MaxValue, 'Range of ' + OptionName);
        cokChoice:
        begin
          CheckTrue(Option.ChoiceCount >= 2, 'Choices of ' + OptionName);
          for k := 0 to Option.ChoiceCount - 1 do
          begin
            CheckTrue(IsXmlName(Option.ChoiceValues[k]), 'Choice value of ' + OptionName);
            CheckNotEquals('', Option.ChoiceCaptions[k], 'Choice caption of ' + OptionName);
          end;
        end;
      end;
      if Option.Info.Kind <> cokChoice then
        CheckEquals('', Option.Info.Choices, 'Choices of the option that is not a choice ' + OptionName);
      if not Option.Info.Rule.StartsWith(CODE_STYLE_TEMPLATE_PREFIX) then
        Inc(OptionCount);
    end;
  end;

  for i := Low(CODE_STYLE_OPTIONS) to High(CODE_STYLE_OPTIONS) do
    if CODE_STYLE_OPTIONS[i].Rule.StartsWith(CODE_STYLE_TEMPLATE_PREFIX) then
      Inc(OptionCount);
  // Every own option belongs to its rule; with the template options counted once, the numbers match
  CheckTrue(OptionCount >= Length(CODE_STYLE_OPTIONS), 'Every option of the catalog belongs to a rule');

  for DefaultInfo in CODE_STYLE_DEFAULTS do
  begin
    Option := GetOption(DefaultInfo.Rule, DefaultInfo.Option);
    CheckEquals(DefaultInfo.Value, Option.DefaultValue, 'Default of ' + DefaultInfo.Rule + '.' + DefaultInfo.Option);
    CheckNotEquals(Option.Info.DefaultValue, DefaultInfo.Value,
        'A per-rule default that repeats the option default: ' + DefaultInfo.Rule + '.' + DefaultInfo.Option);
  end;
end;

procedure TestTCodeStyleProfile.TestDefaultStyle;
begin
  CheckEquals('Default', FProfile.Name, 'Profile name');
  CheckEquals(0, FProfile.GetChangedRuleCount, 'Changed rules of a new profile');
  CheckTrue(FProfile.GetEnabledRuleCount > 20, 'Common rules are switched on');
  CheckTrue(FProfile.GetEnabledRuleCount < FProfile.GetCheckRuleCount, 'Opinionated rules are switched off');

  CheckEquals(Ord(cslHint), Ord(FProfile.RuleById('SpacesAssignment').Level), 'Spaces around :=');
  CheckEquals('Exactly:1', GetOption('SpacesAssignment', 'SpacesBefore').Value, 'Spaces before :=');
  CheckEquals('Exactly:0', GetOption('SpacesComma', 'SpacesBefore').Value, 'Spaces before a comma');
  CheckEquals('Exactly:1', GetOption('SpacesComma', 'SpacesAfter').Value, 'Spaces after a comma');
  CheckEquals('Exactly:0', GetOption('SpacesCallParentheses', 'SpacesBeforeOpening').Value, 'Call parenthesis');
  CheckEquals('Any', GetOption('SpacesParentheses', 'SpacesBeforeOpening').Value, 'Grouping parenthesis');
  CheckEquals(2, GetOption('BlockIndent', 'Size').AsInteger, 'Block indent');
  CheckEquals(1, GetOption('IndentStatements', 'Indent').AsInteger, 'Statements in begin-end');
  CheckEquals(0, GetOption('IndentRoutineBody', 'Indent').AsInteger, 'Body of a routine');
  CheckEquals('Lower', GetOption('ReservedWordCase', 'Case').Value, 'Reserved words');
  CheckEquals('T', GetOption('NamesClasses', 'Prefixes').Value, 'Class prefix');
  CheckEquals('I', GetOption('NamesInterfaces', 'Prefixes').Value, 'Interface prefix');
  CheckEquals('F', GetOption('NamesPrivateFields', 'Prefixes').Value, 'Field prefix');
  CheckEquals('', GetOption('NamesLocalVariables', 'Prefixes').Value, 'Local variables have no prefix');
  CheckEquals('Value;Sender', GetOption('NamesParameters', 'AllowedNames').Value, 'Parameter names without prefix');
  CheckEquals(Ord(cslOff), Ord(FProfile.RuleById('NamesParameters').Level), 'Parameter prefix is opinionated');
  CheckEquals(Ord(cslOff), Ord(FProfile.RuleById('WithStatement').Level), 'with statement is opinionated');
end;

procedure TestTCodeStyleProfile.TestOptionValues;
var
  Option: TCodeStyleProfileOption;
  Items: TArray<string>;
begin
  Option := GetOption('TabsInsideLines', 'AllowInComments');
  Option.Value := 'false';
  CheckEquals(CODE_STYLE_FALSE, Option.Value, 'Boolean is normalized');
  CheckFalse(Option.AsBoolean, 'AsBoolean');
  CheckFalse(Option.IsDefault, 'Changed boolean');
  CheckFalse(Option.IsValidValue('Yes'), 'Invalid boolean');

  Option := GetOption('LineLength', 'MaxLength');
  CheckTrue(Option.IsValidValue(' 20 '), 'Minimum integer');
  CheckFalse(Option.IsValidValue('19'), 'Integer below the range');
  CheckFalse(Option.IsValidValue('1001'), 'Integer above the range');
  CheckFalse(Option.IsValidValue('12a'), 'Not an integer');
  Option.AsInteger := 100;
  CheckEquals('100', Option.Value, 'AsInteger');
  try
    Option.Value := '5';
    Fail('Invalid value is stored');
  except
    on E: ECodeStyleProfileError do
      CheckEquals('100', Option.Value, 'Value after an invalid value');
  end;

  Option := GetOption('NamesParameters', 'AllowedNames');
  Option.Value := ' Value ; ;Sender;';
  CheckEquals('Value;Sender', Option.Value, 'Text list is normalized');
  CheckTrue(Option.IsDefault, 'Normalized text list is the default');
  Option.Items := TArray<string>.Create(' Index ', '', 'Count;Size');
  CheckEquals('Index;CountSize', Option.Value, 'Items drop empty items and separators');
  Items := Option.Items;
  CheckEquals(2, Length(Items), 'Items');
  CheckEquals('CountSize', Items[1], 'Second item');

  Option := GetOption('ReservedWordCase', 'Case');
  Option.Value := 'upper';
  CheckEquals('Upper', Option.Value, 'Choice is normalized');
  CheckEquals(1, Option.ChoiceIndex, 'ChoiceIndex');
  Option.ChoiceIndex := 2;
  CheckEquals('Capitalized', Option.Value, 'Set ChoiceIndex');
  CheckFalse(Option.IsValidValue('Mixed'), 'Unknown choice');

  Option := GetOption('Profile', 'ProfileName');
  Option.Value := '';
  CheckEquals('', FProfile.Name, 'Empty text is valid');
end;

procedure TestTCodeStyleProfile.TestQuantityValues;
var
  Option: TCodeStyleProfileOption;
begin
  Option := GetOption('SpacesAssignment', 'SpacesAfter');
  CheckEquals(Ord(cqmExactly), Ord(Option.QuantityMode), 'Default mode');
  CheckEquals(1, Option.QuantityCount, 'Default count');

  Option.Value := ' atleast : 2 ';
  CheckEquals('AtLeast:2', Option.Value, 'Quantity is normalized');
  CheckEquals(Ord(cqmAtLeast), Ord(Option.QuantityMode), 'Mode');
  CheckEquals(2, Option.QuantityCount, 'Count');
  Option.Value := 'any';
  CheckEquals('Any', Option.Value, 'Any');
  CheckEquals(0, Option.QuantityCount, 'Count of Any');
  Option.SetQuantity(cqmAtMost, 0);
  CheckEquals('AtMost:0', Option.Value, 'SetQuantity');
  Option.SetQuantity(cqmAny, 5);
  CheckEquals('Any', Option.Value, 'SetQuantity ignores the count of Any');

  CheckTrue(Option.IsValidValue('Exactly:10'), 'Maximum count');
  CheckFalse(Option.IsValidValue('Exactly:11'), 'Count above the range');
  CheckFalse(Option.IsValidValue('Exactly:-1'), 'Count below the range');
  CheckFalse(Option.IsValidValue('Exactly'), 'Mode without a count');
  CheckFalse(Option.IsValidValue('Any:1'), 'Any with a count');
  CheckFalse(Option.IsValidValue('Most:1'), 'Unknown mode');
  CheckFalse(Option.IsValidValue('Exactly:one'), 'Count that is not a number');
end;

procedure TestTCodeStyleProfile.TestRuleDefaults;
var
  CommaOption, PlusOption: TCodeStyleProfileOption;
begin
  // Both options come from the template Spaces, only the comma has a default of its own
  CommaOption := GetOption('SpacesComma', 'SpacesBefore');
  PlusOption := GetOption('SpacesPlus', 'SpacesBefore');
  CheckEquals(CommaOption.Info.Rule, PlusOption.Info.Rule, 'One template option');
  CheckEquals('Exactly:0', CommaOption.DefaultValue, 'Default of the comma');
  CheckEquals('Exactly:1', PlusOption.DefaultValue, 'Default of the plus');

  CommaOption.SetQuantity(cqmExactly, 1);
  CheckFalse(CommaOption.IsDefault, 'The template default is not the default of the comma');
  CheckFalse(FProfile.RuleById('SpacesComma').IsDefault, 'Changed rule');
  FProfile.RuleById('SpacesComma').Reset;
  CheckEquals('Exactly:0', CommaOption.Value, 'Reset returns to the default of the comma');
end;

procedure TestTCodeStyleProfile.TestRuleSpecificOptions;
var
  Option: TCodeStyleProfileOption;
begin
  // Next to a word a word operator needs a space: a count of 0 is not valid
  Option := GetOption('SpacesWordOperators', 'SpacesBefore');
  CheckFalse(Option.IsValidValue('Exactly:0'), 'No space before a word operator');
  CheckTrue(Option.IsValidValue('Exactly:1'), 'One space before a word operator');
  CheckNotNull(FProfile.RuleById('SpacesWordOperators').FindOption('SpaceAtBracket'), 'Space next to a bracket');
  CheckNull(FProfile.RuleById('SpacesNot').FindOption('SpacesBefore'), 'The space before not is not set by its rule');
  CheckFalse(GetOption('SpacesNot', 'SpacesAfter').IsValidValue('AtMost:0'), 'No space after not');

  // Alignment only where code is aligned in columns
  CheckNotNull(FProfile.RuleById('SpacesAssignment').FindOption('AllowAlignment'), 'Alignment of :=');
  CheckNotNull(FProfile.RuleById('SpacesColonDeclaration').FindOption('AllowAlignment'), 'Alignment of colons');
  CheckNull(FProfile.RuleById('SpacesDot').FindOption('AllowAlignment'), 'No alignment of the point');
  CheckNull(FProfile.RuleById('SpacesComma').FindOption('AllowAlignment'), 'No alignment of commas');

  // Empty brackets only where they are possible
  CheckNotNull(FProfile.RuleById('SpacesCallParentheses').FindOption('SpacesInsideEmpty'), 'Foo()');
  CheckNotNull(FProfile.RuleById('SpacesSetBrackets').FindOption('SpacesInsideEmpty'), '[]');
  CheckNull(FProfile.RuleById('SpacesParentheses').FindOption('SpacesInsideEmpty'), 'No empty expression parentheses');
  CheckNull(FProfile.RuleById('SpacesIndexBrackets').FindOption('SpacesInsideEmpty'), 'No empty index brackets');

  // One gap between two declarations, one count
  CheckEquals(1, FProfile.RuleById('BlankLinesBetweenRoutines').OptionCount, 'Blank lines between routines');
  CheckEquals('AtLeast:1', GetOption('BlankLinesBetweenTypes', 'LinesBetween').Value, 'Blank lines between types');

  // A number instead of a choice that said the same
  CheckNull(FProfile.RuleById('UsesLayout').FindOption('Layout'), 'Layout of uses clauses');
  CheckNull(FProfile.RuleById('ArrayConstantLayout').FindOption('Layout'), 'Layout of constant arrays');
  CheckFalse(GetOption('EnumLayout', 'Layout').IsValidValue('OnePerLine'), 'One element per line is the number');

  // Settings without a level and rules with the level only
  CheckTrue(FProfile.RuleById('BlockIndent').Info.WithoutLevel, 'Size of a block indent');
  CheckEquals(0, FProfile.RuleById('IdentifierCharacters').OptionCount, 'Characters of identifiers');

  // Both directions of a style
  CheckEquals('ResultExit', GetOption('ExitWithValue', 'PreferredForm').Value, 'Exit with a value');
  CheckTrue(GetOption('ExitWithValue', 'PreferredForm').IsValidValue('ExitValue'), 'Exit(Value) can be required');
  CheckEquals('Explicit', GetOption('PointerDereference', 'Form').Value, 'Dereference');
  CheckTrue(GetOption('PointerDereference', 'Form').IsValidValue('Implicit'), 'Item.Name can be required');

  // New values and options
  CheckTrue(GetOption('NamesClasses', 'Case').IsValidValue('Snake'), 'snake_case');
  CheckTrue(GetOption('CompilerDirectiveCase', 'Case').IsValidValue('Pascal'), '{$IfDef}');
  CheckTrue(GetOption('FileEncoding', 'Encoding').IsValidValue('Ansi'), 'ANSI encoding');
  CheckFalse(GetOption('FileEncoding', 'Encoding').IsValidValue('Ascii'), 'ASCII is a check box, not an encoding');
  CheckFalse(GetOption('NamesPrivateFields', 'IncludeClassFields').AsBoolean, 'Class var fields');
  CheckFalse(GetOption('NamesGlobalConstants', 'IncludeTypedConstants').AsBoolean, 'Typed constants');
  CheckEquals(3, GetOption('NumberLiterals', 'DigitsPerGroup').AsInteger, 'Decimal digit groups');
  CheckEquals(4, GetOption('NumberLiterals', 'HexDigitsPerGroup').AsInteger, 'Hexadecimal digit groups');
  CheckEquals('Exactly:0', GetOption('SpacesPointerType', 'SpacesAfter').Value, 'Spaces after ^ of a pointer type');
end;

procedure TestTCodeStyleProfile.TestAssignResetSwitchOff;
var
  ProfileCopy: TCodeStyleProfile;
  CheckRuleCount: Integer;
begin
  ChangeProfile(FProfile);
  CheckEquals(6, FProfile.GetChangedRuleCount, 'Changed rules');
  CheckFalse(FProfile.RuleById('LineLength').IsDefault, 'Changed rule');
  CheckTrue(FProfile.RuleById('BlockIndent').IsDefault, 'Rule that is not changed');

  ProfileCopy := TCodeStyleProfile.Create;
  try
    ProfileCopy.Assign(FProfile);
    CheckProfilesEqual(FProfile, ProfileCopy, 'Assign');
  finally
    ProfileCopy.Free;
  end;

  FProfile.Reset;
  CheckEquals(0, FProfile.GetChangedRuleCount, 'Reset');
  CheckEquals(120, GetOption('LineLength', 'MaxLength').AsInteger, 'Option after Reset');

  CheckRuleCount := FProfile.GetCheckRuleCount;
  FProfile.SwitchOffAll;
  CheckEquals(0, FProfile.GetEnabledRuleCount, 'SwitchOffAll');
  CheckEquals(CheckRuleCount, FProfile.GetCheckRuleCount, 'Rules after SwitchOffAll');
  CheckEquals(120, GetOption('LineLength', 'MaxLength').AsInteger, 'Options keep their values');
end;

procedure TestTCodeStyleProfile.TestXmlRoundTrip;
var
  Document: IXMLDocument;
  ProfileNode, LineLengthNode: IXMLNode;
  ReadProfile: TCodeStyleProfile;
begin
  ChangeProfile(FProfile);
  Document := NewXMLDocument;
  ProfileNode := Document.AddChild(SETTINGS_NODE_PROFILE);
  FProfile.WriteSettings(ProfileNode);
  // Every rule is written to the node of its category
  CheckEquals(Length(CODE_STYLE_CATEGORIES), ProfileNode.ChildNodes.Count, 'Category nodes');
  LineLengthNode := ProfileNode.ChildNodes['Lines'].ChildNodes['LineLength'];
  CheckEquals('Error', VarToStr(LineLengthNode.Attributes[PROFILE_ATTRIBUTE_LEVEL]), 'Level attribute');
  CheckEquals('100', VarToStr(LineLengthNode.Attributes['MaxLength']), 'Option attribute');
  CheckEquals('Exactly:2',
      VarToStr(ProfileNode.ChildNodes['Operators'].ChildNodes['SpacesAssignment'].Attributes['SpacesAfter']),
      'Quantity attribute');
  CheckFalse(ProfileNode.ChildNodes['General'].ChildNodes['Profile'].HasAttribute(PROFILE_ATTRIBUTE_LEVEL),
      'General settings have no level');

  ReadProfile := TCodeStyleProfile.Create;
  try
    ReadProfile.ReadSettings(ProfileNode);
    CheckProfilesEqual(FProfile, ReadProfile, 'Read settings');

    ReadProfile.ReadSettings(nil);
    CheckEquals(0, ReadProfile.GetChangedRuleCount, 'No settings node gives the default values');
  finally
    ReadProfile.Free;
  end;
end;

procedure TestTCodeStyleProfile.TestXmlInvalidValues;
var
  Document: IXMLDocument;
  ProfileNode, RuleNode: IXMLNode;
begin
  Document := NewXMLDocument;
  ProfileNode := Document.AddChild(SETTINGS_NODE_PROFILE);
  RuleNode := ProfileNode.AddChild('Lines').AddChild('LineLength');
  RuleNode.Attributes[PROFILE_ATTRIBUTE_LEVEL] := 'Fatal';
  RuleNode.Attributes['MaxLength'] := '5000';
  RuleNode.Attributes['IgnoreCommentLines'] := 'true';
  RuleNode := ProfileNode.AddChild('Operators').AddChild('SpacesAssignment');
  RuleNode.Attributes['SpacesBefore'] := 'Exactly:20';
  RuleNode.Attributes['SpacesAfter'] := 'atmost:0';
  RuleNode := ProfileNode.AddChild('Case').AddChild('ReservedWordCase');
  RuleNode.Attributes[PROFILE_ATTRIBUTE_LEVEL] := 'warning';
  RuleNode.Attributes['Case'] := 'Mixed';
  // A rule in another category node is not found
  ProfileNode.AddChild('Lines').AddChild('BooleanComparison').Attributes[PROFILE_ATTRIBUTE_LEVEL] := 'Off';
  // Unknown nodes and attributes are ignored
  ProfileNode.AddChild('Lines').AddChild('UnknownRule').Attributes['Value'] := '1';
  RuleNode.Attributes['UnknownOption'] := '1';

  FProfile.RuleById('IndentStatements').Level := cslOff;
  FProfile.ReadSettings(ProfileNode);
  CheckEquals(Ord(cslHint), Ord(FProfile.RuleById('LineLength').Level), 'Invalid level');
  CheckEquals(120, GetOption('LineLength', 'MaxLength').AsInteger, 'Integer out of range');
  CheckTrue(GetOption('LineLength', 'IgnoreCommentLines').AsBoolean, 'Valid value is read');
  CheckEquals('Exactly:1', GetOption('SpacesAssignment', 'SpacesBefore').Value, 'Count out of range');
  CheckEquals('AtMost:0', GetOption('SpacesAssignment', 'SpacesAfter').Value, 'Quantity ignores the case');
  CheckEquals(Ord(cslWarning), Ord(FProfile.RuleById('ReservedWordCase').Level), 'Level ignores the case');
  CheckEquals('Lower', GetOption('ReservedWordCase', 'Case').Value, 'Unknown choice');
  CheckEquals(Ord(cslHint), Ord(FProfile.RuleById('BooleanComparison').Level), 'Rule in a wrong category');
  CheckEquals(Ord(cslHint), Ord(FProfile.RuleById('IndentStatements').Level), 'A missing rule node gives the default');
end;

procedure TestTCodeStyleProfile.TestProfileFile;
var
  FileName: string;
  LoadedProfile: TCodeStyleProfile;
  Document: IXMLDocument;
begin
  FileName := TPath.Combine(TPath.GetTempPath, TEST_PROFILE_FILE_NAME);
  LoadedProfile := TCodeStyleProfile.Create;
  try
    ChangeProfile(FProfile);
    FProfile.SaveToFile(FileName);
    LoadedProfile.LoadFromFile(FileName);
    CheckProfilesEqual(FProfile, LoadedProfile, 'Loaded profile');
    CheckEquals('My style', LoadedProfile.Name, 'Name of the loaded profile');

    Document := LoadXMLDocument(FileName);
    CheckEquals(PROFILE_FILE_ROOT_NODE, Document.DocumentElement.NodeName, 'Root node');
    CheckEquals(IntToStr(PROFILE_FILE_VERSION), VarToStr(Document.DocumentElement.Attributes[PROFILE_ATTRIBUTE_VERSION]),
        'Version');
    Document := nil;

    // Another XML file is not loaded and does not change the profile
    Document := NewXMLDocument;
    Document.AddChild('root');
    Document.SaveToFile(FileName);
    Document := nil;
    try
      LoadedProfile.LoadFromFile(FileName);
      Fail('A file with another root node is loaded');
    except
      on E: ECodeStyleProfileError do
        CheckProfilesEqual(FProfile, LoadedProfile, 'Profile after a failed load');
    end;
  finally
    LoadedProfile.Free;
    if FileExists(FileName) then
      DeleteFile(FileName);
  end;
end;

initialization
  // Register any test cases with the test runner
  RegisterTest(TestTCodeStyleProfile.Suite);
end.
