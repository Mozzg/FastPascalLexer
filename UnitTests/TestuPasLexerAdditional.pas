unit TestuPasLexerAdditional;
{
  Additional tests for TPasLexer focusing on tokenization behavior.

  The tests are written to reach every handler and every state branch of
  TPasLexer:
    - run handlers: whitespace, line breaks, ascii chars, hex numbers, numbers,
      strings, comments, operators, symbols and unknown characters;
    - identifier/keyword recognition through the prefix tree, including keyword
      prefixes, identifiers with digits/underscores and non ascii identifiers;
    - post identifier handlers: property, property directives, end/unit end;
    - the comment state machine, including multi line comments and comments
      that are not terminated at end of data;
    - the compiler directive state machine: counters, if/elseif/else/endif
      state arrays and all reachable error messages;
    - lexer state save/restore and the NextTokenXXX helpers.

  TPasLexer emits whitespace and comment tokens by design, so most expectations
  below are written against the complete token stream. Where whitespace is not
  interesting the token list is filtered with TokenizeNoJunk.
}

interface

uses
  TestFramework, System.SysUtils, System.Character,
  uPasLexer, uPasLexerTypes, uPasExceptions;

type
  // Snapshot of everything the lexer exposes about a single token
  TLexToken = record
    Kind: TTokenKind;
    Text: string;
    Line: Cardinal;
    TokenPos: Cardinal;
    LineStartPos: Cardinal;
    CommentState: TCommentState;
  end;
  TLexTokenArray = TArray<TLexToken>;

  TestTPasLexerAdditional = class(TTestCase)
  strict private
    FPasLexer: TPasLexer;
    // The lexer keeps a pointer inside the data string, so the string has to
    // stay alive (and unshared) while the lexer is used.
    FData: string;

    procedure SetLexerData(const AData: string);
    function CurrentLexToken: TLexToken;
    function TokenizeAll(const AData: string): TLexTokenArray;
    function TokenizeNoJunk(const AData: string): TLexTokenArray;
    function LexAllCatchException(const AData: string): string;

    procedure CheckTokenKinds(const AContext: string; const ATokens: TLexTokenArray;
        const AExpected: array of TTokenKind);
    procedure CheckTokenTexts(const AContext: string; const ATokens: TLexTokenArray;
        const AExpected: array of string);
    procedure CheckTokenLines(const AContext: string; const ATokens: TLexTokenArray;
        const AExpected: array of Integer);
    procedure CheckCounters(const AContext: string; ARoundCount, ASquareCount, AIfDirectiveCount: Integer);
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestIdentifiersAndPunctuation;
    procedure TestNumbers;
    procedure TestStrings;
    procedure TestComments;
    procedure TestCompilerDirectivesAndCounters;

    procedure TestInitialLexerState;
    procedure TestResetRestartsLexing;
    procedure TestWhitespaceHandling;
    procedure TestLineTracking;
    procedure TestOperators;
    procedure TestSymbolAndUnknownChars;
    procedure TestAsciiCharAndHexNumbers;
    procedure TestNumberEdgeCases;
    procedure TestStringEdgeCases;
    procedure TestSingleLineComments;
    procedure TestMultiLineCurlyComment;
    procedure TestMultiLineStarParenComment;
    procedure TestStarParenCompilerDirective;
    procedure TestUnterminatedComments;
    procedure TestCommentForeignTerminators;
    procedure TestAllKeywords;
    procedure TestIdentifierEdgeCases;
    procedure TestNonAsciiIdentifiers;
    procedure TestPropertyDirectives;
    procedure TestEndAndUnitEnd;
    procedure TestBracketCounters;
    procedure TestMultiLineCompilerDirective;
    procedure TestConditionalDirectiveKinds;
    procedure TestElseIfDirectiveChain;
    procedure TestDirectiveErrorUnexpectedElse;
    procedure TestDirectiveErrorCountersMismatch;
    procedure TestDirectiveErrorStateMismatch;
    procedure TestIgnoreCompilerDirectiveChecks;
    procedure TestLastSignificantToken;
    procedure TestLexerStateSaveRestore;
    procedure TestNextTokenNoJunk;
    procedure TestNextTokenWithKind;
    procedure TestNextTokenNoDirectiveBranching;
  end;

implementation

