unit CFEdit;

interface

uses
  Windows, Classes, Controls, CFControl, Graphics, Messages;

type
  TScrollAlign = (csaLeft, csaRight);

  TCFEdit = class(TCFTextControl)
  private
    FFocus: Boolean;
    FTopPadding,           // ��ƫ�ƶ��ٿ�ʼ��ʾ�ı�
    FLeftPadding,          // ��ƫ�ƶ��ٿ�ʼ��ʾ�ı�
    FRightPadding          // ��ƫ�ƶ���ֹͣ��ʾ�ı�
      : Byte;
    FDrawLeftOffs, FTextWidth: Integer;  // ����ʱ��ƫ�ƣ��ı����ݿ���
    FSelStart, FSelEnd: Integer;  // ѡ����ʼ�ͽ��������ڵڼ������� >0 ��Ч
    FCanSelect: Boolean;
    FSelecting: Boolean;
    FReadOnly: Boolean;
    FHelpText: string;
    /// <summary>
    /// ����λ���ڵڼ����ַ�����(>0��Ч)
    /// </summary>
    /// <param name="AX">λ��</param>
    /// <returns>�ڵڼ����ַ�����</returns>
    function GetOffsetBeforAt(const AX: Integer): Integer;
    procedure ScrollTo(const AOffset: Integer; const AAlign: TScrollAlign);
    procedure MoveCaretAfter(const AOffset: Integer);
    procedure RightKeyPress;
    procedure CopyText;
    procedure CutText;
    procedure PasteText;
    procedure SelectAll;
  protected
    /// <summary> ���Ƶ����� </summary>
    procedure DrawControl(ACanvas: TCanvas); override;
    procedure DeleteSelect(const AUpdate: Boolean = False);
    procedure DisSelect;
    //
    procedure SetCanSelect(Value: Boolean);
    function GetFocus: Boolean; override;
    procedure SetFocus(Value: Boolean); override;
    function GetTabStop: Boolean; override;
    procedure SetReadOnly(Value: Boolean);
    procedure SetHelpText(Value: string);
    procedure AdjustBounds; override;
    //
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    //
    procedure CMMouseEnter(var Msg: TMessage ); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Msg: TMessage ); message CM_MOUSELEAVE;
    procedure WMLButtonDblClk(var Message: TWMLButtonDblClk); message WM_LBUTTONDBLCLK;
    // ͨ��Tab���뽹��
    procedure CMUIActivate(var Message: TMessage); message CM_UIACTIVATE;
    // ͨ��Tab�Ƴ�����
    procedure CMUIDeActivate(var Message: TMessage); message CM_UIDEACTIVATE;
    procedure CMTextChanged(var Message: TMessage); message CM_TEXTCHANGED;

    procedure KeyPress(var Key: Char); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;

    function SelectExist: Boolean;
    function TextLength: Integer;
    function SelText: string;
    //
    property RightPadding: Byte read FRightPadding write FRightPadding;
    property LeftPadding: Byte read FLeftPadding write FLeftPadding;
  published
    property CanSelect: Boolean read FCanSelect write SetCanSelect;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    property HelpText: string read FHelpText write SetHelpText;
    //
    property Text;
    property OnChange;
    property OnKeyDown;
    property OnKeyPress;
  end;

implementation

uses
  Clipbrd;

{ TCFEdit }

procedure TCFEdit.ScrollTo(const AOffset: Integer; const AAlign: TScrollAlign);
var
  vS: string;
  vW, vDecW: Integer;
begin
  vS := Copy(Text, 1, AOffset);
  vW := TextMetricWidth(vS);
  if AAlign = csaRight then  // ���������AOffsetǡ����ʾ
  begin
    vDecW := FDrawLeftOffs + FLeftPadding + vW - (Width - FRightPadding);
    if vDecW > 0 then  // ��������
    begin
      FDrawLeftOffs := FDrawLeftOffs - vDecW;
      UpdateDirectUI;
    end
    else
    if vDecW < 0 then  // û�г�������
    begin
      if FDrawLeftOffs < 0 then  // �����û��ʾ������
      begin
        FDrawLeftOffs := FDrawLeftOffs - vDecW;
        if FDrawLeftOffs > 0 then
          FDrawLeftOffs := 0;
        UpdateDirectUI;
      end;
    end;
  end
  else
  begin
    vDecW := FDrawLeftOffs + vW;
    if vDecW < 0 then
    begin
      FDrawLeftOffs := FDrawLeftOffs - vDecW;
      UpdateDirectUI;
    end;
  end;
