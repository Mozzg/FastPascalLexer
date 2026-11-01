@echo off
rem Builds the unit tests in the Console configuration and runs them.
rem Works from cmd, PowerShell and Git Bash; the current directory does not matter.
rem
rem Usage: test.cmd [Platform]
rem   Platform - Win32 or Win64 (default: Win32)
rem
rem Exit code: 0 - the build succeeded and all tests passed;
rem            nonzero - the build failed, or the number of test errors + failures.
setlocal

set "TEST_PLATFORM=%~1"
if "%TEST_PLATFORM%"=="" set "TEST_PLATFORM=Win32"

call "%~dp0build.cmd" UnitTests\PasLexerTests.dproj Console %TEST_PLATFORM%
if errorlevel 1 (
  echo test.cmd: the build failed, tests were not run.
  exit /b 1
)

"%~dp0Exe\PasLexerTests.exe"
exit /b %ERRORLEVEL%
