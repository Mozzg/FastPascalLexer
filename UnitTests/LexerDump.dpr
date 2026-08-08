program LexerDump;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  uPasLexer, uPasLexerTypes;

procedure DumpTokens(const S: string);
var
  L: TPasLexer;
  TokenName: string;
begin
  Writeln('Input: ', S);
  L := TPasLexer.Create;
  try
    var Data: string := S;
    L.SetData(Data);
    // Print tokens until EOF
    repeat
      TokenName := TOKEN_NAMES[L.TokenID];
      Writeln(Format('  %3d %-24s  |%s|', [Ord(L.TokenID), TokenName, L.TokenString]));
    until not L.NextToken or (L.TokenID = tkEOF);
  finally
    L.Free;
  end;
  Writeln;
end;

begin
  try
    DumpTokens('MyVar _temp var1;');
    DumpTokens('a := 123; b := 12.34e-2; c := $FF;');
    DumpTokens('s := ''hello'';');
    DumpTokens('t := ''notclosed');
    DumpTokens('{comment} (* another comment *) // single line' + sLineBreak + 'x');
    DumpTokens('{$IFDEF A}{$IFDEF B}{$ENDIF}{$ENDIF}');
    DumpTokens('{$IFDEF A}{$ELSE}');
  except
    on E: Exception do
      Writeln('Error: ', E.ClassName, ' - ', E.Message);
  end;
end.