end;

procedure TCFEdit.CMMouseEnter(var Msg: TMessage);
begin
  inherited;
  UpdateDirectUI;
end;

procedure TCFEdit.CMMouseLeave(var Msg: TMessage);
begin
  inherited;
  UpdateDirectUI;
end;

procedure TCFEdit.CMTextChanged(var Message: TMessage);
begin
  inherited;
  if Assigned(OnChange) then
    OnChange(Self);
end;

procedure TCFEdit.CMUIActivate(var Message: TMessage);
begin
  FSelStart := TextLength;
  MoveCaretAfter(FSelStart);
  Focus := True;
  Message.Result := 1;
end;

procedure TCFEdit.CMUIDeActivate(var Message: TMessage);
begin
  Focus := False;
  Message.Result := 1;
end;

procedure TCFEdit.CopyText;
begin
  if not FReadOnly then
    Clipboard.AsText := SelText;
end;

constructor TCFEdit.Create(AOwner: TComponent);
begin
  inherited;
  FFocus := False;
  FCanSelect := True;
  FSelecting := False;
  FTopPadding := 2;
  FLeftPadding := 2;
  FRightPadding := 2;
  FDrawLeftOffs := 0;
  FSelStart := -1;
  FSelEnd := -1;
  Width := 120;
  Height := 20;
  //Text := 'TCFEdit';  // ����win32�Դ�����Ĭ��ֵ
end;

procedure TCFEdit.CutText;
var
  vS: string;
begin
  if not FReadOnly then
  begin
    vS := SelText;
    Clipboard.AsText := vS;
    DeleteSelect;
    FDrawLeftOffs := FDrawLeftOffs + TextMetricWidth(vS);
    if FDrawLeftOffs > 0 then
      FDrawLeftOffs := 0;
    UpdateDirectUI;
  end;
end;

procedure TCFEdit.DeleteSelect(const AUpdate: Boolean = False);
var
  vS: string;
begin
  if SelectExist then  // ��ѡ��
  begin
    vS := Text;
    if FSelEnd < FSelStart then  // ѡ�н���λ������ʼλ��ǰ��
      System.Delete(vS, FSelEnd + 1, FSelStart - FSelEnd)
    else  // ѡ�н���λ������ʼλ�ú���
      System.Delete(vS, FSelStart + 1, FSelEnd - FSelStart);
    Text := vS;

    if FSelEnd < FSelStart then
      FSelStart := FSelEnd;
    FSelEnd := -1;
    if AUpdate then
      UpdateDirectUI;
    MoveCaretAfter(FSelStart);
  end;
end;

procedure TCFEdit.DisSelect;
begin
  if SelectExist then
  begin
    FSelStart := FSelEnd;
    FSelEnd := -1;
    UpdateDirectUI;
  end;
end;

procedure TCFEdit.DrawControl(ACanvas: TCanvas);
var
  vRect: TRect;
  vS: string;
  vLeft, vRight: Integer;
  vSaveDC: Integer;
  //vRgn: HRGN;
  //vBmp: TBitmap;
