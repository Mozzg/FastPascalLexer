(*******************************************************************************
*  Copyright © 2025 - 2026 Pervov Evgeny                                       *
*                                                                              *
*  Licensed under the Apache License, Version 2.0 (the "License");             *
*  you may not use this file except in compliance with the License.            *
*  You may obtain a copy of the License at                                     *
*                                                                              *
*      http://www.apache.org/licenses/LICENSE-2.0                              *
*                                                                              *
*  Unless required by applicable law or agreed to in writing, software         *
*  distributed under the License is distributed on an "AS IS" BASIS,           *
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.    *
*  See the License for the specific language governing permissions and         *
*  limitations under the License.                                              *
*                                                                              *
*  Author: Pervov Evgeny                                                       *
*  Created: 16.03.2025                                                         *
*  Class: TPasParser                                                           *
*  Description: Pascal source code parser based on TPasLexer tokenizer/lexer   *
*  Version: 0.4                                                                *
*  Last modified: 02.11.2026                                                   *
*  Contributor(s):                                                             *
*    Pervov Evgeny <operationm@list.ru>                                        *
*******************************************************************************)

unit uPasParser;

interface

uses
  System.SysUtils, System.Classes, System.Math, Winapi.Windows,
  uPasLexer, uPasParserTypes, uPasLexerTypes, uPasParserGrammar;

const
  // Expected average count of characters per token, used to size the token arrays
  SIZE_TOKEN_RATIO = 3.5;
  MIN_TOKEN_CAPACITY = 16;

type
  TParserParsedStateEnumerator = class;
  TParserErrorEnumerator = class;

  // Parser of Pascal source code.
  // It reads all tokens of the source with TPasLexer (SourceTokenItem), keeps the tokens of the code compiled when the
  // first branch of every conditional directive is taken, without the compiler directives (ParsedStateItem), and builds
  // the lexeme tree from them (RootLexeme). The tokens of both lists carry the layout data for code style checks: line,
  // column, whitespace around the token and its place on the line; LineItem describes the lines of the source.
  TPasParser = class(TObject)
  private
    FLexer: TPasLexer;
    FDataString: string;
    // All tokens of the source, including the compiler directives and the inactive conditional branches
    FSourceTokens: TLexerStateArray;
    FSourceTokensCount: Integer;
    // Tokens of the parsed code: without the compiler directives and the inactive conditional branches
    FParsedStates: TLexerStateArray;
    FParsedStatesCount: Integer;
    FLines: TArray<TPasLineInfo>;
    FRootLexemeNode: TBaseLexemeNode;
    FErrorOutputArray: TArray<TParseErrorItem>;
    FParsedStateEnumerator: TParserParsedStateEnumerator;
    FErrorEnumerator: TParserErrorEnumerator;

    function InternalParse: Boolean;
    // Reads all tokens of the source; AActiveFlags marks the tokens of the code to parse
    procedure ReadSourceTokens(var AActiveFlags: TArray<Boolean>);
    // True when the lexer is in the first branch of every conditional directive around the current token
    function IsLexerInActiveBranch: Boolean;
    // Splits the source into lines
    procedure FillLines;
    // Fills the lines and the layout fields of the source tokens
    procedure FillLayout;
    // Copies the tokens of the code to parse into the parsed states
    procedure FillParsedStates(const AActiveFlags: TArray<Boolean>);
    // Builds the lexeme tree; on a syntax error adds it to the errors and returns False
    function BuildLexemeTree: Boolean;
    procedure AddError(ALineNumber, ALinePosition: Integer; const AMessage: string);

    function GetSourceTokenCount: Integer;
    function GetSourceTokenItem(AIndex: Integer): TPasLexerMinimalState;
    function GetParsedStateCount: Integer;
    function GetParsedStateItem(AIndex: Integer): TPasLexerMinimalState;
    function GetLineCount: Integer;
    function GetLineItem(ALineNumber: Integer): TPasLineInfo;
    function GetErrorCount: Integer;
    function GetErrorItem(AIndex: Integer): TParseErrorItem;
  public
    constructor Create;
    destructor Destroy; override;

    class function TryGetEncodingByPreamble(ABuffer: Pointer; ASize: Integer): TEncoding; overload;
    class function TryGetEncodingByPreamble(AStream: TStream): TEncoding; overload;
    class function GetFileDataString(const AFileName: string): string;

    // Parses the source. Returns False when the source has a syntax error or unbalanced conditional directives,
    // ErrorItem describes the error and RootLexeme is nil. The tokens and the lines are available in both cases (after
    // a lexer error, the tokens read before it).
    function ParseFile(const AFileName: string): Boolean;
    function ParseString(const ADataString: string): Boolean;
    procedure Clear;

    property DataString: string read FDataString;
    // All tokens of the source, including the compiler directives and the inactive conditional branches
    property SourceTokenCount: Integer read GetSourceTokenCount;
    property SourceTokenItem[AIndex: Integer]: TPasLexerMinimalState read GetSourceTokenItem;
    // Tokens of the parsed code, the lexeme nodes refer to them
    property ParsedStateCount: Integer read GetParsedStateCount;
    property ParsedStateItem[AIndex: Integer]: TPasLexerMinimalState read GetParsedStateItem;
    // Lines of the source; ALineNumber is 1-based like TPasLexerMinimalState.CurrentLine
    property LineCount: Integer read GetLineCount;
    property LineItem[ALineNumber: Integer]: TPasLineInfo read GetLineItem;
    property ErrorCount: Integer read GetErrorCount;
    property ErrorItem[AIndex: Integer]: TParseErrorItem read GetErrorItem;
    // Root of the lexeme tree, nil when the source has an error
    property RootLexeme: TBaseLexemeNode read FRootLexemeNode;

    property ParsedStateEnum: TParserParsedStateEnumerator read FParsedStateEnumerator;
    property ErrorEnum: TParserErrorEnumerator read FErrorEnumerator;
  end;

  TParserParsedStateEnumerator = class(TObject)
  strict private
    FOwner: TPasParser;
    FCurrentIndex: Integer;
  protected
    function GetCurrent: TPasLexerMinimalState;
  public
    constructor Create(AOwner: TPasParser);

    function GetEnumerator: TParserParsedStateEnumerator;
    function MoveNext: Boolean;

    property Current: TPasLexerMinimalState read GetCurrent;
  end;

  TParserErrorEnumerator = class(TObject)
  strict private
    FOwner: TPasParser;
    FCurrentIndex: Integer;
  protected
    function GetCurrent: TParseErrorItem;
  public
    constructor Create(AOwner: TPasParser);

    function GetEnumerator: TParserErrorEnumerator;
    function MoveNext: Boolean;

    property Current: TParseErrorItem read GetCurrent;
  end;

