// Copy of Delphi-IDE-Code-Expert (DICE) Source/uWizardMain.pas, commit 5c8be6b, without the splash screen, the about
// box and the menu item image (they need the DICE bitmaps) and so without the plugin version. Not moved to DICE with
// the CodeStyle feature.
unit uWizardMain;

interface

uses
  ToolsApi, System.SysUtils, Vcl.Forms, Winapi.Windows, System.Classes,
  Vcl.Menus,
  uWizardConsts, uWizardSettings, uFeatureCollection, uWizardLog, ufmWizardSettings;

type
  // Plugin "application": creates all plugin objects and passes them their dependencies.
  // Lower level units get what they need through constructors and don't call GetDICEMainApp.
  TDICEMainApp = class(TObject)
  private
    class var FPluginTerminated: Boolean;
    class var FDICEMainAppInstance: TDICEMainApp;
    class var FSplashTimerHandle: UIntPtr;
  private
    FDICEMenuItem: TMenuItem;  // Owned by IDE Tools menu, but freed by plugin on unload
    FWizardSettings: TWizardSettings;
    FSettingsForm: TfmWizardSettings;
    FFeatures: TFeatureCollection;
    FLogger: TWizardLogger;

    procedure InitAfterIDELoad;
    procedure CreateAndInitSettingsForm;
    procedure ApplyIDEThemeToSettingsForm;
    procedure ShowModalSettingsForm;

    procedure OnClickWizardSettingsMenuItem(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    class destructor Destroy;

    class function GetDICEMainApp: TDICEMainApp;

    procedure InitApp;

    property WizardSettings: TWizardSettings read FWizardSettings;
    property Features: TFeatureCollection read FFeatures;
    property Logger: TWizardLogger read FLogger;
  end;

  TDICEWizard = class(TNotifierObject, IOTANotifier, IOTAWizard, IOTAMenuWizard)
  public
    // IOTAWizard
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
    // IOTAMenuWizard
    function GetMenuText: string;
  end;

// TWizardInitProc
function InitWizard(const BorlandIDEServices: IBorlandIDEServices; RegisterProc: TWizardRegisterProc;
    var Terminate: TWizardTerminateProc): Boolean stdcall;

// +++  http://www.delphikingdom.com/asp/viewitem.asp?catalogid=899
// +++ C:\GitHub Repos\OTAPI-Docs\The Delphi IDE Open Tools API - Version 1.2.docx

implementation

{ }

procedure DestroySplashTimer;
begin
  if TDICEMainApp.FSplashTimerHandle <> 0 then
    KillTimer(0, TDICEMainApp.FSplashTimerHandle);
  TDICEMainApp.FSplashTimerHandle := 0;
end;

// Logs an error that was not handled by the plugin objects. When plugin "application" doesn't exist
// (not created yet or already destroyed), error can be reported only to the debugger.
procedure LogUnhandledException(const AContext: string; E: Exception);
begin
  if not TDICEMainApp.FPluginTerminated and Assigned(TDICEMainApp.FDICEMainAppInstance) then
    TDICEMainApp.FDICEMainAppInstance.Logger.LogException(AContext, E)
  else
    OutputDebugString(PChar(WIZARD_NAME + ': ' + AContext + ', ' + E.ClassName + ': ' + E.Message));
end;

procedure OnSplashTimer(Wnd: HWND; Msg: Cardinal; IDEvent: Cardinal; Time: DWORD); stdcall;
begin
  // Windows silently suppresses exceptions raised in timer callbacks, so they must be handled here
  try
    if TDICEMainApp.FPluginTerminated or not Assigned(Application) or Application.Terminated then
      DestroySplashTimer
    else if (Application.MainForm <> nil) and Application.MainForm.Visible then
    begin
      DestroySplashTimer;
      TDICEMainApp.GetDICEMainApp.InitAfterIDELoad;
    end;
  except
    on E: Exception do
      LogUnhandledException('Error initializing plugin after IDE load', E);
  end;
end;

procedure InitSplashTimer;
begin
  DestroySplashTimer;
  TDICEMainApp.FSplashTimerHandle := SetTimer(0, 0, 100, @OnSplashTimer);
end;

procedure TerminateWizard;
begin
  // First of all, so timer is killed even if plugin is already marked as terminated
  DestroySplashTimer;
  if TDICEMainApp.FPluginTerminated then Exit;

  TDICEMainApp.FPluginTerminated := True;
  FreeAndNil(TDICEMainApp.FDICEMainAppInstance);
end;

function InitWizard(const BorlandIDEServices: IBorlandIDEServices; RegisterProc: TWizardRegisterProc;
    var Terminate: TWizardTerminateProc): Boolean stdcall;
var
  MainApp: TDICEMainApp;
begin
  Result := Assigned(BorlandIDEServices);

  if Result then
  begin
    TDICEMainApp.FSplashTimerHandle := 0;
    TDICEMainApp.FPluginTerminated := False;
    Terminate := TerminateWizard;

    // Exception must not get into the IDE expert loader. InitApp handles errors of its parts itself,
    // so here are only fatal errors (plugin objects can't be created), and the plugin is not loaded.
    try
      MainApp := TDICEMainApp.GetDICEMainApp;
      MainApp.InitApp;
      InitSplashTimer;

      // Last, because after registration IDE owns the wizard and the plugin can't be unloaded here
      RegisterProc(TDICEWizard.Create);
    except
      on E: Exception do
      begin
        // Rolls back everything already added to the IDE, so the DLL can be unloaded
        TerminateWizard;
        Terminate := nil;
        Result := False;
        LogUnhandledException('Error loading plugin', E);
      end;
    end;
  end;
end;

{ TDICEMainApp }

constructor TDICEMainApp.Create;
begin
  inherited Create;

  // First of all, so other parts of the plugin can log their errors
  FLogger := TWizardLogger.Create;
  FWizardSettings := TWizardSettings.Create(FLogger);
  FFeatures := TFeatureCollection.Create(FWizardSettings, FLogger);
end;

destructor TDICEMainApp.Destroy;
begin
  // GetDICEMainApp is not available here (instance is already nil), so nothing below should call it.

  // Menu first, so it can't be clicked while plugin is being destroyed
  FreeAndNil(FDICEMenuItem);

  // Features must be rolled back and freed before settings form, because the form owns features controls
  if Assigned(FFeatures) then
    FFeatures.FinalizeAllFeatures;
  FreeAndNil(FFeatures);
  FreeAndNil(FSettingsForm);
  FreeAndNil(FWizardSettings);
  FreeAndNil(FLogger);

  TDICEMainApp.FPluginTerminated := True;
  inherited Destroy;
end;

class destructor TDICEMainApp.Destroy;
begin
  FreeAndNil(FDICEMainAppInstance);
  DestroySplashTimer;
end;

class function TDICEMainApp.GetDICEMainApp: TDICEMainApp;
var
  NewInstance: TDICEMainApp;
begin
  if FPluginTerminated then
    raise Exception.Create('Error getting an instance of TDICEWizard, plugin already terminated.');

  if not Assigned(FDICEMainAppInstance) then
  begin
    NewInstance := TDICEMainApp.Create;
    if InterlockedCompareExchangePointer(Pointer(FDICEMainAppInstance), NewInstance, nil) <> nil then
      NewInstance.Free;
  end;

  Result := FDICEMainAppInstance;
end;

procedure TDICEMainApp.InitApp;
begin
  // Messages View is not ready yet, logger keeps errors and shows them when IDE is loaded.
  try
    FWizardSettings.InitXMLSettings;
  except
    on E: Exception do
      FLogger.LogException('Error initializing settings', E);
  end;
end;

procedure TDICEMainApp.InitAfterIDELoad;
var
  ToolsMenuItem, FirstDivider: TMenuItem;
  AppMainMenu: TMainMenu;
  ServicesIntf: INTAServices;
  i, DividerIndex: Integer;
begin
  // IDE is loaded, messages logged before this moment can be shown now
  FLogger.SetMessageViewReady;

  // Each part is protected separately, so an error in one of them doesn't stop the others
  try
    if Supports(BorlandIDEServices, INTAServices, ServicesIntf) then
      AppMainMenu := ServicesIntf.GetMainMenu
    else
      AppMainMenu := nil;

    if Assigned(AppMainMenu) then
    begin
      ToolsMenuItem := nil;
      for i := 0 to AppMainMenu.Items.Count - 1 do
        if AppMainMenu.Items[i].Name = 'ToolsMenu' then
        begin
          ToolsMenuItem := AppMainMenu.Items[i];
          Break;
        end;

      if Assigned(ToolsMenuItem) then
      begin
        FDICEMenuItem := TMenuItem.Create(ToolsMenuItem);
        FDICEMenuItem.Name := WIZARD_SETTINGS_MENU_ITEM_NAME;
        FDICEMenuItem.Caption := WIZARD_SETTINGS_MENU_ITEM_CAPTION;
        FDICEMenuItem.OnClick := OnClickWizardSettingsMenuItem;

        FirstDivider := ToolsMenuItem.Find('-');
        if Assigned(FirstDivider) then
          DividerIndex := FirstDivider.MenuIndex
        else
          DividerIndex := 0;

        ToolsMenuItem.Insert(DividerIndex, FDICEMenuItem);
      end
      else
        FLogger.LogError('Tools menu not found, settings menu item is not added');
    end;
  except
    on E: Exception do
    begin
      FreeAndNil(FDICEMenuItem);
      FLogger.LogException('Error adding settings menu item', E);
    end;
  end;

  // Errors of single features are handled inside, other features are still created and initialized
  FFeatures.CreateAllFeatures;
  FFeatures.InitAllFeatures;

  try
    CreateAndInitSettingsForm;
  except
    on E: Exception do
      FLogger.LogException('Error creating settings form', E);
  end;
end;

procedure TDICEMainApp.CreateAndInitSettingsForm;
var
  ThemingServices: IOTAIDEThemingServices;
begin
  if not Assigned(FSettingsForm) then
  begin
    // Form class must be registered before the form is created, so IDE applies its style to the form
    if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemingServices) then
      ThemingServices.RegisterFormClass(TfmWizardSettings);

    FSettingsForm := TfmWizardSettings.Create(nil);
    FFeatures.InitFeaturesControls(FSettingsForm);
    FSettingsForm.InitSectionsTree;

    FLogger.Log('Settings form created');
  end;
