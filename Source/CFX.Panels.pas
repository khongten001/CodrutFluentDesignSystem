﻿unit CFX.Panels;

interface

uses
  SysUtils,
  Classes,
  Threading,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.ExtCtrls,
  CFX.Colors,
  CFX.UIConsts,
  CFX.Classes,
  CFX.Types,
  CFX.Animations,
  CFX.Linker,
  CFX.ThemeManager;

type

  FXPanel = class(TPanel, FXControl)
    private
      FCustomColors: FXColorSets;

      FDrawColors: FXColorSet;

      FAccentLine: boolean;
      FLineWidth: integer;

      procedure SetAccentLine(const Value: boolean);
      procedure SetAccentLineWidth(const Value: integer);

    protected
      procedure Paint; override;

      // Inherited
      procedure Resize; override;

    published
      property CustomColors: FXColorSets read FCustomColors write FCustomColors;
      property AccentLine: boolean read FAccentLine write SetAccentLine default False;
      property AccentLineWidth: integer read FLineWidth write SetAccentLineWidth;

    public
      constructor Create(AOwner : TComponent); override;
      destructor Destroy; override;

      // Draw
      procedure DrawAccentLine; virtual;

      // Interface
      function IsContainer: Boolean;
      procedure UpdateTheme(const UpdateChildren: Boolean);

      function Background: TColor;
  end;

  FXMinimisePanel = class(FXPanel, FXControl)
    private
      var
      FCustomColors: FXCompleteColorSets;
      FCustomHandleColor: FXColorStateSets;

      FHandleColor: FXColorStateSet;
      FDrawColors: FXCompleteColorSet;

      FHandleSize: integer;
      FHandleRound: integer;

      FText: string;
      FSkipRedrawFill: boolean;

      FContentFill: boolean;

      FMinimised: boolean;
      FAnimation: boolean;
      FControlState: FXControlState;
      FMouseInHandle: boolean;

      FImage: FXIconSelect;

      FAutoCursor: boolean;

      FAnim: TIntAni;
      FAnGoTo, FAnStart: integer;

      FDefaultHeight: integer;

      // UI
      function TrimEdges: boolean;
      procedure AnimateTranzition;

      // Set
      procedure SetState(AState: FXControlState);
      procedure SetHandleSize(const Value: integer);
      procedure SetHandleRound(const Value: integer);
      procedure StartToggle;
      procedure SetMinimiseState(statemin: boolean; instant: boolean = false);
      procedure SetMinimised(const Value: boolean);
      procedure SetText(const Value: string);
      procedure SetContentFill(const Value: boolean);
      procedure SetImage(const Value: FXIconSelect);

    protected
      procedure Paint; override;

      // Paint
      procedure PaintHandle;
      procedure PaintAccentLine;

      // Override
      procedure Resize; override;

      procedure MouseUp(Button : TMouseButton; Shift: TShiftState; X, Y : integer); override;
      procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
      procedure MouseDown(Button : TMouseButton; Shift: TShiftState; X, Y : integer); override;

    published
      property OnMouseEnter;
      property OnMouseLeave;
      property OnMouseDown;
      property OnMouseUp;
      property OnMouseMove;
      property OnClick;

      property Align;
      property Anchors;
      property Cursor;
      property Visible;
      property Enabled;
      property Constraints;
      property DoubleBuffered;

      property DefaultHeight: integer read FDefaultHeight write FDefaultHeight;
      property CustomColors: FXCompleteColorSets read FCustomColors write FCustomColors;
      property HandleCustomColors: FXColorStateSets read FCustomHandleColor write FCustomHandleColor;

      property HandleText: string read FText write SetText;
      property HandleSize: integer read FHandleSize write SetHandleSize default 60;
      property HandleRoundness: integer read FHandleRound write SetHandleRound default 15;

      property IsMinimised: boolean read FMinimised write SetMinimised;

      property Animation: boolean read FAnimation write FAnimation default false;
      property Image: FXIconSelect read FImage write SetImage;

      property ContentFill: boolean read FContentFill write SetContentFill default true;
      property DynamicCursor: boolean read FAutoCursor write FAutoCursor default true;

    public
      constructor Create(AOwner : TComponent); override;
      destructor Destroy; override;

      procedure DrawAccentLine; override;

      // State
      procedure ToggleMinimised;
      procedure ChangeMinimised(Minimised: boolean);

      // Interface
      function IsContainer: Boolean;
      procedure UpdateTheme(const UpdateChildren: Boolean);

      function Background: TColor;
  end;

