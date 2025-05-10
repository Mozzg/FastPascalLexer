unit BeginEndCountTestUnit1;

interface
{$HINTS OFF}

type
  ClassTest1 = class;
  ICommonLink_AI = interface;
  ICommonLink_AIDisp = dispinterface;
  ITestInterface = interface;

  ClassTest1 = class(TObject)
  private
    FPrivateIndex: Integer;
  public
    procedure MYTest;
  end;
  
  TOrdExHTTP = class abstract
  public
    class function Authenticate(): boolean; virtual; abstract;
  end;
  
  TClassVarTest = class
    class var FInt: Integer;
  end;

  StrHelper = class helper for TObject
    function MyName: string;
  end;

  TClassNestedType = class
  type
    TNestTest = record
      F1: Integer;
      F2: Double;
    end;
  end;

  TClassNestedConst = class
  const
    CLASS_CONST = 321;
  end;

  TObjectClass = object
  private
    FObjField: Integer;
  end;

  TAnotherObjectClass = object
    const
      OBJECT_CONST = 123;
  end;

  TInheritedObject = object(TObjectClass)
  end;

  ICommonLink_AI = interface(IDispatch)
    ['{A4D78B9C-BA96-4D5E-9074-25959632A044}']
    procedure Done; safecall;
    procedure Progress(RecNo: Integer; RecCount: Integer; var Continue: WordBool); safecall;
    procedure Timer10; safecall;
  end;

  ICommonLink_AIDisp = dispinterface
    ['{A4D78B9C-BA96-4D5E-9074-25959632A044}']
    procedure Done; dispid 1;
    procedure Progress(RecNo: Integer; RecCount: Integer; var Continue: WordBool); dispid 2;
    procedure Timer10; dispid 201;
  end;

  ITestInterface = interface
    procedure MyTest;
  end;
{$HINTS ON}

implementation

{ ClassTest1 }

procedure ClassTest1.MYTest;
var
  Index: Integer;

  procedure InnerProc;
  begin
    Index := Index + 1;
  end;

begin
  Index := 0;
  InnerProc;
  Index := Index * 2;
  FPrivateIndex := Index;
end;

{ StrHelper }

function StrHelper.MyName: string;
begin
  Result := Copy(ClassName, 1, 2);
end;

end.
