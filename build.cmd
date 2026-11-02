@echo off
rem Builds a Delphi project of this repository with MSBuild.
rem Works from cmd, PowerShell and Git Bash; the current directory does not matter.
rem
rem Usage: build.cmd [Project] [Config] [Platform] [map]
rem   Project  - .dproj or .groupproj path relative to the repository root, "\" or "/" separated
rem              (default: PascalLexerGroup.groupproj)
rem   Config   - Debug, Release or Console (Console exists only in UnitTests\PasLexerTests.dproj;
rem              default: Debug)
rem   Platform - Win32 or Win64 (default: Win32)
rem   map      - also write a detailed map file (.map) next to the executable, for example to check
rem              the code layout of LexerBenchmark; the .dproj files are not changed
rem
rem Environment overrides for other machines:
rem   DELPHI_RSVARS - full path to rsvars.bat of Delphi 11 Alexandria
rem   MSBUILD_EXE   - full path to the .NET Framework 4.0 MSBuild.exe
rem
rem Exit code: 0 - build succeeded, nonzero - build failed.
setlocal

set "REPO_ROOT=%~dp0"
set "BUILD_PROJECT=%~1"
if "%BUILD_PROJECT%"=="" set "BUILD_PROJECT=PascalLexerGroup.groupproj"
rem Accept forward slashes, which are easier to pass from Git Bash
set "BUILD_PROJECT=%BUILD_PROJECT:/=\%"
set "BUILD_CONFIG=%~2"
if "%BUILD_CONFIG%"=="" set "BUILD_CONFIG=Debug"
set "BUILD_PLATFORM=%~3"
if "%BUILD_PLATFORM%"=="" set "BUILD_PLATFORM=Win32"
set "BUILD_MAP=%~4"
set "BUILD_OPTIONS="
set "BUILD_MAP_TEXT="
if /i "%BUILD_MAP%"=="map" (
  set "BUILD_OPTIONS=/p:DCC_MapFile=3"
  set "BUILD_MAP_TEXT= MapFile=detailed"
) else if not "%BUILD_MAP%"=="" (
  echo build.cmd: unknown parameter "%BUILD_MAP%", expected "map".
  exit /b 1
)

if not defined DELPHI_RSVARS set "DELPHI_RSVARS=C:\Program Files (x86)\Embarcadero\Studio\22.0\bin\rsvars.bat"
if not defined MSBUILD_EXE set "MSBUILD_EXE=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe"

if not exist "%DELPHI_RSVARS%" (
  echo build.cmd: rsvars.bat was not found: "%DELPHI_RSVARS%". Set DELPHI_RSVARS.
  exit /b 1
)
if not exist "%MSBUILD_EXE%" (
  echo build.cmd: MSBuild.exe was not found: "%MSBUILD_EXE%". Set MSBUILD_EXE.
  exit /b 1
)
if not exist "%REPO_ROOT%%BUILD_PROJECT%" (
  echo build.cmd: project was not found: "%REPO_ROOT%%BUILD_PROJECT%".
  exit /b 1
)

call "%DELPHI_RSVARS%" >nul 2>&1
set "PATH=%BDS%\bin;%PATH%"

echo build.cmd: %BUILD_PROJECT% Config=%BUILD_CONFIG% Platform=%BUILD_PLATFORM%%BUILD_MAP_TEXT%
"%MSBUILD_EXE%" "%REPO_ROOT%%BUILD_PROJECT%" /t:Build /p:Config=%BUILD_CONFIG% /p:Platform=%BUILD_PLATFORM% %BUILD_OPTIONS% /v:minimal /nologo
exit /b %ERRORLEVEL%
