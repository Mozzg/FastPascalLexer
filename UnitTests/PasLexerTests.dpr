program PasLexerTests;
{
  Delphi DUnit Test Project
  -------------------------
  This is the single main unit test project for the FastPascalLexer repository.
  It registers and runs the complete test suite (TestuPasLexer,
  TestuPasLexerAdditional, TestuPasParser and TestuCodeStyleProfile) through
  the DUnit framework.

  Configurations:
  - Debug / Release build the visual DUnit GUI test runner window — the
    default way to run the tests interactively.
  - Console (based on Debug) defines "CONSOLE_TESTRUNNER", which enables the
    APPTYPE CONSOLE directive below, so the executable is a console
    application and DUnit prints text output — the automated (agent/CI) way
    to run the tests. The console runner halts with exit code
    Errors + Failures, so a nonzero exit code means a failing suite.
}

(*$IFDEF DEBUG
*)
{$ENDIF}

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  TextTestRunner,
  uPasLexer in '..\Source\uPasLexer.pas',
  uPasLexerTypes in '..\Source\uPasLexerTypes.pas',
  uPasParser in '..\Source\uPasParser.pas',
  TestuPasLexer in '..\Source\TestuPasLexer.pas',
  TestuPasLexerAdditional in '..\Source\TestuPasLexerAdditional.pas',
  TestuPasParser in '..\Source\TestuPasParser.pas',
  uPasExceptions in '..\Source\uPasExceptions.pas',
  uPasParserTypes in '..\Source\uPasParserTypes.pas',
  uPasParserGrammar in '..\Source\uPasParserGrammar.pas',
  uPasParserSettings in '..\Source\uPasParserSettings.pas',
  uPasLexerPerformance in '..\Source\uPasLexerPerformance.pas',
  uCodeStyleConsts in '..\Source\uCodeStyleConsts.pas',
  uCodeStyleProfileCatalog in '..\Source\uCodeStyleProfileCatalog.pas',
  uCodeStyleProfile in '..\Source\uCodeStyleProfile.pas',
  TestuCodeStyleProfile in '..\Source\TestuCodeStyleProfile.pas';

{$R *.RES}

begin
  {$IFDEF CONSOLE_TESTRUNNER}
  // Halts with exit code Errors + Failures when the suite fails
  TextTestRunner.RunRegisteredTests(rxbHaltOnFailures).Free;
  {$ELSE}
  DUnitTestRunner.RunRegisteredTests;
  {$ENDIF}
end.

