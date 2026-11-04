// Copy of Delphi-IDE-Code-Expert (DICE) Source/uWizardSettings.pas, commit 5c8be6b, without changes: the CodeStyle feature
// is built on its API. Not moved to DICE with the CodeStyle feature.
unit uWizardSettings;

interface

uses
  System.SysUtils, Xml.XMLDoc, Xml.XMLIntf, System.IOUtils, Winapi.Windows,
  uWizardConsts, uWizardUtils, uWizardLog;

type
  // Storage of plugin settings in XML file. Settings form is managed by TDICEMainApp.
  TWizardSettings = class(TObject)
  private
    FLogger: TWizardLogger;
    FXMLDocSettings: IXMLDocument;
    FSettingsFilePath: string;

    function GetDLLPath: string;
  public
    constructor Create(ALogger: TWizardLogger);
    destructor Destroy; override;

    procedure InitXMLSettings;
    procedure FlushXMLSettings;
    function GetXMLSettingsForFeature(const AFeatureName: string): IXMLNode;
  end;

implementation

{ TWizardSettings }

constructor TWizardSettings.Create(ALogger: TWizardLogger);
begin
  inherited Create;

  FLogger := ALogger;
end;

destructor TWizardSettings.Destroy;
begin
  FXMLDocSettings := nil;

  inherited Destroy;
end;

function TWizardSettings.GetDLLPath: string;
begin
  // Directory of the plugin DLL, not the full file name
  Result := ExtractFilePath(GetModuleFileNameCustom);
end;

procedure TWizardSettings.InitXMLSettings;
begin
  FSettingsFilePath := IncludeTrailingPathDelimiter(TPath.GetHomePath) + WIZARD_NAME + '\' + WIZARD_NAME + '.xml';
  if not ForceDirectories(ExtractFilePath(FSettingsFilePath)) then
    FSettingsFilePath := IncludeTrailingPathDelimiter(GetDLLPath) + WIZARD_NAME + '.xml';

  try
    if not FileExists(FSettingsFilePath) then
    begin
      FXMLDocSettings := NewXMLDocument;
      FXMLDocSettings.AddChild('root');
      FXMLDocSettings.SaveToFile(FSettingsFilePath);
      FXMLDocSettings := nil;
    end;

    FXMLDocSettings := TXMLDocument.Create(FSettingsFilePath);
    FXMLDocSettings.Active := True;
    FXMLDocSettings.Options := [doNodeAutoCreate, doNodeAutoIndent, doAttrNull, doAutoSave];
    FXMLDocSettings.Encoding := 'UTF-8';
  except
    on E: Exception do
    begin
      FLogger.LogException('Error loading settings from ' + FSettingsFilePath
          + ', default settings are used, file will be overwritten on next save', E);

      // Root node is required, GetXMLSettingsForFeature works with DocumentElement
      FXMLDocSettings := nil;
      FXMLDocSettings := NewXmlDocument;
      FXMLDocSettings.Options := [doNodeAutoCreate, doNodeAutoIndent, doAttrNull, doAutoSave];
      FXMLDocSettings.Encoding := 'UTF-8';
      FXMLDocSettings.AddChild('root');
    end;
  end;
end;

procedure TWizardSettings.FlushXMLSettings;
begin
  try
    if FXMLDocSettings.FileName <> FSettingsFilePath then
      FXMLDocSettings.FileName := FSettingsFilePath;
    FXMLDocSettings.SaveToFile(FSettingsFilePath);
  except
    on E: Exception do
      // Settings form is already closed here, so error is shown in Messages window
      FLogger.LogException('Error saving settings to ' + FSettingsFilePath, E);
  end;
end;

function TWizardSettings.GetXMLSettingsForFeature(const AFeatureName: string): IXMLNode;
begin
  Result := FXMLDocSettings.DocumentElement.ChildNodes.Nodes[AFeatureName];
end;

end.
