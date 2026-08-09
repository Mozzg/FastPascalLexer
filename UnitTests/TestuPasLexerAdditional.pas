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
  strict private
    FPasLexer: TPasLexer;
    function TokenNames(const ASource: string): string;
    function TokenNamesNoJunk(const ASource: string): string;
    procedure ExpectsLexerException(const ASource, SExpected: string);
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
    procedure TestNextTokenNoJunk;
    procedure TestNextTokenWithKind;
    procedure TestNextTokenNoDirectiveBranching;
    procedure TestLexerDumpSamples;
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

function TestTPasLexerAdditional.TokenNames(const ASource: string): string;
var
  S: string;
begin
  S := ASource;
  FPasLexer.SetData(S);
  Result := TOKEN_NAMES[FPasLexer.TokenID];
  while FPasLexer.NextToken do
    Result := Result + ';' + TOKEN_NAMES[FPasLexer.TokenID];
end;

function TestTPasLexerAdditional.TokenNamesNoJunk(const ASource: string): string;
var
  S: string;
  Token: TTokenKind;
begin
  Result := '';
  S := ASource;
  FPasLexer.SetData(S);
  Token := FPasLexer.TokenID;
  if not (Token in DIRECTIVE_UNSIGNIFICANT_TOKENS) then
    Result := TOKEN_NAMES[Token];
  while FPasLexer.NextToken do
  begin
    Token := FPasLexer.TokenID;
    if not (Token in DIRECTIVE_UNSIGNIFICANT_TOKENS) then
      Result := Result + ';' + TOKEN_NAMES[Token];
  end;
end;

procedure TestTPasLexerAdditional.ExpectsLexerException(const ASource, SExpected: string);
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
      CheckEquals(SExpected, E.Message, 'Unexpected exception message');
    end;
  end;
  CheckTrue(Raised, 'Expected EPasLexerException for: ' + ASource);
end;

procedure TestTPasLexerAdditional.TestIdentifiersAndPunctuation;
var
  S: string;
begin
  S := 'MyVar _temp var1;';
  FPasLexer.SetData(S);

  CheckEquals(Integer(tkIdentifier), Integer(FPasLexer.TokenID), 'First token must be identifier');

  CheckTrue(FPasLexer.NextToken, 'Expected space token');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID), 'Second token must be space');

  CheckTrue(FPasLexer.NextToken, 'Expected second identifier');
  CheckEquals(Integer(tkIdentifier), Integer(FPasLexer.TokenID), 'Third token must be identifier');

  CheckTrue(FPasLexer.NextToken, 'Expected space token');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID), 'Fourth token must be space');

  CheckTrue(FPasLexer.NextToken, 'Expected third identifier');
  CheckEquals(Integer(tkIdentifier), Integer(FPasLexer.TokenID), 'Fifth token must be identifier');

  CheckTrue(FPasLexer.NextToken, 'Expected semicolon token');
  CheckEquals(Integer(tkSemiColon), Integer(FPasLexer.TokenID), 'Sixth token must be semicolon');

  CheckFalse(FPasLexer.NextToken, 'No more tokens expected');
end;

procedure TestTPasLexerAdditional.TestNumbers;
var
  S: string;
