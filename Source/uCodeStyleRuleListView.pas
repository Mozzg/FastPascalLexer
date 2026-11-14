// List view of the code style profile dialog with a fixed style hook and double buffering.
//
// Under a VCL style (the IDE theme) the thumb of the vertical scroll bar of a TListView in the report view lags behind
// the mouse: TListViewStyleHook asks the list to scroll by a fractional number of rows, the list scrolls by whole rows
// only, and the hook drops the rest of a row on every mouse move. Without a VCL style the scroll bar is native and has
// no such problem.
//
// Without a VCL style a fast scroll makes the newly shown rows flicker: they are erased and drawn on the screen row by
// row (the dialog draws the category rows itself). LVS_EX_DOUBLEBUFFER makes the list draw them in memory first. VCL
// does not set this style (DoubleBuffered of TWinControl is a different mechanism), and TCustomListView.ResetExStyles
// overwrites all extended styles, so it is added after every creation of the window. A double buffered list paints
// its whole area in WM_PAINT, so the background is not erased: TWinControl.WMEraseBkgnd would fill the whole list with
// its color, and while the thumb is dragged WM_PAINT comes only when the mouse stops, so the list stayed white. For the
// same reason the list is painted at once after every step of the thumb.
//
// TListView here is an interposer class: a unit that lists uCodeStyleRuleListView after Vcl.ComCtrls creates its
// TListView fields from this class, while the form designer still sees the standard TListView. The style hook is
// registered for this class only, the other list views (also those of the IDE) keep the standard one.
unit uCodeStyleRuleListView;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.CommCtrl, System.Classes, Vcl.Controls, Vcl.ComCtrls, Vcl.Themes;

type
  // TListView that draws double buffered and gets TCodeStyleRuleListViewStyleHook under a VCL style
  TListView = class(Vcl.ComCtrls.TListView)
  private
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMVScroll(var Message: TWMVScroll); message WM_VSCROLL;
  protected
    procedure CreateWnd; override;
  end;

  // Style hook of TListView: dragging the vertical thumb in the report view scrolls the list to the row under the thumb,
  // computed from the real position of the list, so no rest of a row is lost
  TCodeStyleRuleListViewStyleHook = class(TListViewStyleHook)
  strict private
    procedure TrackVerticalThumb;
  strict protected
    procedure WndProc(var Message: TMessage); override;
  end;

implementation

{ TListView }

procedure TListView.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  // Not erased: the double buffered list paints its background in WM_PAINT together with the rows
  Message.Result := 1;
end;

procedure TListView.WMVScroll(var Message: TWMVScroll);
begin
  inherited;

  // The native thumb sends a step on every mouse move; without an immediate paint the list is painted only when the
  // mouse stops
  if Message.ScrollCode = SB_THUMBTRACK then
    Update;
end;

procedure TListView.CreateWnd;
begin
  inherited CreateWnd;

  // After ResetExStyles of the inherited CreateWnd, which sets the extended styles of the properties. A later change
  // of RowSelect, GridLines, Checkboxes or HotTrack would drop it; the dialog does not change them.
  ListView_SetExtendedListViewStyleEx(Handle, LVS_EX_DOUBLEBUFFER, LVS_EX_DOUBLEBUFFER);
end;

{ TCodeStyleRuleListViewStyleHook }

procedure TCodeStyleRuleListViewStyleHook.TrackVerticalThumb;
var
  ScrollInfo: TScrollInfo;
  TrackRect, ItemRect: TRect;
  TrackTop, TrackBottom: TPoint;
  CursorY, MaxPos, Rows: Integer;
begin
  TrackRect := VertTrackRect;
  TrackTop := TrackRect.TopLeft;
  TrackBottom := TrackRect.BottomRight;
  ClientToScreen(Handle, TrackTop);
  ClientToScreen(Handle, TrackBottom);
  CursorY := Mouse.CursorPos.Y;

  // Beyond the track the thumb stays at its end until the mouse comes back, as in TListViewStyleHook
  if (CursorY < TrackTop.Y) and (PrevScrollPos <= CursorY) then
  begin
    PrevScrollPos := TrackTop.Y;
    Exit;
  end;
  if (CursorY > TrackBottom.Y) and (PrevScrollPos >= CursorY) then
  begin
    PrevScrollPos := TrackBottom.Y;
    Exit;
  end;

  ScrollInfo.cbSize := SizeOf(ScrollInfo);
  ScrollInfo.fMask := SIF_ALL;
  GetScrollInfo(Handle, SB_VERT, ScrollInfo);
  // The position under the thumb in rows, with the fraction; the mapping of the mouse to rows is the one of
  // TListViewStyleHook, so the thumb follows the mouse as in the other styled controls
  ScrollPos := ScrollPos + (ScrollInfo.nMax - ScrollInfo.nMin) * ((CursorY - PrevScrollPos) / TrackRect.Height);
  PrevScrollPos := CursorY;
  MaxPos := ScrollInfo.nMax - Integer(ScrollInfo.nPage) + 1;
  if ScrollPos > MaxPos then
    ScrollPos := MaxPos;
  if ScrollPos < ScrollInfo.nMin then
    ScrollPos := ScrollInfo.nMin;

  // The report view scrolls by whole rows: scroll from the real top row to the row under the thumb
  Rows := Round(ScrollPos) - ScrollInfo.nPos;
  if Rows <> 0 then
  begin
    ListView_GetItemRect(Handle, 0, ItemRect, LVIR_BOUNDS);
    ListView_Scroll(Handle, 0, Rows * ItemRect.Height);
    // Painted at once, like after a step of the native thumb (TListView.WMVScroll)
    Control.Update;
  end;
  ListPos := Round(ScrollPos);
  PaintScroll;
end;

procedure TCodeStyleRuleListViewStyleHook.WndProc(var Message: TMessage);
begin
  // Other messages, the horizontal thumb and the other views are handled by TListViewStyleHook
  if (Message.Msg = WM_MOUSEMOVE) and (VertSliderState = tsThumbBtnVertPressed) and (Control is TListView)
      and (TListView(Control).ViewStyle = vsReport) and (not TListView(Control).GroupView)
  then
  begin
    TrackVerticalThumb;
    Handled := True;
    Exit;
  end;

  inherited WndProc(Message);
end;

initialization
  TCustomStyleEngine.RegisterStyleHook(TListView, TCodeStyleRuleListViewStyleHook);

finalization
  // Before the plugin is unloaded: the engine frees the hooks of this class, which lives in the plugin
  TCustomStyleEngine.UnRegisterStyleHook(TListView, TCodeStyleRuleListViewStyleHook);

end.
