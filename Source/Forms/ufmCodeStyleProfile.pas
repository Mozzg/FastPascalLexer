// Dialog of the code style profile: the rules of the catalog under bold category rows, the level and the options of
// the selected rule, loading and saving profile files. Edits a copy of the profile; OK assigns it back.
unit ufmCodeStyleProfile;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Themes,
  uCodeStyleConsts, uCodeStyleProfileCatalog, uCodeStyleProfile,
  // After Vcl.ComCtrls: its interposer TListView gives lvRules the fixed style hook
  uCodeStyleRuleListView;

type
  // Which rules the list shows
  TCodeStyleRuleFilter = (
    crfAll,
    crfEnabled,
    crfDisabled,
    crfChanged
  );

  TfmCodeStyleProfile = class(TForm)
    pnTop: TPanel;
    lblFilter: TLabel;
    edFilter: TEdit;
    cbShow: TComboBox;
    pnBottom: TPanel;
    btnLoad: TButton;
    btnSave: TButton;
    btnReset: TButton;
    btnSwitchOff: TButton;
    btnOK: TButton;
    btnCancel: TButton;
    lvRules: TListView;
    spRules: TSplitter;
    pnDetails: TPanel;
    lblRuleCaption: TLabel;
    lblRuleSubtitle: TLabel;
    lblRuleDescription: TLabel;
    pnLevel: TPanel;
    lblLevel: TLabel;
    cbLevel: TComboBox;
    sbOptions: TScrollBox;
    dlgOpen: TOpenDialog;
    dlgSave: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure edFilterChange(Sender: TObject);
    procedure cbShowChange(Sender: TObject);
    procedure lvRulesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure lvRulesCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
        var DefaultDraw: Boolean);
    procedure cbLevelChange(Sender: TObject);
    procedure btnLoadClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnResetClick(Sender: TObject);
    procedure btnSwitchOffClick(Sender: TObject);
  private const
    OPTION_MARGIN = 8;
    OPTION_SPACING = 6;
    LABEL_SPACING = 3;
    INTEGER_EDIT_WIDTH = 80;
    TEXT_LIST_HEIGHT = 96;
    QUANTITY_MODE_WIDTH = 110;
  private
    // Copy of the edited profile, assigned back on OK
    FProfile: TCodeStyleProfile;
    // Rule shown in the details, nil when no rule is selected
    FCurrentRule: TCodeStyleProfileRule;
    // Panel in sbOptions with the controls of the options of FCurrentRule; nil when no rule is shown. Every rule gets
    // a new panel, built while hidden and shown at once, so the controls do not flicker while they are created
    FOptionsPanel: TPanel;
    // Top of the next option control in FOptionsPanel
    FNextOptionTop: Integer;
    // True while FillRuleList changes the items, the selection events are ignored then
    FFillingList: Boolean;

    function IsRuleShown(ARule: TCodeStyleProfileRule): Boolean;
    function GetLevelText(ARule: TCodeStyleProfileRule): string;
    // Line under the caption of a rule: its category, and whether it is changed
    function GetRuleSubtitle(ARule: TCodeStyleProfileRule): string;
    procedure UpdateRuleItem(AItem: TListItem);
    procedure UpdateCurrentRuleItem;
    // Fills the list with the rules that pass the filter, every category under a row of its own (an item without
    // Data); keeps the selected rule when it is still shown
    procedure FillRuleList;
    // Creates the hidden panel in sbOptions for the controls of the options of a rule
    function CreateOptionsPanel: TPanel;
    // Places a control of the option below the previous ones
    procedure PlaceOptionControl(AControl: TControl; AWidth: Integer);
    procedure AddOptionLabel(AOption: TCodeStyleProfileOption);
    // A cokQuantity option: the mode and, on the same line, the count with an up-down
    procedure AddQuantityControls(AOptionIndex: Integer; AOption: TCodeStyleProfileOption);
    procedure AddOptionControl(AOptionIndex: Integer; AOption: TCodeStyleProfileOption);
    // The control of the class AControlClass of the option with the index AOptionIndex, nil if there is none
    function FindOptionControl(AOptionIndex: Integer; AControlClass: TControlClass): TControl;
    procedure ShowRule(ARule: TCodeStyleProfileRule);
    // Shows the category of the row AItem and the numbers of its rules in the list
    procedure ShowCategory(AItem: TListItem);
    function ConfirmAction(const AQuestion: string): Boolean;
    procedure ShowError(const AMessage: string);

    procedure BooleanOptionClick(Sender: TObject);
    procedure IntegerOptionChange(Sender: TObject);
    procedure IntegerOptionExit(Sender: TObject);
    procedure TextOptionChange(Sender: TObject);
    procedure TextListOptionChange(Sender: TObject);
    procedure ChoiceOptionChange(Sender: TObject);
    procedure QuantityModeChange(Sender: TObject);
    procedure QuantityCountChange(Sender: TObject);
    procedure QuantityCountExit(Sender: TObject);
  public
    // Shows the dialog for AProfile; on OK assigns the changes to AProfile and returns True
    function Execute(AProfile: TCodeStyleProfile): Boolean;
  end;

