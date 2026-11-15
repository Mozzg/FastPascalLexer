// Catalog of the code style profile: the categories, the rules, the options of the rules and their default values.
// Every rule is one logical unit of a style (the spaces around one operator, the naming of one kind of identifiers,
// the indent of one construct) with its own level, so any style can be described by combining the rules.
//
// Rules of one kind share their options through a template: an option whose Rule is '@Name' belongs to every rule
// with Template 'Name'. The template options come first, then the own options of the rule; CODE_STYLE_DEFAULTS
// changes the default value of an option for one rule. The default values follow the common Delphi conventions (the
// style of the RTL and VCL sources); opinionated rules are switched off. Pure data, does not depend on the IDE.
//
// The profile is a set of settings only: the check does not use it yet. A rule of uCodeStyleRules will later read
// its rule of the profile (the Id) instead of its own settings.
unit uCodeStyleProfileCatalog;

interface

type
  // Level of a rule: switched off or the kind of the message of the found issues
  TCodeStyleLevel = (
    cslOff,
    cslHint,
    cslWarning,
    cslError
  );

  // Kind of the value of an option
  TCodeStyleOptionKind = (
    // 'True' or 'False'
    cokBoolean,
    // Integer between MinValue and MaxValue
    cokInteger,
    // Any text, also empty
    cokText,
    // List of words, stored separated by ';'
    cokTextList,
    // One of the values of Choices
    cokChoice,
    // Condition on a count, like a number of spaces: 'Any', 'Exactly:N', 'AtLeast:N' or 'AtMost:N', N between
    // MinValue and MaxValue
    cokQuantity
  );

  // Mode of a cokQuantity value
  TCodeStyleQuantityMode = (
    cqmAny,
    cqmExactly,
    cqmAtLeast,
    cqmAtMost
  );

  TCodeStyleCategoryInfo = record
    // Identifier of the category, the name of its XML node
    Id: string;
    Caption: string;
  end;

  TCodeStyleRuleInfo = record
    // Identifier of the category of the rule
    Category: string;
    // Unique identifier of the rule, the name of its XML node
    Id: string;
    Caption: string;
    // Default level
    Level: TCodeStyleLevel;
    // True for a group of general settings that has no level
    WithoutLevel: Boolean;
    // Template of the shared options, without '@'; empty when the rule has only its own options
    Template: string;
    Description: string;
  end;

  TCodeStyleOptionInfo = record
    // Identifier of the rule of the option, or '@' + the name of a template
    Rule: string;
    // Name of the option, unique within the rule, the name of its XML attribute
    Name: string;
    Caption: string;
    Kind: TCodeStyleOptionKind;
    // Default value, written as it is stored; CODE_STYLE_DEFAULTS can change it for one rule
    DefaultValue: string;
    // Range of a cokInteger value and of the count of a cokQuantity value
    MinValue: Integer;
    MaxValue: Integer;
    // Values of a cokChoice option: pairs 'Value=Caption' separated by '|'
    Choices: string;
    // Explanation shown as the hint of the control
    Hint: string;
  end;

  // Default value of an option for one rule, instead of the default value of the option (of its template)
  TCodeStyleDefaultInfo = record
    Rule: string;
    Option: string;
    Value: string;
  end;

