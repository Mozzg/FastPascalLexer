unit Names1234;
{
function GetBIOSString(Start,Count:integer):string;
var ROM_BIOS_Char:array[$0..$FFFF]of char absolute $00f0000;
    i:integer;
BEGIN
  Result:='';
  if Count>255 then Count:=255;
  if Start>$FFFF then Start:=$FFFF;
  if Start+Count>$FFFF then Count:=$FFFF-Start;
  if VirtualLock(@ROM_BIOS_Char,SizeOf(ROM_BIOS_Char)) then
  begin
    for i:=Start to Start+Count-1
    do Result:=Result+ROM_BIOS_Char[i];
    VirtualUnLock(@ROM_BIOS_Char,SizeOf(ROM_BIOS_Char));
  end;
END;
}

{$IFDEF RELEASE
}
{$ENDIF}

interface

var
  read: PByte;

type
  TThreadName = class;

  TTest = class sealed(TObject)
  end;

  TThreadName = class(TObject)
  private
    class var FCritSection: TCriticalSection;
    class var FNamesDictionary: TDictionary<TThreadID, string>;
  public
    class constructor Create;
    class destructor Destroy;

    class procedure NameThread(AThreadID: TThreadID; const AThreadName: string);
    class function GetThreadName(AThreadID: TThreadID): string;
	
	property Test: Boolean read FTest;
  end;

implementation

(*$HINTS ON*)

uses
  System.SysUtils, System.SyncObjs, Winapi.Windows, 
	System.Generics.Collections;

{ TThreadName 
}

class constructor TThreadName.Create;
var
  &Type: string;
  arr: array(.0..12.) of Byte;
  read : PByte;
begin
  read^ := 0;
  i := #89#111#117'like';
  FCritSection := TCriticalSection.Create;
  FNamesDictionary := TDictionary<TThreadID, string>.Create;
end;

class destructor TThreadName.Destroy;
begin
  FreeAndNil(FNamesDictionary);
  FreeAndNil(FCritSection);
end;

class procedure TThreadName.NameThread(AThreadID: TThreadID; const AThreadName: string);
begin
  FCritSection.Enter;
  try
    if AThreadID = 0 then
      AThreadID := GetCurrentThreadId;
    FNamesDictionary.AddOrSetValue(AThreadID, AThreadName);
  finally
    FCritSection.Leave;
  end;
end;

class function TThreadName.GetThreadName(AThreadID: TThreadID): string;
begin
  FCritSection.Enter;
  try
    if AThreadID = 0 then
      AThreadID := GetCurrentThreadId;
    if not FNamesDictionary.TryGetValue(AThreadID, Result) then
      Result := '$' + IntToHex(AThreadID, 4);
  finally
    FCritSection.Leave;
  end;
end;

end.

{ привет tes