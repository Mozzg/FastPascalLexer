// Copy of Delphi-IDE-Code-Expert (DICE) Source/uBaseFeature.pas, commit 5c8be6b, without changes: the CodeStyle feature
// is built on its API. Not moved to DICE with the CodeStyle feature.
unit uBaseFeature;

interface

uses
  Xml.XMLIntf, System.Variants, System.SysUtils, Vcl.StdCtrls, Vcl.Forms, Winapi.Windows,
  uWizardConsts, uWizardSettings, uWizardLog, ufmWizardSettings;

type
  TBaseFeature = class(TObject)
  protected
    FFeatureEnabled: Boolean;
    FGlobalWizardSettings: TWizardSettings;
    FLogger: TWizardLogger;

    function GetFeatureEnabled: Boolean; virtual;
    procedure SetFeatureEnabled(Value: Boolean); virtual; abstract;
    // Switches feature by settings checkbox. If switching fails, checkbox is returned to the real
    // state of the feature, so it doesn't show the wrong state next time the form is opened.
    procedure ApplyCheckBoxState(ACheckBox: TCheckBox);
  public
    constructor CreateFeature(AWizardSettings: TWizardSettings; ALogger: TWizardLogger); virtual;

    procedure InitFeature; virtual;
    procedure InitFeatureControls(ASettingsForm: TfmWizardSettings); virtual;
    // Rolls back all changes made to the IDE, called before plugin is unloaded
    procedure FinalizeFeature; virtual;

    procedure ReadFeatureSettings(AFeatureSettings: IXMLNode); virtual;
    procedure WriteFeatureSettings(AFeatureSettings: IXMLNode); virtual;

    property FeatureEnabled: Boolean read GetFeatureEnabled write SetFeatureEnabled;
    property Logger: TWizardLogger read FLogger;
  end;

  TBaseFeatureClass = class of TBaseFeature;

implementation

{ TBaseFeature }

constructor TBaseFeature.CreateFeature(AWizardSettings: TWizardSettings; ALogger: TWizardLogger);
begin
  inherited Create;

  FFeatureEnabled := False;
  FGlobalWizardSettings := AWizardSettings;
  FLogger := ALogger;
end;

function TBaseFeature.GetFeatureEnabled: Boolean;
begin
  Result := FFeatureEnabled;
end;

procedure TBaseFeature.ApplyCheckBoxState(ACheckBox: TCheckBox);
var
  ErrorMessage: string;
begin
  try
    FeatureEnabled := ACheckBox.Checked;
  except
    on E: Exception do
    begin
      // Triggers OnClick again, but state is the same as feature state, so nothing is switched
      ACheckBox.Checked := FeatureEnabled;

      FLogger.LogException('Error switching feature ' + ClassName, E);
      // Settings form is modal and covers Messages window, so error is also shown to user
      ErrorMessage := 'Error switching "' + ACheckBox.Caption + '": ' + E.Message;
      Application.MessageBox(PChar(ErrorMessage), PChar(WIZARD_NAME), MB_OK or MB_ICONERROR);
    end;
  end;
end;

procedure TBaseFeature.InitFeature;
var
  FeatureSettings: IXMLNode;
begin
  try
    FeatureSettings := FGlobalWizardSettings.GetXMLSettingsForFeature(ClassName);
    ReadFeatureSettings(FeatureSettings);
    // Not in finally, so it is not logged when initialization failed
    FLogger.Log('Feature ' + Self.ClassName + ' initialized');
  finally
    FeatureSettings := nil;
  end;
end;

procedure TBaseFeature.InitFeatureControls(ASettingsForm: TfmWizardSettings);
begin
  // Empty method, no controls to init
end;

procedure TBaseFeature.FinalizeFeature;
begin
  // Settings are not saved here, so feature will be enabled again on next IDE start
  FeatureEnabled := False;
end;

procedure TBaseFeature.ReadFeatureSettings(AFeatureSettings: IXMLNode);
var
  FeatureEnabledSetting: OleVariant;
begin
  FeatureEnabledSetting := AFeatureSettings.Attributes['Enabled'];
  if not VarIsNull(FeatureEnabledSetting) then
    FeatureEnabled := FeatureEnabledSetting;
end;

procedure TBaseFeature.WriteFeatureSettings(AFeatureSettings: IXMLNode);
begin
  AFeatureSettings.Attributes['Enabled'] := FeatureEnabled;
end;

end.
