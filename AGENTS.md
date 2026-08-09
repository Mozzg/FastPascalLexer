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

## 1. Code style (based on existing code)

Base new code on the conventions already present in `Source/` (exclude
`UnitTests/` and `TestApp/` when deriving style; the lexer units are canonical).

### Naming conventions

- **Units**: lower-case `u` prefix, PascalCase rest — `uPasLexer`, `uPasLexerTypes`.
- **Classes / records / types**: `T` prefix — `TPasLexer`, `TTokenKind`, `TPasLexerState`.
- **Enumerated types**: `T` prefix on the type name; values use a short
  lower-case tag prefix — `tkBegin`, `tkIfDefDirective` (`tk...` for token
  kinds), `csNo`, `csCurly` (`cs...` for comment state), `idsIf`, `idsElse`
  (`ids...` for directive state), `emMili` (`em...` for magnitude), `potInteger`
  (`pot...` for option types).
- **Set types**: `T` prefix + `Set` suffix — `TTokenKindSet`.
- **Fields**: `F` prefix — `FLexerState`, `FStartPtr`, `FPrefixTreeRoot`.
- **Parameters**: `A` prefix — `ASource`, `ANewState`, `ATokenKind`.
- **Local variables**: `L` prefix preferred — `LState`, `LS`, `LToken`.
- **Constants**: `UPPER_CASE_SNAKE` for messages/sizes — `PREFIX_TREE_NODE_SIZE`,
  `SIZE_TOKEN_RATIO`, `TOKEN_INCREASE_COUNT`; all-caps for message strings
  declared in `resourcestring` blocks (`EMESSAGE_...`).
- **Methods / properties**: PascalCase — `NextToken`, `SetData`, `TokenID`,
  `TokenString`, `GetIdentifierKindWithTree`.
- **Exception types**: `E` prefix — `EPasBaseException`, `EPasLexerException`,
  `EPasParserException`.
- **Component/Form** (TestApp only): `T` + `fm` prefix — `TfmMainTest`.

### Indentation and layout

- **2 spaces** per indent level. No tabs.
- `begin`/`end` on their own lines; bodies indented one level.
- `case` statement arms: a `case ... of` selector, each arm indented, multi-line
  arms wrapped in `begin ... end`.
- Continued conditions align to a readable depth, operators (`and`, `or`)
  at the end of the line (see `NextTokenNoDirectiveBranching`).
- Blank line between method declarations and between logical sections.
- `interface` uses a `uses` clause; `implementation` adds its own `uses` for
  units used only there (e.g. `uPasLexer.pas` pulls `uPasExceptions` in the
  implementation section).
- Prefix original comment blocks in the lexer/parser units document the class,
  author, license and version — preserve this header format for new units.

### File conventions

- Line endings: **CRLF** for all source files.
- Units named after their content; one primary class per unit.
- New hot-path procedures should be declared as private methods on `TPasLexer`
  and wired into `FillRunProcTable` / `FillPostIdentifierTable` when they are
  character or post-identifier handlers.

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
