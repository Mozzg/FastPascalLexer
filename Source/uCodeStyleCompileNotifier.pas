// Notifier of the IDE compilation that starts the code style check of every compiled project
unit uCodeStyleCompileNotifier;

interface

uses
  System.SysUtils, System.Classes, ToolsAPI,
  uWizardLog,
  uCodeStyleConsts, uCodeStyleProjectChecker;

type
  TCodeStyleCompileNotifier = class(TInterfacedObject, IOTACompileNotifier)
  private
    FProjectChecker: TCodeStyleProjectChecker;
    // Plugin log (a tab of the message view) for the errors of the check
    FLogger: TWizardLogger;
    // Mode of the running compilation: ProjectCompileFinished does not pass it
    FCompileMode: TOTACompileMode;
  public
    // The project checker and the logger are not owned
    constructor Create(AProjectChecker: TCodeStyleProjectChecker; ALogger: TWizardLogger);

    // Called before the project checker and the logger are freed: the IDE may keep the notifier a bit longer
    procedure Detach;

    // IOTACompileNotifier
    procedure ProjectCompileStarted(const Project: IOTAProject; Mode: TOTACompileMode);
    procedure ProjectCompileFinished(const Project: IOTAProject; Result: TOTACompileResult);
    procedure ProjectGroupCompileStarted(Mode: TOTACompileMode);
    procedure ProjectGroupCompileFinished(Result: TOTACompileResult);
  end;

implementation

{ TCodeStyleCompileNotifier }

constructor TCodeStyleCompileNotifier.Create(AProjectChecker: TCodeStyleProjectChecker; ALogger: TWizardLogger);
begin
  inherited Create;

  FProjectChecker := AProjectChecker;
  FLogger := ALogger;
  FCompileMode := cmOTAMake;
end;

procedure TCodeStyleCompileNotifier.Detach;
begin
  FProjectChecker := nil;
  FLogger := nil;
end;

procedure TCodeStyleCompileNotifier.ProjectCompileStarted(const Project: IOTAProject; Mode: TOTACompileMode);
begin
  FCompileMode := Mode;
end;

procedure TCodeStyleCompileNotifier.ProjectCompileFinished(const Project: IOTAProject; Result: TOTACompileResult);
begin
  if (not Assigned(FProjectChecker)) or (Result = crOTABackground) then
    Exit;
  // +++ With the background compilation the notification may come from the compiler thread, the check is not done
  // there yet: it uses the editor buffers and the message view
  if TThread.CurrentThread.ThreadID <> MainThreadID then
    Exit;

  // The exception must not get into the IDE compiler
  try
    FProjectChecker.CheckProject(Project, FCompileMode);
  except
    on E: Exception do
      FLogger.LogException(Format(EMESSAGE_CHECK_PROJECT_FAILED, [Project.FileName]), E);
  end;
end;

procedure TCodeStyleCompileNotifier.ProjectGroupCompileStarted(Mode: TOTACompileMode);
begin
end;

procedure TCodeStyleCompileNotifier.ProjectGroupCompileFinished(Result: TOTACompileResult);
begin
end;

end.
