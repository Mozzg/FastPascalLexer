(*******************************************************************************
*  Copyright © 2026 Pervov Evgeny                                              *
*                                                                              *
*  Licensed under the Apache License, Version 2.0 (the "License");             *
*  you may not use this file except in compliance with the License.            *
*  You may obtain a copy of the License at                                     *
*                                                                              *
*      http://www.apache.org/licenses/LICENSE-2.0                              *
*                                                                              *
*  Unless required by applicable law or agreed to in writing, software         *
*  distributed under the License is distributed on an "AS IS" BASIS,           *
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.    *
*  See the License for the specific language governing permissions and         *
*  limitations under the License.                                              *
*                                                                              *
*  Author: Pervov Evgeny                                                       *
*  Created: 31.10.2026                                                         *
*  Classes: EBenchmarkError, TLexerBenchmark                                   *
*  Description: Console benchmark of TPasLexer tokenization speed. Loads a     *
*    Pascal source once, validates one full pass, runs warm-up passes and      *
*    then measured passes of SetData + NextToken over the whole text, and      *
*    prints the timing summary as "Key: Value" lines.                          *
*  Version: 0.1                                                                *
*  Last modified: 31.10.2026                                                   *
*  Contributor(s):                                                             *
*    Pervov Evgeny <operationm@list.ru>                                        *
*******************************************************************************)

unit uLexerBenchmark;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Winapi.Windows,
  uPasLexer, uPasLexerTypes, uPasParser, uPasLexerPerformance,
  uLexerBenchmarkConsts;

type
  // Benchmark failure carrying the process exit code to report
  EBenchmarkError = class(Exception)
  private
    FExitCode: Integer;
  public
    constructor Create(AExitCode: Integer; const AMessage: string);

    // Process exit code describing the failure
    property ExitCode: Integer read FExitCode;
  end;

  // Main class of the console benchmark: reads the command line, runs the passes and prints the summary
  TLexerBenchmark = class(TObject)
  private
    FLexer: TPasLexer;
    FStopwatch: THighResolutionStopwatch;
    FFormatSettings: TFormatSettings;
    FFileName: string;
    FFileSize: Int64;
    // Text of the input file, loaded once and tokenized by every pass
    FData: string;
    FIterations: Integer;
    FWarmupCount: Integer;
    FHelpRequested: Boolean;
    FHighPriority: Boolean;
    // Token count of the validation pass, every later pass must produce the same count
    FTokenCount: Int64;
    // Duration of every measured pass in nanoseconds, sorted after the measurement
    FPassTimes: TArray<Int64>;
    function ReadCount(const ASwitch, AValue: string; AMinimum: Integer): Integer;
    procedure ReadParameters;
    procedure LoadData;
    procedure RaisePriority;
    // Tokenizes the whole text once and returns the number of tokens, the final tkEOF not counted
    function RunPass: Int64;
    procedure ValidateData;
    procedure RunWarmupPasses;
    procedure RunMeasuredPasses;
    function FormatTime(ANanoseconds: Double): string;
    procedure PrintUsage;
    procedure PrintSummary;
  public
    constructor Create;
    destructor Destroy; override;

    // Runs the benchmark described by the command line; raises EBenchmarkError on failure
    procedure Execute;
  end;

implementation

{ EBenchmarkError }

constructor EBenchmarkError.Create(AExitCode: Integer; const AMessage: string);
begin
  inherited Create(AMessage);
  FExitCode := AExitCode;
end;

{ TLexerBenchmark }

constructor TLexerBenchmark.Create;
begin
  inherited Create;
  FFormatSettings := TFormatSettings.Invariant;
  FFileName := ExpandFileName(ExtractFilePath(ParamStr(0)) + DEFAULT_DATA_FILE);
  FIterations := DEFAULT_ITERATIONS;
  FWarmupCount := DEFAULT_WARMUP_COUNT;
  FStopwatch := THighResolutionStopwatch.Create;
  FLexer := TPasLexer.Create;
end;

destructor TLexerBenchmark.Destroy;
begin
  FreeAndNil(FLexer);
  FreeAndNil(FStopwatch);
  inherited Destroy;
end;

function TLexerBenchmark.ReadCount(const ASwitch, AValue: string; AMinimum: Integer): Integer;
begin
  if (not TryStrToInt(AValue, Result)) or (Result < AMinimum) then
    raise EBenchmarkError.Create(EXIT_CODE_INVALID_PARAMETER, Format(EMESSAGE_INVALID_COUNT, [AValue, ASwitch, AMinimum]));