begin
  S := 'a := 123; b := 12.34e-2; c := $FF;';
  FPasLexer.SetData(S);

  CheckEquals(Integer(tkIdentifier), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected space token after identifier');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected assign token');
  CheckEquals(Integer(tkAssign), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected space after assign');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected number token');
  CheckEquals(Integer(tkNumber), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected semicolon token');
  CheckEquals(Integer(tkSemiColon), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected space token');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected identifier b');
  CheckEquals(Integer(tkIdentifier), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected space token');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected assign token');
  CheckEquals(Integer(tkAssign), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected space token');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected float token');
  CheckTrue((FPasLexer.TokenID = tkFloat) or (FPasLexer.TokenID = tkNumber), 'Expected float or number token');

  CheckTrue(FPasLexer.NextToken, 'Expected semicolon token');
  CheckEquals(Integer(tkSemiColon), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected space token');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected identifier c');
  CheckEquals(Integer(tkIdentifier), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected space token');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected assign token');
  CheckEquals(Integer(tkAssign), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected space token');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected hex integer token');
  CheckEquals(Integer(tkInteger), Integer(FPasLexer.TokenID), 'Hex literal should be integer token');

  CheckTrue(FPasLexer.NextToken, 'Expected semicolon token');
  CheckEquals(Integer(tkSemiColon), Integer(FPasLexer.TokenID));

  CheckFalse(FPasLexer.NextToken, 'No more tokens expected');
end;

procedure TestTPasLexerAdditional.TestStrings;
var
  S: string;
begin
  S := 's := ''hello'';';
  FPasLexer.SetData(S);
  CheckEquals(Integer(tkIdentifier), Integer(FPasLexer.TokenID));
  CheckTrue(FPasLexer.NextToken, 'Expected space after identifier');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));
  CheckTrue(FPasLexer.NextToken, 'Expected assign token');
  CheckEquals(Integer(tkAssign), Integer(FPasLexer.TokenID));
  CheckTrue(FPasLexer.NextToken, 'Expected space after assign');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));
  CheckTrue(FPasLexer.NextToken, 'Expected string token');
  CheckEquals(Integer(tkString), Integer(FPasLexer.TokenID));

  // An empty string literal '' (two quotes) is still a string token
  S := #39#39;
  FPasLexer.SetData(S);
  CheckEquals(Integer(tkString), Integer(FPasLexer.TokenID), 'An empty string literal');

  S := 't := ''notclosed';
  FPasLexer.SetData(S);
  CheckEquals(Integer(tkIdentifier), Integer(FPasLexer.TokenID));
  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));
  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkAssign), Integer(FPasLexer.TokenID));
  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));
  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkUnterminatedString), Integer(FPasLexer.TokenID));
end;

procedure TestTPasLexerAdditional.TestComments;
var
  S: string;
begin
  S := '{comment} (* another comment *) // single line' + sLineBreak + 'x';
  FPasLexer.SetData(S);

  CheckEquals(Integer(tkCurlyComment), Integer(FPasLexer.TokenID), 'First token should be curly comment');

  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID), 'Second token should be space between comments');

  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkStarParenComment), Integer(FPasLexer.TokenID), 'Third token should be star/paren comment');

  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID), 'Fourth token should be space after star/paren comment');

  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkSingleLineComment), Integer(FPasLexer.TokenID), 'Fifth token should be single line comment');

  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkCRLF), Integer(FPasLexer.TokenID), 'Newline after single line comment');

  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkIdentifier), Integer(FPasLexer.TokenID), 'Final identifier after newline');
end;

procedure TestTPasLexerAdditional.TestCompilerDirectivesAndCounters;
var
  S: string;
  LState: TPasLexerState;
begin
  S := '{$IFDEF A}{$IFDEF B}{$ENDIF}{$ENDIF}';
  FPasLexer.SetData(S);

  while FPasLexer.NextToken do
  begin
    // let the lexer process the directive counters
  end;

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
  CheckEquals(
    'tkIdentifier;tkSpace;tkAssign;tkSpace;tkNotEqual;tkSpace;tkLowerEqual;tkSpace;tkGreaterEqual;' +
    'tkSpace;tkEqual;tkSpace;tkPlus;tkSpace;tkMinus;tkSpace;tkStar;tkSpace;tkSlash;tkSpace;' +
    'tkRoundOpen;tkSpace;tkRoundClose;tkSpace;tkSquareOpen;tkSpace;tkSquareClose;tkSpace;' +
    'tkPointerSymbol;tkSpace;tkPoint;tkSpace;tkDotDot;tkSpace;tkComma;tkSpace;tkAddressSymbol;' +
    'tkSpace;tkSemiColon;tkSpace;tkColon',
    TokenNames('x8 := <> <= >= = + - * / ( ) [ ] ^ . .. , @ ; :'),
    'Operator and punctuation token sequence');

  CheckEquals('tkSquareOpen;tkSquareClose',
    TokenNames('(..)'),
    'Legacy ( . ... . ) square brackets');
  CheckEquals('tkRoundOpen;tkRoundClose',
    TokenNames('()'),
    'Plain parentheses');
end;

procedure TestTPasLexerAdditional.TestGenericSymbols;
begin
  CheckEquals(
    'tkSymbol;tkSpace;tkSymbol;tkSpace;tkSymbol;tkSpace;tkSymbol;tkSpace;tkSymbol;tkSpace;' +
    'tkSymbol;tkSpace;tkSymbol;tkSpace;tkUnknown',
    TokenNames('! % & \ ? ~ " }'),
    'Generic symbol mapping and unmatched right brace');
  CheckEquals('tkUnknown', TokenNames('}'), 'A lone closing brace is unknown');
end;