const
  // Values of the levels in the XML settings
  CODE_STYLE_LEVEL_NAMES: array[TCodeStyleLevel] of string = (
    'Off',
    'Hint',
    'Warning',
    'Error'
  );
  // Modes of a cokQuantity value as stored, and their captions
  CODE_STYLE_QUANTITY_NAMES: array[TCodeStyleQuantityMode] of string = (
    'Any',
    'Exactly',
    'AtLeast',
    'AtMost'
  );
  CODE_STYLE_QUANTITY_CAPTIONS: array[TCodeStyleQuantityMode] of string = (
    'Any',
    'Exactly',
    'At least',
    'At most'
  );
  // Separator of the items of a cokTextList value and of the choices of a cokChoice option
  CODE_STYLE_LIST_SEPARATOR = ';';
  CODE_STYLE_CHOICE_SEPARATOR = '|';
  CODE_STYLE_CHOICE_VALUE_SEPARATOR = '=';
  // Separator of the mode and the count of a cokQuantity value
  CODE_STYLE_QUANTITY_SEPARATOR = ':';
  // First character of the Rule of a template option
  CODE_STYLE_TEMPLATE_PREFIX = '@';
  CODE_STYLE_TRUE = 'True';
  CODE_STYLE_FALSE = 'False';

  // Choices shared by several options
  CHOICES_LINE = 'NewLine=On a new line|SameLine=On the same line|Any=Any';
  CHOICES_REQUIRED = 'Required=Required|Forbidden=Forbidden|Any=Any';
  CHOICES_WORD_CASE = 'Lower=lowercase: begin|Upper=UPPERCASE: BEGIN|Capitalized=Capitalized: Begin|Any=Any';
  CHOICES_NAME_CASE = 'Pascal=PascalCase: SetNumber|Camel=camelCase: setNumber|Upper=UPPER_CASE: MAX_SIZE'
      + '|Lower=lowercase: index|Snake=snake_case: max_size|Any=Any';
  CHOICES_LINE_POSITION = 'LineStart=At the start of the next line|LineEnd=At the end of the line|Any=Any';
  CHOICES_CLOSING = 'AfterLast=After the last item|OwnLine=On its own line|Any=Any';
  CHOICES_COMMENT = 'DoubleSlash=// comment|Braces={ comment }|Parentheses=(* comment *)|Any=Any';

  CODE_STYLE_CATEGORIES: array[0..18] of TCodeStyleCategoryInfo = (
    (Id: 'General'; Caption: 'General'),
    (Id: 'Lines'; Caption: 'Files and lines'),
    (Id: 'BlankLines'; Caption: 'Blank lines'),
    (Id: 'Indentation'; Caption: 'Indentation'),
    (Id: 'Operators'; Caption: 'Spaces around operators'),
    (Id: 'Punctuation'; Caption: 'Spaces around punctuation and brackets'),
    (Id: 'LineBreaks'; Caption: 'Line breaks'),
    (Id: 'Wrapping'; Caption: 'Wrapping of long lines'),
    (Id: 'Case'; Caption: 'Case of keywords and literals'),
    (Id: 'NamingGeneral'; Caption: 'Naming: general'),
    (Id: 'NamingTypes'; Caption: 'Naming: types'),
    (Id: 'NamingMembers'; Caption: 'Naming: members and routines'),
    (Id: 'NamingVariables'; Caption: 'Naming: variables, constants and units'),
    (Id: 'Statements'; Caption: 'Statements'),
    (Id: 'Declarations'; Caption: 'Declarations and code order'),
    (Id: 'Uses'; Caption: 'Uses clauses'),
    (Id: 'Comments'; Caption: 'Comments'),
    (Id: 'Language'; Caption: 'Language features'),
    (Id: 'Metrics'; Caption: 'Metrics')
  );

  CODE_STYLE_RULES: array[0..212] of TCodeStyleRuleInfo = (
    // General
    (Category: 'General'; Id: 'Profile'; Caption: 'Profile name'; WithoutLevel: True;
        Description: 'Name of the profile. Save the profile to a file to share the style with other developers.'),
    (Category: 'General'; Id: 'Scope'; Caption: 'Checked files'; WithoutLevel: True;
        Description: 'Which modules of a project are checked and how many issues are shown.'),
    (Category: 'General'; Id: 'Suppression'; Caption: 'Suppression comments'; WithoutLevel: True;
        Description: 'Comments that switch the check off for a line or for a part of a module, for code that has to be'
        + ' formatted in a special way.'),
    (Category: 'General'; Id: 'Columns'; Caption: 'Tab width in spaces'; WithoutLevel: True;
        Description: 'How many spaces a tab character counts for in the rules that measure lines and indents.'),
    // Files and lines
    (Category: 'Lines'; Id: 'LineLength'; Caption: 'Line length'; Level: cslHint;
        Description: 'A line is longer than the limit.'),
    (Category: 'Lines'; Id: 'TrailingSpaces'; Caption: 'Trailing spaces'; Level: cslHint;
        Description: 'A line ends with spaces or tab characters.'),
    (Category: 'Lines'; Id: 'TabsInsideLines'; Caption: 'Tab characters inside lines';
        Description: 'A line contains tab characters after its indent.'),
    (Category: 'Lines'; Id: 'LineEndings'; Caption: 'Line endings';
        Description: 'The line break that is used in the files.'),
    (Category: 'Lines'; Id: 'FileEncoding'; Caption: 'File encoding';
        Description: 'The encoding that is used for files.'),
    (Category: 'Lines'; Id: 'FileStart'; Caption: 'Blank lines at the start of a file';
        Description: 'How a file starts.'),
    (Category: 'Lines'; Id: 'FileEnd'; Caption: 'End of a file after the final end.';
        Description: 'How a file ends.'),
    (Category: 'Lines'; Id: 'StatementsPerLine'; Caption: 'Statements per line'; Level: cslHint;
        Description: 'How many statements are written per line.'),
    // Blank lines
    (Category: 'BlankLines'; Id: 'ConsecutiveBlankLines'; Caption: 'Consecutive blank lines'; Level: cslHint;
        Description: 'How many blank lines follow each other.'),
    (Category: 'BlankLines'; Id: 'BlankLinesInsideBlocks'; Caption: 'Blank lines at the start and the end of blocks';
        Description: 'How many blank lines follow the first line of a block (begin, try, repeat, record, class, var...) and precede'
        + ' its end.'),
    (Category: 'BlankLines'; Id: 'BlankLinesUnitSections'; Caption: 'Blank lines around unit sections'; Template: 'BlankLines';
        Description: 'How many blank lines surround interface, implementation, initialization and finalization.'),
    (Category: 'BlankLines'; Id: 'BlankLinesUses'; Caption: 'Blank lines around uses clauses'; Template: 'BlankLines';
        Description: 'How many blank lines surround a uses clause.'),
    (Category: 'BlankLines'; Id: 'BlankLinesDeclarationSections'; Caption: 'Blank lines around declaration sections of a unit';
        Template: 'BlankLines';
        Description: 'How many blank lines surround the type, const, var, resourcestring and threadvar sections of a unit.'),
    (Category: 'BlankLines'; Id: 'BlankLinesBetweenTypes'; Caption: 'Blank lines between type declarations';
        Description: 'How many blank lines separate two declarations of classes, records or interfaces in a type section.'),
    (Category: 'BlankLines'; Id: 'BlankLinesBetweenRoutines'; Caption: 'Blank lines between routine implementations';
        Description: 'How many blank lines separate the implementations of two routines or methods.'),
    (Category: 'BlankLines'; Id: 'BlankLinesNestedRoutines'; Caption: 'Blank lines around nested routines'; Template: 'BlankLines';
        Description: 'How many blank lines surround a routine declared inside another routine.'),
    (Category: 'BlankLines'; Id: 'BlankLinesVisibilitySections'; Caption: 'Blank lines around visibility sections';
        Template: 'BlankLines';
        Description: 'How many blank lines surround private, protected, public and published in a class or record. The'
        + ' section right after the line of the class is decided by Blank lines at the start and the end of blocks.'),
    (Category: 'BlankLines'; Id: 'BlankLinesClassComment'; Caption: 'Blank lines around the comment of a class';
        Template: 'BlankLines';
        Description: 'How many blank lines surround a comment like { TMyClass } before the methods of a class.'),
    // Indentation
    (Category: 'Indentation'; Id: 'BlockIndent'; Caption: 'Size and character of a block indent'; WithoutLevel: True;
        Description: 'Which character indents consist of and how many of them one indent level has.'),
    (Category: 'Indentation'; Id: 'IndentStatements'; Caption: 'Indent of statements in begin-end'; Level: cslHint;
        Template: 'Indent';
        Description: 'How far the statements between begin and end are indented, relative to begin.'),
    (Category: 'Indentation'; Id: 'IndentBeginOfStatement'; Caption: 'Indent of begin after if, else and loops'; Level: cslHint;
        Template: 'Indent';
        Description: 'How far begin on its own line after if, else, for, while or with is indented, relative to the statement.'),
    (Category: 'Indentation'; Id: 'IndentSingleStatement'; Caption: 'Indent of a statement after then, else or do'; Level: cslHint;
        Template: 'Indent';
        Description: 'How far a single statement on the line after then, else or do is indented, relative to the statement.'),
    (Category: 'Indentation'; Id: 'IndentTryBlocks'; Caption: 'Indent of statements in try blocks'; Level: cslHint;
        Template: 'Indent';
        Description: 'How far the statements after try, finally and except are indented, relative to these words.'),
    (Category: 'Indentation'; Id: 'IndentRepeat'; Caption: 'Indent of statements in repeat-until'; Level: cslHint;
        Template: 'Indent';
        Description: 'How far the statements between repeat and until are indented, relative to repeat.'),
    (Category: 'Indentation'; Id: 'IndentCaseLabels'; Caption: 'Indent of case labels'; Level: cslHint; Template: 'Indent';
        Description: 'How far the labels of a case statement are indented, relative to case.'),
    (Category: 'Indentation'; Id: 'IndentCaseStatements'; Caption: 'Indent of statements under case labels'; Level: cslHint;
        Template: 'Indent';
        Description: 'How far the statement of a label on the next line is indented, relative to the label.'),
    (Category: 'Indentation'; Id: 'IndentCaseBegin'; Caption: 'Indent of begin under a case label'; Template: 'Indent';
        Description: 'How far begin on the line after a label is indented, relative to the label.'),
    (Category: 'Indentation'; Id: 'IndentCaseElse'; Caption: 'Indent of else of case'; Level: cslHint;
        Template: 'Indent';
        Description: 'How far the else of a case statement is indented, relative to case.'),
    (Category: 'Indentation'; Id: 'IndentCaseElseStatements'; Caption: 'Indent of statements in the else of case'; Level: cslHint;
        Template: 'Indent';
        Description: 'How far the statements after the else of a case statement are indented, relative to else.'),
    (Category: 'Indentation'; Id: 'IndentAsm'; Caption: 'Indent of assembler instructions'; Template: 'Indent';
        Description: 'How far the instructions between asm and end are indented, relative to asm.'),
    (Category: 'Indentation'; Id: 'IndentRoutineBody'; Caption: 'Indent of the body of a routine'; Level: cslHint; Template: 'Indent';
        Description: 'How far the begin or asm of a routine body is indented, relative to the routine header.'),
    (Category: 'Indentation'; Id: 'IndentLocalSections'; Caption: 'Indent of local declaration sections'; Level: cslHint;
        Template: 'Indent';
        Description: 'How far the type, const, var and label of a routine are indented, relative to the routine header.'),
    (Category: 'Indentation'; Id: 'IndentDeclarations'; Caption: 'Indent of declarations in a section'; Level: cslHint;
        Template: 'Indent';
        Description: 'How far the declarations are indented, relative to their type, const, var, label or resourcestring.'),
    (Category: 'Indentation'; Id: 'IndentNestedRoutines'; Caption: 'Indent of nested routines'; Template: 'Indent';
        Description: 'How far a routine declared inside another routine is indented, relative to the header of that routine.'),
    (Category: 'Indentation'; Id: 'IndentUsesList'; Caption: 'Indent of units in a uses clause'; Template: 'Indent';
        Description: 'How far the unit names on the lines after uses are indented, relative to uses.'),
    (Category: 'Indentation'; Id: 'IndentVisibilitySections'; Caption: 'Indent of visibility sections'; Level: cslHint;
        Template: 'Indent';
        Description: 'How far private, protected, public and published are indented, relative to the name of the type.'),
    (Category: 'Indentation'; Id: 'IndentClassMembers'; Caption: 'Indent of members of classes and records'; Level: cslHint;
        Template: 'Indent';
        Description: 'How far the fields, methods and properties are indented, relative to their visibility section, or to the name'
        + ' of the type when there is none.'),
    (Category: 'Indentation'; Id: 'IndentTypeEnd'; Caption: 'Indent of the end of a class or record'; Level: cslHint;
        Template: 'Indent';
        Description: 'How far the end of a class, record or interface is indented, relative to the name of the type.'),
    (Category: 'Indentation'; Id: 'IndentEnumElements'; Caption: 'Indent of enumeration elements'; Template: 'Indent';
        Description: 'How far the elements written on lines of their own are indented, relative to the name of the type.'),
    (Category: 'Indentation'; Id: 'IndentArrayElements'; Caption: 'Indent of elements of constant arrays'; Template: 'Indent';
        Description: 'How far the elements written on lines of their own are indented, relative to the name of the constant.'),
    (Category: 'Indentation'; Id: 'IndentAnonymousMethods'; Caption: 'Indent of anonymous methods'; Template: 'Indent';
        Description: 'How far the body of an anonymous method is indented, relative to the line where it starts.'),
    (Category: 'Indentation'; Id: 'IndentInitialization'; Caption: 'Indent of initialization and finalization'; Template: 'Indent';
        Description: 'How far the statements of initialization and finalization are indented, relative to these words.'),
    (Category: 'Indentation'; Id: 'LayoutWords'; Caption: 'Layout words at the left margin';
        Description: 'A word that lays out a unit or a project file (unit, interface, uses...) does not start at the beginning'
        + ' of the line.'),
    (Category: 'Indentation'; Id: 'IndentCompilerDirectives'; Caption: 'Indent of compiler directives';
        Description: 'Where compiler directives on lines of their own start.'),
    (Category: 'Indentation'; Id: 'IndentComments'; Caption: 'Indent of comments';
        Description: 'Where comments on lines of their own start.'),
    (Category: 'Indentation'; Id: 'IndentLabels'; Caption: 'Indent of goto labels';
        Description: 'Where the labels of goto statements start.'),
    // Spaces around operators
    (Category: 'Operators'; Id: 'SpacesAssignment'; Caption: 'Spaces around the assignment :='; Level: cslHint; Template: 'AlignedSpaces';
        Description: 'How many spaces surround the assignment operator :=.'),
    (Category: 'Operators'; Id: 'SpacesEqual'; Caption: 'Spaces around the comparison ='; Level: cslHint; Template: 'AlignedSpaces';
        Description: 'How many spaces surround = in expressions.'),
    (Category: 'Operators'; Id: 'SpacesNotEqual'; Caption: 'Spaces around the comparison <>'; Level: cslHint; Template: 'AlignedSpaces';
        Description: 'How many spaces surround <>.'),
    (Category: 'Operators'; Id: 'SpacesLess'; Caption: 'Spaces around the comparison <'; Level: cslHint; Template: 'AlignedSpaces';
        Description: 'How many spaces surround < in expressions (not the brackets of generics).'),
    (Category: 'Operators'; Id: 'SpacesGreater'; Caption: 'Spaces around the comparison >'; Level: cslHint; Template: 'AlignedSpaces';
        Description: 'How many spaces surround > in expressions (not the brackets of generics).'),
    (Category: 'Operators'; Id: 'SpacesLessEqual'; Caption: 'Spaces around the comparison <='; Level: cslHint; Template: 'AlignedSpaces';
        Description: 'How many spaces surround <=.'),
    (Category: 'Operators'; Id: 'SpacesGreaterEqual'; Caption: 'Spaces around the comparison >='; Level: cslHint; Template: 'AlignedSpaces';
        Description: 'How many spaces surround >=.'),
    (Category: 'Operators'; Id: 'SpacesPlus'; Caption: 'Spaces around the addition +'; Level: cslHint; Template: 'Spaces';
        Description: 'How many spaces surround the binary + (addition, string concatenation, set union).'),
    (Category: 'Operators'; Id: 'SpacesMinus'; Caption: 'Spaces around the subtraction -'; Level: cslHint; Template: 'Spaces';
        Description: 'How many spaces surround the binary - (subtraction, set difference).'),
    (Category: 'Operators'; Id: 'SpacesMultiply'; Caption: 'Spaces around the multiplication *'; Level: cslHint; Template: 'Spaces';
        Description: 'How many spaces surround * (multiplication, set intersection).'),
    (Category: 'Operators'; Id: 'SpacesDivide'; Caption: 'Spaces around the division /'; Level: cslHint; Template: 'Spaces';
        Description: 'How many spaces surround /.'),
    (Category: 'Operators'; Id: 'SpacesWordOperators'; Caption: 'Spaces around and, or, div, mod, in, is...'; Level: cslHint;
        Description: 'How many spaces surround and, or, xor, div, mod, shl, shr, in, is and as. Next to a word at least one'
        + ' space is required by the syntax, next to a bracket none is needed: (A)and(B).'),
    (Category: 'Operators'; Id: 'SpacesNot'; Caption: 'Spaces around not';
        Description: 'How many spaces follow not, and whether a space separates it from an opening bracket: not (A) or'
        + ' not(A). The space before not is decided by the word before it: if not, := not.'),
    (Category: 'Operators'; Id: 'SpacesUnary'; Caption: 'Spaces around the unary - and +'; Template: 'Spaces';
        Description: 'How many spaces surround the sign of a number or an expression: -1, -Value.'),
    (Category: 'Operators'; Id: 'SpacesAddress'; Caption: 'Spaces around the address operator @'; Template: 'Spaces';
        Description: 'How many spaces surround @ that takes an address.'),
    (Category: 'Operators'; Id: 'SpacesDereference'; Caption: 'Spaces around the dereference ^'; Template: 'Spaces';
        Description: 'How many spaces surround ^ after a pointer: P^.Name.'),
    (Category: 'Operators'; Id: 'SpacesPointerType'; Caption: 'Spaces around ^ in pointer types'; Template: 'Spaces';
        Description: 'How many spaces surround ^ of a pointer type: PItem = ^TItem.'),
    (Category: 'Operators'; Id: 'SpacesRange'; Caption: 'Spaces around the range ..'; Template: 'Spaces';
        Description: 'How many spaces surround .. of subranges, sets and case labels.'),
    (Category: 'Operators'; Id: 'SpacesDot'; Caption: 'Spaces around the member access point'; Template: 'Spaces';
        Description: 'How many spaces surround the point of qualified names: Form.Caption, System.SysUtils.'),
    (Category: 'Operators'; Id: 'SpacesDeclarationEqual'; Caption: 'Spaces around = in type and const declarations'; Level: cslHint;
        Template: 'AlignedSpaces';
        Description: 'How many spaces surround = in type and constant declarations: TName = class, MAX = 10.'),
    (Category: 'Operators'; Id: 'SpacesDefaultValue'; Caption: 'Spaces around = of default parameter values'; Template: 'AlignedSpaces';
        Description: 'How many spaces surround = of a default parameter value: ACount: Integer = 0.'),
    // Spaces around punctuation and brackets
    (Category: 'Punctuation'; Id: 'SpacesComma'; Caption: 'Spaces around commas'; Level: cslHint; Template: 'Spaces';
        Description: 'How many spaces surround a comma.'),
    (Category: 'Punctuation'; Id: 'SpacesSemicolon'; Caption: 'Spaces around semicolons inside a line'; Level: cslHint;
        Template: 'Spaces';
        Description: 'How many spaces surround a semicolon that is followed by more code on the line, like in parameter lists.'),
    (Category: 'Punctuation'; Id: 'SpacesColonDeclaration'; Caption: 'Spaces around the colon of declarations'; Level: cslHint;
        Template: 'AlignedSpaces';
        Description: 'How many spaces surround the colon of variables, fields, parameters, function results and exception handlers:'
        + ' Count: Integer.'),
    (Category: 'Punctuation'; Id: 'SpacesColonCaseLabel'; Caption: 'Spaces around the colon of case labels'; Level: cslHint;
        Template: 'AlignedSpaces';
        Description: 'How many spaces surround the colon after a case label.'),
    (Category: 'Punctuation'; Id: 'SpacesColonRecordConstant'; Caption: 'Spaces around the colon of record constants';
        Template: 'AlignedSpaces';
        Description: 'How many spaces surround the colon of a field in a record constant: (Name: ''A''; Size: 1).'),
    (Category: 'Punctuation'; Id: 'SpacesColonFormat'; Caption: 'Spaces around the colons of output formats'; Template: 'Spaces';
        Description: 'How many spaces surround the colons of the width and the precision: Str(Value:8:2, Text).'),
    (Category: 'Punctuation'; Id: 'SpacesParentheses'; Caption: 'Spaces at parentheses of expressions'; Level: cslHint;
        Template: 'Brackets';
        Description: 'How many spaces are before and inside the parentheses that group an expression.'),
    (Category: 'Punctuation'; Id: 'SpacesCallParentheses'; Caption: 'Spaces at parentheses of calls'; Level: cslHint;
        Template: 'Brackets';
        Description: 'How many spaces are before and inside the parentheses of the arguments of a call.'),
    (Category: 'Punctuation'; Id: 'SpacesDeclarationParentheses'; Caption: 'Spaces at parentheses of parameter lists';
        Level: cslHint; Template: 'Brackets';
        Description: 'How many spaces are before and inside the parentheses of the parameters of a routine declaration.'),
    (Category: 'Punctuation'; Id: 'SpacesIndexBrackets'; Caption: 'Spaces at brackets of indexes'; Level: cslHint;
        Template: 'Brackets';
        Description: 'How many spaces are before and inside the brackets of array indexes and indexed properties: Items[i].'),
    (Category: 'Punctuation'; Id: 'SpacesSetBrackets'; Caption: 'Spaces at brackets of sets and array constants';
        Template: 'Brackets';
        Description: 'How many spaces are before and inside the brackets of sets and dynamic array constants: [fsBold, fsItalic].'),
    (Category: 'Punctuation'; Id: 'SpacesGenericBrackets'; Caption: 'Spaces at angle brackets of generics'; Template: 'Brackets';
        Description: 'How many spaces are before and inside < and > of generic types and methods: TList<Integer>.'),
    (Category: 'Punctuation'; Id: 'SpacesAttributeBrackets'; Caption: 'Spaces at brackets of attributes'; Template: 'Brackets';
        Description: 'How many spaces are before and inside the brackets of attributes: [Weak].'),
    // Line breaks
    (Category: 'LineBreaks'; Id: 'BeginPlacement'; Caption: 'Placement of begin'; Level: cslHint;
        Description: 'Where begin is written: on a new line or at the end of the line of its statement.'),
    (Category: 'LineBreaks'; Id: 'EndPlacement'; Caption: 'Placement of end'; Level: cslHint;
        Description: 'Whether end is written on a line of its own and whether a comment follows it.'),
    (Category: 'LineBreaks'; Id: 'ElsePlacement'; Caption: 'Placement of else'; Level: cslHint;
        Description: 'Where else is written after the then branch, and where if is written after else.'),
    (Category: 'LineBreaks'; Id: 'ConditionKeywords'; Caption: 'Placement of then and do after a wrapped condition';
        Description: 'Where then and do are written when the condition of if, while, for or with is wrapped.'),
    (Category: 'LineBreaks'; Id: 'SameLineStatements'; Caption: 'Statement on the line of then, else, do or a label';
        Description: 'Where a single statement after then, else, do or a case label is written: on the same line or on a new'
        + ' line. Not for begin: Placement of begin decides about it.'),
    (Category: 'LineBreaks'; Id: 'UsesLayout'; Caption: 'Layout of uses clauses';
        Description: 'How many unit names of a uses clause are written on one line, and where the first one is written.'),
    (Category: 'LineBreaks'; Id: 'EnumLayout'; Caption: 'Layout of enumerations';
        Description: 'How the elements of an enumeration type are placed on the lines.'),
    (Category: 'LineBreaks'; Id: 'ArrayConstantLayout'; Caption: 'Layout of constant arrays';
        Description: 'How many elements of a constant array are written on one line, and where the closing parenthesis is'
        + ' written.'),
    (Category: 'LineBreaks'; Id: 'AnonymousMethodLayout'; Caption: 'Layout of anonymous methods';
        Description: 'How an anonymous method is placed on the lines.'),
    // Wrapping of long lines
    (Category: 'Wrapping'; Id: 'ContinuationIndent'; Caption: 'Indent of continuation lines';
        Description: 'How far the lines that continue a wrapped statement or declaration are indented.'),
    (Category: 'Wrapping'; Id: 'OperatorAtLineBreak'; Caption: 'Operators and punctuation at a line break';
        Description: 'Where an operator or a punctuation mark is written when a line is wrapped at it: at the end of the line or at'
        + ' the start of the next one.'),
    (Category: 'Wrapping'; Id: 'WrappedHeaders'; Caption: 'Wrapped routine headers';
        Description: 'Whether and how routine headers are written on several lines.'),
    (Category: 'Wrapping'; Id: 'WrappedArguments'; Caption: 'Wrapped argument lists';
        Description: 'How the arguments of a call are written on several lines.'),
    (Category: 'Wrapping'; Id: 'WrappedVariableLists'; Caption: 'Wrapped variable lists';
        Description: 'A list of variables of one type (A, B, C: Integer) is written on several lines.'),
    // Case of keywords and literals
    (Category: 'Case'; Id: 'ReservedWordCase'; Caption: 'Case of reserved words'; Level: cslHint;
        Description: 'How reserved words are written: begin, class, type...'),
    (Category: 'Case'; Id: 'DirectiveCase'; Caption: 'Case of directives'; Level: cslHint;
        Description: 'How directives are written: virtual, override, stdcall, published...'),
    (Category: 'Case'; Id: 'StandardIdentifierCase'; Caption: 'Case of standard types, constants and routines';
        Description: 'How the identifiers of the System unit are written: Integer, Boolean, True, Exit, Length...'),
    (Category: 'Case'; Id: 'DeclaredCase'; Caption: 'Case of identifiers as declared';
        Description: 'An identifier is written in another case than in its declaration.'),
    (Category: 'Case'; Id: 'HexDigitsCase'; Caption: 'Case of hexadecimal digits';
        Description: 'How the letters of hexadecimal numbers are written: $FF or $ff.'),
    (Category: 'Case'; Id: 'NumberLiterals'; Caption: 'Digit separators and exponents of numbers';
        Description: 'How numbers are written: digit separators (1_000_000) and the exponent (1.5E3).'),
    (Category: 'Case'; Id: 'CompilerDirectiveCase'; Caption: 'Case of compiler directive names';
        Description: 'How the names of compiler directives are written: {$IFDEF} or {$ifdef}.'),
    (Category: 'Case'; Id: 'CompilerDirectiveStyle'; Caption: 'Form of compiler switches';
        Description: 'Which form of the switch directives is used: {$RANGECHECKS ON} or {$R+}.'),
    (Category: 'Case'; Id: 'ControlCharacters'; Caption: 'Control characters in strings';
        Description: 'How control characters are written in strings: #13#10 or ^M^J.'),
    // Naming: general
    (Category: 'NamingGeneral'; Id: 'IdentifierCharacters'; Caption: 'Characters of identifiers'; Level: cslHint;
        Description: 'An identifier contains other characters than Latin letters, digits and _.'),
    (Category: 'NamingGeneral'; Id: 'KeywordNames'; Caption: 'Names that match keywords';
        Description: 'An identifier is named like a reserved word or a directive.'),
    (Category: 'NamingGeneral'; Id: 'ShortNames'; Caption: 'Short identifier names';
        Description: 'An identifier is shorter than the limit.'),
    (Category: 'NamingGeneral'; Id: 'WordsWithDigits'; Caption: 'Words with digits allowed in names'; WithoutLevel: True;
        Description: 'Parts of names whose digits are not counted by the "Allow digits" options of the naming rules.'),
    (Category: 'NamingGeneral'; Id: 'MethodVerbs'; Caption: 'Verb at the start of method names';
        Description: 'A method name does not start with a verb: Layout instead of SaveLayout.'),
    // Naming: types
    (Category: 'NamingTypes'; Id: 'NamesClasses'; Caption: 'Names of classes'; Level: cslHint; Template: 'Naming';
        Description: 'How classes are named, except exception classes, forms, frames, data modules, helpers and attributes:'
        + ' they have rules of their own.'),
    (Category: 'NamingTypes'; Id: 'NamesRecords'; Caption: 'Names of records'; Level: cslHint; Template: 'Naming';
        Description: 'How records are named.'),
    (Category: 'NamingTypes'; Id: 'NamesInterfaces'; Caption: 'Names of interfaces'; Level: cslHint; Template: 'Naming';
        Description: 'How interfaces are named.'),
    (Category: 'NamingTypes'; Id: 'NamesEnumerations'; Caption: 'Names of enumeration types'; Level: cslHint; Template: 'Naming';
        Description: 'How enumeration types are named.'),
    (Category: 'NamingTypes'; Id: 'NamesPointerTypes'; Caption: 'Names of pointer types'; Level: cslHint; Template: 'Naming';
        Description: 'How pointer types are named: PItem = ^TItem.'),
    (Category: 'NamingTypes'; Id: 'NamesClassReferences'; Caption: 'Names of class reference types'; Template: 'Naming';
        Description: 'How class reference types are named: TItemClass = class of TItem.'),
    (Category: 'NamingTypes'; Id: 'NamesExceptionClasses'; Caption: 'Names of exception classes'; Level: cslHint;
        Template: 'Naming';
        Description: 'How the classes derived from Exception are named.'),
    (Category: 'NamingTypes'; Id: 'NamesHelpers'; Caption: 'Names of class and record helpers'; Template: 'Naming';
        Description: 'How class and record helpers are named.'),
    (Category: 'NamingTypes'; Id: 'NamesAttributes'; Caption: 'Names of attribute classes'; Template: 'Naming';
        Description: 'How the classes derived from TCustomAttribute are named.'),
    (Category: 'NamingTypes'; Id: 'NamesForms'; Caption: 'Names of form classes'; Template: 'Naming';
        Description: 'How form classes are named.'),
    (Category: 'NamingTypes'; Id: 'NamesFrames'; Caption: 'Names of frame classes'; Template: 'Naming';
        Description: 'How frame classes are named.'),
    (Category: 'NamingTypes'; Id: 'NamesDataModules'; Caption: 'Names of data module classes'; Template: 'Naming';
        Description: 'How data module classes are named.'),
    (Category: 'NamingTypes'; Id: 'NamesGenericParameters'; Caption: 'Names of generic type parameters'; Template: 'Naming';
        Description: 'How the type parameters of generics are named: TList<T>, TDictionary<TKey, TValue>.'),
    (Category: 'NamingTypes'; Id: 'NamesOtherTypes'; Caption: 'Names of other types'; Level: cslHint; Template: 'Naming';
        Description: 'How array, set, procedural and alias types are named.'),
    (Category: 'NamingTypes'; Id: 'EnumElementPrefixes'; Caption: 'Prefixes of enumeration elements';
        Description: 'Which prefix the elements of an enumeration have: TAlign = (alNone, alLeft).'),
    // Naming: members and routines
    (Category: 'NamingMembers'; Id: 'NamesPrivateFields'; Caption: 'Names of private fields'; Level: cslHint;
        Template: 'Naming';
        Description: 'How the fields of the private and strict private sections are named.'),
    (Category: 'NamingMembers'; Id: 'NamesProtectedFields'; Caption: 'Names of protected fields'; Level: cslHint;
        Template: 'Naming';
        Description: 'How the fields of the protected and strict protected sections are named.'),
    (Category: 'NamingMembers'; Id: 'NamesPublicFields'; Caption: 'Names of public fields'; Template: 'Naming';
        Description: 'How the fields of the public section are named.'),
    (Category: 'NamingMembers'; Id: 'NamesPublishedFields'; Caption: 'Names of published fields'; Template: 'Naming';
        Description: 'How the fields of the published section, like the components of a form, are named.'),
    (Category: 'NamingMembers'; Id: 'NamesRecordFields'; Caption: 'Names of record fields'; Template: 'Naming';
        Description: 'How the fields of records are named.'),
    (Category: 'NamingMembers'; Id: 'NamesClassFields'; Caption: 'Names of class fields'; Template: 'Naming';
        Description: 'How class var fields are named.'),
    (Category: 'NamingMembers'; Id: 'NamesProperties'; Caption: 'Names of properties'; Template: 'Naming';
        Description: 'How properties are named, except the event properties.'),
    (Category: 'NamingMembers'; Id: 'NamesEventProperties'; Caption: 'Names of event properties'; Template: 'Naming';
        Description: 'How the properties of a procedural type are named: OnClick.'),
    (Category: 'NamingMembers'; Id: 'NamesMethods'; Caption: 'Names of methods'; Template: 'Naming';
        Description: 'How methods are named, except constructors and destructors.'),
    (Category: 'NamingMembers'; Id: 'NamesConstructors'; Caption: 'Names of constructors'; Template: 'Naming';
        Description: 'How constructors are named.'),
    (Category: 'NamingMembers'; Id: 'NamesDestructors'; Caption: 'Names of destructors'; Template: 'Naming';
        Description: 'How destructors are named.'),
    (Category: 'NamingMembers'; Id: 'NamesRoutines'; Caption: 'Names of standalone routines'; Template: 'Naming';
        Description: 'How the procedures and functions that are not methods are named.'),
    (Category: 'NamingMembers'; Id: 'NamesNestedRoutines'; Caption: 'Names of nested routines'; Template: 'Naming';
        Description: 'How the routines declared inside other routines are named.'),
    (Category: 'NamingMembers'; Id: 'NamesParameters'; Caption: 'Names of parameters'; Template: 'Naming';
        Description: 'How the parameters of routines and methods are named.'),
    (Category: 'NamingMembers'; Id: 'PropertyAccessors'; Caption: 'Names of property accessors';
        Description: 'How the methods and fields that read and write a property are named.'),
    // Naming: variables, constants and units
    (Category: 'NamingVariables'; Id: 'NamesLocalVariables'; Caption: 'Names of local variables'; Template: 'Naming';
        Description: 'How the variables of routines are named, except loop counters.'),
    (Category: 'NamingVariables'; Id: 'NamesLoopVariables'; Caption: 'Names of loop counters'; Template: 'Naming';
        Description: 'How the control variables of for loops are named.'),
    (Category: 'NamingVariables'; Id: 'NamesExceptionVariables'; Caption: 'Names of exception variables'; Template: 'Naming';
        Description: 'How the variables of exception handlers are named: on E: Exception do.'),
    (Category: 'NamingVariables'; Id: 'NamesGlobalVariables'; Caption: 'Names of global variables'; Template: 'Naming';
        Description: 'How the variables declared in a unit, outside of routines, are named.'),
    (Category: 'NamingVariables'; Id: 'NamesLocalConstants'; Caption: 'Names of local constants'; Template: 'Naming';
        Description: 'How the constants of routines are named.'),
    (Category: 'NamingVariables'; Id: 'NamesGlobalConstants'; Caption: 'Names of unit constants'; Template: 'Naming';
        Description: 'How the true constants declared in a unit, outside of routines, are named.'),
    (Category: 'NamingVariables'; Id: 'NamesTypedConstants'; Caption: 'Names of typed constants'; Template: 'Naming';
        Description: 'How typed constants are named: MAX_ITEMS: Integer = 10.'),
    (Category: 'NamingVariables'; Id: 'NamesResourceStrings'; Caption: 'Names of resource strings'; Template: 'Naming';
        Description: 'How resourcestring constants are named.'),
    (Category: 'NamingVariables'; Id: 'NamesUnits'; Caption: 'Names of units'; Template: 'Naming';
        Description: 'How units and project files are named.'),
    (Category: 'NamingVariables'; Id: 'FormUnitNames'; Caption: 'Names of the units of forms';
        Description: 'How the unit of a form, frame or data module is named after its class.'),
    (Category: 'NamingVariables'; Id: 'NamesLabels'; Caption: 'Names of goto labels'; Template: 'Naming';
        Description: 'How the labels of goto statements are named.'),
    // Statements
    (Category: 'Statements'; Id: 'WithStatement'; Caption: 'Use of the with statement';
        Description: 'A with statement is used.'),
    (Category: 'Statements'; Id: 'GotoStatement'; Caption: 'Use of the goto statement';
        Description: 'A goto statement or a label is used.'),
    (Category: 'Statements'; Id: 'BooleanComparison'; Caption: 'Comparison with True or False'; Level: cslHint;
        Description: 'A Boolean expression compared with True or False instead of being used as it is or with not.'),
    (Category: 'Statements'; Id: 'EmptyBlocks'; Caption: 'Empty begin-end blocks';
        Description: 'A begin-end has no statements.'),
    (Category: 'Statements'; Id: 'EmptyStatements'; Caption: 'Empty statements'; Level: cslHint;
        Description: 'An extra semicolon that makes an empty statement: if Ready then ; Run;;'),
    (Category: 'Statements'; Id: 'SingleStatementBlocks'; Caption: 'begin-end around a single statement';
        Description: 'Whether a single statement is wrapped in begin-end.'),
    (Category: 'Statements'; Id: 'SemicolonBeforeEnd'; Caption: 'Semicolon before end';
        Description: 'Whether the last statement of a block ends with a semicolon.'),
    (Category: 'Statements'; Id: 'EmptyParenthesesCalls'; Caption: 'Empty parentheses in calls without arguments';
        Description: 'Whether a routine or method is called without arguments with empty parentheses: Run(); or Run;'),
    (Category: 'Statements'; Id: 'ElseAfterJump'; Caption: 'else after Exit, Break, Continue or raise';
        Description: 'An else branch follows a branch that ends with Exit, Break, Continue or raise: the else is not needed.'),
    (Category: 'Statements'; Id: 'InvertIf'; Caption: 'Short else after a long then';
        Description: 'A short else branch follows a long then branch: inverting the condition keeps the short branch next to it.'),
    (Category: 'Statements'; Id: 'CaseElse'; Caption: 'else branch of case statements';
        Description: 'Whether a case statement has an else branch and how many statements it has without begin-end.'),
    (Category: 'Statements'; Id: 'ExitWithValue'; Caption: 'Exit with a value';
        Description: 'Which form returns a value and leaves a routine: Result := Value; Exit or Exit(Value).'),
    (Category: 'Statements'; Id: 'InlineVariables'; Caption: 'Inline variables';
        Description: 'Which variables are declared inside a block: var Index := 0; for var Item in List do.'),
    // Declarations and code order
    (Category: 'Declarations'; Id: 'VisibilityOrder'; Caption: 'Order of visibility sections';
        Description: 'In which order the visibility sections of classes and records go.'),
    (Category: 'Declarations'; Id: 'MemberOrder'; Caption: 'Order of members in a visibility section';
        Description: 'In which order the kinds of members go inside a visibility section.'),
    (Category: 'Declarations'; Id: 'ConstructorsFirst'; Caption: 'Constructors and destructor first';
        Description: 'Constructors and the destructor are not the first methods of a class.'),
    (Category: 'Declarations'; Id: 'LifecycleMethods'; Caption: 'Placement of AfterConstruction and BeforeDestruction';
        Description: 'AfterConstruction and BeforeDestruction do not follow the constructors and the destructor.'),
    (Category: 'Declarations'; Id: 'ImplementationOrder'; Caption: 'Implementation order follows interface';
        Description: 'Routines, classes or methods are implemented in another order than they are declared.'),
    (Category: 'Declarations'; Id: 'HeaderMatch'; Caption: 'Implementation headers repeat declarations';
        Description: 'What the header of an implementation repeats from the declaration.'),
    (Category: 'Declarations'; Id: 'EmptyParenthesesDeclarations'; Caption: 'Empty parentheses in declarations without parameters';
        Description: 'Whether a routine, method or procedural type without parameters is declared with empty parentheses:'
        + ' procedure Run(); or procedure Run;'),
    (Category: 'Declarations'; Id: 'ClassComment'; Caption: 'Comment before the methods of a class';
        Description: 'The methods of a class are not preceded by a comment with the class name: { TMyClass }.'),
    (Category: 'Declarations'; Id: 'StandaloneRoutines'; Caption: 'Placement of standalone routines';
        Description: 'Where the implementations of the routines that are not methods are placed.'),
    (Category: 'Declarations'; Id: 'DeclarationsAfterCode'; Caption: 'Declarations after implementations';
        Description: 'A type, const or var section follows or separates the implementations of routines.'),
    (Category: 'Declarations'; Id: 'LocalSectionOrder'; Caption: 'Order of local declaration sections';
        Description: 'In which order the type, const, var and label sections and the nested routines of a routine go.'),
    (Category: 'Declarations'; Id: 'GlobalVariables'; Caption: 'Use of global variables';
        Description: 'A variable is declared in a unit, outside of routines.'),
    (Category: 'Declarations'; Id: 'ForwardDeclarations'; Caption: 'Use of forward declarations';
        Description: 'Whether forward declarations of classes and routines are used and where.'),
    (Category: 'Declarations'; Id: 'ClassesPerUnit'; Caption: 'Classes per unit';
        Description: 'How many classes a unit declares.'),
    (Category: 'Declarations'; Id: 'ClassParent'; Caption: 'Explicit parent class';
        Description: 'A class derived from TObject does not name its parent: class instead of class(TObject).'),
    (Category: 'Declarations'; Id: 'InheritedCall'; Caption: 'Explicit inherited calls';
        Description: 'What an inherited call names.'),
    (Category: 'Declarations'; Id: 'StringLiterals'; Caption: 'String literals instead of constants';
        Description: 'A string literal is used in the code instead of a constant.'),
    (Category: 'Declarations'; Id: 'MagicNumbers'; Caption: 'Magic numbers';
        Description: 'A number is used in the code instead of a constant.'),
    (Category: 'Declarations'; Id: 'ParameterModifiers'; Caption: 'const for unchanged parameters';
        Description: 'A parameter of a managed type is not changed by the routine, but is not declared const.'),
    (Category: 'Declarations'; Id: 'LocalObjects'; Caption: 'try-finally for local objects';
        Description: 'The code up to the release of a local object is not protected by try-finally.'),
    // Uses clauses
    (Category: 'Uses'; Id: 'UsesPlacement'; Caption: 'Units in the interface or implementation uses';
        Description: 'In which uses clause the units are listed.'),
    (Category: 'Uses'; Id: 'UsesGroups'; Caption: 'Groups of units in uses clauses';
        Description: 'In which groups and in which order the units are listed.'),
    (Category: 'Uses'; Id: 'UnitScopeNames'; Caption: 'Unit scope names';
        Description: 'Whether standard units are named with their unit scope: System.SysUtils or SysUtils.'),
    (Category: 'Uses'; Id: 'UnusedUnits'; Caption: 'Unused units in uses clauses';
        Description: 'A unit is listed that is not needed to compile the module.'),
    // Comments
    (Category: 'Comments'; Id: 'CommentStyle'; Caption: 'Comment style';
        Description: 'Which kind of comment is used.'),
    (Category: 'Comments'; Id: 'CommentSpaces'; Caption: 'Spaces in comments';
        Description: 'How many spaces separate the comment marks from the text.'),
    (Category: 'Comments'; Id: 'TrailingComments'; Caption: 'Comments at the end of a line';
        Description: 'Where comments are written after code on the same line.'),
    (Category: 'Comments'; Id: 'DeclarationComments'; Caption: 'Comments of declarations';
        Description: 'Which declarations have comments and how the comments are written.'),
    (Category: 'Comments'; Id: 'CommentSentences'; Caption: 'Capital letters and periods in comments';
        Description: 'How the text of a comment starts and ends.'),
    (Category: 'Comments'; Id: 'EndComments'; Caption: 'Comments after end';
        Description: 'Whether the end of a block has a comment that names what it closes: end; // if Ready'),
    (Category: 'Comments'; Id: 'TodoComments'; Caption: 'Temporary comments like TODO';
        Description: 'How comments that mark unfinished code are written.'),
    (Category: 'Comments'; Id: 'ForbiddenWords'; Caption: 'Forbidden words in comments and strings';
        Description: 'A forbidden word appears in a comment or a string literal.'),
    (Category: 'Comments'; Id: 'UnitHeaderComment'; Caption: 'Comment at the start of a unit';
        Description: 'A unit does not start with a comment, like a description or a license.'),
    (Category: 'Comments'; Id: 'CommentedOutCode'; Caption: 'Commented-out code';
        Description: 'A comment contains code.'),
    // Language features
    (Category: 'Language'; Id: 'EmptyExcept'; Caption: 'Empty except blocks'; Level: cslHint;
        Description: 'An except block neither handles nor re-raises the exception.'),
    (Category: 'Language'; Id: 'CatchAllExceptions'; Caption: 'Handlers that catch all exceptions';
        Description: 'An except block without on, or with on E: Exception, does not re-raise the exception.'),
    (Category: 'Language'; Id: 'PointerDereference'; Caption: 'Dereference of pointers to records';
        Description: 'How a field is reached through a pointer to a record: Item^.Name or Item.Name.'),
    (Category: 'Language'; Id: 'ExternalRoutines'; Caption: 'Static external routines';
        Description: 'A routine is imported from a library with the external directive.'),
    (Category: 'Language'; Id: 'AsmBlocks'; Caption: 'Use of assembler code';
        Description: 'An asm block or an assembler routine is used.'),
    (Category: 'Language'; Id: 'ForbiddenIdentifiers'; Caption: 'Forbidden identifiers';
        Description: 'A forbidden type, routine or unit is used.'),
    // Metrics
    (Category: 'Metrics'; Id: 'NestingDepth'; Caption: 'Nesting depth of statements';
        Description: 'How deep statements are nested in a routine.'),
    (Category: 'Metrics'; Id: 'RoutineLength'; Caption: 'Routine length';
        Description: 'How many lines the body of a routine has.'),
    (Category: 'Metrics'; Id: 'ParameterCount'; Caption: 'Number of parameters of a routine';
        Description: 'How many parameters a routine has.'),
    (Category: 'Metrics'; Id: 'LocalVariableCount'; Caption: 'Number of local variables of a routine';
        Description: 'How many local variables a routine has.'),
    (Category: 'Metrics'; Id: 'Complexity'; Caption: 'Cyclomatic complexity';
        Description: 'How many independent paths the code of a routine has.'),
    (Category: 'Metrics'; Id: 'UnitLength'; Caption: 'Unit length';
        Description: 'How many lines a unit has.'),
    (Category: 'Metrics'; Id: 'ClassSize'; Caption: 'Number of members of a class';
        Description: 'How many members a class declares.')
  );

  CODE_STYLE_OPTIONS: array[0..246] of TCodeStyleOptionInfo = (
    // Template: spaces around an operator or a punctuation mark
    (Rule: '@Spaces'; Name: 'SpacesBefore'; Caption: 'Spaces before'; Kind: cokQuantity; DefaultValue: 'Exactly:1';
        MinValue: 0; MaxValue: 10; Hint: 'Not checked at the start of a line'),
    (Rule: '@Spaces'; Name: 'SpacesAfter'; Caption: 'Spaces after'; Kind: cokQuantity; DefaultValue: 'Exactly:1';
        MinValue: 0; MaxValue: 10; Hint: 'Not checked at the end of a line'),
    // Template: spaces around an operator or a punctuation mark that may be aligned in columns
    (Rule: '@AlignedSpaces'; Name: 'SpacesBefore'; Caption: 'Spaces before'; Kind: cokQuantity; DefaultValue: 'Exactly:1';
        MinValue: 0; MaxValue: 10; Hint: 'Not checked at the start of a line'),
    (Rule: '@AlignedSpaces'; Name: 'SpacesAfter'; Caption: 'Spaces after'; Kind: cokQuantity; DefaultValue: 'Exactly:1';
        MinValue: 0; MaxValue: 10; Hint: 'Not checked at the end of a line'),
    (Rule: '@AlignedSpaces'; Name: 'AllowAlignment'; Caption: 'Allow more spaces before it to align consecutive lines';
        DefaultValue: CODE_STYLE_FALSE),
    // Template: spaces at brackets
    (Rule: '@Brackets'; Name: 'SpacesBeforeOpening'; Caption: 'Spaces before the opening bracket'; Kind: cokQuantity;
        DefaultValue: 'Any'; MinValue: 0; MaxValue: 10; Hint: 'Not checked at the start of a line'),
    (Rule: '@Brackets'; Name: 'SpacesAfterOpening'; Caption: 'Spaces after the opening bracket'; Kind: cokQuantity;
        DefaultValue: 'Exactly:0'; MinValue: 0; MaxValue: 10; Hint: 'Not checked at the end of a line'),
    (Rule: '@Brackets'; Name: 'SpacesBeforeClosing'; Caption: 'Spaces before the closing bracket'; Kind: cokQuantity;
        DefaultValue: 'Exactly:0'; MinValue: 0; MaxValue: 10; Hint: 'Not checked at the start of a line'),
    // Template: indent of a construct
    (Rule: '@Indent'; Name: 'Indent'; Caption: 'Indent, in block indents'; Kind: cokInteger; DefaultValue: '1';
        MinValue: 0; MaxValue: 4; Hint: '0: flush with the line it is relative to; the size is set by Block indent'),
    // Template: blank lines around a construct
    (Rule: '@BlankLines'; Name: 'LinesBefore'; Caption: 'Blank lines before'; Kind: cokQuantity;
        DefaultValue: 'AtLeast:1'; MinValue: 0; MaxValue: 10),
    (Rule: '@BlankLines'; Name: 'LinesAfter'; Caption: 'Blank lines after'; Kind: cokQuantity;
        DefaultValue: 'AtLeast:1'; MinValue: 0; MaxValue: 10),
    // Template: naming of a kind of identifiers
    (Rule: '@Naming'; Name: 'Case'; Caption: 'Case of the name without prefix and suffix'; Kind: cokChoice;
        DefaultValue: 'Pascal'; Choices: CHOICES_NAME_CASE),
    (Rule: '@Naming'; Name: 'Prefixes'; Caption: 'Required prefix, one of'; Kind: cokTextList; DefaultValue: '';
        Hint: 'One prefix per line; empty: no prefix is required'),
    (Rule: '@Naming'; Name: 'Suffixes'; Caption: 'Required suffix, one of'; Kind: cokTextList; DefaultValue: '';
        Hint: 'One suffix per line; empty: no suffix is required'),
    (Rule: '@Naming'; Name: 'CaseSensitiveAffixes'; Caption: 'Prefixes and suffixes are case sensitive';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: '@Naming'; Name: 'AllowUnderscores'; Caption: 'Allow "_" in PascalCase and camelCase names';
        DefaultValue: CODE_STYLE_FALSE; Hint: 'UPPER_CASE and snake_case names always separate their words with _'),
    (Rule: '@Naming'; Name: 'AllowDigits'; Caption: 'Allow digits in the name'; DefaultValue: CODE_STYLE_TRUE;
        Hint: 'The words of the rule Words with digits are always allowed'),
    (Rule: '@Naming'; Name: 'MinLength'; Caption: 'Minimum length'; Kind: cokInteger; DefaultValue: '1';
        MinValue: 1; MaxValue: 100;
        Hint: 'Of the whole name with the prefix and the suffix; Short identifier names also applies, the longer limit wins'),
    (Rule: '@Naming'; Name: 'MaxLength'; Caption: 'Maximum length'; Kind: cokInteger; DefaultValue: '0';
        MinValue: 0; MaxValue: 255; Hint: 'Of the whole name with the prefix and the suffix; 0: no limit'),
    (Rule: '@Naming'; Name: 'Pattern'; Caption: 'Regular expression of the whole name'; Kind: cokText;
        DefaultValue: ''; Hint: 'Checked in addition to the other options; empty: not used'),
    (Rule: '@Naming'; Name: 'AllowedNames'; Caption: 'Names that are not checked'; Kind: cokTextList; DefaultValue: ''),
    (Rule: '@Naming'; Name: 'ForbiddenNames'; Caption: 'Forbidden names'; Kind: cokTextList; DefaultValue: ''),
    // General
    (Rule: 'Profile'; Name: 'ProfileName'; Caption: 'Profile name'; Kind: cokText; DefaultValue: 'Default'),
    (Rule: 'Scope'; Name: 'ExcludedFiles'; Caption: 'Excluded files'; Kind: cokTextList; DefaultValue: '';
        Hint: 'File masks of the modules that are not checked, like *_TLB.pas, one per line'),
    (Rule: 'Scope'; Name: 'CheckProjectSource'; Caption: 'Check the project source (.dpr, .dpk)';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'Scope'; Name: 'MaxIssuesPerFile'; Caption: 'Maximum issues shown per file'; Kind: cokInteger;
        DefaultValue: '100'; MinValue: 1; MaxValue: 10000),
    (Rule: 'Suppression'; Name: 'Enabled'; Caption: 'Allow suppression comments'; DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'Suppression'; Name: 'LineComment'; Caption: 'Comment that suppresses its line'; Kind: cokText;
        DefaultValue: 'CodeStyle: ignore'),
    (Rule: 'Suppression'; Name: 'OffComment'; Caption: 'Comment that switches the check off'; Kind: cokText;
        DefaultValue: 'CodeStyle: off'),
    (Rule: 'Suppression'; Name: 'OnComment'; Caption: 'Comment that switches the check on again'; Kind: cokText;
        DefaultValue: 'CodeStyle: on'),
    (Rule: 'Columns'; Name: 'TabWidth'; Caption: 'Width of a tab character, spaces'; Kind: cokInteger;
        DefaultValue: '8'; MinValue: 1; MaxValue: 16),
    // Files and lines
    (Rule: 'LineLength'; Name: 'MaxLength'; Caption: 'Maximum line length'; Kind: cokInteger; DefaultValue: '160';
        MinValue: 20; MaxValue: 1000),
    (Rule: 'LineLength'; Name: 'IgnoreCommentLines'; Caption: 'Do not check lines that hold only a comment';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'LineLength'; Name: 'IgnoreStringLines'; Caption: 'Do not check lines that end in a string literal';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'LineLength'; Name: 'IgnoreEndOfLineComment'; Caption: 'Do not count comments at the end of line';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'TrailingSpaces'; Name: 'CheckBlankLines'; Caption: 'Also lines of spaces only'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'TabsInsideLines'; Name: 'AllowInComments'; Caption: 'Allow in comments'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'TabsInsideLines'; Name: 'AllowInStrings'; Caption: 'Allow in string literals'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'LineEndings'; Name: 'Style'; Caption: 'Line break'; Kind: cokChoice; DefaultValue: 'CRLF';
        Choices: 'CRLF=CRLF (Windows)|LF=LF (Unix)|Consistent=Either, but the same in a file'),
    (Rule: 'FileEncoding'; Name: 'Encoding'; Caption: 'Encoding'; Kind: cokChoice; DefaultValue: 'Utf8Bom';
        Choices: 'Utf8Bom=UTF-8 with BOM|Utf8=UTF-8 without BOM|Ansi=ANSI (a Windows code page)|Any=Any'),
    (Rule: 'FileEncoding'; Name: 'AsciiOnly'; Caption: 'Only ASCII characters in the file'; DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'FileStart'; Name: 'MaxBlankLines'; Caption: 'Blank lines at the start, at most'; Kind: cokInteger;
        DefaultValue: '0'; MinValue: 0; MaxValue: 10),
    (Rule: 'FileEnd'; Name: 'FinalLineBreak'; Caption: 'Line break after the last line'; Kind: cokChoice;
        DefaultValue: 'Required'; Choices: CHOICES_REQUIRED),
    (Rule: 'FileEnd'; Name: 'MaxBlankLines'; Caption: 'Blank lines at the end, at most'; Kind: cokInteger;
        DefaultValue: '0'; MinValue: 0; MaxValue: 10),
    (Rule: 'FileEnd'; Name: 'NoTextAfterEnd'; Caption: 'No text after the final end.'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'StatementsPerLine'; Name: 'MaxStatementsPerLine'; Caption: 'Statements per line, at most'; Kind: cokInteger;
        DefaultValue: '1'; MinValue: 1; MaxValue: 10),
    // Blank lines
    (Rule: 'ConsecutiveBlankLines'; Name: 'MaxBlankLines'; Caption: 'Blank lines in a row, at most'; Kind: cokInteger;
        DefaultValue: '1'; MinValue: 0; MaxValue: 10),
    (Rule: 'ConsecutiveBlankLines'; Name: 'MaxInRoutines'; Caption: 'Blank lines in a row inside routines, at most';
        Kind: cokInteger; DefaultValue: '1'; MinValue: 0; MaxValue: 10),
    (Rule: 'BlankLinesInsideBlocks'; Name: 'AfterStart'; Caption: 'Blank lines after the first line of a block';
        Kind: cokQuantity; DefaultValue: 'Exactly:0'; MinValue: 0; MaxValue: 10),
    (Rule: 'BlankLinesInsideBlocks'; Name: 'BeforeEnd'; Caption: 'Blank lines before the end of a block';
        Kind: cokQuantity; DefaultValue: 'Exactly:0'; MinValue: 0; MaxValue: 10),
    (Rule: 'BlankLinesInsideBlocks'; Name: 'IgnoreNestedRoutines'; Caption: 'Do not check around a nested routine';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'BlankLinesBetweenTypes'; Name: 'LinesBetween'; Caption: 'Blank lines between'; Kind: cokQuantity;
        DefaultValue: 'Exactly:1'; MinValue: 0; MaxValue: 10),
    (Rule: 'BlankLinesBetweenRoutines'; Name: 'LinesBetween'; Caption: 'Blank lines between'; Kind: cokQuantity;
        DefaultValue: 'Exactly:1'; MinValue: 0; MaxValue: 10),
    // Indentation
    (Rule: 'BlockIndent'; Name: 'IndentWith'; Caption: 'Characters used for indents'; Kind: cokChoice;
        DefaultValue: 'Spaces'; Choices: 'Spaces=Spaces|Tabs=Tab characters'),
    (Rule: 'BlockIndent'; Name: 'Size'; Caption: 'Number of indent characters in one indent'; Kind: cokInteger;
        DefaultValue: '2'; MinValue: 1; MaxValue: 16),
    (Rule: 'LayoutWords'; Name: 'Words'; Caption: 'Layout words'; Kind: cokTextList;
        DefaultValue: 'program;library;package;unit;interface;implementation;uses;contains;requires;exports;'
        + 'initialization;finalization;end.'),
    (Rule: 'LayoutWords'; Name: 'UnitSections'; Caption: 'Also type, const, var and resourcestring of the unit';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'IndentCompilerDirectives'; Name: 'Position'; Caption: 'Directives start'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: 'FirstColumn=At the start of the line|Code=At the indent of the code|Any=Any'),
    (Rule: 'IndentComments'; Name: 'Position'; Caption: 'Comments start'; Kind: cokChoice; DefaultValue: 'Code';
        Choices: 'Code=At the indent of the code|Any=Any'),
    (Rule: 'IndentComments'; Name: 'AllowFirstColumn'; Caption: 'Also allow the start of the line (commented-out code)';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'IndentLabels'; Name: 'Position'; Caption: 'Labels start'; Kind: cokChoice; DefaultValue: 'Any';
        Choices: 'FirstColumn=At the start of the line|Code=At the indent of the code|Outdented=One level left of the code'
        + '|Any=Any'),
    // Spaces around operators
    (Rule: 'SpacesColonDeclaration'; Name: 'SpacesColonAfter'; Caption: 'Allow more spaces after it to align consecutive lines';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'SpacesWordOperators'; Name: 'SpacesBefore'; Caption: 'Spaces before, next to a word'; Kind: cokQuantity;
        DefaultValue: 'Exactly:1'; MinValue: 1; MaxValue: 10; Hint: 'Not checked at the start of a line'),
    (Rule: 'SpacesWordOperators'; Name: 'SpacesAfter'; Caption: 'Spaces after, next to a word'; Kind: cokQuantity;
        DefaultValue: 'Exactly:1'; MinValue: 1; MaxValue: 10; Hint: 'Not checked at the end of a line'),
    (Rule: 'SpacesWordOperators'; Name: 'SpaceAtBracket'; Caption: 'Space next to a bracket: (A) and (B) or (A)and(B)';
        Kind: cokChoice; DefaultValue: 'Any'; Choices: CHOICES_REQUIRED),
    (Rule: 'SpacesNot'; Name: 'SpacesAfter'; Caption: 'Spaces after, next to a word'; Kind: cokQuantity;
        DefaultValue: 'Exactly:1'; MinValue: 1; MaxValue: 10; Hint: 'Not checked at the end of a line'),
    (Rule: 'SpacesNot'; Name: 'SpaceBeforeBracket'; Caption: 'Space before an opening bracket: not (A) or not(A)';
        Kind: cokChoice; DefaultValue: 'Any'; Choices: CHOICES_REQUIRED),
    // Spaces around punctuation and brackets
    (Rule: 'SpacesCallParentheses'; Name: 'SpacesInsideEmpty'; Caption: 'Spaces inside empty parentheses: Foo()';
        Kind: cokQuantity; DefaultValue: 'Exactly:0'; MinValue: 0; MaxValue: 10),
    (Rule: 'SpacesDeclarationParentheses'; Name: 'SpacesInsideEmpty'; Caption: 'Spaces inside empty parentheses: X()';
        Kind: cokQuantity; DefaultValue: 'Exactly:0'; MinValue: 0; MaxValue: 10),
    (Rule: 'SpacesSetBrackets'; Name: 'SpacesInsideEmpty'; Caption: 'Spaces inside empty brackets: []'; Kind: cokQuantity;
        DefaultValue: 'Exactly:0'; MinValue: 0; MaxValue: 10),
    // Line breaks
    (Rule: 'BeginPlacement'; Name: 'AfterThen'; Caption: 'begin after then'; Kind: cokChoice; DefaultValue: 'NewLine';
        Choices: CHOICES_LINE),
    (Rule: 'BeginPlacement'; Name: 'AfterElse'; Caption: 'begin after else'; Kind: cokChoice; DefaultValue: 'NewLine';
        Choices: CHOICES_LINE),
    (Rule: 'BeginPlacement'; Name: 'AfterDo'; Caption: 'begin after do'; Kind: cokChoice; DefaultValue: 'NewLine';
        Choices: CHOICES_LINE),
    (Rule: 'BeginPlacement'; Name: 'AfterCaseLabel'; Caption: 'begin after a case label'; Kind: cokChoice;
        DefaultValue: 'NewLine'; Choices: CHOICES_LINE),
    (Rule: 'BeginPlacement'; Name: 'RoutineBody'; Caption: 'begin of a routine body'; Kind: cokChoice;
        DefaultValue: 'NewLine'; Choices: CHOICES_LINE),
    (Rule: 'EndPlacement'; Name: 'OwnLine'; Caption: 'end is the only statement of its line';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'EndPlacement'; Name: 'AllowComment'; Caption: 'Allow a comment after end'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'ElsePlacement'; Name: 'AfterEnd'; Caption: 'else after end'; Kind: cokChoice; DefaultValue: 'NewLine';
        Choices: CHOICES_LINE),
    (Rule: 'ElsePlacement'; Name: 'ElseIf'; Caption: 'if after else'; Kind: cokChoice; DefaultValue: 'SameLine';
        Choices: CHOICES_LINE),
    (Rule: 'ConditionKeywords'; Name: 'Then'; Caption: 'then of a wrapped condition'; Kind: cokChoice;
        DefaultValue: 'Any';
        Choices: 'OwnLine=On its own line|EndOfCondition=After the last line of the condition|Any=Any'),
    (Rule: 'ConditionKeywords'; Name: 'Do'; Caption: 'do of a wrapped condition'; Kind: cokChoice;
        DefaultValue: 'Any';
        Choices: 'OwnLine=On its own line|EndOfCondition=After the last line of the condition|Any=Any'),
    (Rule: 'SameLineStatements'; Name: 'AfterThen'; Caption: 'Statement after then'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: CHOICES_LINE),
    (Rule: 'SameLineStatements'; Name: 'AfterElse'; Caption: 'Statement after else'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: CHOICES_LINE),
    (Rule: 'SameLineStatements'; Name: 'AfterDo'; Caption: 'Statement after do'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: CHOICES_LINE),
    (Rule: 'SameLineStatements'; Name: 'AfterCaseLabel'; Caption: 'Statement after a case label'; Kind: cokChoice;
        DefaultValue: 'Any';
        Choices: 'NewLine=On a new line|SameLine=On the same line|Consistent=Either, but the same in a case'
        + '|Any=Any'),
    (Rule: 'SameLineStatements'; Name: 'MaxLineLength'; Caption: 'Maximum length of such a line'; Kind: cokInteger;
        DefaultValue: '0'; MinValue: 0; MaxValue: 1000; Hint: '0: only the line length limit'),
    (Rule: 'UsesLayout'; Name: 'FirstOnNewLine'; Caption: 'The first unit is on the line after uses';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'UsesLayout'; Name: 'MaxUnitsPerLine'; Caption: 'Units per line, at most'; Kind: cokInteger;
        DefaultValue: '0'; MinValue: 0; MaxValue: 50; Hint: '0: no limit, 1: one unit per line'),
    (Rule: 'EnumLayout'; Name: 'Layout'; Caption: 'Elements'; Kind: cokChoice; DefaultValue: 'Any';
        Choices: 'OneLine=The whole enumeration on one line|Any=Any'),
    (Rule: 'EnumLayout'; Name: 'OnePerLineWithValues'; Caption: 'One element per line when an element has a value';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'EnumLayout'; Name: 'MaxOneLineElements'; Caption: 'Elements allowed on one line'; Kind: cokInteger;
        DefaultValue: '0'; MinValue: 0; MaxValue: 100; Hint: '0: no limit, 1: one element per line'),
    (Rule: 'EnumLayout'; Name: 'ClosingParenthesis'; Caption: 'Closing parenthesis'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: CHOICES_CLOSING),
    (Rule: 'ArrayConstantLayout'; Name: 'MaxOneLineElements'; Caption: 'Elements allowed on one line';
        Kind: cokInteger; DefaultValue: '0'; MinValue: 0; MaxValue: 100; Hint: '0: no limit, 1: one element per line'),
    (Rule: 'ArrayConstantLayout'; Name: 'ClosingParenthesis'; Caption: 'Closing parenthesis'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: CHOICES_CLOSING),
    (Rule: 'AnonymousMethodLayout'; Name: 'HeaderAfterAssignment'; Caption: 'Header on the line of :=';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'AnonymousMethodLayout'; Name: 'BodyOnNewLine'; Caption: 'As an argument, the method starts on a new line';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'AnonymousMethodLayout'; Name: 'ClosingParenthesis'; Caption: 'Closing parenthesis of the call';
        Kind: cokChoice; DefaultValue: 'Any'; Choices: CHOICES_CLOSING),
    // Wrapping of long lines
    (Rule: 'ContinuationIndent'; Name: 'Size'; Caption: 'Indent, in block indents'; Kind: cokInteger;
        DefaultValue: '2'; MinValue: 0; MaxValue: 6),
    (Rule: 'ContinuationIndent'; Name: 'Mode'; Caption: 'Continuation lines are'; Kind: cokChoice;
        DefaultValue: 'Either';
        Choices: 'Fixed=Indented by the continuation indent|Aligned=Aligned with the opening bracket'
        + '|Either=Either|Any=Any'),
    (Rule: 'ContinuationIndent'; Name: 'SameForAllLines'; Caption: 'All continuation lines of a statement have one indent';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'OperatorAtLineBreak'; Name: 'BinaryOperators'; Caption: 'Arithmetic and comparison operators';
        Kind: cokChoice; DefaultValue: 'Any'; Choices: CHOICES_LINE_POSITION),
    (Rule: 'OperatorAtLineBreak'; Name: 'LogicalOperators'; Caption: 'and, or, xor'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: CHOICES_LINE_POSITION),
    (Rule: 'OperatorAtLineBreak'; Name: 'Assignment'; Caption: ':='; Kind: cokChoice; DefaultValue: 'LineEnd';
        Choices: CHOICES_LINE_POSITION),
    (Rule: 'OperatorAtLineBreak'; Name: 'Dot'; Caption: 'Member access .'; Kind: cokChoice; DefaultValue: 'Any';
        Choices: CHOICES_LINE_POSITION),
    (Rule: 'OperatorAtLineBreak'; Name: 'Comma'; Caption: 'Comma and semicolon'; Kind: cokChoice;
        DefaultValue: 'LineEnd'; Choices: CHOICES_LINE_POSITION),
    (Rule: 'WrappedHeaders'; Name: 'Allowed'; Caption: 'Headers may be wrapped'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'WrappedHeaders'; Name: 'BreakBetweenParameters'; Caption: 'Breaks only between parameters';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'WrappedHeaders'; Name: 'MaxLines'; Caption: 'Lines of a header, at most'; Kind: cokInteger;
        DefaultValue: '0'; MinValue: 0; MaxValue: 20; Hint: '0: no limit'),
    (Rule: 'WrappedHeaders'; Name: 'WrappedParametersPerLine'; Caption: 'Parameters per line'; Kind: cokInteger;
        DefaultValue: '0'; MinValue: 0; MaxValue: 20; Hint: '0: no limit'),
    (Rule: 'WrappedArguments'; Name: 'OneArgumentPerLine'; Caption: 'One argument per line when wrapped';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'WrappedArguments'; Name: 'ClosingParenthesis'; Caption: 'Closing parenthesis'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: CHOICES_CLOSING),
    (Rule: 'WrappedVariableLists'; Name: 'WrappedVariables'; Caption: 'Instead of wrapping, declare each line with its own type';
        DefaultValue: CODE_STYLE_TRUE),
    // Case of keywords and literals
    (Rule: 'ReservedWordCase'; Name: 'Case'; Caption: 'Reserved words are written'; Kind: cokChoice;
        DefaultValue: 'Lower'; Choices: CHOICES_WORD_CASE),
    (Rule: 'DirectiveCase'; Name: 'Case'; Caption: 'Directives are written'; Kind: cokChoice; DefaultValue: 'Lower';
        Choices: CHOICES_WORD_CASE),
    (Rule: 'StandardIdentifierCase'; Name: 'Case'; Caption: 'Standard identifiers are written'; Kind: cokChoice;
        DefaultValue: 'Declared'; Choices: 'Declared=As declared: Integer, True|Lower=lowercase: integer, true|Any=Any'),
    (Rule: 'HexDigitsCase'; Name: 'Case'; Caption: 'Letters are written'; Kind: cokChoice; DefaultValue: 'Upper';
        Choices: 'Upper=Uppercase: $FF|Lower=Lowercase: $ff'),
    (Rule: 'NumberLiterals'; Name: 'DigitSeparators'; Caption: 'Digit separators _'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: 'Forbidden=Forbidden|Required=Required in long numbers|Any=Any'),
    (Rule: 'NumberLiterals'; Name: 'MinDigitsForSeparators'; Caption: 'Digits of a long number, at least';
        Kind: cokInteger; DefaultValue: '5'; MinValue: 2; MaxValue: 30),
    (Rule: 'NumberLiterals'; Name: 'ExponentCase'; Caption: 'Exponent letter'; Kind: cokChoice; DefaultValue: 'Any';
        Choices: 'Upper=1.5E3|Lower=1.5e3|Any=Any'),
    (Rule: 'NumberLiterals'; Name: 'DigitsPerGroup'; Caption: 'Digits between separators: 1_000_000'; Kind: cokInteger;
        DefaultValue: '3'; MinValue: 1; MaxValue: 8),
    (Rule: 'NumberLiterals'; Name: 'HexDigitsPerGroup'; Caption: 'Digits between separators in hexadecimal numbers: $FFFF_FFFF';
        Kind: cokInteger; DefaultValue: '4'; MinValue: 1; MaxValue: 8),
    (Rule: 'CompilerDirectiveCase'; Name: 'Case'; Caption: 'Directive names are written'; Kind: cokChoice;
        DefaultValue: 'Upper';
        Choices: 'Upper=UPPERCASE: {$IFDEF}|Lower=lowercase: {$ifdef}|Pascal=PascalCase: {$IfDef}|Any=Any'),
    (Rule: 'CompilerDirectiveStyle'; Name: 'Switches'; Caption: 'Switch directives'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: 'Long=Long: {$RANGECHECKS ON}|Short=Short: {$R+}|Any=Any'),
    (Rule: 'ControlCharacters'; Name: 'Style'; Caption: 'Control characters are written'; Kind: cokChoice;
        DefaultValue: 'Hash'; Choices: 'Hash=#13#10|Caret=^M^J|Any=Any'),
    // Naming: general
    (Rule: 'KeywordNames'; Name: 'IncludeDirectives'; Caption: 'Also names of directives'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'KeywordNames'; Name: 'AllowEscaped'; Caption: 'Allow names escaped with &, like &Type';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'ShortNames'; Name: 'MinLength'; Caption: 'Minimum length'; Kind: cokInteger; DefaultValue: '3';
        MinValue: 1; MaxValue: 20; Hint: 'The minimum length of the naming rules also applies, the longer limit wins'),
    (Rule: 'ShortNames'; Name: 'AllowedNames'; Caption: 'Short names allowed everywhere'; Kind: cokTextList;
        DefaultValue: 'E;X;Y'),
    (Rule: 'ShortNames'; Name: 'AllowLoopCounters'; Caption: 'Allow short loop counters and indexes';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'WordsWithDigits'; Name: 'Words'; Caption: 'Words'; Kind: cokTextList;
        DefaultValue: 'Int8;Int16;Int32;Int64;UInt8;UInt16;UInt32;UInt64;Win32;Win64;UTF8;UTF16;Base64;MD5;SHA1;SHA256;'
        + 'X509;IPv4;IPv6;Direct2D;Direct3D'),
    (Rule: 'MethodVerbs'; Name: 'Verbs'; Caption: 'Verbs'; Kind: cokTextList;
        DefaultValue: 'Add;Apply;Assign;Build;Calculate;Can;Check;Clear;Close;Compare;Convert;Copy;Create;Delete;Do;Draw;'
        + 'Execute;Fill;Find;Free;Generate;Get;Has;Hide;Init;Initialize;Insert;Is;Load;Lock;Make;Move;Open;Paint;Parse;'
        + 'Prepare;Process;Read;Receive;Register;Release;Remove;Reset;Run;Save;Search;Select;Send;Set;Show;Sleep;Sort;'
        + 'Start;Stop;Unlock;Unregister;Update;Validate;Write'),
    (Rule: 'MethodVerbs'; Name: 'GroupingPrefixes'; Caption: 'Prefixes allowed before the verb'; Kind: cokTextList;
        DefaultValue: ''; Hint: 'Prefixes that group methods, like Db in DbOpen'),
    (Rule: 'MethodVerbs'; Name: 'SkipEventHandlers'; Caption: 'Do not check event handlers'; DefaultValue: CODE_STYLE_TRUE),
    // Naming: types
    (Rule: 'EnumElementPrefixes'; Name: 'Prefix'; Caption: 'Prefix of the elements'; Kind: cokChoice;
        DefaultValue: 'Common';
        Choices: 'Initials=Initials of the type name: TValueType - vt|Common=Any, but the same for all elements'
        + '|None=No prefix'),
    (Rule: 'EnumElementPrefixes'; Name: 'PrefixCase'; Caption: 'Case of the prefix'; Kind: cokChoice;
        DefaultValue: 'Lower'; Choices: 'Lower=lowercase: alNone|Any=Any'),
    (Rule: 'EnumElementPrefixes'; Name: 'MinLength'; Caption: 'Minimum prefix length'; Kind: cokInteger;
        DefaultValue: '2'; MinValue: 1; MaxValue: 8),
    (Rule: 'EnumElementPrefixes'; Name: 'MaxLength'; Caption: 'Maximum prefix length'; Kind: cokInteger;
        DefaultValue: '4'; MinValue: 1; MaxValue: 8),
    (Rule: 'EnumElementPrefixes'; Name: 'UniqueInUnit'; Caption: 'The prefixes of a unit differ';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'EnumElementPrefixes'; Name: 'SkipScopedEnums'; Caption: 'Do not check enumerations under {$SCOPEDENUMS ON}';
        DefaultValue: CODE_STYLE_TRUE),
    // Naming: members and routines
    (Rule: 'NamesParameters'; Name: 'SkipOverrides'; Caption: 'Do not check overridden methods and event handlers';
        DefaultValue: CODE_STYLE_TRUE; Hint: 'They repeat the parameter names of the inherited method or the event type'),
    (Rule: 'NamesPrivateFields'; Name: 'IncludeClassFields'; Caption: 'Also class var fields'; DefaultValue: CODE_STYLE_FALSE;
        Hint: 'Off: class var fields are checked only by Names of class fields'),
    (Rule: 'NamesProtectedFields'; Name: 'IncludeClassFields'; Caption: 'Also class var fields'; DefaultValue: CODE_STYLE_FALSE;
        Hint: 'Off: class var fields are checked only by Names of class fields'),
    (Rule: 'NamesPublicFields'; Name: 'IncludeClassFields'; Caption: 'Also class var fields'; DefaultValue: CODE_STYLE_FALSE;
        Hint: 'Off: class var fields are checked only by Names of class fields'),
    (Rule: 'NamesPublishedFields'; Name: 'IncludeClassFields'; Caption: 'Also class var fields'; DefaultValue: CODE_STYLE_FALSE;
        Hint: 'Off: class var fields are checked only by Names of class fields'),
    (Rule: 'PropertyAccessors'; Name: 'GetterPrefix'; Caption: 'Prefix of read methods'; Kind: cokText;
        DefaultValue: 'Get'),
    (Rule: 'PropertyAccessors'; Name: 'SetterPrefix'; Caption: 'Prefix of write methods'; Kind: cokText;
        DefaultValue: 'Set'),
    (Rule: 'PropertyAccessors'; Name: 'MatchPropertyName'; Caption: 'Accessor named after its property: GetText for Text';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'PropertyAccessors'; Name: 'FieldMatchesProperty'; Caption: 'Field named after its property, with the field prefix';
        DefaultValue: CODE_STYLE_TRUE; Hint: 'The prefix is taken from the field naming rules: FText, m_Text or Text for Text'),
    // Naming: variables, constants and units
    (Rule: 'FormUnitNames'; Name: 'Format'; Caption: 'Unit name, %s is the class name without its prefix';
        Kind: cokText; DefaultValue: '%s'; Hint: 'Like u%s: the unit of TfmMain is ufmMain when the prefix is T'),
    (Rule: 'FormUnitNames'; Name: 'ClassPrefix'; Caption: 'Prefix dropped from the class name'; Kind: cokText;
        DefaultValue: 'T'),
    // Statements
    (Rule: 'GotoStatement'; Name: 'AllowInAsm'; Caption: 'Allow to enter and leave assembler code';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'EmptyBlocks'; Name: 'AllowWithComment'; Caption: 'Allow an empty block with a comment';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'SingleStatementBlocks'; Name: 'AfterThenElse'; Caption: 'After then and else'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: CHOICES_REQUIRED),
    (Rule: 'SingleStatementBlocks'; Name: 'AfterDo'; Caption: 'After do of loops and with'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: CHOICES_REQUIRED),
    (Rule: 'SingleStatementBlocks'; Name: 'CaseLabels'; Caption: 'After case labels'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: CHOICES_REQUIRED),
    (Rule: 'SemicolonBeforeEnd'; Name: 'Semicolon'; Caption: 'Semicolon before end'; Kind: cokChoice;
        DefaultValue: 'Required'; Choices: CHOICES_REQUIRED),
    (Rule: 'EmptyParenthesesCalls'; Name: 'Parentheses'; Caption: 'Empty parentheses: Run()'; Kind: cokChoice;
        DefaultValue: 'Forbidden'; Choices: CHOICES_REQUIRED),
    (Rule: 'InvertIf'; Name: 'MinThenLines'; Caption: 'then branch of at least, lines'; Kind: cokInteger;
        DefaultValue: '10'; MinValue: 2; MaxValue: 200),
    (Rule: 'InvertIf'; Name: 'MaxElseLines'; Caption: 'else branch of at most, lines'; Kind: cokInteger;
        DefaultValue: '1'; MinValue: 1; MaxValue: 20),
    (Rule: 'CaseElse'; Name: 'Required'; Caption: 'Every case has an else'; DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'CaseElse'; Name: 'MaxStatements'; Caption: 'Statements of else without begin-end, at most';
        Kind: cokInteger; DefaultValue: '0'; MinValue: 0; MaxValue: 50; Hint: '0: no limit'),
    (Rule: 'InlineVariables'; Name: 'AllowInBlocks'; Caption: 'Allow var inside blocks'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'InlineVariables'; Name: 'AllowInLoops'; Caption: 'Allow for var'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'InlineVariables'; Name: 'AllowTypeInference'; Caption: 'Allow inline variables without a type';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'ExitWithValue'; Name: 'PreferredForm'; Caption: 'Preferred form'; Kind: cokChoice; DefaultValue: 'ResultExit';
        Choices: 'ResultExit=Result := Value; Exit|ExitValue=Exit(Value)'),
    // Declarations and code order
    (Rule: 'VisibilityOrder'; Name: 'Order'; Caption: 'Order of the sections'; Kind: cokTextList;
        DefaultValue: 'private;protected;public;published'),
    (Rule: 'VisibilityOrder'; Name: 'StrictFirst'; Caption: 'strict private and strict protected before their sections';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'VisibilityOrder'; Name: 'AllowRepeated'; Caption: 'Allow a section to appear several times';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'VisibilityOrder'; Name: 'MembersBeforeSections'; Caption: 'Members before the first section'; Kind: cokChoice;
        DefaultValue: 'Forms'; Choices: 'Forms=Only in forms, frames and data modules|Never=Never|Always=Always'),
    (Rule: 'MemberOrder'; Name: 'Order'; Caption: 'Order of the kinds of members'; Kind: cokTextList;
        DefaultValue: 'Fields;Methods;Properties';
        Hint: 'Kinds: Constants, Types, Fields, Constructors, Destructors, Methods, Properties, one per line'),
    (Rule: 'ConstructorsFirst'; Name: 'InDeclaration'; Caption: 'In the declaration of the class';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'ConstructorsFirst'; Name: 'InImplementation'; Caption: 'In the implementation of the class';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'ImplementationOrder'; Name: 'CheckRoutines'; Caption: 'Routines'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'ImplementationOrder'; Name: 'CheckClasses'; Caption: 'Classes'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'ImplementationOrder'; Name: 'CheckMethods'; Caption: 'Methods of classes'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'ImplementationOrder'; Name: 'CheckRecordMethods'; Caption: 'Methods of records'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'HeaderMatch'; Name: 'Parameters'; Caption: 'The parameters'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'HeaderMatch'; Name: 'DefaultValues'; Caption: 'The default values of the parameters';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'HeaderMatch'; Name: 'Directives'; Caption: 'The directives (overload, stdcall...)';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'EmptyParenthesesDeclarations'; Name: 'Parentheses'; Caption: 'Empty parentheses: procedure Run()';
        Kind: cokChoice; DefaultValue: 'Forbidden'; Choices: CHOICES_REQUIRED),
    (Rule: 'ClassComment'; Name: 'Format'; Caption: 'Comment, %s is the class name'; Kind: cokText;
        DefaultValue: '{ %s }'),
    (Rule: 'StandaloneRoutines'; Name: 'Placement'; Caption: 'Standalone routines are placed'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: 'First=Before the methods|Last=After the methods|Any=Anywhere'),
    (Rule: 'StandaloneRoutines'; Name: 'Comment'; Caption: 'Comment before the routines'; Kind: cokText;
        DefaultValue: ''; Hint: 'Like { }; empty: no comment is required'),
    (Rule: 'LocalSectionOrder'; Name: 'Order'; Caption: 'Order of the sections'; Kind: cokTextList;
        DefaultValue: 'label;const;type;var'),
    (Rule: 'LocalSectionOrder'; Name: 'NestedRoutines'; Caption: 'Nested routines'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: 'AfterSections=After all sections|Any=Anywhere'),
    (Rule: 'GlobalVariables'; Name: 'AllowFormVariables'; Caption: 'Allow the variables of auto-created forms';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'GlobalVariables'; Name: 'AllowedNames'; Caption: 'Allowed variables'; Kind: cokTextList; DefaultValue: ''),
    (Rule: 'GlobalVariables'; Name: 'AllowImplementation'; Caption: 'Allow variables of the implementation section';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'ForwardDeclarations'; Name: 'Allowed'; Caption: 'Allow forward declarations'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'ForwardDeclarations'; Name: 'AtTop'; Caption: 'Forward declarations at the top of the type section';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'ClassesPerUnit'; Name: 'MaxClasses'; Caption: 'Classes per unit, at most'; Kind: cokInteger;
        DefaultValue: '1'; MinValue: 1; MaxValue: 100),
    (Rule: 'ClassesPerUnit'; Name: 'OnlyInterface'; Caption: 'Count only the classes of the interface section';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'ClassesPerUnit'; Name: 'OnlyFormInFormUnits'; Caption: 'A form unit declares only the form class';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'InheritedCall'; Name: 'RequireMethodName'; Caption: 'Name the method'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'InheritedCall'; Name: 'RequireParameters'; Caption: 'Pass the parameters'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'StringLiterals'; Name: 'AllowEmpty'; Caption: 'Allow empty strings'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'StringLiterals'; Name: 'AllowSingleCharacter'; Caption: 'Allow strings of one character';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'StringLiterals'; Name: 'AllowedStrings'; Caption: 'Allowed strings'; Kind: cokTextList; DefaultValue: ''),
    (Rule: 'StringLiterals'; Name: 'ExceptionTextsUnit'; Caption: 'Unit of the exception texts'; Kind: cokText;
        DefaultValue: ''; Hint: 'Exception messages come from this unit; empty: any constant'),
    (Rule: 'MagicNumbers'; Name: 'AllowedNumbers'; Caption: 'Allowed numbers'; Kind: cokTextList; DefaultValue: '0;1;-1'),
    (Rule: 'ParameterModifiers'; Name: 'Strings'; Caption: 'Strings'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'ParameterModifiers'; Name: 'Records'; Caption: 'Records'; DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'ParameterModifiers'; Name: 'Interfaces'; Caption: 'Interfaces'; DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'ParameterModifiers'; Name: 'DynamicArrays'; Caption: 'Dynamic arrays'; DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'LocalObjects'; Name: 'OneBlockPerObject'; Caption: 'One try-finally per object';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'LocalObjects'; Name: 'AllowSharedBlock'; Caption: 'Allow one block for objects whose variables are nil before try';
        DefaultValue: CODE_STYLE_TRUE),
    // Uses clauses
    (Rule: 'UsesPlacement'; Name: 'Placement'; Caption: 'Units are listed'; Kind: cokChoice; DefaultValue: 'Any';
        Choices: 'Interface=In interface, unless a circular reference|Implementation=In implementation when possible'
        + '|Any=Anywhere'),
    (Rule: 'UsesGroups'; Name: 'Groups'; Caption: 'Groups'; Kind: cokTextList;
        DefaultValue: 'System,Winapi,Vcl,FMX,Data,Xml,Soap,Web,Datasnap,FireDAC,REST,Posix;*';
        Hint: 'One group per line: unit name prefixes separated by commas; * is every other unit'),
    (Rule: 'UsesGroups'; Name: 'GroupOnNewLine'; Caption: 'Every group starts on a new line';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'UsesGroups'; Name: 'BlankLineBetweenGroups'; Caption: 'Blank line between the groups';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'UsesGroups'; Name: 'SortInGroups'; Caption: 'Units sorted alphabetically in a group';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'UnitScopeNames'; Name: 'Scope'; Caption: 'Unit scope'; Kind: cokChoice; DefaultValue: 'Required';
        Choices: CHOICES_REQUIRED),
    // Comments
    (Rule: 'CommentStyle'; Name: 'SingleLine'; Caption: 'Comments of one line'; Kind: cokChoice; DefaultValue: 'Any';
        Choices: CHOICES_COMMENT),
    (Rule: 'CommentStyle'; Name: 'MultiLine'; Caption: 'Comments of several lines'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: CHOICES_COMMENT),
    (Rule: 'CommentSpaces'; Name: 'AfterSlashes'; Caption: 'Spaces after // and ///'; Kind: cokQuantity;
        DefaultValue: 'AtLeast:1'; MinValue: 0; MaxValue: 10),
    (Rule: 'CommentSpaces'; Name: 'InsideBraces'; Caption: 'Spaces inside { } and (* *)'; Kind: cokQuantity;
        DefaultValue: 'Any'; MinValue: 0; MaxValue: 10),
    (Rule: 'TrailingComments'; Name: 'Allowed'; Caption: 'Comments at the end of a line'; Kind: cokChoice;
        DefaultValue: 'Any';
        Choices: 'Never=Never|Code=After statements and declarations, not after routine headers|Any=Anywhere'),
    (Rule: 'TrailingComments'; Name: 'SpacesBefore'; Caption: 'Spaces before the comment'; Kind: cokQuantity;
        DefaultValue: 'AtLeast:1'; MinValue: 0; MaxValue: 20),
    (Rule: 'DeclarationComments'; Name: 'Required'; Caption: 'Declarations that need a comment'; Kind: cokChoice;
        DefaultValue: 'None';
        Choices: 'None=None|Public=Public and published members and routines|Protected=Protected, public and published members and routines'
        + '|All=All members and routines'),
    (Rule: 'DeclarationComments'; Name: 'Style'; Caption: 'Style of the comments'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: 'Line=A comment above the declaration|XmlDoc=/// XML documentation|Any=Any'),
    (Rule: 'DeclarationComments'; Name: 'NoDuplicates'; Caption: 'Comments are not repeated in implementation';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'DeclarationComments'; Name: 'FieldCommentAtProperty'; Caption: 'The comment of a field is repeated at its property';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'DeclarationComments'; Name: 'MinRoutineLines'; Caption: 'A routine needs a comment from this many lines of its body';
        Kind: cokInteger; DefaultValue: '0'; MinValue: 0; MaxValue: 1000; Hint: '0: every routine'),
    (Rule: 'CommentSentences'; Name: 'Capital'; Caption: 'Capital letter at the start'; Kind: cokChoice;
        DefaultValue: 'Any'; Choices: 'Always=Always|Sentences=For sentences|Any=Any'),
    (Rule: 'CommentSentences'; Name: 'Period'; Caption: 'Period at the end'; Kind: cokChoice; DefaultValue: 'Any';
        Choices: 'Always=Always|Sentences=For sentences|Never=Never|Any=Any'),
    (Rule: 'CommentSentences'; Name: 'MinSentenceWords'; Caption: 'Words of a sentence, at least'; Kind: cokInteger;
        DefaultValue: '4'; MinValue: 1; MaxValue: 20; Hint: 'A shorter comment is not a sentence'),
    (Rule: 'CommentSentences'; Name: 'CapitalInDeclarations'; Caption: 'Always a capital letter inside class declarations';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'EndComments'; Name: 'Mode'; Caption: 'Comments after end'; Kind: cokChoice; DefaultValue: 'Allowed';
        Choices: 'Required=Required for long blocks|Allowed=Allowed|Forbidden=Forbidden'),
    (Rule: 'EndComments'; Name: 'MinBlockLines'; Caption: 'Lines of a long block, at least'; Kind: cokInteger;
        DefaultValue: '30'; MinValue: 2; MaxValue: 1000),
    (Rule: 'TodoComments'; Name: 'Markers'; Caption: 'Markers'; Kind: cokTextList; DefaultValue: 'TODO;FIXME'),
    (Rule: 'TodoComments'; Name: 'ReportMarkers'; Caption: 'Report every temporary comment as a reminder';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'TodoComments'; Name: 'ForbiddenMarkers'; Caption: 'Markers that must not be used'; Kind: cokTextList;
        DefaultValue: ''),
    (Rule: 'ForbiddenWords'; Name: 'Words'; Caption: 'Forbidden words'; Kind: cokTextList; DefaultValue: ''),
    (Rule: 'ForbiddenWords'; Name: 'CheckStrings'; Caption: 'Also string literals'; DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'UnitHeaderComment'; Name: 'Pattern'; Caption: 'Regular expression of the comment'; Kind: cokText;
        DefaultValue: ''; Hint: 'Empty: any comment'),
    // Language features
    (Rule: 'EmptyExcept'; Name: 'AllowWithComment'; Caption: 'Allow an except block with only a comment';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'CatchAllExceptions'; Name: 'AllowAtTopLevel'; Caption: 'Allow in the main block and in thread Execute';
        DefaultValue: CODE_STYLE_TRUE),
    (Rule: 'PointerDereference'; Name: 'Form'; Caption: 'Form'; Kind: cokChoice; DefaultValue: 'Explicit';
        Choices: 'Explicit=Explicit: Item^.Name|Implicit=Implicit: Item.Name'),
    (Rule: 'ForbiddenIdentifiers'; Name: 'Names'; Caption: 'Forbidden identifiers'; Kind: cokTextList; DefaultValue: '';
        Hint: 'Like WideString or Application.ProcessMessages, one per line'),
    // Metrics
    (Rule: 'NestingDepth'; Name: 'MaxDepth'; Caption: 'Maximum nesting depth'; Kind: cokInteger; DefaultValue: '5';
        MinValue: 1; MaxValue: 20),
    (Rule: 'RoutineLength'; Name: 'MaxLines'; Caption: 'Maximum lines of a routine body'; Kind: cokInteger;
        DefaultValue: '100'; MinValue: 5; MaxValue: 10000),
    (Rule: 'RoutineLength'; Name: 'CountBlankLines'; Caption: 'Count blank and comment lines';
        DefaultValue: CODE_STYLE_FALSE),
    (Rule: 'ParameterCount'; Name: 'MaxParameters'; Caption: 'Maximum parameters'; Kind: cokInteger; DefaultValue: '7';
        MinValue: 1; MaxValue: 50),
    (Rule: 'LocalVariableCount'; Name: 'MaxVariables'; Caption: 'Maximum local variables'; Kind: cokInteger;
        DefaultValue: '15'; MinValue: 1; MaxValue: 100),
    (Rule: 'Complexity'; Name: 'MaxComplexity'; Caption: 'Maximum complexity'; Kind: cokInteger; DefaultValue: '15';
        MinValue: 2; MaxValue: 100),
    (Rule: 'UnitLength'; Name: 'MaxLines'; Caption: 'Maximum lines of a unit'; Kind: cokInteger; DefaultValue: '3000';
        MinValue: 100; MaxValue: 100000),
    (Rule: 'ClassSize'; Name: 'MaxMembers'; Caption: 'Maximum members of a class'; Kind: cokInteger;
        DefaultValue: '50'; MinValue: 5; MaxValue: 1000)
  );

  CODE_STYLE_DEFAULTS: array[0..69] of TCodeStyleDefaultInfo = (
    // Blank lines
    (Rule: 'BlankLinesNestedRoutines'; Option: 'LinesBefore'; Value: 'Exactly:1'),
    (Rule: 'BlankLinesNestedRoutines'; Option: 'LinesAfter'; Value: 'Exactly:1'),
    (Rule: 'BlankLinesVisibilitySections'; Option: 'LinesBefore'; Value: 'Any'),
    (Rule: 'BlankLinesVisibilitySections'; Option: 'LinesAfter'; Value: 'Exactly:0'),
    (Rule: 'BlankLinesClassComment'; Option: 'LinesBefore'; Value: 'Exactly:1'),
    (Rule: 'BlankLinesClassComment'; Option: 'LinesAfter'; Value: 'Exactly:1'),
    // Indentation
    (Rule: 'IndentCaseBegin'; Option: 'Indent'; Value: '0'),
    (Rule: 'IndentCaseElse'; Option: 'Indent'; Value: '0'),
    (Rule: 'IndentBeginOfStatement'; Option: 'Indent'; Value: '0'),
    (Rule: 'IndentRoutineBody'; Option: 'Indent'; Value: '0'),
    (Rule: 'IndentLocalSections'; Option: 'Indent'; Value: '0'),
    (Rule: 'IndentVisibilitySections'; Option: 'Indent'; Value: '0'),
    (Rule: 'IndentTypeEnd'; Option: 'Indent'; Value: '0'),
    // Spaces around operators
    (Rule: 'SpacesUnary'; Option: 'SpacesBefore'; Value: 'Any'),
    (Rule: 'SpacesUnary'; Option: 'SpacesAfter'; Value: 'Exactly:0'),
    (Rule: 'SpacesAddress'; Option: 'SpacesBefore'; Value: 'Any'),
    (Rule: 'SpacesAddress'; Option: 'SpacesAfter'; Value: 'Exactly:0'),
    (Rule: 'SpacesDereference'; Option: 'SpacesBefore'; Value: 'Exactly:0'),
    (Rule: 'SpacesDereference'; Option: 'SpacesAfter'; Value: 'Any'),
    (Rule: 'SpacesPointerType'; Option: 'SpacesBefore'; Value: 'Any'),
    (Rule: 'SpacesPointerType'; Option: 'SpacesAfter'; Value: 'Exactly:0'),
    (Rule: 'SpacesRange'; Option: 'SpacesBefore'; Value: 'AtMost:1'),
    (Rule: 'SpacesRange'; Option: 'SpacesAfter'; Value: 'AtMost:1'),
    (Rule: 'SpacesDot'; Option: 'SpacesBefore'; Value: 'Exactly:0'),
    (Rule: 'SpacesDot'; Option: 'SpacesAfter'; Value: 'Exactly:0'),
    // Spaces around punctuation and brackets
    (Rule: 'SpacesComma'; Option: 'SpacesBefore'; Value: 'Exactly:0'),
    (Rule: 'SpacesSemicolon'; Option: 'SpacesBefore'; Value: 'Exactly:0'),
    (Rule: 'SpacesColonDeclaration'; Option: 'SpacesBefore'; Value: 'Exactly:0'),
    (Rule: 'SpacesColonCaseLabel'; Option: 'SpacesBefore'; Value: 'Exactly:0'),
    (Rule: 'SpacesColonRecordConstant'; Option: 'SpacesBefore'; Value: 'Exactly:0'),
    (Rule: 'SpacesColonFormat'; Option: 'SpacesBefore'; Value: 'Exactly:0'),
    (Rule: 'SpacesColonFormat'; Option: 'SpacesAfter'; Value: 'Exactly:0'),
    (Rule: 'SpacesCallParentheses'; Option: 'SpacesBeforeOpening'; Value: 'Exactly:0'),
    (Rule: 'SpacesDeclarationParentheses'; Option: 'SpacesBeforeOpening'; Value: 'Exactly:0'),
    (Rule: 'SpacesIndexBrackets'; Option: 'SpacesBeforeOpening'; Value: 'Exactly:0'),
    (Rule: 'SpacesGenericBrackets'; Option: 'SpacesBeforeOpening'; Value: 'Exactly:0'),
    // Naming
    (Rule: 'NamesClasses'; Option: 'Prefixes'; Value: 'T'),
    (Rule: 'NamesRecords'; Option: 'Prefixes'; Value: 'T'),
    (Rule: 'NamesInterfaces'; Option: 'Prefixes'; Value: 'I'),
    (Rule: 'NamesEnumerations'; Option: 'Prefixes'; Value: 'T'),
    (Rule: 'NamesPointerTypes'; Option: 'Prefixes'; Value: 'P'),
    (Rule: 'NamesClassReferences'; Option: 'Prefixes'; Value: 'T'),
    (Rule: 'NamesClassReferences'; Option: 'Suffixes'; Value: 'Class'),
    (Rule: 'NamesExceptionClasses'; Option: 'Prefixes'; Value: 'E'),
    (Rule: 'NamesHelpers'; Option: 'Prefixes'; Value: 'T'),
    (Rule: 'NamesHelpers'; Option: 'Suffixes'; Value: 'Helper'),
    (Rule: 'NamesAttributes'; Option: 'Suffixes'; Value: 'Attribute'),
    (Rule: 'NamesForms'; Option: 'Prefixes'; Value: 'T'),
    (Rule: 'NamesFrames'; Option: 'Prefixes'; Value: 'T'),
    (Rule: 'NamesDataModules'; Option: 'Prefixes'; Value: 'T'),
    (Rule: 'NamesGenericParameters'; Option: 'Prefixes'; Value: 'T'),
    (Rule: 'NamesOtherTypes'; Option: 'Prefixes'; Value: 'T'),
    (Rule: 'NamesPrivateFields'; Option: 'Prefixes'; Value: 'F'),
    (Rule: 'NamesProtectedFields'; Option: 'Prefixes'; Value: 'F'),
    (Rule: 'NamesClassFields'; Option: 'Prefixes'; Value: 'F'),
    (Rule: 'NamesEventProperties'; Option: 'Prefixes'; Value: 'On'),
    (Rule: 'NamesConstructors'; Option: 'Prefixes'; Value: 'Create'),
    (Rule: 'NamesDestructors'; Option: 'AllowedNames'; Value: 'Destroy'),
    (Rule: 'NamesParameters'; Option: 'Prefixes'; Value: 'A'),
    (Rule: 'NamesParameters'; Option: 'AllowedNames'; Value: 'Value;Sender'),
    (Rule: 'NamesLoopVariables'; Option: 'Case'; Value: 'Any'),
    (Rule: 'NamesExceptionVariables'; Option: 'Case'; Value: 'Any'),
    (Rule: 'NamesLocalConstants'; Option: 'Case'; Value: 'Any'),
    (Rule: 'NamesLocalConstants'; Option: 'AllowUnderscores'; Value: CODE_STYLE_TRUE),
    (Rule: 'NamesGlobalConstants'; Option: 'Case'; Value: 'Any'),
    (Rule: 'NamesGlobalConstants'; Option: 'AllowUnderscores'; Value: CODE_STYLE_TRUE),
    (Rule: 'NamesTypedConstants'; Option: 'Case'; Value: 'Any'),
    (Rule: 'NamesTypedConstants'; Option: 'AllowUnderscores'; Value: CODE_STYLE_TRUE),
    (Rule: 'NamesResourceStrings'; Option: 'Prefixes'; Value: 'S'),
    (Rule: 'NamesLabels'; Option: 'Case'; Value: 'Any')
  );

implementation

end.
