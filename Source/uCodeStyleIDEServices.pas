// Access to the IDE for the code style check: the source files of a project, the text of the editor buffers and the
// messages of the Build tab of the message view
unit uCodeStyleIDEServices;

interface

uses
  System.SysUtils, System.Classes, ToolsAPI,
  uPasParser,
  uCodeStyleConsts, uCodeStyleRules;

// True for the files checked by the feature: units, programs and packages
function IsPascalSourceFile(const AFileName: string): Boolean;
// Adds the Pascal sources of AProject to AFileNames: its main source and its units, without duplicates
procedure GetProjectSourceFiles(const AProject: IOTAProject; AFileNames: TStrings);
// Source editor of AFileName when the file is open in the IDE, otherwise nil
function FindSourceEditor(const AFileName: string): IOTASourceEditor;
// Text of the editor buffer, also the changes that are not saved yet
function ReadEditorSource(const ASourceEditor: IOTASourceEditor): string;
// Text of the module that the compiler sees: the editor buffer when the file is open in the IDE, otherwise the file
function ReadModuleSource(const AFileName: string): string;
// Adds AIssue to the Build tab like a compiler message: "[CodeStyle Warning] uMain.pas(12): CS1001 ..."
procedure AddIssueMessage(const AMessageServices: IOTAMessageServices; const AFileName: string;
    const AIssue: TCodeStyleIssue);

implementation

{ }

function IsPascalSourceFile(const AFileName: string): Boolean;
var
  Extension, SourceExtension: string;
begin
  Extension := ExtractFileExt(AFileName);
  for SourceExtension in PASCAL_SOURCE_EXTENSIONS do
    if SameText(Extension, SourceExtension) then
      Exit(True);
  Result := False;
end;

procedure GetProjectSourceFiles(const AProject: IOTAProject; AFileNames: TStrings);
var
  i: Integer;

  procedure AddFileName(const AFileName: string);
  begin
    if IsPascalSourceFile(AFileName) and (AFileNames.IndexOf(AFileName) < 0) then
      AFileNames.Add(AFileName);
  end;

begin
  // The main source (.dpr, .dpk) is one of the files of the project module, the units are its modules
  for i := 0 to AProject.GetModuleFileCount - 1 do
    AddFileName(AProject.GetModuleFileEditor(i).FileName);
  for i := 0 to AProject.GetModuleCount - 1 do
    AddFileName(AProject.GetModule(i).FileName);
end;

function FindSourceEditor(const AFileName: string): IOTASourceEditor;
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  Editor: IOTAEditor;
  i: Integer;
begin
  Result := nil;
  if not Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) then
    Exit;

  Module := ModuleServices.FindModule(AFileName);
  if not Assigned(Module) then
    Exit;

  for i := 0 to Module.GetModuleFileCount - 1 do
  begin
    Editor := Module.GetModuleFileEditor(i);
    if SameFileName(Editor.FileName, AFileName) and Supports(Editor, IOTASourceEditor, Result) then
      Exit;
  end;
  Result := nil;
end;

function ReadEditorSource(const ASourceEditor: IOTASourceEditor): string;
var
  Reader: IOTAEditReader;
  Utf8Text: UTF8String;
  Position, ReadCount: Integer;
begin
  // The editor buffer is UTF-8
  Reader := ASourceEditor.CreateReader;
  Position := 0;
  repeat
    SetLength(Utf8Text, Position + EDITOR_READ_BLOCK_SIZE);
    ReadCount := Reader.GetText(Position, PAnsiChar(Utf8Text) + Position, EDITOR_READ_BLOCK_SIZE);
    Inc(Position, ReadCount);
  until ReadCount < EDITOR_READ_BLOCK_SIZE;
  SetLength(Utf8Text, Position);

  Result := UTF8ToString(Utf8Text);
  if (Result <> '') and (Result[1] = #$FEFF) then
    Delete(Result, 1, 1);
end;

function ReadModuleSource(const AFileName: string): string;
var
  SourceEditor: IOTASourceEditor;
begin
  SourceEditor := FindSourceEditor(AFileName);
  if Assigned(SourceEditor) then
    Result := ReadEditorSource(SourceEditor)
  else
    Result := TPasParser.GetFileDataString(AFileName);
end;

procedure AddIssueMessage(const AMessageServices: IOTAMessageServices; const AFileName: string;
    const AIssue: TCodeStyleIssue);
const
  MESSAGE_KINDS: array[TCodeStyleSeverity] of TOTAMessageKind = (
    otamkHint,
    otamkWarn
  );
var
  LineRef: Pointer;
begin
  AMessageServices.AddCompilerMessage(AFileName, AIssue.Code + ' ' + AIssue.Message, CODE_STYLE_TOOL_NAME,
      MESSAGE_KINDS[AIssue.Severity], AIssue.LineNumber, AIssue.Column, nil, LineRef);
end;

end.
