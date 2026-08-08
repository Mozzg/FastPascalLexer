(*******************************************************************************
*  Copyright © 2025 Pervov Evgeny                                              *
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
*  Version: 0.2                                                                *
*  Last modified: 10.05.2025                                                   *
*  Contributor(s):                                                             *
*    Pervov Evgeny <operationm@list.ru>                                        *
*******************************************************************************)

unit uPasParser;

interface

uses
  System.SysUtils, System.Classes, System.Math, Winapi.Windows,
  uPasLexer, uPasParserTypes, uPasLexerTypes, uPasParserGrammar;

const
  SIZE_TOKEN_RATIO = 3.5;
  TOKEN_INCREASE_COUNT = 200;

type
  // +++ распарсить токены без whitespace. Запоминать статус токенайзера только на значимых токенах.
  // Отталкиваться в проверке правил от значимых токенов. Попробовать предпарсер, который убирает conditional compile
  // путем оставления только первого блока, без else.

  TParserParsedStateEnumerator = class;
  TParserErrorEnumerator = class;
  //TLexemeNodes = class;

  {TLexemeNode = class(TObject)
  private
    FParent: TLexemeNode;
    FNodeType: TLexemeType;
    FChildren: TLexemeNodes;
  public
    constructor Create(AParent: TLexemeNode; ANodeType: TLexemeType);

    function GetFirstChild: TLexemeNode;
    function GetLastChild: TLexemeNode;
    function GetNextTraversal: TLexemeNode;
    function GetPrevTraversal: TLexemeNode;
    function GetNextSibling: TLexemeNode;
    function GetPrevSibling: TLexemeNode;

    property Parent: TLexemeNode read FParent;
  end;

  TLexemeNodes = class(TObject)
  private
    FFirst: TLexemeNode;
    FLast: TLexemeNode;
  public
    function GetFirst: TLexemeNode;
    function GetLast: TLexemeNode;
  end; }

  TPasParser = class(TObject)
  private
    FLexer: TPasLexer;
    FDataString: string;
    FParsedStates: TLexerStateArray;
    FRootLexemeNode: TBaseLexemeNode;
    FErrorOutputArray: TArray<TParseErrorItem>;
    FParsedStateEnumerator: TParserParsedStateEnumerator;
    FErrorEnumerator: TParserErrorEnumerator;

    FParsedStatesCount: Integer;  // +++ возможно не нужны некоторые поля
    FParsedStatesSize: Integer;

    procedure InternalParse;

    function GetParsedStateCount: Integer;
    function GetParsedStateItem(AIndex: Integer): TPasLexerMinimalState;

    function GetErrorCount: Integer;
    function GetErrorItem(AIndex: Integer): TParseErrorItem;

    procedure SetParsedSize(ANewSize: Integer);
  public
    constructor Create;
    destructor Destroy; override;

    class function TryGetEncodingByPreamble(ABuffer: Pointer; ASize: Integer): TEncoding; overload;
    class function TryGetEncodingByPreamble(AStream: TStream): TEncoding; overload;
    class function GetFileDataString(const AFileName: string): string;

    function ParseFile(const AFileName: string): Boolean;
    function ParseString(const ADataString: string): Boolean;
    procedure Clear;

    property DataString: string read FDataString;
    property ParsedStateCount: Integer read GetParsedStateCount;
    property ParsedStateItem[AIndex: Integer]: TPasLexerMinimalState read GetParsedStateItem;
    property ErrorCount: Integer read GetErrorCount;
    property ErrorItem[AIndex: Integer]: TParseErrorItem read GetErrorItem;
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
  // +++ убрать лишние юниты
  uPasExceptions;

