unit TestuPasLexerAdditional;

{
  Additional tests for TPasLexer.
  The goal of this suite is to exercise as much of TPasLexer as possible:
  every run handler (tokens), the post-identifier handlers, the compiler
  directive logic, the prefix tree keyword matching and the public API.
}

interface

uses
  System.SysUtils, TestFramework,
  uPasLexer, uPasLexerTypes, uPasExceptions;

type
  TestTPasLexerAdditional = class(TTestCase)
  private
    FPasLexer: TPasLexer;
    // Lexes ASource completely and returns the token sequence, including the token
    // active right after SetData; the trailing tkEOF after NextToken returns False
    // is not included.
    function GetTokens(const ASource: string): TTokenKindArray;
    // Same as GetTokens, but skips the tokens of DIRECTIVE_UNSIGNIFICANT_TOKENS.
    function GetTokensNoJunk(const ASource: string): TTokenKindArray;
    // Fails the test when the two sequences differ in length or in any element,
    // reporting the first mismatch as index and both token names.
    procedure CheckTokensEqual(const AExpected, AActual: TTokenKindArray; const AMessage: string = '');
    // Fails the test when the two tokens differ, reporting both token names.
    procedure CheckTokenEquals(AExpected, AActual: TTokenKind; const AMessage: string = '');
    procedure ExpectsLexerException(const ASource, AExpected: string);
    // Checks the token, its text and its position (1-based line and column) after SetData or NextToken.
    procedure CheckTokenAt(AToken: TTokenKind; const AText: string; ALine, AColumn: Integer; const AMessage: string);
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestIdentifiersAndPunctuation;
    procedure TestNumbers;
    procedure TestStrings;
    // Doubled quotes ('') inside a string literal do not end the string.
    procedure TestStringDoubledQuotes;
    procedure TestComments;
    procedure TestCompilerDirectivesAndCounters;

    procedure TestOperators;
    procedure TestGenericSymbols;
    procedure TestNumbersExponentAndHex;
    procedure TestAsciiChars;
    procedure TestIdentifiers;
    procedure TestAllKeywords;
    procedure TestKeywordCaseInsensitivity;
    procedure TestCommentLineBreaks;
    procedure TestCommentAtEndOfFile;

    procedure TestCompilerDirectiveNesting;
    procedure TestCompilerDirectiveExceptions;
    procedure TestCompilerDirectiveCountersAndBrackets;
    // An {$ELSEIF} chain nested in another level closes only its own level (System.pas)
    procedure TestDirectiveNestedElseIfChain;
    // A level opened inside an {$ELSEIF} branch, with or without {$ELSE} (System.Math.pas)
    procedure TestDirectiveNestedLevelInElseIfBranch;
    // Delphi accepts a repeated {$ELSE} (TestExtensions.pas, Macapi.ObjectiveC.pas), but not {$ELSEIF} after {$ELSE}
    procedure TestDirectiveRepeatedElse;
    // Every branch must leave the bracket counters as the first branch of its level does
    procedure TestDirectiveBranchCountersCompared;
    // With IgnoreCompilerDirectiveChecks = True broken conditionals are lexed to the end and leave a consistent state
    procedure TestDirectiveErrorsWithChecksIgnored;

    procedure TestPropertyTokens;
    procedure TestEndTokens;

    procedure TestTokenString;
    procedure TestReset;
    procedure TestLexerStateSnapshot;
    procedure TestLineTracking;
    procedure TestEOFBehavior;
    procedure TestSetDataEmptyString;
    procedure TestNextTokenNoJunk;
    procedure TestNextTokenWithKind;
    procedure TestNextTokenNoDirectiveBranching;
    procedure TestLexerDumpSamples;
    procedure TestNextTokenWithKindNotFound;
    // Starting inside the else branch returns the tokens of that branch only
    procedure TestNextTokenNoDirectiveBranchingElseBranch;
    // #0 terminates the data for the lexer: everything after it is not lexed
    procedure TestEmbeddedNullChar;
    // A line break at the very end of the data is still counted
    procedure TestTrailingLineBreak;
    // CRCR, LF and LFCR are each a single line break token
    procedure TestConsecutiveLineBreaks;
    // Numbers and identifiers are separated even without whitespace
    procedure TestNumberIdentifierSequences;
    // A (*$...*) directive spanning several lines is one token, the lines after it are counted correctly
    procedure TestStarParenDirectiveLineBreak;
    // Conditional directive recognition inside the curly braces
    procedure TestDirectiveKeywordEdgeCases;
    // The state array must contain an idsIf entry to restore the counters from
    procedure TestDirectiveErrorCountersNotFoundOnRestore;
    // '{$' ends only at '}' and '(*$' only at '*)', quotes inside the directive do not matter
    procedure TestDirectiveClosingBracket;
    // Every kind of line break inside a {$...} directive is counted, the column restarts after the last one
    procedure TestCurlyDirectiveLineBreaks;
    // Delphi 11 digit separator '_' in decimal, real, hexadecimal and character literals
    procedure TestDigitSeparators;
    // Delphi 11 binary literals %1010 are one integer token
    procedure TestBinaryNumbers;
    // Like Delphi, a dot followed by an ASCII letter or '_' ends the number: 1.ToString is 1 . ToString
    procedure TestNumberFollowedByPoint;
    // Inside an asm block a double quote starts a BASM string, elsewhere it is a symbol
    procedure TestAsmDoubleQuotedStrings;
    // IsAsmBlock is set by 'asm' and cleared by the 'end' of the block
    procedure TestAsmBlockFlag;
  end;

implementation

{ TestTPasLexerAdditional }

procedure TestTPasLexerAdditional.SetUp;
begin
  FPasLexer := TPasLexer.Create;
end;

procedure TestTPasLexerAdditional.TearDown;
begin
  FreeAndNil(FPasLexer);
end;

function TestTPasLexerAdditional.GetTokens(const ASource: string): TTokenKindArray;
var
  S: string;
  Count: Integer;
begin
  Result := nil;
  S := ASource;
  FPasLexer.SetData(S);
  Count := 0;
  repeat
    SetLength(Result, Count + 1);
    Result[Count] := FPasLexer.TokenID;
    Inc(Count);
  until not FPasLexer.NextToken;
end;

function TestTPasLexerAdditional.GetTokensNoJunk(const ASource: string): TTokenKindArray;
var
  S: string;
  Token: TTokenKind;
  Count: Integer;
begin
  Result := nil;
  S := ASource;
  FPasLexer.SetData(S);
  Count := 0;
  repeat
    Token := FPasLexer.TokenID;
    if not (Token in DIRECTIVE_INSIGNIFICANT_TOKENS) then
    begin
      SetLength(Result, Count + 1);
      Result[Count] := Token;
      Inc(Count);
    end;
  until not FPasLexer.NextToken;
end;

procedure TestTPasLexerAdditional.CheckTokensEqual(const AExpected, AActual: TTokenKindArray; const AMessage: string = '');
var
  i: Integer;
  FailMessage: string;
begin
  FailMessage := '';
  if Length(AExpected) <> Length(AActual) then
    FailMessage := Format('expected %d tokens, actual %d tokens',
        [Length(AExpected), Length(AActual)])
  else
    for i := Low(AExpected) to High(AExpected) do
      if AExpected[i] <> AActual[i] then
      begin
        FailMessage := Format('index %d: expected %s, actual %s',
            [i, TOKEN_NAMES[AExpected[i]], TOKEN_NAMES[AActual[i]]]);
        Break;
      end;
  if FailMessage <> '' then
    if AMessage = '' then
      Fail(FailMessage)
    else
      Fail(AMessage + ' - ' + FailMessage);
end;

procedure TestTPasLexerAdditional.CheckTokenEquals(AExpected, AActual: TTokenKind; const AMessage: string = '');
var
  FailMessage: string;
