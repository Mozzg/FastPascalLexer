// Test IDE plugin (DLL expert) for the code style feature of Delphi IDE Code Expert (DICE): after every compilation it
// checks the code style of the project modules with TPasParser and adds the issues to the Build tab of the message view.
// See README.md for the structure, the installation and the move of the feature to DICE.
library CodeStyleExpert;

{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

uses
  ToolsAPI,
  uWizardMain in '..\Source\uWizardMain.pas',
  uWizardConsts in '..\Source\uWizardConsts.pas',
  uFeatureCollection in '..\Source\uFeatureCollection.pas',
  ufrBaseSettings in '..\Source\Forms\ufrBaseSettings.pas' {frBaseSettings: TFrame},
  uBaseFeature in '..\Source\uBaseFeature.pas',
  uWizardSettings in '..\Source\uWizardSettings.pas',
  ufmWizardSettings in '..\Source\Forms\ufmWizardSettings.pas' {fmWizardSettings},
  uWizardUtils in '..\Source\uWizardUtils.pas',
  uWizardLog in '..\Source\uWizardLog.pas',
  uPasLexer in '..\Source\uPasLexer.pas',
  uPasLexerTypes in '..\Source\uPasLexerTypes.pas',
  uPasExceptions in '..\Source\uPasExceptions.pas',
  uPasParser in '..\Source\uPasParser.pas',
  uPasParserTypes in '..\Source\uPasParserTypes.pas',
  uPasParserGrammar in '..\Source\uPasParserGrammar.pas',
  uCodeStyleConsts in '..\Source\uCodeStyleConsts.pas',
  uCodeStyleRules in '..\Source\uCodeStyleRules.pas',
  uCodeStyleProfileCatalog in '..\Source\uCodeStyleProfileCatalog.pas',
  uCodeStyleProfile in '..\Source\uCodeStyleProfile.pas',
  uCodeStyleBasicRules in '..\Source\uCodeStyleBasicRules.pas',
  uCodeStyleChecker in '..\Source\uCodeStyleChecker.pas',
  uCodeStyleIDEServices in '..\Source\uCodeStyleIDEServices.pas',
  uCodeStyleProjectChecker in '..\Source\uCodeStyleProjectChecker.pas',
  uCodeStyleCompileNotifier in '..\Source\uCodeStyleCompileNotifier.pas',
  ufmCodeStyleProfile in '..\Source\Forms\ufmCodeStyleProfile.pas' {fmCodeStyleProfile},
  uCodeStyleFeature in '..\Source\uCodeStyleFeature.pas';

exports
  InitWizard name WizardEntryPoint;

begin
end.
