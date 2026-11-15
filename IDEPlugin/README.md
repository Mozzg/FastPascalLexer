# CodeStyleExpert

Test IDE plugin (DLL expert for RAD Studio / Delphi 11) for the code style feature of
Delphi IDE Code Expert (DICE, `C:\RADStudioProjects\Evgeny\Delphi-IDE-Code-Expert`).
After every compilation of a project it checks the code style of the project modules with
`TPasParser` and adds the issues to the Build tab of the message view, like the compiler messages:

```
[CodeStyle Warning] uMain.pas(12): CS1001 Line is 152 characters long, the limit is 140
[CodeStyle Hint] uOther.pas(40): CS0001 Code style is not checked, the parser failed: ...
Code style: 12 file(s) checked in 35 ms, 3 warning(s), 1 hint(s)
```

A double click on a message moves the editor to the issue, like for the compiler messages.

## Structure

The project folder holds only the project files, the units are in `Source\` of the repository
(a flat folder with `Forms\` for the forms and frames, the same layout as in DICE):

```
IDEPlugin\
  CodeStyleExpert.dpr / .dproj   library project, Win32 only (the IDE is 32-bit)
  movedll.cmd                    pre-build event: renames the DLL that the IDE holds loaded
Source\
  copy of the DICE framework (DICE commit 5c8be6b), NOT moved to DICE:
    uWizardMain.pas              TDICEMainApp: entry point InitWizard, Tools menu item, settings form
                                 (no splash screen, about box and menu item image: no DICE bitmaps)
    uWizardConsts.pas            other ID, name and menu item name than DICE
    uWizardSettings.pas          XML settings (%APPDATA%\CodeStyleExpert\CodeStyleExpert.xml)
    uWizardLog.pas               TWizardLogger: plugin log, the CodeStyleExpert tab of the message view
    uWizardUtils.pas             module file name, file version, menu bitmap
    uBaseFeature.pas             TBaseFeature
    uFeatureCollection.pas       TFeatureCollection.RegisterFeature
    Forms\ufmWizardSettings.pas/.dfm   settings form (no icon: no DICE bitmap)
    Forms\ufrBaseSettings.pas/.dfm     settings frame
  the feature, moved to DICE as is:
    uCodeStyleFeature.pas        TCodeStyleFeature(TBaseFeature): settings, check boxes, compile notifier
    uCodeStyleCompileNotifier.pas  IOTACompileNotifier: starts the check after a project compilation
    uCodeStyleProjectChecker.pas   project files, cache of the checked sources, messages, summary
    uCodeStyleIDEServices.pas      ToolsAPI helpers: project files, editor buffers, AddCompilerMessage
    uCodeStyleChecker.pas          parses one source and runs the rules (no ToolsAPI)
    uCodeStyleRules.pas            issue, check context, base rule, rule set and registration (no ToolsAPI)
    uCodeStyleBasicRules.pas       sample rules CS1001-CS1003 (no ToolsAPI)
    uCodeStyleConsts.pas           codes, texts, settings names
    uCodeStyleProfileCatalog.pas   catalog of the profile: categories, rules, options, defaults (data only)
    uCodeStyleProfile.pas          code style profile: levels and option values, XML settings and files
    uCodeStyleRuleListView.pas     list view of the dialog: scroll bar drag under the IDE theme, double buffering
    Forms\ufmCodeStyleProfile.pas/.dfm  dialog of the profile
  the parser: uPasLexer, uPasLexerTypes, uPasExceptions, uPasParser, uPasParserTypes, uPasParserGrammar
```

Dependencies inside the feature go one way only:

```
uCodeStyleFeature -> uCodeStyleCompileNotifier -> uCodeStyleProjectChecker -> uCodeStyleIDEServices
                                                                           -> uCodeStyleChecker -> uCodeStyleRules
uCodeStyleBasicRules -> uCodeStyleRules
uCodeStyleFeature -> ufmCodeStyleProfile -> uCodeStyleProfile -> uCodeStyleProfileCatalog
                                         -> uCodeStyleRuleListView
