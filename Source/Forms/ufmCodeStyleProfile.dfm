object fmCodeStyleProfile: TfmCodeStyleProfile
  Left = 0
  Top = 0
  Caption = 'fmCodeStyleProfile'
  ClientHeight = 600
  ClientWidth = 1000
  Color = clBtnFace
  Constraints.MinHeight = 400
  Constraints.MinWidth = 780
  DefaultMonitor = dmMainForm
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  PopupMode = pmAuto
  Position = poMainFormCenter
  ShowHint = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object spRules: TSplitter
    Left = 530
    Top = 37
    Width = 5
    Height = 522
    MinSize = 250
    ResizeStyle = rsUpdate
  end
  object pnTop: TPanel
    Left = 0
    Top = 0
    Width = 1000
    Height = 37
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblFilter: TLabel
      Left = 8
      Top = 11
      Width = 29
      Height = 15
      Caption = 'Filter:'
      FocusControl = edFilter
    end
    object edFilter: TEdit
      Left = 48
      Top = 7
      Width = 220
      Height = 23
      Hint = 'Part of the name or of the description of a rule'
      TabOrder = 0
      TextHint = 'Rule name or text'
      OnChange = edFilterChange
    end
    object cbShow: TComboBox
      Left = 276
      Top = 7
      Width = 240
      Height = 23
      Style = csDropDownList
      TabOrder = 1
      OnChange = cbShowChange
    end
  end
  object pnBottom: TPanel
    Left = 0
    Top = 559
    Width = 1000
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 3
    DesignSize = (
      1000
      41)
    object btnLoad: TButton
      Left = 8
      Top = 8
      Width = 90
      Height = 25
      Hint = 'Load a profile file'
      Caption = 'Load...'
      TabOrder = 0
      OnClick = btnLoadClick
    end
    object btnSave: TButton
      Left = 104
      Top = 8
      Width = 90
      Height = 25
      Hint = 'Save the profile to a file, to share it with other developers'
      Caption = 'Save as...'
      TabOrder = 1
      OnClick = btnSaveClick
    end
    object btnReset: TButton
      Left = 200
      Top = 8
      Width = 130
      Height = 25
      Hint = 'Return all rules to the default values'
      Caption = 'Defaults'
      TabOrder = 2
      OnClick = btnResetClick
    end
    object btnSwitchOff: TButton
      Left = 336
      Top = 8
      Width = 110
      Height = 25
      Hint = 'Switch all rules off, to switch on only the needed ones'
      Caption = 'Switch all off'
      TabOrder = 3
      OnClick = btnSwitchOffClick
    end
    object btnOK: TButton
      Left = 836
      Top = 8
      Width = 75
      Height = 25
      Anchors = [akRight, akBottom]
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 4
    end
    object btnCancel: TButton
      Left = 917
      Top = 8
      Width = 75
      Height = 25
      Anchors = [akRight, akBottom]
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 5
    end
  end
  object lvRules: TListView
    AlignWithMargins = True
    Left = 3
    Top = 40
    Width = 527
    Height = 516
    Margins.Right = 0
    Align = alLeft
    Columns = <
      item
        Caption = 'Rule'
        Width = 400
      end
      item
        Caption = 'Level'
        Width = 90
      end>
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnCustomDrawItem = lvRulesCustomDrawItem
    OnSelectItem = lvRulesSelectItem
  end
  object pnDetails: TPanel
    Left = 535
    Top = 37
    Width = 465
    Height = 522
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object lblRuleCaption: TLabel
      AlignWithMargins = True
      Left = 8
      Top = 6
      Width = 449
      Height = 20
      Margins.Left = 8
      Margins.Top = 6
      Margins.Right = 8
      Align = alTop
      Caption = 'lblRuleCaption'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblRuleSubtitle: TLabel
      AlignWithMargins = True
      Left = 8
      Top = 29
      Width = 449
      Height = 15
      Margins.Left = 8
      Margins.Top = 0
      Margins.Right = 8
      Align = alTop
      Caption = 'lblRuleSubtitle'
    end
    object lblRuleDescription: TLabel
      AlignWithMargins = True
      Left = 8
      Top = 53
      Width = 449
      Height = 15
      Margins.Left = 8
      Margins.Top = 6
      Margins.Right = 8
      Align = alTop
      Caption = 'lblRuleDescription'
      WordWrap = True
    end
    object pnLevel: TPanel
      Left = 0
      Top = 71
      Width = 465
      Height = 36
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object lblLevel: TLabel
        Left = 8
        Top = 11
        Width = 30
        Height = 15
        Caption = 'Level:'
        FocusControl = cbLevel
      end
      object cbLevel: TComboBox
        Left = 56
        Top = 7
        Width = 150
        Height = 23
        Hint = 
          'Off: the rule is not checked; otherwise the kind of the message ' +
          'of a found issue'
        Style = csDropDownList
        TabOrder = 0
        OnChange = cbLevelChange
      end
    end
    object sbOptions: TScrollBox
      Left = 0
      Top = 107
      Width = 465
      Height = 415
      VertScrollBar.Tracking = True
      Align = alClient
      BorderStyle = bsNone
      TabOrder = 1
    end
  end
  object dlgOpen: TOpenDialog
    DefaultExt = 'xml'
    Filter = 'Code style profile (*.xml)|*.xml|All files (*.*)|*.*'
    Options = [ofHideReadOnly, ofFileMustExist, ofEnableSizing]
    Title = 'Load code style profile'
    Left = 552
    Top = 280
  end
  object dlgSave: TSaveDialog
    DefaultExt = 'xml'
    Filter = 'Code style profile (*.xml)|*.xml|All files (*.*)|*.*'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Title = 'Save code style profile'
    Left = 632
    Top = 280
  end
end
