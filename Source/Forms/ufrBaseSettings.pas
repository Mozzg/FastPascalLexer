// Copy of Delphi-IDE-Code-Expert (DICE) Source/Forms/ufrBaseSettings.pas, commit 5c8be6b, without changes: the CodeStyle feature
// is built on its API. Not moved to DICE with the CodeStyle feature.
unit ufrBaseSettings;

interface

uses
  Vcl.Forms, Vcl.Controls;

type
  TfrBaseSettings = class(TFrame)
  private
    FFrameCaption: string;
    FLastControlBottom: Integer;
  protected const
    CONTROL_MARGIN = 6;
    LEFT_CONTROL_MARGIN = 10;
  public
    function TryAddControl(AControl: TControl): Boolean;

    property FrameCaption: string read FFrameCaption write FFrameCaption;
  end;

implementation

{$R *.dfm}

{ TfrBaseSettings }

function TfrBaseSettings.TryAddControl(AControl: TControl): Boolean;
begin
  if (FLastControlBottom + AControl.Height + CONTROL_MARGIN) > Self.Height then
    Exit(False);

  AControl.Parent := Self;
  AControl.Left := LEFT_CONTROL_MARGIN;
  AControl.Top := FLastControlBottom + CONTROL_MARGIN;
  AControl.Width := Self.ClientWidth - 2 * LEFT_CONTROL_MARGIN;
  FLastControlBottom := FLastControlBottom + AControl.Height + CONTROL_MARGIN;
  Result := True;
end;

end.