implementation

uses
  uPasExceptions;

const
  // Whitespace characters, the same as for tkSpace of the lexer
  WHITESPACE_CHARS = [#1..#9, #11..#12, #14..#32];
  // Tokens that are not content of a line for the layout fields
  LINE_LAYOUT_TOKENS = [tkSpace, tkCRLF, tkCRLFComment];

{ TPasParser }

constructor TPasParser.Create;
begin
  inherited Create;

  FLexer := TPasLexer.Create;
  FParsedStateEnumerator := TParserParsedStateEnumerator.Create(Self);
  FErrorEnumerator := TParserErrorEnumerator.Create(Self);
end;

destructor TPasParser.Destroy;
begin
  FreeAndNil(FRootLexemeNode);
  FreeAndNil(FErrorEnumerator);
  FreeAndNil(FParsedStateEnumerator);
  FreeAndNil(FLexer);

  inherited Destroy;
end;

function TPasParser.InternalParse: Boolean;
var
  ActiveFlags: TArray<Boolean>;
  WasLexerError: Boolean;
begin
  WasLexerError := False;
  try
    ReadSourceTokens(ActiveFlags);
  except
    on E: EPasLexerException do
    begin
      AddError(E.LineNumber, E.LineCharIndex, E.Message);
      WasLexerError := True;
    end;
  end;

  // After a lexer error the tokens read before it are available, but the tree is not built
  FillLayout;
  FillParsedStates(ActiveFlags);
  if WasLexerError then
    Exit(False);
  Result := BuildLexemeTree;
end;

procedure TPasParser.ReadSourceTokens(var AActiveFlags: TArray<Boolean>);
var
  Capacity: Integer;
begin
  Capacity := Max(Trunc(Length(FDataString) / SIZE_TOKEN_RATIO), MIN_TOKEN_CAPACITY);
  SetLength(FSourceTokens, Capacity);
  SetLength(AActiveFlags, Capacity);
  FSourceTokensCount := 0;
  try
    FLexer.SetData(FDataString);
    while FLexer.TokenID <> tkEOF do
    begin
      if FSourceTokensCount >= Capacity then
      begin
        Capacity := Capacity * 2;
        SetLength(FSourceTokens, Capacity);
        SetLength(AActiveFlags, Capacity);
      end;

      FSourceTokens[FSourceTokensCount].FillFromLexer(FLexer);
      FSourceTokens[FSourceTokensCount].SourceTokenIndex := FSourceTokensCount;
      AActiveFlags[FSourceTokensCount] := (FLexer.TokenID <> tkCompilerDirective) and IsLexerInActiveBranch;
      Inc(FSourceTokensCount);

      FLexer.NextToken;
    end;
  finally
    SetLength(FSourceTokens, FSourceTokensCount);
    SetLength(AActiveFlags, FSourceTokensCount);
  end;
end;

function TPasParser.IsLexerInActiveBranch: Boolean;
var
  i: Integer;
begin
  for i := 0 to High(FLexer.LexerState.IfDirectiveStateArray) do
    if FLexer.LexerState.IfDirectiveStateArray[i] <> idsIf then
      Exit(False);
  Result := True;
end;

procedure TPasParser.FillLines;
var
  Text: PChar;
  TextLength, Position, LineStart, LineIndex, Indent, i: Integer;
begin
  Text := PChar(FDataString);
  TextLength := Length(FDataString);

  // Line breaks are CR LF, CR or LF, the same as for the lexer
  LineIndex := 0;
  for Position := 0 to TextLength - 1 do
    if (Text[Position] = #10) or ((Text[Position] = #13) and (Text[Position + 1] <> #10)) then
      Inc(LineIndex);
  // A line break at the end of the text does not start a new line
  if (TextLength > 0) and CharInSet(Text[TextLength - 1], [#10, #13]) then
    SetLength(FLines, LineIndex)
  else
    SetLength(FLines, LineIndex + 1);

  LineIndex := 0;
  LineStart := 0;
  Position := 0;
  while (Position < TextLength) and (LineIndex < Length(FLines)) do
  begin
    if CharInSet(Text[Position], [#10, #13]) then
    begin
      FLines[LineIndex].StartPos := LineStart;
      FLines[LineIndex].LineLength := Position - LineStart;
      Inc(LineIndex);
      if (Text[Position] = #13) and (Text[Position + 1] = #10) then
        Inc(Position);
      LineStart := Position + 1;
    end;
    Inc(Position);
  end;
  if LineIndex < Length(FLines) then
  begin
    FLines[LineIndex].StartPos := LineStart;
    FLines[LineIndex].LineLength := TextLength - LineStart;
  end;

  for i := 0 to High(FLines) do
  begin
    Indent := 0;
    while (Indent < FLines[i].LineLength) and CharInSet(Text[FLines[i].StartPos + Indent], WHITESPACE_CHARS) do
      Inc(Indent);
    FLines[i].Indent := Indent;
    FLines[i].IsBlank := Indent = FLines[i].LineLength;
    FLines[i].FirstTokenIndex := -1;
  end;
end;

procedure TPasParser.FillLayout;
var
  i, LineIndex, EndLineIndex, EndPos, LastContentLineIndex, NextContentLineIndex: Integer;
  EndLineIndexes: TArray<Integer>;
  Token: PPasLexerMinimalState;
begin
  FillLines;
  SetLength(EndLineIndexes, FSourceTokensCount);

  LineIndex := 0;
  LastContentLineIndex := -1;
  for i := 0 to FSourceTokensCount - 1 do
  begin
    Token := @FSourceTokens[i];
    // The lines are recomputed from the text: the lexer counts a directive spanning several lines as one line
    while (LineIndex < High(FLines)) and (FLines[LineIndex + 1].StartPos <= Integer(Token^.CurrentIndex)) do
      Inc(LineIndex);
    Token^.CurrentLine := LineIndex + 1;
    Token^.CurrentLineStartPos := FLines[LineIndex].StartPos;
    if FLines[LineIndex].FirstTokenIndex < 0 then
      FLines[LineIndex].FirstTokenIndex := i;

    EndLineIndex := LineIndex;
    EndPos := Integer(Token^.CurrentIndex) + Token^.TokenLength - 1;
    while (EndLineIndex < High(FLines)) and (FLines[EndLineIndex + 1].StartPos <= EndPos) do
      Inc(EndLineIndex);
    EndLineIndexes[i] := EndLineIndex;

    Token^.IsFirstOnLine := LastContentLineIndex < LineIndex;
    if not (Token^.CurrentToken in LINE_LAYOUT_TOKENS) then
      LastContentLineIndex := EndLineIndex;

    if (i > 0) and (FSourceTokens[i - 1].CurrentToken = tkSpace) then
      Token^.SpaceBefore := FSourceTokens[i - 1].TokenLength;
    if (i < FSourceTokensCount - 1) and (FSourceTokens[i + 1].CurrentToken = tkSpace) then
      Token^.SpaceAfter := FSourceTokens[i + 1].TokenLength;
  end;

  NextContentLineIndex := MaxInt;
  for i := FSourceTokensCount - 1 downto 0 do
  begin
    Token := @FSourceTokens[i];
    Token^.IsLastOnLine := NextContentLineIndex > EndLineIndexes[i];
    if not (Token^.CurrentToken in LINE_LAYOUT_TOKENS) then
      NextContentLineIndex := Integer(Token^.CurrentLine) - 1;
  end;
end;

procedure TPasParser.FillParsedStates(const AActiveFlags: TArray<Boolean>);
var
  i, LineOutputStart: Integer;
  LineHasCode, LineHasRemovedTokens: Boolean;
begin
  SetLength(FParsedStates, FSourceTokensCount);
  FParsedStatesCount := 0;
  LineOutputStart := 0;
  LineHasCode := False;
  LineHasRemovedTokens := False;
  for i := 0 to FSourceTokensCount - 1 do
  begin
    if AActiveFlags[i] then
    begin
      FParsedStates[FParsedStatesCount] := FSourceTokens[i];
      Inc(FParsedStatesCount);
      if not (FSourceTokens[i].CurrentToken in INSIGNIFICANT_TOKENS) then
        LineHasCode := True;
    end
    else
      LineHasRemovedTokens := True;

    if FSourceTokens[i].CurrentToken in [tkCRLF, tkCRLFComment] then
    begin
      // A line that held only removed tokens, whitespace and comments is dropped completely
      if LineHasRemovedTokens and not LineHasCode then
        FParsedStatesCount := LineOutputStart;
      LineOutputStart := FParsedStatesCount;
      LineHasCode := False;
      LineHasRemovedTokens := False;
    end;
  end;
  SetLength(FParsedStates, FParsedStatesCount);
end;

function TPasParser.BuildLexemeTree: Boolean;
begin
  FRootLexemeNode := TRootLexemeNode.Create(@FParsedStates, FParsedStatesCount);
  try
    FRootLexemeNode.ParseItself;
    Result := True;
  except
    on E: EPasGrammarParserException do
    begin
      FreeAndNil(FRootLexemeNode);
      AddError(E.LineNumber, E.LineCharIndex, E.Message);
      Result := False;
    end;
  else
    FreeAndNil(FRootLexemeNode);
    raise;
  end;
end;

procedure TPasParser.AddError(ALineNumber, ALinePosition: Integer; const AMessage: string);
var
  ErrorIndex: Integer;
begin
  ErrorIndex := Length(FErrorOutputArray);
  SetLength(FErrorOutputArray, ErrorIndex + 1);
  FErrorOutputArray[ErrorIndex].LineNumber := ALineNumber;
  FErrorOutputArray[ErrorIndex].LinePosition := ALinePosition;
  FErrorOutputArray[ErrorIndex].ErrorSeverity := pesError;
  FErrorOutputArray[ErrorIndex].Message := AMessage;
end;

function TPasParser.GetSourceTokenCount: Integer;
begin
  Result := FSourceTokensCount;
end;

function TPasParser.GetSourceTokenItem(AIndex: Integer): TPasLexerMinimalState;
begin
  if (AIndex < 0) or (AIndex >= FSourceTokensCount) then
    raise EPasParserException.CreateFmt(EMESSAGE_GET_INDEX_OUT_OF_RANGE, [AIndex], Self);

  Result := FSourceTokens[AIndex];
end;

function TPasParser.GetParsedStateCount: Integer;
begin
  Result := FParsedStatesCount;
end;

function TPasParser.GetParsedStateItem(AIndex: Integer): TPasLexerMinimalState;
begin
  if (AIndex < 0) or (AIndex >= FParsedStatesCount) then
    raise EPasParserException.CreateFmt(EMESSAGE_GET_INDEX_OUT_OF_RANGE, [AIndex], Self);

  Result := FParsedStates[AIndex];
end;

function TPasParser.GetLineCount: Integer;
begin
  Result := Length(FLines);
end;

function TPasParser.GetLineItem(ALineNumber: Integer): TPasLineInfo;
begin
  if (ALineNumber < 1) or (ALineNumber > Length(FLines)) then
    raise EPasParserException.CreateFmt(EMESSAGE_GET_INDEX_OUT_OF_RANGE, [ALineNumber], Self);

  Result := FLines[ALineNumber - 1];
end;

function TPasParser.GetErrorCount: Integer;
begin
  Result := Length(FErrorOutputArray);
end;

function TPasParser.GetErrorItem(AIndex: Integer): TParseErrorItem;
begin
  if (AIndex < 0) or (AIndex >= Length(FErrorOutputArray)) then
    raise EPasParserException.CreateFmt(EMESSAGE_GET_INDEX_OUT_OF_RANGE, [AIndex], Self);

  Result := FErrorOutputArray[AIndex];
end;

class function TPasParser.TryGetEncodingByPreamble(ABuffer: Pointer; ASize: Integer): TEncoding;
var
  Preamble: TBytes;
begin
  if (not Assigned(ABuffer)) or (ASize <= 0) then Exit(nil);
  Result := nil;

  Preamble := TEncoding.UTF8.GetPreamble;
  if (Length(Preamble) <= ASize) and CompareMem(ABuffer, Pointer(Preamble), Length(Preamble)) then
    Exit(TEncoding.UTF8);

  Preamble := TEncoding.Unicode.GetPreamble;
  if (Length(Preamble) <= ASize) and CompareMem(ABuffer, Pointer(Preamble), Length(Preamble)) then
    Exit(TEncoding.Unicode);

  Preamble := TEncoding.BigEndianUnicode.GetPreamble;
  if (Length(Preamble) <= ASize) and CompareMem(ABuffer, Pointer(Preamble), Length(Preamble)) then
    Exit(TEncoding.BigEndianUnicode);
end;

class function TPasParser.TryGetEncodingByPreamble(AStream: TStream): TEncoding;
const
  MAX_PREAMBLE_SIZE = 10;
var
  OldPosition: Int64;
  Buffer: Pointer;
  Size: Integer;
  Preamble: TBytes;
begin
  Result := nil;
  OldPosition := AStream.Position;

  GetMem(Buffer, MAX_PREAMBLE_SIZE);
  try
    Size := Min(MAX_PREAMBLE_SIZE, AStream.Size - AStream.Position);
    if Size > 0 then
    begin
      AStream.ReadBuffer(Buffer^, Size);
      AStream.Seek(OldPosition, soBeginning);
    end;
    Result := TryGetEncodingByPreamble(Buffer, Size);
  finally
    FreeMem(Buffer);
    if Assigned(Result) then
    begin
      Preamble := Result.GetPreamble;
      OldPosition := OldPosition + Length(Preamble);
      AStream.Seek(OldPosition, soBeginning);
    end;
  end;
end;

class function TPasParser.GetFileDataString(const AFileName: string): string;
const
  MAX_BUFFER_SIZE = 512;
var
  DataEncoding, SecondaryEncoding: TEncoding;
  FileStream: TFileStream;
  MemStream: TMemoryStream;
  DataStartPosition: Int64;
  Buffer, ConvertedBuffer: TBytes;
  BufferSize, Mask: Integer;
  WasError: Boolean;
begin
  if not FileExists(AFileName) then
    raise EPasParserException.CreateFmt(EMESSAGE_FILE_DOES_NOT_EXISTS, [AFileName]);

  MemStream := TMemoryStream.Create;
  try
    FileStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      MemStream.LoadFromStream(FileStream);
      DataStartPosition := MemStream.Seek(0, soBeginning);
    finally
      FileStream.Free;
    end;

    DataEncoding := TryGetEncodingByPreamble(MemStream);

    if Assigned(DataEncoding) then
      DataStartPosition := MemStream.Position
    else
    begin
      BufferSize := Min(MAX_BUFFER_SIZE, MemStream.Size);
      SetLength(Buffer, BufferSize);
      MemStream.ReadBuffer(Buffer, Length(Buffer));

      Mask := IS_TEXT_UNICODE_UNICODE_MASK or IS_TEXT_UNICODE_REVERSE_MASK;
      IsTextUnicode(Buffer, Length(Buffer), @Mask);

      if (BufferSize mod 2 = 0) and ((Mask and IS_TEXT_UNICODE_UNICODE_MASK) <> 0) then
        DataEncoding := TEncoding.Unicode
      else if (BufferSize mod 2 = 0) and ((Mask and IS_TEXT_UNICODE_REVERSE_MASK) <> 0) then
        DataEncoding := TEncoding.BigEndianUnicode
      else
        DataEncoding := TEncoding.UTF8;
    end;

    if DataEncoding.IsSingleByte then
      SecondaryEncoding := TEncoding.UTF8
    else
      SecondaryEncoding := TEncoding.ANSI;

    SetLength(Buffer, MemStream.Size);
    MemStream.Seek(DataStartPosition, soBeginning);
    MemStream.ReadBuffer(Buffer, MemStream.Size - DataStartPosition);
    MemStream.Clear;

    if DataEncoding.CodePage <> TEncoding.Unicode.CodePage then
    begin
      WasError := False;
      try
        ConvertedBuffer := TEncoding.Convert(DataEncoding, TEncoding.Unicode, Buffer)
      except
        WasError := True;
      end;

      if WasError then
      begin
        WasError := False;
        try
          ConvertedBuffer := TEncoding.Convert(SecondaryEncoding, TEncoding.Unicode, Buffer)
        except
          WasError := True;
        end;

        if WasError then
        begin
          SetLength(ConvertedBuffer, Length(Buffer));
          Move(Buffer[0], ConvertedBuffer[0], Length(Buffer));
        end;
      end;
    end
    else
    begin
      SetLength(ConvertedBuffer, Length(Buffer));
      Move(Buffer[0], ConvertedBuffer[0], Length(Buffer));
    end;

    SetLength(Buffer, 0);

    try
      Result := TEncoding.Unicode.GetString(ConvertedBuffer);
      Exit;
    except
      on E: Exception do
        raise EPasParserException.CreateFmt(EMESSAGE_FAILED_TO_READ_FILE, [AFileName, E.Message]);
    end;
  finally
    MemStream.Free;
  end;
end;

function TPasParser.ParseFile(const AFileName: string): Boolean;
begin
  Result := ParseString(GetFileDataString(AFileName));
end;

function TPasParser.ParseString(const ADataString: string): Boolean;
begin
  Clear;
  FDataString := ADataString;

  Result := InternalParse;
end;

procedure TPasParser.Clear;
begin
  // The tree refers to the parsed states, it is freed first
  FreeAndNil(FRootLexemeNode);
  FDataString := EmptyStr;
  FSourceTokens := nil;
  FSourceTokensCount := 0;
  FParsedStates := nil;
  FParsedStatesCount := 0;
  FLines := nil;
  FErrorOutputArray := nil;
end;

{ TParserParsedStateEnumerator }

constructor TParserParsedStateEnumerator.Create(AOwner: TPasParser);
begin
  inherited Create;

  FOwner := AOwner;
  FCurrentIndex := -1;
end;

function TParserParsedStateEnumerator.GetCurrent: TPasLexerMinimalState;
begin
  Result := FOwner.ParsedStateItem[FCurrentIndex];
end;

function TParserParsedStateEnumerator.GetEnumerator: TParserParsedStateEnumerator;
begin
  Result := TParserParsedStateEnumerator.Create(FOwner);
end;

function TParserParsedStateEnumerator.MoveNext: Boolean;
begin
  Inc(FCurrentIndex);
  Result := FCurrentIndex < FOwner.FParsedStatesCount;
end;

{ TParserErrorEnumerator }

constructor TParserErrorEnumerator.Create(AOwner: TPasParser);
begin
  inherited Create;

  FOwner := AOwner;
  FCurrentIndex := -1;
end;

function TParserErrorEnumerator.GetCurrent: TParseErrorItem;
begin
  Result := FOwner.ErrorItem[FCurrentIndex];
end;

function TParserErrorEnumerator.GetEnumerator: TParserErrorEnumerator;
begin
  Result := TParserErrorEnumerator.Create(FOwner);
end;

function TParserErrorEnumerator.MoveNext: Boolean;
begin
  Inc(FCurrentIndex);
  Result := FCurrentIndex < FOwner.ErrorCount;
end;

end.