end;

procedure TDICEMainApp.ApplyIDEThemeToSettingsForm;
var
  ThemingServices: IOTAIDEThemingServices;
begin
  // Called before each showing, because user can change IDE theme while the form exists.
  // ApplyTheme sets colors of controls without style hooks (panels, labels, frames).
  try
    if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemingServices)
        and ThemingServices.IDEThemingEnabled then
      ThemingServices.ApplyTheme(FSettingsForm);
  except
    on E: Exception do
      FLogger.LogException('Error applying IDE theme to settings form', E);
  end;
end;

procedure TDICEMainApp.ShowModalSettingsForm;
begin
  CreateAndInitSettingsForm;
  ApplyIDEThemeToSettingsForm;
  FSettingsForm.ShowModal;
  FFeatures.SaveFeaturesSettings;
  FWizardSettings.FlushXMLSettings;
end;

procedure TDICEMainApp.OnClickWizardSettingsMenuItem(Sender: TObject);
begin
  ShowModalSettingsForm;
end;

{ TDICEWizard }

function TDICEWizard.GetIDString: string;
begin
  Result := WIZARD_ID_STRING;
end;

function TDICEWizard.GetName: string;
begin
  Result := WIZARD_NAME;
end;

function TDICEWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TDICEWizard.Execute;
begin
  if Assigned(Application) then
    Application.MessageBox(PWideChar(Format(WIZARD_HELP_MENU_TEXT, [WIZARD_PRODUCT_NAME, WIZARD_COPYRIGHT_TEXT, WIZARD_LICENCE_TEXT])),
        PWideChar(WIZARD_NAME));
end;

function TDICEWizard.GetMenuText: string;
begin
  Result := WIZARD_HELP_MENU_CAPTION;
end;

end.