implementation

{$R *.dfm}

procedure TfmCodeStyleProfile.FormCreate(Sender: TObject);
var
  Level: TCodeStyleLevel;
begin
  FProfile := TCodeStyleProfile.Create;
  Caption := PROFILE_FORM_CAPTION;

  // In the order of TCodeStyleRuleFilter
  cbShow.Items.Add(PROFILE_FILTER_ALL);
  cbShow.Items.Add(PROFILE_FILTER_ENABLED);
  cbShow.Items.Add(PROFILE_FILTER_DISABLED);
  cbShow.Items.Add(PROFILE_FILTER_CHANGED);
  cbShow.ItemIndex := Ord(crfAll);

  for Level := Low(TCodeStyleLevel) to High(TCodeStyleLevel) do
    cbLevel.Items.Add(CODE_STYLE_LEVEL_NAMES[Level]);
end;

procedure TfmCodeStyleProfile.FormDestroy(Sender: TObject);
begin
  // The option controls refer to the rules of the profile
  FCurrentRule := nil;
  FreeAndNil(FProfile);
end;

procedure TfmCodeStyleProfile.edFilterChange(Sender: TObject);
begin
  FillRuleList;
end;

procedure TfmCodeStyleProfile.cbShowChange(Sender: TObject);
begin
  FillRuleList;
end;

procedure TfmCodeStyleProfile.lvRulesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if FFillingList then
    Exit;

  if not Selected then
  begin
    if not Assigned(lvRules.Selected) then
      ShowRule(nil);
  end
  else if Assigned(Item.Data) then
    ShowRule(TCodeStyleProfileRule(Item.Data))
  else
    ShowCategory(Item);
end;

procedure TfmCodeStyleProfile.lvRulesCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
    var DefaultDraw: Boolean);
var
  Styles: TCustomStyleServices;
begin
  // Category rows instead of native group headers: those ignore the dark theme of the IDE
  if Assigned(Item.Data) then
    Exit;

  // A changed font makes the list view apply the colors of the canvas, so they are set from the active style
  // (the IDE theme); without a style these are the system colors
  Styles := StyleServices(Sender);
  Sender.Canvas.Font.Style := [fsBold];
  // Not cdsSelected: the list view in report mode sets it for rows that are not selected
  if Item.Selected then
  begin
    Sender.Canvas.Font.Color := Styles.GetStyleFontColor(sfListItemTextSelected);
    Sender.Canvas.Brush.Color := Styles.GetStyleColor(scListView);
  end
  else
  begin
    Sender.Canvas.Font.Color := Styles.GetStyleFontColor(sfListItemTextNormal);
    Sender.Canvas.Brush.Color := Styles.GetStyleColor(scListView);
  end;