end;

procedure TLexerBenchmark.ReadParameters;
var
  i, SeparatorPos: Integer;
  Parameter, Switch, Value: string;
  HasValue: Boolean;
begin
  i := 1;
  while i <= ParamCount do
  begin
    Parameter := ParamStr(i);
    if (Parameter = '') or (not CharInSet(Parameter[1], SWITCH_PREFIXES)) then
      raise EBenchmarkError.Create(EXIT_CODE_INVALID_PARAMETER, Format(EMESSAGE_UNKNOWN_SWITCH, [Parameter]));

    // The value is either appended after a colon or given as the next parameter
    Switch := Copy(Parameter, 2, MaxInt);
    SeparatorPos := Pos(SWITCH_VALUE_SEPARATOR, Switch);
    HasValue := SeparatorPos > 0;
    if HasValue then
    begin
      Value := Copy(Switch, SeparatorPos + 1, MaxInt);
      Switch := Copy(Switch, 1, SeparatorPos - 1);
    end;

    if SameText(Switch, SWITCH_HELP) or (Switch = SWITCH_HELP_SHORT) then
    begin
      FHelpRequested := True;
      Inc(i);
      Continue;
    end;
    if not (SameText(Switch, SWITCH_FILE) or SameText(Switch, SWITCH_ITERATIONS) or SameText(Switch, SWITCH_WARMUP)) then
      raise EBenchmarkError.Create(EXIT_CODE_INVALID_PARAMETER, Format(EMESSAGE_UNKNOWN_SWITCH, [Parameter]));

    if not HasValue then
    begin
      if i = ParamCount then
        raise EBenchmarkError.Create(EXIT_CODE_INVALID_PARAMETER, Format(EMESSAGE_MISSING_VALUE, [Parameter]));
      Inc(i);
      Value := ParamStr(i);
    end;

    if SameText(Switch, SWITCH_FILE) then
      FFileName := ExpandFileName(Value)
    else if SameText(Switch, SWITCH_ITERATIONS) then
      FIterations := ReadCount(Switch, Value, 1)
    else
      FWarmupCount := ReadCount(Switch, Value, 0);
    Inc(i);
  end; // while i <= ParamCount
end;

procedure TLexerBenchmark.LoadData;
var
  FileStream: TFileStream;
begin
  if not FileExists(FFileName) then
    raise EBenchmarkError.Create(EXIT_CODE_FILE_NOT_FOUND, Format(EMESSAGE_FILE_NOT_FOUND, [FFileName]));

  FileStream := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyNone);
  try
    FFileSize := FileStream.Size;
  finally
    FileStream.Free;
  end;

  FData := TPasParser.GetFileDataString(FFileName);
end;

procedure TLexerBenchmark.RaisePriority;
begin
  // Less preemption by other processes gives more stable timings; failure only lowers the stability
  FHighPriority := SetPriorityClass(GetCurrentProcess, HIGH_PRIORITY_CLASS);
end;

function TLexerBenchmark.RunPass: Int64;
begin
  FLexer.SetData(FData);
  // SetData already reads the first token
  Result := 0;
  if FLexer.TokenID <> tkEOF then
    Result := 1;
  while FLexer.NextToken do
    Inc(Result);
end;

procedure TLexerBenchmark.ValidateData;
var
  Counters: TPasLexerStateCounters;
begin
  // The same check as the first pass of TMeasureThread: the lexer must finish the text without errors
  try
    FTokenCount := RunPass;
  except
    on E: Exception do
      raise EBenchmarkError.Create(EXIT_CODE_LEXER_FAILURE,
          Format(EMESSAGE_LEXER_EXCEPTION, [FLexer.LexerState.CurrentLine, E.ClassName, E.Message]));
  end;

  if FTokenCount = 0 then
    raise EBenchmarkError.Create(EXIT_CODE_LEXER_FAILURE, Format(EMESSAGE_EMPTY_FILE, [FFileName]));

  Counters := FLexer.LexerState.Counters;
  if (Counters.RoundCount <> 0) or (Counters.SquareCount <> 0) or (Counters.IfDirectiveCount <> 0) then
    raise EBenchmarkError.Create(EXIT_CODE_LEXER_FAILURE,
        Format(EMESSAGE_UNBALANCED_COUNTERS, [Counters.RoundCount, Counters.SquareCount, Counters.IfDirectiveCount]));
