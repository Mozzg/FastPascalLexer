# AGENTS.md

Guidelines for AI agents and contributors working in this repository.

This project is a high-performance Pascal tokenizer/lexer and parser for the
Delphi 11 Alexandria compiler. The main deliverable is `TPasLexer` in
`Source/uPasLexer.pas`, a lexer whose single most important design goal is raw
tokenization speed. Every change must respect that goal.

Repository layout:

- `Source/` — production units (`uPasLexer.pas`, `uPasLexerTypes.pas`,
  `uPasParser.pas`, `uPasParserGrammar.pas`, `uPasParserTypes.pas`,
  `uPasParserSettings.pas`, `uPasExceptions.pas`, `uPasLexerPerformance.pas`)
  and the bundled third-party memory manager under `Source/ThirdParty/FastMM5/`.
- `TestApp/` — VCL GUI test/benchmark application (`TestApp.dpr`).
- `UnitTests/` — DUnit test project (`PasLexerTests.dpr`) and test data.
- `PascalLexerGroup.groupproj` — the group project, the repository entry point.

---

## 1. Code style

### Naming conventions

- **Latin letters only.** All code must be written in Latin letters; other alphabets appear only in string constant values and in comments. Names are English and chosen so the name reveals the construct's purpose. Avoid names produced by transliterating Russian words. Choose frequently used names (types, classes, properties, methods, functions) with special care: prefer semantically fitting short, common English words and avoid abbreviations. Example: a method sorting cargo by vehicle → `SortByVehicle`; `SortByTransportFacility` is bad, `SortByTransFclt` very bad, `SrtvPoTS` inadmissible.
- **Reserved words and directives in lowercase**: `type`, `class`, `protected`, `begin`, `inherited`, `stdcall`, etc.
- **`end` of large blocks** may carry a comment naming what the block closed, e.g. `end; // SomeCondition`.
- **UpperCamelCase** for every other construct: each word capitalized, never `_`-separated (`SetNumber`, `ConvertFile`). Exception: constants and names borrowed from external libraries/APIs keep their original style: `STATUS_INVALID_HANDLE = DWORD($C0000008);`.
- **No identifiers matching reserved or IDE-highlighted keywords.**
- **No digits in method names.** Write `PngToBmp`, not `PNG2BMP`; never `Calculate2` — pick a name that states the difference (`CalculateInKilometers` vs `CalculateInMiles`).
- **Method names** follow the template `<verb><adjective><noun>` with the verb always present; a grouping prefix is allowed: `UpdateReturnActsStatus`, `ClsFind`, `ClsListMaxNo`, `ClsPrepareFilter`.
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
- Do not split method headers across lines; restructure instead (e.g. fewer parameters).
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

## 2. Performance focus

This is a lexer where per-byte speed matters. Follow these rules in `Source/`:

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
- **Keep memory manager in mind.** TestApp links FastMM5
  (`Source/ThirdParty/FastMM5/FastMM5.pas`); performance measurements and
  allocations are done with `THighResolutionStopwatch` /
  `TMeasureThread` (`uPasLexerPerformance.pas`). Keep the lexer itself
  allocation-free so these measurements stay meaningful.
- When you change tokenizer behavior, run the full unit test suite (see below)
  — `UnitTests/TestuPasLexerAdditional.pas` exercises most handlers and the
  prefix-tree keyword path.

---

## 3. Building the project (msbuild, current environment)

Environment (this machine):

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
- Build outputs go to `DCU\<Platform><Config>` and `Exe\` per the `.dproj`
  settings. Use the `workdir` of the repository root when building.

### Prerequisite: load the Delphi environment

In PowerShell, run MSBuild inside a `cmd` context that sources `rsvars.bat`,
otherwise `$(BDS)` and the Delphi compiler targets are undefined. Example that
builds the unit-test project (Debug, Win32):

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\22.0\bin\rsvars.bat"" >nul 2>&1 && set PATH=%BDS%\bin;%PATH% && ""C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe"" ""C:\GitHub Repos\FastPascalLexer\UnitTests\PasLexerTests.dproj"" /t:Build /p:Config=Debug /p:Platform=Win32 /v:minimal"
```

### Build the whole solution (group project)

`PascalLexerGroup.groupproj` is the repository entry point and builds
`TestApp` + `PasLexerTests`. Equivalent MSBuild targets:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\22.0\bin\rsvars.bat"" >nul 2>&1 && set PATH=%BDS%\bin;%PATH% && ""C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe"" ""C:\GitHub Repos\FastPascalLexer\PascalLexerGroup.groupproj"" /t:Build /p:Config=Debug /p:Platform=Win32 /v:minimal"
```

Available group targets: `Build`, `Clean`, `Make`, plus per-project
`TestApp`/`TestApp:Clean`/`TestApp:Make` and
`PasLexerTests`/`PasLexerTests:Clean`/`PasLexerTests:Make`.

### Individual projects

- **Unit tests (console):** `UnitTests\PasLexerTests.dproj`
  `AppType=Console`; the `.dproj` defines `CONSOLE_TESTRUNNER`, which makes
  `PasLexerTests.dpr` compile as a console app and DUnit emit text output.
  Build with `Config=Debug|Release`, `Platform=Win32` (or `Win64`).
  Known compiler warnings (W1036 in `uPasParserGrammar.pas`) are pre-existing
  and not errors.
- **GUI test app:** `TestApp\TestApp.dproj` (VCL `AppType=Application`,
  links FastMM5). Debug config defines `DEBUG` (enables
  `ReportMemoryLeaksOnShutdown`); Release defines `RELEASE`.
- Config/Platform variants: Debug/Release x Win32/Win64, all defined in the
  `.dproj` files.

### Run the tests

```powershell
& "C:\GitHub Repos\FastPascalLexer\Exe\PasLexerTests.exe"
```

Expect a trailing line like `OK: 31 tests` (test count grows with the suite).
The console runner prints per-test progress dots and the failure/error summary;
nonzero output means a failing suite. `TestData/` files are read relative to
the repo layout at runtime — run from the repository root.

### After a build

- Outputs land in `Exe\` (`TestApp.exe`, `PasLexerTests.exe`) and DCUs in
  `DCU\<Platform><Config>\`. These are generated artifacts; do not commit them.
- Keep line endings CRLF in any source file you touch (see section 1).