end;

procedure TfmCodeStyleProfile.cbLevelChange(Sender: TObject);
begin
  if (not Assigned(FCurrentRule)) or (cbLevel.ItemIndex < 0) then
    Exit;

  FCurrentRule.Level := TCodeStyleLevel(cbLevel.ItemIndex);
  UpdateCurrentRuleItem;
end;

procedure TfmCodeStyleProfile.btnLoadClick(Sender: TObject);
var
  LoadedProfile: TCodeStyleProfile;
begin
  if not dlgOpen.Execute(Handle) then
    Exit;

  // Loaded into a copy, so a failed load leaves the edited profile as it is
  LoadedProfile := TCodeStyleProfile.Create;
  try
    try
      LoadedProfile.LoadFromFile(dlgOpen.FileName);
      FProfile.Assign(LoadedProfile);
    except
      on E: Exception do
        ShowError(Format(PROFILE_LOAD_FAILED, [dlgOpen.FileName, E.Message]));
    end;
  finally
    LoadedProfile.Free;
  end;
  FillRuleList;
end;

procedure TfmCodeStyleProfile.btnSaveClick(Sender: TObject);
begin
  if not dlgSave.Execute(Handle) then
    Exit;

  try
    FProfile.SaveToFile(dlgSave.FileName);
  except
    on E: Exception do
      ShowError(Format(PROFILE_SAVE_FAILED, [dlgSave.FileName, E.Message]));
  end;
end;

procedure TfmCodeStyleProfile.btnResetClick(Sender: TObject);
begin
  if not ConfirmAction(PROFILE_CONFIRM_RESET) then
    Exit;

  FProfile.Reset;
  FillRuleList;
end;

procedure TfmCodeStyleProfile.btnSwitchOffClick(Sender: TObject);
begin
  if not ConfirmAction(PROFILE_CONFIRM_SWITCH_OFF) then
    Exit;

  FProfile.SwitchOffAll;
  FillRuleList;
end;

function TfmCodeStyleProfile.IsRuleShown(ARule: TCodeStyleProfileRule): Boolean;
var
  FilterText: string;
begin
  case TCodeStyleRuleFilter(cbShow.ItemIndex) of
    crfEnabled: Result := (not ARule.Info.WithoutLevel) and (ARule.Level <> cslOff);
    crfDisabled: Result := (not ARule.Info.WithoutLevel) and (ARule.Level = cslOff);
    crfChanged: Result := not ARule.IsDefault;
  else
    Result := True;
  end;
  if not Result then
    Exit;

  FilterText := Trim(edFilter.Text);
  Result := (FilterText = '') or ARule.Info.Caption.ToLower.Contains(FilterText.ToLower)
      or ARule.Info.Description.ToLower.Contains(FilterText.ToLower) or SameText(ARule.Id, FilterText);
end;

function TfmCodeStyleProfile.GetLevelText(ARule: TCodeStyleProfileRule): string;
begin
  if ARule.Info.WithoutLevel then
    Result := ''
  else
    Result := CODE_STYLE_LEVEL_NAMES[ARule.Level];
  if not ARule.IsDefault then
    Result := Format(PROFILE_LEVEL_CHANGED, [Result]);
end;

function TfmCodeStyleProfile.GetRuleSubtitle(ARule: TCodeStyleProfileRule): string;
begin
  Result := CODE_STYLE_CATEGORIES[ARule.CategoryIndex].Caption;
  if not ARule.IsDefault then
    Result := Format(PROFILE_RULE_CHANGED, [Result]);
end;

procedure TfmCodeStyleProfile.UpdateRuleItem(AItem: TListItem);
var
  Rule: TCodeStyleProfileRule;
begin
  Rule := TCodeStyleProfileRule(AItem.Data);
  AItem.Caption := Rule.Info.Caption;
  AItem.SubItems.Clear;
  AItem.SubItems.Add(GetLevelText(Rule));
