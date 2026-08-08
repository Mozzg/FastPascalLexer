unit cuSystem;

interface

uses
  Winapi.Windows, System.SysUtils, System.Math, Winapi.MMSystem, System.Classes,
  cuConsts;

type
  // Custom High resolution timer
  THighResolutionStopwatch = class(TObject)
  strict private
    fTicksPerSecond: Int64;
    fInverseTicksPerMilisecond: Double;
    fInverseTicksPerMicrosecond: Double;
    fInverseTicksPerNanosecond: Double;
  private
    // +++ подумать насчет помещения хендла CreateWaitableTimer в TThreadList для потоков, который не унаследованы
    // от нашего. Переместить работу с SleepPrecise в cuThreads. Или возможно сделать подобие TThreadList, чтобы можно
    // было найти нужный элемент.
    class var fPrecisionTimerInitialized: Boolean;
    class procedure InitPrecisionTimer;
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
    class procedure SleepPrecise(const a100NanosecIntervalsCount: Int64);

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

implementation

var
  ulTimeDeviceCaps: TTimeCaps;
  ulTimePrecisionChanged: Boolean;
  ulWaitableTimerHandle: Winapi.Windows.THandle;

{ THighResolutionTimer }

constructor THighResolutionStopwatch.Create;
begin
  inherited Create;
  if (not QueryPerformanceFrequency(fTicksPerSecond)) or (not QueryPerformanceCounter(fCurrentTicks)) then
    raise Exception.CreateFmt(EXCEPTION_MESSAGE_TIMER_NOT_AVAILABLE, [ClassName]);
  fStartTicks := fCurrentTicks;
  fInverseTicksPerMilisecond := 1000 / fTicksPerSecond;
  fInverseTicksPerMicrosecond := 1000000 / fTicksPerSecond;
  fInverseTicksPerNanosecond := 1000000000 / fTicksPerSecond;
end;

class procedure THighResolutionStopwatch.InitPrecisionTimer;
begin
  ulWaitableTimerHandle := CreateWaitableTimer(nil, False, nil);
  if ulWaitableTimerHandle = 0 then
    Exit;
  if timeGetDevCaps(@ulTimeDeviceCaps, SizeOf(TTimeCaps)) = MMSYSERR_NOERROR then
    if ulTimeDeviceCaps.wPeriodMin <> PRECISION_TIMER_MINIMUM_RESOLUTION then
      if timeBeginPeriod(PRECISION_TIMER_MINIMUM_RESOLUTION) = MMSYSERR_NOERROR then
        ulTimePrecisionChanged := True;
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
  Result := GetElapsedTicks / fTicksPerSecond;
end;

function THighResolutionStopwatch.GetElapsedMiliseconds: Int64;
begin
  Result := Floor(GetElapsedTicks * fInverseTicksPerMilisecond);
end;

function THighResolutionStopwatch.GetElapsedMicroseconds: Int64;
begin
  Result := Floor(GetElapsedTicks * fInverseTicksPerMicrosecond);
end;

function THighResolutionStopwatch.GetElapsedNanoseconds: Int64;
begin
  // +++ проверить, что правильно считает, что-то было минусовое значение
  Result := Floor(GetElapsedTicks * fInverseTicksPerNanosecond);
end;

function THighResolutionStopwatch.GetCurrentTicks: Int64;
begin
  InternalUpdateCurrentTicks;
  Result := fCurrentTicks;
end;

function THighResolutionStopwatch.GetCurrentSeconds: Double;
begin
  Result := GetCurrentTicks / fTicksPerSecond;
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

class procedure THighResolutionStopwatch.SleepPrecise(const a100NanosecIntervalsCount: Int64);
 var
  lWaitInterval100ns: Int64;
begin
  if not THighResolutionStopwatch.fPrecisionTimerInitialized then
    raise Exception.Create(EXCEPTION_MESSAGE_TIMER_NOT_INITIALIZED);
  lWaitInterval100ns := a100NanosecIntervalsCount * -1;
  if SetWaitableTimer(ulWaitableTimerHandle, lWaitInterval100ns, 0, nil, nil, False) then
    if WaitForSingleObject(ulWaitableTimerHandle, INFINITE) = WAIT_FAILED then
      raise Exception.Create(EXCEPTION_MESSAGE_TIMER_WAIT_FAILED);
end;

initialization
  // Initializing variables for precision sleep
  ulWaitableTimerHandle := 0;
  ulTimePrecisionChanged := False;
  // Initializing precision timer
  THighResolutionStopwatch.fPrecisionTimerInitialized := False;
  THighResolutionStopwatch.InitPrecisionTimer;

finalization
  // Restoring and cleaning
  if ulTimePrecisionChanged then
    timeEndPeriod(PRECISION_TIMER_MINIMUM_RESOLUTION);
  if ulWaitableTimerHandle <> 0 then
    CloseHandle(ulWaitableTimerHandle);
end.
