unit BeginEndCountTestUnit2;

interface
{$HINTS OFF}

function GetNumber: Integer;

(*****)
type
  TTestNormalRec = record
    Data1: string;
    Data2: Integer;
  end;

  TTestCaseRec = record
    Data1: string;
    case Integer of
      0: (Left, Top, Right, Bottom: Longint);
      1: (TopLeft, BottomRight: Int64);
  end;

  TTestRecHelper = record helper for string
    function GetByteCount: Integer;
  end;
  
  TVTVirtualNodeEnumerator = {$if CompilerVersion >= 18}class{$else}record{$ifend}
  private
    FNode: Pointer;
  public
    property Current: Pointer read FNode;
  end;

  ICommonLink_AI = {$if CompilerVersion >= 18}interface{$else}dispinterface{$ifend}
    ['{E0EDADCC-BE9C-4459-993A-45729B52D47F}']
    procedure Done; safecall;
    procedure Progress(RecNo: Integer; RecCount: Integer; var Continue: WordBool); safecall;
    procedure Timer10; safecall;
  end;
  
  TSimpleFieldClass = class
    FClassField: Integer;
  end;
  
  TStrictClass = class
  strict private
    FClassField: Integer;
  end;

  TVarFieldClass = class
  var
    FVarField: Integer;
  end;

  TRecTest = record
    type
      TTest12114 = Integer;
  end;

  TClassProcClass = class
    class procedure AbstractProc; virtual; abstract;
  end;
  
  TRegularProcClass = class
    procedure AnotherAbstractProc; virtual; abstract;
  end;

  TInnerTypeClass = class
  type
    TInnerClass = class
    private
      FInnerField: Integer;
    end;
  public
    procedure InnerAbstractProc; virtual; abstract;
  end;
{$HINTS ON}

implementation

{ }

function GetNumber: Integer;
begin
  Result := Random(10);
end;

procedure Log(const AMessage: string);
begin

end;

{ TTestRecHelper }

function TTestRecHelper.GetByteCount: Integer;
begin
  Result := SizeOf(Char) * Length(Self);
end;

{$IFDEF DEBUG}
procedure TestLog(const AMess: string);
begin
  if AMess = '' then
    Exit
  {$IFNDEF DEBUG2}
  ;
  {$ELSE}
  else
    Log('123' + {$IFDEF DEBUG3} + ' '{$ENDIF});
  {$ENDIF}

  Log({$IFDEF DEBUG3}'Test'{$ELSE}''{$ENDIF});
end;
{$ENDIF}

{$IFDEF DEBUG}
initialization
finalization
{$ELSE}
finalization
{$ENDIF}

end.