end;

procedure TfmCodeStyleProfile.UpdateCurrentRuleItem;
begin
  if Assigned(lvRules.Selected) and Assigned(lvRules.Selected.Data) then
    UpdateRuleItem(lvRules.Selected);
  if Assigned(FCurrentRule) then
    lblRuleSubtitle.Caption := GetRuleSubtitle(FCurrentRule);
end;

procedure TfmCodeStyleProfile.FillRuleList;
var
  SelectedRule: TCodeStyleProfileRule;
  Item, SelectedItem: TListItem;
  LastCategoryIndex, i: Integer;
begin
  SelectedRule := FCurrentRule;
  SelectedItem := nil;
  FFillingList := True;
  try
    lvRules.Items.BeginUpdate;
    try
      lvRules.Items.Clear;
      // The rules of a category follow each other in the catalog
      LastCategoryIndex := -1;
      for i := 0 to FProfile.RuleCount - 1 do
        if IsRuleShown(FProfile[i]) then
        begin
          if FProfile[i].CategoryIndex <> LastCategoryIndex then
          begin
            LastCategoryIndex := FProfile[i].CategoryIndex;
            lvRules.Items.Add.Caption := CODE_STYLE_CATEGORIES[LastCategoryIndex].Caption;
          end;
          Item := lvRules.Items.Add;
          Item.Data := FProfile[i];
          UpdateRuleItem(Item);
          if FProfile[i] = SelectedRule then
            SelectedItem := Item;
        end;
    finally
      lvRules.Items.EndUpdate;
    end;

    // Otherwise the first rule, not the row of its category
    if (not Assigned(SelectedItem)) and (lvRules.Items.Count > 1) then
      SelectedItem := lvRules.Items[1];
    if Assigned(SelectedItem) then
    begin
      lvRules.Selected := SelectedItem;
      SelectedItem.MakeVisible(False);
    end;
  finally
    FFillingList := False;
  end;

  // Also when the selected rule stays the same: its values may have changed (loading, reset)
  if Assigned(SelectedItem) then
    ShowRule(TCodeStyleProfileRule(SelectedItem.Data))
  else
    ShowRule(nil);
end;

function TfmCodeStyleProfile.CreateOptionsPanel: TPanel;
begin
  // sbOptions owns the panel, the panel owns the controls of the options
  Result := TPanel.Create(sbOptions);
  Result.Visible := False;
  Result.BevelOuter := bvNone;
  Result.ShowCaption := False;
  Result.ParentColor := True;
  Result.ParentBackground := True;
  Result.Parent := sbOptions;
  // A hidden control is not aligned, so the width for the controls is set here; alTop keeps it when shown
  Result.SetBounds(0, 0, sbOptions.ClientWidth, sbOptions.ClientHeight);
  Result.Align := alTop;
end;

procedure TfmCodeStyleProfile.PlaceOptionControl(AControl: TControl; AWidth: Integer);
begin
  AControl.Parent := FOptionsPanel;
  AControl.Left := OPTION_MARGIN;
  AControl.Top := FNextOptionTop;
  if AWidth > 0 then
    AControl.Width := AWidth
  else
  begin
    AControl.Width := FOptionsPanel.ClientWidth - 2 * OPTION_MARGIN;
    AControl.Anchors := [akLeft, akTop, akRight];
  end;
  FNextOptionTop := FNextOptionTop + AControl.Height;
end;

procedure TfmCodeStyleProfile.AddOptionLabel(AOption: TCodeStyleProfileOption);
var
  OptionLabel: TLabel;
begin
  OptionLabel := TLabel.Create(FOptionsPanel);
  OptionLabel.Caption := Format(PROFILE_OPTION_CAPTION, [AOption.Info.Caption]);
  OptionLabel.Hint := AOption.Info.Hint;
  OptionLabel.ShowHint := True;
  PlaceOptionControl(OptionLabel, 0);
  FNextOptionTop := FNextOptionTop + LABEL_SPACING;
