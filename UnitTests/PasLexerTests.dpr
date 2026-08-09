program PasLexerTests;
{
  Delphi DUnit Test Project
  -------------------------
  This is the single main unit test project for the FastPascalLexer repository.
  It registers and runs the complete test suite (TestuPasLexer plus
  TestuPasLexerAdditional) through the DUnit framework.
  Add "CONSOLE_TESTRUNNER" to the conditional defines entry in the project
  options to use the console test runner.  Otherwise the GUI test runner will
  be used by default.
}

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

