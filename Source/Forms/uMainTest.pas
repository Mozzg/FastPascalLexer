unit uMainTest;

interface

uses
  Vcl.Forms, System.Classes, Vcl.Controls, Vcl.StdCtrls, System.SysUtils, System.TypInfo,
  System.StrUtils, System.IOUtils, System.Types, Winapi.Windows, Vcl.Dialogs,
  uPasLexer, uPasLexerTypes, uPasParser, uPasLexerPerformance, uPasExceptions,
  uPasParserTypes, uPasParserGrammar;

const
  COMMA_BOOL_ARRAY_SPACE: array [False .. True] of string = (', ', '');

type
  TfmMainTest = class(TForm)
    Memo1: TMemo;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Button5: TButton;
    Button6: TButton;
    Button7: TButton;
    Button8: TButton;
    Button9: TButton;
    Button10: TButton;
    Button11: TButton;
    Button12: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure Button9Click(Sender: TObject);
    procedure Button10Click(Sender: TObject);
    procedure Button11Click(Sender: TObject);
    procedure Button12Click(Sender: TObject);
  private type
    TMyClass122 = class( tobject)
      FField: Integer;
    end;
    TMyRecord12 = record

    end;
  private
    FMeasureThread: TMeasureThread;

    procedure CustomOnUpdateElapsed(AAverageElapsed, ACycleCount: Int64);
    procedure LogLexemeTree(ANode: TBaseLexemeNode; AIndent: Integer);
  public
    procedure Log(const AMessage: string);
  end;

var
  fmMainTest: TfmMainTest;

implementation

{$R *.dfm}

const
  {IGNORE_PARSE_FILES: array[0..5] of string = (
    'C:\AirusTT\Source\KKM\Shtrih-415\FMU415\fmuZReport.pas',
    'C:\AirusTT\Source\KKM\Shtrih-415\Samples\Borland Delphi 7.0\DrvFRTst\FMU\fmuZReport.pas',
    'C:\AirusTT\Source\KKM\Shtrih-517\FMU\fmuZReport.pas',
    'C:\AirusTT\Source\Libraries\EhLib110\Lazarus\Lib\PropFilerEh.pas',
    'C:\AirusTT\Source\Libraries\EhLib110\Lib\PropFilerEh.pas'
    'C:\AirusTT\Source\Libraries\EhLib91\PropFilerEh.pas'
  ); }

  IGNORE_PARSE_FILES: array[0..1] of string = (
    'C:\AirusTT\Source\Scripts_MSSQL\TdaLu\fordebug\log_actual.pas',
    'C:\AirusTT\Source\Scripts_MSSQL\TdaLu\fordebug\log_full.pas'
  );

type
  // Kind of a source line for the blank line checks
  TSourceLineKind = (slkBlank, slkComment, slkCode);

function DetectEncoding(const AFileName: String): TEncoding;
const
  MaxBufferSize = 1024;
var
  Buffer: RawByteString;
  Stream: TStream;
  Mask: Integer;
  Len: Int64;
begin
  // Загрузили начало файла в буфер Buffer для анализа
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    Len := Stream.Size;
    if Len > MaxBufferSize then
      SetLength(Buffer, MaxBufferSize)
    else
      SetLength(Buffer, Len);

    Stream.Position := 0;
    Stream.ReadBuffer(Pointer(Buffer)^, Length(Buffer));
  finally
    FreeAndNil(Stream);
  end;

  // Явная проверка на UTF-8 с BOM,
  // т.к. IsTextUnicode на UTF-8 не проверяет
  if Copy(Buffer, 1, 3) = #$EF#$BB#$BF then
  begin
    Result := TEncoding.UTF8;
    Exit;
  end;

  // Вызываем анализ "как в Блокноте"
  // Это сможет отличить только UTF-16 от ANSI
  Mask :=
    IS_TEXT_UNICODE_UNICODE_MASK or
    IS_TEXT_UNICODE_REVERSE_MASK or
    IS_TEXT_UNICODE_NOT_UNICODE_MASK or
    IS_TEXT_UNICODE_NOT_ASCII_MASK;
  IsTextUnicode(Pointer(Buffer), Length(Buffer), @Mask);

  // UTF-16
  if (Len mod 2 = 0) and (Mask and IS_TEXT_UNICODE_UNICODE_MASK <> 0) then
    Result := TEncoding.Unicode
  else
  // UTF-16 (big endian)
  if (Len mod 2 = 0) and (Mask and IS_TEXT_UNICODE_REVERSE_MASK <> 0) then
    Result := TEncoding.BigEndianUnicode
  else if (Mask and IS_TEXT_UNICODE_NOT_ASCII_MASK <> 0) then
    Result := TEncoding.UTF8
  else
    Result := TEncoding.ANSI;
end;