implementation


{ CProgress }

procedure FXMinimisePanel.AnimateTranzition;
begin
  // Prepare
  FAnStart := Height;

  if FMinimised then
    FAnGoTo := FHandleSize
  else
    FAnGoTo := FDefaultHeight;

  // Prepare
  if FAnim.Finished then
    begin
      FAnim.Free;
      FAnim := TIntAni.Create;
    end;

  FAnim.AniFunctionKind := afkQuartic;
  FAnim.Duration := 40;
  FAnim.Step := 10;

  FAnim.StartValue := FAnStart;
  FAnim.DeltaValue := FAnGoTo - FAnStart;

  // Animate
  FAnim.OnSync := procedure(Value: integer)
  begin
    Height := Value;
  end;

  FAnim.OnDone := procedure
  begin
    TThread.Synchronize( nil, procedure
      var
        I: integer;
      begin
        for I := 0 to ControlCount - 1 do
          Controls[I].Invalidate;

        PaintHandle;
      end);
  end;

  FAnim.AniFunctionKind := afkLinear;
  FAnim.FreeOnTerminate := false;

  FAnim.Start;
end;

function FXMinimisePanel.Background: TColor;
begin
  if FContentFill then
    Result := FDrawColors.BackGroundInterior
  else
    Result := FDrawColors.BackGround;
end;

procedure FXMinimisePanel.ChangeMinimised(Minimised: boolean);
begin
  SetMinimiseState(Minimised);
end;

constructor FXMinimisePanel.Create(AOwner: TComponent);
begin
  inherited;
  Width := 350;
  Height := 200;

  ParentColor := true;
  ParentBackground := true;
  ShowCaption := false;
  TabStop := true;

  FSkipRedrawFill := true;

  FullRepaint := false;

  // Theme Manager building
  FCustomColors := FXCompleteColorSets.Create;
  FDrawColors := FXCompleteColorSet.Create(ThemeManager.SystemColorSet, ThemeManager.DarkTheme);
  FCustomHandleColor := FXColorStateSets.Create;
  FHandleColor := FXColorStateSet.Create(FCustomHandleColor, ThemeManager.DarkTheme);

  FAnim := TIntAni.Create;

  // Default Font
  Font.Size := 11;
  Font.Name := 'Segoe UI Semibold';

  FImage := FXIconSelect.Create(Self);

  // Default Handle
  FHandleRound := MINIMISE_PANEL_ROUND;
  FHandleSize := MINIMISE_PANEL_SIZE;
  FContentFill := true;

  FAutoCursor := true;

  FAnimation := false;
  FText := 'Minimised Panel';

  FDefaultHeight := Height;
end;

destructor FXMinimisePanel.Destroy;
begin
  FreeAndNil(FImage);
  FreeAndNil(FAnim);
  FreeAndNil(FCustomHandleColor);
  FreeAndNil(FCustomColors);
  inherited;
end;


procedure FXMinimisePanel.DrawAccentLine;
begin
  // No nothing
end;

function FXMinimisePanel.IsContainer: Boolean;
begin
  Result := true;
end;

procedure FXMinimisePanel.MouseDown(Button: TMouseButton; Shift: TShiftState; X,
  Y: integer);
begin
  inherited;
  if FMouseInHandle then
    SetState(FXControlState.Press);
end;

