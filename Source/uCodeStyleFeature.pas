// DICE feature: checks the code style of the modules of every compiled project with TPasParser and adds the found
// issues to the Build tab of the message view as compiler warnings and hints
unit uCodeStyleFeature;

interface

uses
  System.SysUtils, System.Classes, Vcl.StdCtrls, Xml.XMLIntf, ToolsAPI,
  uBaseFeature, uFeatureCollection, ufmWizardSettings,
  uCodeStyleConsts, uCodeStyleRules, uCodeStyleProjectChecker, uCodeStyleCompileNotifier;

type
  TCodeStyleFeature = class(TBaseFeature)
  private
    FRuleSet: TCodeStyleRuleSet;
    FProjectChecker: TCodeStyleProjectChecker;
    // Notifier registered in IOTACompileServices while the feature is enabled
    FCompileNotifier: TCodeStyleCompileNotifier;
    // Reference that keeps FCompileNotifier alive until it is unregistered
    FCompileNotifierRef: IOTACompileNotifier;
    FCompileNotifierIndex: Integer;
    // Parent will be frame, so no need to free
    FSettingsCheckBox: TCheckBox;

    procedure RegisterCompileNotifier;
    procedure UnregisterCompileNotifier;
    // Creates a check box in the section of the feature; its parent frame frees it
    function AddSettingsCheckBox(ASettingsForm: TfmWizardSettings; const AName, ACaption: string; AChecked: Boolean;
        AOnClick: TNotifyEvent): TCheckBox;
    procedure SettingsCheckBoxClick(Sender: TObject);
    procedure RuleCheckBoxClick(Sender: TObject);
  protected
    procedure SetFeatureEnabled(Value: Boolean); override;
  public
    destructor Destroy; override;

    procedure InitFeature; override;
    procedure InitFeatureControls(ASettingsForm: TfmWizardSettings); override;

    procedure ReadFeatureSettings(AFeatureSettings: IXMLNode); override;
    procedure WriteFeatureSettings(AFeatureSettings: IXMLNode); override;
  end;

implementation

{ TCodeStyleFeature }

destructor TCodeStyleFeature.Destroy;
begin
  // FinalizeFeature has already disabled the feature, unless it failed: the notifier must not outlive the feature.
  // Not FeatureEnabled := False: the settings check box may be already freed with the settings form.
  UnregisterCompileNotifier;
  FreeAndNil(FProjectChecker);
  FreeAndNil(FRuleSet);

  inherited Destroy;
end;

procedure TCodeStyleFeature.RegisterCompileNotifier;
var
  CompileServices: IOTACompileServices;
begin
  if Assigned(FCompileNotifier) then
    Exit;
  if not Supports(BorlandIDEServices, IOTACompileServices, CompileServices) then
    raise Exception.Create(EMESSAGE_NO_COMPILE_SERVICES);

  // The sources could change while the feature was disabled
  FProjectChecker.ClearCache;
  FCompileNotifier := TCodeStyleCompileNotifier.Create(FProjectChecker, FLogger);
  FCompileNotifierRef := FCompileNotifier;
  FCompileNotifierIndex := CompileServices.AddNotifier(FCompileNotifierRef);
end;

procedure TCodeStyleFeature.UnregisterCompileNotifier;
var
  CompileServices: IOTACompileServices;
begin
  if not Assigned(FCompileNotifier) then
    Exit;

  FCompileNotifier.Detach;
  if Assigned(BorlandIDEServices) and Supports(BorlandIDEServices, IOTACompileServices, CompileServices) then
    CompileServices.RemoveNotifier(FCompileNotifierIndex);
  FCompileNotifier := nil;
  FCompileNotifierRef := nil;
end;

function TCodeStyleFeature.AddSettingsCheckBox(ASettingsForm: TfmWizardSettings; const AName, ACaption: string;
    AChecked: Boolean; AOnClick: TNotifyEvent): TCheckBox;
begin
  Result := TCheckBox.Create(nil);
  try
    Result.Name := AName;
    Result.Caption := ACaption;
    Result.Checked := AChecked;
    Result.OnClick := AOnClick;
    // Assigning parent to control
    ASettingsForm.AddSettingsControl(SETTINGS_SECTION_NAME, Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TCodeStyleFeature.SettingsCheckBoxClick(Sender: TObject);
begin
  ApplyCheckBoxState(Sender as TCheckBox);
end;

procedure TCodeStyleFeature.RuleCheckBoxClick(Sender: TObject);
var
  RuleCheckBox: TCheckBox;
begin
  // The cache of the checked sources is cleared when the settings are saved
  RuleCheckBox := Sender as TCheckBox;
  FRuleSet[RuleCheckBox.Tag].Enabled := RuleCheckBox.Checked;
end;

procedure TCodeStyleFeature.SetFeatureEnabled(Value: Boolean);
begin
  if FFeatureEnabled = Value then Exit;

  if Value then
    RegisterCompileNotifier
  else
    UnregisterCompileNotifier;
  FFeatureEnabled := Value;

  if Assigned(FSettingsCheckBox) then
    FSettingsCheckBox.Checked := FFeatureEnabled;
end;

procedure TCodeStyleFeature.InitFeature;
begin
  // Before the settings are read: enabling the feature registers the notifier with the project checker
  if not Assigned(FRuleSet) then
    FRuleSet := TCodeStyleRuleSet.Create;
  if not Assigned(FProjectChecker) then
    FProjectChecker := TCodeStyleProjectChecker.Create(FRuleSet);

  inherited InitFeature;
end;

procedure TCodeStyleFeature.InitFeatureControls(ASettingsForm: TfmWizardSettings);
var
  RuleCheckBox: TCheckBox;
  Rule: TCodeStyleRule;
  i: Integer;
begin
  // An exception is logged by TFeatureCollection.InitFeaturesControls, the other features still get their controls
  FSettingsCheckBox := AddSettingsCheckBox(ASettingsForm, SETTINGS_FEATURE_CHECKBOX_NAME,
      SETTINGS_FEATURE_CHECKBOX_CAPTION, FeatureEnabled, SettingsCheckBoxClick);

  for i := 0 to FRuleSet.Count - 1 do
  begin
    Rule := FRuleSet[i];
    RuleCheckBox := AddSettingsCheckBox(ASettingsForm, Format(SETTINGS_RULE_CHECKBOX_NAME, [Rule.GetCode]),
        Format(SETTINGS_RULE_CHECKBOX_CAPTION, [Rule.GetCode, Rule.GetDescription]), Rule.Enabled, RuleCheckBoxClick);
    RuleCheckBox.Tag := i;
  end;
end;

procedure TCodeStyleFeature.ReadFeatureSettings(AFeatureSettings: IXMLNode);
begin
  FRuleSet.ReadSettings(AFeatureSettings.ChildNodes[SETTINGS_NODE_RULES]);

  inherited ReadFeatureSettings(AFeatureSettings);
end;

procedure TCodeStyleFeature.WriteFeatureSettings(AFeatureSettings: IXMLNode);
begin
  inherited WriteFeatureSettings(AFeatureSettings);

  FRuleSet.WriteSettings(AFeatureSettings.ChildNodes[SETTINGS_NODE_RULES]);
  // The rules could change, the next compilation checks all sources with them
  FProjectChecker.ClearCache;
end;

initialization
  TFeatureCollection.RegisterFeature(TCodeStyleFeature);

end.