function IsFileInIgnore(const AFilePath: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := Low(IGNORE_PARSE_FILES) to High(IGNORE_PARSE_FILES) do
    if SameText(IGNORE_PARSE_FILES[i], AFilePath) then
      Exit(True);
end;

// Kind of the source line ALineNumber (1-based) of the parsed text. A line inside a multi-line comment is a comment
// line, also when it is empty; a line with a compiler directive is a code line.
function GetSourceLineKind(AParser: TPasParser; ALineNumber: Integer): TSourceLineKind;
const
  COMMENT_LINE_TOKENS = [tkCurlyComment, tkSingleLineComment, tkStarParenComment, tkCRLFComment];
var
  Line: TPasLineInfo;
  Token: TPasLexerMinimalState;
  i: Integer;
begin
  Line := AParser.LineItem[ALineNumber];
  // Only a compiler directive spanning several lines covers the start of a line: the lexer splits comments at line
  // breaks
  if (Line.FirstTokenIndex < 0) or (Integer(AParser.SourceTokenItem[Line.FirstTokenIndex].CurrentIndex) <> Line.StartPos) then
    Exit(slkCode);

  Result := slkBlank;
  i := Line.FirstTokenIndex;
  while i < AParser.SourceTokenCount do
  begin
    Token := AParser.SourceTokenItem[i];
    if Integer(Token.CurrentLine) <> ALineNumber then
      Break;
    if Token.CurrentToken in COMMENT_LINE_TOKENS then
      Result := slkComment
    else if not (Token.CurrentToken in [tkSpace, tkCRLF]) then
      Exit(slkCode);
    Inc(i);
  end;
end;

// Count of the blank lines right above the line ALineNumber. The comment lines right above it describe the
// declaration that starts on it, the blank lines are counted above them.
function CountBlankLinesBefore(AParser: TPasParser; ALineNumber: Integer): Integer;
var
  LineNumber: Integer;
begin
  LineNumber := ALineNumber - 1;
  while (LineNumber >= 1) and (GetSourceLineKind(AParser, LineNumber) = slkComment) do
    Dec(LineNumber);

  Result := 0;
  while (LineNumber >= 1) and (GetSourceLineKind(AParser, LineNumber) = slkBlank) do
  begin
    Inc(Result);
    Dec(LineNumber);
  end;
end;

// Count of the blank lines right below the line ALineNumber
function CountBlankLinesAfter(AParser: TPasParser; ALineNumber: Integer): Integer;
var
  LineNumber: Integer;
begin
  Result := 0;
  LineNumber := ALineNumber + 1;
  while (LineNumber <= AParser.LineCount) and (GetSourceLineKind(AParser, LineNumber) = slkBlank) do
  begin
    Inc(Result);
    Inc(LineNumber);
  end;
end;

// True when only blank lines and the comment lines above ANextRoutine separate ARoutine from ANextRoutine: the blank
// lines after ARoutine are the blank lines before ANextRoutine
function AreRoutinesAdjacent(AParser: TPasParser; ARoutine, ANextRoutine: TRoutineLexemeNode): Boolean;
var
  LineNumber, NextStartLine: Integer;
begin
  NextStartLine := Integer(ANextRoutine.FirstState.CurrentLine);
  LineNumber := Integer(ARoutine.LastState.CurrentLine) + 1;
  while (LineNumber < NextStartLine) and (GetSourceLineKind(AParser, LineNumber) = slkBlank) do
    Inc(LineNumber);
  while (LineNumber < NextStartLine) and (GetSourceLineKind(AParser, LineNumber) = slkComment) do
    Inc(LineNumber);
  Result := LineNumber = NextStartLine;
end;

// Adds to AErrors the errors of the blank lines around ARoutine: exactly one blank line must separate it from the code
// before and after it. An error before the routine refers to the line of its start, an error after it to the line of
// its last end. ANextRoutine is the next checked routine, nil for the last one: between two adjacent routines the
// error is reported once, before the second one.
procedure CheckRoutineBlankLines(AParser: TPasParser; ARoutine, ANextRoutine: TRoutineLexemeNode; AErrors: TStrings);
const
  REQUIRED_BLANK_LINES = 1;
  ERROR_MISSING_BEFORE = '  Line %d: missing blank line before %s';
  ERROR_TOO_MANY_BEFORE = '  Line %d: too many blank lines (%d) before %s';
  ERROR_MISSING_AFTER = '  Line %d: missing blank line after %s';
  ERROR_TOO_MANY_AFTER = '  Line %d: too many blank lines (%d) after %s';
var
  StartLine, EndLine, BlankCount: Integer;
begin
  StartLine := Integer(ARoutine.FirstState.CurrentLine);
  BlankCount := CountBlankLinesBefore(AParser, StartLine);
  if BlankCount < REQUIRED_BLANK_LINES then
    AErrors.Add(Format(ERROR_MISSING_BEFORE, [StartLine, ARoutine.Heading.Name]))
  else if BlankCount > REQUIRED_BLANK_LINES then
    AErrors.Add(Format(ERROR_TOO_MANY_BEFORE, [StartLine, BlankCount, ARoutine.Heading.Name]));

  if Assigned(ANextRoutine) and AreRoutinesAdjacent(AParser, ARoutine, ANextRoutine) then
    Exit;

  // The blank lines are counted after the semicolon that follows the end
  EndLine := Integer(ARoutine.Body.LastState.CurrentLine);
  BlankCount := CountBlankLinesAfter(AParser, Integer(ARoutine.LastState.CurrentLine));
  if BlankCount < REQUIRED_BLANK_LINES then
    AErrors.Add(Format(ERROR_MISSING_AFTER, [EndLine, ARoutine.Heading.Name]))
  else if BlankCount > REQUIRED_BLANK_LINES then
    AErrors.Add(Format(ERROR_TOO_MANY_AFTER, [EndLine, BlankCount, ARoutine.Heading.Name]));
end;

// Adds to AErrors the blank line errors of the routines of the implementation section of the parsed unit. Nested
// routines and the routines without a body (forward, external) are not checked.
procedure CheckImplementationBlankLines(AParser: TPasParser; AErrors: TStrings);
var
  Section, Node: TBaseLexemeNode;
  Routine, PrevRoutine: TRoutineLexemeNode;
  i: Integer;
begin
  Section := AParser.RootLexeme;
  while Assigned(Section) and (Section.NodeType <> ltImplementation) do
    Section := Section.NextTraversal;
  if not Assigned(Section) then
    Exit;

  // A routine is checked when the next one is found: the blank lines after it can be the blank lines before the next one
  PrevRoutine := nil;
  for i := 0 to Section.ChildCount - 1 do
  begin
    Node := Section.Children[i];
    if (Node.NodeType <> ltRoutine) or (not Assigned(TRoutineLexemeNode(Node).Body)) then
      Continue;

    Routine := TRoutineLexemeNode(Node);
    if Assigned(PrevRoutine) then
      CheckRoutineBlankLines(AParser, PrevRoutine, Routine, AErrors);
    PrevRoutine := Routine;
  end;
  if Assigned(PrevRoutine) then
    CheckRoutineBlankLines(AParser, PrevRoutine, nil, AErrors);
end;

procedure TfmMainTest.Button10Click(Sender: TObject);
var
  Lexer: TPasLexer;
  FileContent, CurrentToken, DirectiveState: string;
  HRTimer: THighResolutionStopwatch;
  i: Integer;
  Elapsed: Int64;
  //f: Double;
begin
  Lexer := TPasLexer.Create;
  try
    HRTimer := THighResolutionStopwatch.Create;
    try
      //FileContent := 'unit test2; 1e-33.4 1.5.6 123e';
      //FileContent := '(*$IFDEF X' + sLineBreak + 'Y*)z';
      FileContent := '(*$IFDEF CONSOLE_TESTRUNNER ' {+ sLineBreak} + ' test123*)z' + sLineBreak + 'a := 1;{$ENDIF}';
      //FileContent := '{$IFDEF test}abc{$ELSE}xyz{$ENDIF}';

      try
        Memo1.Lines.BeginUpdate;
        try
          HRTimer.Restart;
          Lexer.SetData(FileContent);
          while Lexer.TokenID <> tkEOF do
          begin
            CurrentToken := Lexer.TokenString;

            DirectiveState := EmptyStr;
            for i := Low(Lexer.LexerState.IfDirectiveStateArray) to High(Lexer.LexerState.IfDirectiveStateArray) do
              DirectiveState := DirectiveState + COMMA_BOOL_ARRAY_SPACE[DirectiveState = EmptyStr]
                  + GetEnumName(TypeInfo(TIfDirectiveState), Ord(Lexer.LexerState.IfDirectiveStateArray[i]));
            DirectiveState := '[' + DirectiveState + ']';

            Log(TOKEN_NAMES[Lexer.TokenID]
                + '(' + IfThen(Lexer.TokenID in [tkCRLF, tkCRLFComment], '', CurrentToken)
                + ')' (*+ '  BeginEnd=' + IntToStr(Lexer.LexerState.Counters.BeginEndCount)*) + '  LineNo=' + IntToStr(Lexer.LexerState.CurrentLine)
                + '  IfDirCount=' + IntToStr(Lexer.LexerState.Counters.IfDirectiveCount)
                + '  IfDifValues=' + DirectiveState
                //+ '  BlockState=' + Lexer.LexerState.GetCurrentBlockTypeState
                );
            {Log(TOKEN_NAMES[Lexer.TokenID]);
            Log(IfThen(Lexer.TokenID in [tkCRLF, tkCRLFComment], '', CurrentToken));
            Log('BeginEnd=' + IntToStr(Lexer.LexerState.Counters.BeginEndCount));
            Log('LineNo=' + IntToStr(Lexer.LexerState.CurrentLine));
            Log('IfDirCount=' + IntToStr(Lexer.LexerState.Counters.IfDirectiveCount)); }
            Application.ProcessMessages;

            //if Lexer.TokenID = tkImplementation then Break;

            Lexer.NextToken;
          end;
          Elapsed := HRTimer.ElapsedMicroseconds;
        finally
          Memo1.Lines.EndUpdate;
        end;
      except
        on E: EPasLexerException do
        begin
          Log('LineNo=' + IntToStr(E.LineNumber));
          Log('LineCharIndex=' + IntToStr(E.LineCharIndex));
          Log('CurrentToken=' + TOKEN_NAMES[E.CurrentToken]);
          raise;
        end;
      end;

      Log('TimeMicro: ' + IntToStr(Elapsed));
      //Log('BeginEndCount=' + IntToStr(Lexer.LexerState.Counters.BeginEndCount));
      Log('RoundCount=' + IntToStr(Lexer.LexerState.Counters.RoundCount));
      Log('SquareCount=' + IntToStr(Lexer.LexerState.Counters.SquareCount));
      Log('IfDirectiveCount=' + IntToStr(Lexer.LexerState.Counters.IfDirectiveCount));
    finally
      HRTimer.Free;
    end;
  finally
    Lexer.Free;
  end;

  Log('DONE');
end;

procedure TfmMainTest.Button11Click(Sender: TObject);
begin
  try
    raise EPasLexerException.Create('Test message', nil);
  except
    on E: Exception do
      Log('Exception: ' + E.Message);
    on E: EPasLexerException do
      Log('EPasLexerException: ' + E.Message);
  end;

  Log('DONE');
end;

procedure TfmMainTest.Button12Click(Sender: TObject);
const
  DIALOG_TITLE = 'Select a folder with Pascal sources';
  SEARCH_PATTERN = '*.pas';
  SUMMARY_FORMAT = 'Files: %d, with blank line errors: %d, not parsed (skipped): %d';
var
  Dialog: TFileOpenDialog;
  Parser: TPasParser;
  Errors: TStringList;
  Files: TStringDynArray;
  Directory: string;
  i, j, ErrorFileCount, SkippedCount: Integer;
  IsParsed: Boolean;
begin
  Dialog := TFileOpenDialog.Create(nil);
  try
    Dialog.Title := DIALOG_TITLE;
    Dialog.Options := [fdoPickFolders, fdoPathMustExist, fdoForceFileSystem];
    if not Dialog.Execute then
      Exit;
    Directory := Dialog.FileName;
  finally
    Dialog.Free;
  end;

  Files := TDirectory.GetFiles(Directory, SEARCH_PATTERN, TSearchOption.soAllDirectories);
  ErrorFileCount := 0;
  SkippedCount := 0;
  Parser := TPasParser.Create;
  try
    Errors := TStringList.Create;
    try
      Memo1.Lines.BeginUpdate;
      try
        for i := 0 to High(Files) do
        begin
          // A file with a syntax error, or one that can not be read, is skipped
          try
            IsParsed := Parser.ParseFile(Files[i]);
          except
            IsParsed := False;
          end;
          if not IsParsed then
          begin
            Inc(SkippedCount);
            Continue;
          end;

          Errors.Clear;
          CheckImplementationBlankLines(Parser, Errors);
          if Errors.Count = 0 then
            Continue;

          Inc(ErrorFileCount);
          Log(Files[i]);
          for j := 0 to Errors.Count - 1 do
            Log(Errors[j]);
        end;
      finally
        Memo1.Lines.EndUpdate;
      end;
    finally
      Errors.Free;
    end;
  finally
    Parser.Free;
  end;

  Log(Format(SUMMARY_FORMAT, [Length(Files), ErrorFileCount, SkippedCount]));
  Log('DONE');
end;

procedure TfmMainTest.Button1Click(Sender: TObject);
var
  Lexer: TPasLexer;
  HRTimer: THighResolutionStopwatch;
  StrStream: TStringStream;
  FileName, FileContent, CurrentToken, DirectiveState: string;
  Elapsed: Int64;
  i: Integer;
begin
  StrStream := TStringStream.Create('', TEncoding.UTF8);
  try
    Lexer := TPasLexer.Create;
    try
      HRTimer := THighResolutionStopwatch.Create;
      try
        //FileName := ExtractFilePath(ParamStr(0)) + '..\UnitTests\TestData\testunit.pas';
        //FileName := ExtractFilePath(ParamStr(0)) + '..\UnitTests\TestData\VirtualTrees.pas';
        //FileName := 'C:\AirusTT\Source\AirusTT_Lib\CallbackSrv_TLB.pas';
        //FileName := ExtractFilePath(ParamStr(0)) + '..\UnitTests\TestData\BeginEndCountTestUnit2.pas';
        FileName := ExtractFilePath(ParamStr(0)) + '..\UnitTests\TestData\TestPasHi.pas';
        //FileName := 'C:\AirusTT\Source\AirusTT_Lib\N_BIOS.pas';
        //FileName := 'C:\AirusTT\Source\Libraries\EhLib110\Lazarus\Lib\DefaultItemsCollectionEditorsEh.pas';
        //FileName := 'C:\AirusTT\Source\SrvSite\Tovs.Exchange.HTTP.pas';
        //FileName := 'C:\AirusTT\Source\Other\Разное\Modules_RPT\BCS2011\Source\DelphiXE\Source\psReportBuilder.pas';
        //FileName := 'C:\AirusTT\Source\AirusTT_Runtime\aiConst.pas';
        //FileName := 'C:\AirusTT\Source\AirusTT_Lib\N_BIOS.pas';
        //FileName := 'C:\AirusTT\Source\KKM\AirusTT_Shtrih\U_RegisterCheck.pas';
        //FileName := 'C:\AirusTT\Source\KKM\Modules_BN\SBERBANK\Core.PinPad.pas';
        //FileName := 'C:\AirusTT\Source\KKM\Shtrih-415\FMU415\fmuZReport.pas';
        //FileName := 'C:\AirusTT\Source\Libraries\FastReport 2022-3 VCL Enterprise (October 2022) - FS\LibD28\frxBIFF.pas';
        //FileName := 'C:\AirusTT\Source\NPR\NPR\Common\uImportUploader.pas';
        //FileName := 'C:\AirusTT\Source\Modules\OTK\N_InsuranceIncident.pas';
        //FileName := 'C:\AirusTT\Source\Libraries\EhLib91\PropFilerEh.pas';
        //FileName := 'C:\AirusTT\Source\AirusTT_Lib\aiTimer.pas';
        //FileName := ExtractFilePath(ParamStr(0)) + '..\UnitTests\TestData\EmptyUnit.pas';

        //StrStream.LoadFromFile(FileName);
        //FileContent := StrStream.DataString;
        FileContent := TPasParser.GetFileDataString(FileName);

        try
          Memo1.Lines.BeginUpdate;
          try
            HRTimer.Restart;
            Lexer.SetData(FileContent);
            while Lexer.TokenID <> tkEOF do
            begin
              CurrentToken := Lexer.TokenString;

              DirectiveState := EmptyStr;
              for i := Low(Lexer.LexerState.IfDirectiveStateArray) to High(Lexer.LexerState.IfDirectiveStateArray) do
                DirectiveState := DirectiveState + COMMA_BOOL_ARRAY_SPACE[DirectiveState = EmptyStr]
                    + GetEnumName(TypeInfo(TIfDirectiveState), Ord(Lexer.LexerState.IfDirectiveStateArray[i]));
              DirectiveState := '[' + DirectiveState + ']';

              Log(TOKEN_NAMES[Lexer.TokenID]
                  + '(' + IfThen(Lexer.TokenID in [tkCRLF, tkCRLFComment], '', CurrentToken)
                  + ')' (*+ '  BeginEnd=' + IntToStr(Lexer.LexerState.Counters.BeginEndCount)*) + '  LineNo=' + IntToStr(Lexer.LexerState.CurrentLine)
                  + '  IfDirCount=' + IntToStr(Lexer.LexerState.Counters.IfDirectiveCount)
                  + '  IfDifValues=' + DirectiveState
                  //+ '  BlockState=' + Lexer.LexerState.GetCurrentBlockTypeState
                  );
              {Log(TOKEN_NAMES[Lexer.TokenID]);
              Log(IfThen(Lexer.TokenID in [tkCRLF, tkCRLFComment], '', CurrentToken));
              Log('BeginEnd=' + IntToStr(Lexer.LexerState.Counters.BeginEndCount));
              Log('LineNo=' + IntToStr(Lexer.LexerState.CurrentLine));
              Log('IfDirCount=' + IntToStr(Lexer.LexerState.Counters.IfDirectiveCount)); }
              Application.ProcessMessages;

              //if Lexer.TokenID = tkImplementation then Break;

              Lexer.NextToken;
            end;
            Elapsed := HRTimer.ElapsedMicroseconds;
          finally
            Memo1.Lines.EndUpdate;
          end;
        except
          on E: EPasLexerException do
          begin
            Log('LineNo=' + IntToStr(E.LineNumber));
            Log('LineCharIndex=' + IntToStr(E.LineCharIndex));
            Log('CurrentToken=' + TOKEN_NAMES[E.CurrentToken]);
            raise;
          end;
        end;

        Log('TimeMicro: ' + IntToStr(Elapsed));
        //Log('BeginEndCount=' + IntToStr(Lexer.LexerState.Counters.BeginEndCount));
        Log('RoundCount=' + IntToStr(Lexer.LexerState.Counters.RoundCount));
        Log('SquareCount=' + IntToStr(Lexer.LexerState.Counters.SquareCount));
        Log('IfDirectiveCount=' + IntToStr(Lexer.LexerState.Counters.IfDirectiveCount));
      finally
        HRTimer.Free;
      end;
    finally
      Lexer.Free;
    end;
  finally
    StrStream.Free;
  end;

  Log('DONE');
end;

procedure TfmMainTest.Button2Click(Sender: TObject);
var
  Lexer: TPasLexer;
  Files: TStringDynArray;
  i, TokenCount, FoundCount: Integer;
  FileContent, ParseError: string;
  HRTimer: THighResolutionStopwatch;
  Elapsed, ElapsedAverage: Int64;
  TokenSum: Double;
begin
  HRTimer := THighResolutionStopwatch.Create;
  try
    Lexer := TPasLexer.Create;
    try
      Files := TDirectory.GetFiles('C:\AirusTT\Source\', '*.pas', TSearchOption.soAllDirectories);
      Log('Count=' + IntToStr(Length(Files)));

      Elapsed := 0;
      ElapsedAverage := 0;
      FoundCount := 0;
      TokenSum := 0;
      for i := Low(Files) to High(Files) do
      begin
        if IsFileInIgnore(Files[i]) then
          Continue;

        if FoundCount > 20 then
          Break;

        FileContent := TPasParser.GetFileDataString(Files[i]);

        ParseError := '';
        TokenCount := 0;
        try
          HRTimer.Restart;
          Lexer.SetData(FileContent);

          while Lexer.TokenID <> tkEOF do
          begin
            Inc(TokenCount);
            Lexer.NextToken;
          end;
          Elapsed := HRTimer.ElapsedNanoseconds;
        except
          on E: Exception do
            ParseError := E.Message;
        end;

        ElapsedAverage := ElapsedAverage + (Elapsed div TokenCount);

        if {(Lexer.LexerState.Counters.BeginEndCount <> 0) or }(Lexer.LexerState.Counters.RoundCount <> 0)
            or (Lexer.LexerState.Counters.SquareCount <> 0) or (Lexer.LexerState.Counters.IfDirectiveCount <> 0)
            or (ParseError <> '')
        then
        begin
          Log('File: ' + Files[i]);
          if ParseError <> '' then
          begin
            Log('ParseError=' + ParseError);
            Log('Line=' + IntToStr(Lexer.LexerState.CurrentLine));
          end;
          Log('TokenCount=' + IntToStr(TokenCount));
          //Log('BeginEndCount=' + IntToStr(Lexer.LexerState.Counters.BeginEndCount));
          Log('RoundCount=' + IntToStr(Lexer.LexerState.Counters.RoundCount));
          Log('SquareCount=' + IntToStr(Lexer.LexerState.Counters.SquareCount));
          Log('IfDirectiveCount=' + IntToStr(Lexer.LexerState.Counters.IfDirectiveCount));
          Inc(FoundCount);
        end;

        //Log('File: ' + Files[i] + '   Size/Tokens=' + FloatToStr(Length(FileContent) / TokenCount));
        TokenSum := TokenSum + (Length(FileContent) / TokenCount);
      end;

      Log('Average per token(Nanoseconds)=' + FloatToStr(ElapsedAverage / Length(Files)));
      Log('Average Size/Tokens=' + FloatToStr(TokenSum / Length(Files)));
    finally
      Lexer.Free;
    end;
  finally
    HRTimer.Free;
  end;

  Log('DONE');
end;

procedure TfmMainTest.Button3Click(Sender: TObject);
var
  FileName, FileData: string;
begin
  //FileName := 'C:\GitHub Repos\FastPascalLexer\UnitTests\TestData\VirtualTrees.pas';
  //FileName := 'C:\GitHub Repos\FastPascalLexer\UnitTests\TestData\TestPasHi.pas';
  FileName := 'C:\GitHub Repos\FastPascalLexer\UnitTests\TestData\testunit.pas';

  //Enc := DetectEncoding(FileName);
  //Log('Name=' + Enc.EncodingName);

  FileData := TPasParser.GetFileDataString(FileName);

  Log('SystemSize=' + IntToStr(TFile.GetSize(FileName)));
  Log('StrLength=' + IntToStr(Length(FileData)));

  Log(FileData);

  {FileStream := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
  try
    SetLength(Buf, 100);
    FileStream.ReadBuffer(Buf, 100);

    for i := Low(Buf) to High(Buf) do
      Log('#' + IntToStr(Buf[i]));
  finally
    FileStream.Free;
  end;    }

  Log('DONE');
end;

procedure TfmMainTest.Button4Click(Sender: TObject);
const
  BENCHMARK_FILE_NAME = '..\UnitTests\TestData\VirtualTrees.pas';
  START_CAPTION = 'Start time test';
  MISSING_FILE_MESSAGE = 'Benchmark file "%s" was not found. Download '
      + 'https://raw.githubusercontent.com/JAM-Software/Virtual-TreeView/V5.3.0/Source/VirtualTrees.pas '
      + 'into UnitTests\TestData.';
var
  But: TButton;
  FileName: string;
begin
  But := Sender as TButton;

  if But.Tag = 0 then
  begin
    But.Tag := 1;
    But.Caption := 'Stop time test';
  end
  else
  begin
    But.Tag := 0;
    But.Caption := START_CAPTION;
    Log('Test stopped');
  end;

  if Assigned(FMeasureThread) then
    FreeAndNil(FMeasureThread);

  if But.Tag = 0 then Exit;

  FileName := ExtractFilePath(ParamStr(0)) + BENCHMARK_FILE_NAME;
  if not FileExists(FileName) then
  begin
    But.Tag := 0;
    But.Caption := START_CAPTION;
    Log(Format(MISSING_FILE_MESSAGE, [FileName]));
    Exit;
  end;

  FMeasureThread := TMeasureThread.Create(FileName);
  FMeasureThread.OnUpdateElapsed := CustomOnUpdateElapsed;
  FMeasureThread.StartMeasure;
  Log('Test started');
end;

procedure TfmMainTest.Button5Click(Sender: TObject);
var
  State: TPasLexerState;
begin
  Log('TPasLexerState size=' + IntToStr(SizeOf(TPasLexerState)));
  Log('TokenKind size=' + IntToStr(SizeOf(TTokenKind)));
  Log('CommentState size=' + IntToStr(SizeOf(TCommentState)));
  Log('TArray<Integer> size=' + IntToStr(SizeOf(TArray<Integer>)));
  Log('Cardinal size=' + IntToStr(SizeOf(Cardinal)));
  Log('Integer size=' + IntToStr(SizeOf(Integer)));
  Log('Boolean size=' + IntToStr(SizeOf(Boolean)));
  Log('tkInterface=' + IntToHex(Ord(tkInterface)));
  Log('tkSemicolon=' + IntToHex(Ord(tkSemicolon)));
  Log('IfDirectiveStateArray offset=' + IntToStr(NativeInt(@State.IfDirectiveStateArray) - NativeInt(@State)));
end;

procedure TfmMainTest.Button6Click(Sender: TObject);
const
  TRY_COUNT = 1000000;
var
  HRTimer: THighResolutionStopwatch;
  i, j: Integer;
  FirstRec, SecondRec: TPasLexerState;
  Elapsed, ElapsedOverall: Int64;
begin
  RandSeed := 123456;
  ElapsedOverall := 0;
  HRTimer := THighResolutionStopwatch.Create;
  try
    for i := 1 to TRY_COUNT do
    begin
      FirstRec.CurrentIndex := Random(1000);
      FirstRec.MaxIndex := FirstRec.CurrentIndex + Cardinal(Random(1000));
      FirstRec.CurrentLine := Random(100);
      FirstRec.CurrentLineStartPos := Random(100);
      FirstRec.CurrentTokenPos := Random(1000);
      FirstRec.LastSignificantTokenPos := Random(1000);
      FirstRec.Counters.RoundCount := Random(100);
      FirstRec.Counters.SquareCount := Random(100);
      FirstRec.Counters.IfDirectiveCount := Random(10);
      FirstRec.CurrentToken := tkUnknown;
      FirstRec.LastSignificantToken := tkUnknown;
      FirstRec.CommentState := csNo;
      FirstRec.IsProperty := False;
      //FirstRec.IsRecord := False;
      //FirstRec.IsClass := True;
      //FirstRec.IsInterface := False;
      FirstRec.IsCompilerDirective := False;
      FirstRec.IgnoreCompilerDirectiveChecks := False;
      SetLength(FirstRec.IfDirectiveStateArray, Random(10));
      for j := Low(FirstRec.IfDirectiveStateArray) to High(FirstRec.IfDirectiveStateArray) do
        FirstRec.IfDirectiveStateArray[j] := TIfDirectiveState(Random(3));
      SetLength(FirstRec.IfDirectiveSavedCountersArray, Random(10));

      HRTimer.Restart;
      SecondRec.CopyFrom(FirstRec);
      Elapsed := HRTimer.ElapsedNanoseconds;

      ElapsedOverall := ElapsedOverall + Elapsed;
    end;
  finally
    HRTimer.Free
  end;

  Log('Average nanosec=' + FloatToStr(ElapsedOverall/TRY_COUNT));

  Log('DONE');
end;

procedure TfmMainTest.Button7Click(Sender: TObject);
const
  TRY_COUNT = 1000000;
var
  HRTimer: THighResolutionStopwatch;
  i, j: Integer;
  FirstRec: TPasLexerState;
  Elapsed, ElapsedOverall: Int64;
begin
  RandSeed := 123456;
  ElapsedOverall := 0;
  HRTimer := THighResolutionStopwatch.Create;
  try
    for i := 1 to TRY_COUNT do
    begin
      FirstRec.CurrentIndex := Random(1000);
      FirstRec.MaxIndex := FirstRec.CurrentIndex + Cardinal(Random(1000));
      FirstRec.CurrentLine := Random(100);
      FirstRec.CurrentLineStartPos := Random(100);
      FirstRec.CurrentTokenPos := Random(1000);
      FirstRec.LastSignificantTokenPos := Random(1000);
      FirstRec.Counters.RoundCount := Random(100);
      FirstRec.Counters.SquareCount := Random(100);
      FirstRec.Counters.IfDirectiveCount := Random(10);
      FirstRec.CurrentToken := tkUnknown;
      FirstRec.LastSignificantToken := tkUnknown;
      FirstRec.CommentState := csNo;
      FirstRec.IsProperty := False;
      //FirstRec.IsRecord := False;
      //FirstRec.IsClass := True;
      //FirstRec.IsInterface := False;
      FirstRec.IsCompilerDirective := False;
      FirstRec.IgnoreCompilerDirectiveChecks := False;
      SetLength(FirstRec.IfDirectiveStateArray, Random(10));
      for j := Low(FirstRec.IfDirectiveStateArray) to High(FirstRec.IfDirectiveStateArray) do
        FirstRec.IfDirectiveStateArray[j] := TIfDirectiveState(Random(3));
      SetLength(FirstRec.IfDirectiveSavedCountersArray, Random(10));

      HRTimer.Restart;
      FirstRec.Reset;
      Elapsed := HRTimer.ElapsedNanoseconds;

      ElapsedOverall := ElapsedOverall + Elapsed;
    end;
  finally
    HRTimer.Free
  end;

  //Log('Overall=' + IntToStr(ElapsedOverall));
  //ElapsedOverall := ElapsedOverall div TRY_COUNT;
  Log('Average nanosec=' + FloatToStr(ElapsedOverall/TRY_COUNT));

  Log('DONE');
end;

procedure TfmMainTest.Button8Click(Sender: TObject);
var
  Parser: TPasParser;
  HRTimer: THighResolutionStopwatch;
  FileName, DataString{, ExportFileName, TempText, FileExt}: string;
  //i: Integer;
  CurState: TPasLexerMinimalState;
  Elapsed: Int64;
  CurError: TParseErrorItem;
  //FileStream: TFileStream;
  Root: TBaseLexemeNode;
  IsParsed: Boolean;
begin
  Parser := TPasParser.Create;
  try
    HRTimer := THighResolutionStopwatch.Create;
    try
      //FileName := ExtractFilePath(ParamStr(0)) + '..\UnitTests\TestData\EmptyUnit.pas';
      //FileName := ExtractFilePath(ParamStr(0)) + '..\UnitTests\TestData\BeginEndCountTestUnit2.pas';
      //FileName := ExtractFilePath(ParamStr(0)) + '..\UnitTests\TestData\VirtualTrees.pas';
      FileName := ExtractFilePath(ParamStr(0)) + '..\UnitTests\TestData\TestPasHi.pas';

      DataString := TPasParser.GetFileDataString(FileName);

      HRTimer.Restart;
      IsParsed := Parser.ParseString(DataString);
      Elapsed := HRTimer.ElapsedMicroseconds;

      Log('TokenCount=' + IntToStr(Parser.ParsedStateCount) + ', ElapsedMiscoSec=' + IntToStr(Elapsed));
      if not IsParsed then
      begin
        for CurError in Parser.ErrorEnum do
          Log('Parse error (Line: ' + IntToStr(CurError.LineNumber) + ', Column: ' + IntToStr(CurError.LinePosition)
              + '): ' + CurError.Message);
        Exit;
      end;

      for CurState in Parser.ParsedStateEnum do
        Log(TOKEN_NAMES[CurState.CurrentToken]
            + '(' + IfThen(CurState.CurrentToken in [tkCRLF, tkCRLFComment], '', CurState.TokenString)
            + ')'
            + '  LineNo=' + IntToStr(CurState.CurrentLine)
            );
      Log('-------------------------------');

      Root := Parser.RootLexeme;
      LogLexemeTree(Root, 0);

      {Log('----------------------------------- Text:');
      TempText := EmptyStr;
      for CurState in Parser.ParsedStateEnum do
        TempText := TempText + CurState.TokenString;

      ExportFileName := FileName;
      FileExt := ExtractFileExt(ExportFileName);
      ExportFileName := ChangeFileExt(ExportFileName, '');
      ExportFileName := ExportFileName + '_cleared' + FileExt;
      FileStream := TFileStream.Create(ExportFileName, fmCreate);
      try
        FileStream.Write(TempText[1], Length(TempText) * SizeOf(Char));

        Log('Cleared file exported');
      finally
        FileStream.Free;
      end;  }
      //Log(TempText);

      {for CurState in Parser.ParsedStateEnum do
        Log('Token=' + TOKEN_NAMES[CurState.CurrentToken]);

      Log('Second FOR:');

      for CurError in Parser.ErrorEnum do
        Log('ErrorLine=' + IntToStr(CurError.LineNumber) + ', LinePos=' + IntToStr(CurError.LinePosition));}
    finally
      HRTimer.Free;
    end;
  finally
    FreeAndNil(Parser);
  end;

  Log('DONE');
end;

procedure TfmMainTest.Button9Click(Sender: TObject);
begin
  Memo1.Clear;
end;

procedure TfmMainTest.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  FreeAndNil(FMeasureThread);
end;

procedure TfmMainTest.CustomOnUpdateElapsed(AAverageElapsed, ACycleCount: Int64);
begin
  TThread.Queue(nil,
    procedure
    begin
      Label3.Caption := IntToStr(AAverageElapsed);
      Label4.Caption := IntToStr(ACycleCount);
    end
  );
end;

procedure TfmMainTest.LogLexemeTree(ANode: TBaseLexemeNode; AIndent: Integer);
var
  Node: TBaseLexemeNode;
begin
  Log(StringOfChar(' ', AIndent) + ANode.GetLexemeLog);

  Node := ANode.FirstChild;
  while Assigned(Node) do
  begin
    LogLexemeTree(Node, AIndent + 2);
    Node := Node.NextSibling;
  end;
end;

procedure TfmMainTest.Log(const AMessage: string);
begin
  TThread.Queue(nil,
    procedure
    begin
      Memo1.Lines.Add(AMessage);
    end
  );
end;

end.