begin
  if AExpected <> AActual then
  begin
    FailMessage := Format('expected %s, actual %s',
        [TOKEN_NAMES[AExpected], TOKEN_NAMES[AActual]]);
    if AMessage = '' then
      Fail(FailMessage)
    else
      Fail(AMessage + ' - ' + FailMessage);
  end;
end;

procedure TestTPasLexerAdditional.ExpectsLexerException(const ASource, AExpected: string);
var
  S: string;
  Raised: Boolean;
begin
  Raised := False;
  S := ASource;
  try
    FPasLexer.SetData(S);
    while FPasLexer.NextToken do;
  except
    on E: EPasLexerException do
    begin
      Raised := True;
      CheckEquals(AExpected, E.Message, 'Unexpected exception message');
    end;
  end;
  CheckTrue(Raised, 'Expected EPasLexerException for: ' + ASource);
end;

procedure TestTPasLexerAdditional.CheckTokenAt(AToken: TTokenKind; const AText: string; ALine, AColumn: Integer; const AMessage: string);
var
  State: TPasLexerState;
begin
  State := FPasLexer.LexerState;
  CheckTokenEquals(AToken, FPasLexer.TokenID, AMessage + ': token');
  CheckEquals(AText, FPasLexer.TokenString, AMessage + ': text');
  CheckEquals(ALine, Integer(State.CurrentLine), AMessage + ': line');
  CheckEquals(AColumn, Integer(State.CurrentTokenPos - State.CurrentLineStartPos) + 1, AMessage + ': column');
end;

procedure TestTPasLexerAdditional.TestIdentifiersAndPunctuation;
begin
  CheckTokensEqual(
      [tkIdentifier, tkSpace, tkIdentifier, tkSpace, tkIdentifier, tkSemiColon],
      GetTokens('MyVar _temp var1;'),
      'Identifier and punctuation sequence');
end;

procedure TestTPasLexerAdditional.TestNumbers;
begin
  CheckTokensEqual(
      [tkIdentifier, tkSpace, tkAssign, tkSpace, tkNumber, tkSemiColon,
      tkSpace, tkIdentifier, tkSpace, tkAssign, tkSpace, tkFloat, tkSemiColon,
      tkSpace, tkIdentifier, tkSpace, tkAssign, tkSpace, tkInteger, tkSemiColon],
      GetTokens('a := 123; b := 12.34e-2; c := $FF;'),
      'Number, float and hex literal sequence');
end;