```

`uCodeStyleRuleListView` works around a VCL bug: under a VCL style (the IDE theme) `TListViewStyleHook`
scrolls a report view by a fractional number of rows when the scroll bar thumb is dragged, the list
scrolls by whole rows only and the rest of a row is lost on every mouse move, so the thumb falls
behind the mouse. The unit declares an interposer `TListView` (the dialog lists the unit after
`Vcl.ComCtrls`, the form designer still sees the standard class) and registers a style hook for it
that scrolls to the row under the thumb from the real position of the list. Other list views,
also those of the IDE, keep the standard hook; the hook is unregistered when the plugin is unloaded.
The same class also sets `LVS_EX_DOUBLEBUFFER` after every creation of its window (VCL does not set
it, and `ResetExStyles` overwrites the extended styles), so without a VCL style the rows that a fast
scroll shows do not flicker. The list then skips `WM_ERASEBKGND` (it paints its background itself;
`TWinControl.WMEraseBkgnd` would fill the whole list white, and while the thumb is dragged the paint
comes only when the mouse stops) and paints at once after every step of the thumb.

`uCodeStyleChecker`, `uCodeStyleRules`, the rule units and the profile units do not use ToolsAPI, so
they can be used by unit tests and console tools.

## How it works

- `TCodeStyleFeature` is registered with `TFeatureCollection.RegisterFeature` in its
  `initialization` section, like the DICE features. `InitFeature` creates the rule set and the
  project checker, then the base class reads the settings; enabling the feature registers
  `TCodeStyleCompileNotifier` in `IOTACompileServices`. If enabling fails from the settings
  check box (`ApplyCheckBoxState`), the error is shown and the check box returns to the real state.
  `FinalizeFeature` (unloading of the plugin) disables the feature and so unregisters the notifier.
- `ProjectCompileStarted` remembers the compile mode, `ProjectCompileFinished` checks the project:
  its main source (`.dpr`, `.dpk`) and its `.pas` modules. The text is taken from the editor
  buffer when the file is open (also unsaved changes, which the compiler sees too), otherwise from
  the file.
- Make, Compile and Syntax Check check only the sources that changed after the last check of the
  project (hash of the text), like the compiler does not compile unchanged units again; Build
  checks all of them. Saving the settings clears the cache.
- A source with a syntax error is not checked by the rules: one hint `CS0001` with the parser
  error is shown. At most 100 issues per file are shown (`CS0003`).
- Errors of the plugin itself (an exception of the check, of the settings, of a feature) go through
  `TWizardLogger` to the plugin tab of the message view (`CodeStyleExpert`, in DICE `DICE`); the
  Release build logs only errors, the Debug build also information messages.

## Rules

| Code   | Kind    | Rule                                         | Settings (XML)                 |
|--------|---------|----------------------------------------------|--------------------------------|
| CS1001 | lines   | A line is not longer than the limit           | `Enabled`, `MaxLength` (140)   |
| CS1002 | tree    | The `with` statement is forbidden             | `Enabled`                      |
| CS1003 | tokens  | Reserved words in lowercase (not in asm, not `&Type`) | `Enabled`              |

A new rule: a class derived from `TCodeStyleRule` with `GetCode`, `GetDescription` and `Check`
(optionally `GetSeverity`, `ReadSettings`, `WriteSettings`), registered with
`TCodeStyleRuleSet.RegisterRule` in the `initialization` section of its unit. Its check box
appears in the settings by itself. The rule gets `TCodeStyleCheckContext`: the parser with the
tokens, the lines and the lexeme tree (see "Parser" in `AGENTS.md`).

The settings live in the node of the feature:

```xml
<TCodeStyleFeature Enabled="True">
  <Rules>
    <CS1001 Enabled="True" MaxLength="140"/>
    <CS1002 Enabled="True"/>
    <CS1003 Enabled="True"/>
  </Rules>