{ TLexemeNode }
 {
constructor TLexemeNode.Create(AParent: TLexemeNode; ANodeType: TLexemeType);
begin
  inherited Create;

  FParent := AParent;
  FNodeType := ANodeType;
end;

function TLexemeNode.GetFirstChild: TLexemeNode;
begin

end;

function TLexemeNode.GetLastChild: TLexemeNode;
begin

end;

function TLexemeNode.GetNextTraversal: TLexemeNode;
begin

end;

function TLexemeNode.GetPrevTraversal: TLexemeNode;
begin

end;

function TLexemeNode.GetNextSibling: TLexemeNode;
begin

end;

function TLexemeNode.GetPrevSibling: TLexemeNode;
begin

end;
       }
{ TLexemeNodes }
   {
function TLexemeNodes.GetFirst: TLexemeNode;
begin

end;

function TLexemeNodes.GetLast: TLexemeNode;
begin

end;  }

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

procedure TPasParser.InternalParse;
var
  WatchedDirectiveIndex, InitialTokensCount, InitialTokensSize, CurrentOutputIndex, LastCRLFIndex, DirStateLen, i: Integer;
  AddToken, WasSignificantToken, WasNotAddedToken: Boolean;
  InitialTokens: TLexerStateArray;
  AddTokenFlags: TArray<Boolean>;
begin
  WatchedDirectiveIndex := -1;
  InitialTokensCount := 0;

  InitialTokensSize := Trunc(Length(FDataString) / SIZE_TOKEN_RATIO);
  SetLength(InitialTokens, InitialTokensSize);
  SetLength(AddTokenFlags, InitialTokensSize);

  FLexer.SetData(FDataString);
  if FLexer.TokenID <> tkEOF then
    repeat
      DirStateLen := Length(FLexer.LexerState.IfDirectiveStateArray);

      if WatchedDirectiveIndex = -1 then
      begin
        if DirStateLen = 0 then
          AddToken := True
        else
        begin
          if FLexer.LexerState.IfDirectiveStateArray[High(FLexer.LexerState.IfDirectiveStateArray)] = idsIf then
          begin
            WatchedDirectiveIndex := High(FLexer.LexerState.IfDirectiveStateArray);
            AddToken := True;
          end
          else
            AddToken := False;
        end;
      end
      else
      begin
        if DirStateLen <= WatchedDirectiveIndex then
        begin
          Dec(WatchedDirectiveIndex);
          if WatchedDirectiveIndex = -1 then
            AddToken := True
          else
            AddToken := FLexer.LexerState.IfDirectiveStateArray[WatchedDirectiveIndex] = idsIf;
        end
        else
        begin
          if DirStateLen = 0 then
            AddToken := True
          else
          begin
            if (DirStateLen - 2) = WatchedDirectiveIndex then
            begin
              if (FLexer.LexerState.IfDirectiveStateArray[WatchedDirectiveIndex] = idsIf)
                  and (FLexer.LexerState.IfDirectiveStateArray[High(FLexer.LexerState.IfDirectiveStateArray)] = idsIf)
              then
              begin
                Inc(WatchedDirectiveIndex);
                AddToken := True;
              end
              else
                AddToken := False;
            end
            else
              AddToken := FLexer.LexerState.IfDirectiveStateArray[WatchedDirectiveIndex] = idsIf;
          end;
        end;
      end;

      if AddToken and (FLexer.TokenID = tkCompilerDirective) then
        AddToken := False;

      InitialTokens[InitialTokensCount].FillFromLexer(FLexer);
      AddTokenFlags[InitialTokensCount] := AddToken;

      Inc(InitialTokensCount);
      if InitialTokensCount >= InitialTokensSize then
      begin
        InitialTokensSize := InitialTokensSize + TOKEN_INCREASE_COUNT;
        SetLength(InitialTokens, InitialTokensSize);
        SetLength(AddTokenFlags, InitialTokensSize);
      end;
    until not FLexer.NextToken;

  // Remove branching compiler directives
  if InitialTokensCount = 0 then
    SetParsedSize(0)
  else
  begin
    SetParsedSize(InitialTokensCount);

    CurrentOutputIndex := 0;
    LastCRLFIndex := 0;
    WasSignificantToken := False;
    WasNotAddedToken := False;
    for i := Low(InitialTokens) to High(InitialTokens) do
    begin
      if AddTokenFlags[i] then
      begin
        FParsedStates[CurrentOutputIndex] := InitialTokens[i];
        Inc(CurrentOutputIndex);
      end
      else
        WasNotAddedToken := True;

      if InitialTokens[i].CurrentToken in [tkCRLF, tkCRLFComment] then
      begin
        if not WasSignificantToken and WasNotAddedToken then
          CurrentOutputIndex := LastCRLFIndex;

        LastCRLFIndex := CurrentOutputIndex;
        WasSignificantToken := False;
        WasNotAddedToken := False;
      end
      else if not(InitialTokens[i].CurrentToken in UNSIGNIFICANT_TOKENS)
          and AddTokenFlags[i]
      then
        WasSignificantToken := True;
    end;

    FParsedStatesCount := CurrentOutputIndex;
    SetParsedSize(FParsedStatesCount);
  end;

  // Creating lexeme tree
  FRootLexemeNode := TRootLexemeNode.Create(nil, @FParsedStates, 0, FParsedStatesCount);
  try
    FRootLexemeNode.ParseItself;
  except
    on E: EPasGrammarParserException do
      raise Exception.CreateFmt(E.Message + '(Line: %d; Pos: %d; Token: %s)', [E.LineNumber, E.LineCharIndex,
          TOKEN_NAMES[E.CurrentToken]]);
  end;
