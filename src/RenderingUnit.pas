unit RenderingUnit;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.Layouts,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  FMX.Objects,
  FMX.ScrollBox,
  FMX.Memo,
  FMX.Effects,
  {$IFDEF MSWINDOWS}
    FMX.Platform.Win, Winapi.Windows, Winapi.TlHelp32;
  {$ENDIF MSWINDOWS}
  {$IFDEF MACOS}
  Posix.Unistd;
  {$ENDIF MACOS}

type
  TRenderingForm = class(TForm)
    Title: TLabel;
    RenderingStatusBar: TStatusBar;
    totalProgressBottomLabel: TLabel;
    statusBarSeparator1: TLine;
    abortRenderingButton: TButton;
    statusBarTopLayout: TLayout;
    RenderingToolBar: TToolBar;
    statusBarSeparator2: TLine;
    TotalProgressBar: TProgressBar;
    totalProgressLabel: TLabel;
    framesLabel: TLabel;
    topLayoutTitle: TLayout;
    totalProgressPercentage: TLabel;
    renderingTimer: TTimer;
    emptyLabel: TLabel;
    VertScrollBox1: TVertScrollBox;
    AErenderLayout: TLayout;
    BlurEffect1: TBlurEffect;
    FFMPEGConcatLayout: TLayout;
    Rectangle1: TRectangle;
    Label1: TLabel;
    ProgressBar1: TProgressBar;
    Label2: TLabel;
    Button1: TButton;
    procedure ShowLogButtonClick (Sender: TObject);
    procedure renderingTimerTimer(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure abortRenderingButtonClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
  public
    { Public declarations }
    {$IFDEF MSWINDOWS}procedure CreateHandle; override;{$ENDIF MSWINDOWS}
  end;
  TRenderGroup = record
    TRenderGroupBox: TGroupBox;
      TRenderGroupBoxMainLayout: TLayout;
        TRenderProgressBar: TProgressBar;
        TRenderProgressLabel: TLabel;
        TRenderShowLogButton: TButton;
      TLogMemo: TMemo;
  end;

var
  RenderingForm: TRenderingForm;
  VISIBLE: Boolean = False;
  RenderGroups: TArray<TRenderGroup>;
  LogIncrement: Integer = 0;

implementation

{$R *.fmx}

uses
  Unit1;

{$IFDEF MSWINDOWS}
procedure TRenderingForm.CreateHandle;
begin
  inherited CreateHandle;

  SetWindowLong(WindowHandleToPlatform(Handle).Wnd, GWL_EXSTYLE,
    GetWindowLong(WindowHandleToPlatform(Handle).Wnd, GWL_EXSTYLE) or WS_EX_APPWINDOW);
end;
{$ENDIF MSWINDOWS}

function LimitInt (I: Integer): Integer;
begin
  if I < 0 then
    Result := 0
  else
    Result := I;
end;

procedure TRenderingForm.abortRenderingButtonClick(Sender: TObject);
begin
  try
    begin
      {$IFDEF MSWINDOWS}KillProcess('AfterFX.com');{$ENDIF MSWINDOWS}
      {$IFDEF MACOS}KillProcess('aerendercore');{$ENDIF MACOS}
      for var i := 0 to High(RenderGroups) do
        begin
          RenderGroups[i].TLogMemo.Free;
          RenderGroups[i].TRenderShowLogButton.Free;
          RenderGroups[i].TRenderProgressLabel.Free;
          RenderGroups[i].TRenderProgressBar.Free;
          RenderGroups[i].TRenderGroupBoxMainLayout.Free;
          RenderGroups[i].TRenderGroupBox.Free;

          {$IFDEF MSWNDOWS}DeleteFile(Unit1.LogFiles[i]);{$ENDIF MSWINDOWS}
        end;
      emptyLabel.Visible := True;
      emptyLabel.Enabled := True;
      renderingTimer.Enabled := False;
      totalProgressPercentage.Text := '0%'
    end
  except
    on Exception do
      ShowMessage ('Nothing to abort!')
  end;
end;

procedure TRenderingForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  VISIBLE := False;
  if TotalProgressBar.Value = TotalProgressBar.Max then
    begin
      abortRenderingButtonClick(Sender);
      TotalProgressBar.Value := 0;
    end;
end;

procedure TRenderingForm.FormShow(Sender: TObject);
begin
  VISIBLE := True;
  if Unit1.RenderWindowSender = Form1.launchButton then
    begin
      if Length(Unit1.LogFiles) = 0 then
        begin
          emptyLabel.Visible := True;
          emptyLabel.Enabled := True;
        end
      else
        begin
          emptyLabel.Visible := False;
          emptyLabel.Enabled := False;

          SetLength (RenderGroups, Length(Unit1.LogFiles));

          for var i := 0 to High (RenderGroups) do
            begin
              //Initialize GroupBox
              RenderGroups[i].TRenderGroupBox := TGroupBox.Create(Self);
              RenderGroups[i].TRenderGroupBox.Parent := VertScrollBox1;
              RenderGroups[i].TRenderGroupBox.Align := TAlignLayout.Top;
              RenderGroups[i].TRenderGroupBox.Margins.Left := 5;
              RenderGroups[i].TRenderGroupBox.Margins.Bottom := 5;
              RenderGroups[i].TRenderGroupBox.Position.X := 5;
              RenderGroups[i].TRenderGroupBox.Height := 75;
              RenderGroups[i].TRenderGroupBox.Text := ExtractFileName(Unit1.LogFiles[i]);
              RenderGroups[i].TRenderGroupBox.Tag := i;

              //Initialize GroupBox MainLayout
              RenderGroups[i].TRenderGroupBoxMainLayout := TLayout.Create(Self);
              RenderGroups[i].TRenderGroupBoxMainLayout.Parent := RenderGroups[i].TRenderGroupBox;
              RenderGroups[i].TRenderGroupBoxMainLayout.Align := TAlignLayout.Top;
              RenderGroups[i].TRenderGroupBoxMainLayout.Margins.Left := 5;
              RenderGroups[i].TRenderGroupBoxMainLayout.Margins.Top := 20;
              RenderGroups[i].TRenderGroupBoxMainLayout.Margins.Right := 5;
              RenderGroups[i].TRenderGroupBoxMainLayout.Margins.Bottom := 5;

              //Initialize GroupBox MainLayout ProgressBar
              RenderGroups[i].TRenderProgressBar := TProgressBar.Create(Self);
              RenderGroups[i].TRenderProgressBar.Parent := RenderGroups[i].TRenderGroupBoxMainLayout;
              RenderGroups[i].TRenderProgressBar.Align := TAlignLayout.Top;
              RenderGroups[i].TRenderProgressBar.Orientation := TOrientation.Horizontal;
              RenderGroups[i].TRenderProgressBar.StyleLookup := 'progressbarstyle';
              RenderGroups[i].TRenderProgressBar.Margins.Left := 5;
              RenderGroups[i].TRenderProgressBar.Margins.Top := 10;
              RenderGroups[i].TRenderProgressBar.Margins.Right := 5;
              RenderGroups[i].TRenderProgressBar.Height := 10;
              RenderGroups[i].TRenderProgressBar.Min := 0;
              RenderGroups[i].TRenderProgressBar.Value := 0;
              if Form1.threadsSwitch.IsChecked then
                RenderGroups[i].TRenderProgressBar.Max := Form1.threadsGrid.Cells[1, i].ToSingle() - Form1.threadsGrid.Cells[0, i].ToSingle() + 50
              else
                if Form1.outFrame.Text.IsEmpty or Form1.compSwitch.IsChecked then
                  RenderGroups[i].TRenderProgressBar.Max := 1
                else
                  RenderGroups[i].TRenderProgressBar.Max := Form1.outFrame.Text.ToSingle() + 50;

              //Initialise GroupBox MainLayout ProgressLabel
              RenderGroups[i].TRenderProgressLabel := TLabel.Create(Self);
              RenderGroups[i].TRenderProgressLabel.Parent := RenderGroups[i].TRenderGroupBoxMainLayout;
              RenderGroups[i].TRenderProgressLabel.Align := TAlignLayout.Client;
              RenderGroups[i].TRenderProgressLabel.Margins.Left := 5;
              RenderGroups[i].TRenderProgressLabel.AutoSize := False;
              RenderGroups[i].TRenderProgressLabel.TextSettings.WordWrap := False;
              if Form1.threadsSwitch.IsChecked then
                RenderGroups[i].TRenderProgressLabel.Text := '0%'
              else
                if Form1.outFrame.Text.IsEmpty then
                  RenderGroups[i].TRenderProgressLabel.Text := 'N/A'
                else
                  RenderGroups[i].TRenderProgressLabel.Text := '0%';

              //Initialize GroupBox MainLayout ShowLogButton
              RenderGroups[i].TRenderShowLogButton := TButton.Create(Self);
              RenderGroups[i].TRenderShowLogButton.Parent := RenderGroups[i].TRenderGroupBoxMainLayout;
              RenderGroups[i].TRenderShowLogButton.Align := TAlignLayout.Right;
              RenderGroups[i].TRenderShowLogButton.Width := 150;
              RenderGroups[i].TRenderShowLogButton.Margins.Top := 5;
              RenderGroups[i].TRenderShowLogButton.Margins.Right := 5;
              RenderGroups[i].TRenderShowLogButton.Margins.Bottom := 5;
              RenderGroups[i].TRenderShowLogButton.Text := 'Toggle Render Log';
              RenderGroups[i].TRenderShowLogButton.Tag := i;
              RenderGroups[i].TRenderShowLogButton.OnClick := ShowLogButtonClick;

              //Initialise GroupBox LogMemo
              RenderGroups[i].TLogMemo := TMemo.Create(Self);
              RenderGroups[i].TLogMemo.Parent := RenderGroups[i].TRenderGroupBox;
              RenderGroups[i].TLogMemo.Align := TAlignLayout.Client;
              RenderGroups[i].TLogMemo.Margins.Left := 5;
              RenderGroups[i].TLogMemo.Margins.Right := 5;
              RenderGroups[i].TLogMemo.Margins.Bottom := 5;
              RenderGroups[i].TLogMemo.ReadOnly := True;
              RenderGroups[i].TLogMemo.WordWrap := True;
              RenderGroups[i].TLogMemo.Visible := False;
              RenderGroups[i].TLogMemo.TextSettings.Font.Family := 'Consolas';
            end;
        end;
      renderingTimer.Enabled := True;
    end;
end;

procedure TRenderingForm.renderingTimerTimer(Sender: TObject);
type
  TRenderData = record
    LogFile: TStrings;
    Data: TStrings;
    Stream: TStream;
    State: String[6];
  end;
var
  Render: TArray<TRenderData>;
  i: Integer;
begin
  var Finished: Integer := 0;
  SetLength (Render, Length(Unit1.LogFiles));

  for var j := 0 to High(Render) do
    begin
      Render[j].Data := TStrings.Create;
      Render[j].State := '';
    end;

  for i := 0 to High(Render) do
    begin
      var sum: Integer := 0;
      Render[i].LogFile := TStringList.Create;
      Render[i].LogFile.Encoding.UTF8;

      try
        Render[i].Stream := TFileStream.Create(LogFiles[i], fmOpenRead or fmShareDenyNone);
        try
          Render[i].LogFile.LoadFromStream(Render[i].Stream);
        finally
          Render[i].Stream.Free;
        end;

        if Render[i].LogFile.Count > RenderGroups[i].TLogMemo.Lines.Count then
          begin
            if Form1.threadsSwitch.IsChecked or (not Form1.compSwitch.IsChecked and not Form1.outFrame.Text.IsEmpty) then
              begin
                RenderGroups[i].TRenderProgressBar.Value := Render[i].LogFile.Count;
                RenderGroups[i].TRenderProgressLabel.Text := Round((RenderGroups[i].TRenderProgressBar.Value / RenderGroups[i].TRenderProgressBar.Max) * 100).ToString + '%';
              end
            else
              if Form1.outFrame.Text.IsEmpty then
                begin
                  RenderGroups[i].TRenderProgressLabel.Text := 'Rendering';
                end
              else
                RenderGroups[i].TRenderProgressLabel.Text := Round((RenderGroups[i].TRenderProgressBar.Value / RenderGroups[i].TRenderProgressBar.Max) * 100).ToString + '%';
            RenderGroups[i].TLogMemo.Lines.Add(Render[i].LogFile[RenderGroups[i].TLogMemo.Lines.Count]);
            RenderGroups[i].TLogMemo.GoToTextEnd;
          end;

        for var j := 0 to High(RenderGroups) do
          if (Form1.threadsSwitch.IsChecked) and (not Form1.outFrame.Text.IsEmpty) then
            inc (sum, LimitInt(RenderGroups[j].TRenderProgressBar.Value.ToString.ToInteger))
          else
            inc (sum, RenderGroups[j].TRenderProgressBar.Value.ToString.ToInteger);

        TotalProgressBar.Value := sum;
        totalProgressPercentage.Text := Round((TotalProgressBar.Value / TotalProgressBar.Max) * 100).ToString + '%';

        {framesLabel.Text := 'tpb.max = ' + TotalProgressBar.max.ToString + '; '
                          + 'tpb.val = ' + TotalProgressBar.Value.ToString + '; '
                          + 'rg[0].val = ' + RenderGroups[0].TRenderProgressBar.Value.ToString + '; '
                          + 'rg[0].max = ' + RenderGroups[0].TRenderProgressBar.Max.ToString + '; '
                          + 'rg[1].val = ' + RenderGroups[1].TRenderProgressBar.Value.ToString + '; '
                          + 'rg[1].max = ' + RenderGroups[1].TRenderProgressBar.Max.ToString + '; ';}

        if RenderGroups[i].TLogMemo.Text.Contains('Finished composition') then
          begin
            Render[i].State := 'finish';
            RenderGroups[i].TRenderProgressLabel.Text := 'Finished';
            RenderGroups[i].TRenderProgressBar.Value := RenderGroups[i].TRenderProgressBar.Max;
          end;
        if RenderGroups[i].TLogMemo.Text.Contains('aerender ERROR') or RenderGroups[i].TLogMemo.Text.Contains('aerender Error') then
          begin
            Render[i].State := 'error';
            RenderGroups[i].TRenderProgressLabel.Text := 'ERROR: See log for more info';
            RenderGroups[i].TRenderProgressBar.Value := RenderGroups[i].TRenderProgressBar.Max;
            RenderGroups[i].TRenderProgressBar.StyleLookup := 'progressbarerrorstyle'
          end;
      finally
        Render[i].LogFile.Free;
      end;
    end;

    for var j := 0 to High(Render) do
      if Render[j].State = 'finish' then
        inc (Finished);

    if Finished = Length(LogFiles) then
      begin
        Sleep (2000);
        TotalProgressBar.Value := TotalProgressBar.Max;
        totalProgressPercentage.Text := '100%';
        renderingTimer.Enabled := False;
      end;
end;

procedure TRenderingForm.ShowLogButtonClick (Sender: TObject);
begin
  var visibleMemos: Integer := 0;
  if RenderGroups[TButton(Sender).Tag].TLogMemo.Visible = False then
    begin
      RenderGroups[TButton(Sender).Tag].TLogMemo.Visible := True;
      RenderGroups[TButton(Sender).Tag].TRenderGroupBox.Height := RenderGroups[TButton(Sender).Tag].TRenderGroupBox.Height + 175;

      for var i := 0 to High(RenderGroups) do
        if RenderGroups[i].TLogMemo.Visible = True then
          inc (visibleMemos);
      if visibleMemos <> 0 then
        LogIncrement := 175
      else
        LogIncrement := 0;
    end
  else
    begin
      RenderGroups[TButton(Sender).Tag].TLogMemo.Visible := False;
      RenderGroups[TButton(Sender).Tag].TRenderGroupBox.Height := RenderGroups[TButton(Sender).Tag].TRenderGroupBox.Height - 175;

      for var i := 0 to High(RenderGroups) do
        if RenderGroups[i].TLogMemo.Visible = True then
          inc (visibleMemos);
      if visibleMemos <> 0 then
        LogIncrement := 175
      else
        LogIncrement := 0;
    end;
end;

end.