procedure TestTPasLexerAdditional.TestNumbersExponentAndHex;
begin
  CheckEquals(
    'tkNumber;tkSpace;tkFloat;tkSpace;tkFloat;tkSpace;tkFloat;tkSpace;tkFloat;tkSpace;' +
    'tkInteger;tkSpace;tkNumber',
    TokenNames('0 1.5 1.5e3 1E-2 10.25E+8 $AB 42'),
    'Number, float, exponent and hex literals');
end;

procedure TestTPasLexerAdditional.TestAsciiChars;
begin
  CheckEquals('tkAsciiChar;tkSpace;tkAsciiChar', TokenNames('#65 #$AF'),
    'Numeric character literals');
  CheckEquals('tkAsciiChar;tkAsciiChar', TokenNames('#0#1'),
    'Adjacent character literals');
end;

procedure TestTPasLexerAdditional.TestIdentifiers;
begin
  CheckEquals('tkIdentifier', TokenNames('foo'), 'Simple identifier');
  CheckEquals('tkIdentifier', TokenNames('_foo'), 'Identifier starting with underscore');
  CheckEquals('tkIdentifier', TokenNames('foo1_2'), 'Identifier containing digits');
  CheckEquals('tkIdentifier', TokenNames(#$00E9'clair'), 'Identifier containing non-ascii');
end;

procedure TestTPasLexerAdditional.TestAllKeywords;
var
  i: Integer;
  S: string;
begin
  for i := Low(DELPHI_KEYWORDS) to High(DELPHI_KEYWORDS) do
  begin
    S := DELPHI_KEYWORDS[i].Word;
    FPasLexer.SetData(S);
    if DELPHI_KEYWORDS[i].Token in [tkRead, tkWrite, tkIndex, tkStored, tkDefault, tkNodefault] then
      CheckEquals(Integer(tkIdentifier), Integer(FPasLexer.TokenID),
        'Property directive ' + DELPHI_KEYWORDS[i].Word + ' is an identifier outside a property')
    else
      CheckEquals(Integer(DELPHI_KEYWORDS[i].Token), Integer(FPasLexer.TokenID),
        'Keyword ' + DELPHI_KEYWORDS[i].Word);
  end;
end;

procedure TestTPasLexerAdditional.TestKeywordCaseInsensitivity;
begin
  CheckEquals('tkBegin', TokenNames('begin'));
  CheckEquals('tkBegin', TokenNames('BEGIN'));
  CheckEquals('tkBegin', TokenNames('BeGiN'));
  CheckEquals('tkProcedure', TokenNames('procedure'));
  CheckEquals('tkProgram', TokenNames('pRoGrAm'));
end;

procedure TestTPasLexerAdditional.TestCommentLineBreaks;
var
  Multi: string;
begin
  Multi := '{line1' + sLineBreak + 'line2}';
  CheckEquals('tkCurlyComment;tkCRLFComment;tkCurlyComment',
    TokenNames(Multi), 'Multiline curly comment');
  Multi := '(*line1' + sLineBreak + 'line2*)';
  CheckEquals('tkStarParenComment;tkCRLFComment;tkStarParenComment',
    TokenNames(Multi), 'Multiline star/paren comment');
end;

procedure TestTPasLexerAdditional.TestCommentAtEndOfFile;
begin
  CheckEquals('tkSingleLineComment', TokenNames('// no trailing newline'), 'Single line comment at EOF');
  CheckEquals('tkCurlyComment', TokenNames('{ unterminated'), 'Unterminated curly comment');
  CheckEquals('tkStarParenComment', TokenNames('(* unterminated'), 'Unterminated star comment');
end;

procedure TestTPasLexerAdditional.TestCompilerDirectiveNesting;
begin
  TokenNames('{$IFDEF A}{$IFNDEF B}{$IFOPT C}{$IFEND}{$ENDIF}{$ENDIF}');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount,
    'Balanced dialog nesting ends with zero directives on the stack');

  TokenNames('{$IFDEF A}{$ELSEIF B}{$ELSE}{$ENDIF}');
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
  TokenNames('{$IFDEF A}[(x)]{$ELSE}(y){$ENDIF}');
  CheckEquals(0, FPasLexer.LexerState.Counters.RoundCount);
  CheckEquals(0, FPasLexer.LexerState.Counters.SquareCount);
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount);
end;
procedure TestTPasLexerAdditional.TestPropertyTokens;
begin
  CheckEquals(
    'tkProperty;tkIdentifier;tkColon;tkIdentifier;tkRead;tkIdentifier;tkWrite;tkIdentifier;' +
    'tkSemiColon;tkIdentifier;tkIdentifier',
    TokenNamesNoJunk('property Value : Integer read GetValue write SetValue; x read'),
    'Property directive tokens are context sensitive');

  CheckEquals('tkProperty;tkIdentifier;tkColon;tkIdentifier;tkDefault;tkNumber;tkSemiColon',
    TokenNamesNoJunk('property V : Integer default 3;'));

  CheckEquals('tkIdentifier', TokenNames('read'), 'read outside of property');
  CheckEquals('tkIdentifier', TokenNames('write'), 'write outside of property');
  CheckEquals('tkIdentifier', TokenNames('index'), 'index outside of property');
  CheckEquals('tkIdentifier', TokenNames('stored'), 'stored outside of property');
  CheckEquals('tkIdentifier', TokenNames('nodefault'), 'nodefault outside of property');
  CheckEquals('tkIdentifier', TokenNames('default'), 'default outside of property');