end;

function TPasParser.GetParsedStateCount: Integer;
begin
  Result := Length(FParsedStates);
end;

function TPasParser.GetParsedStateItem(AIndex: Integer): TPasLexerMinimalState;
begin
  if (AIndex < 0) or (AIndex >= Length(FParsedStates)) then
    raise EPasParserException.CreateFmt(EMESSAGE_GET_INDEX_OUT_OF_RANGE, [AIndex], Self);

  Result := FParsedStates[AIndex];
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

procedure TPasParser.SetParsedSize(ANewSize: Integer);
begin
  if FParsedStatesSize <> ANewSize then
  begin
    FParsedStatesSize := ANewSize;
    SetLength(FParsedStates, FParsedStatesSize);
  end;
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
    raise Exception.CreateFmt('File does not exists (%s)', [AFileName]);

  MemStream := TMemoryStream.Create;
  try
    FileStream := TFileStream.Create(AFileName, fmOpenReadWrite or fmShareDenyNone);
    try
      MemStream.LoadFromStream(FileStream);
      DataStartPosition := MemStream.Seek(0, soBeginning);
    finally
      FileStream.Free;
    end;

    DataEncoding := TryGetEncodingByPreamble(MemStream);

    if not Assigned(DataEncoding) then
    begin
      BufferSize := Min(MAX_BUFFER_SIZE, MemStream.Size);
      SetLength(Buffer, BufferSize);
      MemStream.ReadBuffer(Buffer, Length(Buffer));

      Mask := IS_TEXT_UNICODE_UNICODE_MASK or IS_TEXT_UNICODE_REVERSE_MASK
          or IS_TEXT_UNICODE_NOT_UNICODE_MASK or IS_TEXT_UNICODE_NOT_ASCII_MASK;
      IsTextUnicode(Buffer, Length(Buffer), @Mask);

      if (BufferSize mod 2 = 0) and (Mask and IS_TEXT_UNICODE_UNICODE_MASK <> 0) then
        DataEncoding := TEncoding.Unicode
      else if (BufferSize mod 2 = 0) and (Mask and IS_TEXT_UNICODE_REVERSE_MASK <> 0) then
        DataEncoding := TEncoding.BigEndianUnicode
      else
        DataEncoding := TEncoding.UTF8;
    end
    else
      DataStartPosition := MemStream.Position;

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
      raise Exception.Create('Failed to read file');
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

  InternalParse;

  Result := True;
end;

procedure TPasParser.Clear;
begin
  FLexer.Reset;
  FDataString := EmptyStr;
  FParsedStatesCount := 0;
  SetParsedSize(0);
  SetLength(FErrorOutputArray, 0);
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