procedure TestTPasLexerAdditional.TestStrings;
begin
  CheckTokensEqual(
      [tkIdentifier, tkSpace, tkAssign, tkSpace, tkString, tkSemiColon],
      GetTokens('s := ''hello'';'),
      'Quoted string literal');

  // An empty string literal '' (two quotes) is still a string token
  CheckTokensEqual([tkString], GetTokens(#39#39), 'An empty string literal');

  CheckTokensEqual(
      [tkIdentifier, tkSpace, tkAssign, tkSpace, tkUnterminatedString],
      GetTokens('t := ''notclosed'),
      'Unterminated string literal');
end;

procedure TestTPasLexerAdditional.TestStringDoubledQuotes;
var
  S: string;
begin
  CheckTokensEqual(
      [tkIdentifier, tkSpace, tkAssign, tkSpace, tkString, tkSemiColon],
      GetTokens('s := ''it''''s'';'),
      'Doubled quote inside a string literal');

  CheckTokensEqual(
      [tkString, tkSemiColon],
      GetTokens('''a''''b''''c'';'),
      'Several doubled quotes inside a string literal');

  // The whole literal, including the doubled quote, is one token
  S := '''it''''s'';';
  FPasLexer.SetData(S);
  CheckTokenEquals(tkString, FPasLexer.TokenID, 'Token of the string literal');
  CheckEquals('''it''''s''', FPasLexer.TokenString, 'Text of the string literal');
end;

procedure TestTPasLexerAdditional.TestComments;
begin
  CheckTokensEqual(
      [tkCurlyComment, tkSpace, tkStarParenComment, tkSpace, tkSingleLineComment, tkCRLF,
      tkIdentifier],
      GetTokens('{comment} (* another comment *) // single line' + sLineBreak + 'x'),
      'Comment token sequence');
end;

procedure TestTPasLexerAdditional.TestCompilerDirectivesAndCounters;
var
  S: string;
  LState: TPasLexerState;
begin
  GetTokens('{$IFDEF A}{$IFDEF B}{$ENDIF}{$ENDIF}');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount,
      'IfDirectiveCount should be 0 after matching endif');

  S := '{$IFDEF A}{$ELSE}';
  FPasLexer.SetData(S);
  LState := FPasLexer.LexerState;
  LState.IgnoreCompilerDirectiveChecks := True;
  FPasLexer.LexerState := LState;
  while FPasLexer.NextToken do;
  CheckTrue(True, 'Lexer handled directives with IgnoreCompilerDirectiveChecks = True');
end;

procedure TestTPasLexerAdditional.TestOperators;
begin
  CheckTokensEqual(
      [tkIdentifier, tkSpace, tkAssign, tkSpace, tkNotEqual, tkSpace, tkLowerEqual, tkSpace,
      tkGreaterEqual, tkSpace, tkEqual, tkSpace, tkPlus, tkSpace, tkMinus, tkSpace, tkStar,
      tkSpace, tkSlash, tkSpace, tkRoundOpen, tkSpace, tkRoundClose, tkSpace, tkSquareOpen,
      tkSpace, tkSquareClose, tkSpace, tkPointerSymbol, tkSpace, tkPoint, tkSpace, tkDotDot,
      tkSpace, tkComma, tkSpace, tkAddressSymbol, tkSpace, tkSemiColon, tkSpace, tkColon],
      GetTokens('x8 := <> <= >= = + - * / ( ) [ ] ^ . .. , @ ; :'),
      'Operator and punctuation token sequence');

  CheckTokensEqual([tkSquareOpen, tkSquareClose],
      GetTokens('(..)'),
      'Legacy ( . ... . ) square brackets');
  CheckTokensEqual([tkRoundOpen, tkRoundClose],
      GetTokens('()'),
      'Plain parentheses');
end;

procedure TestTPasLexerAdditional.TestGenericSymbols;
begin
  CheckTokensEqual(
      [tkSymbol, tkSpace, tkSymbol, tkSpace, tkSymbol, tkSpace, tkSymbol, tkSpace, tkSymbol,
      tkSpace, tkSymbol, tkSpace, tkSymbol, tkSpace, tkUnknown],
      GetTokens('! % & \ ? ~ " }'),
      'Generic symbol mapping and unmatched right brace');
  CheckTokensEqual([tkUnknown], GetTokens('}'), 'A lone closing brace is unknown');
end;

procedure TestTPasLexerAdditional.TestNumbersExponentAndHex;
begin
  CheckTokensEqual(
      [tkNumber, tkSpace, tkFloat, tkSpace, tkFloat, tkSpace, tkFloat, tkSpace, tkFloat,
      tkSpace, tkInteger, tkSpace, tkNumber],
      GetTokens('0 1.5 1.5e3 1E-2 10.25E+8 $AB 42'),
      'Number, float, exponent and hex literals');
  CheckTokensEqual([tkNumber, tkIdentifier, tkMinus], GetTokens('1e-'),
      'Exponent without digits is not a float');
  CheckTokensEqual([tkNumber, tkIdentifier, tkPlus], GetTokens('1e+'),
      'Exponent sign without digits is not a float');
  CheckTokensEqual([tkFloat, tkIdentifier, tkMinus], GetTokens('1.5e-'),
      'Exponent without digits after a point keeps the float');
  CheckTokensEqual([tkFloat, tkPoint, tkNumber], GetTokens('1e33.3'),
      'A dot after the exponent is not part of the number');
  CheckTokensEqual([tkFloat, tkPoint, tkNumber], GetTokens('1.5e+3.2'),
      'A dot after a signed exponent is not part of the number');
  CheckTokensEqual([tkFloat, tkPoint, tkNumber], GetTokens('1.5.6'),
      'A dot after float is not part of the number');
end;

procedure TestTPasLexerAdditional.TestAsciiChars;
begin
  CheckTokensEqual([tkAsciiChar, tkSpace, tkAsciiChar], GetTokens('#65 #$AF'),
      'Numeric character literals');
  CheckTokensEqual([tkAsciiChar, tkAsciiChar], GetTokens('#0#1'),
      'Adjacent character literals');
end;

procedure TestTPasLexerAdditional.TestIdentifiers;
begin
  CheckTokensEqual([tkIdentifier], GetTokens('foo'), 'Simple identifier');
  CheckTokensEqual([tkIdentifier], GetTokens('_foo'), 'Identifier starting with underscore');
  CheckTokensEqual([tkIdentifier], GetTokens('foo1_2'), 'Identifier containing digits');
  CheckTokensEqual([tkIdentifier], GetTokens(#$00E9'clair'), 'Identifier containing non-ascii');
end;

procedure TestTPasLexerAdditional.TestAllKeywords;
var
  i: Integer;
  S: string;
begin
  for i := Low(DELPHI_KEYWORDS) to High(DELPHI_KEYWORDS) do
  begin
    S := DELPHI_KEYWORDS[i].Word;
    if DELPHI_KEYWORDS[i].Token in [tkRead, tkWrite, tkIndex, tkStored, tkDefault, tkNodefault] then
      CheckTokensEqual([tkIdentifier], GetTokens(S),
          'Property directive ' + DELPHI_KEYWORDS[i].Word + ' is an identifier outside a property')
    else
      CheckTokensEqual([DELPHI_KEYWORDS[i].Token], GetTokens(S),
          'Keyword ' + DELPHI_KEYWORDS[i].Word);
  end;
end;

procedure TestTPasLexerAdditional.TestKeywordCaseInsensitivity;
begin
  CheckTokensEqual([tkBegin], GetTokens('begin'));
  CheckTokensEqual([tkBegin], GetTokens('BEGIN'));
  CheckTokensEqual([tkBegin], GetTokens('BeGiN'));
  CheckTokensEqual([tkProcedure], GetTokens('procedure'));
  CheckTokensEqual([tkProgram], GetTokens('pRoGrAm'));
end;

procedure TestTPasLexerAdditional.TestCommentLineBreaks;
var
  Multi: string;
begin
  Multi := '{line1' + sLineBreak + 'line2}';
  CheckTokensEqual([tkCurlyComment, tkCRLFComment, tkCurlyComment], GetTokens(Multi),
      'Multiline curly comment');
  Multi := '(*line1' + sLineBreak + 'line2*)';
  CheckTokensEqual([tkStarParenComment, tkCRLFComment, tkStarParenComment], GetTokens(Multi),
      'Multiline star/paren comment');
end;

procedure TestTPasLexerAdditional.TestCommentAtEndOfFile;
begin
  CheckTokensEqual([tkSingleLineComment], GetTokens('// no trailing newline'),
      'Single line comment at EOF');
  CheckTokensEqual([tkCurlyComment], GetTokens('{ unterminated'),
      'Unterminated curly comment');
  CheckTokensEqual([tkStarParenComment], GetTokens('(* unterminated'),
      'Unterminated star comment');
end;

procedure TestTPasLexerAdditional.TestCompilerDirectiveNesting;
begin
  GetTokens('{$IFDEF A}{$IFNDEF B}{$IFOPT C}{$IFEND}{$ENDIF}{$ENDIF}');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount,
      'Balanced dialog nesting ends with zero directives on the stack');

  GetTokens('{$IFDEF A}{$ELSEIF B}{$ELSE}{$ENDIF}');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount,
      'IFDEF/ELSEIF/ELSE/ENDIF chain ends at zero');
end;

procedure TestTPasLexerAdditional.TestCompilerDirectiveExceptions;
var
  S: string;
  LState: TPasLexerState;
  Raised: Boolean;
begin
  ExpectsLexerException('{$ELSE}', EMESSAGE_UNEXPECTED_ELSE_DIRECTIVE);
  ExpectsLexerException('{$ENDIF}', EMESSAGE_DIRECTIVE_STATE_COUNTER_MISMATCH);
  ExpectsLexerException('{$IFEND}', EMESSAGE_DIRECTIVE_STATE_COUNTER_MISMATCH);
  ExpectsLexerException('{$IF A}{$ELSE}{$ELSEIF B}{$ENDIF}',
      EMESSAGE_UNEXPECTED_ELSE_DIRECTIVE);
  ExpectsLexerException('{$IFDEF A}[{$ELSEIF B}{$ENDIF}',
      EMESSAGE_DIRECTIVE_COUNTERS_MISMATCH_ELSE);

  Raised := False;
  S := '{$IFDEF A}[{$ELSEIF B}{$ENDIF}';
  FPasLexer.SetData(S);
  LState := FPasLexer.LexerState;
  LState.IgnoreCompilerDirectiveChecks := True;
  FPasLexer.LexerState := LState;
  try
    while FPasLexer.NextToken do;
  except
    Raised := True;
  end;
  CheckFalse(Raised, 'No exception expected when checks are disabled');
end;

procedure TestTPasLexerAdditional.TestCompilerDirectiveCountersAndBrackets;
begin
  GetTokens('{$IFDEF A}[(x)]{$ELSE}(y){$ENDIF}');
  CheckEquals(0, FPasLexer.LexerState.Counters.RoundCount);
  CheckEquals(0, FPasLexer.LexerState.Counters.SquareCount);
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount);
end;

procedure TestTPasLexerAdditional.TestDirectiveNestedElseIfChain;
begin
  // The inner chain must be compared to its own first branch, not to the outer level
  GetTokens('{$IFNDEF A}{$IF B}({$ELSEIF C}({$IF D}[{$ELSEIF E}[{$ENDIF}]{$ELSEIF F}({$ENDIF}){$ENDIF}');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount, 'All levels are closed');
  CheckEquals(0, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'State array is empty');
  CheckEquals(0, Length(FPasLexer.LexerState.IfDirectiveSavedCountersArray), 'Saved counters array is empty');
  CheckEquals(0, FPasLexer.LexerState.Counters.RoundCount, 'Round brackets are balanced');
  CheckEquals(0, FPasLexer.LexerState.Counters.SquareCount, 'Square brackets are balanced');

  // The same with {$ELSE} and {$IFEND} after the inner chain
  GetTokens('{$IFDEF A}{$IF B}x{$ELSEIF C}y{$ELSE}z{$IFEND}{$ENDIF}');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount, 'Chain with ELSE: all levels are closed');
  CheckEquals(0, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'Chain with ELSE: state array is empty');
end;

procedure TestTPasLexerAdditional.TestDirectiveNestedLevelInElseIfBranch;
var
  S: string;
begin
  GetTokens('{$IF A}({$ELSEIF B}({$IFOPT R+}{$ENDIF}{$ENDIF})');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount, 'IFOPT inside ELSEIF: all levels are closed');
  CheckEquals(0, FPasLexer.LexerState.Counters.RoundCount, 'IFOPT inside ELSEIF: round brackets are balanced');

  // The ELSE of the inner level must not be taken for the ELSE of the outer level
  GetTokens('{$IF A}({$ELSEIF B}({$IFDEF C}[{$ELSE}[{$ENDIF}]{$ENDIF})');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount, 'ELSE inside ELSEIF: all levels are closed');
  CheckEquals(0, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'ELSE inside ELSEIF: state array is empty');
  CheckEquals(0, FPasLexer.LexerState.Counters.RoundCount, 'ELSE inside ELSEIF: round brackets are balanced');
  CheckEquals(0, FPasLexer.LexerState.Counters.SquareCount, 'ELSE inside ELSEIF: square brackets are balanced');

  // After the inner level is closed the outer level is still in its ELSEIF branch
  S := '{$IF A}{$ELSEIF B}{$IFDEF C}{$ELSE}{$ENDIF}x{$ENDIF}';
  FPasLexer.SetData(S);
  CheckTrue(FPasLexer.NextTokenWithKind(tkIdentifier), 'Identifier after the inner level expected');
  CheckEquals(1, FPasLexer.LexerState.Counters.IfDirectiveCount, 'Only the outer level is open');
  CheckEquals(2, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'Outer level has two state entries');
  CheckTrue(FPasLexer.LexerState.IfDirectiveStateArray[0] = idsIf, 'First entry of the outer level');
  CheckTrue(FPasLexer.LexerState.IfDirectiveStateArray[1] = idsElseIf, 'ELSEIF entry of the outer level');
