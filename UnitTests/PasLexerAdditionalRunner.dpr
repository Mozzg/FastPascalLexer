program PasLexerAdditionalRunner;
{
  Console helper that runs the TestuPasLexerAdditional test methods one by one
  without the DUnit runner. PasLexerTests is the main test project, this one is
  only meant for a quick check from the command line. DUnit is still needed for
  TTestCase, compile with the DUnit source folder in the unit search path:
    dcc32 -U"$(BDS)\Source\DUnit\src" PasLexerAdditionalRunner.dpr
}

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  uPasLexerTypes in '..\Source\uPasLexerTypes.pas',
  uPasLexer in '..\Source\uPasLexer.pas',
  uPasParserTypes in '..\Source\uPasParserTypes.pas',
  uPasParserGrammar in '..\Source\uPasParserGrammar.pas',
  uPasParser in '..\Source\uPasParser.pas',
  uPasExceptions in '..\Source\uPasExceptions.pas',
  TestuPasLexerAdditional in 'TestuPasLexerAdditional.pas';

var
  FailedCount: Integer = 0;

procedure RunTest(const TestName: string; ATest: TestTPasLexerAdditional; AMethod: TProc);
begin
  Writeln('--- Running: ', TestName);
  try
    ATest.SetUp;
    try
      AMethod();
      Writeln('+++ Passed: ', TestName);
    finally
      ATest.TearDown;
    end;
  except
    on E: Exception do
    begin
      Inc(FailedCount);
      Writeln('*** Failed: ', TestName, ' -> ', E.ClassName, ': ', E.Message);
    end;
  end;
end;

var
  TestObj: TestTPasLexerAdditional;
begin
  TestObj := TestTPasLexerAdditional.Create('TestTPasLexerAdditional');
  try
    RunTest('TestIdentifiersAndPunctuation', TestObj, procedure begin TestObj.TestIdentifiersAndPunctuation; end);
    RunTest('TestNumbers', TestObj, procedure begin TestObj.TestNumbers; end);
    RunTest('TestStrings', TestObj, procedure begin TestObj.TestStrings; end);
    RunTest('TestComments', TestObj, procedure begin TestObj.TestComments; end);
    RunTest('TestCompilerDirectivesAndCounters', TestObj, procedure begin TestObj.TestCompilerDirectivesAndCounters; end);
    RunTest('TestInitialLexerState', TestObj, procedure begin TestObj.TestInitialLexerState; end);
    RunTest('TestResetRestartsLexing', TestObj, procedure begin TestObj.TestResetRestartsLexing; end);
    RunTest('TestWhitespaceHandling', TestObj, procedure begin TestObj.TestWhitespaceHandling; end);
    RunTest('TestLineTracking', TestObj, procedure begin TestObj.TestLineTracking; end);
    RunTest('TestOperators', TestObj, procedure begin TestObj.TestOperators; end);
    RunTest('TestSymbolAndUnknownChars', TestObj, procedure begin TestObj.TestSymbolAndUnknownChars; end);
    RunTest('TestAsciiCharAndHexNumbers', TestObj, procedure begin TestObj.TestAsciiCharAndHexNumbers; end);
    RunTest('TestNumberEdgeCases', TestObj, procedure begin TestObj.TestNumberEdgeCases; end);
    RunTest('TestStringEdgeCases', TestObj, procedure begin TestObj.TestStringEdgeCases; end);
    RunTest('TestSingleLineComments', TestObj, procedure begin TestObj.TestSingleLineComments; end);
    RunTest('TestMultiLineCurlyComment', TestObj, procedure begin TestObj.TestMultiLineCurlyComment; end);
    RunTest('TestMultiLineStarParenComment', TestObj, procedure begin TestObj.TestMultiLineStarParenComment; end);
    RunTest('TestStarParenCompilerDirective', TestObj, procedure begin TestObj.TestStarParenCompilerDirective; end);
    RunTest('TestUnterminatedComments', TestObj, procedure begin TestObj.TestUnterminatedComments; end);
    RunTest('TestCommentForeignTerminators', TestObj, procedure begin TestObj.TestCommentForeignTerminators; end);
    RunTest('TestAllKeywords', TestObj, procedure begin TestObj.TestAllKeywords; end);
    RunTest('TestIdentifierEdgeCases', TestObj, procedure begin TestObj.TestIdentifierEdgeCases; end);
    RunTest('TestNonAsciiIdentifiers', TestObj, procedure begin TestObj.TestNonAsciiIdentifiers; end);
    RunTest('TestPropertyDirectives', TestObj, procedure begin TestObj.TestPropertyDirectives; end);
    RunTest('TestEndAndUnitEnd', TestObj, procedure begin TestObj.TestEndAndUnitEnd; end);
    RunTest('TestBracketCounters', TestObj, procedure begin TestObj.TestBracketCounters; end);
    RunTest('TestMultiLineCompilerDirective', TestObj, procedure begin TestObj.TestMultiLineCompilerDirective; end);
    RunTest('TestConditionalDirectiveKinds', TestObj, procedure begin TestObj.TestConditionalDirectiveKinds; end);
    RunTest('TestElseIfDirectiveChain', TestObj, procedure begin TestObj.TestElseIfDirectiveChain; end);
    RunTest('TestDirectiveErrorUnexpectedElse', TestObj, procedure begin TestObj.TestDirectiveErrorUnexpectedElse; end);
    RunTest('TestDirectiveErrorCountersMismatch', TestObj, procedure begin TestObj.TestDirectiveErrorCountersMismatch; end);
    RunTest('TestDirectiveErrorStateMismatch', TestObj, procedure begin TestObj.TestDirectiveErrorStateMismatch; end);
    RunTest('TestIgnoreCompilerDirectiveChecks', TestObj, procedure begin TestObj.TestIgnoreCompilerDirectiveChecks; end);
    RunTest('TestLastSignificantToken', TestObj, procedure begin TestObj.TestLastSignificantToken; end);
    RunTest('TestLexerStateSaveRestore', TestObj, procedure begin TestObj.TestLexerStateSaveRestore; end);
    RunTest('TestNextTokenNoJunk', TestObj, procedure begin TestObj.TestNextTokenNoJunk; end);
    RunTest('TestNextTokenWithKind', TestObj, procedure begin TestObj.TestNextTokenWithKind; end);
    RunTest('TestNextTokenNoDirectiveBranching', TestObj, procedure begin TestObj.TestNextTokenNoDirectiveBranching; end);
  finally
    TestObj.Free;
  end;

  Writeln;
  if FailedCount = 0 then
    Writeln('All tests passed')
  else
  begin
    Writeln(FailedCount, ' test(s) failed');
    ExitCode := 1;
  end;
end.