const
  // Tokens skipped by TPasLexer.NextTokenNoJunk
  JUNK_TOKENS: TTokenKindSet = [tkCurlyComment, tkSingleLineComment, tkStarParenComment, tkCompilerDirective,
      tkCRLF, tkCRLFComment, tkSpace];
  // Handled by TPasLexer.PropertyDirectivePostHandler
  PROPERTY_DIRECTIVE_TOKENS: TTokenKindSet = [tkRead, tkWrite, tkIndex, tkStored, tkDefault, tkNodefault];

  QUOTE = '''';
  CYRILLIC_PE = #$041F;  // Cyrillic capital letter PE, above the run handler table
  CYRILLIC_A = #$0430;   // Cyrillic small letter A, above the run handler table

  NO_EXCEPTION_MESSAGE = '<no exception was raised>';

// Makes control characters visible in test failure messages
function DisplayText(const AText: string): string;
var
  i: Integer;
begin
  Result := EmptyStr;
  for i := Low(AText) to High(AText) do
    case AText[i] of
      #13: Result := Result + '\r';
      #10: Result := Result + '\n';
      #9: Result := Result + '\t';
      #0..#8, #11, #12, #14..#31, #127: Result := Result + '#' + IntToStr(Ord(AText[i]));
    else
      Result := Result + AText[i];
    end;
end;

function TokensToString(const ATokens: TLexTokenArray): string;
var
  i: Integer;
begin
  Result := EmptyStr;
  for i := Low(ATokens) to High(ATokens) do
    Result := Result + Format('%d:%s(%s) ', [i, TOKEN_NAMES[ATokens[i].Kind], DisplayText(ATokens[i].Text)]);
end;

{ TestTPasLexerAdditional }

procedure TestTPasLexerAdditional.SetUp;
begin
  FPasLexer := TPasLexer.Create;
end;

procedure TestTPasLexerAdditional.TearDown;
begin
  FreeAndNil(FPasLexer);
  FData := EmptyStr;
end;

procedure TestTPasLexerAdditional.SetLexerData(const AData: string);
begin
  FData := AData;
  // The lexer stores @FData[1], make sure the buffer is not shared with the
  // literal or with a previous data string.
  UniqueString(FData);
  FPasLexer.SetData(FData);
end;

function TestTPasLexerAdditional.CurrentLexToken: TLexToken;
begin
  Result.Kind := FPasLexer.TokenID;
  Result.Text := FPasLexer.TokenString;
  Result.Line := FPasLexer.LexerState.CurrentLine;
  Result.TokenPos := FPasLexer.LexerState.CurrentTokenPos;
  Result.LineStartPos := FPasLexer.LexerState.CurrentLineStartPos;
  Result.CommentState := FPasLexer.LexerState.CommentState;
end;

// Collects every token, including whitespace, comments and directives.
// The tkEOF token itself is not collected.
function TestTPasLexerAdditional.TokenizeAll(const AData: string): TLexTokenArray;
var
  Count: Integer;
begin
  SetLexerData(AData);

  Count := 0;
  SetLength(Result, 32);
  while FPasLexer.TokenID <> tkEOF do
  begin
    if Count = Length(Result) then
      SetLength(Result, Count * 2);
    Result[Count] := CurrentLexToken;
    Inc(Count);

    if not FPasLexer.NextToken then
      Break;
  end;
  SetLength(Result, Count);
end;

// Same as TokenizeAll, but without whitespace/comment/directive tokens.
// The junk is filtered here instead of using TPasLexer.NextTokenNoJunk,
// because that method never returns once the data is exhausted (its loop
// condition "Result and not junk" can not become True at tkEOF).
function TestTPasLexerAdditional.TokenizeNoJunk(const AData: string): TLexTokenArray;
var
  Count: Integer;
begin
  SetLexerData(AData);

  Count := 0;
  SetLength(Result, 32);
  while FPasLexer.TokenID <> tkEOF do
  begin
    if not (FPasLexer.TokenID in JUNK_TOKENS) then
    begin
      if Count = Length(Result) then
        SetLength(Result, Count * 2);
      Result[Count] := CurrentLexToken;
      Inc(Count);
    end;

    if not FPasLexer.NextToken then
      Break;
  end;
  SetLength(Result, Count);
end;

// Lexes the whole data and returns the message of the raised lexer exception
function TestTPasLexerAdditional.LexAllCatchException(const AData: string): string;
begin
  try
    SetLexerData(AData);
    while FPasLexer.NextToken do ;
    Result := NO_EXCEPTION_MESSAGE;
  except
    on E: EPasLexerException do
      Result := E.Message;
  end;
end;

procedure TestTPasLexerAdditional.CheckTokenKinds(const AContext: string; const ATokens: TLexTokenArray;
    const AExpected: array of TTokenKind);
var
  i: Integer;
begin
  CheckEquals(Length(AExpected), Length(ATokens), AContext + ': token count, got ' + TokensToString(ATokens));
  for i := Low(AExpected) to High(AExpected) do
    CheckEquals(TOKEN_NAMES[AExpected[i]], TOKEN_NAMES[ATokens[i].Kind],
        Format('%s: token %d kind, text=%s', [AContext, i, DisplayText(ATokens[i].Text)]));
end;

procedure TestTPasLexerAdditional.CheckTokenTexts(const AContext: string; const ATokens: TLexTokenArray;
    const AExpected: array of string);
var
  i: Integer;
begin
  CheckEquals(Length(AExpected), Length(ATokens), AContext + ': token count, got ' + TokensToString(ATokens));
  for i := Low(AExpected) to High(AExpected) do
    CheckEquals(DisplayText(AExpected[i]), DisplayText(ATokens[i].Text),
        Format('%s: token %d text, kind=%s', [AContext, i, TOKEN_NAMES[ATokens[i].Kind]]));
end;

procedure TestTPasLexerAdditional.CheckTokenLines(const AContext: string; const ATokens: TLexTokenArray;
    const AExpected: array of Integer);
var
  i: Integer;
begin
  CheckEquals(Length(AExpected), Length(ATokens), AContext + ': token count, got ' + TokensToString(ATokens));
  for i := Low(AExpected) to High(AExpected) do
    CheckEquals(AExpected[i], Integer(ATokens[i].Line),
        Format('%s: token %d line, kind=%s, text=%s', [AContext, i, TOKEN_NAMES[ATokens[i].Kind],
        DisplayText(ATokens[i].Text)]));
end;

procedure TestTPasLexerAdditional.CheckCounters(const AContext: string; ARoundCount, ASquareCount,
    AIfDirectiveCount: Integer);
begin
  CheckEquals(ARoundCount, FPasLexer.LexerState.Counters.RoundCount, AContext + ': RoundCount');
  CheckEquals(ASquareCount, FPasLexer.LexerState.Counters.SquareCount, AContext + ': SquareCount');
  CheckEquals(AIfDirectiveCount, FPasLexer.LexerState.Counters.IfDirectiveCount, AContext + ': IfDirectiveCount');
end;

procedure TestTPasLexerAdditional.TestIdentifiersAndPunctuation;
var S: string;
begin
  // simple identifiers with underscore and digits and a semicolon
  S := 'MyVar _temp var1;';
  FPasLexer.SetData(S);

  // Expect sequence including space tokens: Identifier, Space, Identifier, Space, Identifier, SemiColon
  // First token is already set by SetData/Reset
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

  // No more tokens (NextToken should return False when moving past EOF)
  CheckFalse(FPasLexer.NextToken, 'No more tokens expected');
end;

procedure TestTPasLexerAdditional.TestNumbers;
var S: string;
begin
  S := 'a := 123; b := 12.34e-2; c := $FF;';
  FPasLexer.SetData(S);

  // a identifier
  // First token is already set by SetData/Reset
  CheckEquals(Integer(tkIdentifier), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected space token after identifier');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));

  // :=
  CheckTrue(FPasLexer.NextToken, 'Expected assign token');
  CheckEquals(Integer(tkAssign), Integer(FPasLexer.TokenID));

  CheckTrue(FPasLexer.NextToken, 'Expected space after assign');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));

  // 123
  CheckTrue(FPasLexer.NextToken, 'Expected number token');
  CheckEquals(Integer(tkNumber), Integer(FPasLexer.TokenID));

  // ;
  CheckTrue(FPasLexer.NextToken, 'Expected semicolon token');
  CheckEquals(Integer(tkSemiColon), Integer(FPasLexer.TokenID));

  // space
  CheckTrue(FPasLexer.NextToken, 'Expected space token');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));

  // b
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

  // ;
  CheckTrue(FPasLexer.NextToken, 'Expected semicolon token');
  CheckEquals(Integer(tkSemiColon), Integer(FPasLexer.TokenID));

  // space
  CheckTrue(FPasLexer.NextToken, 'Expected space token');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));

  // c
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

  // Next should be semicolon
  CheckTrue(FPasLexer.NextToken, 'Expected semicolon token');
  CheckEquals(Integer(tkSemiColon), Integer(FPasLexer.TokenID));

  // No more tokens
  CheckFalse(FPasLexer.NextToken, 'No more tokens expected');
end;

procedure TestTPasLexerAdditional.TestStrings;
var S: string;
begin
  // Proper string
  S := 's := ''hello'';';
  FPasLexer.SetData(S);
  // First token is already set by SetData/Reset
  CheckEquals(Integer(tkIdentifier), Integer(FPasLexer.TokenID));
  CheckTrue(FPasLexer.NextToken, 'Expected space after identifier');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));
  CheckTrue(FPasLexer.NextToken, 'Expected assign token');
  CheckEquals(Integer(tkAssign), Integer(FPasLexer.TokenID));
  CheckTrue(FPasLexer.NextToken, 'Expected space after assign');
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID));
  CheckTrue(FPasLexer.NextToken, 'Expected string token');
  CheckEquals(Integer(tkString), Integer(FPasLexer.TokenID));

  // Unterminated string should be reported as tkUnterminatedString by lexer
  S := 't := ''notclosed';
  FPasLexer.SetData(S);
  // sequence: identifier, space, assign, space, unterminated string
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
var S: string;
begin
  // Test different comment styles
  S := '{comment} (* another comment *) // single line' + sLineBreak + 'x';
  FPasLexer.SetData(S);

  // First token is already set by SetData/Reset
  CheckEquals(Integer(tkCurlyComment), Integer(FPasLexer.TokenID), 'First token should be curly comment');

  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID), 'Second token should be space between comments');

  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkStarParenComment), Integer(FPasLexer.TokenID), 'Third token should be star/paren comment');

  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkSpace), Integer(FPasLexer.TokenID), 'Fourth token should be space after star/paren comment');

  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkSingleLineComment), Integer(FPasLexer.TokenID), 'Fifth token should be single line comment');

  // Next token after single line comment is CRLF, then identifier 'x'
  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkCRLF), Integer(FPasLexer.TokenID));
  CheckTrue(FPasLexer.NextToken);
  CheckEquals(Integer(tkIdentifier), Integer(FPasLexer.TokenID));
end;

procedure TestTPasLexerAdditional.TestCompilerDirectivesAndCounters;
var S: string;
    LState: TPasLexerState;
begin
  // Simple nested directives
  S := '{$IFDEF A}{$IFDEF B}{$ENDIF}{$ENDIF}';
  FPasLexer.SetData(S);

  // Using NextToken to see directives and allow lexer to update counters
  while FPasLexer.NextToken do
  begin
    // just iterate through tokens to let lexer process directive counters
  end;

  // After processing directives counters should be zero
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount, 'IfDirectiveCount should be 0 after matching endif');

  // Test unexpected ELSE/ENDIF handling by using IgnoreCompilerDirectiveChecks = True to avoid exception
  S := '{$IFDEF A}{$ELSE}';
  FPasLexer.SetData(S);
  LState := FPasLexer.LexerState;
  LState.IgnoreCompilerDirectiveChecks := True;
  FPasLexer.LexerState := LState;
  while FPasLexer.NextToken do ;
  // If checks ignored, the lexer should finish without raising
  CheckTrue(True, 'Lexer handled directives with IgnoreCompilerDirectiveChecks = True');
end;

// A lexer without data must not lex anything: Reset skips NextToken when there
// is no data buffer.
procedure TestTPasLexerAdditional.TestInitialLexerState;
var
  Lexer: TPasLexer;
begin
  Lexer := TPasLexer.Create;
  try
    CheckEquals(TOKEN_NAMES[tkUnknown], TOKEN_NAMES[Lexer.TokenID], 'Fresh lexer token');
    CheckEquals(EmptyStr, Lexer.TokenString, 'Fresh lexer token string');
    CheckEquals(TOKEN_NAMES[tkUnknown], TOKEN_NAMES[Lexer.LexerState.LastSignificantToken], 'Fresh lexer last token');
    CheckEquals(1, Integer(Lexer.LexerState.CurrentLine), 'Fresh lexer CurrentLine');
    CheckEquals(0, Integer(Lexer.LexerState.CurrentIndex), 'Fresh lexer CurrentIndex');
    CheckEquals(0, Integer(Lexer.LexerState.MaxIndex), 'Fresh lexer MaxIndex');
    CheckEquals(0, Integer(Lexer.LexerState.CurrentTokenPos), 'Fresh lexer CurrentTokenPos');
    CheckEquals(0, Integer(Lexer.LexerState.CurrentLineStartPos), 'Fresh lexer CurrentLineStartPos');
    CheckTrue(Lexer.LexerState.CommentState = csNo, 'Fresh lexer CommentState');
    CheckFalse(Lexer.LexerState.IsProperty, 'Fresh lexer IsProperty');
    CheckFalse(Lexer.LexerState.IsCompilerDirective, 'Fresh lexer IsCompilerDirective');
    CheckFalse(Lexer.LexerState.IgnoreCompilerDirectiveChecks, 'Fresh lexer IgnoreCompilerDirectiveChecks');
    CheckFalse(Lexer.LexerState.WasLineChange, 'Fresh lexer WasLineChange');
    CheckEquals(0, Length(Lexer.LexerState.IfDirectiveStateArray), 'Fresh lexer IfDirectiveStateArray');
    CheckEquals(0, Length(Lexer.LexerState.IfDirectiveSavedCountersArray), 'Fresh lexer IfDirectiveSavedCountersArray');

    // Reset without data must stay in the same state
    Lexer.Reset;
    CheckEquals(TOKEN_NAMES[tkUnknown], TOKEN_NAMES[Lexer.TokenID], 'Token after reset without data');
    CheckEquals(0, Integer(Lexer.LexerState.MaxIndex), 'MaxIndex after reset without data');
  finally
    Lexer.Free;
  end;
end;

procedure TestTPasLexerAdditional.TestResetRestartsLexing;
var
  S: string;
begin
  S := 'unit Foo;';
  SetLexerData(S);
  CheckEquals('unit', FPasLexer.TokenString, 'First token text');
  CheckTrue(FPasLexer.NextToken, 'Space expected');
  CheckTrue(FPasLexer.NextToken, 'Identifier expected');
  CheckEquals('Foo', FPasLexer.TokenString, 'Third token text');

  FPasLexer.Reset;
  CheckEquals(TOKEN_NAMES[tkUnit], TOKEN_NAMES[FPasLexer.TokenID], 'Reset must lex the first token again');
  CheckEquals('unit', FPasLexer.TokenString, 'Token text after reset');
  CheckEquals(1, Integer(FPasLexer.LexerState.CurrentLine), 'CurrentLine after reset');
  CheckEquals(Length(S), Integer(FPasLexer.LexerState.MaxIndex), 'MaxIndex after reset');
  CheckEquals(0, Integer(FPasLexer.LexerState.CurrentTokenPos), 'CurrentTokenPos after reset');

  // Reset also drops the directive state arrays. The first token is lexed
  // again by Reset, so the leading directive is counted once more.
  S := '{$IFDEF A}{$IFDEF B}x';
  SetLexerData(S);
  while FPasLexer.NextToken do ;
  CheckEquals(2, FPasLexer.LexerState.Counters.IfDirectiveCount, 'IfDirectiveCount at end of data');
  CheckEquals(2, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'IfDirectiveStateArray at end of data');

  FPasLexer.Reset;
  CheckEquals(1, FPasLexer.LexerState.Counters.IfDirectiveCount, 'IfDirectiveCount after reset');
  CheckEquals(1, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'IfDirectiveStateArray after reset');
  CheckEquals(1, Length(FPasLexer.LexerState.IfDirectiveSavedCountersArray),
      'IfDirectiveSavedCountersArray after reset');
  CheckEquals('{$IFDEF A}', FPasLexer.TokenString, 'Token text after reset');
end;

// #1..#9, #11..#12 and #14..#32 are all collapsed into a single space token
procedure TestTPasLexerAdditional.TestWhitespaceHandling;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeAll('a' + #9 + #11 + #12 + #14 + #32 + 'b' + #1 + 'c');
  CheckTokenKinds('whitespace', Tokens, [tkIdentifier, tkSpace, tkIdentifier, tkSpace, tkIdentifier]);
  CheckTokenTexts('whitespace', Tokens, ['a', #9 + #11 + #12 + #14 + #32, 'b', #1, 'c']);

  // A space run stops at the line break characters
  Tokens := TokenizeAll('  ' + #13#10 + '  ');
  CheckTokenKinds('whitespace and line break', Tokens, [tkSpace, tkCRLF, tkSpace]);
  CheckTokenTexts('whitespace and line break', Tokens, ['  ', #13#10, '  ']);
end;

// CRLF, lone LF and lone CR are single tokens, the line counter is increased
// on the token following the line break
procedure TestTPasLexerAdditional.TestLineTracking;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeAll('a' + #13#10 + 'b' + #10 + 'c' + #13 + 'd');
  CheckTokenKinds('line tracking', Tokens,
      [tkIdentifier, tkCRLF, tkIdentifier, tkCRLF, tkIdentifier, tkCRLF, tkIdentifier]);
  CheckTokenTexts('line tracking', Tokens, ['a', #13#10, 'b', #10, 'c', #13, 'd']);
  CheckTokenLines('line tracking', Tokens, [1, 1, 2, 2, 3, 3, 4]);

  // Line start positions, used to calculate the char index inside the line
  CheckEquals(0, Integer(Tokens[0].LineStartPos), 'LineStartPos of first line');
  CheckEquals(3, Integer(Tokens[2].LineStartPos), 'LineStartPos of second line');
  CheckEquals(5, Integer(Tokens[4].LineStartPos), 'LineStartPos of third line');
  CheckEquals(7, Integer(Tokens[6].LineStartPos), 'LineStartPos of fourth line');
  CheckEquals(3, Integer(Tokens[2].TokenPos), 'TokenPos of second line identifier');
  CheckEquals(7, Integer(Tokens[6].TokenPos), 'TokenPos of fourth line identifier');
end;

procedure TestTPasLexerAdditional.TestOperators;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeNoJunk(':= : <= <> < >= > = + - * / , . .. @ [ ] ^ ( ) (. .)');
  CheckTokenKinds('operators', Tokens,
      [tkAssign, tkColon, tkLowerEqual, tkNotEqual, tkLower, tkGreaterEqual, tkGreater, tkEqual,
       tkPlus, tkMinus, tkStar, tkSlash, tkComma, tkPoint, tkDotDot, tkAddressSymbol,
       tkSquareOpen, tkSquareClose, tkPointerSymbol, tkRoundOpen, tkRoundClose, tkSquareOpen, tkSquareClose]);
  CheckTokenTexts('operators', Tokens,
      [':=', ':', '<=', '<>', '<', '>=', '>', '=', '+', '-', '*', '/', ',', '.', '..', '@',
       '[', ']', '^', '(', ')', '(.', '.)']);
  CheckCounters('operators', 0, 0, 0);
end;

procedure TestTPasLexerAdditional.TestSymbolAndUnknownChars;
var
  Tokens: TLexTokenArray;
begin
  // '}' without an open comment and '|' are not part of the language
  Tokens := TokenizeNoJunk('} | ! " % & ? \ ` ~ ' + #127);
  CheckTokenKinds('symbols', Tokens,
      [tkUnknown, tkUnknown, tkSymbol, tkSymbol, tkSymbol, tkSymbol, tkSymbol, tkSymbol, tkSymbol, tkSymbol,
       tkUnknown]);
  CheckTokenTexts('symbols', Tokens, ['}', '|', '!', '"', '%', '&', '?', '\', '`', '~', #127]);
end;

procedure TestTPasLexerAdditional.TestAsciiCharAndHexNumbers;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeNoJunk('#13#10 #$0D#$0A $FF $ff $ # x');
  CheckTokenKinds('ascii chars and hex numbers', Tokens,
      [tkAsciiChar, tkAsciiChar, tkAsciiChar, tkAsciiChar, tkInteger, tkInteger, tkInteger, tkAsciiChar,
       tkIdentifier]);
  CheckTokenTexts('ascii chars and hex numbers', Tokens,
      ['#13', '#10', '#$0D', '#$0A', '$FF', '$ff', '$', '#', 'x']);
end;

procedure TestTPasLexerAdditional.TestNumberEdgeCases;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeNoJunk('0 123 1.5 1.5e10 2E-3 4e+5 1..2 (.7.) 9.');
  CheckTokenKinds('numbers', Tokens,
      [tkNumber, tkNumber, tkFloat, tkFloat, tkFloat, tkFloat,
       tkNumber, tkDotDot, tkNumber,          // a range must not swallow the dots
       tkSquareOpen, tkNumber, tkSquareClose, // '(.' and '.)' are square brackets
       tkFloat]);
  CheckTokenTexts('numbers', Tokens,
      ['0', '123', '1.5', '1.5e10', '2E-3', '4e+5', '1', '..', '2', '(.', '7', '.)', '9.']);
  CheckCounters('numbers', 0, 0, 0);
end;

procedure TestTPasLexerAdditional.TestStringEdgeCases;
var
  Tokens: TLexTokenArray;
begin
  // Empty string, escaped quote and a string containing comment characters
  Tokens := TokenizeNoJunk('s1 := ' + QUOTE + QUOTE + '; ' +
      's2 := ' + QUOTE + 'it' + QUOTE + QUOTE + 's' + QUOTE + '; ' +
      's3 := ' + QUOTE + 'a//b{x}(*y*)' + QUOTE + ';');
  CheckTokenKinds('strings', Tokens,
      [tkIdentifier, tkAssign, tkString, tkSemiColon,
       tkIdentifier, tkAssign, tkString, tkSemiColon,
       tkIdentifier, tkAssign, tkString, tkSemiColon]);
  CheckTokenTexts('strings', Tokens,
      ['s1', ':=', QUOTE + QUOTE, ';',
       's2', ':=', QUOTE + 'it' + QUOTE + QUOTE + 's' + QUOTE, ';',
       's3', ':=', QUOTE + 'a//b{x}(*y*)' + QUOTE, ';']);

  // A string is terminated by CR, LF or end of data
  Tokens := TokenizeNoJunk('a := ' + QUOTE + 'x' + #13#10 +
      'b := ' + QUOTE + 'y' + #10 +
      'c := ' + QUOTE + 'z' + #13 +
      'd := ' + QUOTE + 'w');
  CheckTokenKinds('unterminated strings', Tokens,
      [tkIdentifier, tkAssign, tkUnterminatedString,
       tkIdentifier, tkAssign, tkUnterminatedString,
       tkIdentifier, tkAssign, tkUnterminatedString,
       tkIdentifier, tkAssign, tkUnterminatedString]);
  CheckTokenTexts('unterminated strings', Tokens,
      ['a', ':=', QUOTE + 'x',
       'b', ':=', QUOTE + 'y',
       'c', ':=', QUOTE + 'z',
       'd', ':=', QUOTE + 'w']);
end;

procedure TestTPasLexerAdditional.TestSingleLineComments;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeAll('a // one' + #13#10 + '// two' + #10 + '// three');
  CheckTokenKinds('single line comments', Tokens,
      [tkIdentifier, tkSpace, tkSingleLineComment, tkCRLF, tkSingleLineComment, tkCRLF, tkSingleLineComment]);
  CheckTokenTexts('single line comments', Tokens,
      ['a', ' ', '// one', #13#10, '// two', #10, '// three']);
  CheckTokenLines('single line comments', Tokens, [1, 1, 1, 1, 2, 2, 3]);
end;

// A curly comment is split into one token per line, line breaks inside a
// comment are reported as tkCRLFComment
procedure TestTPasLexerAdditional.TestMultiLineCurlyComment;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeAll('{aaa' + #13#10 + 'bbb' + #13#10 + 'ccc}x');
  CheckTokenKinds('multi line curly comment', Tokens,
      [tkCurlyComment, tkCRLFComment, tkCurlyComment, tkCRLFComment, tkCurlyComment, tkIdentifier]);
  CheckTokenTexts('multi line curly comment', Tokens,
      ['{aaa', #13#10, 'bbb', #13#10, 'ccc}', 'x']);
  CheckTokenLines('multi line curly comment', Tokens, [1, 1, 2, 2, 3, 3]);

  CheckTrue(Tokens[0].CommentState = csCurly, 'CommentState inside curly comment');
  CheckTrue(Tokens[1].CommentState = csCurly, 'CommentState on comment line break');
  CheckTrue(Tokens[3].CommentState = csCurly, 'CommentState on second comment line break');
  CheckTrue(Tokens[4].CommentState = csNo, 'CommentState after closing brace');
  CheckTrue(Tokens[5].CommentState = csNo, 'CommentState after comment');
end;

procedure TestTPasLexerAdditional.TestMultiLineStarParenComment;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeAll('(*aaa' + #10 + 'bbb' + #10 + 'ccc*)y');
  CheckTokenKinds('multi line star paren comment', Tokens,
      [tkStarParenComment, tkCRLFComment, tkStarParenComment, tkCRLFComment, tkStarParenComment, tkIdentifier]);
  CheckTokenTexts('multi line star paren comment', Tokens,
      ['(*aaa', #10, 'bbb', #10, 'ccc*)', 'y']);
  CheckTokenLines('multi line star paren comment', Tokens, [1, 1, 2, 2, 3, 3]);

  CheckTrue(Tokens[0].CommentState = csStarParen, 'CommentState inside star paren comment');
  CheckTrue(Tokens[2].CommentState = csStarParen, 'CommentState on second comment line');
  CheckTrue(Tokens[4].CommentState = csNo, 'CommentState after comment end');

  // A star that is not followed by a closing paren stays inside the comment
  Tokens := TokenizeAll('(*a*b*)z');
  CheckTokenKinds('star inside star paren comment', Tokens, [tkStarParenComment, tkIdentifier]);
  CheckTokenTexts('star inside star paren comment', Tokens, ['(*a*b*)', 'z']);
end;

// (*$...*) is a compiler directive, but unlike {$...} it is not parsed, so it
// does not take part in the conditional directive bookkeeping
procedure TestTPasLexerAdditional.TestStarParenCompilerDirective;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeAll('(*$IFDEF X*)a');
  CheckTokenKinds('star paren directive', Tokens, [tkCompilerDirective, tkIdentifier]);
  CheckTokenTexts('star paren directive', Tokens, ['(*$IFDEF X*)', 'a']);
  CheckTrue(Tokens[0].CommentState = csNo, 'CommentState of star paren directive');
  CheckCounters('star paren directive', 0, 0, 0);
end;

procedure TestTPasLexerAdditional.TestUnterminatedComments;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeAll('{abc');
  CheckTokenKinds('unterminated curly comment', Tokens, [tkCurlyComment]);
  CheckTokenTexts('unterminated curly comment', Tokens, ['{abc']);
  CheckTrue(Tokens[0].CommentState = csCurly, 'CommentState of unterminated curly comment');
  CheckTrue(FPasLexer.TokenID = tkEOF, 'Lexer must be at EOF');

  Tokens := TokenizeAll('{ab' + #10 + 'cd');
  CheckTokenKinds('unterminated multi line curly comment', Tokens, [tkCurlyComment, tkCRLFComment, tkCurlyComment]);
  CheckTokenTexts('unterminated multi line curly comment', Tokens, ['{ab', #10, 'cd']);

  Tokens := TokenizeAll('(*ab');
  CheckTokenKinds('unterminated star paren comment', Tokens, [tkStarParenComment]);
  CheckTokenTexts('unterminated star paren comment', Tokens, ['(*ab']);
  CheckTrue(Tokens[0].CommentState = csStarParen, 'CommentState of unterminated star paren comment');

  Tokens := TokenizeAll('(*ab' + #13 + 'cd');
  CheckTokenKinds('unterminated multi line star paren comment', Tokens,
      [tkStarParenComment, tkCRLFComment, tkStarParenComment]);
  CheckTokenTexts('unterminated multi line star paren comment', Tokens, ['(*ab', #13, 'cd']);

  // A directive that is not closed still updates the directive counters
  Tokens := TokenizeAll('{$IFDEF A');
  CheckTokenKinds('unterminated directive', Tokens, [tkCompilerDirective]);
  CheckTokenTexts('unterminated directive', Tokens, ['{$IFDEF A']);
  CheckCounters('unterminated directive', 0, 0, 1);
end;

// The terminator of the other comment kind must be ignored inside a comment
procedure TestTPasLexerAdditional.TestCommentForeignTerminators;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeAll('{a' + #13#10 + 'b*)c}(*d' + #13#10 + 'e}f*)');
  CheckTokenKinds('foreign comment terminators', Tokens,
      [tkCurlyComment, tkCRLFComment, tkCurlyComment, tkStarParenComment, tkCRLFComment, tkStarParenComment]);
  CheckTokenTexts('foreign comment terminators', Tokens,
      ['{a', #13#10, 'b*)c}', '(*d', #13#10, 'e}f*)']);
end;

// Every word of the keyword table must be recognized, case insensitively.
// The property directives are the exception: outside of a property declaration
// they are ordinary identifiers.
procedure TestTPasLexerAdditional.TestAllKeywords;
var
  i: Integer;
  KeywordText, UpperKeywordText: string;
  Expected: TTokenKind;
begin
  for i := Low(DELPHI_KEYWORDS) to High(DELPHI_KEYWORDS) do
  begin
    KeywordText := DELPHI_KEYWORDS[i].Word;
    UpperKeywordText := UpperCase(KeywordText);
    Expected := DELPHI_KEYWORDS[i].Token;
    if Expected in PROPERTY_DIRECTIVE_TOKENS then
      Expected := tkIdentifier;

    SetLexerData(KeywordText);
    CheckEquals(TOKEN_NAMES[Expected], TOKEN_NAMES[FPasLexer.TokenID], 'Keyword ' + KeywordText);
    CheckEquals(KeywordText, FPasLexer.TokenString, 'Keyword text ' + KeywordText);

    SetLexerData(UpperKeywordText);
    CheckEquals(TOKEN_NAMES[Expected], TOKEN_NAMES[FPasLexer.TokenID], 'Keyword ' + UpperKeywordText);
    CheckEquals(UpperKeywordText, FPasLexer.TokenString, 'Keyword text ' + UpperKeywordText);
  end;

  // Mixed case is recognized as well
  SetLexerData('bEgIn ProCeduRe');
  CheckEquals(TOKEN_NAMES[tkBegin], TOKEN_NAMES[FPasLexer.TokenID], 'Mixed case begin');
  CheckTrue(FPasLexer.NextToken, 'Space expected');
  CheckTrue(FPasLexer.NextToken, 'Keyword expected');
  CheckEquals(TOKEN_NAMES[tkProcedure], TOKEN_NAMES[FPasLexer.TokenID], 'Mixed case procedure');
end;

procedure TestTPasLexerAdditional.TestIdentifierEdgeCases;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeNoJunk('MyVar _temp var1 my_var wri en zzz Beginning x1_2 endif');
  CheckTokenKinds('identifiers', Tokens,
      [tkIdentifier,        // diverges from the keyword tree in the middle
       tkIdentifier,        // starts with underscore
       tkIdentifier,        // keyword followed by a digit
       tkIdentifier,        // keyword prefix followed by underscore
       tkIdentifier,        // prefix of 'write', not a keyword itself
       tkIdentifier,        // prefix of 'end', not a keyword itself
       tkIdentifier,        // no keyword starts with 'z'
       tkIdentifier,        // keyword followed by more letters
       tkIdentifier,        // letter, digits and underscores
       tkEndIfDirective]);  // conditional directive names are in the keyword tree
  CheckTokenTexts('identifiers', Tokens,
      ['MyVar', '_temp', 'var1', 'my_var', 'wri', 'en', 'zzz', 'Beginning', 'x1_2', 'endif']);
end;

// Characters above the run handler table are treated as identifier characters
procedure TestTPasLexerAdditional.TestNonAsciiIdentifiers;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeNoJunk(CYRILLIC_PE + CYRILLIC_A + '1 var' + CYRILLIC_A + ' a' + CYRILLIC_PE + ' ' +
      CYRILLIC_A + '_2');
  CheckTokenKinds('non ascii identifiers', Tokens,
      [tkIdentifier, tkIdentifier, tkIdentifier, tkIdentifier]);
  CheckTokenTexts('non ascii identifiers', Tokens,
      [CYRILLIC_PE + CYRILLIC_A + '1', 'var' + CYRILLIC_A, 'a' + CYRILLIC_PE, CYRILLIC_A + '_2']);
end;

procedure TestTPasLexerAdditional.TestPropertyDirectives;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeNoJunk('property P: Integer index 3 read FP write FP stored True default 0 nodefault;' +
      sLineBreak + 'read write index stored default nodefault;');
  CheckTokenKinds('property directives', Tokens,
      [tkProperty, tkIdentifier, tkColon, tkIdentifier, tkIndex, tkNumber, tkRead, tkIdentifier,
       tkWrite, tkIdentifier, tkStored, tkTrue, tkDefault, tkNumber, tkNodefault, tkSemiColon,
       // outside of a property declaration the directives are identifiers
       tkIdentifier, tkIdentifier, tkIdentifier, tkIdentifier, tkIdentifier, tkIdentifier, tkSemiColon]);

  // The property flag is set by 'property' and cleared by the semicolon
  SetLexerData('property X;');
  CheckTrue(FPasLexer.LexerState.IsProperty, 'IsProperty after property keyword');
  CheckTrue(FPasLexer.NextToken, 'Space expected');
  CheckTrue(FPasLexer.NextToken, 'Identifier expected');
  CheckTrue(FPasLexer.LexerState.IsProperty, 'IsProperty inside property declaration');
  CheckTrue(FPasLexer.NextToken, 'Semicolon expected');
  CheckFalse(FPasLexer.LexerState.IsProperty, 'IsProperty after semicolon');
end;

procedure TestTPasLexerAdditional.TestEndAndUnitEnd;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeNoJunk('begin end; end' + sLineBreak + 'END. end.x');
  CheckTokenKinds('end tokens', Tokens,
      [tkBegin, tkEnd, tkSemiColon, tkEnd, tkUnitEnd, tkUnitEnd, tkIdentifier]);
  CheckTokenTexts('end tokens', Tokens,
      ['begin', 'end', ';', 'end', 'END.', 'end.', 'x']);

  // 'end' at the very end of the data is not a unit end
  Tokens := TokenizeNoJunk('end');
  CheckTokenKinds('end at end of data', Tokens, [tkEnd]);
  CheckTokenTexts('end at end of data', Tokens, ['end']);
end;

procedure TestTPasLexerAdditional.TestBracketCounters;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeNoJunk('f(a[1], (.2.))');
  CheckTokenKinds('bracket counters', Tokens,
      [tkIdentifier, tkRoundOpen, tkIdentifier, tkSquareOpen, tkNumber, tkSquareClose, tkComma,
       tkSquareOpen, tkNumber, tkSquareClose, tkRoundClose]);
  CheckCounters('balanced brackets', 0, 0, 0);

  TokenizeNoJunk('([');
  CheckCounters('unclosed brackets', 1, 1, 0);

  TokenizeNoJunk(')]');
  CheckCounters('unopened brackets', -1, -1, 0);
end;

// A compiler directive may span several lines, the line breaks inside it do
// not produce line break tokens
procedure TestTPasLexerAdditional.TestMultiLineCompilerDirective;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeAll('{$IFDEF A' + #13#10 + 'B}x{$ENDIF' + #10 + '}y{$IFDEF C' + #13 + 'D}{$ENDIF}');
  CheckTokenKinds('multi line directive', Tokens,
      [tkCompilerDirective, tkIdentifier, tkCompilerDirective, tkIdentifier, tkCompilerDirective,
       tkCompilerDirective]);
  CheckTokenTexts('multi line directive', Tokens,
      ['{$IFDEF A' + #13#10 + 'B}', 'x', '{$ENDIF' + #10 + '}', 'y', '{$IFDEF C' + #13 + 'D}', '{$ENDIF}']);
  CheckTokenLines('multi line directive', Tokens, [1, 2, 2, 3, 3, 4]);
  CheckCounters('multi line directive', 0, 0, 0);
end;

procedure TestTPasLexerAdditional.TestConditionalDirectiveKinds;
var
  Tokens: TLexTokenArray;
begin
  Tokens := TokenizeAll('{$IFDEF A}a{$ELSEIF B}b{$ELSE}c{$ENDIF}' +
      '{$IFNDEF D}d{$IFEND}' +
      '{$IFOPT R+}e{$ENDIF}' +
      '{$IF F}f{$IFEND}' +
      '{$R *.res}{$DEFINE G}');
  CheckTokenKinds('conditional directives', Tokens,
      [tkCompilerDirective, tkIdentifier, tkCompilerDirective, tkIdentifier, tkCompilerDirective, tkIdentifier,
       tkCompilerDirective,
       tkCompilerDirective, tkIdentifier, tkCompilerDirective,
       tkCompilerDirective, tkIdentifier, tkCompilerDirective,
       tkCompilerDirective, tkIdentifier, tkCompilerDirective,
       tkCompilerDirective, tkCompilerDirective]);
  CheckTokenTexts('conditional directives', Tokens,
      ['{$IFDEF A}', 'a', '{$ELSEIF B}', 'b', '{$ELSE}', 'c', '{$ENDIF}',
       '{$IFNDEF D}', 'd', '{$IFEND}',
       '{$IFOPT R+}', 'e', '{$ENDIF}',
       '{$IF F}', 'f', '{$IFEND}',
       '{$R *.res}', '{$DEFINE G}']);
  CheckCounters('conditional directives', 0, 0, 0);
  CheckEquals(0, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'IfDirectiveStateArray at end of data');
  CheckEquals(0, Length(FPasLexer.LexerState.IfDirectiveSavedCountersArray),
      'IfDirectiveSavedCountersArray at end of data');
end;

// Counters are restored at the start of every branch, so branches with equal
// bracket counts must be accepted
procedure TestTPasLexerAdditional.TestElseIfDirectiveChain;
begin
  SetLexerData('{$IFDEF A}(){$ELSEIF B}(){$ELSEIF C}(){$ENDIF}');
  CheckEquals(1, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'State array after IFDEF');
  CheckTrue(FPasLexer.LexerState.IfDirectiveStateArray[0] = idsIf, 'State array content after IFDEF');

  CheckTrue(FPasLexer.NextToken, 'Round open expected');
  CheckTrue(FPasLexer.NextToken, 'Round close expected');
  CheckTrue(FPasLexer.NextToken, 'ELSEIF directive expected');
  CheckEquals(2, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'State array after first ELSEIF');
  CheckTrue(FPasLexer.LexerState.IfDirectiveStateArray[1] = idsElseIf, 'State array content after first ELSEIF');
  CheckCounters('after first ELSEIF', 0, 0, 1);

  while FPasLexer.NextToken do ;
  CheckCounters('after ENDIF', 0, 0, 0);
  CheckEquals(0, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'State array after ENDIF');

  // The same chain closed by an ELSE branch
  SetLexerData('{$IFDEF A}(){$ELSEIF B}(){$ELSE}(){$ENDIF}');
  while FPasLexer.NextToken do ;
  CheckCounters('else after elseif', 0, 0, 0);
  CheckEquals(0, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'State array after ELSE chain');
end;

procedure TestTPasLexerAdditional.TestDirectiveErrorUnexpectedElse;
begin
  CheckEquals(EMESSAGE_UNEXPECTED_ELSE_DIRECTIVE, LexAllCatchException(' {$ELSE}'),
      'ELSE without IF');
  CheckEquals(EMESSAGE_UNEXPECTED_ELSE_DIRECTIVE, LexAllCatchException(' {$ELSEIF X}'),
      'ELSEIF without IF');
  CheckEquals(EMESSAGE_UNEXPECTED_ELSE_DIRECTIVE, LexAllCatchException('{$IFDEF A}{$ELSE}{$ELSE}'),
      'Second ELSE');
  CheckEquals(EMESSAGE_UNEXPECTED_ELSE_DIRECTIVE, LexAllCatchException('{$IFDEF A}{$ELSE}{$ELSEIF X}'),
      'ELSEIF after ELSE');
end;

procedure TestTPasLexerAdditional.TestDirectiveErrorCountersMismatch;
begin
  // The ELSE branch opens a bracket that the IF branch does not
  CheckEquals(EMESSAGE_DIRECTIVE_COUNTERS_MISMATCH_ELSE, LexAllCatchException('{$IFDEF A}(){$ELSE}({$ENDIF}'),
      'Counters mismatch at ENDIF');
  // The counters of the IF branch are compared at the second ELSEIF
  CheckEquals(EMESSAGE_DIRECTIVE_COUNTERS_MISMATCH_ELSE,
      LexAllCatchException('{$IFDEF A}({$ELSEIF B}{$ELSEIF C}{$ENDIF}'), 'Counters mismatch at ELSEIF');
  // Square brackets are compared too
  CheckEquals(EMESSAGE_DIRECTIVE_COUNTERS_MISMATCH_ELSE, LexAllCatchException('{$IFDEF A}[]{$ELSE}[{$ENDIF}'),
      'Square counters mismatch at ENDIF');
end;

procedure TestTPasLexerAdditional.TestDirectiveErrorStateMismatch;
var
  LState: TPasLexerState;
begin
  CheckEquals(EMESSAGE_DIRECTIVE_STATE_COUNTER_MISMATCH, LexAllCatchException(' {$ENDIF}'),
      'ENDIF without IF');
  CheckEquals(EMESSAGE_DIRECTIVE_STATE_COUNTER_MISMATCH, LexAllCatchException(' {$IFEND}'),
      'IFEND without IF');

  // The state array and the saved counters array must have the same length
  SetLexerData('{$IFDEF A}{$ELSE}');
  LState := FPasLexer.LexerState;
  SetLength(LState.IfDirectiveStateArray, 2);
  LState.IfDirectiveStateArray[1] := idsIf;
  FPasLexer.LexerState := LState;
  try
    while FPasLexer.NextToken do ;
    Fail('Expected an exception for mismatched directive state arrays');
  except
    on E: EPasLexerException do
      CheckEquals(EMESSAGE_DIRECTIVE_STATE_COUNTER_MISMATCH, E.Message, 'Mismatched array lengths');
  end;

  // The directive counter must match the state array length at the end directive
  SetLexerData('{$IFDEF A}x{$ENDIF}');
  LState := FPasLexer.LexerState;
  LState.Counters.IfDirectiveCount := 3;
  FPasLexer.LexerState := LState;
  try
    while FPasLexer.NextToken do ;
    Fail('Expected an exception for a wrong directive counter');
  except
    on E: EPasLexerException do
      CheckEquals(EMESSAGE_DIRECTIVE_STATE_COUNTER_MISMATCH, E.Message, 'Wrong directive counter');
  end;
end;

// With IgnoreCompilerDirectiveChecks the same data must be lexed without errors
procedure TestTPasLexerAdditional.TestIgnoreCompilerDirectiveChecks;
var
  S: string;
  LState: TPasLexerState;
begin
  S := '{$IFDEF A}(){$ELSE}({$ENDIF}';
  CheckEquals(EMESSAGE_DIRECTIVE_COUNTERS_MISMATCH_ELSE, LexAllCatchException(S),
      'Counters mismatch must be reported by default');

  SetLexerData(S);
  LState := FPasLexer.LexerState;
  LState.IgnoreCompilerDirectiveChecks := True;
  FPasLexer.LexerState := LState;
  while FPasLexer.NextToken do ;
  CheckTrue(FPasLexer.LexerState.IgnoreCompilerDirectiveChecks, 'IgnoreCompilerDirectiveChecks must be kept');
  CheckEquals(0, FPasLexer.LexerState.Counters.IfDirectiveCount, 'IfDirectiveCount with ignored checks');
  CheckEquals(0, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'State array with ignored checks');
end;

// LastSignificantToken skips whitespace, comments and compiler directives
procedure TestTPasLexerAdditional.TestLastSignificantToken;
begin
  SetLexerData('a := 1;');
  CheckEquals(TOKEN_NAMES[tkUnknown], TOKEN_NAMES[FPasLexer.LexerState.LastSignificantToken],
      'No significant token before the first one');

  CheckTrue(FPasLexer.NextToken, 'Space expected');
  CheckEquals(TOKEN_NAMES[tkIdentifier], TOKEN_NAMES[FPasLexer.LexerState.LastSignificantToken],
      'Last significant token on space');
  CheckEquals(0, Integer(FPasLexer.LexerState.LastSignificantTokenPos), 'Position of the identifier');

  CheckTrue(FPasLexer.NextToken, 'Assign expected');
  CheckEquals(TOKEN_NAMES[tkIdentifier], TOKEN_NAMES[FPasLexer.LexerState.LastSignificantToken],
      'Space must not become the last significant token');

  CheckTrue(FPasLexer.NextToken, 'Space expected');
  CheckEquals(TOKEN_NAMES[tkAssign], TOKEN_NAMES[FPasLexer.LexerState.LastSignificantToken],
      'Last significant token after assign');
  CheckEquals(2, Integer(FPasLexer.LexerState.LastSignificantTokenPos), 'Position of the assign token');

  CheckTrue(FPasLexer.NextToken, 'Number expected');
  CheckTrue(FPasLexer.NextToken, 'Semicolon expected');
  CheckEquals(TOKEN_NAMES[tkNumber], TOKEN_NAMES[FPasLexer.LexerState.LastSignificantToken],
      'Last significant token after number');
  CheckEquals(5, Integer(FPasLexer.LexerState.LastSignificantTokenPos), 'Position of the number token');

  // Compiler directives are not significant either
  SetLexerData('a{$R+}b');
  CheckTrue(FPasLexer.NextToken, 'Directive expected');
  CheckTrue(FPasLexer.NextToken, 'Identifier expected');
  CheckEquals('b', FPasLexer.TokenString, 'Token after directive');
  CheckEquals(TOKEN_NAMES[tkIdentifier], TOKEN_NAMES[FPasLexer.LexerState.LastSignificantToken],
      'Directive must not become the last significant token');
  CheckEquals(0, Integer(FPasLexer.LexerState.LastSignificantTokenPos), 'Position of the first identifier');
end;

procedure TestTPasLexerAdditional.TestLexerStateSaveRestore;
var
  Saved: TPasLexerState;
begin
  SetLexerData('{$IFDEF A}{$IFDEF B}xy{$ENDIF}{$ENDIF}z');
  CheckTrue(FPasLexer.NextToken, 'Second directive expected');
  CheckEquals('{$IFDEF B}', FPasLexer.TokenString, 'Second directive text');

  Saved := FPasLexer.LexerState;
  CheckEquals(2, Length(Saved.IfDirectiveStateArray), 'Saved state array length');
  CheckEquals(2, Length(Saved.IfDirectiveSavedCountersArray), 'Saved counters array length');

  CheckTrue(FPasLexer.NextToken, 'Identifier expected');
  CheckEquals('xy', FPasLexer.TokenString, 'Identifier text');
  while FPasLexer.NextToken do ;
  CheckCounters('at end of data', 0, 0, 0);
  CheckEquals(0, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'State array at end of data');

  // Restoring the state rewinds the lexer
  FPasLexer.LexerState := Saved;
  CheckEquals(2, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'State array after restore');
  CheckEquals(2, Length(FPasLexer.LexerState.IfDirectiveSavedCountersArray), 'Counters array after restore');
  CheckTrue(FPasLexer.LexerState.IfDirectiveStateArray[1] = idsIf, 'State array content after restore');
  CheckCounters('after restore', 0, 0, 2);
  CheckEquals('{$IFDEF B}', FPasLexer.TokenString, 'Token text after restore');
  CheckTrue(FPasLexer.NextToken, 'Identifier expected after restore');
  CheckEquals('xy', FPasLexer.TokenString, 'Identifier text after restore');

  // Restoring a state without directive arrays
  SetLexerData('{a' + #13#10 + 'b}c');
  Saved := FPasLexer.LexerState;
  CheckEquals(0, Length(Saved.IfDirectiveStateArray), 'Saved empty state array');
  CheckTrue(Saved.CommentState = csCurly, 'Saved comment state');

  while FPasLexer.NextToken do ;
  FPasLexer.LexerState := Saved;
  CheckEquals(0, Length(FPasLexer.LexerState.IfDirectiveStateArray), 'Empty state array after restore');
  CheckTrue(FPasLexer.LexerState.CommentState = csCurly, 'Comment state after restore');
  CheckEquals(1, Integer(FPasLexer.LexerState.CurrentLine), 'Line after restore');
  CheckEquals('{a', FPasLexer.TokenString, 'Token text after restore');
  CheckTrue(FPasLexer.NextToken, 'Comment line break expected after restore');
  CheckEquals(TOKEN_NAMES[tkCRLFComment], TOKEN_NAMES[FPasLexer.TokenID], 'Token kind after restore');
end;

// NextTokenNoJunk stops at the next significant token.
// It must not be called when there is no significant token left: its loop
// condition can not be satisfied at tkEOF.
procedure TestTPasLexerAdditional.TestNextTokenNoJunk;
begin
  SetLexerData('a {c1' + #13#10 + 'c2} // x' + #13#10 + '(*s*){$R+} b');
  CheckEquals('a', FPasLexer.TokenString, 'First token');

  CheckTrue(FPasLexer.NextTokenNoJunk, 'Identifier expected');
  CheckEquals(TOKEN_NAMES[tkIdentifier], TOKEN_NAMES[FPasLexer.TokenID], 'Token kind after junk');
  CheckEquals('b', FPasLexer.TokenString, 'All spaces, comments and directives must be skipped');
  CheckEquals(3, Integer(FPasLexer.LexerState.CurrentLine), 'Line of the token after junk');
end;

procedure TestTPasLexerAdditional.TestNextTokenWithKind;
begin
  SetLexerData('unit Foo; interface implementation end.');
  CheckTrue(FPasLexer.NextTokenWithKind(tkImplementation), 'Implementation section expected');
  CheckEquals('implementation', FPasLexer.TokenString, 'Token text');

  CheckTrue(FPasLexer.NextTokenWithKind(tkUnitEnd), 'Unit end expected');
  CheckEquals('end.', FPasLexer.TokenString, 'Token text');
end;

// NextTokenNoDirectiveBranching skips the tokens of the other branches of a
// conditional directive
procedure TestTPasLexerAdditional.TestNextTokenNoDirectiveBranching;
begin
  // Starting outside of a directive: everything inside the directive is skipped
  SetLexerData('a{$IFDEF X}b{$ELSE}c{$ENDIF}d');
  CheckEquals('a', FPasLexer.TokenString, 'First token');
  CheckTrue(FPasLexer.NextTokenNoDirectiveBranching, 'Token after the directive expected');
  CheckEquals('d', FPasLexer.TokenString, 'Directive branches must be skipped');

  // Starting inside a directive: the tokens of the same branch are returned
  SetLexerData('{$IFDEF X}a{$ELSE}b{$ENDIF}c');
  CheckEquals('{$IFDEF X}', FPasLexer.TokenString, 'First token');
  CheckTrue(FPasLexer.NextTokenNoDirectiveBranching, 'Token of the same branch expected');
  CheckEquals('a', FPasLexer.TokenString, 'Token of the same branch');

  // The other branch is skipped, lexing continues after the end directive
  CheckTrue(FPasLexer.NextTokenNoDirectiveBranching, 'Token after the directive expected');
  CheckEquals('c', FPasLexer.TokenString, 'Token after the end directive');
end;

initialization
  RegisterTest(TestTPasLexerAdditional.Suite);

end.
