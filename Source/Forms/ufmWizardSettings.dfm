object fmWizardSettings: TfmWizardSettings
  Left = 449
  Top = 249
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = 'fmWizardSettings'
  ClientHeight = 402
  ClientWidth = 664
  Color = clBtnFace
  DefaultMonitor = dmMainForm
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  TextHeight = 15
  object pnButtons: TPanel
    Left = 0
    Top = 367
    Width = 664
    Height = 35
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object btnOK: TButton
      AlignWithMargins = True
      Left = 584
      Top = 5
      Width = 75
      Height = 25
      Margins.Left = 0
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Align = alRight
      Cancel = True
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
  end
  object pnMain: TPanel
    Left = 0
    Top = 0
    Width = 664
    Height = 367
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object tvSections: TTreeView
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 190
      Height = 361
      Align = alLeft
      Indent = 19
      ReadOnly = True
      TabOrder = 0
      OnChange = tvSectionsChange
    end
    object pnFrameSettingsContainer: TPanel
      AlignWithMargins = True
      Left = 199
      Top = 3
      Width = 462
      Height = 361
      Align = alClient
      TabOrder = 1
    end
  end
end