begin
  inherited;
  // ��ۣ�Բ�Ǿ���
  vRect := Rect(0, 0, Width, Height);
  ACanvas.Brush.Style := bsSolid;
  if not FReadOnly then
    ACanvas.Brush.Color := GThemeColor
  else
    ACanvas.Brush.Color := clInfoBk;
  if FFocus or (cmsMouseIn in MouseState) then
    ACanvas.Pen.Color := GBorderHotColor
  else
    ACanvas.Pen.Color := GBorderColor;
  if BorderVisible then
    ACanvas.Pen.Style := psSolid
  else
    ACanvas.Pen.Style := psClear;
  if BorderVisible then  // ��ʾ�߿�ʱԲ������
    ACanvas.RoundRect(vRect, GRoundSize, GRoundSize)
  else
    ACanvas.FillRect(vRect);
  // ���ÿɻ�������
  InflateRect(vRect, 0, -FTopPadding);
  vRect.Left := vRect.Left + FLeftPadding;
  vRect.Right := vRect.Right - FRightPadding;

  //vRgn := CreateRectRgnIndirect(vRect);
  //SelectClipRgn(ACanvas.Handle, vRgn);  //ExtSelectClipRgn(ACanvas.Handle, vRgn)
  IntersectClipRect(ACanvas.Handle, vRect.Left, vRect.Top, vRect.Right, vRect.Bottom);
  try
    // �����ı�
    if Text <> '' then  // ������
    begin
      //ACanvas.Font.Assign(Font);
      if FSelEnd >= 0 then  // ��ѡ��
      begin
        vLeft := FLeftPadding + FDrawLeftOffs;  // ƫ�Ƶ�����ʾ��ʼλ��

        if FSelEnd < FSelStart then  // ѡ�н���λ������ʼλ��ǰ��
        begin
          vS := Copy(Text, 1, FSelEnd);
          if vS <> '' then
            vLeft := vLeft + ACanvas.TextWidth(vS);
          vS := Copy(Text, 1, FSelStart);
          vRight := FLeftPadding + FDrawLeftOffs + ACanvas.TextWidth(vS);
        end
        else  // ѡ�н���λ������ʼλ�ú���
        begin
          vS := Copy(Text, 1, FSelStart);
          if vS <> '' then
            vLeft := vLeft + ACanvas.TextWidth(vS);
          vS := Copy(Text, 1, FSelEnd);
          vRight := FLeftPadding + FDrawLeftOffs + ACanvas.TextWidth(vS);
        end;
        // ����ѡ�����򱳾�
        ACanvas.Brush.Color := GHightLightColor;
        ACanvas.FillRect(Rect(vLeft, FTopPadding, vRight, Height - FTopPadding));
        ACanvas.Brush.Style := bsClear;
      end;
      // �����ı�
      vRect := Bounds(0, 0, FTextWidth, Height);
      OffsetRect(vRect, FDrawLeftOffs + FLeftPadding, 0);
      vS := Text;
      ACanvas.TextRect(vRect, vS, [tfLeft, tfVerticalCenter, tfSingleLine]);
    end
    else
    if FHelpText <> '' then  // ��ʾ��Ϣ
    begin
      vSaveDC := SaveDC(ACanvas.Handle);  // ����(�豸�����Ļ���)�ֳ�
      try
        ACanvas.Font.Style := [fsItalic];
        ACanvas.Font.Color := clMedGray;  // clGrayText;
        vRect := Bounds(0, 0, TextMetric(FHelpText, Font).cx, Height);
        OffsetRect(vRect, FLeftPadding, 0);
        vS := FHelpText;
        ACanvas.TextRect(vRect, vS, [tfLeft, tfVerticalCenter, tfSingleLine]);
      finally
        RestoreDC(ACanvas.Handle, vSaveDC);  // �ָ�(�豸�����Ļ���)�ֳ�
      end;
    end;
  finally
    SelectClipRgn(ACanvas.Handle, 0);  // �����������
    //DeleteObject(vRgn)
  end;
end;

procedure TCFEdit.AdjustBounds;
var
  DC: HDC;
  Rect: TRect;
begin
  if not (csReading in ComponentState) then
  begin
    Rect := ClientRect;
    DC := GetDC(0);
    try
      Canvas.Handle := DC;
      Canvas.Font := Font;
      Rect.Bottom := Rect.Top + Canvas.TextHeight('��') + GetSystemMetrics(SM_CYBORDER) * 4;
      FTextWidth := Canvas.TextWidth(Text);
      Canvas.Handle := 0;
    finally
      ReleaseDC(0, DC);
    end;
    SetBounds(Left, Top, Rect.Right, Rect.Bottom);
  end;
end;

function TCFEdit.GetFocus: Boolean;
begin
  inherited;
  Result := FFocus;
end;

function TCFEdit.GetOffsetBeforAt(const AX: Integer): Integer;
var
  i, vW, vRight: Integer;
