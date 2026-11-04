@echo off
REM moving %1 so the DLL can be compiled even though it is currently loaded in the IDE
REM (quoted: the repository path may contain spaces)
if exist "%~1" move /y "%~1" "%~1~" >nul
exit /b 0

REM Thanks to dummzeuch for providing this amazing batch file for developing RAD Studio dll experts
