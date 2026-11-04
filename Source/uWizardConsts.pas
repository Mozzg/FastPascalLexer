// Copy of Delphi-IDE-Code-Expert (DICE) Source/uWizardConsts.pas, commit 5c8be6b, with other values: the test plugin
// can be loaded in the IDE together with DICE, so its ID, name (and settings file) and menu item name must differ.
// The texts of the splash screen and the about box are removed (see uWizardMain.pas).
// Not moved to DICE with the CodeStyle feature.
unit uWizardConsts;

interface

const
  // Identifiers used by IDE and in component names, must not be translated
  WIZARD_ID_STRING = 'Mozzg.DICE.CodeStyleExpert';
  WIZARD_SETTINGS_MENU_ITEM_NAME = 'miCodeStyleExpertMenuItem';

resourcestring
  WIZARD_NAME = 'CodeStyleExpert';
  WIZARD_HELP_MENU_CAPTION = 'Code Style Expert';
  WIZARD_PRODUCT_NAME = 'Code Style Expert';
  WIZARD_COPYRIGHT_TEXT = 'Copyright (C) 2026 Evgeny "Mozzg" Pervov';
  WIZARD_LICENCE_TEXT = 'Apache License 2.0';
  WIZARD_HELP_MENU_TEXT = '%s'{$IFDEF DEBUG}+ ' debug version'{$ENDIF} + sLineBreak
      + 'Test IDE plugin for the code style feature of DICE' + sLineBreak + sLineBreak + '%s, %s';
  WIZARD_SETTINGS_MENU_ITEM_CAPTION = 'Code Style Expert Configuration';

implementation

end.