end;

procedure TfmCodeStyleProfile.AddQuantityControls(AOptionIndex: Integer; AOption: TCodeStyleProfileOption);
var
  ModeComboBox: TComboBox;
  CountEdit: TEdit;
  CountUpDown: TUpDown;
  Mode: TCodeStyleQuantityMode;
  Count: Integer;
begin
  AddOptionLabel(AOption);
  ModeComboBox := TComboBox.Create(FOptionsPanel);
  ModeComboBox.Style := csDropDownList;
  ModeComboBox.Tag := AOptionIndex;
  ModeComboBox.Hint := AOption.Info.Hint;
  ModeComboBox.ShowHint := True;
  PlaceOptionControl(ModeComboBox, QUANTITY_MODE_WIDTH);
  for Mode := Low(TCodeStyleQuantityMode) to High(TCodeStyleQuantityMode) do
    ModeComboBox.Items.Add(CODE_STYLE_QUANTITY_CAPTIONS[Mode]);
  ModeComboBox.ItemIndex := Ord(AOption.QuantityMode);
  ModeComboBox.OnChange := QuantityModeChange;

  // The count is on the line of the mode; for Any it shows the minimum and is disabled
  Count := AOption.QuantityCount;
  if Count < AOption.Info.MinValue then
    Count := AOption.Info.MinValue;
  CountEdit := TEdit.Create(FOptionsPanel);
  CountEdit.Parent := FOptionsPanel;
  CountEdit.SetBounds(ModeComboBox.Left + ModeComboBox.Width + OPTION_SPACING, ModeComboBox.Top, INTEGER_EDIT_WIDTH,
      CountEdit.Height);
  CountEdit.NumbersOnly := True;
  CountEdit.Tag := AOptionIndex;
  CountUpDown := TUpDown.Create(FOptionsPanel);
  CountUpDown.Parent := FOptionsPanel;
  CountUpDown.Tag := AOptionIndex;
  CountUpDown.Min := AOption.Info.MinValue;
  CountUpDown.Max := AOption.Info.MaxValue;
  CountUpDown.Thousands := False;
  CountUpDown.Position := Count;
  CountUpDown.Associate := CountEdit;
  CountEdit.Text := IntToStr(Count);
  CountEdit.Enabled := AOption.QuantityMode <> cqmAny;
  CountUpDown.Enabled := CountEdit.Enabled;
  CountEdit.OnChange := QuantityCountChange;
  CountEdit.OnExit := QuantityCountExit;
end;

procedure TfmCodeStyleProfile.AddOptionControl(AOptionIndex: Integer; AOption: TCodeStyleProfileOption);
var
  OptionCheckBox: TCheckBox;
  OptionEdit: TEdit;
  OptionUpDown: TUpDown;
  OptionMemo: TMemo;
  OptionComboBox: TComboBox;
  i: Integer;