end;

procedure TestTPasLexerAdditional.TestDirectiveRepeatedElse;
var
  S: string;
begin
  CheckTokensEqual([tkIdentifier, tkIdentifier, tkIdentifier, tkIdentifier],
      GetTokensNoJunk('{$IFDEF A}a{$ELSE}b{$ELSE}c{$ENDIF}d'),
      'Repeated ELSE');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount, 'Repeated ELSE: the level is closed');
  CheckEquals(0, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'Repeated ELSE: state array is empty');

  // TestExtensions.pas: text after ELSE is ignored by Delphi
  GetTokens('{$IFDEF A}({$ELSE IFDEF B}({$ELSE}({$ENDIF})');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount, 'ELSE with text: the level is closed');
  CheckEquals(0, FPasLexer.LexerState.Counters.RoundCount, 'ELSE with text: round brackets are balanced');

  // The branch of a repeated ELSE is compared like the others
  ExpectsLexerException('{$IFDEF A}({$ELSE}({$ELSE}{$ENDIF})', EMESSAGE_DIRECTIVE_COUNTERS_MISMATCH_ELSE);
  // ELSEIF after ELSE is a compile error (E2029)
  ExpectsLexerException('{$IFDEF A}{$ELSE}{$ELSE}{$ELSEIF B}{$ENDIF}', EMESSAGE_UNEXPECTED_ELSE_DIRECTIVE);

  // From the first ELSE branch NextTokenNoDirectiveBranching skips the repeated ELSE branch
  S := '{$IFDEF X}a{$ELSE}b{$ELSE}c{$ENDIF}d';
  FPasLexer.SetData(S);
  CheckTrue(FPasLexer.NextTokenWithKind(tkIdentifier), 'Identifier of the IF branch expected');
  CheckTrue(FPasLexer.NextTokenWithKind(tkIdentifier), 'Identifier of the ELSE branch expected');
  CheckEquals('b', FPasLexer.TokenString, 'Token of the ELSE branch');
  CheckTrue(FPasLexer.NextTokenNoDirectiveBranching, 'Token after the level expected');
  CheckEquals('d', FPasLexer.TokenString, 'Token after the end directive');
end;

procedure TestTPasLexerAdditional.TestDirectiveBranchCountersCompared;
begin
  GetTokens('{$IF A}({$ELSEIF B}({$ELSE}({$ENDIF})');
  CheckEquals(0, FPasLexer.LexerState.Counters.RoundCount, 'Equal branches: round brackets are balanced');

  // An ELSEIF branch followed by ELSE is compared to the first branch too
  ExpectsLexerException('{$IF A}({$ELSEIF B}{$ELSE}({$ENDIF})', EMESSAGE_DIRECTIVE_COUNTERS_MISMATCH_ELSE);
  ExpectsLexerException('{$IF A}{$ELSEIF B}{$ELSEIF C}[{$ENDIF}', EMESSAGE_DIRECTIVE_COUNTERS_MISMATCH_ELSE);
  ExpectsLexerException('{$IFDEF A}{$ELSE}({$ENDIF}', EMESSAGE_DIRECTIVE_COUNTERS_MISMATCH_ELSE);

  // A level without ELSEIF and ELSE has one branch: it may change the counters
  GetTokens('{$IFDEF A}({$ENDIF}');
  CheckEquals(1, FPasLexer.LexerState.Counters.RoundCount, 'Single branch keeps its round bracket');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount, 'Single branch: the level is closed');

  // After the level the counters are the common end counters of its branches
  GetTokens('{$IFDEF A}([{$ELSE}([{$ENDIF}');
  CheckEquals(1, FPasLexer.LexerState.Counters.RoundCount, 'Round bracket after the level');
  CheckEquals(1, FPasLexer.LexerState.Counters.SquareCount, 'Square bracket after the level');
end;

procedure TestTPasLexerAdditional.TestDirectiveErrorsWithChecksIgnored;
const
  // Every sample starts with an identifier: SetData lexes the first token before the checks can be turned off
  SAMPLES: array[0..6] of string = (
    'x{$ELSE}',
    'x{$ELSEIF A}',
    'x{$ENDIF}',
    'x{$IFEND}{$ELSE}{$ENDIF}{$IFDEF A}{$ENDIF}',
    'x{$IF A}{$ELSE}{$ELSEIF B}{$ENDIF}',
    'x{$IFDEF A}({$ELSE}{$ENDIF}{$ENDIF}',
    'x{$IFDEF A}{$IF B}{$ELSE}{$ELSE}{$ENDIF}{$ENDIF}{$ENDIF}{$ELSE}'
  );
var
  S: string;
  LState: TPasLexerState;
  i: Integer;

  procedure LexWithChecksIgnored(const ASample: string);
  begin
    LState := FPasLexer.LexerState;
    LState.IgnoreCompilerDirectiveChecks := True;
    FPasLexer.LexerState := LState;
    try
      while FPasLexer.NextToken do;
    except
      on E: Exception do
        Fail(Format('No exception expected with checks ignored for %s, got %s: %s', [ASample, E.ClassName, E.Message]));
    end;
    CheckTokenEquals(tkEOF, FPasLexer.TokenID, 'Lexed to the end: ' + ASample);
  end;

begin
  for i := Low(SAMPLES) to High(SAMPLES) do
  begin
    S := SAMPLES[i];
    FPasLexer.SetData(S);
    LexWithChecksIgnored(S);
    CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount, 'No open levels: ' + S);
    CheckEquals(0, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'State array is empty: ' + S);
    CheckEquals(0, Length(FPasLexer.LexerState.IfDirectiveSavedCountersArray), 'Saved counters array is empty: ' + S);
  end;

  // A state without an idsIf entry: the directives cannot be matched and are skipped
  S := '{$IFDEF A}x{$ELSEIF B}{$ELSE}{$ENDIF}';
  FPasLexer.SetData(S);
  LState := FPasLexer.LexerState;
  LState.IfDirectiveStateArray[0] := idsElseIf;
  FPasLexer.LexerState := LState;
  LexWithChecksIgnored(S);

  // State arrays of different lengths
  S := '{$IFDEF A}x{$ELSE}{$ENDIF}';
  FPasLexer.SetData(S);
  LState := FPasLexer.LexerState;
  SetLength(LState.IfDirectiveSavedCountersArray, 0);
  FPasLexer.LexerState := LState;
  LexWithChecksIgnored(S);
end;

procedure TestTPasLexerAdditional.TestPropertyTokens;
begin
  CheckTokensEqual(
      [tkProperty, tkIdentifier, tkColon, tkIdentifier, tkRead, tkIdentifier, tkWrite,
      tkIdentifier, tkSemiColon, tkIdentifier, tkIdentifier],
      GetTokensNoJunk('property Value : Integer read GetValue write SetValue; x read'),
      'Property directive tokens are context sensitive');

  CheckTokensEqual(
      [tkProperty, tkIdentifier, tkColon, tkIdentifier, tkDefault, tkNumber, tkSemiColon],
      GetTokensNoJunk('property V : Integer default 3;'),
      'Property default directive');

  CheckTokensEqual([tkIdentifier], GetTokens('read'), 'read outside of property');
  CheckTokensEqual([tkIdentifier], GetTokens('write'), 'write outside of property');
  CheckTokensEqual([tkIdentifier], GetTokens('index'), 'index outside of property');
  CheckTokensEqual([tkIdentifier], GetTokens('stored'), 'stored outside of property');
  CheckTokensEqual([tkIdentifier], GetTokens('nodefault'), 'nodefault outside of property');
  CheckTokensEqual([tkIdentifier], GetTokens('default'), 'default outside of property');
