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
  // Maximum length of a line, section 2 of AGENTS.md
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

  // Names of the settings controls
  SETTINGS_FEATURE_CHECKBOX_NAME = 'cbCodeStyleCheck';
  SETTINGS_RULE_CHECKBOX_NAME = 'cbCodeStyleRule%s';

resourcestring
  SETTINGS_SECTION_NAME = 'Code style';
  SETTINGS_FEATURE_CHECKBOX_CAPTION = 'Check code style of the compiled modules';
  SETTINGS_RULE_CHECKBOX_CAPTION = '%s: %s';

  // Message texts, the rule code is added before them
  MESSAGE_PARSE_ERROR = 'Code style is not checked, the parser failed: %s';
  MESSAGE_CHECK_ERROR = 'Code style check failed with %s: %s';
  MESSAGE_TOO_MANY_ISSUES = '%d more code style issues are not shown';
  MESSAGE_CHECK_SUMMARY = 'Code style: %d file(s) checked in %d ms, %d warning(s), %d hint(s)';

  // Exception texts
  EMESSAGE_NO_COMPILE_SERVICES = 'Code style check is not enabled: the IDE does not provide IOTACompileServices.';
  // Context of the error in the plugin log, TWizardLogger.LogException adds the exception class and message
  EMESSAGE_CHECK_PROJECT_FAILED = 'Error checking code style of project %s';

  // Descriptions and messages of the rules
  RULE_LINE_LENGTH_DESCRIPTION = 'Line is longer than the limit';
  RULE_LINE_LENGTH_MESSAGE = 'Line is %d characters long, the limit is %d';
  RULE_WITH_STATEMENT_DESCRIPTION = 'The with statement is used';
  RULE_WITH_STATEMENT_MESSAGE = 'The with statement is forbidden';
  RULE_RESERVED_WORD_CASE_DESCRIPTION = 'Reserved word is not in lowercase';
  RULE_RESERVED_WORD_CASE_MESSAGE = 'Reserved word "%s" must be written in lowercase';

implementation

end.
