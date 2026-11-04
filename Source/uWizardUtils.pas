// Copy of Delphi-IDE-Code-Expert (DICE) Source/uWizardUtils.pas, commit 5c8be6b, without changes: the CodeStyle feature
// is built on its API. Not moved to DICE with the CodeStyle feature.
unit uWizardUtils;

interface

uses
  System.SysUtils, ToolsAPI, Winapi.Windows, Vcl.Graphics;

type
  TDICEVersionInfo = record
    FMajor: Cardinal;
    FMinor: Cardinal;
    FBugFix: Cardinal;
    FBuild: Cardinal;
  end;

function GetModuleFileNameCustom: string;
function GetFileVersionCustom(const AFileName: string): Int64; overload;
function GetFileVersionCustom(const AFileName: string; out AResult: TDICEVersionInfo): Boolean; overload;
function GetVersionRevision(ABugFixVersion: Cardinal): string; inline;
function LoadMenuBitmap(const AResName: string): Vcl.Graphics.TBitmap;

implementation

{ }

function GetModuleFileNameCustom: string;
var
  Size: Integer;
begin
  SetLength(Result, MAX_PATH);
  Size := GetModuleFileName(HInstance, PWideChar(Result), MAX_PATH);
  SetLength(Result, Size);
end;

function GetFileVersionCustom(const AFileName: string): Int64;
const
  HIWORD_MASK = $FFFF0000;
  LOWORD_MASK = $FFFF;
var
  FileName: string;
  InfoSize, Wnd: DWORD;
  VerBuf: Pointer;
  FI: PVSFixedFileInfo;
  VerSize: DWORD;
begin
  // This version is copied from SysUtils and slightly modified
  Result := -1;
  // GetFileVersionInfo modifies the filename parameter data while parsing.
  // Copy the string const into a local variable to create a writeable copy.
  FileName := AFileName;
  UniqueString(FileName);
  InfoSize := GetFileVersionInfoSize(PChar(FileName), Wnd);
  if InfoSize <> 0 then
  begin
    GetMem(VerBuf, InfoSize);
    try
      if GetFileVersionInfo(PChar(FileName), Wnd, InfoSize, VerBuf) then
        if VerQueryValue(VerBuf, '\', Pointer(FI), VerSize) then
          Result := ((Int64(FI^.dwFileVersionMS) and HIWORD_MASK) shl 32) or ((Int64(FI^.dwFileVersionMS) and LOWORD_MASK) shl 32)
              or (Int64(FI^.dwFileVersionLS) and HIWORD_MASK) or (Int64(FI^.dwFileVersionLS) and LOWORD_MASK);
    finally
      FreeMem(VerBuf);
    end;
  end;
end;

function GetFileVersionCustom(const AFileName: string; out AResult: TDICEVersionInfo): Boolean;
var
  FileVersion: Int64;
begin
  Result := False;
  FileVersion := GetFileVersionCustom(AFileName);
  if FileVersion <> -1 then
  begin
    AResult.FMajor := (FileVersion and $FFFF000000000000) shr 48;
    AResult.FMinor := (FileVersion and $FFFF00000000) shr 32;
    AResult.FBugFix := (FileVersion and $FFFF0000) shr 16;
    AResult.FBuild := FileVersion and $FFFF;
    Result := True;
  end;
end;

function GetVersionRevision(ABugFixVersion: Cardinal): string;
const
  REVISIONS_CHARS = ' abcdefghijklmnopqrstuvwxyz';
begin
  if ABugFixVersion = 0 then
    Result := EmptyStr
  else
    Result := Copy(REVISIONS_CHARS, ABugFixVersion + 1, 1);
end;

function LoadMenuBitmap(const AResName: string): Vcl.Graphics.TBitmap;
var
  x, y: Integer;
  P: PRGBQuad;
begin
  Result := nil;
  try
    Result := Vcl.Graphics.TBitmap.Create;
    Result.LoadFromResourceName(HInstance, AResName);
    Result.PixelFormat := pf32bit;  // alpha byte is 0 after conversion

    for y := 0 to Result.Height - 1 do
    begin
      P := Result.ScanLine[y];
      for x := 0 to Result.Width - 1 do
      begin
        // Background is pure white, die faces are FEFEFE
        if (P^.rgbRed = $FF) and (P^.rgbGreen = $FF) and (P^.rgbBlue = $FF) then
          P^.rgbReserved := 0
        else
          P^.rgbReserved := $FF;
        Inc(P);
      end;
    end;

    Result.AlphaFormat := afDefined;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

end.
