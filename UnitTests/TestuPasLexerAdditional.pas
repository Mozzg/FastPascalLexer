unit TestuPasLexerAdditional;
{
  Additional tests for TPasLexer focusing on tokenization behavior.
}

interface

uses
  TestFramework, System.SysUtils, System.Character,
  uPasLexer, uPasLexerTypes;

type
  TestTPasLexerAdditional = class(TTestCase)
  strict private
    FPasLexer: TPasLexer;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestIdentifiersAndPunctuation;
    procedure TestNumbers;
    procedure TestStrings;
    procedure TestComments;
    procedure TestCompilerDirectivesAndCounters;
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

initialization
  RegisterTest(TestTPasLexerAdditional.Suite);

end.