procedure FXMinimisePanel.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  FMouseInHandle := (Y <= FHandleSize);

  if FAutoCursor then
    begin
      if FMouseInHandle then
        Cursor := crHandPoint
      else
        Cursor := crDefault;
    end;

  if FMouseInHandle and (FControlState = FXControlState.None) then { Cant be csPress, as if you hold the button while dragging it will hide the effect! }
    SetState(FXControlState.Hover)
      else
        if (not FMouseInHandle) and (FControlState <> FXControlState.None) then
          SetState(FXControlState.None)
end;

procedure FXMinimisePanel.MouseUp(Button: TMouseButton; Shift: TShiftState; X,
  Y: integer);
begin
  inherited;

  SetState(FXControlState.Hover);

  if FMouseInHandle then
    StartToggle;
end;

procedure FXMinimisePanel.Paint;
var
  TemporaryCanvas: TBitMap;
  DrawRect: TRect;
begin
  inherited;
  // Handle
  PaintHandle;

  // Prepare Settings
  DrawRect := Rect(0, 0, Width, Height - FHandleSize - HANDLE_SEPARATOR);

  // Exit running useless code
  if DrawRect.Height <=0 then
    Exit;

  // Canvas
  TemporaryCanvas := TBitMap.Create;
  TemporaryCanvas.Width := DrawRect.Width;
  TemporaryCanvas.Height := DrawRect.Height;

  Self.Color := FDrawColors.BackGround;

  // TMP Canvas
  with TemporaryCanvas.canvas do begin
    Brush.Color := FDrawColors.BackGround;
    FillRect(cliprect);

    // Font
    Font.Assign(Self.Font);
    Font.Color := FDrawColors.ForeGround;

    Pen.Style := psClear;

    // Color
    if FContentFill then
      begin
        Brush.Color := FDrawColors.BackGroundInterior;

        RoundRect(0, 0, DrawRect.Width, DrawRect.Height, FHandleRound, FHandleRound);

        { Secondary }
        if TrimEdges then
          Rectangle(0, 0, DrawRect.Width, DrawRect.Height div 2);
      end;
  end;

  canvas.CopyRect(Rect(0, abs(DrawRect.Height-Height), Width, Height),
                  TemporaryCanvas.Canvas, TemporaryCanvas.Canvas.ClipRect);

  TemporaryCanvas.Free;
end;

procedure FXMinimisePanel.PaintAccentLine;
begin
end;

procedure FXMinimisePanel.PaintHandle;
var
  tmp: TBitMap;
  TmpFont: TFont;
  IconRect: TRect;
  DrawRect: TRect;
  TLeft: integer;
  I: string;
begin
  inherited;
  // Prepare Settings
  DrawRect := Rect(0, 0, Width, FHandleSize);

  tmp := TBitMap.Create;
  tmp.Height := DrawRect.Height;
  tmp.Width := DrawRect.Width;

  // TMP Canvas
  with tmp.canvas do begin
    Brush.Color := FDrawColors.BackGround;
    FillRect(cliprect);

    // Font
    Font.Assign(Self.Font);
    Font.Color := FDrawColors.ForeGround;

    Pen.Style := psClear;

    // Handle
    Brush.Color := FHandleColor.GetColor(false, FControlState);

    //Brush.Color := FDrawColors.BackGroundInterior;

    RoundRect(0, 0, Width, FHandleSize, FHandleRound, FHandleRound);

    { Square Next to contentfill }
    if TrimEdges then
      Rectangle(0, FHandleSize div 2, Width, FHandleSize);

    // Icon
    if FImage.Enabled then
    begin
      TLeft := FHandleSize div 2 + MINIMISE_ICON_MARGIN * 2;

      IconRect := Rect(MINIMISE_ICON_MARGIN, FHandleSize div 4, TLeft - MINIMISE_ICON_MARGIN, FHandleSize - FHandleSize div 4);

      if FImage.IconType <> FXIconType.SegoeIcon then
        FImage.DrawIcon(tmp.Canvas, IconRect)
      else
        begin
          { Font Icon }
          TmpFont := TFont.Create;
          try
            TmpFont.Assign(Font);

            Font := TFont.Create;
            Font.Name := ThemeManager.IconFont;
            Font.Color := FDrawColors.ForeGround;
            Font.Size := round(Self.FHandleSize / 4);;

            I := FImage.SelectSegoe;
            TextRect(IconRect, I, [tfSingleLine, tfVerticalCenter, tfCenter]);

            Font.Assign(TmpFont);
          finally
            TmpFont.Free
          end;
        end;
    end
      else
        TLeft := MINIMISE_ICON_MARGIN;

    // Font
    Font.Assign(Self.Font);
    Font.Color := FDrawColors.ForeGround;

    // Text
    Brush.Style := bsClear;
    TextOut(tleft, FHandleSize div 2 - TextHeight(FText) div 2, FText);

    Pen.Style := psSolid;

    // Icon
    Font := TFont.Create;
    if FMinimised then
      i := ''
    else
      i := '';

    Font.Size := round(Self.FHandleSize / 6);
    Font.Name := ThemeManager.IconFont;
    Font.Color := FDrawColors.ForeGround;

    IconRect := Rect(Width - FHandleSize, 0, Width, FHandleSize);
    TextRect(IconRect, i, [tfSingleLine, tfVerticalCenter, tfCenter]);
    // TextOut(Width - TextWidth(i) - MINIMISE_ICON_MARGIN * 2, FHandleSize div 2 - TextHeight(i) div 2 - 3, i);

    // Reset Settings
    FSkipRedrawFill := false;
  end;

  canvas.CopyRect(DrawRect, tmp.Canvas, DrawRect);