begin
  // The Tag of a control is the index of its option in FCurrentRule
  case AOption.Info.Kind of
    cokBoolean:
    begin
      OptionCheckBox := TCheckBox.Create(FOptionsPanel);
      OptionCheckBox.Caption := AOption.Info.Caption;
      OptionCheckBox.Checked := AOption.AsBoolean;
      OptionCheckBox.Tag := AOptionIndex;
      OptionCheckBox.Hint := AOption.Info.Hint;
      OptionCheckBox.ShowHint := True;
      // After Checked, which calls OnClick
      OptionCheckBox.OnClick := BooleanOptionClick;
      PlaceOptionControl(OptionCheckBox, 0);
    end;
    cokInteger:
    begin
      AddOptionLabel(AOption);
      OptionEdit := TEdit.Create(FOptionsPanel);
      OptionEdit.NumbersOnly := AOption.Info.MinValue >= 0;
      OptionEdit.Tag := AOptionIndex;
      OptionEdit.Hint := AOption.Info.Hint;
      OptionEdit.ShowHint := True;
      PlaceOptionControl(OptionEdit, INTEGER_EDIT_WIDTH);
      OptionUpDown := TUpDown.Create(FOptionsPanel);
      OptionUpDown.Parent := FOptionsPanel;
      OptionUpDown.Tag := AOptionIndex;
      OptionUpDown.Min := AOption.Info.MinValue;
      OptionUpDown.Max := AOption.Info.MaxValue;
      OptionUpDown.Thousands := False;
      OptionUpDown.Position := AOption.AsInteger;
      OptionUpDown.Associate := OptionEdit;
      OptionEdit.Text := AOption.Value;
      OptionEdit.OnChange := IntegerOptionChange;
      OptionEdit.OnExit := IntegerOptionExit;
    end;
    cokText:
    begin
      AddOptionLabel(AOption);
      OptionEdit := TEdit.Create(FOptionsPanel);
      OptionEdit.Text := AOption.Value;
      OptionEdit.Tag := AOptionIndex;
      OptionEdit.Hint := AOption.Info.Hint;
      OptionEdit.ShowHint := True;
      OptionEdit.OnChange := TextOptionChange;
      PlaceOptionControl(OptionEdit, 0);
    end;
    cokTextList:
    begin
      AddOptionLabel(AOption);
      OptionMemo := TMemo.Create(FOptionsPanel);
      OptionMemo.Height := TEXT_LIST_HEIGHT;
      OptionMemo.ScrollBars := ssVertical;
      OptionMemo.WordWrap := False;
      OptionMemo.Tag := AOptionIndex;
      OptionMemo.Hint := AOption.Info.Hint;
      OptionMemo.ShowHint := True;
      PlaceOptionControl(OptionMemo, 0);
      // Lines need the window of the memo, so after the parent is set
      OptionMemo.Lines.Text := string.Join(sLineBreak, AOption.Items);
      OptionMemo.OnChange := TextListOptionChange;
    end;
    cokChoice:
    begin
      AddOptionLabel(AOption);
      OptionComboBox := TComboBox.Create(FOptionsPanel);
      OptionComboBox.Style := csDropDownList;
      OptionComboBox.Tag := AOptionIndex;
      OptionComboBox.Hint := AOption.Info.Hint;
      OptionComboBox.ShowHint := True;
      PlaceOptionControl(OptionComboBox, 0);
      for i := 0 to AOption.ChoiceCount - 1 do
        OptionComboBox.Items.Add(AOption.ChoiceCaptions[i]);
      OptionComboBox.ItemIndex := AOption.ChoiceIndex;
      OptionComboBox.OnChange := ChoiceOptionChange;
    end;
    cokQuantity:
      AddQuantityControls(AOptionIndex, AOption);
  end;
  FNextOptionTop := FNextOptionTop + OPTION_SPACING;
end;

function TfmCodeStyleProfile.FindOptionControl(AOptionIndex: Integer; AControlClass: TControlClass): TControl;
var
  i: Integer;
begin
  for i := 0 to FOptionsPanel.ControlCount - 1 do
    if (FOptionsPanel.Controls[i].Tag = AOptionIndex) and (FOptionsPanel.Controls[i] is AControlClass) then
      Exit(FOptionsPanel.Controls[i]);
  Result := nil;
end;

procedure TfmCodeStyleProfile.ShowRule(ARule: TCodeStyleProfileRule);
var
  OldPanel: TPanel;
  i: Integer;
