// Console benchmark of TPasLexer tokenization speed, run "LexerBenchmark.exe -help" for the parameters
program LexerBenchmark;

{$APPTYPE CONSOLE}

uses
  FastMM5 in '..\Source\ThirdParty\FastMM5\FastMM5.pas',
  System.SysUtils,
  uPasLexer in '..\Source\uPasLexer.pas',
  uPasLexerTypes in '..\Source\uPasLexerTypes.pas',
  uPasParser in '..\Source\uPasParser.pas',
  uPasLexerPerformance in '..\Source\uPasLexerPerformance.pas',
  uPasExceptions in '..\Source\uPasExceptions.pas',
  uPasParserTypes in '..\Source\uPasParserTypes.pas',
  uPasParserGrammar in '..\Source\uPasParserGrammar.pas',
  uPasParserSettings in '..\Source\uPasParserSettings.pas',
  uLexerBenchmarkConsts in 'uLexerBenchmarkConsts.pas',
  uLexerBenchmark in 'uLexerBenchmark.pas';

{$R *.res}

var
  Benchmark: TLexerBenchmark;
begin
  try
    Benchmark := TLexerBenchmark.Create;
    try
      Benchmark.Execute;
    finally
      Benchmark.Free;
    end;
    ExitCode := EXIT_CODE_SUCCESS;
  except
    on E: EBenchmarkError do
    begin
      ExitCode := E.ExitCode;
      Writeln(ErrOutput, Format(TEXT_ERROR, [E.Message]));
      Writeln(Format(TEXT_RESULT_FAILED, [ExitCode]));
    end;
    on E: Exception do
    begin
      ExitCode := EXIT_CODE_UNEXPECTED_ERROR;
      Writeln(ErrOutput, Format(TEXT_UNEXPECTED_ERROR, [E.ClassName, E.Message]));
      Writeln(Format(TEXT_RESULT_FAILED, [ExitCode]));
    end;
  end;
end.
