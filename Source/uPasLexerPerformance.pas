(*******************************************************************************
*  Copyright © 2025 Pervov Evgeny                                              *
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
*  Created: 10.05.2025                                                         *
*  Classes: THighResolutionStopwatch, TMeasureThread                           *
*  Description: Classes for measuring performance of TPasLexer                 *
*  Version: 0.2                                                                *
*  Last modified: 01.11.2026                                                   *
*  Contributor(s):                                                             *
*    Pervov Evgeny <operationm@list.ru>                                        *
*******************************************************************************)

unit uPasLexerPerformance;

interface

uses
  System.Classes, System.SysUtils, System.SyncObjs, Winapi.Windows, Winapi.MMSystem, System.Math,
  uPasLexer, uPasLexerTypes, uPasParser, uPasExceptions;

type
  TUpdateElapsedProc = procedure(AAverageElapsed, ACycleCount: Int64) of object;

  TElapsedMagnitude = (
    emMili,
    emMicro,
    emNano
  );

  // Custom High resolution stopwatch
  THighResolutionStopwatch = class(TObject)
  strict private
    FTicksPerSecond: Int64;
    FInverseTicksPerMilisecond: Double;
    FInverseTicksPerMicrosecond: Double;
    FInverseTicksPerNanosecond: Double;
  private
    class var fPrecisionTimerInitialized: Boolean;
    class procedure InitPrecisionTimer;
  private const
    PRECISION_TIMER_MINIMUM_RESOLUTION = 1;
  protected
    fStartTicks: Int64;
    fCurrentTicks: Int64;
    procedure InternalUpdateCurrentTicks;
    // Elapsed
    function GetElapsedTicks: Int64;
    function GetElapsedSeconds: Double;
    function GetElapsedMiliseconds: Int64;
    function GetElapsedMicroseconds: Int64;
    function GetElapsedNanoseconds: Int64;
    // Current
    function GetCurrentTicks: Int64;
    function GetCurrentSeconds: Double;
  public
    constructor Create;
    // Start ticks becomes 0, changing elapsed properties from system start
    procedure ResetToSystemStart;
    // Returns elapsed ticks
    function Restart: Int64;

    // Precision sleep. Parameter is how many 100 nanosecond intervals to sleep.
    class procedure SleepPrecise(const A100NanosecondIntervalsCount: Int64);

    // Elapsed
    property ElapsedTicks: Int64 read GetElapsedTicks;
    property ElapsedSeconds: Double read GetElapsedSeconds;
    property ElapsedMiliseconds: Int64 read GetElapsedMiliseconds;
    property ElapsedMicroseconds: Int64 read GetElapsedMicroseconds;
    property ElapsedNanoseconds: Int64 read GetElapsedNanoseconds;
    // Current
    property CurrentTicks: Int64 read GetCurrentTicks;
    property CurrentSeconds: Double read GetCurrentSeconds;
  end;

  TMeasureThread = class(TThread)
  private
    FAverageElapsedNano: Int64;
    FMeasureCount: Int64;
    FParseFileName: string;
    FMagnitude: TElapsedMagnitude;
    FStopwatch: THighResolutionStopwatch;
    FUnpauseEvent: TEvent;
    FReadyForMeasureEvent: TEvent;
    FLexer: TPasLexer;
    FWasParseError: Boolean;

    FOnUpdateElapsed: TUpdateElapsedProc;
  protected
    procedure Execute; override;
    procedure TerminatedSet; override;
  public
    constructor Create(const AParseFileName: string; AMagnitude: TElapsedMagnitude = emMicro);
    destructor Destroy; override;

    procedure StartMeasure;
    procedure StopMeasure;

    property OnUpdateElapsed: TUpdateElapsedProc read FOnUpdateElapsed write FOnUpdateElapsed;
  end;

implementation

const
  MILLISECONDS_IN_SECOND = 1000;
  MICROSECONDS_IN_SECOND = 1000000;
  NANOSECONDS_IN_SECOND = 1000000000;