begin
  FCurrentRule := ARule;
  OldPanel := FOptionsPanel;
  FOptionsPanel := nil;
  // The captions change the heights of the labels: pnDetails is aligned once at the end
  pnDetails.DisableAlign;
  try
    if Assigned(ARule) then
    begin
      // The controls are created on a hidden panel, the old panel stays visible meanwhile
      FOptionsPanel := CreateOptionsPanel;
      FNextOptionTop := OPTION_MARGIN;
      for i := 0 to ARule.OptionCount - 1 do
        AddOptionControl(i, ARule.Options[i]);
      FOptionsPanel.Height := FNextOptionTop + OPTION_MARGIN;

      lblRuleCaption.Caption := ARule.Info.Caption;
      lblRuleSubtitle.Caption := GetRuleSubtitle(ARule);
      lblRuleDescription.Caption := ARule.Info.Description;
      pnLevel.Visible := not ARule.Info.WithoutLevel;
      cbLevel.ItemIndex := Ord(ARule.Level);
    end
    else
    begin
      lblRuleCaption.Caption := '';
      lblRuleSubtitle.Caption := '';
      lblRuleDescription.Caption := '';
      pnLevel.Visible := False;
    end;
  finally
    pnDetails.EnableAlign;
  end;

  // The new controls appear at once, then the old ones are removed under them
  sbOptions.VertScrollBar.Position := 0;
  if Assigned(FOptionsPanel) then
    FOptionsPanel.Visible := True;
  OldPanel.Free;
end;

procedure TfmCodeStyleProfile.ShowCategory(AItem: TListItem);
var
  Rule: TCodeStyleProfileRule;
  RuleCount, EnabledCount, i: Integer;
begin
  // ShowRule clears the captions and this method sets them again: pnDetails is aligned once
  pnDetails.DisableAlign;
  try
    ShowRule(nil);

    // The rules of the category are the items up to the next category row
    RuleCount := 0;
    EnabledCount := 0;
    i := AItem.Index + 1;
    while (i < lvRules.Items.Count) and Assigned(lvRules.Items[i].Data) do
    begin
      Rule := TCodeStyleProfileRule(lvRules.Items[i].Data);
      Inc(RuleCount);
      if (not Rule.Info.WithoutLevel) and (Rule.Level <> cslOff) then
        Inc(EnabledCount);
      Inc(i);
    end;
    lblRuleCaption.Caption := AItem.Caption;
    lblRuleSubtitle.Caption := Format(PROFILE_CATEGORY_SUMMARY, [RuleCount, EnabledCount]);
  finally
    pnDetails.EnableAlign;
  end;
end;

function TfmCodeStyleProfile.ConfirmAction(const AQuestion: string): Boolean;
begin
  Result := Application.MessageBox(PChar(AQuestion), PChar(Caption), MB_YESNO or MB_ICONQUESTION) = IDYES;
end;

procedure TfmCodeStyleProfile.ShowError(const AMessage: string);
begin
  Application.MessageBox(PChar(AMessage), PChar(Caption), MB_OK or MB_ICONERROR);
end;

procedure TfmCodeStyleProfile.BooleanOptionClick(Sender: TObject);
var
  OptionCheckBox: TCheckBox;
begin
  OptionCheckBox := Sender as TCheckBox;
  FCurrentRule.Options[OptionCheckBox.Tag].AsBoolean := OptionCheckBox.Checked;
  UpdateCurrentRuleItem;
end;

procedure TfmCodeStyleProfile.IntegerOptionChange(Sender: TObject);
var
  OptionEdit: TEdit;
  Option: TCodeStyleProfileOption;
begin
  // An invalid text is not stored, IntegerOptionExit shows the stored value again
  OptionEdit := Sender as TEdit;
  Option := FCurrentRule.Options[OptionEdit.Tag];
  if Option.IsValidValue(OptionEdit.Text) then
  begin
    Option.Value := OptionEdit.Text;
    UpdateCurrentRuleItem;
  end;
end;

procedure TfmCodeStyleProfile.IntegerOptionExit(Sender: TObject);
var
  OptionEdit: TEdit;
begin
  OptionEdit := Sender as TEdit;
  if Assigned(FCurrentRule) and (OptionEdit.Text <> FCurrentRule.Options[OptionEdit.Tag].Value) then
    OptionEdit.Text := FCurrentRule.Options[OptionEdit.Tag].Value;