end;

procedure TestTPasLexerAdditional.TestEndTokens;
begin
  CheckTokensEqual([tkUnitEnd], GetTokens('end.'), 'Unit end token');
  CheckTokensEqual([tkEnd, tkSpace, tkPoint], GetTokens('end .'),
      'end and dot separated by space');
  CheckTokensEqual([tkEnd, tkSpace, tkSemiColon], GetTokens('end ;'),
      'end followed by semicolon');
  CheckTokensEqual([tkEnd], GetTokens('end'), 'Plain end');
end;

procedure TestTPasLexerAdditional.TestTokenString;
var
  S: string;
begin
  S := 'MyIdent := 1;';
  FPasLexer.SetData(S);
  CheckEquals('MyIdent', FPasLexer.TokenString, 'Identifier token text');
  FPasLexer.NextToken;
  CheckEquals(' ', FPasLexer.TokenString, 'Space token text');
  FPasLexer.NextToken;
  CheckEquals(':=', FPasLexer.TokenString, 'Assign token text');
  FPasLexer.NextToken;
  FPasLexer.NextToken;
  CheckEquals('1', FPasLexer.TokenString, 'Number token text');
  FPasLexer.NextToken;
  CheckEquals(';', FPasLexer.TokenString, 'Semicolon token text');
end;

procedure TestTPasLexerAdditional.TestReset;
begin
  CheckTokensEqual([tkBegin, tkSpace, tkEnd], GetTokens('begin end'));

  FPasLexer.Reset;
  CheckTokenEquals(tkBegin, FPasLexer.TokenID, 'Reset rewinds to the first token');
  CheckEquals(1, Integer(FPasLexer.LexerState.CurrentLine), 'CurrentLine resets to 1');
end;

procedure TestTPasLexerAdditional.TestLexerStateSnapshot;
var
  S: string;
  LState: TPasLexerState;
begin
  S := 'a := 1; b := 2;';
  FPasLexer.SetData(S);       // 'a'
  FPasLexer.NextToken;        // space
  FPasLexer.NextToken;        // ':='
  CheckEquals(':=', FPasLexer.TokenString, 'Before snapshot');
  LState := FPasLexer.LexerState;
  while FPasLexer.NextToken do;
  FPasLexer.LexerState := LState;
  CheckEquals(':=', FPasLexer.TokenString, 'State restored to the := token');
  CheckTokenEquals(tkAssign, FPasLexer.TokenID, 'State restore keeps token id');
end;

procedure TestTPasLexerAdditional.TestLineTracking;
var
  S: string;
begin
  S := 'a' + sLineBreak + 'bb';
  FPasLexer.SetData(S);
  CheckEquals(1, Integer(FPasLexer.LexerState.CurrentLine), 'Line 1 at start');
  CheckEquals('a', FPasLexer.TokenString);

  FPasLexer.NextToken;      // CRLF
  CheckTokenEquals(tkCRLF, FPasLexer.TokenID);
  CheckEquals(1, Integer(FPasLexer.LexerState.CurrentLine), 'Still on line 1 on the CRLF token');

  FPasLexer.NextToken;      // bb
  CheckTokenEquals(tkIdentifier, FPasLexer.TokenID);
  CheckEquals(2, Integer(FPasLexer.LexerState.CurrentLine), 'Line 2 after the line break');
end;

procedure TestTPasLexerAdditional.TestEOFBehavior;
var
  S: string;
begin
  S := 'and';
  FPasLexer.SetData(S);
  CheckTokenEquals(tkAnd, FPasLexer.TokenID);
  CheckFalse(FPasLexer.NextToken, 'NextToken returns False at end of input');
  CheckTokenEquals(tkEOF, FPasLexer.TokenID, 'Token becomes tkEOF');
  CheckFalse(FPasLexer.NextToken, 'Remains tkEOF');
end;

procedure TestTPasLexerAdditional.TestSetDataEmptyString;
var
  S: string;
begin
  S := '';
  FPasLexer.SetData(S);
  CheckTokenEquals(tkEOF, FPasLexer.TokenID, 'Empty input starts at tkEOF');

  while FPasLexer.TokenID <> tkEOF do
    FPasLexer.NextToken;
  CheckTokenEquals(tkEOF, FPasLexer.TokenID, 'Typical token loop stays at tkEOF');
  CheckFalse(FPasLexer.NextToken, 'NextToken returns False for empty input');

  S := 'begin end';
  FPasLexer.SetData(S);
  CheckTokenEquals(tkBegin, FPasLexer.TokenID, 'Lexer can be reused after empty input');

  S := '';
  FPasLexer.SetData(S);
  CheckTokenEquals(tkEOF, FPasLexer.TokenID, 'Empty input after data ends at tkEOF');
end;

procedure TestTPasLexerAdditional.TestNextTokenNoJunk;
var
  S: string;
begin
  S := '{comment}{*star*}//sl' + sLineBreak + 'a[$0]';
  FPasLexer.SetData(S);
  CheckTokenEquals(tkCurlyComment, FPasLexer.TokenID, 'Source begins with a comment');

  CheckTrue(FPasLexer.NextTokenNoJunk, 'NextTokenNoJunk reaches the code');
  CheckTokenEquals(tkIdentifier, FPasLexer.TokenID, 'Identifier after comments');
  CheckEquals('a', FPasLexer.TokenString, 'Correct identifier text');
end;

procedure TestTPasLexerAdditional.TestNextTokenWithKind;
var
  S: string;
begin
  S := 'x := 1; b := 2;';
  FPasLexer.SetData(S);
  CheckTrue(FPasLexer.NextTokenWithKind(tkAssign), 'First assign found');
  CheckTokenEquals(tkAssign, FPasLexer.TokenID);
  CheckTrue(FPasLexer.NextTokenWithKind(tkAssign), 'Second assign found');
  CheckTokenEquals(tkAssign, FPasLexer.TokenID);
end;

procedure TestTPasLexerAdditional.TestNextTokenNoDirectiveBranching;
var
  S: string;
begin
  S := 'a {$IFDEF X} b {$ELSE} c {$ENDIF} d';
  FPasLexer.SetData(S);
  CheckEquals('a', FPasLexer.TokenString, 'Starts with identifier a');
  CheckTrue(FPasLexer.NextTokenNoDirectiveBranching, 'NoDirectiveBranching advances');
  CheckEquals('d', FPasLexer.TokenString, 'Skips the whole inactive branch');
end;

procedure TestTPasLexerAdditional.TestLexerDumpSamples;
const
  Samples: array[0..6] of string = (
    'MyVar _temp var1;',
    'a := 123; b := 12.34e-2; c := $FF;',
    's := ''hello'';',
    't := ''notclosed',
    '{comment} (* another comment *) // single line' + sLineBreak + 'x',
    '{$IFDEF A}{$IFDEF B}{$ENDIF}{$ENDIF}',
    '{$IFDEF A}{$ELSE}'
  );
var
  i: Integer;
  S: string;
  LState: TPasLexerState;
begin
  for i := Low(Samples) to High(Samples) do
  begin
    S := Samples[i];
    FPasLexer.SetData(S);
    if i = High(Samples) then
    begin
      // unmatched {$ELSE} needs directive checks disabled to lex to EOF
      LState := FPasLexer.LexerState;
      LState.IgnoreCompilerDirectiveChecks := True;
      FPasLexer.LexerState := LState;
    end;
    while FPasLexer.NextToken do;
    CheckTokenEquals(tkEOF, FPasLexer.TokenID,
        Format('Sample %d must lex to EOF: %s', [i, S]));
  end;