var
  TimeDeviceCaps: TTimeCaps;
  TimePrecisionChanged: Boolean;
  WaitableTimerHandle: Winapi.Windows.THandle;

{ THighResolutionStopwatch }

constructor THighResolutionStopwatch.Create;
begin
  inherited Create;
  if (not QueryPerformanceFrequency(FTicksPerSecond)) or (not QueryPerformanceCounter(fCurrentTicks)) then
    raise Exception.CreateFmt(EMESSAGE_TIMER_NOT_AVAILABLE, [ClassName]);
  fStartTicks := fCurrentTicks;
  FInverseTicksPerMilisecond := MILLISECONDS_IN_SECOND / FTicksPerSecond;
  FInverseTicksPerMicrosecond := MICROSECONDS_IN_SECOND / FTicksPerSecond;
  FInverseTicksPerNanosecond := NANOSECONDS_IN_SECOND / FTicksPerSecond;
end;

class procedure THighResolutionStopwatch.InitPrecisionTimer;
begin
  WaitableTimerHandle := CreateWaitableTimer(nil, False, nil);
  if WaitableTimerHandle = 0 then
    Exit;
  if timeGetDevCaps(@TimeDeviceCaps, SizeOf(TTimeCaps)) = MMSYSERR_NOERROR then
    if TimeDeviceCaps.wPeriodMin <> PRECISION_TIMER_MINIMUM_RESOLUTION then
      if timeBeginPeriod(PRECISION_TIMER_MINIMUM_RESOLUTION) = MMSYSERR_NOERROR then
        TimePrecisionChanged := True;
  THighResolutionStopwatch.fPrecisionTimerInitialized := True;
end;

procedure THighResolutionStopwatch.InternalUpdateCurrentTicks;
begin
  QueryPerformanceCounter(fCurrentTicks);
end;

function THighResolutionStopwatch.GetElapsedTicks: Int64;
begin
  InternalUpdateCurrentTicks;
  Result := fCurrentTicks - fStartTicks;
end;

function THighResolutionStopwatch.GetElapsedSeconds: Double;
begin
  Result := GetElapsedTicks / FTicksPerSecond;
end;

function THighResolutionStopwatch.GetElapsedMiliseconds: Int64;
begin
  Result := Floor(GetElapsedTicks * FInverseTicksPerMilisecond);
end;

function THighResolutionStopwatch.GetElapsedMicroseconds: Int64;
begin
  Result := Floor(GetElapsedTicks * FInverseTicksPerMicrosecond);
end;

function THighResolutionStopwatch.GetElapsedNanoseconds: Int64;
begin
  Result := Floor(GetElapsedTicks * FInverseTicksPerNanosecond);
end;

function THighResolutionStopwatch.GetCurrentTicks: Int64;
begin
  InternalUpdateCurrentTicks;
  Result := fCurrentTicks;
end;

function THighResolutionStopwatch.GetCurrentSeconds: Double;
begin
  Result := GetCurrentTicks / FTicksPerSecond;
end;

procedure THighResolutionStopwatch.ResetToSystemStart;
begin
  fStartTicks := 0;
end;

function THighResolutionStopwatch.Restart: Int64;
begin
  InternalUpdateCurrentTicks;
  Result := fCurrentTicks - fStartTicks;
  fStartTicks := fCurrentTicks;
end;

class procedure THighResolutionStopwatch.SleepPrecise(const A100NanosecondIntervalsCount: Int64);
var
  lWaitInterval100ns: Int64;
begin
  if not THighResolutionStopwatch.fPrecisionTimerInitialized then
    raise Exception.Create(EMESSAGE_TIMER_NOT_INITIALIZED);
  lWaitInterval100ns := A100NanosecondIntervalsCount * -1;
  if SetWaitableTimer(WaitableTimerHandle, lWaitInterval100ns, 0, nil, nil, False) then
    if WaitForSingleObject(WaitableTimerHandle, INFINITE) = WAIT_FAILED then
      raise Exception.Create(EMESSAGE_TIMER_WAIT_FAILED);
end;

{ TMeasureThread }

