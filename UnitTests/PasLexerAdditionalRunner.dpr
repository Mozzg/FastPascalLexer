program PasLexerAdditionalRunner;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  TestuPasLexerAdditional;

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
      Writeln('*** Failed: ', TestName, ' -> ', E.ClassName, ': ', E.Message);
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
  finally
    TestObj.Free;
  end;
end.