end;

procedure TLexerBenchmark.RunWarmupPasses;
var
  i: Integer;
begin
  for i := 1 to FWarmupCount do
    RunPass;
end;

procedure TLexerBenchmark.RunMeasuredPasses;
var
  i: Integer;
  PassTokenCount: Int64;
begin
  SetLength(FPassTimes, FIterations);
  for i := 0 to FIterations - 1 do
  begin
    FStopwatch.Restart;
    PassTokenCount := RunPass;
    // ElapsedSeconds keeps full precision without the Integer range limit of ElapsedNanoseconds
    FPassTimes[i] := Round(FStopwatch.ElapsedSeconds * NANOSECONDS_PER_SECOND);

    if PassTokenCount <> FTokenCount then
      raise EBenchmarkError.Create(EXIT_CODE_LEXER_FAILURE,
          Format(EMESSAGE_TOKEN_COUNT_CHANGED, [i + 1, PassTokenCount, FTokenCount]));
  end;
  TArray.Sort<Int64>(FPassTimes);
end;

function TLexerBenchmark.FormatTime(ANanoseconds: Double): string;
begin
  Result := FormatFloat(NUMBER_FORMAT_TIME, ANanoseconds / NANOSECONDS_PER_MILLISECOND, FFormatSettings);
end;

procedure TLexerBenchmark.PrintUsage;
begin
  Writeln(TEXT_TITLE);
  Writeln(Format(TEXT_USAGE, [DEFAULT_ITERATIONS, DEFAULT_WARMUP_COUNT]));
end;

procedure TLexerBenchmark.PrintSummary;
var
  i, Middle: Integer;
  TotalTime: Int64;
  MedianTime, MeanTime, MedianSeconds: Double;
  PriorityText: string;
begin
  // FPassTimes is sorted: the median of an even count is the mean of the two middle values
  Middle := FIterations div 2;
  if Odd(FIterations) then
    MedianTime := FPassTimes[Middle]
  else
    MedianTime := (FPassTimes[Middle - 1] + FPassTimes[Middle]) / 2;
  TotalTime := 0;
  for i := 0 to FIterations - 1 do
    Inc(TotalTime, FPassTimes[i]);
  MeanTime := TotalTime / FIterations;
  MedianSeconds := MedianTime / NANOSECONDS_PER_SECOND;

  if FHighPriority then
    PriorityText := TEXT_PRIORITY_HIGH
  else
    PriorityText := TEXT_PRIORITY_NORMAL;

  Writeln(TEXT_TITLE);
  Writeln(Format(TEXT_BUILD, [BUILD_PLATFORM, BUILD_CONFIG]));
  Writeln(Format(TEXT_PRIORITY, [PriorityText]));
  Writeln(Format(TEXT_FILE, [FFileName]));
  Writeln(Format(TEXT_FILE_SIZE, [FFileSize]));
  Writeln(Format(TEXT_CHARACTERS, [Length(FData)]));
  Writeln(Format(TEXT_TOKENS, [FTokenCount]));
  Writeln(Format(TEXT_WARMUP, [FWarmupCount]));
  Writeln(Format(TEXT_ITERATIONS, [FIterations]));
  Writeln(Format(TEXT_MIN_TIME, [FormatTime(FPassTimes[0])]));
  Writeln(Format(TEXT_MEDIAN_TIME, [FormatTime(MedianTime)]));
  Writeln(Format(TEXT_MEAN_TIME, [FormatTime(MeanTime)]));
  Writeln(Format(TEXT_MAX_TIME, [FormatTime(FPassTimes[FIterations - 1])]));
  Writeln(Format(TEXT_MEDIAN_SPEED,
      [FormatFloat(NUMBER_FORMAT_SPEED, FFileSize / BYTES_PER_MEGABYTE / MedianSeconds, FFormatSettings)]));
  Writeln(Format(TEXT_MEDIAN_TOKEN_SPEED,
      [FormatFloat(NUMBER_FORMAT_SPEED, FTokenCount / TOKENS_PER_MILLION / MedianSeconds, FFormatSettings)]));
  Writeln(TEXT_RESULT_OK);
end;

procedure TLexerBenchmark.Execute;
begin
  ReadParameters;
  if FHelpRequested then
  begin
    PrintUsage;
    Exit;
  end;

  LoadData;
  RaisePriority;
  ValidateData;
  RunWarmupPasses;
  RunMeasuredPasses;
  PrintSummary;
end;

end.