begin
  Result := -1;
  //if (AX < FDrawLeftOffs) or (AX > FTextWidth) then Exit;
  if AX < FDrawLeftOffs then
  begin
    Result := 0;
    Exit;
  end;
  if AX > FTextWidth then
  begin
    Result := TextLength;
    Exit;
  end;

  if AX < TextMetricWidth(Text) then  // ���ı���
  begin
    vRight := 0;
    for i := 1 to Length(Text) do
    begin
      vW := TextMetricWidth(Text[i]);
      if vRight + vW > AX then
      begin
        if vRight + vW div 2 > AX then
          Result := i - 1
        else
        begin
          Result := i;
          vRight := vRight + vW;
        end;
        Break;
      end
      else
        vRight := vRight + vW;
    end;
  end
  else  // �����ı���
    Result := TextLength;
end;

function TCFEdit.GetTabStop: Boolean;
begin
  Result := True;
end;

procedure TCFEdit.KeyDown(var Key: Word; Shift: TShiftState);

  {$REGION 'DoBackKey'}
  procedure DoBackKey;
  var
    vS: string;
  begin
    if SelectExist then
      DeleteSelect(True)
    else
    begin
      if (Text <> '') and (FSelStart > 0) then
      begin
        vS := Text;
        Delete(vS, FSelStart, 1);
        Text := vS;
        Dec(FSelStart);
        if FSelStart = TextLength then  // ���������ǰɾ��
        begin
          if FDrawLeftOffs < 0 then  // ǰ����û��ʾ������
            ScrollTo(FSelStart, csaRight);
        end
        else
          UpdateDirectUI;
        MoveCaretAfter(FSelStart);
      end;
    end;
  end;
  {$ENDREGION}

  {$REGION 'DoDeleteKey'}
  procedure DoDeleteKey;
  var
    vS: string;
  begin
    if SelectExist then
      DeleteSelect(True)
    else
    begin
      if (Text <> '') and (FSelStart < TextLength) then
      begin
        vS := Text;
        Delete(vS, FSelStart + 1, 1);
        Text := vS;
        if FSelStart = TextLength then  // ���������ǰɾ��
        begin
          if FDrawLeftOffs < 0 then  // ǰ����û��ʾ������
          begin
            ScrollTo(FSelStart, csaRight);
            MoveCaretAfter(FSelStart);
          end;
        end;
      end;
    end;
  end;
  {$ENDREGION}

  {$REGION 'DoHomeKey'}
  procedure DoHomeKey;
  begin
    DisSelect;
    FSelStart := 0;
    FDrawLeftOffs := 0;
    MoveCaretAfter(FSelStart);
  end;
  {$ENDREGION}

  {$REGION 'DoEndKey'}
  procedure DoEndKey;
  begin
    DisSelect;
    FSelStart := TextLength;
    ScrollTo(FSelStart, csaRight);
    MoveCaretAfter(FSelStart);
  end;
  {$ENDREGION}

  {$REGION 'DoLeftKeyPress'}
  procedure DoLeftKeyPress;
  begin
    DisSelect;
    if FSelStart > 0 then
    begin
      Dec(FSelStart);
      ScrollTo(FSelStart, csaLeft);
      MoveCaretAfter(FSelStart);
    end;
  end;
  {$ENDREGION}

begin
  inherited;
  if FReadOnly then Exit;
  if Shift = [ssCtrl] then
  begin
    case Key of
      Ord('C'): CopyText;
      Ord('X'): CutText;
      Ord('V'): PasteText;
    end;
    Exit;
  end;

  case Key of
    VK_BACK: DoBackKey;
    VK_RETURN: ;
    VK_DELETE: DoDeleteKey;
    VK_LEFT: DoLeftKeyPress;
    VK_RIGHT: RightKeyPress;
    VK_HOME: DoHomeKey;
    VK_END: DoEndKey;
  end;
end;

procedure TCFEdit.KeyPress(var Key: Char);
var
  vS: string;