end;

procedure FXMinimisePanel.Resize;
begin
  inherited;
  Repaint;
end;

procedure FXMinimisePanel.SetContentFill(const Value: boolean);
begin
  FContentFill := Value;
end;

procedure FXMinimisePanel.SetHandleRound(const Value: integer);
begin
  FHandleRound := Value;

  Paint;
end;

procedure FXMinimisePanel.SetHandleSize(const Value: integer);
begin
  FHandleSize := Value;

  if FMinimised then
    Self.Height := Value;
end;

procedure FXMinimisePanel.SetImage(const Value: FXIconSelect);
begin
  FImage := Value;

  Paint;
end;

procedure FXMinimisePanel.SetMinimised(const Value: boolean);
begin
  FMinimised := Value;

  // Design Mode
  if csDesigning in ComponentState then
    begin
      if IsMinimised then
        begin
          if Height > HandleSize then
            FDefaultHeight := Height;

          Height := HandleSize;
        end
      else
        begin
          Height := FDefaultHeight;
        end;
    end;

  // Update State
  SetMinimiseState(Value, true);
end;

procedure FXMinimisePanel.SetMinimiseState(statemin: boolean; instant: boolean);
begin
  // Exit if already Minimised
  if statemin = FMinimised then
    Exit;

  FMinimised := NOT FMinimised;

  if (FAnim <> nil) and (FAnim.Running) then
    Exit;

  // Instant or No Animation
  if (NOT FAnimation) or Instant then
  begin
    if statemin then
      Height := FHandleSize
    else
      Height := FDefaultHeight;
  end
    else
      // Animated
      AnimateTranzition;
end;

procedure FXMinimisePanel.SetState(AState: FXControlState);
begin
  FControlState := AState;

  FSkipRedrawFill := true;

  // Draw
  PaintHandle;
end;

procedure FXMinimisePanel.SetText(const Value: string);
begin
  FText := Value;

  Paint;
end;

procedure FXMinimisePanel.StartToggle;
begin
  if not FAnim.Running then
    SetMinimiseState(NOT FMinimised)
end;

procedure FXMinimisePanel.ToggleMinimised;
begin
  StartToggle;
end;

function FXMinimisePanel.TrimEdges: boolean;
begin
  Result := (not (FMinimised and not FAnim.Running)) and FContentFill
end;

procedure FXMinimisePanel.UpdateTheme(const UpdateChildren: Boolean);
var
  I: integer;