end;

procedure TestTPasLexerAdditional.TestEndTokens;
begin
  CheckEquals('tkUnitEnd', TokenNames('end.'), 'Unit end token');
  CheckEquals('tkEnd;tkSpace;tkPoint', TokenNames('end .'), 'end and dot separated by space');
  CheckEquals('tkEnd;tkSpace;tkSemiColon', TokenNames('end ;'), 'end followed by semicolon');
  CheckEquals('tkEnd', TokenNames('end'), 'Plain end');
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
var
  S: string;
begin
  S := 'begin end';
  FPasLexer.SetData(S);
  CheckEquals(Integer(tkBegin), Integer(FPasLexer.TokenID));
  FPasLexer.NextToken;   // space
  FPasLexer.NextToken;   // end
  CheckEquals(Integer(tkEnd), Integer(FPasLexer.TokenID));

  FPasLexer.Reset;
  CheckEquals(Integer(tkBegin), Integer(FPasLexer.TokenID), 'Reset rewinds to the first token');
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
  CheckEquals(Integer(tkAssign), Integer(FPasLexer.TokenID), 'State restore keeps token id');
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
  CheckEquals(Integer(tkCRLF), Integer(FPasLexer.TokenID));
  CheckEquals(1, Integer(FPasLexer.LexerState.CurrentLine), 'Still on line 1 on the CRLF token');

  FPasLexer.NextToken;      // bb
  CheckEquals(Integer(tkIdentifier), Integer(FPasLexer.TokenID));
  CheckEquals(2, Integer(FPasLexer.LexerState.CurrentLine), 'Line 2 after the line break');
end;

procedure TestTPasLexerAdditional.TestEOFBehavior;
var
  S: string;
begin
  S := 'and';
  FPasLexer.SetData(S);
  CheckEquals(Integer(tkAnd), Integer(FPasLexer.TokenID));
  CheckFalse(FPasLexer.NextToken, 'NextToken returns False at end of input');
  CheckEquals(Integer(tkEOF), Integer(FPasLexer.TokenID), 'Token becomes tkEOF');
  CheckFalse(FPasLexer.NextToken, 'Remains tkEOF');
end;

procedure TestTPasLexerAdditional.TestNextTokenNoJunk;
var
  S: string;
begin
  S := '{comment}{*star*}//sl' + sLineBreak + 'a[$0]';
  FPasLexer.SetData(S);
  CheckEquals(Integer(tkCurlyComment), Integer(FPasLexer.TokenID), 'Source begins with a comment');

  CheckTrue(FPasLexer.NextTokenNoJunk, 'NextTokenNoJunk reaches the code');
  CheckEquals(Integer(tkIdentifier), Integer(FPasLexer.TokenID), 'Identifier after comments');
  CheckEquals('a', FPasLexer.TokenString, 'Correct identifier text');
end;

procedure TestTPasLexerAdditional.TestNextTokenWithKind;
var
  S: string;
begin
  S := 'x := 1; b := 2;';
  FPasLexer.SetData(S);
  CheckTrue(FPasLexer.NextTokenWithKind(tkAssign), 'First assign found');
  CheckEquals(Integer(tkAssign), Integer(FPasLexer.TokenID));
  CheckTrue(FPasLexer.NextTokenWithKind(tkAssign), 'Second assign found');
  CheckEquals(Integer(tkAssign), Integer(FPasLexer.TokenID));
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
    '{$IFDEF A}{$ELSE}');
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
    CheckEquals(Integer(tkEOF), Integer(FPasLexer.TokenID),
      Format('Sample %d must lex to EOF: %s', [i, S]));
  end;
end;

initialization
  RegisterTest(TestTPasLexerAdditional.Suite);

end.