end;

procedure TfmCodeStyleProfile.TextOptionChange(Sender: TObject);
var
  OptionEdit: TEdit;
begin
  OptionEdit := Sender as TEdit;
  FCurrentRule.Options[OptionEdit.Tag].Value := OptionEdit.Text;
  UpdateCurrentRuleItem;
end;

procedure TfmCodeStyleProfile.TextListOptionChange(Sender: TObject);
var
  OptionMemo: TMemo;
begin
  OptionMemo := Sender as TMemo;
  FCurrentRule.Options[OptionMemo.Tag].Items := OptionMemo.Lines.ToStringArray;
  UpdateCurrentRuleItem;
end;

procedure TfmCodeStyleProfile.ChoiceOptionChange(Sender: TObject);
var
  OptionComboBox: TComboBox;
begin
  OptionComboBox := Sender as TComboBox;
  FCurrentRule.Options[OptionComboBox.Tag].ChoiceIndex := OptionComboBox.ItemIndex;
  UpdateCurrentRuleItem;
end;

procedure TfmCodeStyleProfile.QuantityModeChange(Sender: TObject);
var
  ModeComboBox: TComboBox;
  CountEdit: TEdit;
  CountUpDown: TControl;
  Option: TCodeStyleProfileOption;
  Mode: TCodeStyleQuantityMode;
  Count: Integer;
begin
  ModeComboBox := Sender as TComboBox;
  if ModeComboBox.ItemIndex < 0 then
    Exit;

  Option := FCurrentRule.Options[ModeComboBox.Tag];
  Mode := TCodeStyleQuantityMode(ModeComboBox.ItemIndex);
  CountEdit := FindOptionControl(ModeComboBox.Tag, TEdit) as TEdit;
  CountUpDown := FindOptionControl(ModeComboBox.Tag, TUpDown);
  // The count shown in the disabled edit is kept, it is taken when the mode changes from Any
  if not TryStrToInt(CountEdit.Text, Count) or (Count < Option.Info.MinValue) or (Count > Option.Info.MaxValue) then
    Count := Option.Info.MinValue;
  Option.SetQuantity(Mode, Count);
  CountEdit.Enabled := Mode <> cqmAny;
  CountUpDown.Enabled := CountEdit.Enabled;
  UpdateCurrentRuleItem;
end;

procedure TfmCodeStyleProfile.QuantityCountChange(Sender: TObject);
var
  CountEdit: TEdit;
  Option: TCodeStyleProfileOption;
  Count: Integer;
begin
  // An invalid text is not stored, QuantityCountExit shows the stored count again
  CountEdit := Sender as TEdit;
  Option := FCurrentRule.Options[CountEdit.Tag];
  if (Option.QuantityMode <> cqmAny) and TryStrToInt(CountEdit.Text, Count) and (Count >= Option.Info.MinValue)
      and (Count <= Option.Info.MaxValue)
  then
  begin
    Option.SetQuantity(Option.QuantityMode, Count);
    UpdateCurrentRuleItem;
  end;
end;

procedure TfmCodeStyleProfile.QuantityCountExit(Sender: TObject);
var
  CountEdit: TEdit;
  Option: TCodeStyleProfileOption;
begin
  CountEdit := Sender as TEdit;
  if not Assigned(FCurrentRule) then
    Exit;

  Option := FCurrentRule.Options[CountEdit.Tag];
  if (Option.QuantityMode <> cqmAny) and (CountEdit.Text <> IntToStr(Option.QuantityCount)) then
    CountEdit.Text := IntToStr(Option.QuantityCount);
end;

function TfmCodeStyleProfile.Execute(AProfile: TCodeStyleProfile): Boolean;
begin
  FProfile.Assign(AProfile);
  FillRuleList;
  Result := ShowModal = mrOk;
  if Result then
    AProfile.Assign(FProfile);
end;

end.