</TCodeStyleFeature>
```

## Code style profile

The profile holds the settings of all code style rules: what a developer or a team wants checked
and how. It is edited in the dialog behind the "Code style profile..." button of the Code style
section and is stored with the other settings. **The profile is only settings for now: the check
does not use it.** The rules above keep their own settings; later every rule will read its rule of
the profile, and new rules will be added for the rest of the profile.

The profile is built to describe any style, so it is split into small logical units: every rule
is one thing that a style decides, with its own level (Off, Hint, Warning, Error) and its own
options. Spaces are set per operator and punctuation mark (`:=`, `=`, `<>`, `+`, the comma, the
colon of declarations...), naming per kind of identifier (classes, interfaces, private fields,
parameters, local constants...), indents per construct (statements of begin-end, case labels,
visibility sections...), blank lines per construct.

- The catalog (`uCodeStyleProfileCatalog.pas`) lists categories and rules. Option kinds:
  a check box, a number, a text, a list (one item per line), a choice and a count condition: Any,
  Exactly N, At least N or At most N (for example 1 space before `:=` and none after it, or at
  least 1 blank line between routines).
- Rules of one kind share their options through a template (`Rule: '@Spaces'` in the catalog):
  `Spaces` (spaces before and after), `AlignedSpaces` (the same plus the alignment of consecutive
  lines, for `:=`, the comparisons, `=` of declarations and the colons), `Brackets` (spaces before
  and inside brackets), `Indent` (indent in block indents), `BlankLines` (blank lines before and
  after) and `Naming` (case, required prefixes and suffixes, underscores, digits, length, a regular
  expression, allowed and forbidden names). A rule may add own options after the template ones;
  `CODE_STYLE_DEFAULTS` gives a template option another default value for one rule (no space
  before a comma, the prefix I of interfaces).
- A rule offers only values that can occur in valid code: the word operators (`and`, `div`,
  `not`...) need at least one space next to a word, so their counts start at 1 and the space next
  to a bracket is a separate choice; empty brackets are only an option where Delphi allows them
  (`Foo()`, `procedure X()`, `[]`). Where styles differ in both directions, the rule has a choice
  instead of reporting one form (`Exit(Value)` or `Result := Value; Exit`, `Item^.Name` or
  `Item.Name`).
- Every identifier is checked by one naming rule: the specific kinds (exception classes, forms,
  class var fields, typed constants...) have rules of their own, the general rules leave them out
  unless their check box (like "Also class var fields") includes them.
- Some gaps are governed by two rules: the space between `:=` and a unary minus (`:= -1`: the
  spaces after `:=` and before the unary minus), the blank line between `interface` and `uses`
  (blank lines around unit sections and around uses clauses). Then both rules must be satisfied;
  the default values do not contradict each other.
- The defaults follow the common Delphi conventions of the RTL and VCL sources (lowercase
  reserved words, an indent of 2, the prefixes T, I, E, P and F...) and are switched on as hints;
  opinionated rules (with, parameter prefixes, comment rules, metrics...) are switched off. The
  General category holds settings without a level: the profile name, the checked files,
  suppression comments, the width of a tab character.
- The dialog shows the rules under bold category rows (not native list view groups: their headers
  ignore the dark IDE theme) with their level, a filter by text and by state (switched on,
  switched off, changed), the category, the description and the options of the selected rule. A
  rule changed from the defaults has `*` after its level. Load and Save as share a profile as an
  XML file; Defaults and Switch all off reset it. Cancel drops the changes. Neither the dialog nor
  the catalog refers to a particular company or style guide.
- A new rule or option is a line of the catalog: `TestuCodeStyleProfile` checks the catalog (unique
  identifiers that are XML names, used templates, valid defaults) and the default values.

The settings, and a profile file with the root node `CodeStyleProfile Version="1"` instead of
`Profile`, keep one node per category with one node per rule:

```xml
<TCodeStyleFeature Enabled="True">
  <Profile>
    <General>
      <Profile ProfileName="Default"/>
      ...
    </General>
    <Operators>
      <SpacesAssignment Level="Hint" SpacesBefore="Exactly:1" SpacesAfter="Exactly:1" AllowAlignment="False"/>
      ...
    </Operators>
    ...
  </Profile>
