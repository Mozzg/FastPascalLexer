// Code style check of the modules of a compiled project, the issues go to the Build tab of the message view
unit uCodeStyleProjectChecker;

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Hash, System.Diagnostics, System.Generics.Collections,
  ToolsAPI,
  uCodeStyleConsts, uCodeStyleRules, uCodeStyleChecker, uCodeStyleIDEServices;

type
  TCodeStyleProjectChecker = class(TObject)
  private
    FChecker: TCodeStyleChecker;
    FIssues: TCodeStyleIssueList;
    // Hashes of the checked sources by the project and the file name: a make does not check an unchanged source
    // again, like the compiler does not compile an unchanged unit again
    FSourceHashes: TDictionary<string, Integer>;
    // Counters of the messages of the current check
    FWarningCount: Integer;
    FHintCount: Integer;

    // Checks the file when ACheckAll or when it changed after the last check; returns True when it was checked
    function CheckFile(const AMessageServices: IOTAMessageServices; const AProjectFileName, AFileName: string;
        ACheckAll: Boolean): Boolean;
    // Adds the issues of the file to the Build tab, at most MAX_ISSUES_PER_FILE of them
    procedure WriteIssues(const AMessageServices: IOTAMessageServices; const AFileName: string);
    procedure WriteIssue(const AMessageServices: IOTAMessageServices; const AFileName: string;
        const AIssue: TCodeStyleIssue);
  public
    // The rule set is not owned
    constructor Create(ARuleSet: TCodeStyleRuleSet);
    destructor Destroy; override;

    // Checks the Pascal sources of AProject after its compilation in AMode
    procedure CheckProject(const AProject: IOTAProject; AMode: TOTACompileMode);
    // Forgets the checked sources, so the next compilation checks all of them: called when the settings change
    procedure ClearCache;
  end;

implementation

{ TCodeStyleProjectChecker }

constructor TCodeStyleProjectChecker.Create(ARuleSet: TCodeStyleRuleSet);
begin
  inherited Create;

  FChecker := TCodeStyleChecker.Create(ARuleSet);
  FIssues := TCodeStyleIssueList.Create;
  FSourceHashes := TDictionary<string, Integer>.Create;
end;

destructor TCodeStyleProjectChecker.Destroy;
begin
  FreeAndNil(FSourceHashes);
  FreeAndNil(FIssues);
  FreeAndNil(FChecker);

  inherited Destroy;
end;

function TCodeStyleProjectChecker.CheckFile(const AMessageServices: IOTAMessageServices;
    const AProjectFileName, AFileName: string; ACheckAll: Boolean): Boolean;
var
  Source, CacheKey: string;
  SourceHash, CheckedHash: Integer;
begin
  Source := ReadModuleSource(AFileName);
  CacheKey := AnsiLowerCase(AProjectFileName + '|' + AFileName);
  SourceHash := THashBobJenkins.GetHashValue(Source);
  if (not ACheckAll) and FSourceHashes.TryGetValue(CacheKey, CheckedHash) and (CheckedHash = SourceHash) then
    Exit(False);

  FIssues.Clear;
  FChecker.CheckSource(AFileName, Source, FIssues);
  WriteIssues(AMessageServices, AFileName);
  FSourceHashes.AddOrSetValue(CacheKey, SourceHash);
  Result := True;
end;

procedure TCodeStyleProjectChecker.WriteIssues(const AMessageServices: IOTAMessageServices; const AFileName: string);
var
  TooManyIssue: TCodeStyleIssue;
  i: Integer;
begin
  for i := 0 to Min(FIssues.Count, MAX_ISSUES_PER_FILE) - 1 do
    WriteIssue(AMessageServices, AFileName, FIssues[i]);

  if FIssues.Count > MAX_ISSUES_PER_FILE then
  begin
    TooManyIssue := FIssues[MAX_ISSUES_PER_FILE];
    TooManyIssue.Code := CODE_TOO_MANY_ISSUES;
    TooManyIssue.Severity := cssHint;
    TooManyIssue.Message := Format(MESSAGE_TOO_MANY_ISSUES, [FIssues.Count - MAX_ISSUES_PER_FILE]);
    WriteIssue(AMessageServices, AFileName, TooManyIssue);
  end;
end;

procedure TCodeStyleProjectChecker.WriteIssue(const AMessageServices: IOTAMessageServices; const AFileName: string;
    const AIssue: TCodeStyleIssue);
begin
  AddIssueMessage(AMessageServices, AFileName, AIssue);
  case AIssue.Severity of
    cssHint: Inc(FHintCount);
    cssWarning: Inc(FWarningCount);
  end;
end;

procedure TCodeStyleProjectChecker.CheckProject(const AProject: IOTAProject; AMode: TOTACompileMode);
const
  CHECKED_COMPILE_MODES = [cmOTAMake, cmOTABuild, cmOTACheck, cmOTAMakeUnit];
var
  MessageServices: IOTAMessageServices;
  FileNames: TStringList;
  Stopwatch: TStopwatch;
  ErrorIssue: TCodeStyleIssue;
  FileName: string;
  CheckedCount: Integer;
begin
  if (not (AMode in CHECKED_COMPILE_MODES)) or (not Assigned(AProject))
      or (not Supports(BorlandIDEServices, IOTAMessageServices, MessageServices))
  then
    Exit;

  Stopwatch := TStopwatch.StartNew;
  CheckedCount := 0;
  FWarningCount := 0;
  FHintCount := 0;
  FileNames := TStringList.Create;
  try
    GetProjectSourceFiles(AProject, FileNames);
    for FileName in FileNames do
    begin
      try
        if CheckFile(MessageServices, AProject.FileName, FileName, AMode = cmOTABuild) then
          Inc(CheckedCount);
      except
        on E: Exception do
        begin
          // One broken file does not stop the check of the others
          ErrorIssue.Code := CODE_CHECK_ERROR;
          ErrorIssue.Severity := cssWarning;
          ErrorIssue.LineNumber := 1;
          ErrorIssue.Column := 1;
          ErrorIssue.Message := Format(MESSAGE_CHECK_ERROR, [E.ClassName, E.Message]);
          WriteIssue(MessageServices, FileName, ErrorIssue);
        end;
      end;
    end;
  finally
    FileNames.Free;
  end;

  if CheckedCount > 0 then
    MessageServices.AddTitleMessage(Format(MESSAGE_CHECK_SUMMARY,
        [CheckedCount, Stopwatch.ElapsedMilliseconds, FWarningCount, FHintCount]));
end;

procedure TCodeStyleProjectChecker.ClearCache;
begin
  FSourceHashes.Clear;
end;

end.
