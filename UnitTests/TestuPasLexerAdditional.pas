unit TestuPasLexerAdditional;

{
  Additional tests for TPasLexer.
  The goal of this suite is to exercise as much of TPasLexer as possible:
  every run handler (tokens), the post-identifier handlers, the compiler
  directive logic, the prefix tree keyword matching and the public API.
}

interface

uses
  TestFramework, System.SysUtils, System.Character,
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
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestIdentifiersAndPunctuation;
    procedure TestNumbers;
    procedure TestStrings;
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
    procedure TestNextTokenNoDirectiveBranchingElseBranch;
    procedure TestEmbeddedNullChar;
    procedure TestTrailingLineBreak;
    procedure TestConsecutiveLineBreaks;
    procedure TestNumberIdentifierSequences;
    procedure TestStarParenDirectiveLineBreak;
    procedure TestDirectiveKeywordEdgeCases;
    procedure TestDirectiveErrorCountersNotFoundOnRestore;
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
    if not (Token in DIRECTIVE_UNSIGNIFICANT_TOKENS) then
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
    while FPasLexer.NextToken do ;
  except
    on E: EPasLexerException do
    begin
      Raised := True;
      CheckEquals(AExpected, E.Message, 'Unexpected exception message');
    end;
  end;
  CheckTrue(Raised, 'Expected EPasLexerException for: ' + ASource);
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
  while FPasLexer.NextToken do ;
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
  ExpectsLexerException('{$IFDEF A}{$ELSE}{$ELSE}{$ENDIF}',
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
    while FPasLexer.NextToken do ;
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
  while FPasLexer.NextToken do ;
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
begin
  for i := Low(Samples) to High(Samples) do
  begin
    S := Samples[i];
    FPasLexer.SetData(S);
    if i = High(Samples) then
    begin
      // unmatched {$ELSE} needs directive checks disabled to lex to EOF
      var LState: TPasLexerState := FPasLexer.LexerState;
      LState.IgnoreCompilerDirectiveChecks := True;
      FPasLexer.LexerState := LState;
    end;
    while FPasLexer.NextToken do ;
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

// Starting inside the else branch returns the tokens of that branch only
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

// #0 terminates the data for the lexer: everything after it is not lexed
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

// A line break at the very end of the data is still counted
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

// CRCR, LF and LFCR are each a single line break token
procedure TestTPasLexerAdditional.TestConsecutiveLineBreaks;
begin
  CheckTokensEqual(
      [tkIdentifier, tkCRLF, tkCRLF, tkIdentifier, tkCRLF, tkCRLF, tkIdentifier],
      GetTokens('a' + #13#13 + 'b' + #10#13 + 'c'),
      'Consecutive line breaks');
  CheckEquals(5, Integer(FPasLexer.LexerState.CurrentLine),
      'Line after the last line break');
end;

// Numbers and identifiers are separated even without whitespace
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

// (*$...*) directives are read like comments and do not span lines
procedure TestTPasLexerAdditional.TestStarParenDirectiveLineBreak;
begin
  // +++ поидее неправильно
  CheckTokensEqual(
      [tkCompilerDirective, tkIdentifier],
      GetTokens('(*$IFDEF X' + sLineBreak + 'Y*)z'),
      'Star paren directive with a line break');
end;

// Conditional directive recognition inside the curly braces
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

// The state array must contain an idsIf entry to restore the counters from
procedure TestTPasLexerAdditional.TestDirectiveErrorCountersNotFoundOnRestore;
var
  S: string;
  LState: TPasLexerState;
  Raised: Boolean;

  procedure ExpectCounterRestoreError(const AMessage: string);
  begin
    Raised := False;
    try
      while FPasLexer.NextToken do ;
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

initialization
  RegisterTest(TestTPasLexerAdditional.Suite);

end.