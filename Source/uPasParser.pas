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
  uPasLexer, uPasLexerTypes;

type
  TPasParser = class(TObject)
  public
    class function TryGetEncodingByPreamble(ABuffer: Pointer; ASize: Integer): TEncoding; overload;
    class function TryGetEncodingByPreamble(AStream: TStream): TEncoding; overload;
    class function GetFileDataString(const AFileName: string): string;
  end;

implementation

{ TPasParser }

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

end.
