object fmMainTest: TfmMainTest
  Left = 0
  Top = 0
  Caption = 'fmMainTest'
  ClientHeight = 574
  ClientWidth = 1070
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCloseQuery = FormCloseQuery
  TextHeight = 15
  object Label1: TLabel
    Left = 8
    Top = 8
    Width = 49
    Height = 15
    Caption = 'Average: '
  end
  object Label2: TLabel
    Left = 8
    Top = 29
    Width = 39
    Height = 15
    Caption = 'Count: '
  end
  object Label3: TLabel
    Left = 63
    Top = 8
    Width = 34
    Height = 15
    Caption = 'Label3'
  end
  object Label4: TLabel
    Left = 53
    Top = 29
    Width = 34
    Height = 15
    Caption = 'Label4'
  end
  object Memo1: TMemo
    Left = 256
    Top = 8
    Width = 806
    Height = 558
    ScrollBars = ssBoth
    TabOrder = 0
  end
  object Button1: TButton
    Left = 136
    Top = 8
    Width = 114
    Height = 25
    Caption = 'Test parse'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 136
    Top = 39
    Width = 114
    Height = 25
    Caption = 'Test parse all source'
    TabOrder = 2
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 136
    Top = 192
    Width = 114
    Height = 25
    Caption = 'Read file test'
    TabOrder = 3
    OnClick = Button3Click
  end
  object Button4: TButton
    Left = 8
    Top = 50
    Width = 114
    Height = 25
    Caption = 'Start time test'
    TabOrder = 4
    OnClick = Button4Click
  end
  object Button5: TButton
    Left = 136
    Top = 223
    Width = 114
    Height = 25
    Caption = 'Type size test'
    TabOrder = 5
    OnClick = Button5Click
  end
  object Button6: TButton
    Left = 136
    Top = 70
    Width = 114
    Height = 25
    Caption = 'Time state copy'
    TabOrder = 6
    OnClick = Button6Click
  end
  object Button7: TButton
    Left = 136
    Top = 101
    Width = 114
    Height = 25
    Caption = 'Time state reset'
    TabOrder = 7
    OnClick = Button7Click
  end
  object Button8: TButton
    Left = 136
    Top = 288
    Width = 114
    Height = 25
    Caption = 'Test final parse'
    TabOrder = 8
    OnClick = Button8Click
  end
  object Button9: TButton
    Left = 175
    Top = 541
    Width = 75
    Height = 25
    Caption = 'Clear'
    TabOrder = 9
    OnClick = Button9Click
  end
  object Button10: TButton
    Left = 136
    Top = 132
    Width = 114
    Height = 25
    Caption = 'Test parse 2'
    TabOrder = 10
    OnClick = Button10Click
  end
  object Button11: TButton
    Left = 175
    Top = 344
    Width = 75
    Height = 25
    Caption = 'Button11'
    TabOrder = 11
    OnClick = Button11Click
  end
end
