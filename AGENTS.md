# AGENTS.md

Guidelines for AI agents and contributors working in this repository.

This project is a high-performance Pascal tokenizer/lexer and parser for the
Delphi 11 Alexandria compiler. The main deliverable is `TPasLexer` in
`Source/uPasLexer.pas`, a lexer whose single most important design goal is raw
tokenization speed. Every change must respect that goal.

Repository layout:

- `Source/` — production units:
  - `uPasLexer.pas`, `uPasLexerTypes.pas` — the lexer `TPasLexer`, token kinds
    and the keyword table.
  - `uPasParser.pas`, `uPasParserGrammar.pas`, `uPasParserTypes.pas` — the
    parser (work in progress, see section 3).
  - `uPasExceptions.pas` — lexer and parser exception classes.
  - `uPasParserSettings.pas` — a stub for future parser settings; not used yet.
  - `uPasLexerPerformance.pas` — measurement tools (`THighResolutionStopwatch`,
    `TMeasureThread`) used by TestApp; not part of the lexer.
  - `ThirdParty/FastMM5/` — the FastMM5 memory manager, a git submodule
    (`pleriche/FastMM5`, pinned commit) used by TestApp.
- `TestApp/` — VCL GUI test/benchmark application (`TestApp.dpr`).
- `UnitTests/` — DUnit test project (`PasLexerTests.dpr`), test units and
  `TestData/`.
- `Benchmark/` — console benchmark of the lexer speed (`LexerBenchmark.dpr`,
  see section 5).
- `build.cmd`, `test.cmd` — build and test scripts (see section 5).
- `PascalLexerGroup.groupproj` — the group project (TestApp, PasLexerTests,
  LexerBenchmark), the repository entry point.

Fresh clone setup:

1. Fetch the FastMM5 submodule (TestApp does not compile without it; the unit
   tests do): `git submodule update --init`, or clone with
   `--recurse-submodules`.