</TCodeStyleFeature>
```

A missing node or attribute gives the default value, an invalid value (out of range, an unknown
choice) is ignored, so a profile of an older catalog still loads.

## Build and install

```bash
./build.cmd IDEPlugin/CodeStyleExpert.dproj Debug Win32
```

The DLL is written to `Exe\CodeStyleExpert.dll`. Register it as an expert of Delphi 11 (once),
then restart the IDE:

```bash
reg add "HKCU\Software\Embarcadero\BDS\22.0\Experts" /v CodeStyleExpert /t REG_SZ /d "C:\GitHub Repos\FastPascalLexer\Exe\CodeStyleExpert.dll" /f
```

Like the DICE features, the feature is disabled until it is switched on: Tools > Code Style
Expert Configuration > Code style. A rebuild while the IDE holds the DLL works thanks to
`movedll.cmd` (the old DLL becomes `CodeStyleExpert.dll~`); the new DLL is loaded on the next
start of the IDE. The Debug configuration runs `bds.exe -pDelphi` as the host application.

## Moving the feature to DICE

1. Copy `Source\uCodeStyle*.pas` to `DICE\Source\` and
   `Source\Forms\ufmCodeStyleProfile.pas/.dfm` to `DICE\Source\Forms\`.
2. Make the parser units available to DICE: `uPasLexer`, `uPasLexerTypes`, `uPasExceptions`,
   `uPasParser`, `uPasParserTypes`, `uPasParserGrammar` from `Source\` of FastPascalLexer
   (as a git submodule or a copy).
3. Add the `uCodeStyle*` units, `ufmCodeStyleProfile` and the parser units to the `uses` clause of
   `DICE.dpr` and to the `DCCReference` list of `DICE.dproj` (Project > Add to Project does both). `uCodeStyleBasicRules`
   and `uCodeStyleFeature` must be in the project: their `initialization` sections register the
   rules and the feature.
4. Nothing else changes: of the framework the feature uses only `uBaseFeature`,
   `uFeatureCollection`, `uWizardLog`, `uWizardConsts` (`WIZARD_NAME`) and `ufmWizardSettings` (its
   public part). The copies of `uBaseFeature`, `uFeatureCollection` and `uWizardLog` in `Source\`
   are identical to DICE commit `5c8be6b` (only a header comment is added); the copy of
   `ufmWizardSettings` lacks only the form icon; the copy of `uWizardConsts` has other values, in
   DICE the feature gets the DICE ones. Do not copy the framework units back to DICE. The settings
   go to the `TCodeStyleFeature` node of `DICE.xml`.
5. Remove the test plugin from the `Experts` key, otherwise both check the code.

## Updating the framework copy from DICE

When the DICE framework changes, copy its units over the copies in `Source\` again and compare
them with the DICE commit named in their header comment: keep the header (with the new commit), the
values of `uWizardConsts` and the removed parts listed in the headers of `uWizardMain`,
`uWizardConsts` and `ufmWizardSettings`. Then adapt the `uCodeStyle*` units to the changed API
and add new framework units to `CodeStyleExpert.dpr` and `.dproj`.

## Known limits

- The check runs in the main thread after the compilation. With the background compilation the
  notification may come from the compiler thread; it is skipped there (`// +++` in
  `uCodeStyleCompileNotifier.pas`).
- Only the modules listed in the project are checked, not the units found by the search path, and
  not include files.
- Under the first-branch rule of the parser, mutually exclusive `{$IFDEF}` blocks may give a
  syntax error (hint `CS0001`) for valid code.
- `MaxLength` has no control in the settings form yet, only the XML attribute.
- The code style profile is not used by the check yet (see "Code style profile").
