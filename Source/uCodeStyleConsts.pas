// Constants and texts of the code style feature
unit uCodeStyleConsts;

interface

const
  // Tool name in the messages of the Build tab: "[CodeStyle Warning] uMain.pas(12): CS1001 ..."
  CODE_STYLE_TOOL_NAME = 'CodeStyle';
  // Extensions of the project files that are checked
  PASCAL_SOURCE_EXTENSIONS: array[0..2] of string = (
    '.pas',
    '.dpr',
    '.dpk'
  );
  // More issues of one file are not shown, the Build tab would become unusable
  MAX_ISSUES_PER_FILE = 100;
  // Default maximum length of a line of the rule CS1001
  DEFAULT_MAX_LINE_LENGTH = 140;
  // Size of a block read from an editor buffer
  EDITOR_READ_BLOCK_SIZE = 64 * 1024;

  // Codes of the messages that do not belong to a rule
  CODE_PARSE_ERROR = 'CS0001';
  CODE_CHECK_ERROR = 'CS0002';
  CODE_TOO_MANY_ISSUES = 'CS0003';
  // Codes of the rules
  CODE_LINE_LENGTH = 'CS1001';
  CODE_WITH_STATEMENT = 'CS1002';
  CODE_RESERVED_WORD_CASE = 'CS1003';

  // Names of the XML settings (the node of the feature is created by TWizardSettings)
  SETTINGS_ATTRIBUTE_ENABLED = 'Enabled';
  SETTINGS_NODE_RULES = 'Rules';
  SETTINGS_ATTRIBUTE_MAX_LENGTH = 'MaxLength';

  // Names of the XML settings of the code style profile (uCodeStyleProfile)
  SETTINGS_NODE_PROFILE = 'Profile';
  PROFILE_ATTRIBUTE_LEVEL = 'Level';
  // Root node and version of a profile file
  PROFILE_FILE_ROOT_NODE = 'CodeStyleProfile';
  PROFILE_ATTRIBUTE_VERSION = 'Version';
  PROFILE_FILE_VERSION = 1;
  PROFILE_FILE_ENCODING = 'UTF-8';
  // Rule and option of the catalog that hold the name of the profile
  PROFILE_RULE_PROFILE = 'Profile';
  PROFILE_OPTION_PROFILE_NAME = 'ProfileName';

  // Names of the settings controls
  SETTINGS_FEATURE_CHECKBOX_NAME = 'cbCodeStyleCheck';
  SETTINGS_RULE_CHECKBOX_NAME = 'cbCodeStyleRule%s';
  SETTINGS_PROFILE_PANEL_NAME = 'pnCodeStyleProfile';

resourcestring
  SETTINGS_SECTION_NAME = 'Code style';
  SETTINGS_FEATURE_CHECKBOX_CAPTION = 'Check code style of the compiled modules';
  SETTINGS_RULE_CHECKBOX_CAPTION = '%s: %s';
  SETTINGS_PROFILE_BUTTON_CAPTION = 'Code style profile...';
  SETTINGS_PROFILE_SUMMARY = 'Profile "%s": %d of %d rules on, %d changed.'
      + sLineBreak + 'The check does not use the profile yet.';

  // Dialog of the code style profile (ufmCodeStyleProfile)
  PROFILE_FORM_CAPTION = 'Code style profile (not used by the check yet)';
  PROFILE_FILTER_ALL = 'All rules';
  PROFILE_FILTER_ENABLED = 'Switched on';
  PROFILE_FILTER_DISABLED = 'Switched off';
  PROFILE_FILTER_CHANGED = 'Changed from the defaults';
  // Line under the caption of a rule: its category, and whether it is changed
  PROFILE_RULE_CHANGED = '%s; changed from the defaults';
  // Line under the caption of a category: the number of its shown rules and of the switched on ones
  PROFILE_CATEGORY_SUMMARY = 'Rules: %d, switched on: %d';
  // Mark of a rule changed from the defaults in the Level column
  PROFILE_LEVEL_CHANGED = '%s *';
  PROFILE_OPTION_CAPTION = '%s:';
  PROFILE_CONFIRM_RESET = 'Reset all rules to the default values?';
  PROFILE_CONFIRM_SWITCH_OFF = 'Switch all rules off?';
  PROFILE_LOAD_FAILED = 'Error loading the profile from %s:' + sLineBreak + '%s';
  PROFILE_SAVE_FAILED = 'Error saving the profile to %s:' + sLineBreak + '%s';

  // Message texts, the rule code is added before them
  MESSAGE_PARSE_ERROR = 'Code style is not checked, the parser failed: %s';
  MESSAGE_CHECK_ERROR = 'Code style check failed with %s: %s';
  MESSAGE_TOO_MANY_ISSUES = '%d more code style issues are not shown';
  MESSAGE_CHECK_SUMMARY = 'Code style: %d file(s) checked in %d ms, %d warning(s), %d hint(s)';

  // Exception texts
  EMESSAGE_NO_COMPILE_SERVICES = 'Code style check is not enabled: the IDE does not provide IOTACompileServices.';
  // Context of the error in the plugin log, TWizardLogger.LogException adds the exception class and message
  EMESSAGE_CHECK_PROJECT_FAILED = 'Error checking code style of project %s';
  EMESSAGE_PROFILE_FAILED = 'Error editing the code style profile';
  EMESSAGE_PROFILE_UNKNOWN_CATEGORY = 'Code style profile: rule %s refers to the unknown category %s.';
  EMESSAGE_PROFILE_UNKNOWN_RULE = 'Code style profile has no rule %s.';
  EMESSAGE_PROFILE_UNKNOWN_OPTION = 'Rule %s of the code style profile has no option %s.';
  EMESSAGE_PROFILE_INVALID_VALUE = 'Value "%s" is not valid for option %s of rule %s of the code style profile.';
  EMESSAGE_PROFILE_INVALID_FILE = 'File %s is not a code style profile: its root node is "%s", expected "%s".';

  // Descriptions and messages of the rules
  RULE_LINE_LENGTH_DESCRIPTION = 'Line is longer than the limit';
  RULE_LINE_LENGTH_MESSAGE = 'Line is %d characters long, the limit is %d';
  RULE_WITH_STATEMENT_DESCRIPTION = 'The with statement is used';
  RULE_WITH_STATEMENT_MESSAGE = 'The with statement is forbidden';
  RULE_RESERVED_WORD_CASE_DESCRIPTION = 'Reserved word is not in lowercase';
  RULE_RESERVED_WORD_CASE_MESSAGE = 'Reserved word "%s" must be written in lowercase';

implementation

end.
