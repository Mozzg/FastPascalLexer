program TestApp;

uses
  FastMM5 in '..\Source\ThirdParty\FastMM5\FastMM5.pas',
  Vcl.Forms,
  uMainTest in '..\Source\Forms\uMainTest.pas' {fmMainTest},
  uPasLexer in '..\Source\uPasLexer.pas',
  uPasLexerTypes in '..\Source\uPasLexerTypes.pas',
  uPasParser in '..\Source\uPasParser.pas',
  uPasLexerPerformance in '..\Source\uPasLexerPerformance.pas',
  uPasExceptions in '..\Source\uPasExceptions.pas',
  uPasParserTypes in '..\Source\uPasParserTypes.pas',
  uPasParserGrammar in '..\Source\uPasParserGrammar.pas',
  uPasParserSettings in '..\Source\uPasParserSettings.pas',
  ufmCodeStyleProfile in '..\Source\Forms\ufmCodeStyleProfile.pas' {fmCodeStyleProfile},
  uCodeStyleConsts in '..\Source\uCodeStyleConsts.pas',
  uCodeStyleProfile in '..\Source\uCodeStyleProfile.pas',
  uCodeStyleProfileCatalog in '..\Source\uCodeStyleProfileCatalog.pas',
  uCodeStyleRuleListView in '..\Source\uCodeStyleRuleListView.pas';

{$R *.res}

begin
  Application.Initialize;
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfmMainTest, fmMainTest);
  Application.Run;
end.
