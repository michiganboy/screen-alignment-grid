# Screen Alignment Grid
# Transparent click-through grid/centerline overlay for arranging UI elements.
# Run with: powershell.exe -ExecutionPolicy Bypass -File .\ScreenAlignmentGrid.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDirectory = Split-Path -Parent $PSCommandPath
[Environment]::SetEnvironmentVariable("SCREEN_ALIGNMENT_GRID_DIR", $scriptDirectory, "Process")

$source = @"
using System;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.IO;

namespace ScreenAlignmentGrid
{
    public class NoWheelTrackBar : TrackBar
    {
        private const int WM_MOUSEWHEEL = 0x020A;

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WM_MOUSEWHEEL)
            {
                return;
            }
            base.WndProc(ref m);
        }
    }

    public class GridOverlayForm : Form
    {
        private const int WS_EX_TRANSPARENT = 0x00000020;
        private const int WS_EX_LAYERED = 0x00080000;
        private const int WS_EX_TOOLWINDOW = 0x00000080;
        private const int WS_EX_TOPMOST = 0x00000008;

        private const int WM_HOTKEY = 0x0312;
        private const uint MOD_ALT = 0x0001;
        private const uint MOD_CONTROL = 0x0002;

        private const int HOTKEY_TOGGLE = 1;
        private const int HOTKEY_CENTER_ONLY = 2;
        private const int HOTKEY_GRID_SMALLER = 3;
        private const int HOTKEY_GRID_LARGER = 4;
        private const int HOTKEY_OPACITY_DOWN = 5;
        private const int HOTKEY_OPACITY_UP = 6;
        private const int HOTKEY_EXIT = 7;
        private const int HOTKEY_NEXT_MONITOR = 8;
        private const int HOTKEY_ALL_MONITORS = 9;
        private const int HOTKEY_AXIS_LABELS = 10;
        private const int HOTKEY_SETTINGS = 11;

        [DllImport("user32.dll")]
        private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

        [DllImport("user32.dll")]
        private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        private const int SW_SHOWNORMAL = 1;
        private const int SW_SHOW = 5;
        private const int SW_RESTORE = 9;

        private bool overlayEnabled = true;
        private bool centerOnly = false;
        private bool allMonitors = false;
        private bool showAxisLabels = true;
        private int selectedMonitorIndex = 0;
        private int gridSize = 50;
        private int alpha = 200;
        private int centerAlpha = 255;
        private Color gridColor = Color.FromArgb(0, 220, 255);
        private Color majorGridColor = Color.FromArgb(0, 255, 180);
        private Color centerColor = Color.FromArgb(255, 80, 80);
        private Color borderColor = Color.White;
        private Color labelColor = Color.White;
        private int axisLabelSize = 10;
        private int axisLabelOffset = 10;
        private int activeColorPresetIndex = 0;
        private bool suppressPresetChanged = false;
        private Color customGridColor = Color.FromArgb(0, 220, 255);
        private Color customMajorGridColor = Color.FromArgb(0, 255, 180);
        private Color customCenterColor = Color.FromArgb(255, 80, 80);
        private Color customLabelColor = Color.White;
        private Color customBorderColor = Color.White;
        private readonly Color transparentColor = Color.Magenta;
        private NotifyIcon trayIcon;
        private Form settingsForm;
        private readonly Font settingsFont = new Font("Segoe UI", 12F, FontStyle.Regular);

        public GridOverlayForm()
        {
            Rectangle bounds = SystemInformation.VirtualScreen;
            StartPosition = FormStartPosition.Manual;
            Bounds = bounds;
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            TopMost = true;
            BackColor = transparentColor;
            TransparencyKey = transparentColor;
            DoubleBuffered = true;

            trayIcon = new NotifyIcon();
            trayIcon.Icon = SystemIcons.Application;
            trayIcon.Visible = true;
            trayIcon.Text = "Screen Alignment Grid";
            var menu = new ContextMenuStrip();
            menu.Items.Add("Settings (Ctrl+Alt+S)", null, (s, e) => ShowSettingsWindow());
            menu.Items.Add("Toggle grid (Ctrl+Alt+G)", null, (s, e) => ToggleOverlay());
            menu.Items.Add("Center lines only (Ctrl+Alt+C)", null, (s, e) => ToggleCenterOnly());
            menu.Items.Add("Next monitor (Ctrl+Alt+M)", null, (s, e) => NextMonitor());
            menu.Items.Add("All monitors (Ctrl+Alt+A)", null, (s, e) => ToggleAllMonitors());
            menu.Items.Add("Axis labels (Ctrl+Alt+N)", null, (s, e) => ToggleAxisLabels());
            menu.Items.Add("Exit (Ctrl+Alt+Esc)", null, (s, e) => Close());
            trayIcon.ContextMenuStrip = menu;

            trayIcon.ShowBalloonTip(
                2500,
                "Screen Alignment Grid",
                "Settings open by default | Ctrl+Alt+S settings | Ctrl+Alt+G toggle",
                ToolTipIcon.Info
            );

            Shown += (s, e) => BeginInvoke(new Action(ShowSettingsWindow));
        }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.ExStyle |= WS_EX_TRANSPARENT | WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_TOPMOST;
                return cp;
            }
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            RegisterHotKey(Handle, HOTKEY_TOGGLE, MOD_CONTROL | MOD_ALT, (uint)Keys.G);
            RegisterHotKey(Handle, HOTKEY_CENTER_ONLY, MOD_CONTROL | MOD_ALT, (uint)Keys.C);
            RegisterHotKey(Handle, HOTKEY_GRID_SMALLER, MOD_CONTROL | MOD_ALT, (uint)Keys.OemMinus);
            RegisterHotKey(Handle, HOTKEY_GRID_LARGER, MOD_CONTROL | MOD_ALT, (uint)Keys.Oemplus);
            RegisterHotKey(Handle, HOTKEY_OPACITY_DOWN, MOD_CONTROL | MOD_ALT, (uint)Keys.Down);
            RegisterHotKey(Handle, HOTKEY_OPACITY_UP, MOD_CONTROL | MOD_ALT, (uint)Keys.Up);
            RegisterHotKey(Handle, HOTKEY_EXIT, MOD_CONTROL | MOD_ALT, (uint)Keys.Escape);
            RegisterHotKey(Handle, HOTKEY_NEXT_MONITOR, MOD_CONTROL | MOD_ALT, (uint)Keys.M);
            RegisterHotKey(Handle, HOTKEY_ALL_MONITORS, MOD_CONTROL | MOD_ALT, (uint)Keys.A);
            RegisterHotKey(Handle, HOTKEY_AXIS_LABELS, MOD_CONTROL | MOD_ALT, (uint)Keys.N);
            RegisterHotKey(Handle, HOTKEY_SETTINGS, MOD_CONTROL | MOD_ALT, (uint)Keys.S);
        }

        protected override void OnHandleDestroyed(EventArgs e)
        {
            for (int i = 1; i <= 11; i++) UnregisterHotKey(Handle, i);
            if (settingsForm != null && !settingsForm.IsDisposed)
            {
                settingsForm.Close();
            }
            if (trayIcon != null)
            {
                trayIcon.Visible = false;
                trayIcon.Dispose();
            }
            base.OnHandleDestroyed(e);
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WM_HOTKEY)
            {
                int id = m.WParam.ToInt32();
                switch (id)
                {
                    case HOTKEY_TOGGLE:
                        ToggleOverlay();
                        return;
                    case HOTKEY_CENTER_ONLY:
                        ToggleCenterOnly();
                        return;
                    case HOTKEY_GRID_SMALLER:
                        gridSize = Math.Max(10, gridSize - 10);
                        Invalidate();
                        return;
                    case HOTKEY_GRID_LARGER:
                        gridSize = Math.Min(200, gridSize + 10);
                        Invalidate();
                        return;
                    case HOTKEY_OPACITY_DOWN:
                        alpha = Math.Max(20, alpha - 15);
                        centerAlpha = Math.Max(80, centerAlpha - 15);
                        Invalidate();
                        return;
                    case HOTKEY_OPACITY_UP:
                        alpha = Math.Min(200, alpha + 15);
                        centerAlpha = Math.Min(255, centerAlpha + 15);
                        Invalidate();
                        return;
                    case HOTKEY_EXIT:
                        Close();
                        return;
                    case HOTKEY_NEXT_MONITOR:
                        NextMonitor();
                        return;
                    case HOTKEY_ALL_MONITORS:
                        ToggleAllMonitors();
                        return;
                    case HOTKEY_AXIS_LABELS:
                        ToggleAxisLabels();
                        return;
                    case HOTKEY_SETTINGS:
                        ShowSettingsWindow();
                        return;
                }
            }
            base.WndProc(ref m);
        }

        private void ToggleOverlay()
        {
            overlayEnabled = !overlayEnabled;
            Invalidate();
        }

        private void ToggleCenterOnly()
        {
            centerOnly = !centerOnly;
            overlayEnabled = true;
            Invalidate();
        }

        private void NextMonitor()
        {
            Screen[] screens = Screen.AllScreens;
            if (screens.Length == 0) return;
            selectedMonitorIndex = (selectedMonitorIndex + 1) % screens.Length;
            allMonitors = false;
            overlayEnabled = true;
            Invalidate();
        }

        private void ToggleAllMonitors()
        {
            allMonitors = !allMonitors;
            overlayEnabled = true;
            Invalidate();
        }

        private void ToggleAxisLabels()
        {
            showAxisLabels = !showAxisLabels;
            overlayEnabled = true;
            Invalidate();
        }


        private void ShowSettingsWindow()
        {
            if (settingsForm != null && !settingsForm.IsDisposed)
            {
                settingsForm.Activate();
                settingsForm.BringToFront();
                return;
            }

            Screen[] screens = Screen.AllScreens;
            if (screens.Length == 0) return;
            if (selectedMonitorIndex < 0 || selectedMonitorIndex >= screens.Length) selectedMonitorIndex = 0;

            Form form = new Form();
            settingsForm = form;
            form.Text = "Screen Alignment Grid Settings";
            form.StartPosition = FormStartPosition.CenterScreen;
            form.FormBorderStyle = FormBorderStyle.FixedDialog;
            form.MaximizeBox = false;
            form.MinimizeBox = false;
            form.TopMost = true;
            form.ClientSize = new Size(760, 560);
            form.MinimumSize = new Size(760, 560);
            form.Font = settingsFont;

            Label title = new Label();
            title.Text = "Screen Alignment Grid";
            title.Font = new Font("Segoe UI", 18, FontStyle.Bold);
            title.AutoSize = true;
            title.Location = new Point(20, 16);
            form.Controls.Add(title);

            TabControl tabs = new TabControl();
            tabs.Location = new Point(20, 64);
            tabs.Size = new Size(720, 410);
            form.Controls.Add(tabs);

            TabPage generalTab = new TabPage("General");
            TabPage gridTab = new TabPage("Grid");
            TabPage labelsTab = new TabPage("Line numbers");
            TabPage colorsTab = new TabPage("Colors");
            tabs.TabPages.Add(generalTab);
            tabs.TabPages.Add(gridTab);
            tabs.TabPages.Add(labelsTab);
            tabs.TabPages.Add(colorsTab);

            CheckBox overlayCheck = new CheckBox();
            overlayCheck.Text = "Overlay enabled";
            overlayCheck.Checked = overlayEnabled;
            overlayCheck.AutoSize = true;
            overlayCheck.Location = new Point(24, 28);
            generalTab.Controls.Add(overlayCheck);

            CheckBox centerCheck = new CheckBox();
            centerCheck.Text = "Center lines only";
            centerCheck.Checked = centerOnly;
            centerCheck.AutoSize = true;
            centerCheck.Location = new Point(24, 70);
            generalTab.Controls.Add(centerCheck);

            CheckBox allCheck = new CheckBox();
            allCheck.Text = "Draw on all displays";
            allCheck.Checked = allMonitors;
            allCheck.AutoSize = true;
            allCheck.Location = new Point(24, 128);
            generalTab.Controls.Add(allCheck);

            Label monitorLabel = new Label();
            monitorLabel.Text = "Target display";
            monitorLabel.AutoSize = true;
            monitorLabel.Location = new Point(24, 178);
            generalTab.Controls.Add(monitorLabel);

            ComboBox monitorCombo = new ComboBox();
            monitorCombo.DropDownStyle = ComboBoxStyle.DropDownList;
            monitorCombo.Location = new Point(24, 210);
            monitorCombo.Width = 620;
            for (int i = 0; i < screens.Length; i++)
            {
                Screen screen = screens[i];
                Rectangle r = screen.Bounds;
                string label = (i + 1).ToString() + ": " + (screen.Primary ? "Primary" : "Monitor") + " " + r.Width + "x" + r.Height + " @ " + r.Left + "," + r.Top;
                monitorCombo.Items.Add(label);
            }
            monitorCombo.SelectedIndex = selectedMonitorIndex;
            monitorCombo.Enabled = !allMonitors;
            generalTab.Controls.Add(monitorCombo);

            Button uninstallButton = new Button();
            uninstallButton.Text = "Uninstall...";
            uninstallButton.Location = new Point(24, 300);
            uninstallButton.Size = new Size(180, 44);
            generalTab.Controls.Add(uninstallButton);

            Label uninstallHelp = new Label();
            uninstallHelp.Text = "Remove installed app files";
            uninstallHelp.AutoSize = false;
            uninstallHelp.Location = new Point(244, 306);
            uninstallHelp.Size = new Size(420, 52);
            generalTab.Controls.Add(uninstallHelp);

            Label gridLabel = new Label();
            gridLabel.Text = "Grid spacing";
            gridLabel.AutoSize = true;
            gridLabel.Location = new Point(24, 34);
            gridTab.Controls.Add(gridLabel);

            Label gridValue = new Label();
            gridValue.Text = gridSize.ToString() + " px";
            gridValue.AutoSize = true;
            gridValue.Location = new Point(610, 34);
            gridTab.Controls.Add(gridValue);

            NoWheelTrackBar gridTrack = new NoWheelTrackBar();
            gridTrack.Minimum = 10;
            gridTrack.Maximum = 200;
            gridTrack.TickFrequency = 10;
            gridTrack.SmallChange = 10;
            gridTrack.LargeChange = 25;
            gridTrack.Value = Math.Max(gridTrack.Minimum, Math.Min(gridTrack.Maximum, gridSize));
            gridTrack.Location = new Point(24, 66);
            gridTrack.Width = 640;
            gridTab.Controls.Add(gridTrack);

            Label opacityLabel = new Label();
            opacityLabel.Text = "Grid intensity";
            opacityLabel.AutoSize = true;
            opacityLabel.Location = new Point(24, 156);
            gridTab.Controls.Add(opacityLabel);

            Label opacityValue = new Label();
            opacityValue.Text = alpha.ToString();
            opacityValue.AutoSize = true;
            opacityValue.Location = new Point(610, 156);
            gridTab.Controls.Add(opacityValue);

            NoWheelTrackBar opacityTrack = new NoWheelTrackBar();
            opacityTrack.Minimum = 20;
            opacityTrack.Maximum = 200;
            opacityTrack.TickFrequency = 15;
            opacityTrack.SmallChange = 15;
            opacityTrack.LargeChange = 30;
            opacityTrack.Value = Math.Max(opacityTrack.Minimum, Math.Min(opacityTrack.Maximum, alpha));
            opacityTrack.Location = new Point(24, 188);
            opacityTrack.Width = 640;
            gridTab.Controls.Add(opacityTrack);

            Label opacityHelp = new Label();
            opacityHelp.Text = "Intensity dims line colors without alpha-blending them into the transparent background.";
            opacityHelp.AutoSize = false;
            opacityHelp.Location = new Point(24, 286);
            opacityHelp.Size = new Size(650, 42);
            gridTab.Controls.Add(opacityHelp);

            CheckBox axisCheck = new CheckBox();
            axisCheck.Text = "Show line numbers on center axes";
            axisCheck.Checked = showAxisLabels;
            axisCheck.AutoSize = true;
            axisCheck.Location = new Point(24, 28);
            labelsTab.Controls.Add(axisCheck);

            Label sizeLabel = new Label();
            sizeLabel.Text = "Number size";
            sizeLabel.AutoSize = true;
            sizeLabel.Location = new Point(24, 86);
            labelsTab.Controls.Add(sizeLabel);

            Label sizeValue = new Label();
            sizeValue.Text = axisLabelSize.ToString() + " pt";
            sizeValue.AutoSize = true;
            sizeValue.Location = new Point(610, 86);
            labelsTab.Controls.Add(sizeValue);

            NoWheelTrackBar sizeTrack = new NoWheelTrackBar();
            sizeTrack.Minimum = 8;
            sizeTrack.Maximum = 40;
            sizeTrack.TickFrequency = 4;
            sizeTrack.Value = Math.Max(sizeTrack.Minimum, Math.Min(sizeTrack.Maximum, axisLabelSize));
            sizeTrack.Location = new Point(24, 118);
            sizeTrack.Width = 640;
            labelsTab.Controls.Add(sizeTrack);

            Label offsetLabel = new Label();
            offsetLabel.Text = "Offset from center axes";
            offsetLabel.AutoSize = true;
            offsetLabel.Location = new Point(24, 212);
            labelsTab.Controls.Add(offsetLabel);

            Label offsetValue = new Label();
            offsetValue.Text = axisLabelOffset.ToString() + " px";
            offsetValue.AutoSize = true;
            offsetValue.Location = new Point(610, 212);
            labelsTab.Controls.Add(offsetValue);

            NoWheelTrackBar offsetTrack = new NoWheelTrackBar();
            offsetTrack.Minimum = 0;
            offsetTrack.Maximum = 60;
            offsetTrack.TickFrequency = 5;
            offsetTrack.Value = Math.Max(offsetTrack.Minimum, Math.Min(offsetTrack.Maximum, axisLabelOffset));
            offsetTrack.Location = new Point(24, 244);
            offsetTrack.Width = 640;
            labelsTab.Controls.Add(offsetTrack);

            Label offsetHelp = new Label();
            offsetHelp.Text = "Offset moves X-axis labels vertically and Y-axis labels horizontally. Labels stay anchored to the grid line they represent.";
            offsetHelp.AutoSize = false;
            offsetHelp.Location = new Point(24, 330);
            offsetHelp.Size = new Size(650, 46);
            labelsTab.Controls.Add(offsetHelp);

            Label colorPresetLabel = new Label();
            colorPresetLabel.Text = "Color preset";
            colorPresetLabel.AutoSize = true;
            colorPresetLabel.Location = new Point(24, 34);
            colorsTab.Controls.Add(colorPresetLabel);

            ComboBox colorPresetCombo = new ComboBox();
            colorPresetCombo.DropDownStyle = ComboBoxStyle.DropDownList;
            colorPresetCombo.Location = new Point(24, 66);
            colorPresetCombo.Width = 360;
            colorPresetCombo.Items.Add("Default cyan/red");
            colorPresetCombo.Items.Add("Colorblind safe blue/orange");
            colorPresetCombo.Items.Add("High contrast white/yellow");
            colorPresetCombo.Items.Add("Low brightness gray/gold");
            colorPresetCombo.Items.Add("Custom");
            colorPresetCombo.SelectedIndex = activeColorPresetIndex;
            colorsTab.Controls.Add(colorPresetCombo);

            Button gridColorButton = new Button();
            gridColorButton.Text = "Thin grid lines";
            gridColorButton.Location = new Point(24, 128);
            gridColorButton.Size = new Size(200, 48);
            SetColorButtonBack(gridColorButton, gridColor);
            colorsTab.Controls.Add(gridColorButton);

            Button majorColorButton = new Button();
            majorColorButton.Text = "Major grid lines";
            majorColorButton.Location = new Point(244, 128);
            majorColorButton.Size = new Size(210, 48);
            SetColorButtonBack(majorColorButton, majorGridColor);
            colorsTab.Controls.Add(majorColorButton);

            Button centerColorButton = new Button();
            centerColorButton.Text = "Center lines";
            centerColorButton.Location = new Point(474, 128);
            centerColorButton.Size = new Size(190, 48);
            SetColorButtonBack(centerColorButton, centerColor);
            colorsTab.Controls.Add(centerColorButton);

            Button labelColorButton = new Button();
            labelColorButton.Text = "Line number text";
            labelColorButton.Location = new Point(24, 202);
            labelColorButton.Size = new Size(220, 48);
            SetColorButtonBack(labelColorButton, labelColor);
            colorsTab.Controls.Add(labelColorButton);

            Button matchGridColorsButton = new Button();
            matchGridColorsButton.Text = "Use thin color for all grid lines";
            matchGridColorsButton.Location = new Point(264, 202);
            matchGridColorsButton.Size = new Size(330, 48);
            colorsTab.Controls.Add(matchGridColorsButton);

            Label colorsHelp = new Label();
            colorsHelp.Text = "Built-in presets are locked. Select Custom to edit colors. Thin grid, major grid, center lines, and line-number text are separate layers.";
            colorsHelp.AutoSize = false;
            colorsHelp.Location = new Point(24, 286);
            colorsHelp.Size = new Size(650, 64);
            colorsTab.Controls.Add(colorsHelp);

            UpdateColorControlsForPreset(
                colorPresetCombo,
                gridColorButton,
                majorColorButton,
                centerColorButton,
                labelColorButton,
                matchGridColorsButton
            );

            Button nextButton = new Button();
            nextButton.Text = "Next display";
            nextButton.Location = new Point(20, 492);
            nextButton.Size = new Size(160, 44);
            form.Controls.Add(nextButton);

            Button allButton = new Button();
            allButton.Text = "Toggle all displays";
            allButton.Location = new Point(200, 492);
            allButton.Size = new Size(210, 44);
            form.Controls.Add(allButton);

            Button closeButton = new Button();
            closeButton.Text = "Exit";
            closeButton.Location = new Point(620, 492);
            closeButton.Size = new Size(120, 44);
            form.Controls.Add(closeButton);

            overlayCheck.CheckedChanged += (sender, args) =>
            {
                overlayEnabled = overlayCheck.Checked;
                Invalidate();
            };
            centerCheck.CheckedChanged += (sender, args) =>
            {
                centerOnly = centerCheck.Checked;
                overlayEnabled = true;
                overlayCheck.Checked = true;
                Invalidate();
            };
            axisCheck.CheckedChanged += (sender, args) =>
            {
                showAxisLabels = axisCheck.Checked;
                overlayEnabled = true;
                overlayCheck.Checked = true;
                Invalidate();
            };
            allCheck.CheckedChanged += (sender, args) =>
            {
                allMonitors = allCheck.Checked;
                monitorCombo.Enabled = !allMonitors;
                overlayEnabled = true;
                overlayCheck.Checked = true;
                Invalidate();
            };
            monitorCombo.SelectedIndexChanged += (sender, args) =>
            {
                if (monitorCombo.SelectedIndex >= 0)
                {
                    selectedMonitorIndex = monitorCombo.SelectedIndex;
                    allMonitors = false;
                    allCheck.Checked = false;
                    monitorCombo.Enabled = true;
                    overlayEnabled = true;
                    overlayCheck.Checked = true;
                    Invalidate();
                }
            };
            gridTrack.Scroll += (sender, args) =>
            {
                gridSize = gridTrack.Value;
                gridValue.Text = gridSize.ToString() + " px";
                overlayEnabled = true;
                overlayCheck.Checked = true;
                Invalidate();
            };
            opacityTrack.Scroll += (sender, args) =>
            {
                alpha = opacityTrack.Value;
                centerAlpha = Math.Min(255, Math.Max(80, alpha + 130));
                opacityValue.Text = alpha.ToString();
                overlayEnabled = true;
                overlayCheck.Checked = true;
                Invalidate();
            };
            sizeTrack.Scroll += (sender, args) =>
            {
                axisLabelSize = sizeTrack.Value;
                sizeValue.Text = axisLabelSize.ToString() + " pt";
                overlayEnabled = true;
                overlayCheck.Checked = true;
                Invalidate();
            };
            offsetTrack.Scroll += (sender, args) =>
            {
                axisLabelOffset = offsetTrack.Value;
                offsetValue.Text = axisLabelOffset.ToString() + " px";
                overlayEnabled = true;
                overlayCheck.Checked = true;
                Invalidate();
            };
            colorPresetCombo.SelectedIndexChanged += (sender, args) =>
            {
                if (suppressPresetChanged) return;
                activeColorPresetIndex = colorPresetCombo.SelectedIndex;
                if (activeColorPresetIndex == 4)
                {
                    ApplyCustomColors();
                }
                else
                {
                    ApplyColorPreset(activeColorPresetIndex);
                }
                UpdateColorControlsForPreset(
                    colorPresetCombo,
                    gridColorButton,
                    majorColorButton,
                    centerColorButton,
                    labelColorButton,
                    matchGridColorsButton
                );
                overlayEnabled = true;
                overlayCheck.Checked = true;
                Invalidate();
            };
            gridColorButton.Click += (sender, args) =>
            {
                if (activeColorPresetIndex != 4) return;
                if (PickColor(ref customGridColor))
                {
                    ApplyCustomColors();
                    UpdateColorControlsForPreset(colorPresetCombo, gridColorButton, majorColorButton, centerColorButton, labelColorButton, matchGridColorsButton);
                    Invalidate();
                }
            };
            majorColorButton.Click += (sender, args) =>
            {
                if (activeColorPresetIndex != 4) return;
                if (PickColor(ref customMajorGridColor))
                {
                    ApplyCustomColors();
                    UpdateColorControlsForPreset(colorPresetCombo, gridColorButton, majorColorButton, centerColorButton, labelColorButton, matchGridColorsButton);
                    Invalidate();
                }
            };
            centerColorButton.Click += (sender, args) =>
            {
                if (activeColorPresetIndex != 4) return;
                if (PickColor(ref customCenterColor))
                {
                    ApplyCustomColors();
                    UpdateColorControlsForPreset(colorPresetCombo, gridColorButton, majorColorButton, centerColorButton, labelColorButton, matchGridColorsButton);
                    Invalidate();
                }
            };
            labelColorButton.Click += (sender, args) =>
            {
                if (activeColorPresetIndex != 4) return;
                if (PickColor(ref customLabelColor))
                {
                    ApplyCustomColors();
                    UpdateColorControlsForPreset(colorPresetCombo, gridColorButton, majorColorButton, centerColorButton, labelColorButton, matchGridColorsButton);
                    Invalidate();
                }
            };
            matchGridColorsButton.Click += (sender, args) =>
            {
                if (activeColorPresetIndex != 4) return;
                customMajorGridColor = customGridColor;
                ApplyCustomColors();
                UpdateColorControlsForPreset(colorPresetCombo, gridColorButton, majorColorButton, centerColorButton, labelColorButton, matchGridColorsButton);
                overlayEnabled = true;
                overlayCheck.Checked = true;
                Invalidate();
            };
            nextButton.Click += (sender, args) =>
            {
                NextMonitor();
                monitorCombo.SelectedIndex = selectedMonitorIndex;
                allCheck.Checked = allMonitors;
                monitorCombo.Enabled = !allMonitors;
                overlayCheck.Checked = overlayEnabled;
            };
            allButton.Click += (sender, args) =>
            {
                ToggleAllMonitors();
                allCheck.Checked = allMonitors;
                monitorCombo.Enabled = !allMonitors;
                overlayCheck.Checked = overlayEnabled;
            };
            uninstallButton.Click += (sender, args) => LaunchUninstaller();
            closeButton.Click += (sender, args) => Close();
            form.FormClosed += (sender, args) => settingsForm = null;
            form.Shown += (sender, args) =>
            {
                ShowWindow(form.Handle, SW_RESTORE);
                ShowWindow(form.Handle, SW_SHOW);
                form.WindowState = FormWindowState.Normal;
                form.Visible = true;
                form.Activate();
                form.BringToFront();
            };
            form.Show();
            ShowWindow(form.Handle, SW_RESTORE);
            ShowWindow(form.Handle, SW_SHOW);
            form.WindowState = FormWindowState.Normal;
            form.Visible = true;
            form.Activate();
            form.BringToFront();
        }

        private void LaunchUninstaller()
        {
            DialogResult result = MessageBox.Show(
                "This will close Screen Alignment Grid and run the uninstaller for the current user. Continue?",
                "Uninstall Screen Alignment Grid",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning
            );

            if (result != DialogResult.Yes) return;

            string appDir = Environment.GetEnvironmentVariable("SCREEN_ALIGNMENT_GRID_DIR");
            if (String.IsNullOrWhiteSpace(appDir))
            {
                appDir = Environment.CurrentDirectory;
            }

            string uninstallPath = Path.Combine(appDir, "Uninstall Screen Alignment Grid.cmd");
            if (!File.Exists(uninstallPath))
            {
                MessageBox.Show(
                    "Could not find the uninstaller next to the app files:\n" + uninstallPath,
                    "Uninstaller not found",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
                return;
            }

            ProcessStartInfo info = new ProcessStartInfo();
            info.FileName = uninstallPath;
            info.WorkingDirectory = appDir;
            info.UseShellExecute = true;
            Process.Start(info);
            Close();
        }

        private void ApplyCustomColors()
        {
            gridColor = customGridColor;
            majorGridColor = customMajorGridColor;
            centerColor = customCenterColor;
            labelColor = customLabelColor;
            borderColor = customBorderColor;
        }

        private void UpdateColorControlsForPreset(
            ComboBox colorPresetCombo,
            Button gridColorButton,
            Button majorColorButton,
            Button centerColorButton,
            Button labelColorButton,
            Button matchGridColorsButton
        )
        {
            bool customSelected = activeColorPresetIndex == 4;
            colorPresetCombo.SelectedIndex = activeColorPresetIndex;
            gridColorButton.Enabled = customSelected;
            majorColorButton.Enabled = customSelected;
            centerColorButton.Enabled = customSelected;
            labelColorButton.Enabled = customSelected;
            matchGridColorsButton.Enabled = customSelected;
            SetColorButtonBack(gridColorButton, gridColor);
            SetColorButtonBack(majorColorButton, majorGridColor);
            SetColorButtonBack(centerColorButton, centerColor);
            SetColorButtonBack(labelColorButton, labelColor);
        }

        private void SetColorButtonBack(Button button, Color color)
        {
            button.UseVisualStyleBackColor = false;
            button.BackColor = color;
            int brightness = color.R + color.G + color.B;
            button.ForeColor = brightness < 360 ? Color.White : Color.Black;
            button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderColor = Color.FromArgb(80, 80, 80);
        }

        private bool PickColor(ref Color target)
        {
            using (ColorDialog dialog = new ColorDialog())
            {
                dialog.FullOpen = true;
                dialog.Color = target;
                if (dialog.ShowDialog() == DialogResult.OK)
                {
                    target = dialog.Color;
                    overlayEnabled = true;
                    return true;
                }
            }
            return false;
        }

        private void ApplyColorPreset(int index)
        {
            switch (index)
            {
                case 1:
                    // Okabe-Ito inspired: blue/orange is safer for common red/green color blindness.
                    gridColor = Color.FromArgb(86, 180, 233);
                    majorGridColor = Color.FromArgb(0, 114, 178);
                    centerColor = Color.FromArgb(230, 159, 0);
                    labelColor = Color.White;
                    borderColor = Color.FromArgb(240, 240, 240);
                    break;
                case 2:
                    gridColor = Color.White;
                    majorGridColor = Color.FromArgb(255, 255, 0);
                    centerColor = Color.FromArgb(255, 255, 0);
                    labelColor = Color.White;
                    borderColor = Color.White;
                    break;
                case 3:
                    gridColor = Color.FromArgb(150, 150, 150);
                    majorGridColor = Color.FromArgb(210, 180, 70);
                    centerColor = Color.FromArgb(255, 215, 0);
                    labelColor = Color.FromArgb(235, 235, 235);
                    borderColor = Color.FromArgb(180, 180, 180);
                    break;
                default:
                    gridColor = Color.FromArgb(0, 220, 255);
                    majorGridColor = Color.FromArgb(0, 255, 180);
                    centerColor = Color.FromArgb(255, 80, 80);
                    labelColor = Color.White;
                    borderColor = Color.White;
                    break;
            }
        }

        private bool ShouldDrawScreen(Screen screen, int index)
        {
            if (allMonitors) return true;
            return index == selectedMonitorIndex;
        }

        private Color ScaleColor(Color color, int strength)
        {
            int clamped = Math.Max(0, Math.Min(255, strength));
            return Color.FromArgb(
                255,
                (color.R * clamped) / 255,
                (color.G * clamped) / 255,
                (color.B * clamped) / 255
            );
        }


        private void DrawAxisLabels(
            Graphics graphics,
            int left,
            int top,
            int right,
            int bottom,
            int centerX,
            int centerY,
            int spacing,
            Font font,
            Brush textBrush,
            int labelOffset)
        {
            DrawAxisTextCentered(graphics, "0", centerX, centerY + labelOffset, font, textBrush, true);

            for (int x = centerX + spacing, line = 1; x <= right; x += spacing, line++)
            {
                DrawAxisTextCentered(graphics, "+" + line.ToString(), x, centerY + labelOffset, font, textBrush, true);
            }
            for (int x = centerX - spacing, line = -1; x >= left; x -= spacing, line--)
            {
                DrawAxisTextCentered(graphics, line.ToString(), x, centerY + labelOffset, font, textBrush, true);
            }
            for (int y = centerY + spacing, line = 1; y <= bottom; y += spacing, line++)
            {
                DrawAxisTextCentered(graphics, "+" + line.ToString(), centerX + labelOffset, y, font, textBrush, false);
            }
            for (int y = centerY - spacing, line = -1; y >= top; y -= spacing, line--)
            {
                DrawAxisTextCentered(graphics, line.ToString(), centerX + labelOffset, y, font, textBrush, false);
            }
        }

        private void DrawAxisTextCentered(Graphics graphics, string text, int anchorX, int anchorY, Font font, Brush textBrush, bool centerHorizontally)
        {
            SizeF size = graphics.MeasureString(text, font);
            float x = centerHorizontally ? anchorX - (size.Width / 2) : anchorX;
            float y = centerHorizontally ? anchorY : anchorY - (size.Height / 2);
            graphics.DrawString(text, font, textBrush, x, y);
        }

        private void DrawTag(Graphics graphics, string text, int x, int y, Font font, Brush textBrush, Brush backgroundBrush)
        {
            SizeF size = graphics.MeasureString(text, font);
            RectangleF rect = new RectangleF(x, y, size.Width + 8, size.Height + 4);
            graphics.FillRectangle(backgroundBrush, rect);
            graphics.DrawString(text, font, textBrush, x + 4, y + 2);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.Clear(transparentColor);
            if (!overlayEnabled) return;

            e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.None;
            Rectangle virtualBounds = SystemInformation.VirtualScreen;

            using (Pen gridPen = new Pen(ScaleColor(gridColor, alpha), 1))
            using (Pen majorGridPen = new Pen(ScaleColor(majorGridColor, Math.Min(220, alpha + 35)), 1))
            using (Pen centerPen = new Pen(ScaleColor(centerColor, centerAlpha), 2))
            using (Pen borderPen = new Pen(ScaleColor(borderColor, Math.Min(180, alpha + 20)), 1))
            using (Font labelFont = new Font("Segoe UI", 12, FontStyle.Bold))
            using (Font axisLabelFont = new Font("Segoe UI", axisLabelSize, FontStyle.Bold))
            using (Brush labelBrush = new SolidBrush(ScaleColor(labelColor, 220)))
            {
                Screen[] screens = Screen.AllScreens;
                if (screens.Length == 0) return;
                if (selectedMonitorIndex < 0 || selectedMonitorIndex >= screens.Length) selectedMonitorIndex = 0;

                for (int screenIndex = 0; screenIndex < screens.Length; screenIndex++)
                {
                    Screen screen = screens[screenIndex];
                    if (!ShouldDrawScreen(screen, screenIndex)) continue;
                    Rectangle r = screen.Bounds;
                    int left = r.Left - virtualBounds.Left;
                    int top = r.Top - virtualBounds.Top;
                    int right = left + r.Width;
                    int bottom = top + r.Height;
                    int centerX = left + r.Width / 2;
                    int centerY = top + r.Height / 2;

                    if (!centerOnly)
                    {
                        // Anchor the grid to the true monitor center so the red center lines
                        // always sit exactly on grid lines, even when the resolution is not
                        // evenly divisible by the selected grid spacing.
                        for (int x = centerX; x <= right; x += gridSize)
                        {
                            int stepsFromCenter = Math.Abs((x - centerX) / gridSize);
                            bool major = (stepsFromCenter % 2) == 0;
                            e.Graphics.DrawLine(major ? majorGridPen : gridPen, x, top, x, bottom);
                        }
                        for (int x = centerX - gridSize; x >= left; x -= gridSize)
                        {
                            int stepsFromCenter = Math.Abs((x - centerX) / gridSize);
                            bool major = (stepsFromCenter % 2) == 0;
                            e.Graphics.DrawLine(major ? majorGridPen : gridPen, x, top, x, bottom);
                        }
                        for (int y = centerY; y <= bottom; y += gridSize)
                        {
                            int stepsFromCenter = Math.Abs((y - centerY) / gridSize);
                            bool major = (stepsFromCenter % 2) == 0;
                            e.Graphics.DrawLine(major ? majorGridPen : gridPen, left, y, right, y);
                        }
                        for (int y = centerY - gridSize; y >= top; y -= gridSize)
                        {
                            int stepsFromCenter = Math.Abs((y - centerY) / gridSize);
                            bool major = (stepsFromCenter % 2) == 0;
                            e.Graphics.DrawLine(major ? majorGridPen : gridPen, left, y, right, y);
                        }
                    }

                    e.Graphics.DrawLine(centerPen, centerX, top, centerX, bottom);
                    e.Graphics.DrawLine(centerPen, left, centerY, right, centerY);

                    if (showAxisLabels && !centerOnly)
                    {
                        DrawAxisLabels(e.Graphics, left, top, right, bottom, centerX, centerY, gridSize, axisLabelFont, labelBrush, axisLabelOffset);
                    }

                    e.Graphics.DrawRectangle(borderPen, left, top, r.Width - 1, r.Height - 1);

                }
            }
        }
    }

    public static class Program
    {
        [DllImport("Shcore.dll")]
        private static extern int SetProcessDpiAwareness(int awareness);

        [DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();

        private static void EnableDpiAwareness()
        {
            try
            {
                // Per-monitor DPI awareness keeps WinForms coordinates closer to
                // physical monitor pixels on mixed-DPI 2K/5K display setups.
                SetProcessDpiAwareness(2);
            }
            catch
            {
                try { SetProcessDPIAware(); } catch { }
            }
        }

        [STAThread]
        public static void Main()
        {
            EnableDpiAwareness();
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            using (GridOverlayForm form = new GridOverlayForm())
            {
                Application.Run(form);
            }
        }
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies @("System.Windows.Forms", "System.Drawing")
[ScreenAlignmentGrid.Program]::Main()