end;

procedure TestTPasLexerAdditional.TestNextTokenWithKindNotFound;
var
  S: string;
begin
  S := 'a := 1;';
  FPasLexer.SetData(S);
  CheckFalse(FPasLexer.NextTokenWithKind(tkImplementation),
      'NextTokenWithKind returns False when the kind is absent');
  CheckTokenEquals(tkEOF, FPasLexer.TokenID, 'Lexer is at EOF');
end;

procedure TestTPasLexerAdditional.TestNextTokenNoDirectiveBranchingElseBranch;
var
  S: string;
begin
  S := '{$IFDEF X}a{$ELSE}b{$ENDIF}c';
  FPasLexer.SetData(S);
  CheckEquals('{$IFDEF X}', FPasLexer.TokenString, 'First token');
  CheckTrue(FPasLexer.NextToken, 'Identifier of the if branch expected');
  CheckTrue(FPasLexer.NextToken, 'ELSE directive expected');
  CheckEquals('{$ELSE}', FPasLexer.TokenString, 'ELSE directive');

  CheckTrue(FPasLexer.NextTokenNoDirectiveBranching, 'Token of the else branch expected');
  CheckEquals('b', FPasLexer.TokenString, 'Token of the else branch');

  // After the else branch ends lexing continues past the end directive
  CheckTrue(FPasLexer.NextTokenNoDirectiveBranching, 'Token after the directive expected');
  CheckEquals('c', FPasLexer.TokenString, 'Token after the end directive');
  CheckFalse(FPasLexer.NextTokenNoDirectiveBranching, 'No more tokens');
end;

procedure TestTPasLexerAdditional.TestEmbeddedNullChar;
var
  S: string;
