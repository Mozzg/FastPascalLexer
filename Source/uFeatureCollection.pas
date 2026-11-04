// Copy of Delphi-IDE-Code-Expert (DICE) Source/uFeatureCollection.pas, commit 5c8be6b, without changes: the CodeStyle feature
// is built on its API. Not moved to DICE with the CodeStyle feature.
unit uFeatureCollection;

interface

uses
  System.Generics.Collections, System.SysUtils, Xml.XMLIntf, Winapi.Windows,
  uWizardConsts, uBaseFeature, uWizardSettings, uWizardLog, ufmWizardSettings;

type
  TFeatureCollection = class(TObject)
  private
    class var FFeatureClassList: TList<TBaseFeatureClass>;
  private
    FFeatureList: TObjectList<TBaseFeature>;
    FWizardSettings: TWizardSettings;
    FLogger: TWizardLogger;
  public
    constructor Create(AWizardSettings: TWizardSettings; ALogger: TWizardLogger);
    destructor Destroy; override;

    class procedure RegisterFeature(AFeatureClass: TBaseFeatureClass);

    procedure CreateAllFeatures;
    procedure InitAllFeatures;
    procedure InitFeaturesControls(ASettingsForm: TfmWizardSettings);
    procedure SaveFeaturesSettings;
    procedure FinalizeAllFeatures;
  end;

implementation

{ TFeatureCollection }

constructor TFeatureCollection.Create(AWizardSettings: TWizardSettings; ALogger: TWizardLogger);
begin
  inherited Create;

  FFeatureList := TObjectList<TBaseFeature>.Create(True);
  FWizardSettings := AWizardSettings;
  FLogger := ALogger;
end;

destructor TFeatureCollection.Destroy;
begin
  FreeAndNil(FFeatureList);

  inherited Destroy;
end;

class procedure TFeatureCollection.RegisterFeature(AFeatureClass: TBaseFeatureClass);
begin
  FFeatureClassList.Add(AFeatureClass);
end;

procedure TFeatureCollection.CreateAllFeatures;
var
  FeatureClass: TBaseFeatureClass;
  Feature: TBaseFeature;
begin
  for FeatureClass in FFeatureClassList do
  begin
    Feature := nil;

    try
      // CreateFeature is virtual, so constructor of the actual feature class is called
      Feature := FeatureClass.CreateFeature(FWizardSettings, FLogger);
      FFeatureList.Add(Feature);
    except
      on E: Exception do
      begin
        FreeAndNil(Feature);
        FLogger.LogException('Error creating feature of class ' + FeatureClass.ClassName, E);
      end;
    end;
  end;
end;

procedure TFeatureCollection.InitAllFeatures;
var
  Feature: TBaseFeature;
begin
  for Feature in FFeatureList do
  begin
    // Error in one feature must not stop initialization of the others
    try
      Feature.InitFeature;
    except
      on E: Exception do
        FLogger.LogException('Error initializing feature ' + Feature.ClassName, E);
    end;
  end;
end;

procedure TFeatureCollection.InitFeaturesControls(ASettingsForm: TfmWizardSettings);
var
  Feature: TBaseFeature;
begin
  for Feature in FFeatureList do
  begin
    // Error in one feature must not stop creating controls of the others
    try
      Feature.InitFeatureControls(ASettingsForm);
    except
      on E: Exception do
        FLogger.LogException('Error creating settings controls of feature ' + Feature.ClassName, E);
    end;
  end;
end;

procedure TFeatureCollection.SaveFeaturesSettings;
var
  Feature: TBaseFeature;
  FeatureSettings: IXMLNode;
begin
  for Feature in FFeatureList do
  begin
    // Error in one feature must not stop saving settings of the others
    try
      try
        FeatureSettings := FWizardSettings.GetXMLSettingsForFeature(Feature.ClassName);
        Feature.WriteFeatureSettings(FeatureSettings);
      finally
        FeatureSettings := nil;
      end;
    except
      on E: Exception do
        FLogger.LogException('Error saving settings of feature ' + Feature.ClassName, E);
    end;
  end;
end;

procedure TFeatureCollection.FinalizeAllFeatures;
var
  i: Integer;
  Feature: TBaseFeature;
begin
  // Reverse order, so features are rolled back in the opposite order of their initialization.
  // IDE is shutting down, so errors are not shown, only reported to the debugger.
  for i := FFeatureList.Count - 1 downto 0 do
  begin
    Feature := FFeatureList[i];
    try
      Feature.FinalizeFeature;
    except
      on E: Exception do
        OutputDebugString(PWideChar(WIZARD_NAME + ': error finalizing feature ' + Feature.ClassName + ', message: ' + E.Message));
    end;
  end;
end;

initialization
  TFeatureCollection.FFeatureClassList := TList<TBaseFeatureClass>.Create;

finalization
  FreeAndNil(TFeatureCollection.FFeatureClassList);

end.
