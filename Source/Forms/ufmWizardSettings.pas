// Copy of Delphi-IDE-Code-Expert (DICE) Source/Forms/ufmWizardSettings.pas, commit 5c8be6b, without the form icon
// (it needs the DICE bitmap). Not moved to DICE with the CodeStyle feature: the feature is built on its API.
unit ufmWizardSettings;

interface

uses
  Vcl.Forms, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Controls, System.Classes, Vcl.StdCtrls,
  System.SysUtils, System.Contnrs,
  uWizardConsts, ufrBaseSettings;

type
  TfmWizardSettings = class(TForm)
    pnButtons: TPanel;
    btnOK: TButton;
    pnMain: TPanel;
    tvSections: TTreeView;
    pnFrameSettingsContainer: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tvSectionsChange(Sender: TObject; Node: TTreeNode);
    procedure FormShow(Sender: TObject);
  private
    FFrameList: TObjectList;
    FCurrentVisibleFrame: TfrBaseSettings;

    function CreateNewSection(const ANewSectionName: string): TTreeNode;
    procedure AddControlToSection(TreeNode: TTreeNode; AControl: TControl);
  public
    procedure InitSectionsTree;
    procedure AddSettingsControl(const ASectionName: string; AControl: TControl);
  end;

implementation

{$R *.dfm}

function TfmWizardSettings.CreateNewSection(const ANewSectionName: string): TTreeNode;
var
  FrameIndex: Integer;
  NewFrame: TfrBaseSettings;
begin
  try
    NewFrame := TfrBaseSettings.Create(pnFrameSettingsContainer);
    NewFrame.Visible := False;
    NewFrame.Name := 'Frame' + IntToStr(FFrameList.Count);
    NewFrame.FrameCaption := ANewSectionName;
    NewFrame.Parent := pnFrameSettingsContainer;
    NewFrame.Align := alClient;
    // Need to be here, because frame dimensions doesn't change until frame is visible
    NewFrame.Top := 0;
    NewFrame.Left := 0;
    NewFrame.Width := pnFrameSettingsContainer.Width;
    NewFrame.Height := pnFrameSettingsContainer.Height;
    FrameIndex := FFrameList.Add(NewFrame);
  except
    on E: Exception do
      raise Exception.Create('Error creating settings section frame, message: ' + E.Message);
  end;

  Result := tvSections.Items.AddNode(nil, nil, ANewSectionName, FFrameList.Items[FrameIndex], naAdd);
end;

procedure TfmWizardSettings.AddControlToSection(TreeNode: TTreeNode; AControl: TControl);
var
  SectionFrame: TfrBaseSettings;
  NewNode: TTreeNode;
begin
  SectionFrame := TfrBaseSettings(TreeNode.Data);

  if not SectionFrame.TryAddControl(AControl) then
  begin
    NewNode := CreateNewSection(TreeNode.Text + '_');
    AddControlToSection(NewNode, AControl);
  end;
end;

procedure TfmWizardSettings.InitSectionsTree;
begin
  if tvSections.Items.Count > 0 then
    tvSections.Select(tvSections.Items.GetFirstNode, [ssLeft]);
end;

procedure TfmWizardSettings.AddSettingsControl(const ASectionName: string; AControl: TControl);
var
  Node: TTreeNode;
  i: Integer;
begin
  Node := nil;
  for i := 0 to tvSections.Items.Count - 1 do
    if SameText(ASectionName, tvSections.Items[i].Text) then
    begin
      Node := tvSections.Items[i];
      Break;
    end;

  if not Assigned(Node) then
    Node := CreateNewSection(ASectionName);

  AddControlToSection(Node, AControl);
end;

procedure TfmWizardSettings.FormCreate(Sender: TObject);
begin
  FFrameList := TObjectList.Create(False);
  Caption := WIZARD_SETTINGS_MENU_ITEM_CAPTION;
end;

procedure TfmWizardSettings.FormDestroy(Sender: TObject);
begin
  tvSections.Items.Clear;
end;

procedure TfmWizardSettings.FormShow(Sender: TObject);
begin
  FocusControl(tvSections);
end;

procedure TfmWizardSettings.tvSectionsChange(Sender: TObject; Node: TTreeNode);
begin
  if Assigned(FCurrentVisibleFrame) then
  begin
    FCurrentVisibleFrame.Visible := False;
    FCurrentVisibleFrame := nil;
  end;

  FCurrentVisibleFrame := TfrBaseSettings(Node.Data);
  FCurrentVisibleFrame.Visible := True;
end;

end.