2. The benchmarks (`LexerBenchmark` and TestApp's "Start time test") read
   `UnitTests/TestData/VirtualTrees.pas` (VirtualTreeView 5.3.0, ~1.4 MB,
   MPL 1.1 / LGPL), which is not stored in the repository. Download it into
   `UnitTests/TestData/`:
   `https://raw.githubusercontent.com/JAM-Software/Virtual-TreeView/V5.3.0/Source/VirtualTrees.pas`.
   Without the file everything else works; the benchmarks only report that
   the file is missing.

---

## 1. Code style

### Naming conventions

- **Latin letters only.** All code must be written in Latin letters; other alphabets appear only in string constant values and in comments. Names are English and chosen so the name reveals the construct's purpose. Avoid names produced by transliterating Russian words. Choose frequently used names (types, classes, properties, methods, functions) with special care: prefer semantically fitting short, common English words and avoid abbreviations. Example: a method sorting cargo by vehicle → `SortByVehicle`; `SortByTransportFacility` is bad, `SortByTransFclt` very bad, `SrtvPoTS` inadmissible.
- **Reserved words and directives in lowercase**: `type`, `class`, `protected`, `begin`, `inherited`, `stdcall`, etc.
- **`end` of large blocks** may carry a comment naming what the block closed, e.g. `end; // SomeCondition`.
- **UpperCamelCase** for every other construct: each word capitalized, never `_`-separated (`SetNumber`, `ConvertFile`). Exception: constants and names borrowed from external libraries/APIs keep their original style: `STATUS_INVALID_HANDLE = DWORD($C0000008);`.
- **No identifiers matching reserved or IDE-highlighted keywords.**
- **No digits in method names.** Write `PngToBmp`, not `PNG2BMP`; never `Calculate2` — pick a name that states the difference (`CalculateInKilometers` vs `CalculateInMiles`).
- **Method names** should follow the template `<verb><adjective><noun>` but there can be exceptions; a grouping prefix is allowed: `UpdateReturnActsStatus`, `ClsFind`, `ClsListMaxNo`, `ClsPrepareFilter`.
- **Types/classes prefixed `T`, pointers to them prefixed `P`**: `TObjectArray = array [0..$EFFFFFF] of TObject;` and `PObjectArray = ^TObjectArray;`.
- **Enum elements** carry a prefix taken from the first letters of two or three words of the type name (four or more letters discouraged), lowercase, unique within the module: `TValueType = (vtVariant, vtAnsiString, vtUnicodeString, vtInteger, vtInt64);`.
- **Fields** in `private`/`protected` sections are prefixed `F`; the property exposing the field drops it.
- **Parameters** of constructors/methods/functions/procedures are prefixed `A` (`function MyFunction(var ASumDivider: Byte; ACrossSwitcher: Integer);`); conventional names also apply (`var Value: Byte; Position: Integer`).
- **Loop counters and array indices** may be 1-2 letters with optional digits (`i`, `j`, `i2`); do not overuse — rename to a meaningful word for complex algorithms.
- **Inheriting from `TObject`** must state the parent in parentheses: `class(TObject)`. Declaring a class without a parent is not allowed.
- **`inherited`** calls always name the method and pass its parameters explicitly, even when they match the current header.
- **Property accessors** use `Get`/`Set` prefixes: `GetText`, `SetNum`.
- **Unit names**: form units `u` + form class minus `T` (class starts `Tfm`, e.g. `ufmSales`); frame units `u` + frame class minus `T` (class starts `Tfr`, e.g. `ufrSales`); data module units `u` + data module class minus `T` (class starts `Tdm`, e.g. `udmData`); all other project units are prefixed `u`.
- **Standard unit names** must include the full name, including the unit scope.
- **Hexadecimal constants** use uppercase letters.

### Indentation and layout

- One statement per line. `begin` and `end` never share a line with other commands. `else` always starts its own line, never at the end of the line above (see the `if` rules).
- Assignment, comparison and arithmetic operators, and `=` in constant definitions, are surrounded by spaces: `DestText := UnicodeString(SourceText);`.
- Extra spaces may align consecutive assignments/constants, but this is not recommended; keep `:=` flush against the variable so `ABC :=` stays greppable.
- A space follows `,`, `;` and `:`; never one before them: `procedure ConvertFile(const ASourceFileName, ADestFileName: UnicodeString); register;`.
- Blocks of different logical levels are indented 2 spaces:

  ```
  if FileExists(ADestFileName) then
    lDestFile := TFileStream.Create(ADestFileName, fmOpenReadWrite)
  else
    lDestFile := TFileStream.Create(ADestFileName, fmCreate);
  ```

- Contents of `begin-end`, `asm-end`, `try-finally-end`, `try-except-end`, `repeat-until` and `while-do` blocks are indented 2 spaces.
- The first logical block of a function/method is not shifted relative to the header (e.g. `asm` flush with `procedure`).
- Layout reserved words — `program`, `unit`, `uses`, `implementation`, `initialization`, the final `end.` — are written at the left margin without indent.
- Local `type`/`const`/`var` in a function: the keyword flush with the header, the declarations indented 2 spaces:

  ```
  procedure ConvertFile(const ASourceFileName, ADestFileName: UnicodeString);
  const
    CHUNK_SIZE = 2000;
  var
    Length: Integer;
    SourceText: AnsiString;
    DestText: UnicodeString;
  begin
    ...
  end;
  ```

- Class `private`/`protected`/`public`/`published` keywords are flush with the class name.
- Nested functions: the whole nested function is indented 2 spaces relative to the enclosing function, with one blank line before and after. `var`/`type`/`const` sections always precede nested functions.
- Anonymous methods are indented 2 spaces; when assigned to a variable the header follows `:=` on the same line; as a parameter the body (including local declarations) starts on a new indented line and the caller's closing paren goes on a new line flush with the call.
- Lines must not be much longer than the editor view (about 140 characters). Wrap what does not fit.
- Continued lines are indented **4 spaces** to distinguish them from a 2-space block indent (see the `if` example).
- When wrapping an `if` condition, put `then` on its own line so the end of the condition is visible.
- On a wrapped expression, binary/arithmetic/logical operators begin the next line rather than ending the previous one; exception: `,` and `;` stay at the end of the previous line.
- Avoid splitting method headers across lines: preferably restructure the header so it fits (e.g. fewer parameters, shorter names or directives). When restructuring is not reasonable, a header may be wrapped: break after the `;` between parameters or before the directives, with continuation lines indented 4 spaces.
- Blank lines may separate logical blocks, but never two or more in a row.
- Blocks that receive extra indent (`begin-end`, `asm`, `try-*`, `var`/class sections, etc.) — except nested functions — must not start or end with a blank line.
- Occasional extra spaces for readability are allowed but must not be abused.

### Source code order

- The order of declarations in `interface` matches the order of their implementations in `implementation` — for all definitions, classes and class methods.
- Implementation headers are identical to the declarations: no dropped parameters, no dropped default values.
- Form units declare no classes besides the form class unless they are tightly coupled; other classes go into dedicated units.
- Global variables are forbidden in any form (a `var` section under `interface`). Exceptions: auto-generated form objects and the main application object. Global-like state lives as fields of the main class.
- The main application class is declared in its own unit; its object is created and freed in the `.dpr` inside a `try-finally`, and all global-like state is accessed through it.
- No `var`/`type`/`const` declarations appear after or between function/method implementations in any section.
- Local variables are declared at the start of a method, after local types and constants. Variables of one type may share a line (no line breaks); group by type and purpose.
- Definitions follow "from smaller to larger": base logic, abstract classes, helper/secondary functionality first, the main functionality last. Minimize forward declarations and place them as high as possible.
- Visibility sections are ordered `private`, `protected`, `public`, `published`. A class declares no members before the first visibility section (standard forms excepted). Records may skip sections, but if a record has any, every member lives inside one.
- Functionally similar code is grouped (types, classes, variables, properties, methods).
- No type/const declarations after or between implementations; they belong before any implementation or inside one.
- Before each class or record implementation insert a `{ TCar }` comment (one space inside the braces), separated from the code by one blank line before and one after.
- Standalone functions/procedures come first in `implementation`, preceded by a `{ }` comment separated by blank lines.
- Constructors, then the destructor, come first in `public` and first in the implementation section.
- `AfterConstruction`/`BeforeDestruction`, when defined, come right after the constructors/destructor in both sections.
- Class methods appear in the implementation section in the same order as in the interface; group class methods together.
- All text data is extracted into string constants: a local `const` for method-local text, the `interface` const section (or a dedicated unit) when shared, and a dedicated unit for exception text.
- Avoid "magic numbers"; extract them to local or global constants.

### Comments and other textual data

- Comments are mandatory for complex algorithms and for functions/methods whose purpose cannot be inferred from the name. Domain-specific modules carry a module-level comment. Commenting is a necessary attribute of good code — there is no "self-documenting" application more complex than a calculator.
- A usage comment for a function/method is written in `interface` one line above the declaration and is not duplicated in `implementation`.
- A comment for a local variable, field or property is written one line above it, whenever its use is not obvious.
- When a field backs a property, the comment is duplicated at the property declaration.
- In-code comments start at the indent of the current logical block. Short comments use `//`; tiny comments may trail a statement or variable line, but never a function/method declaration.
- A few words may start lowercase without a period; complete sentences start with a capital letter and end with a period.
- Inside a class declaration, comments always start with a capital letter.
- Texts are written without mistakes and with correct punctuation.
- Error messages are written even more carefully — they reach users: capital letter, ending period, no profanity.
- Temporary comments that must be revisited start with `// +++` so they are searchable.
- Temporary code segments use `{$MESSAGE Warn '...'}` so the IDE surfaces a persistent reminder.

### Language constructs

- **Strings.** The string type is always explicit: `AnsiString` for ANSI strings; `WideString` for Unicode on Delphi up to 2007; `string` for Unicode from Delphi 2009. New code is Unicode-oriented; `AnsiString` is used only for specific tasks. A string parameter must have an explicit kind (`const`, `var`, `out`); unmodified strings are `const`.
- **case.** Labels are indented 2 spaces relative to `case` and aligned; each arm's statements go on the next line with a further 2-space indent, and a `begin-end` wrap carries no extra indent. Single-instruction arms may sit on the label line (space after the colon), but if any arm has several statements, all arms move to the next line. `else` is flush with `case`, its body indented 2 spaces; `// of case` comments are allowed; an `else` body of more than 2 commands is wrapped in `begin-end`. Variant records follow the same rules, with parentheses instead of `begin-end`.
- **if.** `else` is written on its own line at the indent of its `if`; `else if` stays on one line. A one-line `if Condition then Op1 else Op2` is allowed only without `begin`/`end` and at most 50 characters; a short condition with a short statement may share a line. Do not overuse either. When the `else` branch is short and the `if` branch is bulky, invert the condition and swap the branches. When one branch ends in `Exit`, `Break`, `Continue` or `raise`, invert the condition so the interrupting statement stands alone without `else`. Do not compare a `Boolean` with `True`/`False` — use the variable or `not`:

  ```
  if lServerAvailable and (not lConnectError) then
  begin
    <...Code...>
  end;
  ```

- **with** is categorically forbidden.
- **try-except / try-finally.** The `except` block must handle or re-raise the exception — never empty. Code that could deadlock or block the UI on exception, and all thread synchronization, goes into `try-finally`. Local objects: everything up to the release is inside `try-finally`, one block per object so a constructor exception cannot leak an earlier object (combining objects in one block is allowed only when an exception on any line is accounted for — see the `TestMemoryLeak`/`WrongTestMemoryLeak` pattern).
- **Enumerated types.** Elements are written either on one line or one per line; if any element has an explicit value, every element goes on its own line, indented 2 spaces, closing paren at the enumeration name's indent. The one-line form must respect the 140-character rule.
- **Constant arrays.** One element per line, indented 2 spaces relative to the array name; the closing paren goes on its own line at the array name's indent.
- **Pointers.** Typed pointers are always dereferenced with `^`.
- **uses.** List only units needed to compile the module; put all units in `interface` except circular-reference units (those go in `implementation`). Order: standard Delphi units (with unit scope), third-party libraries, company/common units, project units — each group starts on a new line. Qualify ambiguous identifiers explicitly (`uStrings.FormatDateTime`, `System.Delete`, `uDataRecords.TDataType`).
- **goto / label** are forbidden, except for entering and leaving an assembler block — and should be avoided even there.
- **External functions** from libraries not covered by the standard Delphi units are always linked dynamically, checking that the library and function exist and handling errors; static `external` linking is not allowed.

### Exceptions and memory leaks

- Use structural exception handling. All errors raise exceptions whose messages carry detailed cause information (error code, detailed text, object identifiers).
- Do not use `Result` to signal an error — it conveys only that one happened, not why. It may signal success only when error types are strictly enumerated or map unambiguously to result values.
- No object or memory leaks: every object, allocation and handle is released/finalized after use, including when any exception (up to `EOutOfMemory`) is raised along the way.

### File conventions

- Line endings: **CRLF** for all source files.
- Units named after their content; one primary class per unit.
- Prefix original comment blocks in the lexer/parser units document the class, author, license and version — preserve this header format for new units.

---

## 2. Project-specific rules

Section 1 is the company-wide coding standard and is kept verbatim. The rules
below add project-specific details and exceptions; where they differ from
section 1, they take precedence.

### Exceptions to section 1

- **DUnit test names.** Test units are named `Test<UnitName>` (e.g.
  `TestuPasLexer`) and test classes `Test<ClassName>` (e.g. `TestTPasLexer`),
  following the DUnit wizard convention instead of the `u`/`T` prefix rules.
- **TestApp has no main application class.** TestApp is an internal test
  stand; its state may live in the form (`TfmMainTest`).
- **Parameter prefix `A`** is mandatory for every parameter, except when a
  method overrides or mirrors an RTL/VCL signature: `Sender` in event
  handlers, `Msg`/`Args` as in `Exception.CreateFmt`, `Value` in
  IDE-generated property setters.
- **Comment language.** Comments may be written in English or Russian.
  Identifiers stay English (section 1).

### Additional rules

- **Line length.** In new and modified code a line must not exceed 140
  characters (a hard limit). Do not rewrap existing long lines the task does
  not touch.
- **No inline variables.** Inline `var` declarations inside a block and
  `for var` loops are forbidden; declare all locals at the start of the
  method.
- **Language features on the lexer hot path.** Generics and anonymous methods
  are allowed in general, but not on the lexer hot path (`NextToken*` and the
  `*Handler` methods): no anonymous methods there (they allocate and are
  called through an interface) and no generic collections — only the existing
  `TArray<>` fields of `TPasLexerState`.

### Wrapping long lines

Examples of the wrapping rules of section 1. Every continuation line is
indented **4 spaces** relative to the first line of the statement (all
continuation lines of one statement use the same indent, it does not grow);
binary and logical operators start the continuation line, while `,` stays at
the end of the wrapped line.

Wrapped `if` condition — `then` on its own line, at the indent of `if`:

```pascal
  if (FLexerState.CurrentToken in CONDITIONAL_TOKENS)
      and (Length(FLexerState.IfDirectiveStateArray) > 0)
  then
  begin
    ...
  end;
```

Wrapped parameter list — the line ends with `,`:

```pascal
      raise EBenchmarkError.Create(EXIT_CODE_LEXER_FAILURE,
          Format(EMESSAGE_LEXER_EXCEPTION, [FLexer.LexerState.CurrentLine, E.ClassName, E.Message]));
```

Multi-line string constant — the value starts on the line of `=`, `+` starts
each continuation line:

```pascal
  EMESSAGE_FILE_NOT_FOUND = 'Input file "%s" does not exist.'
      + sLineBreak + 'Download VirtualTrees.pas into UnitTests\TestData,'
      + sLineBreak + 'or pass another Pascal source with -file <path>.';
```

Wrong — a 2-space continuation looks like a nested block, and the operator
hides at the end of the line:

```pascal
  EMESSAGE_FILE_NOT_FOUND =
    'Input file "%s" does not exist.' + sLineBreak +
    'or pass another Pascal source with -file <path>.';
```

### Files not to change

- `Source/ThirdParty/` — third-party code (git submodule). Do not edit it;
  move the submodule to another upstream commit only when asked.
- `UnitTests/TestData/` — test input. The files intentionally contain unusual
  or non-standard code; do not fix or reformat them. Adding new test data
  files is fine.
- `*.dproj`, `*.groupproj` — edit only surgically (unit list, options); never
  reformat or regenerate them. When adding or removing a unit, change the
  `.dpr` `uses` clause and the `.dproj` `DCCReference` list together. Do not
  edit `*.res` files. A build may rewrite the tracked `*.res` files (version
  info); unless the task is about resources, restore them with
  `git checkout -- <file>.res` after building.
- IDE local state — `*.local`, `*.identcache`, `__history/`, `__recovery/`:
  do not create, modify or delete.
- License texts — `LICENSE` and the header comment blocks of units (author,
  license, version): do not change or remove.

---

## 3. Lexer and parser

### Lexer contract

Read `README.md` before changing lexer behavior: it explains that whitespace
and comment tokens are emitted by design and that `SetData` already produces
the first token. In addition:

- **The lexer does not own its input.** `SetData(var ADataString: string)`
  stores a raw pointer into the caller's string. The string must stay alive
  and unmodified until lexing is finished.
- **End of input is the terminating `#0`** of the Delphi string (`#0` is
  dispatched to `NullHandler`, which yields `tkEOF`); a `#0` inside the text
  also ends tokenization.

### Parser (work in progress)

`TPasParser` (`uPasParser.pas`) loads a file or a string (`ParseFile`,
`ParseString`), feeds it to its own `TPasLexer` and builds a tree of grammar
nodes derived from `TBaseLexemeNode` (`uPasParserGrammar.pas`). Shared types
live in `uPasParserTypes.pas`; errors are raised with the exception classes
from `uPasExceptions.pas`. The parser is under active development and is not
covered by unit tests yet (the tests use only `TPasParser.GetFileDataString`).

### Performance rules

Raw tokenization speed is the main design goal. The rules below are mandatory
for the lexer (`uPasLexer.pas`, `uPasLexerTypes.pas`), above all for its hot
path. The parser may allocate (it creates tree nodes) and use virtual methods,
but must avoid needless work.

**Measure every change of the lexer hot path** with the console benchmark
(section 5, "Measuring lexer speed"): run it before and after the change and
put both `MedianMs` values into your report. The change must not raise
`MedianMs` beyond run-to-run noise.

- **No allocations on the hot path.** `NextToken` and all `*Handler` methods
  must not allocate strings, objects, or dynamic arrays. Token text is produced
  lazily by `TokenString` (a `SetString` off `FStartPtr`). Never cache an
  intermediate `string` per token.
- **Dispatch via lookup tables, not chained comparisons.** Character dispatch
  uses `FRunHandlers: array[#0..#127] of TRunProcedure`; keyword lookup uses the
  class-level prefix tree `FPrefixTreeRoot` plus `FCharHashTable` for O(1)
  character hashing. Add to the tables, do not replace them with `case`
  over characters inside the hot loop.
- **Pointer arithmetic over index math.** Keep `PChar` cursors (`FStartPtr +
  index`) and `Cardinal`/`Integer` indices; avoid `AnsiChar`/`Char` conversions
  in inner loops.
- **Use `Move`, `CompareMem`, `FillChar`, `SetLength` sizing once.** Copying
  lexer state copies only the leading fixed-size part with a single `Move` and
  then deep-copies the two dynamic arrays (see `TPasLexerState.CopyFrom`).
- **Pack records that are copied by raw pointer** (`TPasLexerState` is
  `packed` for this reason).
- **Initialize shared read-only data once.** Class constructors
  (`ClassCreate`/`ClassDestroy`) build the hash table and prefix tree; guard
  with `Assigned` checks.
- **Use `inline` sparingly and only where it wins**, and gate it so it can be
  turned off for debugging: `{$IFDEF RELEASE} inline;{$ENDIF}`.
- **Prefer sets and `in` tests** for token classification, and constants for
  message strings instead of building them per call.
- **Do not add indirection that a benchmark would notice** — no interfaces,
  virtual calls, or RTTI in the lexing loop.
- **Keep the 64-bit build in mind.** Both Win32 and Win64 are built and
  tested; use `NativeInt`/`NativeUInt` for pointer-sized values and never
  cast pointers to `Integer`/`Cardinal`.
- **Keep memory manager in mind.** TestApp links FastMM5
  (`Source/ThirdParty/FastMM5/FastMM5.pas`); performance measurements and
  allocations are done with `THighResolutionStopwatch` /
  `TMeasureThread` (`uPasLexerPerformance.pas`). Keep the lexer itself
  allocation-free so these measurements stay meaningful.

---

## 4. Tests

- Every change of lexer behavior and every bug fix comes with a test.
- Tests on code fragments go into `UnitTests/TestuPasLexerAdditional.pas` and
  use its helpers (`GetTokens`, `GetTokensNoJunk`, `CheckTokensEqual`,
  `CheckTokenEquals`). Tests that read files from `UnitTests/TestData/` go
  into `UnitTests/TestuPasLexer.pas`.
- Test methods are named `Test<WhatIsChecked>` (e.g.
  `TestNumbersExponentAndHex`) and declared in the `published` section.
- Build test data paths relative to the executable, as the existing tests do:
  `ExtractFilePath(ParamStr(0)) + '..\UnitTests\TestData\<file>'`.
- Do not delete or weaken existing tests without the user's consent. The
  number of tests must not drop unless tests were removed on purpose.
- `TestuPasLexerAdditional.pas` exercises most handlers and the prefix-tree
  keyword path; run the full suite after every change (`test.cmd`, section 5),
  on Win32 and, for low-level changes, on Win64 too.
- The test project also compiles `uPasParserSettings.pas` and
  `uPasLexerPerformance.pas` so that their compilation is checked; they have
  no tests.

---

## 5. Building and running

### Scripts (preferred)

Two scripts in the repository root load the Delphi environment and call
MSBuild. They work from cmd, PowerShell (`.\test.cmd`) and Git Bash
(`./test.cmd`), and the current directory does not matter.

- `test.cmd [Platform]` — builds `UnitTests\PasLexerTests.dproj` in the
  `Console` configuration and runs the tests. `Platform` is `Win32`
  (default) or `Win64`.
- `build.cmd [Project] [Config] [Platform]` — builds one project. `Project`
  is a path relative to the repository root, with `\` or `/` separators
  (default `PascalLexerGroup.groupproj`); `Config` is `Debug` (default),
  `Release` or `Console` (tests only); `Platform` is `Win32` (default) or
  `Win64`. Example: `build.cmd TestApp/TestApp.dproj Debug Win64`.
- Exit code 0 means success. On another machine set `DELPHI_RSVARS` (path to
  `rsvars.bat` of Delphi 11) and `MSBUILD_EXE` (path to `MSBuild.exe`).

**Agents run the tests only through `test.cmd` (or a `Console` build).** The
`Debug` and `Release` configurations of `PasLexerTests` build the DUnit GUI
runner: running that executable opens a window and blocks the session. Those
configurations are for interactive use in the IDE.

### Test result

- Success: `test.cmd` exits with code 0 and the output ends with
  `OK: N tests`.
- Failure: a nonzero exit code — either the build failed (`test.cmd` prints
  "the build failed") or the runner halted with exit code Errors + Failures;
  the output lists each error and failure after `There was N failure` /
  `There were N errors`.
- Test data is located relative to the executable, so `PasLexerTests.exe` must
  stay in `Exe\`; the current directory does not matter.

### Measuring lexer speed

`Benchmark\LexerBenchmark.dproj` is a console benchmark (FastMM5 linked, like
TestApp). Each pass is `SetData` + `while NextToken do` over the whole text,
without `TokenString`. A validation pass checks that the text is tokenized
without errors, then warm-up passes and measured passes run at high process
priority with power throttling disabled, and every measured pass must yield
the same token count. The warm-up lasts until both a minimum pass count and a
minimum duration are reached: an idle CPU needs up to ~10 ms to reach its full
clock, and passes started earlier are up to ~2 times slower.

- Build in `Release Win32` — the variant to compare numbers in:
  `build.cmd Benchmark/LexerBenchmark.dproj Release Win32`.
- Run `Exe\LexerBenchmark.exe` (defaults: warm-up of at least 10 passes and
  at least 200 ms, then 500 measured passes over
  `UnitTests\TestData\VirtualTrees.pas`, about 3 s). Switches (`-` or `/`,
  value as the next parameter or after `:`): `-file <path>`,
  `-iterations <n>`, `-warmup <n>` (minimum warm-up passes),
  `-warmuptime <ms>` (minimum warm-up duration), `-trace` (also print every
  measured pass in run order), `-help`.
- Output: one `Key: Value` line each (`Build`, `Priority`, `PowerThrottling`,
  `File`, `FileSizeBytes`, `Characters`, `Tokens`, `WarmupPasses`,
  `WarmupMs`, `Iterations`, `MinMs`, `MedianMs`, `MeanMs`, `MaxMs`,
  `MedianMBPerSecond`, `MedianMTokensPerSecond`; with `-trace` also
  `PassMs[N]` for every measured pass), ending with `Result: OK`.
  `WarmupPasses` and `WarmupMs` are the actual warm-up.
- Compare `MedianMs` (lower is better). Back-to-back runs differ by about
  0.5 %, single passes by up to ±10-15 %, but series taken at different times
  differ by up to ~4 % because of other load on the machine. Compare variants
  only within one series: run each variant several times, alternating them.
- Exit codes: 0 success, 1 input file not found, 2 invalid parameter,
  3 lexer error (exception, unbalanced counters or a changed token count),
  4 unexpected error. On failure the error goes to stderr and stdout ends with
  `Result: FAILED (exit code N)`.
- Started in a console window of its own (from the IDE or Explorer), the
  benchmark waits for Enter before exiting so the output stays readable. It
  does not wait when started from a command prompt or with redirected input
  or output, so automated runs never block.
- The numbers are lower than TestApp's "Start time test", which also calls
  `TokenString` for every token. Compare only runs of the same build variant
  on the same machine.

### Environment (this machine)

- Delphi 11 Alexandria installed at `C:\Program Files (x86)\Embarcadero\Studio\22.0`
  (also a Delphi 10.4 install at `...\Studio\21.0`; use 22.0).
- The environment is prepared by `rsvars.bat`:
  `C:\Program Files (x86)\Embarcadero\Studio\22.0\bin\rsvars.bat`
  (sets `BDS`, PATH, etc.).
- MSBuild: use the .NET Framework 4.0 build engine at
  `C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe`.
  Plain `msbuild` is **not** on PATH; always call it with the full path.
- DUnit sources live at `$(BDS)\Source\DUnit\src` (the test project already
  adds this to `DCC_UnitSearchPath`).

### Calling MSBuild directly

Only needed when the scripts do not fit. Run MSBuild inside a `cmd` context
that sources `rsvars.bat`, otherwise `$(BDS)` and the Delphi compiler targets
are undefined. PowerShell example that builds the unit tests for automated
runs (Console, Win32):

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\22.0\bin\rsvars.bat"" >nul 2>&1 && set PATH=%BDS%\bin;%PATH% && ""C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe"" ""C:\GitHub Repos\FastPascalLexer\UnitTests\PasLexerTests.dproj"" /t:Build /p:Config=Console /p:Platform=Win32 /v:minimal"
```

The group project `PascalLexerGroup.groupproj` builds `TestApp`,
`PasLexerTests` and `LexerBenchmark`. Available group targets: `Build`,
`Clean`, `Make`, plus per-project `<Project>`, `<Project>:Clean` and
`<Project>:Make` for each of the three projects.

### Projects and configurations

- **Unit tests:** `UnitTests\PasLexerTests.dproj` — configurations `Debug`,
  `Release` (GUI runner) and `Console` (based on `Debug`, defines
  `CONSOLE_TESTRUNNER`: console app, text output, exit code), platforms
  `Win32` and `Win64`. Builds without compiler warnings.
- **GUI test app:** `TestApp\TestApp.dproj` (VCL, links FastMM5) —
  configurations `Debug` (defines `DEBUG`, enables
  `ReportMemoryLeaksOnShutdown`) and `Release` (defines `RELEASE`), platforms
  `Win32` and `Win64`. Do not add files from `UnitTests\TestData\` to a
  project: they are test input and may not compile in every configuration.
- **Console benchmark:** `Benchmark\LexerBenchmark.dproj` — configurations
  `Debug` and `Release` (default), platforms `Win32` and `Win64`.
- All configurations and platforms write the executables to the same `Exe\`
  folder, so the last build wins: build the variant you intend to run right
  before running it. DCUs go to `DCU\<Platform><Config>\`.

### After a build

- Outputs in `Exe\` and `DCU\` are generated artifacts; do not commit them.
- Keep line endings CRLF in any source file you touch (see section 1).

---

## 6. Git workflow

- **Always ask before committing or pushing.** Before any `git commit` or
  `git push` (including `--amend`, merge commits and pushed tags), show the
  user the repository, branch, files to be committed and the commit message,
  and wait for an explicit "yes" in chat. One approval covers one commit only.
- Do not stage (`git add`) files the user has not asked to commit.
- Never commit build outputs (`Exe\`, `DCU\`) or agent docs (`AGENTS.md`,
  `CLAUDE.md`) unless the user explicitly asks for it.
- FastMM5 is a submodule: never commit changes inside
  `Source/ThirdParty/FastMM5`. When the pinned commit changes after a pull,
  run `git submodule update --init`.
