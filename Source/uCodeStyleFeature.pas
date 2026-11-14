// DICE feature: checks the code style of the modules of every compiled project with TPasParser and adds the found
// issues to the Build tab of the message view as compiler warnings and hints
unit uCodeStyleFeature;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Xml.XMLIntf,
  ToolsAPI,
  uWizardConsts, uBaseFeature, uFeatureCollection, ufmWizardSettings,
  uCodeStyleConsts, uCodeStyleRules, uCodeStyleProfile, uCodeStyleProjectChecker, uCodeStyleCompileNotifier,
  ufmCodeStyleProfile;

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
    // Settings of the code style rules; only edited and stored, the check does not use them yet
    FProfile: TCodeStyleProfile;
    // Summary of the profile under its button; parent will be frame, so no need to free
    FProfileSummaryLabel: TLabel;

    procedure RegisterCompileNotifier;
    procedure UnregisterCompileNotifier;
    // Creates a check box in the section of the feature; its parent frame frees it
    function AddSettingsCheckBox(ASettingsForm: TfmWizardSettings; const AName, ACaption: string; AChecked: Boolean;
        AOnClick: TNotifyEvent): TCheckBox;
    // Creates the button of the profile dialog and the summary label in the section of the feature
    procedure AddProfileControls(ASettingsForm: TfmWizardSettings);
    procedure UpdateProfileSummary;
    procedure SettingsCheckBoxClick(Sender: TObject);
    procedure RuleCheckBoxClick(Sender: TObject);
    procedure ProfileButtonClick(Sender: TObject);
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
  FreeAndNil(FProfile);

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

procedure TCodeStyleFeature.AddProfileControls(ASettingsForm: TfmWizardSettings);
const
  BUTTON_WIDTH = 180;
  BUTTON_HEIGHT = 25;
  LABEL_TOP = 31;
  PANEL_HEIGHT = 64;
var
  ProfilePanel: TPanel;
  ProfileButton: TButton;
  ThemingServices: IOTAIDEThemingServices;
begin
  // Before the dialog is created, so the IDE applies its style to it
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemingServices) then
    ThemingServices.RegisterFormClass(TfmCodeStyleProfile);

  ProfilePanel := TPanel.Create(nil);
  try
    ProfilePanel.Name := SETTINGS_PROFILE_PANEL_NAME;
    ProfilePanel.Caption := '';
    ProfilePanel.BevelOuter := bvNone;
    ProfilePanel.Height := PANEL_HEIGHT;

    // The panel frees its controls
    ProfileButton := TButton.Create(ProfilePanel);
    ProfileButton.Parent := ProfilePanel;
    ProfileButton.SetBounds(0, 0, BUTTON_WIDTH, BUTTON_HEIGHT);
    ProfileButton.Caption := SETTINGS_PROFILE_BUTTON_CAPTION;
    ProfileButton.OnClick := ProfileButtonClick;

    FProfileSummaryLabel := TLabel.Create(ProfilePanel);
    FProfileSummaryLabel.Parent := ProfilePanel;
    FProfileSummaryLabel.Left := 0;
    FProfileSummaryLabel.Top := LABEL_TOP;
    UpdateProfileSummary;

    // Assigning parent to control
    ASettingsForm.AddSettingsControl(SETTINGS_SECTION_NAME, ProfilePanel);
  except
    FProfileSummaryLabel := nil;
    ProfilePanel.Free;
    raise;
  end;
end;

procedure TCodeStyleFeature.UpdateProfileSummary;
begin
  if Assigned(FProfileSummaryLabel) then
    FProfileSummaryLabel.Caption := Format(SETTINGS_PROFILE_SUMMARY, [FProfile.Name, FProfile.GetEnabledRuleCount,
        FProfile.GetCheckRuleCount, FProfile.GetChangedRuleCount]);
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

procedure TCodeStyleFeature.ProfileButtonClick(Sender: TObject);
var
  ProfileForm: TfmCodeStyleProfile;
  ThemingServices: IOTAIDEThemingServices;
  ErrorMessage: string;
begin
  // The profile is saved with the other settings when the settings form is closed
  try
    ProfileForm := TfmCodeStyleProfile.Create(nil);
    try
      if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemingServices)
          and ThemingServices.IDEThemingEnabled
      then
        ThemingServices.ApplyTheme(ProfileForm);
      if ProfileForm.Execute(FProfile) then
        UpdateProfileSummary;
    finally
      ProfileForm.Free;
    end;
  except
    on E: Exception do
    begin
      FLogger.LogException(EMESSAGE_PROFILE_FAILED, E);
      // The settings form is modal and covers the message view, so the error is also shown to the user
      ErrorMessage := EMESSAGE_PROFILE_FAILED + ': ' + E.Message;
      Application.MessageBox(PChar(ErrorMessage), PChar(WIZARD_NAME), MB_OK or MB_ICONERROR);
    end;
  end;
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
  if not Assigned(FProfile) then
    FProfile := TCodeStyleProfile.Create;
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

  AddProfileControls(ASettingsForm);
end;

procedure TCodeStyleFeature.ReadFeatureSettings(AFeatureSettings: IXMLNode);
begin
  FRuleSet.ReadSettings(AFeatureSettings.ChildNodes[SETTINGS_NODE_RULES]);
  // A missing node gives the default values
  FProfile.ReadSettings(AFeatureSettings.ChildNodes.FindNode(SETTINGS_NODE_PROFILE));

  inherited ReadFeatureSettings(AFeatureSettings);
end;

procedure TCodeStyleFeature.WriteFeatureSettings(AFeatureSettings: IXMLNode);
begin
  inherited WriteFeatureSettings(AFeatureSettings);

  FRuleSet.WriteSettings(AFeatureSettings.ChildNodes[SETTINGS_NODE_RULES]);
  FProfile.WriteSettings(AFeatureSettings.ChildNodes[SETTINGS_NODE_PROFILE]);
  // The rules could change, the next compilation checks all sources with them
  FProjectChecker.ClearCache;
end;

initialization
  TFeatureCollection.RegisterFeature(TCodeStyleFeature);

end.