begin
  // Access Theme Manager
  if FCustomColors.Enabled then
    FDrawColors := FXCompleteColorSet.Create( FCustomColors, ThemeManager.DarkTheme )
  else
    FDrawColors := FXCompleteColorSet.Create( ThemeManager.SystemColorSet, ThemeManager.DarkTheme );

  if FCustomHandleColor.Enabled then
    FHandleColor := FXColorStateSet.Create(FCustomHandleColor, ThemeManager.DarkTheme)
  else
    begin
      FHandleColor := FXColorStateSet.Create;
      FHandleColor.ForeGroundNone := FDrawColors.ForeGround;
      FHandleColor.ForeGroundHover := FDrawColors.ForeGround;
      FHandleColor.ForeGroundPress := ChangeColorLight( FDrawColors.ForeGround, -20);

      FHandleColor.BackGroundNone := FDrawColors.BackGroundInterior;
      FHandleColor.BackGroundHover := ChangeColorLight( FDrawColors.BackGroundInterior, MINIMISE_COLOR_CHANGE);
      FHandleColor.BackGroundPress := ChangeColorLight( FDrawColors.BackGroundInterior, -MINIMISE_COLOR_CHANGE);
    end;

  // Legacy Control Support
  if ThemeManager.LegacyFontColor then
    Font.Color := FDrawColors.ForeGround;

  Self.Paint;

  // Update Children
  if IsContainer and UpdateChildren then
    begin
      for i := 0 to ControlCount - 1 do
        if Supports(Controls[i], FXControl) then
          (Controls[i] as FXControl).UpdateTheme(UpdateChildren);
    end;
end;

{ FXPanel }

function FXPanel.Background: TColor;
begin
  Result := FDrawColors.Background;
end;

constructor FXPanel.Create(AOwner: TComponent);
begin
  inherited;

  FullRepaint := false;

  FCustomColors := FXColorSets.Create();
  FDrawColors := FXColorSet.Create(ThemeManager.SystemColorSet, ThemeManager.DarkTheme);

  FLineWidth := PANEL_LINE_WIDTH;

  BevelKind := bkNone;
  BevelOuter := bvNone;
end;

destructor FXPanel.Destroy;
begin

  inherited;
end;

procedure FXPanel.DrawAccentLine;
begin
  if FAccentLine then
    with Canvas do
      begin
        Brush.Color := FDrawColors.Accent;
        Pen.Style :=psClear;

        RoundRect( PANEL_LINE_SPACING, PANEL_LINE_SPACING, PANEL_LINE_SPACING + FLineWidth, Height - PANEL_LINE_SPACING,
                    PANEL_LINE_ROUND, PANEL_LINE_ROUND);
      end;
end;

function FXPanel.IsContainer: Boolean;
begin
  Result := true;
end;

procedure FXPanel.Paint;
begin
  DrawAccentLine;

  inherited;
end;

procedure FXPanel.Resize;
begin
  inherited;
  if AccentLine and not FullRepaint then
    DrawAccentLine;
end;

procedure FXPanel.SetAccentLine(const Value: boolean);
begin
  FAccentLine := Value;

  if not (csReading in ComponentState) then
    RePaint;
end;

procedure FXPanel.SetAccentLineWidth(const Value: integer);
begin
  FLineWidth := Value;

  if not (csReading in ComponentState) then
    RePaint;
end;

procedure FXPanel.UpdateTheme(const UpdateChildren: Boolean);
var
  I: integer;
begin
  // Access Theme Manager
  if FCustomColors.Enabled then
    FDrawColors := FXColorSet.Create( FCustomColors, ThemeManager.DarkTheme )
  else
    FDrawColors := FXColorSet.Create( ThemeManager.SystemColorSet, ThemeManager.DarkTheme);

  // Legacy Control Support
  if ThemeManager.LegacyFontColor then
    Font.Color := FDrawColors.ForeGround;

  Invalidate;

  // Update Children
  if IsContainer and UpdateChildren then
    begin
      for i := 0 to ControlCount - 1 do
        if Supports(Controls[i], FXControl) then
          (Controls[i] as FXControl).UpdateTheme(UpdateChildren);
    end;
end;

end.
