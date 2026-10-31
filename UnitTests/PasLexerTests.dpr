program PasLexerTests;
{
  Delphi DUnit Test Project
  -------------------------
  This is the single main unit test project for the FastPascalLexer repository.
  It registers and runs the complete test suite (TestuPasLexer plus
  TestuPasLexerAdditional) through the DUnit framework.

  Configurations:
  - Debug / Release build the visual DUnit GUI test runner window — the
    default way to run the tests interactively.
  - Console (based on Debug) defines "CONSOLE_TESTRUNNER", which enables the
    APPTYPE CONSOLE directive below, so the executable is a console
    application and DUnit prints text output — the automated (agent/CI) way
    to run the tests.
}

(*$IFDEF DEBUG
*)
{$ENDIF}

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  uPasLexer in '..\Source\uPasLexer.pas',
  uPasLexerTypes in '..\Source\uPasLexerTypes.pas',
  uPasParser in '..\Source\uPasParser.pas',
  TestuPasLexer in 'TestuPasLexer.pas',
  TestuPasLexerAdditional in 'TestuPasLexerAdditional.pas',
  uPasExceptions in '..\Source\uPasExceptions.pas',
  uPasParserTypes in '..\Source\uPasParserTypes.pas',
  uPasParserGrammar in '..\Source\uPasParserGrammar.pas';

{$R *.RES}

begin
  DUnitTestRunner.RunRegisteredTests;
end.