constructor TMeasureThread.Create(const AParseFileName: string; AMagnitude: TElapsedMagnitude = emMicro);
begin
  FParseFileName := AParseFileName;
  FMagnitude := AMagnitude;
  FWasParseError := False;

  FStopwatch := THighResolutionStopwatch.Create;
  FUnpauseEvent := TEvent.Create(nil, True, False, '');
  FReadyForMeasureEvent := TEvent.Create(nil, True, False, '');
  FLexer := TPasLexer.Create;

  inherited Create(False);
end;

destructor TMeasureThread.Destroy;
begin
  inherited Destroy;

  FreeAndNil(FStopwatch);
  FreeAndNil(FReadyForMeasureEvent);
  FreeAndNil(FUnpauseEvent);
  FreeAndNil(FLexer);
end;

procedure TMeasureThread.Execute;
var
  ParseFileContents, CurrentToken: string;
  CurrentElapsedNano, AverageConverted: Int64;
begin
  ParseFileContents := TPasParser.GetFileDataString(FParseFileName);
  FLexer.SetData(ParseFileContents);

  // Check for first full successful parse
  try
    while FLexer.TokenID <> tkEOF do
    begin
      CurrentToken := FLexer.TokenString;
      FLexer.NextToken;
    end;

    if (FLexer.LexerState.Counters.RoundCount <> 0) or (FLexer.LexerState.Counters.SquareCount <> 0)
        or (FLexer.LexerState.Counters.IfDirectiveCount <> 0)
    then
      FWasParseError := True;
  except
    FWasParseError := True;
  end;

  FReadyForMeasureEvent.SetEvent;

  while not Terminated do
  begin
    FUnpauseEvent.WaitFor(INFINITE);

    if Terminated then
      Break;

    FStopwatch.Restart;
    FLexer.Reset;
    while FLexer.TokenID <> tkEOF do
    begin
      CurrentToken := FLexer.TokenString;
      FLexer.NextToken;
    end;
    CurrentElapsedNano := FStopwatch.ElapsedNanoseconds;

    FAverageElapsedNano := (FAverageElapsedNano * FMeasureCount + CurrentElapsedNano) div (FMeasureCount + 1);
    Inc(FMeasureCount);

    if Assigned(FOnUpdateElapsed) and ((FMeasureCount mod 100) = 0) then
    begin
      if FMagnitude = emNano then
        FOnUpdateElapsed(FAverageElapsedNano, FMeasureCount)
      else
      begin
        case FMagnitude of
          emMili: AverageConverted := FAverageElapsedNano div 1000000;
          emMicro: AverageConverted := FAverageElapsedNano div 1000;
        else
          AverageConverted := 0;
        end;
        FOnUpdateElapsed(AverageConverted, FMeasureCount);
      end;
    end;
  end;
end;

procedure TMeasureThread.TerminatedSet;
begin
  inherited TerminatedSet;

  if Assigned(FUnpauseEvent) then
    FUnpauseEvent.SetEvent;
end;

procedure TMeasureThread.StartMeasure;
var
  WaitResult: TWaitResult;
begin
  WaitResult := FReadyForMeasureEvent.WaitFor(10000);

  if WaitResult in [wrTimeout, wrAbandoned, wrError] then
    raise Exception.Create('Failed to wait for first parse completion or wait error');

  if FWasParseError then
    raise Exception.Create('First parse failed');

  FUnpauseEvent.SetEvent;
end;

procedure TMeasureThread.StopMeasure;
begin
  FUnpauseEvent.ResetEvent;
end;

initialization
  // Initializing variables for precision sleep
  WaitableTimerHandle := 0;
  TimePrecisionChanged := False;
  // Initializing precision timer
  THighResolutionStopwatch.fPrecisionTimerInitialized := False;
  THighResolutionStopwatch.InitPrecisionTimer;

finalization
  // Restoring and cleaning
  if TimePrecisionChanged then
    timeEndPeriod(THighResolutionStopwatch.PRECISION_TIMER_MINIMUM_RESOLUTION);
  if WaitableTimerHandle <> 0 then
    CloseHandle(WaitableTimerHandle);

end.
