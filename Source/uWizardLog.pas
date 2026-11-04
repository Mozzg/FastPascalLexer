// Copy of Delphi-IDE-Code-Expert (DICE) Source/uWizardLog.pas, commit 5c8be6b, without changes: the CodeStyle feature
// is built on its API. Not moved to DICE with the CodeStyle feature.
unit uWizardLog;

interface

uses
  ToolsAPI, System.SysUtils, System.Classes, Winapi.Windows,
  uWizardConsts;

type
  TLogMessageKind = (lmkInfo, lmkError);

  // Writes plugin messages into own tab of IDE Messages window.
  // Messages logged before IDE is loaded are kept and written when message view becomes ready.
  // In release build only errors are written, info messages are skipped.
  TWizardLogger = class(TObject)
  private
    FPendingMessages: TStringList;
    FMessageViewReady: Boolean;

    procedure WriteToMessageView(const AMessage: string);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Log(const AMessage: string; AKind: TLogMessageKind = lmkInfo);
    procedure LogError(const AMessage: string);
    procedure LogException(const AContext: string; E: Exception);
    procedure SetMessageViewReady;
  end;

implementation

{ TWizardLogger }

constructor TWizardLogger.Create;
begin
  inherited Create;

  FPendingMessages := TStringList.Create;
  FMessageViewReady := False;
end;

destructor TWizardLogger.Destroy;
begin
  FreeAndNil(FPendingMessages);

  inherited Destroy;
end;

procedure TWizardLogger.Log(const AMessage: string; AKind: TLogMessageKind = lmkInfo);
begin
  {$IFDEF RELEASE}
  if AKind = lmkInfo then
    Exit;
  {$ENDIF}

  if FMessageViewReady then
    WriteToMessageView(AMessage)
  else
    FPendingMessages.Add(AMessage);
end;

procedure TWizardLogger.LogError(const AMessage: string);
begin
  Log(AMessage, lmkError);
end;

procedure TWizardLogger.LogException(const AContext: string; E: Exception);
begin
  LogError(AContext + ', ' + E.ClassName + ': ' + E.Message);
end;

procedure TWizardLogger.SetMessageViewReady;
var
  PendingMessage: string;
begin
  FMessageViewReady := True;

  for PendingMessage in FPendingMessages do
    WriteToMessageView(PendingMessage);
  FPendingMessages.Clear;
end;

procedure TWizardLogger.WriteToMessageView(const AMessage: string);
var
  MessageServices: IOTAMessageServices;
  MessageGroup: IOTAMessageGroup;
begin
  try
    if Supports(BorlandIDEServices, IOTAMessageServices, MessageServices) then
    begin
      // Group is not stored, because IDE deletes it when user closes the tab
      MessageGroup := MessageServices.GetGroup(WIZARD_NAME);
      if not Assigned(MessageGroup) then
        MessageGroup := MessageServices.AddMessageGroup(WIZARD_NAME);

      MessageServices.AddTitleMessage(AMessage, MessageGroup);
      MessageServices.ShowMessageView(MessageGroup);
    end;
  except
    on E: Exception do
      OutputDebugString(PWideChar('Error while writing to message log: ' + E.Message));
  end;
end;

end.