begin
  inherited;
  if FReadOnly then Exit;

  //if Ord(Key) in [VK_BACK, VK_RETURN] then Exit;
  if ((Key < #32) or (Key = #127)) and (Ord(Key) <> VK_TAB) then Exit;

  DeleteSelect;  // ɾ��ѡ��
  vS := Text;
  Insert(Key, vS, FSelStart + 1);
  Text := vS;

  RightKeyPress;
end;

procedure TCFEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
var
  vS: string;
  vOffs: Integer;
  vSelStart: Integer absolute vOffs;
  vReUpdate: Boolean;
begin
  inherited;
  if FReadOnly then Exit;
  if (X < FLeftPadding) or (X > Width - FRightPadding) then
  begin
    DisSelect;
    Exit;
  end;
  vReUpdate := False;
  //FTextWidth := Canvas.TextWidth(Text);
  if FSelEnd >= 0 then
  begin
    FSelEnd := -1;
    vReUpdate := True;
  end;
  vSelStart := GetOffsetBeforAt(X - FDrawLeftOffs - FLeftPadding);
  if FSelStart <> vSelStart then
  begin
    FSelStart := vSelStart;
    vReUpdate := True;
  end;
  // ����ʾ���Ҳ���ַ��а��¶��ʱ��������ȫ��ʾ
  vS := Copy(Text, 1, FSelStart);
  vOffs := Width - FLeftPadding - FRightPadding - (TextMetricWidth(vS) + FDrawLeftOffs);
  if vOffs < 0 then
  begin
    FDrawLeftOffs := FDrawLeftOffs + vOffs;
    vReUpdate := True;
  end;
  if vReUpdate then
    UpdateDirectUI;
  MoveCaretAfter(FSelStart);
  FSelecting := True;
end;

procedure TCFEdit.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  vS: string;
  vSelEnd, vW: Integer;
  vReUpdate: Boolean;
begin
  inherited;
  if FReadOnly then Exit;
  if FSelecting and (ssLeft in Shift) then  // ��ѡ
  begin
    if not FCanSelect then Exit;

    vReUpdate := False;
    try
      if X > Width - FRightPadding then  // ����ڿؼ��Ҳ�
      begin
        vW := FTextWidth - (Width - FLeftPadding - FRightPadding);
        if FDrawLeftOffs + vW > 0 then  // �Ҳ�����δ��ʾ��ȫ
        begin
          Dec(FDrawLeftOffs, GPadding);
          if FDrawLeftOffs < -vW then
            FDrawLeftOffs := -vW;
          vReUpdate := True;
        end;
        vSelEnd := GetOffsetBeforAt(Width - FDrawLeftOffs + FLeftPadding - FRightPadding);
        vS := Copy(Text, 1, vSelEnd);
        if TextMetricWidth(vS) + FDrawLeftOffs > Width - FLeftPadding - FRightPadding then
          Dec(vSelEnd);
      end
      else
      if X < FLeftPadding then
      begin
        if FDrawLeftOffs < 0 then  // �������δ��ʾ��ȫ
        begin
          Inc(FDrawLeftOffs, GPadding);
          if FDrawLeftOffs > 0 then
            FDrawLeftOffs := 0;
          vReUpdate := True;
        end;
        vSelEnd := GetOffsetBeforAt({FLeftPadding - ���ַ�һ��С��FLeftPaddingʱ���㲻׼ȷ}-FDrawLeftOffs);
        vS := Copy(Text, 1, vSelEnd);
        if TextMetricWidth(vS) + FDrawLeftOffs < 0 then
          Inc(vSelEnd);
      end
      else
      begin
        vSelEnd := GetOffsetBeforAt(X - FDrawLeftOffs - FLeftPadding);
        vS := Copy(Text, 1, vSelEnd);
        if TextMetricWidth(vS) + FDrawLeftOffs + FLeftPadding > Width - FRightPadding then
          Dec(vSelEnd);
      end;

      if vSelEnd < 0 then  // ��겻��������
      begin
        if SelectExist then  // ��ѡ���ؼ���ʱ�������ѡ�У���ѡ�н���λ�ò��Ķ�
          Exit;
      end;

      //if FSelEnd <> vSelEnd then  // ��ʱ���������begin end
      begin
        FSelEnd := vSelEnd;
        if FSelEnd = FSelStart then  // ѡ����ʼ�ͽ���λ����ͬ
          FSelEnd := -1;
        if FSelEnd < 0 then Exit;
        vS := Copy(Text, 1, FSelEnd);
        SetCaretPos(Left + FLeftPadding + TextMetricWidth(vS) + FDrawLeftOffs, Top + FTopPadding);
        PostMessage(GetUIHandle, WM_C_CARETCHANGE, 0, Height - 2 * FTopPadding);
        vReUpdate := True;
      end;
    finally
      if vReUpdate then
        UpdateDirectUI;
    end;
  end;
end;

procedure TCFEdit.MouseUp(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
begin
  inherited;
  if FReadOnly then Exit;
  FSelecting := False;
end;

procedure TCFEdit.MoveCaretAfter(const AOffset: Integer);
var
  vS: string;
  vCaretLeft, vCaretHeight: Integer;
begin
  if AOffset < 0 then Exit;
  vCaretHeight := Height - 2 * FTopPadding;
  vCaretLeft := Left + FLeftPadding;

  if AOffset > 0 then
  begin
    vS := Copy(Text, 1, AOffset);
    vCaretLeft := vCaretLeft + TextMetricWidth(vS) + FDrawLeftOffs;
  end;

  DestroyCaret;
  CreateCaret(GetUIHandle, 0, 1, vCaretHeight);
  SetCaretPos(vCaretLeft, Top + FTopPadding);
  ShowCaret(GetUIHandle);
  PostMessage(GetUIHandle, WM_C_CARETCHANGE, 0, vCaretHeight);
end;

procedure TCFEdit.PasteText;
var
  vsClip, vS: string;
begin
  if not FReadOnly then
  begin
    DeleteSelect;
    vS := Text;
    vsClip := Clipboard.AsText;
    Insert(vsClip, vS, FSelStart + 1);
    Text := vS;
    FSelStart := FSelStart + Length(vsClip);
    if FDrawLeftOffs < 0 then
      FDrawLeftOffs := FDrawLeftOffs - TextMetricWidth(vsClip)
    else
      ScrollTo(FSelStart, csaRight);
    MoveCaretAfter(FSelStart);
    UpdateDirectUI;
  end;
end;

procedure TCFEdit.RightKeyPress;
begin
  DisSelect;
  if FSelStart < TextLength then
  begin
    Inc(FSelStart);
    ScrollTo(FSelStart, csaRight);
    MoveCaretAfter(FSelStart);
  end;
end;

procedure TCFEdit.SelectAll;
begin
  FSelecting := False;  // ����˫�����ƶ����ʱ����Ȼ˫��ȫѡ�����ƶ��ֽ�ѡ�н���λ�ø�Ϊ��ǰ��괦
  FSelStart := 0;
  FSelEnd := TextLength;
  ScrollTo(FSelEnd, csaRight);
  UpdateDirectUI;
  MoveCaretAfter(FSelEnd);
end;

function TCFEdit.SelectExist: Boolean;
begin
  Result := (FSelEnd >= 0) and (FSelEnd <> FSelStart);
end;

function TCFEdit.SelText: string;
begin
  if SelectExist then
    Result := Copy(Text, FSelStart + 1, FSelEnd - FSelStart)
  else
    Result := '';
end;

procedure TCFEdit.SetCanSelect(Value: Boolean);
begin
  if FCanSelect <> Value then
  begin
    FCanSelect := Value;
    if not FCanSelect then
      DisSelect;
  end;
end;

procedure TCFEdit.SetFocus(Value: Boolean);
begin
  inherited;
  if FFocus <> Value then
  begin
    if not Value then
    begin
      DisSelect;
      DestroyCaret;
      FSelStart := -1;
    end
    else
    begin
      FSelStart := 0;
      MoveCaretAfter(FSelStart);
    end;
    FFocus := Value;
    UpdateDirectUI;
  end;
end;

procedure TCFEdit.SetHelpText(Value: string);
begin
  if FHelpText <> Value then
  begin
    FHelpText := Value;
    UpdateDirectUI;
  end;
end;

procedure TCFEdit.SetReadOnly(Value: Boolean);
begin
  if FReadOnly <> Value then
  begin
    FReadOnly := Value;
    DisSelect;
    DestroyCaret;
  end;
end;

function TCFEdit.TextLength: Integer;
begin
  Result := Length(Text);
end;

procedure TCFEdit.WMLButtonDblClk(var Message: TWMLButtonDblClk);
begin
  inherited;
  SelectAll;
end;

end.