begin
  S := 'ab' + #0 + 'cd';
  CheckTokensEqual([tkIdentifier], GetTokens(S),
      'Lexing must stop at the embedded null char');

  // #0 as the first char is already EOF
  S := #0;
  FPasLexer.SetData(S);
  CheckTokenEquals(tkEOF, FPasLexer.TokenID, 'Data starting with a null char');
  CheckFalse(FPasLexer.NextToken, 'NextToken after null char');

  // A null char inside a string makes the string unterminated
  CheckTokensEqual([tkUnterminatedString], GetTokens('''' + 'a' + #0 + 'b'),
      'Null char inside a string');

  // A null char at the end of a curly comment leaves the comment open
  CheckTokensEqual([tkCurlyComment], GetTokens('{ab' + #0 + '}'),
      'Null char inside a curly comment');
  CheckTrue(csCurly = FPasLexer.LexerState.CommentState, 'Lexer commentstate with #0 inside a comment');
end;

procedure TestTPasLexerAdditional.TestTrailingLineBreak;
var
  S: string;
begin
  S := 'a' + sLineBreak;
  FPasLexer.SetData(S);
  CheckTokenEquals(tkIdentifier, FPasLexer.TokenID, 'First token');

  CheckTrue(FPasLexer.NextToken, 'Line break expected');
  CheckTokenEquals(tkCRLF, FPasLexer.TokenID, 'Trailing line break token');
  CheckFalse(FPasLexer.NextToken, 'EOF after the trailing line break');
  CheckEquals(2, Integer(FPasLexer.LexerState.CurrentLine),
      'Line counter is increased after the trailing line break');
end;

procedure TestTPasLexerAdditional.TestConsecutiveLineBreaks;
begin
  CheckTokensEqual(
      [tkIdentifier, tkCRLF, tkCRLF, tkIdentifier, tkCRLF, tkCRLF, tkIdentifier],
      GetTokens('a' + #13#13 + 'b' + #10#13 + 'c'),
      'Consecutive line breaks');
  CheckEquals(5, Integer(FPasLexer.LexerState.CurrentLine),
      'Line after the last line break');
end;

procedure TestTPasLexerAdditional.TestNumberIdentifierSequences;
begin
  CheckTokensEqual([tkNumber, tkIdentifier], GetTokens('1e'),
      'Exponent without digits');
  CheckTokensEqual([tkFloat, tkIdentifier], GetTokens('1e2x'),
      'Float followed by identifier');
  CheckTokensEqual([tkNumber, tkIdentifier], GetTokens('123abc'),
      'Number followed by identifier');
  CheckTokensEqual([tkPoint, tkNumber], GetTokens('.5'),
      'Point followed by number');
end;

procedure TestTPasLexerAdditional.TestStarParenDirectiveLineBreak;
var
  S: string;
begin
  CheckTokensEqual(
      [tkCompilerDirective, tkIdentifier],
      GetTokens('(*$IFDEF X' + sLineBreak + 'Y*)z'),
      'Star paren directive with a line break');

  // The directive keeps the line it starts on, the next token is on the line where the directive ends
  S := '(*$IFDEF X' + sLineBreak + 'Y*)z' + sLineBreak + ' w';
  FPasLexer.SetData(S);
  CheckTokenAt(tkCompilerDirective, '(*$IFDEF X' + sLineBreak + 'Y*)', 1, 1, 'Directive');
  FPasLexer.NextToken;
  CheckTokenAt(tkIdentifier, 'z', 2, 4, 'Token after the directive');
  FPasLexer.NextToken;
  CheckTokenAt(tkCRLF, sLineBreak, 2, 5, 'Line break after the directive');
  FPasLexer.NextToken;
  FPasLexer.NextToken;
  CheckTokenAt(tkIdentifier, 'w', 3, 2, 'Token on the next line');
end;

procedure TestTPasLexerAdditional.TestDirectiveKeywordEdgeCases;
begin
  // Lowercase directive keywords are recognized too
  CheckTokensEqual([tkCompilerDirective, tkCompilerDirective], GetTokens('{$ifdef a}{$endif}'),
      'Lowercase conditional directives');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount,
      'Lowercase directives balance');

  // A directive keyword without a condition still opens a branch
  CheckTokensEqual([tkCompilerDirective, tkCompilerDirective], GetTokens('{$IFDEF}{$ENDIF}'),
      'Directives without conditions');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount,
      'Conditionless directives balance');

  // An underscore after the keyword makes it an identifier, not a directive
  CheckTokensEqual([tkCompilerDirective], GetTokens('{$IFDEF_1}'),
      'IFDEF with underscore is not a conditional directive');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount,
      'No branch opened by IFDEF_1');
  ExpectsLexerException('{$IFDEF_1}{$ENDIF}', EMESSAGE_DIRECTIVE_STATE_COUNTER_MISMATCH);

  // The dollar sign must follow the opening brace directly
  CheckTokensEqual([tkCurlyComment], GetTokens('{ $IFDEF A}'),
      'Space after the opening brace makes it a comment');
end;

procedure TestTPasLexerAdditional.TestDirectiveErrorCountersNotFoundOnRestore;
var
  S: string;
  LState: TPasLexerState;
  Raised: Boolean;

  procedure ExpectCounterRestoreError(const AMessage: string);
  begin
    Raised := False;
    try
      while FPasLexer.NextToken do;
    except
      on E: EPasLexerException do
      begin
        Raised := True;
        CheckEquals(EMESSAGE_DIRECTIVE_COUNTERS_NOTFOUND_ON_RESTORE, E.Message, AMessage);
      end;
    end;
    CheckTrue(Raised, 'Expected exception: ' + AMessage);
  end;

begin
  // {$ELSEIF} cannot find an {$IF...} state to restore
  S := '{$IFDEF A}{$ELSEIF B}';
  FPasLexer.SetData(S);
  LState := FPasLexer.LexerState;
  LState.IfDirectiveStateArray[0] := idsElseIf;
  FPasLexer.LexerState := LState;
  ExpectCounterRestoreError('ELSEIF without an if state to restore');

  // The same applies to {$ELSE}
  S := '{$IFDEF A}{$ELSE}';
  FPasLexer.SetData(S);
  LState := FPasLexer.LexerState;
  LState.IfDirectiveStateArray[0] := idsElseIf;
  FPasLexer.LexerState := LState;
  ExpectCounterRestoreError('ELSE without an if state to restore');

  // At the end directive the state array must contain a non-ELSEIF entry
  S := '{$IFDEF A}{$ENDIF}';
  FPasLexer.SetData(S);
  LState := FPasLexer.LexerState;
  LState.IfDirectiveStateArray[0] := idsElseIf;
  FPasLexer.LexerState := LState;
  ExpectCounterRestoreError('ENDIF without an if state to restore');
end;

procedure TestTPasLexerAdditional.TestDirectiveClosingBracket;
var
  S: string;
begin
  // Delphi 11 RTL (System.TypInfo, Winapi.Windows): curly braces inside a (*$...*) directive
  S := '(*$HPPEMIT END ''  {}''*)x';
  FPasLexer.SetData(S);
  CheckTokenAt(tkCompilerDirective, '(*$HPPEMIT END ''  {}''*)', 1, 1, 'Curly braces inside a star paren directive');
  FPasLexer.NextToken;
  CheckTokenAt(tkIdentifier, 'x', 1, 24, 'Token after the star paren directive');

  CheckTokensEqual([tkCompilerDirective, tkIdentifier], GetTokens('{$HPPEMIT ''*)''}x'),
      'Star paren end inside a curly directive');
  CheckTokensEqual([tkCompilerDirective, tkIdentifier, tkCompilerDirective], GetTokens('(*$IFDEF X}*)a(*$ENDIF*)'),
      'Conditional star paren directives with a curly brace');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount, 'Conditional star paren directives balance');

  // Like Delphi, the directive ends at its first closing bracket even inside quotes
  CheckTokensEqual([tkCompilerDirective, tkIdentifier, tkUnterminatedString], GetTokens('{$MESSAGE HINT ''a}b''}'),
      'Curly brace inside quotes ends the curly directive');
  CheckTokensEqual([tkCompilerDirective, tkIdentifier, tkUnterminatedString], GetTokens('(*$MESSAGE HINT ''a*)b''*)'),
      'Star paren end inside quotes ends the star paren directive');

  CheckTokensEqual([tkCompilerDirective], GetTokens('(*$DEFINE X}'), 'Unterminated star paren directive');
  // A null char ends the directive and the data
  CheckTokensEqual([tkCompilerDirective], GetTokens('{$DEFINE X' + #0 + '}y'), 'Null char inside a directive');
end;

procedure TestTPasLexerAdditional.TestCurlyDirectiveLineBreaks;
var
  S: string;
  Raised: Boolean;
begin
  // LF, CR, CRLF and LFCR (two line breaks): five line breaks inside one directive
  S := '{$DEFINE' + #10 + 'A' + #13 + 'B' + #13#10 + 'C' + #10#13 + '  D}  x' + sLineBreak + 'y';
  FPasLexer.SetData(S);
  CheckTokenAt(tkCompilerDirective, '{$DEFINE' + #10 + 'A' + #13 + 'B' + #13#10 + 'C' + #10#13 + '  D}', 1, 1, 'Directive');
  FPasLexer.NextToken;
  CheckTokenAt(tkSpace, '  ', 6, 5, 'Space after the directive');
  FPasLexer.NextToken;
  CheckTokenAt(tkIdentifier, 'x', 6, 7, 'Identifier after the directive');
  FPasLexer.NextToken;
  CheckTokenAt(tkCRLF, sLineBreak, 6, 8, 'Line break after the directive');
  FPasLexer.NextToken;
  CheckTokenAt(tkIdentifier, 'y', 7, 1, 'Identifier on the next line');

  // A lexer error after the directive reports its own line and column ({$ELSEIF} after {$ELSE} is an error)
  S := '{$IFDEF A' + sLineBreak + sLineBreak + '  B}' + sLineBreak + '  {$ELSE}{$ELSEIF B}{$ENDIF}';
  Raised := False;
  try
    FPasLexer.SetData(S);
    while FPasLexer.NextToken do;
  except
    on E: EPasLexerException do
    begin
      Raised := True;
      CheckEquals(EMESSAGE_UNEXPECTED_ELSE_DIRECTIVE, E.Message, 'Error message');
      CheckEquals(4, Integer(E.LineNumber), 'Line of the error');
      CheckEquals(10, Integer(E.LineCharIndex), 'Column of the error');
    end;
  end;
  CheckTrue(Raised, 'The ELSEIF directive after ELSE must raise an error');
end;

procedure TestTPasLexerAdditional.TestDigitSeparators;
var
  S: string;
begin
  CheckTokensEqual(
      [tkIdentifier, tkAssign, tkNumber, tkPlus, tkFloat, tkPlus, tkInteger, tkPlus, tkAsciiChar, tkSemiColon],
      GetTokensNoJunk('a := 1_000_000 + 1_000.000_5 + $FFFF_FFFF + #$00_41;'),
      'Digit separators in an expression');

  S := '1_000.5';
  FPasLexer.SetData(S);
  CheckTokenAt(tkFloat, '1_000.5', 1, 1, 'Real number with a digit separator');

  CheckTokensEqual([tkNumber], GetTokens('1__0_'), 'Several and trailing digit separators');
  CheckTokensEqual([tkFloat], GetTokens('1_.5'), 'Digit separator before the point');
  CheckTokensEqual([tkFloat], GetTokens('1_e3'), 'Digit separator before the exponent');
  CheckTokensEqual([tkFloat], GetTokens('1.5e+1_0'), 'Digit separator inside the exponent');
  CheckTokensEqual([tkInteger], GetTokens('$_FF_'), 'Digit separators around hexadecimal digits');
  CheckTokensEqual([tkAsciiChar, tkAsciiChar], GetTokens('#1_3#_10'), 'Digit separators in character codes');

  // Like Delphi, the exponent must start with a digit
  CheckTokensEqual([tkNumber, tkIdentifier], GetTokens('1E_5'), 'Digit separator right after the exponent');
  CheckTokensEqual([tkFloat, tkIdentifier, tkPlus, tkIdentifier], GetTokens('1.5e+_3'),
      'Digit separator right after the exponent sign');
  CheckTokensEqual([tkNumber, tkSpace, tkIdentifier], GetTokens('1 _a'), 'Identifier starting with an underscore');
end;

procedure TestTPasLexerAdditional.TestBinaryNumbers;
var
  S: string;
begin
  CheckTokensEqual(
      [tkIdentifier, tkAssign, tkInteger, tkAnd, tkInteger, tkSemiColon],
      GetTokensNoJunk('a := %1010_0101 and %1;'),
      'Binary numbers in an expression');

  S := '%1010';
  FPasLexer.SetData(S);
  CheckTokenAt(tkInteger, '%1010', 1, 1, 'Binary number');

  CheckTokensEqual([tkInteger], GetTokens('%_1_'), 'Digit separators around binary digits');
  // Like Delphi, the binary number ends at the first digit that is not binary
  CheckTokensEqual([tkInteger, tkNumber], GetTokens('%102'), 'Decimal digit after binary digits');
  // A percent sign without binary digits stays a symbol
  CheckTokensEqual([tkSymbol, tkNumber], GetTokens('%2'), 'Percent sign before a decimal digit');
  CheckTokensEqual([tkSymbol, tkSpace, tkInteger], GetTokens('% %0'), 'Single percent sign');
end;

procedure TestTPasLexerAdditional.TestNumberFollowedByPoint;
var
  S: string;
begin
  CheckTokensEqual(
      [tkIdentifier, tkAssign, tkNumber, tkPoint, tkIdentifier, tkSemiColon],
      GetTokensNoJunk('S := 1.ToString;'),
      'Method call on an integer literal');

  S := '1.ToString';
  FPasLexer.SetData(S);
  CheckTokenAt(tkNumber, '1', 1, 1, 'Number before the point');
  FPasLexer.NextToken;
  CheckTokenAt(tkPoint, '.', 1, 2, 'Point after the number');
  FPasLexer.NextToken;
  CheckTokenAt(tkIdentifier, 'ToString', 1, 3, 'Identifier after the point');

  // dcc32 reports "Undeclared identifier" for e5, E5, _5 and e: the exponent letter is not part of the number
  CheckTokensEqual([tkNumber, tkPoint, tkIdentifier], GetTokens('1.e5'), 'Lowercase exponent letter after the point');
  CheckTokensEqual([tkNumber, tkPoint, tkIdentifier], GetTokens('1.E5'), 'Uppercase exponent letter after the point');
  CheckTokensEqual([tkNumber, tkPoint, tkIdentifier], GetTokens('1._5'), 'Underscore after the point');
  CheckTokensEqual([tkNumber, tkPoint, tkIdentifier, tkPlus, tkNumber], GetTokens('10.e+45'),
      'Signed exponent after the point');
  CheckTokensEqual([tkNumber, tkPoint, tkType], GetTokens('1.type'), 'Keyword after the point');
  CheckTokensEqual([tkNumber, tkPoint, tkIdentifier], GetTokens('1_000.MaxValue'),
      'Digit separator before the point');
  CheckTokensEqual([tkFloat, tkPoint, tkIdentifier], GetTokens('1.5.ToString'), 'Method call on a real literal');
  CheckTokensEqual([tkFloat, tkPoint, tkIdentifier], GetTokens('1e5.ToString'),
      'Method call on a real literal with an exponent');

  // Any other character after the point makes a real number, the next token is separate
  CheckTokensEqual([tkFloat], GetTokens('1.'), 'Point at the end of the data');
  CheckTokensEqual([tkFloat, tkSemiColon], GetTokens('1.;'), 'Point before a semicolon');
  CheckTokensEqual([tkFloat, tkSpace, tkIdentifier], GetTokens('1. ToString'), 'Point before a space');
  CheckTokensEqual([tkFloat, tkSymbol, tkIdentifier], GetTokens('1.&ToString'), 'Point before an ampersand');
  CheckTokensEqual([tkFloat, tkIdentifier], GetTokens('1.' + #$00C4), 'Point before a non-ASCII letter');
  CheckTokensEqual([tkFloat, tkInteger], GetTokens('1.$5'), 'Point before a hexadecimal number');
  CheckTokensEqual([tkFloat, tkAsciiChar], GetTokens('1.#5'), 'Point before a character code');
end;

procedure TestTPasLexerAdditional.TestAsmDoubleQuotedStrings;
var
  S: string;
  State: TPasLexerState;
begin
  // System.AnsiStrings.pas: the single quote inside the double quotes does not start a string
  S := 'asm' + sLineBreak + '  CMP AL,"''"  // quote' + sLineBreak + 'end;';
  CheckTokensEqual([tkAsm, tkIdentifier, tkIdentifier, tkComma, tkString, tkEnd, tkSemiColon], GetTokensNoJunk(S),
      'Double-quoted single quote');
  FPasLexer.SetData(S);
  FPasLexer.NextTokenWithKind(tkString);
  CheckTokenAt(tkString, '"''"', 2, 10, 'BASM string');
  FPasLexer.NextToken;
  FPasLexer.NextToken;
  CheckTokenAt(tkSingleLineComment, '// quote', 2, 15, 'Comment after the BASM string');

  // Comment openers and brackets inside double quotes are text of the string
  CheckTokensEqual(
      [tkAsm, tkIdentifier, tkString, tkComma, tkString, tkComma, tkString, tkComma, tkString, tkComma, tkString, tkEnd],
      GetTokensNoJunk('asm DB "a''b", "", "{", "(*", "//" end'),
      'Double-quoted strings with quotes and comment openers');
  State := FPasLexer.LexerState;
  CheckTrue(State.CommentState = csNo, 'Comment state after the block');
  CheckEquals(0, State.Counters.RoundCount, 'Round brackets after the block');

  // Like Delphi, there are no escapes: "a""b" is two strings
  CheckTokensEqual([tkAsm, tkIdentifier, tkString, tkString, tkEnd], GetTokensNoJunk('asm DB "a""b" end'),
      'Doubled double quote');
  CheckTokensEqual([tkAsm, tkIdentifier, tkUnterminatedString, tkEnd, tkSemiColon],
      GetTokensNoJunk('asm DB "abc' + sLineBreak + 'end;'), 'Double-quoted string ends at the line end');
  CheckTokensEqual([tkAsm, tkIdentifier, tkString, tkEnd], GetTokensNoJunk('asm DB ''a"b'' end'),
      'Single-quoted string with a double quote inside an asm block');

  // Outside asm blocks a double quote stays a symbol
  CheckTokensEqual([tkSymbol, tkIdentifier, tkSymbol], GetTokens('"a"'), 'Double quotes outside an asm block');
  CheckTokensEqual(
      [tkBegin, tkAsm, tkIdentifier, tkIdentifier, tkComma, tkString, tkEnd, tkSemiColon, tkIdentifier, tkAssign,
      tkSymbol, tkIdentifier, tkSymbol, tkSemiColon, tkEnd, tkSemiColon],
      GetTokensNoJunk('begin asm CMP AL,"''" end; S := "x"; end;'),
      'Double quotes after an asm statement');
end;

procedure TestTPasLexerAdditional.TestAsmBlockFlag;
var
  S: string;
  State: TPasLexerState;
begin
  S := 'begin asm NOP end end';
  FPasLexer.SetData(S);
  CheckFalse(FPasLexer.LexerState.IsAsmBlock, 'Before asm');
  FPasLexer.NextTokenWithKind(tkAsm);
  CheckTrue(FPasLexer.LexerState.IsAsmBlock, 'After asm');
  FPasLexer.NextTokenWithKind(tkEnd);
  CheckFalse(FPasLexer.LexerState.IsAsmBlock, 'After the end of the block');

  // Vcl.Graphics.pas: BASM labels named @@END do not end the block
  CheckTokensEqual(
      [tkAsm, tkIdentifier, tkAddressSymbol, tkAddressSymbol, tkEnd, tkAddressSymbol, tkAddressSymbol, tkEnd, tkColon,
      tkIdentifier, tkIdentifier, tkComma, tkString, tkEnd],
      GetTokensNoJunk('asm JMP @@END' + sLineBreak + '@@END: CMP AL,"x"' + sLineBreak + 'end'),
      'Label named end inside an asm block');

  // '&asm' is an identifier
  CheckTokensEqual([tkSymbol, tkAsm, tkAssign, tkSymbol, tkIdentifier, tkSymbol, tkSemiColon],
      GetTokensNoJunk('&asm := "x";'), 'Escaped asm');
  CheckFalse(FPasLexer.LexerState.IsAsmBlock, 'After an escaped asm');

  // The flag is a part of the lexer state
  S := 'asm "a" end';
  FPasLexer.SetData(S);
  State := FPasLexer.LexerState;
  FPasLexer.NextTokenWithKind(tkEnd);
  FPasLexer.LexerState := State;
  CheckTrue(FPasLexer.LexerState.IsAsmBlock, 'Restored lexer state');
  FPasLexer.NextTokenNoJunk;
  CheckTokenAt(tkString, '"a"', 1, 5, 'BASM string after the restored state');
  S := '"a"';
  FPasLexer.SetData(S);
  CheckTokenAt(tkSymbol, '"', 1, 1, 'Double quote after SetData');
end;

initialization
  RegisterTest(TestTPasLexerAdditional.Suite);

end.