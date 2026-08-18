# ==========================================================
# PC Doctor Portable - GUI Launcher v1.1
# Code Knot Technology
# ==========================================================
# World-class WPF desktop UI. Runs the engine (Main.ps1)
# as a hidden child process in AUTO mode, tails the log
# file it writes, and live-updates the module list,
# progress bar and output pane.
#
#   powershell -File App\PCDoctor-GUI.ps1      (run the app)
#   powershell -File App\PCDoctor-GUI.ps1 -SelfTest  (validate UI)
# ==========================================================

param(
    [switch]$SelfTest,

    # Dev tooling: render the window to a PNG (no dialog, no
    # network, no timers) so the UI can be inspected visually.
    [switch]$RenderShot,
    [string]$ShotPath = "",
    [int]$ShotView = 0,

    # Optional theme override for RenderShot (Dark/Light); the
    # persisted pref wins when this is left empty.
    [string]$ShotTheme = "",

    # Optional taller window for RenderShot, so scrollable content
    # (the live dashboard stats) fits in one frame.
    [int]$ShotHeight = 0
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$AppRoot = Split-Path -Parent $PSScriptRoot
$Version = "1.2"

# Windows Task Scheduler integration (register/unregister the
# weekly auto-run task). Only the query helpers are used here;
# registration runs elevated via App\Register-TaskElevated.ps1.
. (Join-Path $AppRoot "Modules\TaskScheduler.ps1")

# Load Config.json (version + update URL for the update check)
$Global:Config = $null
try
{
    $Global:Config = Get-Content (Join-Path $AppRoot "Config.json") -Raw -Encoding UTF8 | ConvertFrom-Json
}
catch {}

# ----------------------------------------------------------
# XAML - dark modern theme
# ----------------------------------------------------------

$Xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="PC Doctor Portable"
    Width="1000" Height="660" MinWidth="820" MinHeight="560"
    WindowStartupLocation="CenterScreen"
    Background="#0D1117" FontFamily="Segoe UI Variable Text" FontSize="13"
    Foreground="#D7E0EA">

    <Window.Resources>
        <SolidColorBrush x:Key="Bg" Color="#0D1117"/>
        <SolidColorBrush x:Key="Panel" Color="#161B22"/>
        <SolidColorBrush x:Key="Panel2" Color="#1C2330"/>
        <SolidColorBrush x:Key="Border" Color="#2D3644"/>
        <SolidColorBrush x:Key="Text" Color="#D7E0EA"/>
        <SolidColorBrush x:Key="Muted" Color="#8B98A9"/>
        <SolidColorBrush x:Key="Accent" Color="#4FC1FF"/>
        <SolidColorBrush x:Key="Green" Color="#3DDC84"/>
        <SolidColorBrush x:Key="Yellow" Color="#FFD866"/>
        <SolidColorBrush x:Key="Red" Color="#FF6B6B"/>
        <SolidColorBrush x:Key="Header1" Color="#10151F"/>
        <SolidColorBrush x:Key="Header2" Color="#0D2838"/>
        <SolidColorBrush x:Key="RowHover" Color="#1F2733"/>
        <SolidColorBrush x:Key="StartG1" Color="#4BE89A"/>
        <SolidColorBrush x:Key="StartG2" Color="#23A564"/>

        <!-- Premium button style: rounded corners, hover and
             disabled feedback - applied to every Button.
             NOTE: the template only uses TemplateBinding - never
             StaticResource - because WPF freezes brushes that
             styles reference, which would break theme switching. -->
        <Style TargetType="Button">
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="14,8"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="8"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Opacity" Value="0.85"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bd" Property="Opacity" Value="0.7"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="bd" Property="Opacity" Value="0.38"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Premium rounded progress bar. Same rule as the button
             style: setters must not reference shared brushes (WPF
             freezes them), so Background/Foreground come from the
             element's own local values via TemplateBinding. -->
        <Style TargetType="ProgressBar">
            <Setter Property="Height" Value="10"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid>
                            <Border x:Name="PART_Track"
                                    Background="{TemplateBinding Background}"
                                    CornerRadius="5"/>
                            <Border x:Name="PART_Indicator"
                                    HorizontalAlignment="Left"
                                    Background="{TemplateBinding Foreground}"
                                    CornerRadius="5"/>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0"
                BorderBrush="{StaticResource Border}" BorderThickness="0,0,0,1" Padding="16,12">
            <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                    <GradientStop Offset="0" Color="{Binding Color, Source={StaticResource Header1}}"/>
                    <GradientStop Offset="1" Color="{Binding Color, Source={StaticResource Header2}}"/>
                </LinearGradientBrush>
            </Border.Background>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <Border Width="46" Height="46" CornerRadius="10"
                        Background="{StaticResource Panel2}"
                        BorderBrush="{StaticResource Border}" BorderThickness="1"
                        VerticalAlignment="Center">
                    <Border.Effect>
                        <DropShadowEffect BlurRadius="14" ShadowDepth="0" Opacity="0.35" Color="#000000"/>
                    </Border.Effect>
                    <Image x:Name="HeaderLogo" Width="32" Height="32"
                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>

                <StackPanel Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center">
                    <TextBlock Text="PC DOCTOR PORTABLE" FontSize="18" FontWeight="Bold"
                               FontFamily="Segoe UI Variable Display"
                               Foreground="{StaticResource Accent}"/>
                    <TextBlock x:Name="SubtitleText" Text="Windows Maintenance &amp; Repair Tool"
                               FontSize="12" Foreground="{StaticResource Muted}"/>
                </StackPanel>

                <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                    <Border CornerRadius="999" Padding="10,4"
                            Background="{StaticResource Panel2}"
                            BorderBrush="{StaticResource Border}" BorderThickness="1"
                            Margin="0,0,8,0">
                        <TextBlock x:Name="VersionBadge" Text="v1.2"
                                   Foreground="{StaticResource Muted}" FontSize="12"/>
                    </Border>
                    <ToggleButton x:Name="ThemeButton" Content="Dark" Width="64" FontSize="12"
                                 Background="{StaticResource Panel2}"
                                 BorderBrush="{StaticResource Border}"
                                 Foreground="{StaticResource Text}"
                                 Margin="0,0,8,0" VerticalAlignment="Center" Padding="4,2"/>
                    <ComboBox x:Name="LangBox" Width="112" FontSize="12"
                              Background="{StaticResource Panel2}"
                              BorderBrush="{StaticResource Border}"
                              Foreground="{StaticResource Text}"
                              VerticalAlignment="Center" Padding="4,2"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Content -->
        <Grid Grid.Row="1" Margin="14">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="300"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Left panel -->
            <Border Grid.Column="0" Background="{StaticResource Panel}"
                    BorderBrush="{StaticResource Border}" BorderThickness="1"
                    CornerRadius="10" Padding="14" Margin="0,0,8,0">
                <Border.Effect>
                    <DropShadowEffect BlurRadius="22" ShadowDepth="0" Opacity="0.22" Color="#000000"/>
                </Border.Effect>
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <StackPanel Grid.Row="0">

                    <TextBlock x:Name="ModeLabel" Text="MODE" FontSize="10" FontWeight="Bold"
                               Foreground="{StaticResource Muted}" Margin="0,0,0,6"/>
                    <Border Background="{StaticResource Panel2}" CornerRadius="8"
                            Padding="10,8" BorderBrush="{StaticResource Border}" BorderThickness="1">
                        <StackPanel>
                            <TextBlock x:Name="ModeTitleText" Text="Auto Mode" FontWeight="SemiBold"
                                       Foreground="{StaticResource Green}"/>
                            <TextBlock x:Name="ModeNoteText" Text="Runs all 12 modules unattended. Interactive prompts are available in the console version."
                                       FontSize="11" Foreground="{StaticResource Muted}"
                                       TextWrapping="Wrap" Margin="0,3,0,0"/>
                        </StackPanel>
                    </Border>
                    <StackPanel Orientation="Horizontal" Margin="0,8,0,0">
                        <TextBlock x:Name="UpdateText" FontSize="11"
                                   Foreground="{StaticResource Muted}"
                                   TextWrapping="Wrap" VerticalAlignment="Center"/>
                        <Button x:Name="DownloadButton" Content="Download"
                                FontSize="11" Padding="8,2" Margin="8,0,0,0"
                                Background="{StaticResource Accent}"
                                Foreground="White" BorderThickness="0"
                                Cursor="Hand" Visibility="Collapsed"
                                VerticalAlignment="Center"/>
                    </StackPanel>

                    <!-- Navigation rail (Fluent-style) -->
                    <StackPanel Margin="0,10,0,0">
                        <Button x:Name="NavDashboard" Height="32" Margin="0,1"
                                HorizontalContentAlignment="Stretch" Background="Transparent"
                                BorderThickness="0" Cursor="Hand">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#xE80F;" FontFamily="Segoe MDL2 Assets" FontSize="13"/>
                                <TextBlock x:Name="NavDashboardText" Text="Dashboard" Margin="10,0,0,0"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="NavModules" Height="32" Margin="0,1"
                                HorizontalContentAlignment="Stretch" Background="Transparent"
                                BorderThickness="0" Cursor="Hand">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#xE71D;" FontFamily="Segoe MDL2 Assets" FontSize="13"/>
                                <TextBlock x:Name="NavModulesText" Text="Modules" Margin="10,0,0,0"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="NavSettings" Height="32" Margin="0,1"
                                HorizontalContentAlignment="Stretch" Background="Transparent"
                                BorderThickness="0" Cursor="Hand">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="13"/>
                                <TextBlock x:Name="NavSettingsText" Text="Settings" Margin="10,0,0,0"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="NavHistory" Height="32" Margin="0,1"
                                HorizontalContentAlignment="Stretch" Background="Transparent"
                                BorderThickness="0" Cursor="Hand">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#xE81C;" FontFamily="Segoe MDL2 Assets" FontSize="13"/>
                                <TextBlock x:Name="NavHistoryText" Text="History" Margin="10,0,0,0"/>
                            </StackPanel>
                        </Button>
                    </StackPanel>

                    <!-- Buttons -->
                    <Grid Margin="0,10,0,0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="10"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <Button x:Name="StartButton" Grid.Column="0" Content="Start"
                                Height="38" FontSize="14" FontWeight="SemiBold"
                                Foreground="#0D1117" BorderThickness="0" Cursor="Hand">
                            <Button.Background>
                                <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                                    <GradientStop Offset="0" Color="{Binding Color, Source={StaticResource StartG1}}"/>
                                    <GradientStop Offset="1" Color="{Binding Color, Source={StaticResource StartG2}}"/>
                                </LinearGradientBrush>
                            </Button.Background>
                        </Button>
                        <Button x:Name="AbortButton" Grid.Column="2" Content="Abort"
                                Height="38" FontSize="14" FontWeight="SemiBold"
                                Foreground="White" Background="{StaticResource Red}"
                                BorderThickness="0" IsEnabled="False" Cursor="Hand"/>
                    </Grid>
                    </StackPanel>

                    <!-- Views scroll independently so nothing clips on
                         smaller windows (dashboard has live stats now) -->
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                    <StackPanel>

                    <!-- Dashboard view (default) -->
                    <StackPanel x:Name="DashboardView" Margin="0,14,0,0">
                        <Border Background="{StaticResource Panel2}" CornerRadius="8"
                                Padding="10,10" BorderBrush="{StaticResource Border}" BorderThickness="1">
                            <StackPanel>
                                <StackPanel Orientation="Horizontal">
                                    <Ellipse x:Name="DashDot" Width="10" Height="10"
                                             Fill="{StaticResource Green}" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="DashHealthText" Text="SYSTEM HEALTHY" FontSize="13" FontWeight="Bold"
                                               Foreground="{StaticResource Green}" Margin="8,0,0,0"/>
                                </StackPanel>
                                <TextBlock x:Name="DashHealthNote" FontSize="11"
                                           Foreground="{StaticResource Muted}" TextWrapping="Wrap" Margin="0,4,0,0"/>
                            </StackPanel>
                        </Border>

                        <TextBlock x:Name="DashResourcesLabel" Text="RESOURCE USAGE" FontSize="10" FontWeight="Bold"
                                   Foreground="{StaticResource Muted}" Margin="0,12,0,6"/>
                        <StackPanel Orientation="Horizontal" Margin="0,2,0,0">
                            <TextBlock x:Name="DashRamLabel" Text="RAM" FontSize="11"
                                       Foreground="{StaticResource Muted}" Width="52"/>
                            <ProgressBar x:Name="DashRamBar" Height="6" Width="110" Minimum="0" Maximum="100" Value="0"
                                         Background="{StaticResource Panel2}" Foreground="{StaticResource Green}"
                                         VerticalAlignment="Center"/>
                            <TextBlock x:Name="DashRamText" Text="--" FontSize="11"
                                       Foreground="{StaticResource Text}" Margin="8,0,0,0"/>
                        </StackPanel>
                        <StackPanel Orientation="Horizontal" Margin="0,5,0,0">
                            <TextBlock x:Name="DashDiskLabel" Text="Disk" FontSize="11"
                                       Foreground="{StaticResource Muted}" Width="52"/>
                            <ProgressBar x:Name="DashDiskBar" Height="6" Width="110" Minimum="0" Maximum="100" Value="0"
                                         Background="{StaticResource Panel2}" Foreground="{StaticResource Accent}"
                                         VerticalAlignment="Center"/>
                            <TextBlock x:Name="DashDiskText" Text="--" FontSize="11"
                                       Foreground="{StaticResource Text}" Margin="8,0,0,0"/>
                        </StackPanel>
                        <TextBlock x:Name="DashUpdates" FontSize="11" Foreground="{StaticResource Muted}"
                                   TextWrapping="Wrap" Margin="0,7,0,0"/>

                        <TextBlock Text="SYSTEM" FontSize="10" FontWeight="Bold"
                                   Foreground="{StaticResource Muted}" Margin="0,12,0,6"/>
                        <TextBlock x:Name="DashOs" FontSize="11" Foreground="{StaticResource Text}" TextWrapping="Wrap"/>
                        <TextBlock x:Name="DashCpu" FontSize="11" Foreground="{StaticResource Muted}" TextWrapping="Wrap" Margin="0,2,0,0"/>
                        <TextBlock x:Name="DashRam" FontSize="11" Foreground="{StaticResource Muted}" TextWrapping="Wrap" Margin="0,2,0,0"/>
                        <TextBlock x:Name="DashUptime" FontSize="11" Foreground="{StaticResource Muted}" TextWrapping="Wrap" Margin="0,2,0,0"/>

                        <TextBlock Text="MAINTENANCE" FontSize="10" FontWeight="Bold"
                                   Foreground="{StaticResource Muted}" Margin="0,12,0,6"/>
                        <TextBlock x:Name="DashLastRun" FontSize="11" Foreground="{StaticResource Text}" TextWrapping="Wrap"/>
                        <TextBlock x:Name="DashNextRun" FontSize="11" Foreground="{StaticResource Muted}" TextWrapping="Wrap" Margin="0,2,0,0"/>
                        <TextBlock x:Name="DashVersion" FontSize="11" Foreground="{StaticResource Muted}" TextWrapping="Wrap" Margin="0,2,0,0"/>
                    </StackPanel>

                    <!-- Modules view -->
                    <StackPanel x:Name="ModulesView" Visibility="Collapsed" Margin="0,14,0,0">
                        <TextBlock x:Name="ModulesLabel" Text="MODULES" FontSize="11" FontWeight="Bold"
                                   Foreground="{StaticResource Muted}" Margin="0,0,0,6"/>
                        <ScrollViewer x:Name="ModulesScroll" VerticalScrollBarVisibility="Auto" MaxHeight="330">
                            <StackPanel x:Name="ModulePanel"/>
                        </ScrollViewer>
                    </StackPanel>

                    <!-- Settings view -->
                    <StackPanel x:Name="SettingsView" Visibility="Collapsed" Margin="0,14,0,0">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock x:Name="SettingsTitle" Text="SETTINGS" FontSize="11" FontWeight="Bold"
                                       Foreground="{StaticResource Muted}" VerticalAlignment="Center"/>
                            <Button x:Name="BackButton" Grid.Column="1" Content="Back"
                                    FontSize="11" Padding="6,2" Background="{StaticResource Panel2}"
                                    BorderBrush="{StaticResource Border}" Foreground="{StaticResource Text}"
                                    BorderThickness="1" Cursor="Hand"/>
                        </Grid>
                        <TextBlock x:Name="SettingsHint" FontSize="11" Foreground="{StaticResource Muted}"
                                   TextWrapping="Wrap" Margin="0,4,0,6"/>
                        <ScrollViewer VerticalScrollBarVisibility="Auto" MaxHeight="240">
                            <StackPanel x:Name="SettingsList"/>
                        </ScrollViewer>

                        <Border Background="{StaticResource Panel2}" CornerRadius="8"
                                Padding="10,8" BorderBrush="{StaticResource Border}"
                                BorderThickness="1" Margin="0,12,0,0">
                            <StackPanel>
                                <CheckBox x:Name="ScheduleCheck" Foreground="{StaticResource Text}"/>
                                <Grid Margin="0,6,0,0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock x:Name="ScheduleDayLabel" VerticalAlignment="Center"
                                               Foreground="{StaticResource Muted}" FontSize="11"/>
                                    <ComboBox x:Name="ScheduleDayBox" Grid.Column="1" Width="150"
                                              HorizontalAlignment="Left" Margin="8,0,0,0"
                                              FontSize="11" Background="{StaticResource Panel}"
                                              BorderBrush="{StaticResource Border}"
                                              Foreground="{StaticResource Text}"/>
                                </Grid>
                                <Grid Margin="0,6,0,0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock x:Name="ScheduleTimeLabel" VerticalAlignment="Center"
                                               Foreground="{StaticResource Muted}" FontSize="11"/>
                                    <ComboBox x:Name="ScheduleHourBox" Grid.Column="1" Width="64"
                                              Margin="8,0,6,0" FontSize="11"
                                              Background="{StaticResource Panel}"
                                              BorderBrush="{StaticResource Border}"
                                              Foreground="{StaticResource Text}"/>
                                    <ComboBox x:Name="ScheduleMinuteBox" Grid.Column="2" Width="64"
                                              FontSize="11" Background="{StaticResource Panel}"
                                              BorderBrush="{StaticResource Border}"
                                              Foreground="{StaticResource Text}"/>
                                </Grid>
                                <TextBlock x:Name="ScheduleNextText" FontSize="11"
                                           Foreground="{StaticResource Muted}" TextWrapping="Wrap"
                                           Margin="0,8,0,0"/>
                                <Button x:Name="ScheduleTaskButton" Content="Register in Windows Task Scheduler"
                                        FontSize="11" Padding="8,4" Margin="0,10,0,0"
                                        HorizontalAlignment="Left"
                                        Background="{StaticResource Panel2}"
                                        BorderBrush="{StaticResource Border}"
                                        Foreground="{StaticResource Text}"/>
                                <TextBlock x:Name="ScheduleTaskStatus" FontSize="10"
                                           Foreground="{StaticResource Muted}" TextWrapping="Wrap"
                                           Margin="0,4,0,0"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>

                    <!-- History view -->
                    <StackPanel x:Name="HistoryView" Visibility="Collapsed" Margin="0,14,0,0">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock x:Name="HistoryTitle" Text="RUN HISTORY" FontSize="11" FontWeight="Bold"
                                       Foreground="{StaticResource Muted}" VerticalAlignment="Center"/>
                            <Button x:Name="HistoryRefreshButton" Grid.Column="1" Content="Refresh"
                                    FontSize="11" Padding="6,2" Margin="0,0,6,0"
                                    Background="{StaticResource Panel2}" BorderBrush="{StaticResource Border}"
                                    Foreground="{StaticResource Text}" BorderThickness="1" Cursor="Hand"/>
                            <Button x:Name="HistoryBackButton" Grid.Column="2" Content="Back"
                                    FontSize="11" Padding="6,2" Background="{StaticResource Panel2}"
                                    BorderBrush="{StaticResource Border}" Foreground="{StaticResource Text}"
                                    BorderThickness="1" Cursor="Hand"/>
                        </Grid>
                        <ListBox x:Name="HistoryList" Margin="0,8,0,0" MaxHeight="400"
                                 Background="{StaticResource Panel2}"
                                 BorderBrush="{StaticResource Border}"
                                 Foreground="{StaticResource Text}"
                                 BorderThickness="1"
                                 HorizontalContentAlignment="Stretch"
                                 FontFamily="Consolas" FontSize="11"/>
                        <TextBlock x:Name="HistoryHint" FontSize="11" Foreground="{StaticResource Muted}"
                                   TextWrapping="Wrap" Margin="0,6,0,0"/>
                    </StackPanel>

                    </StackPanel>
                    </ScrollViewer>
                </Grid>
            </Border>

            <!-- Right panel -->
            <Border Grid.Column="1" Background="{StaticResource Panel}"
                    BorderBrush="{StaticResource Border}" BorderThickness="1"
                    CornerRadius="10" Padding="14" Margin="8,0,0,0">
                <Border.Effect>
                    <DropShadowEffect BlurRadius="22" ShadowDepth="0" Opacity="0.22" Color="#000000"/>
                </Border.Effect>
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <!-- Progress -->
                    <StackPanel Grid.Row="0" Margin="0,0,0,10">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock x:Name="StatusText" Text="Ready - click Start to begin."
                                       Foreground="{StaticResource Muted}"/>
                            <TextBlock x:Name="ProgressText" Grid.Column="1" Text="0 / 12"
                                       Foreground="{StaticResource Accent}" FontWeight="SemiBold"/>
                        </Grid>
                        <ProgressBar x:Name="ProgressBar" Height="8" Margin="0,8,0,0"
                                     Background="{StaticResource Panel2}"
                                     BorderThickness="0" Foreground="{StaticResource Accent}"/>
                    </StackPanel>

                    <!-- Output -->
                    <TextBlock x:Name="OutputLabel" Grid.Row="1" Text="LIVE OUTPUT" FontSize="11" FontWeight="Bold"
                               Foreground="{StaticResource Muted}" Margin="0,0,0,6"/>
                    <Border Grid.Row="2" Background="{StaticResource Panel2}"
                            BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="8">
                        <RichTextBox x:Name="LogBox" BorderThickness="0" Background="Transparent"
                                     IsReadOnly="True" FontFamily="Consolas" FontSize="12"
                                     Foreground="{StaticResource Text}"
                                     VerticalScrollBarVisibility="Auto"
                                     Padding="10,8" Margin="0"/>
                    </Border>
                </Grid>
            </Border>
        </Grid>

        <!-- Footer -->
        <Border Grid.Row="2" Background="{StaticResource Panel}"
                BorderBrush="{StaticResource Border}" BorderThickness="0,1,0,0" Padding="16,8">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock x:Name="FooterText" Text="PC Doctor Portable v1.2  -  Code Knot Technology  -  Windows Maintenance &amp; Repair Tool"
                           FontSize="11" Foreground="{StaticResource Muted}"
                           VerticalAlignment="Center"/>
                <Button x:Name="FeedbackButton" Grid.Column="1" Content="Feedback"
                        FontSize="11" Padding="10,3" Height="24"
                        Background="{StaticResource Panel2}" BorderBrush="{StaticResource Border}"
                        Foreground="{StaticResource Text}" BorderThickness="1" Cursor="Hand"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$Xaml = $Xaml -replace 'mc:Ignorable="d"', ''
$Xaml = $Xaml -replace 'xmlns:d="http://schemas.microsoft.com/expression/blend/2008"', ''
$Xaml = $Xaml -replace 'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"', ''

$Reader = [System.Xml.XmlReader]::Create(
    (New-Object System.IO.StringReader($Xaml))
)
$Window = [System.Windows.Markup.XamlReader]::Load($Reader)
$Reader.Close()

# Own application logo (title bar + taskbar) instead of the
# default Windows PowerShell icon
$IconPath = Join-Path $AppRoot "Assets\PCDoctor.ico"
try
{
    if (Test-Path $IconPath)
    {
        $Window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create(
            (New-Object System.Uri($IconPath))
        )

        if ($HeaderLogo)
        {
            $HeaderLogo.Source = $Window.Icon
        }
    }
}
catch {}

# ----------------------------------------------------------
# UI wiring
# ----------------------------------------------------------

$StartButton   = $Window.FindName("StartButton")
$AbortButton   = $Window.FindName("AbortButton")
$ModulePanel   = $Window.FindName("ModulePanel")
$LogBox        = $Window.FindName("LogBox")
$ProgressBar   = $Window.FindName("ProgressBar")
$StatusText    = $Window.FindName("StatusText")
$ProgressText  = $Window.FindName("ProgressText")
$SubtitleText  = $Window.FindName("SubtitleText")
$ModeLabel     = $Window.FindName("ModeLabel")
$ModeTitleText = $Window.FindName("ModeTitleText")
$ModeNoteText  = $Window.FindName("ModeNoteText")
$ModulesLabel  = $Window.FindName("ModulesLabel")
$OutputLabel   = $Window.FindName("OutputLabel")
$FooterText    = $Window.FindName("FooterText")
$LangBox       = $Window.FindName("LangBox")
$UpdateText    = $Window.FindName("UpdateText")
$ThemeButton    = $Window.FindName("ThemeButton")
$DownloadButton = $Window.FindName("DownloadButton")
$HeaderLogo    = $Window.FindName("HeaderLogo")
$NavDashboard   = $Window.FindName("NavDashboard")
$NavModules     = $Window.FindName("NavModules")
$NavSettings    = $Window.FindName("NavSettings")
$NavHistory     = $Window.FindName("NavHistory")
$NavDashboardText = $Window.FindName("NavDashboardText")
$NavModulesText   = $Window.FindName("NavModulesText")
$NavSettingsText  = $Window.FindName("NavSettingsText")
$NavHistoryText   = $Window.FindName("NavHistoryText")
$BackButton        = $Window.FindName("BackButton")
$DashboardView     = $Window.FindName("DashboardView")
$ModulesView       = $Window.FindName("ModulesView")
$DashDot      = $Window.FindName("DashDot")
$DashHealthText = $Window.FindName("DashHealthText")
$DashHealthNote = $Window.FindName("DashHealthNote")
$DashOs      = $Window.FindName("DashOs")
$DashCpu     = $Window.FindName("DashCpu")
$DashRam     = $Window.FindName("DashRam")
$DashUptime  = $Window.FindName("DashUptime")
$DashLastRun = $Window.FindName("DashLastRun")
$DashNextRun = $Window.FindName("DashNextRun")
$DashVersion = $Window.FindName("DashVersion")
$DashRamBar    = $Window.FindName("DashRamBar")
$DashRamText   = $Window.FindName("DashRamText")
$DashDiskBar   = $Window.FindName("DashDiskBar")
$DashDiskText  = $Window.FindName("DashDiskText")
$DashUpdates   = $Window.FindName("DashUpdates")
$SettingsView      = $Window.FindName("SettingsView")
$SettingsList      = $Window.FindName("SettingsList")
$SettingsTitle     = $Window.FindName("SettingsTitle")
$SettingsHint      = $Window.FindName("SettingsHint")
$ScheduleDayLabel  = $Window.FindName("ScheduleDayLabel")
$ScheduleTimeLabel = $Window.FindName("ScheduleTimeLabel")
$ModulesScroll     = $Window.FindName("ModulesScroll")
$ScheduleCheck     = $Window.FindName("ScheduleCheck")
$ScheduleDayBox    = $Window.FindName("ScheduleDayBox")
$ScheduleHourBox   = $Window.FindName("ScheduleHourBox")
$ScheduleMinuteBox = $Window.FindName("ScheduleMinuteBox")
$ScheduleNextText  = $Window.FindName("ScheduleNextText")
$ScheduleTaskButton = $Window.FindName("ScheduleTaskButton")
$ScheduleTaskStatus = $Window.FindName("ScheduleTaskStatus")
$HistoryView        = $Window.FindName("HistoryView")
$HistoryList        = $Window.FindName("HistoryList")
$HistoryTitle       = $Window.FindName("HistoryTitle")
$HistoryHint        = $Window.FindName("HistoryHint")
$HistoryRefreshButton = $Window.FindName("HistoryRefreshButton")
$HistoryBackButton  = $Window.FindName("HistoryBackButton")
$FeedbackButton     = $Window.FindName("FeedbackButton")

# ----------------------------------------------------------
# Module list (matches Main.ps1 run order)
# ----------------------------------------------------------

$ModuleNames = @(
    "Internet Check",
    "Restore Point",
    "Windows Update",
    "Driver Update",
    "Software Update",
    "Microsoft Store",
    "Windows Repair",
    "Cleanup",
    "Optimization",
    "Verification",
    "Report",
    "Restart Manager"
)

$ModuleKeys = @(
    "ModuleInternet", "ModuleRestorePoint", "ModuleWindowsUpdate", "ModuleDrivers",
    "ModuleSoftware", "ModuleStore", "ModuleRepair", "ModuleCleanup",
    "ModuleOptimization", "ModuleVerification", "ModuleReport", "ModuleRestart"
)

function Get-GUIModuleDisplay
{
    param([int]$Index)

    $Key = $ModuleKeys[$Index]

    if ($Global:Strings -and $Global:Strings.$Global:CurrentLang -and $Global:Strings.$Global:CurrentLang.$Key)
    {
        return $Global:Strings.$Global:CurrentLang.$Key
    }

    return $ModuleNames[$Index]
}

$TotalModules = $ModuleNames.Count
$Script:ModuleRows = @{}
$Script:ModuleDisplayNames = @()
$Script:ModuleOutput = @{}
$Script:CurrentModule = $null
$Script:CompletedCount = 0
$Script:Running = $false
$Script:Proc = $null
$Script:LastLogPath = $null
$Script:LastPos = 0
$Script:UpdatePS = $null
$Script:UpdateHandle = $null
$Script:UpdateAssetUrl = $null
$Script:UpdateAssetName = $null
$Script:CurrentTheme = "Dark"
$Script:ScheduleEnabled = $false

# System Default theme: detect Windows app theme via registry
function Get-SystemTheme {
    try {
        $AppsUseLightTheme = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -ErrorAction SilentlyContinue).AppsUseLightTheme
        if ($null -eq $AppsUseLightTheme) { return 'Dark' }
        return if ($AppsUseLightTheme -eq 0) { 'Dark' } else { 'Light' }
    } catch { return 'Dark' }
}

# DPI awareness for sharp rendering
$Script:DpiScale = 1.0
try {
    $Source = [System.Windows.Interop.HwndSource]::FromHwnd([System.Windows.Interop.WindowInteropHelper]::new($Window).Handle)
    if ($Source) {
        $Script:DpiScale = $Source.CompositionTarget.TransformToDevice.M11
    }
} catch { $Script:DpiScale = [System.Windows.SystemParameters]::Dpi / 96.0 }
$Script:ScheduleDay = 0
$Script:ScheduleHour = 9
$Script:ScheduleMinute = 0
$Script:ScheduleRanOn = ""

# Brushes for status dots
$Script:BrushPending = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(0x8B, 0x98, 0xA9))
$Script:BrushRunning = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(0x4F, 0xC1, 0xFF))
$Script:BrushSuccess = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(0x3D, 0xDC, 0x84))
$Script:BrushFailed  = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(0xFF, 0x6B, 0x6B))
$Script:BrushWarn    = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(0xFF, 0xD8, 0x66))
$Script:BrushMuted   = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(0x8B, 0x98, 0xA9))
$Script:BrushRowHover = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(0x1F, 0x27, 0x33))

# ----------------------------------------------------------
# Theme (dark / light) - mutates the shared brushes so every
# control using them repaints automatically.
# ----------------------------------------------------------

$Script:DarkPalette = @{
    Bg     = "#0D1117"
    Panel  = "#161B22"
    Panel2 = "#1C2330"
    Border = "#2D3644"
    Text   = "#D7E0EA"
    Muted  = "#8B98A9"
    Accent = "#4FC1FF"
    Green  = "#3DDC84"
    Yellow = "#FFD866"
    Red    = "#FF6B6B"
    Header1 = "#10151F"
    Header2 = "#0D2838"
    RowHover = "#1F2733"
    StartG1 = "#4BE89A"
    StartG2 = "#23A564"
}

$Script:LightPalette = @{
    Bg     = "#F0F2F5"
    Panel  = "#FFFFFF"
    Panel2 = "#E8ECF1"
    Border = "#BCC3CE"
    Text   = "#111827"
    Muted  = "#4B5563"
    Accent = "#0066CC"
    Green  = "#15803D"
    Yellow = "#92400E"
    Red    = "#B91C1C"
    Header1 = "#FFFFFF"
    Header2 = "#DBEAFE"
    RowHover = "#E0E7EE"
    StartG1 = "#16A34A"
    StartG2 = "#15803D"
}

function Set-Theme
{
    param([string]$Theme)

    # Resolve 'System' to the actual OS theme
    $ResolvedTheme = if ($Theme -eq 'System') { Get-SystemTheme } else { $Theme }

    $P = if ($ResolvedTheme -eq "Light") { $Script:LightPalette } else { $Script:DarkPalette }

    $Names = @("Bg","Panel","Panel2","Border","Text","Muted","Accent","Green","Yellow","Red",
               "Header1","Header2","RowHover","StartG1","StartG2")

    foreach ($Name in $Names)
    {
        $Brush = $Window.FindResource($Name)
        $Brush.Color = [System.Windows.Media.ColorConverter]::ConvertFromString($P[$Name])
    }

    $Window.Background = $Window.FindResource("Bg")

    $Script:BrushPending.Color = [System.Windows.Media.ColorConverter]::ConvertFromString($P["Muted"])
    $Script:BrushRunning.Color = [System.Windows.Media.ColorConverter]::ConvertFromString($P["Accent"])
    $Script:BrushSuccess.Color = [System.Windows.Media.ColorConverter]::ConvertFromString($P["Green"])
    $Script:BrushFailed.Color  = [System.Windows.Media.ColorConverter]::ConvertFromString($P["Red"])
    $Script:BrushWarn.Color    = [System.Windows.Media.ColorConverter]::ConvertFromString($P["Yellow"])
    $Script:BrushMuted.Color   = [System.Windows.Media.ColorConverter]::ConvertFromString($P["Muted"])
    $Script:BrushRowHover.Color = [System.Windows.Media.ColorConverter]::ConvertFromString($P["RowHover"])

    # Update logo tint based on resolved theme
    try {
        $LogoPath = Join-Path $AppRoot "Assets" "PCDoctor.ico"
        if (Test-Path $LogoPath) {
            $LogoBitmap = New-Object System.Windows.Media.Imaging.BitmapImage
            $LogoBitmap.BeginInit()
            $LogoBitmap.UriSource = New-Object System.Uri($LogoPath)
            $LogoBitmap.CacheOption = "OnLoad"
            $LogoBitmap.EndInit()
            $LogoBitmap.Freeze()
            $HeaderLogo.Source = $LogoBitmap
        }
    } catch {}

    # Update theme button text
    $ThemeButton.Content = $Theme

    $Script:CurrentTheme = $Theme
}

# ----------------------------------------------------------
# User preferences (theme + language persist in %APPDATA%)
# ----------------------------------------------------------

$Script:PrefsDir  = Join-Path $env:APPDATA "PCDoctorPortable"
$Script:PrefsFile = Join-Path $Script:PrefsDir "prefs.json"

function Load-Prefs
{
    try
    {
        if (Test-Path $Script:PrefsFile)
        {
            $P = Get-Content $Script:PrefsFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($P.Theme) { $Script:CurrentTheme = $P.Theme }
            if ($P.Lang)  { $Global:CurrentLang = $P.Lang }
            if ($null -ne $P.ScheduleEnabled) { $Script:ScheduleEnabled = [bool]$P.ScheduleEnabled }
            if ($null -ne $P.ScheduleDay)     { $Script:ScheduleDay = [int]$P.ScheduleDay }
            if ($null -ne $P.ScheduleHour)    { $Script:ScheduleHour = [int]$P.ScheduleHour }
            if ($null -ne $P.ScheduleMinute)  { $Script:ScheduleMinute = [int]$P.ScheduleMinute }
        }
    }
    catch {}
}

function Save-Prefs
{
    try
    {
        New-Item -ItemType Directory -Path $Script:PrefsDir -Force | Out-Null

        @{
            Theme           = $Script:CurrentTheme
            Lang            = $Global:CurrentLang
            ScheduleEnabled = $Script:ScheduleEnabled
            ScheduleDay     = $Script:ScheduleDay
            ScheduleHour    = $Script:ScheduleHour
            ScheduleMinute  = $Script:ScheduleMinute
        } |
            ConvertTo-Json |
            Set-Content -Path $Script:PrefsFile -Encoding UTF8
    }
    catch {}
}

# ----------------------------------------------------------
# Settings panel - edit Config.json values from the GUI
# ----------------------------------------------------------

$Script:RunConfigPath = Join-Path $Script:PrefsDir "Config.json"

# Live dashboard state: cached pending-update count and the
# in-flight WU search (run on a background runspace so the UI
# never blocks), plus the last measured resource pressure.
$Script:WUCheck         = $null
$Script:WUCount         = $null
$Script:LastLivePressure = $false

$Script:SettingDefs = @(
    @{ Label = "ShowToast";       Key = "General.ShowToast" },
    @{ Label = "RestorePoint";    Key = "RestorePoint.Enabled" },
    @{ Label = "WindowsUpdate";   Key = "WindowsUpdate.Enabled" },
    @{ Label = "Drivers";         Key = "Drivers.Enabled" },
    @{ Label = "SoftwareUpdates"; Key = "Winget.Enabled" },
    @{ Label = "StoreUpdates";    Key = "Store.Enabled" },
    @{ Label = "DISM";            Key = "Repair.RunDISM" },
    @{ Label = "SFC";             Key = "Repair.RunSFC" },
    @{ Label = "TempCleanup";     Key = "Cleanup.CleanTemp" },
    @{ Label = "DiskCleanup";     Key = "Cleanup.RunDiskCleanup" },
    @{ Label = "Cookies";         Key = "Cleanup.CleanCookies" },
    @{ Label = "BrowserCache";    Key = "Cleanup.CleanBrowserCache" },
    @{ Label = "Prefetch";        Key = "Cleanup.CleanPrefetch" },
    @{ Label = "CrashDumps";      Key = "Cleanup.CleanCrashDumps" },
    @{ Label = "WUCache";         Key = "Cleanup.CleanWindowsUpdateCache" },
    @{ Label = "OptimizeDrives";  Key = "Optimization.OptimizeDrives" },
    @{ Label = "RestartExplorer"; Key = "Optimization.RestartExplorer" },
    @{ Label = "Thumbnails";      Key = "Optimization.ClearThumbnailCache" },
    @{ Label = "AutoRestart";     Key = "Restart.AutoRestart" }
)

function Get-ConfigValue
{
    param([string]$Path)

    $Current = $Global:Config

    foreach ($Part in ($Path -split "\."))
    {
        $Current = $Current.$Part
    }

    return $Current
}

function Set-ConfigValue
{
    param(
        [string]$Path,
        $Value
    )

    $Parts = $Path -split "\."
    $Current = $Global:Config

    for ($i = 0; $i -lt ($Parts.Count - 1); $i++)
    {
        $Current = $Current.$($Parts[$i])
    }

    $Current.($Parts[$Parts.Count - 1]) = $Value
}

function Save-Config
{
    param([string]$Path = "")

    if (-not $Path) { $Path = $Script:RunConfigPath }

    try
    {
        New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null

        $Global:Config |
            ConvertTo-Json -Depth 10 |
            Set-Content -Path $Path -Encoding UTF8

        return $true
    }
    catch
    {
        return $false
    }
}

function Build-SettingsList
{
    $SettingsList.Children.Clear()

    foreach ($Def in $Script:SettingDefs)
    {
        $Label = $Global:Strings.$Global:CurrentLang.($Def.Label)

        $Check = New-Object System.Windows.Controls.CheckBox
        $Check.Content = $Label
        $Check.Margin = New-Object System.Windows.Thickness(0, 3, 0, 3)
        $Check.Foreground = $Script:BrushMuted
        $Check.IsChecked = [bool](Get-ConfigValue -Path $Def.Key)

        $Key = $Def.Key

        $Check.Add_Click({
            Set-ConfigValue -Path $Key -Value ([bool]$Check.IsChecked)
            Save-Config
        })

        $SettingsList.Children.Add($Check) | Out-Null
    }
}

function Set-NavState
{
    param([int]$Index)

    $Nav  = @($NavDashboard, $NavModules, $NavSettings, $NavHistory)
    $Text = @($NavDashboardText, $NavModulesText, $NavSettingsText, $NavHistoryText)

    for ($i = 0; $i -lt 4; $i++)
    {
        if ($i -eq $Index)
        {
            $Nav[$i].Background = $Window.FindResource("Panel2")
            $Nav[$i].Foreground = $Window.FindResource("Accent")
            $Text[$i].FontWeight = "SemiBold"
        }
        else
        {
            $Nav[$i].Background = [System.Windows.Media.Brushes]::Transparent
            $Nav[$i].Foreground = $Window.FindResource("Muted")
            $Text[$i].FontWeight = "Normal"
        }
    }
}

# 0 = Dashboard, 1 = Modules, 2 = Settings, 3 = History
function Set-ActiveView
{
    param([int]$Index)

    $Views = @($DashboardView, $ModulesView, $SettingsView, $HistoryView)

    # Smooth fade + slide-up when switching views (Fluent-style).
    # Skipped in self-test / render mode: the WPF animation clock
    # never pumps there, so views would stay at Opacity 0.
    $Animate = -not ($SelfTest -or $RenderShot)

    for ($i = 0; $i -lt 4; $i++)
    {
        if ($i -eq $Index)
        {
            $Views[$i].Visibility = "Visible"

            if ($Animate)
            {
                $Views[$i].Opacity = 0

                $Fade = New-Object System.Windows.Media.Animation.DoubleAnimation(0, 1, [TimeSpan]::FromMilliseconds(220))
                $Fade.EasingFunction = New-Object System.Windows.Media.Animation.CubicEase
                $Fade.EasingFunction.EasingMode = "EaseOut"
                $Views[$i].BeginAnimation([System.Windows.UIElement]::OpacityProperty, $Fade)

                $Slide = New-Object System.Windows.Media.TranslateTransform(0, 8)
                $Views[$i].RenderTransform = $Slide
                $Views[$i].RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0)

                $SlideAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(8, 0, [TimeSpan]::FromMilliseconds(220))
                $SlideAnim.EasingFunction = New-Object System.Windows.Media.Animation.CubicEase
                $SlideAnim.EasingFunction.EasingMode = "EaseOut"
                $Slide.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $SlideAnim)
            }
            else
            {
                $Views[$i].Opacity = 1
            }
        }
        else
        {
            $Views[$i].Visibility = "Collapsed"
        }
    }

    Set-NavState -Index $Index

    if ($Index -eq 0) { Refresh-Dashboard }
    if ($Index -eq 2) { Build-SettingsList }
    if ($Index -eq 3) { Build-HistoryList }
}

function Show-ModulesView  { Set-ActiveView -Index 1 }
function Show-SettingsView { Set-ActiveView -Index 2 }
function Show-HistoryView  { Set-ActiveView -Index 3 }

function Refresh-Dashboard
{
    if (-not $Global:Strings) { return }

    $S = $Global:Strings.$Global:CurrentLang

    # Health + last run from the most recent scheduled run
    $SummaryFile = Join-Path $Script:PrefsDir "scheduled-runs.json"
    $Last = $null

    if (Test-Path $SummaryFile)
    {
        $Runs = @(Get-Content $SummaryFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json)

        if ($Runs.Count -gt 0) { $Last = $Runs[$Runs.Count - 1] }
    }

    $CardStatus = "NONE"
    $CardNote   = $S.DashNoRuns

    if ($Last)
    {
        switch ($Last.Status)
        {
            "SUCCESS" { $CardStatus = "OK";   $CardNote = $S.DashSystemHealthy }
            "WARNING" { $CardStatus = "WARN"; $CardNote = $S.DashSystemWarn }
            "FAILED"  { $CardStatus = "FAIL"; $CardNote = $S.DashSystemFail }
        }

        $DashLastRun.Text = ($S.DashLastRun -f $Last.Date)
    }
    else
    {
        $DashLastRun.Text = $S.DashNoRuns
    }

    # Remember the base verdict so the live timer can restore it
    # once any momentary resource pressure clears.
    $Script:LastRunHealth = @{ Status = $CardStatus; Note = $CardNote }

    Set-DashHealthCard -Status $CardStatus -Note $CardNote

    # Next scheduled run
    if ($Script:ScheduleEnabled)
    {
        $Next = Get-NextRunTime
        $DashNextRun.Text = ($S.DashNextRun -f $Next.ToString("dddd, dd MMM yyyy HH:mm"))
    }
    else
    {
        $DashNextRun.Text = ($S.DashNextRun -f $S.ScheduleDisabled)
    }

    $DashVersion.Text = ($S.DashVersion -f $Version)

    # System info (cheap guarded queries)
    try { $DashOs.Text = [System.Environment]::OSVersion.VersionString } catch {}
    try { $DashCpu.Text = (Get-CimInstance Win32_Processor | Select-Object -First 1 -ExpandProperty Name) } catch {}
    try { $DashRam.Text = ("RAM : {0} GB" -f [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)) } catch {}
    try
    {
        $Up = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $DashUptime.Text = ("Uptime : {0}d {1}h {2}m" -f $Up.Days, $Up.Hours, $Up.Minutes)
    }
    catch {}

    # Live resource stats + pending-update count (real data)
    Update-LiveStats
    Start-PendingUpdateCheck
    Update-PendingUpdatesText
}

function Set-DashHealthCard
{
    param(
        [string]$Status,
        [string]$Note
    )

    switch ($Status)
    {
        "OK"   { $Color = "Green";  $Text = $Global:Strings.$Global:CurrentLang.DashHealthOk }
        "WARN" { $Color = "Yellow"; $Text = $Global:Strings.$Global:CurrentLang.DashHealthWarn }
        "FAIL" { $Color = "Red";    $Text = $Global:Strings.$Global:CurrentLang.DashHealthFail }
        Default{ $Color = "Muted";  $Text = $Global:Strings.$Global:CurrentLang.DashNoRunsTitle }
    }

    $DashHealthText.Text       = $Text
    $DashHealthText.Foreground = $Window.FindResource($Color)
    $DashDot.Fill              = $Window.FindResource($Color)
    $DashHealthNote.Text       = $Note
}

# Real RAM / disk / CPU readings - direct CIM calls, no fake data.
function Get-LiveStats
{
    $Stats = @{ RamPct = 0; DiskPct = 0; DiskLabel = $env:SystemDrive; CpuPct = $null }

    try
    {
        $OS = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $Total = [double]$OS.TotalVisibleMemorySize
        $Free  = [double]$OS.FreePhysicalMemory

        if ($Total -gt 0)
        {
            $Stats.RamPct = [math]::Round(100 * (1 - ($Free / $Total)), 0)
        }
    }
    catch {}

    try
    {
        $Drive = Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction Stop
        $Used  = [double]$Drive.Used
        $FreeD = [double]$Drive.Free

        if (($Used + $FreeD) -gt 0)
        {
            $Stats.DiskPct = [math]::Round(100 * $Used / ($Used + $FreeD), 0)
        }
    }
    catch {}

    try
    {
        $Cpu = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop
        $Stats.CpuPct = [double]$Cpu.PercentProcessorTime
    }
    catch {}

    return $Stats
}

# Live gauges + the momentary health-card override when RAM or
# disk pressure is high (>= 92% - real readings, not estimates).
function Update-LiveStats
{
    if (-not $Global:Strings -or -not $DashRamBar) { return }

    $S = $Global:Strings.$Global:CurrentLang
    $Stats = Get-LiveStats

    $DashRamBar.Value      = $Stats.RamPct
    $DashRamBar.Foreground = if ($Stats.RamPct -ge 90) { $Window.FindResource("Red") }
                             elseif ($Stats.RamPct -ge 75) { $Window.FindResource("Yellow") }
                             else { $Window.FindResource("Green") }
    $DashRamText.Text      = ("{0}%" -f $Stats.RamPct)

    $DashDiskBar.Value      = $Stats.DiskPct
    $DashDiskBar.Foreground = if ($Stats.DiskPct -ge 90) { $Window.FindResource("Red") }
                              elseif ($Stats.DiskPct -ge 75) { $Window.FindResource("Yellow") }
                              else { $Window.FindResource("Accent") }
    $DashDiskText.Text      = ("{0}%" -f $Stats.DiskPct)

    # CPU load appended to the CPU model line (no accumulation)
    if ($null -ne $Stats.CpuPct -and $DashCpu.Text)
    {
        try
        {
            $Base = [string]($DashCpu.Text -replace "\s+\d+%$", "")
            $DashCpu.Text = ("{0}   {1}%" -f $Base, [math]::Round($Stats.CpuPct, 0))
        }
        catch {}
    }

    $Script:LastLivePressure = ($Stats.RamPct -ge 92 -or $Stats.DiskPct -ge 92)

    if ($Script:LastLivePressure)
    {
        Set-DashHealthCard -Status "WARN" -Note $S.DashLiveWarn
    }
    elseif ($Script:LastRunHealth)
    {
        Set-DashHealthCard -Status $Script:LastRunHealth.Status -Note $Script:LastRunHealth.Note
    }
}

# Background Windows Update search for the pending-update count.
# Runs on its own STA runspace (the WU COM API needs STA) so the
# UI never blocks; the live timer polls for completion.
function Start-PendingUpdateCheck
{
    if ($SelfTest -or $RenderShot) { return }

    if ($Script:WUCheck -and -not $Script:WUCheck.Handle.IsCompleted) { return }

    # Throttle: at most one fresh WU query every 10 minutes
    if ($Script:WUCheck -and ((Get-Date) - $Script:WUCheck.Started).TotalMinutes -lt 10) { return }

    try
    {
        # Create a dedicated STA runspace (the WU COM API needs STA);
        # [powershell]::Create() reuses an already-open runspace, so
        # the apartment state must be set on a fresh RunspaceFactory
        # instance before Open() is called.
        $RS = [runspacefactory]::CreateRunspace()
        $RS.ApartmentState = "STA"
        $RS.Open()

        $PS = [powershell]::Create()
        $PS.Runspace = $RS
        $null = $PS.AddScript(@'
            try
            {
                $Session  = New-Object -ComObject Microsoft.Update.Session
                $Searcher = $Session.CreateUpdateSearcher()
                return @($Searcher.Search("IsInstalled=0 and IsHidden=0").Updates).Count
            }
            catch { return -1 }
'@)
        $Script:WUCheck = @{ PS = $PS; Handle = $PS.BeginInvoke(); Started = Get-Date }
    }
    catch
    {
        $Script:WUCheck = $null
    }
}

function Poll-PendingUpdateCheck
{
    if (-not $Script:WUCheck -or -not $Script:WUCheck.Handle.IsCompleted) { return }

    try
    {
        # EndInvoke returns a PSDataCollection - the real result
        # is its first element (the WU script returns one number).
        $Results = $Script:WUCheck.PS.EndInvoke($Script:WUCheck.Handle)
        $Script:WUCount = if ($Results -and $Results.Count -gt 0) { [int]$Results[0] } else { -1 }
    }
    catch
    {
        $Script:WUCount = $null
    }
    finally
    {
        try { $Script:WUCheck.PS.Dispose() } catch {}
        $Script:WUCheck = $null
    }

    Update-PendingUpdatesText
}

function Update-PendingUpdatesText
{
    if (-not $Global:Strings -or -not $DashUpdates) { return }

    $S = $Global:Strings.$Global:CurrentLang

    if ($Script:WUCheck -and -not $Script:WUCheck.Handle.IsCompleted)
    {
        $DashUpdates.Text = ($S.DashUpdates + " : " + $S.DashUpdatesChecking)
        return
    }

    if ($null -eq $Script:WUCount)
    {
        $DashUpdates.Text = ($S.DashUpdates + " : " + $S.DashUpdatesUnavailable)
        return
    }

    if ($Script:WUCount -le 0)
    {
        $DashUpdates.Text = ($S.DashUpdates + " : " + $S.DashUpdatesNone)
    }
    else
    {
        $DashUpdates.Text = ($S.DashUpdates + " : " + (($S.DashUpdatesCount -f $Script:WUCount)))
    }
}

function Build-HistoryList
{
    if (-not $Global:Strings) { return }

    $S = $Global:Strings.$Global:CurrentLang

    $HistoryList.Items.Clear()

    # Scheduled (background) runs first - with status badges
    $SummaryFile = Join-Path $Script:PrefsDir "scheduled-runs.json"
    $ScheduledCount = 0

    if (Test-Path $SummaryFile)
    {
        $Runs = @(Get-Content $SummaryFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json)

        foreach ($Run in $Runs | Select-Object -Last 8)
        {
            $Badge = switch ($Run.Status)
            {
                "SUCCESS" { "[ OK ]" }
                "WARNING" { "[WARN]" }
                "FAILED"  { "[FAIL]" }
                Default   { "[ ?? ]" }
            }

            $Color = switch ($Run.Status)
            {
                "SUCCESS" { $Script:BrushSuccess }
                "WARNING" { $Script:BrushWarn }
                "FAILED"  { $Script:BrushFailed }
                Default   { $Script:BrushMuted }
            }

            $Item = New-Object System.Windows.Controls.ListBoxItem
            $Item.Content = ("SCHEDULED  {0}   {1}   {2} OK / {3} warn / {4} fail" -f $Run.Date, $Badge, $Run.Ok, $Run.Warn, $Run.Fail)
            $Item.Foreground = $Color
            $Item.FontWeight = "SemiBold"
            $Item.Tag = $SummaryFile
            $Item.Cursor = "Hand"
            $Item.ToolTip = $SummaryFile
            $null = $HistoryList.Items.Add($Item)
            $ScheduledCount++
        }
    }

    # Log / report files, newest first
    $Entries = @()

    foreach ($Folder in @((Join-Path $AppRoot "Logs"), (Join-Path $AppRoot "Reports")))
    {
        if (Test-Path $Folder)
        {
            $Entries += Get-ChildItem $Folder -File -Filter *.txt -ErrorAction SilentlyContinue
        }
    }

    $Entries = @($Entries | Sort-Object LastWriteTime -Descending)

    if ($ScheduledCount -eq 0 -and $Entries.Count -eq 0)
    {
        $HistoryHint.Text = $S.HistoryEmpty
        return
    }

    $HistoryHint.Text = (($ScheduledCount + $Entries.Count).ToString() + " entries")

    foreach ($File in $Entries)
    {
        $Item = New-Object System.Windows.Controls.ListBoxItem
        $Item.Content = ("{0}   ({1:yyyy-MM-dd HH:mm}  {2:N0} KB)" -f $File.Name, $File.LastWriteTime, ($File.Length / 1KB))
        $Item.Tag = $File.FullName
        $Item.Cursor = "Hand"
        $Item.ToolTip = $File.FullName
        $null = $HistoryList.Items.Add($Item)
    }
}

# Generic text viewer used by the run-history list
function Show-FileView
{
    param([string]$Path)

    if (-not $Path -or -not (Test-Path $Path)) { return }

    $S = $Global:Strings.$Global:CurrentLang
    if (-not $S) { return }

    $Viewer = New-Object System.Windows.Window
    $Viewer.Title = (Split-Path $Path -Leaf)
    $Viewer.Width = 640
    $Viewer.Height = 460
    $Viewer.WindowStartupLocation = "CenterOwner"
    $Viewer.Owner = $Window
    $Viewer.Icon = $Window.Icon
    $Viewer.Background = $Window.FindResource("Panel")
    $Viewer.Foreground = $Window.FindResource("Text")
    $Viewer.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe UI")

    $Root = New-Object System.Windows.Controls.DockPanel
    $Root.Margin = New-Object System.Windows.Thickness(14)

    $Title = New-Object System.Windows.Controls.TextBlock
    $Title.Text = (Split-Path $Path -Leaf)
    $Title.FontSize = 14
    $Title.FontWeight = "Bold"
    $Title.Foreground = $Window.FindResource("Accent")
    $Title.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    [System.Windows.Controls.DockPanel]::SetDock($Title, "Top")
    $Root.Children.Add($Title) | Out-Null

    $CloseBtn = New-Object System.Windows.Controls.Button
    $CloseBtn.Content = $S.CloseBtn
    $CloseBtn.Height = 30
    $CloseBtn.MinWidth = 90
    $CloseBtn.HorizontalAlignment = "Right"
    $CloseBtn.Margin = New-Object System.Windows.Thickness(0, 10, 0, 0)
    $CloseBtn.Background = $Window.FindResource("Accent")
    $CloseBtn.Foreground = "White"
    $CloseBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $CloseBtn.Cursor = "Hand"
    $CloseBtn.Add_Click({ $Viewer.Close() })
    [System.Windows.Controls.DockPanel]::SetDock($CloseBtn, "Bottom")
    $Root.Children.Add($CloseBtn) | Out-Null

    $Box = New-Object System.Windows.Controls.TextBox
    $Box.IsReadOnly = $true
    $Box.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas")
    $Box.FontSize = 12
    $Box.Background = $Window.FindResource("Panel2")
    $Box.Foreground = $Window.FindResource("Text")
    $Box.BorderThickness = New-Object System.Windows.Thickness(0)
    $Box.Padding = New-Object System.Windows.Thickness(10, 8, 10, 8)
    $Box.VerticalScrollBarVisibility = "Auto"
    $Box.HorizontalScrollBarVisibility = "Auto"
    $Box.TextWrapping = "NoWrap"
    $Box.Text = (Get-Content $Path -Raw -ErrorAction SilentlyContinue)

    $Root.Children.Add($Box) | Out-Null

    $Viewer.Content = $Root
    $Viewer.Show()
}

# ----------------------------------------------------------
# Feedback / report-a-bug dialog
# ----------------------------------------------------------

function Get-LastFilePath
{
    param([string]$Folder)

    if (-not (Test-Path $Folder)) { return "" }

    $Latest = Get-ChildItem $Folder -File -Filter *.txt -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($Latest) { return $Latest.FullName }

    return ""
}

function Get-DiagnosticsText
{
    $Lines = @()

    $Lines += "PC Doctor Portable - Diagnostics"
    $Lines += "====================================="
    $Lines += ("App version : " + $Version)
    $Lines += ("Language    : " + $Global:CurrentLang)
    $Lines += ("Theme       : " + $Script:CurrentTheme)

    try   { $Lines += ("OS          : " + [System.Environment]::OSVersion.VersionString) } catch {}
    try   { $Lines += ("Machine     : " + $env:COMPUTERNAME) } catch {}
    try   { $Lines += ("CPU         : " + ((Get-CimInstance Win32_Processor | Select-Object -First 1).Name)) } catch {}
    try   { $Lines += ("RAM         : " + [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1) + " GB") } catch {}
    try   { $Lines += ("Uptime      : " + ((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).ToString()) } catch {}
    try   { $Lines += ("Update URL  : " + $Global:Config.General.UpdateUrl) } catch {}

    $LastLog = Get-LastFilePath (Join-Path $AppRoot "Logs")
    $LastReport = Get-LastFilePath (Join-Path $AppRoot "Reports")

    $NoLog = $Global:Strings.$Global:CurrentLang.FeedbackNoLog

    $Lines += ""
    $Lines += ("Last log    : " + $(if ($LastLog) { $LastLog } else { $NoLog }))
    $Lines += ("Last report : " + $(if ($LastReport) { $LastReport } else { $NoLog }))

    if ($LastLog)
    {
        $Tail = Get-Content $LastLog -Tail 40 -ErrorAction SilentlyContinue
        $Lines += ""
        $Lines += "--- Last log (tail) ---"
        $Lines += $Tail
    }

    if ($LastReport)
    {
        $Tail = Get-Content $LastReport -Tail 30 -ErrorAction SilentlyContinue
        $Lines += ""
        $Lines += "--- Last report (tail) ---"
        $Lines += $Tail
    }

    return ($Lines -join "`r`n")
}

function Show-FeedbackDialog
{
    $S = $Global:Strings.$Global:CurrentLang
    if (-not $S) { return }

    $Dialog = New-Object System.Windows.Window
    $Dialog.Title = $S.FeedbackTitle
    $Dialog.Width = 620
    $Dialog.Height = 540
    $Dialog.WindowStartupLocation = "CenterOwner"
    $Dialog.Owner = $Window
    $Dialog.Icon = $Window.Icon
    $Dialog.Background = $Window.FindResource("Panel")
    $Dialog.Foreground = $Window.FindResource("Text")
    $Dialog.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe UI")

    $Root = New-Object System.Windows.Controls.DockPanel
    $Root.Margin = New-Object System.Windows.Thickness(14)

    $Title = New-Object System.Windows.Controls.TextBlock
    $Title.Text = $S.FeedbackTitle
    $Title.FontSize = 16
    $Title.FontWeight = "Bold"
    $Title.Foreground = $Window.FindResource("Accent")
    [System.Windows.Controls.DockPanel]::SetDock($Title, "Top")
    $Root.Children.Add($Title) | Out-Null

    $Desc = New-Object System.Windows.Controls.TextBlock
    $Desc.Text = $S.FeedbackDesc
    $Desc.TextWrapping = "Wrap"
    $Desc.FontSize = 12
    $Desc.Foreground = $Window.FindResource("Muted")
    $Desc.Margin = New-Object System.Windows.Thickness(0, 4, 0, 10)
    [System.Windows.Controls.DockPanel]::SetDock($Desc, "Top")
    $Root.Children.Add($Desc) | Out-Null

    $Status = New-Object System.Windows.Controls.TextBlock
    $Status.FontSize = 11
    $Status.Foreground = $Window.FindResource("Green")
    $Status.Margin = New-Object System.Windows.Thickness(0, 8, 0, 0)
    [System.Windows.Controls.DockPanel]::SetDock($Status, "Bottom")
    $Root.Children.Add($Status) | Out-Null

    $Buttons = New-Object System.Windows.Controls.StackPanel
    $Buttons.Orientation = "Horizontal"
    $Buttons.HorizontalAlignment = "Right"
    $Buttons.Margin = New-Object System.Windows.Thickness(0, 10, 0, 0)
    [System.Windows.Controls.DockPanel]::SetDock($Buttons, "Bottom")
    $Root.Children.Add($Buttons) | Out-Null

    $OpenBtn = New-Object System.Windows.Controls.Button
    $OpenBtn.Content = $S.FeedbackOpenIssue
    $OpenBtn.Height = 30
    $OpenBtn.MinWidth = 120
    $OpenBtn.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    $OpenBtn.Background = $Window.FindResource("Accent")
    $OpenBtn.Foreground = "White"
    $OpenBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $OpenBtn.Cursor = "Hand"
    $Buttons.Children.Add($OpenBtn) | Out-Null

    $CopyBtn = New-Object System.Windows.Controls.Button
    $CopyBtn.Content = $S.FeedbackCopy
    $CopyBtn.Height = 30
    $CopyBtn.MinWidth = 120
    $CopyBtn.Background = $Window.FindResource("Panel2")
    $CopyBtn.Foreground = $Window.FindResource("Text")
    $CopyBtn.BorderBrush = $Window.FindResource("Border")
    $CopyBtn.Cursor = "Hand"
    $Buttons.Children.Add($CopyBtn) | Out-Null

    $CloseBtn = New-Object System.Windows.Controls.Button
    $CloseBtn.Content = $S.CloseBtn
    $CloseBtn.Height = 30
    $CloseBtn.MinWidth = 90
    $CloseBtn.Margin = New-Object System.Windows.Thickness(8, 0, 0, 0)
    $CloseBtn.Background = $Window.FindResource("Panel2")
    $CloseBtn.Foreground = $Window.FindResource("Text")
    $CloseBtn.BorderBrush = $Window.FindResource("Border")
    $CloseBtn.Cursor = "Hand"
    $CloseBtn.Add_Click({ $Dialog.Close() })
    $Buttons.Children.Add($CloseBtn) | Out-Null

    $Box = New-Object System.Windows.Controls.TextBox
    $Box.IsReadOnly = $true
    $Box.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas")
    $Box.FontSize = 11
    $Box.Background = $Window.FindResource("Panel2")
    $Box.Foreground = $Window.FindResource("Text")
    $Box.BorderThickness = New-Object System.Windows.Thickness(0)
    $Box.Padding = New-Object System.Windows.Thickness(10, 8, 10, 8)
    $Box.VerticalScrollBarVisibility = "Auto"
    $Box.TextWrapping = "NoWrap"
    $Box.Text = (Get-DiagnosticsText)

    $Root.Children.Add($Box) | Out-Null

    $OpenBtn.Add_Click({
        try
        {
            $Repo = $Global:Config.General.UpdateUrl -replace "https://api.github.com/repos/", "" -replace "/releases/latest", ""

            if (-not $Repo) { $Repo = "codeknot/pc-doctor-portable" }

            $Title = [Uri]::EscapeDataString("PC Doctor Portable bug report")
            $Body  = [Uri]::EscapeDataString($Box.Text)
            $Url   = ("https://github.com/{0}/issues/new?title={1}&body={2}" -f $Repo, $Title, $Body)

            Start-Process $Url | Out-Null
        }
        catch {}
    })

    $CopyBtn.Add_Click({
        try
        {
            Set-Clipboard -Value $Box.Text -ErrorAction Stop
            $Status.Text = $S.FeedbackCopied
        }
        catch {}
    })

    $Dialog.Content = $Root
    $Dialog.Show()
}

# ----------------------------------------------------------
# Scheduler - weekly auto-run at a fixed time
# ----------------------------------------------------------

$Script:SchedulerReady = $false

function Init-Scheduler
{
    $S = $Global:Strings.$Global:CurrentLang
    if (-not $S) { return }

    $Script:SchedulerReady = $false

    $ScheduleDayBox.Items.Clear()
    foreach ($Key in @("EveryDay","Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"))
    {
        $null = $ScheduleDayBox.Items.Add($S.$Key)
    }

    $ScheduleHourBox.Items.Clear()
    for ($h = 0; $h -lt 24; $h++)
    {
        $null = $ScheduleHourBox.Items.Add(("{0:00}" -f $h))
    }

    $ScheduleMinuteBox.Items.Clear()
    foreach ($m in @("00","15","30","45"))
    {
        $null = $ScheduleMinuteBox.Items.Add($m)
    }

    $ScheduleDayBox.SelectedIndex    = $Script:ScheduleDay
    $ScheduleHourBox.SelectedIndex   = $Script:ScheduleHour
    $ScheduleMinuteBox.SelectedIndex = [int]($Script:ScheduleMinute / 15)
    $ScheduleCheck.IsChecked         = $Script:ScheduleEnabled

    $Script:SchedulerReady = $true
}

function Get-NextRunTime
{
    $Target = Get-Date -Hour $Script:ScheduleHour -Minute $Script:ScheduleMinute -Second 0
    $Now = Get-Date

    for ($d = 0; $d -lt 8; $d++)
    {
        $Candidate = $Target.AddDays($d)
        $DayIndex = [int]$Candidate.DayOfWeek

        if (($Script:ScheduleDay -eq 0 -or $Script:ScheduleDay -eq ($DayIndex + 1)) -and $Candidate -gt $Now)
        {
            return $Candidate
        }
    }

    return $Target.AddDays(7)
}

function Update-NextRunText
{
    if (-not $Global:Strings) { return }

    $S = $Global:Strings.$Global:CurrentLang

    if (-not $Script:ScheduleEnabled)
    {
        $ScheduleNextText.Text = $S.ScheduleDisabled
        return
    }

    $Next = Get-NextRunTime
    $ScheduleNextText.Text = ($S.ScheduleNext -f $Next.ToString("dddd, dd MMM yyyy HH:mm"))

    Update-TaskButtonState
}

function Check-Schedule
{
    if (-not $Script:ScheduleEnabled) { return }
    if ($Script:Running) { return }

    $Now = Get-Date
    $DayIndex = [int]$Now.DayOfWeek

    if ($Script:ScheduleDay -ne 0 -and $Script:ScheduleDay -ne ($DayIndex + 1)) { return }

    $Today = $Now.ToString("yyyy-MM-dd")
    $Target = Get-Date -Hour $Script:ScheduleHour -Minute $Script:ScheduleMinute -Second 0

    if ($Now -ge $Target -and $Script:ScheduleRanOn -ne $Today)
    {
        $Script:ScheduleRanOn = $Today
        Start-Run
    }
}

function Sync-ScheduleState
{
    if (-not $Script:SchedulerReady) { return }

    $Script:ScheduleEnabled = [bool]$ScheduleCheck.IsChecked
    $Script:ScheduleDay     = [int]$ScheduleDayBox.SelectedIndex
    $Script:ScheduleHour    = [int]$ScheduleHourBox.SelectedIndex
    $Script:ScheduleMinute  = [int]@("00","15","30","45")[$ScheduleMinuteBox.SelectedIndex]

    Save-Prefs
    Update-NextRunText
}

# Wire the scheduler controls (after Init-Scheduler has set them)
$ScheduleCheck.Add_Click({ Sync-ScheduleState })
$ScheduleDayBox.Add_SelectionChanged({ if ($ScheduleDayBox.SelectedIndex -ge 0) { Sync-ScheduleState } })
$ScheduleHourBox.Add_SelectionChanged({ if ($ScheduleHourBox.SelectedIndex -ge 0) { Sync-ScheduleState } })
$ScheduleMinuteBox.Add_SelectionChanged({ if ($ScheduleMinuteBox.SelectedIndex -ge 0) { Sync-ScheduleState } })

# Check every 30 seconds while the GUI is running (also from the tray).
# The timer starts in the Launch section after strings are loaded.
$ScheduleTimer = New-Object System.Windows.Threading.DispatcherTimer
$ScheduleTimer.Interval = [TimeSpan]::FromSeconds(30)
$ScheduleTimer.Add_Tick({ Check-Schedule })

# Live dashboard: refresh the real RAM/disk/CPU gauges every
# 5 seconds while the Dashboard view is visible, and poll the
# background pending-update search for completion.
$LiveTimer = New-Object System.Windows.Threading.DispatcherTimer
$LiveTimer.Interval = [TimeSpan]::FromSeconds(5)
$LiveTimer.Add_Tick({
    if ($DashboardView.Visibility -ne "Visible") { return }

    Update-LiveStats
    Poll-PendingUpdateCheck
    Update-PendingUpdatesText
})

# ----------------------------------------------------------
# Windows Task Scheduler integration: "Register in Windows
# Task Scheduler" - the scheduled task runs Main.ps1 even
# when the GUI is closed. Registration needs elevation, so
# the helper script is launched via UAC and the result file
# is polled with a timer.
# ----------------------------------------------------------

function Update-TaskButtonState
{
    if (-not $Global:Strings -or -not $ScheduleTaskButton) { return }

    $S = $Global:Strings.$Global:CurrentLang

    if (Test-PCScheduledTask)
    {
        $ScheduleTaskButton.Content = $S.ScheduleTaskRemove
    }
    else
    {
        $ScheduleTaskButton.Content = $S.ScheduleTaskRegister
    }
}

function Start-TaskElevated
{
    param([string]$Action)

    $S = $Global:Strings.$Global:CurrentLang

    $ScheduleTaskStatus.Text = $S.ScheduleTaskConfirm
    $ScheduleTaskButton.IsEnabled = $false

    $ResultFile = Join-Path $env:TEMP "PCDoctorTaskResult.txt"
    Remove-Item $ResultFile -Force -ErrorAction SilentlyContinue

    $Helper = Join-Path $AppRoot "App\Register-TaskElevated.ps1"
    $Day    = [int]$ScheduleDayBox.SelectedIndex
    $Hour   = [int]$ScheduleHourBox.SelectedIndex
    $Minute = @("00","15","30","45")[[int]$ScheduleMinuteBox.SelectedIndex]
    $Time   = ("{0:00}:{1}" -f $Hour, $Minute)

    $Args = ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -Action {1} -Day {2} -Time {3}' -f $Helper, $Action, $Day, $Time)

    Start-Process -FilePath "powershell.exe" -ArgumentList $Args -Verb RunAs | Out-Null

    $Script:TaskPollStart  = Get-Date
    $Script:TaskPollAction = $Action
    $Script:TaskPollFile   = $ResultFile
    $Script:TaskPollTimer.Start()
}

function Poll-TaskResult
{
    if (-not $Script:TaskPollFile) { return }

    $S = $Global:Strings.$Global:CurrentLang

    if ((Get-Date) - $Script:TaskPollStart -gt [TimeSpan]::FromSeconds(90))
    {
        $Script:TaskPollTimer.Stop()
        $ScheduleTaskButton.IsEnabled = $true
        $ScheduleTaskStatus.Text = ($S.ScheduleTaskError -f "timeout")
        return
    }

    if (Test-Path $Script:TaskPollFile)
    {
        $Script:TaskPollTimer.Stop()

        $Content = Get-Content $Script:TaskPollFile -Raw -ErrorAction SilentlyContinue
        Remove-Item $Script:TaskPollFile -Force -ErrorAction SilentlyContinue
        $Script:TaskPollFile = ""
        $ScheduleTaskButton.IsEnabled = $true

        if ($Content -match "OK=True")
        {
            if ($Script:TaskPollAction -eq "Register")
            {
                $DayLabel = if ($Script:ScheduleDay -eq 0)
                {
                    $S.EveryDay
                }
                else
                {
                    @($S.Sunday, $S.Monday, $S.Tuesday, $S.Wednesday,
                      $S.Thursday, $S.Friday, $S.Saturday)[$Script:ScheduleDay - 1]
                }

                $TimeLabel = ("{0:00}:{1}" -f $Script:ScheduleHour, $Script:ScheduleMinute)
                $ScheduleTaskStatus.Text = ($S.ScheduleTaskRegistered -f ($DayLabel + " " + $TimeLabel))
            }
            else
            {
                $ScheduleTaskStatus.Text = $S.ScheduleTaskRemoved
            }
        }
        else
        {
            $Err = if ($Content -match "ERR=(.*)") { $Matches[1] } else { "unknown" }
            $ScheduleTaskStatus.Text = ($S.ScheduleTaskError -f $Err)
        }

        Update-TaskButtonState
    }
}

$Script:TaskPollTimer = New-Object System.Windows.Threading.DispatcherTimer
$Script:TaskPollTimer.Interval = [TimeSpan]::FromMilliseconds(600)
$Script:TaskPollTimer.Add_Tick({ Poll-TaskResult })

$ScheduleTaskButton.Add_Click({
    if (Test-PCScheduledTask)
    {
        Start-TaskElevated -Action "Unregister"
    }
    else
    {
        Start-TaskElevated -Action "Register"
    }
})

function New-StatusBrush
{
    param([string]$Hex)

    $Converter = New-Object System.Windows.Media.BrushConverter
    return $Converter.ConvertFromString($Hex)
}

# ----------------------------------------------------------
# Language switcher (English / Hindi)
# ----------------------------------------------------------

$Global:Strings = $null
$Global:CurrentLang = "EN"

# Restore saved theme/language preference
Load-Prefs

try
{
    $Global:Strings = Get-Content (Join-Path $AppRoot "App\strings.json") -Raw -Encoding UTF8 | ConvertFrom-Json
}
catch {}

function Apply-Language
{
    $S = $Global:Strings.$Global:CurrentLang
    if (-not $S) { return }

    $SubtitleText.Text   = $S.Subtitle
    $ModeLabel.Text      = $S.ModeLabel
    $ModeTitleText.Text  = $S.ModeTitle
    $ModeNoteText.Text   = $S.ModeNote
    $StartButton.Content = $S.Start
    $AbortButton.Content = $S.Abort
    $ModulesLabel.Text   = $S.ModulesLabel
    $OutputLabel.Text    = $S.OutputLabel
    $FooterText.Text     = $S.Footer
    $NavDashboardText.Text  = $S.NavDashboard
    $NavModulesText.Text    = $S.NavModules
    $NavSettingsText.Text   = $S.NavSettings
    $NavHistoryText.Text    = $S.NavHistory
    $BackButton.Content     = $S.BackToModules
    $HistoryTitle.Text      = $S.HistoryTitle
    $HistoryRefreshButton.Content = $S.HistoryRefresh
    $HistoryBackButton.Content    = $S.BackToModules
    $FeedbackButton.Content = $S.Feedback
    $SettingsTitle.Text     = $S.SettingsTitle
    $SettingsHint.Text      = $S.SettingsHint
    $ScheduleCheck.Content  = $S.ScheduleEnabled
    $ScheduleDayLabel.Text  = $S.ScheduleDay
    $ScheduleTimeLabel.Text = $S.ScheduleTime

    # Rebuild translated day names (keep selection)
    if ($ScheduleDayBox.Items.Count -gt 0)
    {
        $Selection = $ScheduleDayBox.SelectedIndex
        $ScheduleDayBox.Items.Clear()

        foreach ($Key in @("EveryDay","Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"))
        {
            $null = $ScheduleDayBox.Items.Add($S.$Key)
        }

        $ScheduleDayBox.SelectedIndex = $Selection
    }

    if ($Global:Strings)
    {
        Build-SettingsList
    }

    if (-not $Script:Running)
    {
        $StatusText.Text = $S.Ready
        Build-ModuleList
        Reset-ModuleList
    }

    Update-NextRunText
}

# Populate the language combo box (label text comes from
# strings.json so this source stays pure ASCII)
if ($Global:Strings)
{
    $null = $LangBox.Items.Add("English")
    $null = $LangBox.Items.Add($Global:Strings.EN.LangDisplay)
    $LangBox.SelectedIndex = if ($Global:CurrentLang -eq "HI") { 1 } else { 0 }

    $LangBox.Add_SelectionChanged({
        if ($LangBox.SelectedIndex -eq 1)
        {
            $Global:CurrentLang = "HI"
        }
        else
        {
            $Global:CurrentLang = "EN"
        }

        Apply-Language
        Save-Prefs
    })
}

# ----------------------------------------------------------
# Auto-update check (background runspace, GitHub releases API)
# ----------------------------------------------------------

function Start-UpdateCheck
{
    $S = $Global:Strings.$Global:CurrentLang

    if (-not $Global:Config -or -not $Global:Config.General.UpdateUrl)
    {
        if ($S) { $UpdateText.Text = $S.UpdateUnavailable }
        return
    }

    if ($S) { $UpdateText.Text = $S.CheckUpdate }
    $UpdateText.Foreground = $Script:BrushMuted

    $ScriptBlock = {
        param($UpdateUrl, $CurrentVersion)

        try
        {
            $Request = [System.Net.HttpWebRequest]::Create($UpdateUrl)
            $Request.Timeout = 10000
            $Request.ReadWriteTimeout = 10000
            $Request.UserAgent = "PCDoctorPortable"

            $Response = $Request.GetResponse()
            $Reader = New-Object System.IO.StreamReader($Response.GetResponseStream())
            $Json = $Reader.ReadToEnd()
            $Reader.Dispose()
            $Response.Dispose()

            $Release = $Json | ConvertFrom-Json

            $Asset = $Release.assets | Select-Object -First 1
            $AssetUrl  = if ($Asset) { $Asset.browser_download_url } else { $null }
            $AssetName = if ($Asset) { $Asset.name } else { $null }

            $TagMatch = [regex]::Match(($Release.tag_name -replace "^[vV]", ""), "\d+([._]\d+)*")
            $Latest = ($TagMatch.Value -replace "_", ".")

            if (-not $Latest)
            {
                return @{ Newer = $false; Version = $Release.tag_name; Url = $Release.html_url }
            }

            try
            {
                $CParts = $CurrentVersion -split "\."
                while ($CParts.Count -lt 3) { $CParts += "0" }
                $LParts = $Latest -split "\."
                while ($LParts.Count -lt 3) { $LParts += "0" }

                $CurVer = [version]($CParts -join ".")
                $LatVer = [version]($LParts -join ".")

                if ($LatVer -gt $CurVer)
                {
                    return @{ Newer = $true; Version = $Latest; Url = $Release.html_url; AssetUrl = $AssetUrl; AssetName = $AssetName }
                }
            }
            catch {}

            return @{ Newer = $false; Version = $Latest; Url = $Release.html_url; AssetUrl = $null; AssetName = $null }
        }
        catch
        {
            return @{ Newer = $null }
        }
    }

    $Script:UpdatePS = [powershell]::Create()
    [void]$Script:UpdatePS.AddScript($ScriptBlock)
    [void]$Script:UpdatePS.AddArgument($Global:Config.General.UpdateUrl)
    [void]$Script:UpdatePS.AddArgument($Global:Config.General.Version)

    $Script:UpdateHandle = $Script:UpdatePS.BeginInvoke()
}

function Complete-UpdateCheck
{
    if (-not $Script:UpdateHandle -or -not $Script:UpdateHandle.IsCompleted) { return }

    $Info = $null

    try
    {
        $Result = $Script:UpdatePS.EndInvoke($Script:UpdateHandle)
        $Info = $Result[0]
    }
    catch
    {
        $Info = $null
    }
    finally
    {
        $Script:UpdatePS.Dispose()
        $Script:UpdatePS = $null
        $Script:UpdateHandle = $null
    }

    $S = $Global:Strings.$Global:CurrentLang
    if (-not $S) { return }

    if ($Info -and $Info.Newer -eq $true)
    {
        $UpdateText.Text = ($S.UpdateAvailable -f $Info.Version)
        $UpdateText.Foreground = $Script:BrushWarn

        if ($Info.AssetUrl)
        {
            $Script:UpdateAssetUrl  = $Info.AssetUrl
            $Script:UpdateAssetName = $Info.AssetName

            $DownloadButton.Content = $S.Download
            $DownloadButton.Visibility = "Visible"
            $DownloadButton.IsEnabled = $true
        }
        else
        {
            $DownloadButton.Visibility = "Collapsed"
        }
    }
    elseif ($Info -and $Info.Newer -eq $false)
    {
        $UpdateText.Text = ($S.UpToDate -f $Info.Version)
        $UpdateText.Foreground = $Script:BrushMuted
        $DownloadButton.Visibility = "Collapsed"
    }
    else
    {
        $UpdateText.Text = $S.UpdateUnavailable
        $UpdateText.Foreground = $Script:BrushMuted
        $DownloadButton.Visibility = "Collapsed"
    }
}

function Start-DownloadUpdate
{
    param(
        [string]$Url,
        [string]$FileName
    )

    $S = $Global:Strings.$Global:CurrentLang

    $DownloadDir = Join-Path ([Environment]::GetFolderPath("UserProfile")) "Downloads"
    New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null

    $Target = Join-Path $DownloadDir $FileName

    $DownloadButton.IsEnabled = $false
    $UpdateText.Text = $S.Downloading
    $UpdateText.Foreground = $Script:BrushMuted

    try
    {
        $Client = New-Object System.Net.WebClient
        $Client.DownloadFile($Url, $Target)
        $Client.Dispose()

        $UpdateText.Text = ($S.Downloaded -f $FileName)
        $UpdateText.Foreground = $Script:BrushSuccess

        # Open Explorer with the downloaded file selected
        Start-Process explorer.exe -ArgumentList ("/select,`"" + $Target + "`"")
    }
    catch
    {
        $UpdateText.Text = ($S.DownloadFailed -f $_.Exception.Message)
        $UpdateText.Foreground = $Script:BrushFailed
        $DownloadButton.IsEnabled = $true
    }
}

$DownloadButton.Add_Click({
    if ($Script:UpdateAssetUrl -and $Script:UpdateAssetName)
    {
        Start-DownloadUpdate -Url $Script:UpdateAssetUrl -FileName $Script:UpdateAssetName
    }
})

$NavDashboard.Add_Click({ Set-ActiveView -Index 0 })
$NavModules.Add_Click({ Set-ActiveView -Index 1 })
$NavSettings.Add_Click({ Set-ActiveView -Index 2 })
$NavHistory.Add_Click({ Set-ActiveView -Index 3 })
$BackButton.Add_Click({ Show-ModulesView })
$HistoryBackButton.Add_Click({ Show-ModulesView })
$HistoryRefreshButton.Add_Click({ Build-HistoryList })
$FeedbackButton.Add_Click({ Show-FeedbackDialog })

# Double-click / Enter a history entry to open it; also handle
# selection when the list is rebuilt (guard against stale tags)
$HistoryList.Add_SelectionChanged({
    $Item = $HistoryList.SelectedItem
    if ($Item -and $Item.Tag -and (Test-Path $Item.Tag))
    {
        Show-FileView -Path $Item.Tag
    }
})

# Theme cycle: Dark -> Light -> System -> Dark
$Script:ThemeOrder = @("Dark", "Light", "System")
$ThemeButton.Add_Click({
    $Idx = [Array]::IndexOf($Script:ThemeOrder, $Script:CurrentTheme)
    $Next = $Script:ThemeOrder[($Idx + 1) % $Script:ThemeOrder.Count]
    Set-Theme -Theme $Next
    Save-Prefs
})
# RenderShot can force a theme regardless of the persisted pref
if ($RenderShot -and $ShotTheme)
{
    $Script:CurrentTheme = $ShotTheme
}

$ThemeButton.Content = $Script:CurrentTheme
Set-Theme -Theme $Script:CurrentTheme

function Build-ModuleList
{
    $ModulePanel.Children.Clear()
    $Script:ModuleRows.Clear()
    $Script:ModuleDisplayNames = @()

    for ($Index = 0; $Index -lt $ModuleNames.Count; $Index++)
    {
        $Name = Get-GUIModuleDisplay -Index $Index
        $Script:ModuleDisplayNames += $Name

        $Row = New-Object System.Windows.Controls.Grid
        $Row.Margin = New-Object System.Windows.Thickness(0, 2, 0, 2)
        $Row.Tag = $Name
        $Row.Cursor = "Hand"

        $ColDot  = New-Object System.Windows.Controls.ColumnDefinition
        $ColDot.Width = New-Object System.Windows.GridLength(18)
        $ColName = New-Object System.Windows.Controls.ColumnDefinition
        $ColName.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $ColStat = New-Object System.Windows.Controls.ColumnDefinition
        $ColStat.Width = New-Object System.Windows.GridLength(70)
        $ColDur  = New-Object System.Windows.Controls.ColumnDefinition
        $ColDur.Width = New-Object System.Windows.GridLength(46)

        $Row.ColumnDefinitions.Add($ColDot)
        $Row.ColumnDefinitions.Add($ColName)
        $Row.ColumnDefinitions.Add($ColStat)
        $Row.ColumnDefinitions.Add($ColDur)

        $Dot = New-Object System.Windows.Shapes.Ellipse
        $Dot.Width = 10
        $Dot.Height = 10
        $Dot.Fill = $Script:BrushPending
        $Dot.VerticalAlignment = "Center"
        $Dot.HorizontalAlignment = "Left"

        $NameText = New-Object System.Windows.Controls.TextBlock
        $NameText.Text = $Name
        $NameText.VerticalAlignment = "Center"
        $NameText.Foreground = $Script:BrushMuted
        $NameText.ToolTip = (Get-GUIModuleDisplay -Index $Index)

        $StatusText = New-Object System.Windows.Controls.TextBlock
        $StatusText.Text = "Pending"
        $StatusText.FontSize = 11
        $StatusText.HorizontalAlignment = "Right"
        $StatusText.VerticalAlignment = "Center"
        $StatusText.Foreground = $Script:BrushMuted

        $DurText = New-Object System.Windows.Controls.TextBlock
        $DurText.Text = ""
        $DurText.FontSize = 11
        $DurText.HorizontalAlignment = "Right"
        $DurText.VerticalAlignment = "Center"
        $DurText.Foreground = $Script:BrushMuted

        $Row.Children.Add($Dot)      | Out-Null
        $Row.Children.Add($NameText) | Out-Null
        $Row.Children.Add($StatusText) | Out-Null
        $Row.Children.Add($DurText)  | Out-Null

        [System.Windows.Controls.Grid]::SetColumn($Dot, 0)
        [System.Windows.Controls.Grid]::SetColumn($NameText, 1)
        [System.Windows.Controls.Grid]::SetColumn($StatusText, 2)
        [System.Windows.Controls.Grid]::SetColumn($DurText, 3)

        $ModulePanel.Children.Add($Row) | Out-Null

        # Premium touch: highlight the row on hover
        $Row.Add_MouseEnter({
            $args[0].Background = $Script:BrushRowHover
        })
        $Row.Add_MouseLeave({
            $args[0].Background = [System.Windows.Media.Brushes]::Transparent
        })

        $Row.Add_MouseLeftButtonDown({
            $Grid = $args[0]
            if ($Grid -and $Grid.Tag)
            {
                Show-ModuleDetail -Name $Grid.Tag
            }
        })

        $Script:ModuleRows[$Name] = @{
            Dot      = $Dot
            Status   = $StatusText
            Duration = $DurText
        }
    }
}

function Set-ModuleStatus
{
    param(
        [string]$Name,
        [string]$Status,
        [string]$Duration
    )

    if (-not $Script:ModuleRows.ContainsKey($Name)) { return }

    $Row = $Script:ModuleRows[$Name]

    switch ($Status.ToUpper())
    {
        "RUNNING" { $Row.Dot.Fill = $Script:BrushRunning }
        "SUCCESS" { $Row.Dot.Fill = $Script:BrushSuccess }
        "FAILED"  { $Row.Dot.Fill = $Script:BrushFailed }
        "WARNING" { $Row.Dot.Fill = $Script:BrushWarn }
        "SKIPPED" { $Row.Dot.Fill = $Script:BrushMuted }
        Default   { $Row.Dot.Fill = $Script:BrushPending }
    }

    $Row.Status.Text = $Status
    $Row.Status.Foreground = $Row.Dot.Fill

    if ($Duration)
    {
        $Row.Duration.Text = $Duration
    }
}

function Reset-ModuleList
{
    $Script:ModuleOutput = @{}
    $Script:CurrentModule = $null

    foreach ($Name in $Script:ModuleDisplayNames)
    {
        Set-ModuleStatus -Name $Name -Status "Pending" -Duration ""
    }
}

function Set-Progress
{
    param(
        [int]$Completed,
        [string]$Message
    )

    $Script:CompletedCount = $Completed
    $ProgressBar.Value = $Completed
    $ProgressBar.Maximum = $TotalModules
    $ProgressText.Text = ("{0} / {1}" -f $Completed, $TotalModules)
    $StatusText.Text = $Message
}

function Add-LogLine
{
    param([string]$Line)

    $Color = $Script:BrushMuted

    if ($Line -match "\[(SUCCESS|WARNING|ERROR|INFO)\]")
    {
        switch ($Matches[1])
        {
            "SUCCESS" { $Color = $Script:BrushSuccess }
            "WARNING" { $Color = $Script:BrushWarn }
            "ERROR"   { $Color = $Script:BrushFailed }
            "INFO"    { $Color = $Script:BrushMuted }
        }
    }

    $Paragraph = New-Object System.Windows.Documents.Paragraph
    $Paragraph.Margin = New-Object System.Windows.Thickness(0)

    $Run = New-Object System.Windows.Documents.Run($Line)
    $Run.Foreground = $Color

    $Paragraph.Inlines.Add($Run) | Out-Null
    $LogBox.Document.Blocks.Add($Paragraph) | Out-Null
    $LogBox.ScrollToEnd()
}

function Parse-LogLine
{
    param([string]$Line)

    if ($Line -match "Running : (.+)$")
    {
        Set-ModuleStatus -Name $Matches[1] -Status "Running" -Duration ""

        $Script:CurrentModule = $Matches[1]

        if (-not $Script:ModuleOutput.ContainsKey($Script:CurrentModule))
        {
            $Script:ModuleOutput[$Script:CurrentModule] = @()
        }
    }
    elseif ($Line -match "Result : (.+?) : (.+?) : (.+)$")
    {
        $Name = $Matches[1]

        Set-ModuleStatus -Name $Name -Status $Matches[2] -Duration $Matches[3]
        Set-Progress -Completed ($Script:CompletedCount + 1) -Message ("Completed: " + $Name)

        if ($Script:ModuleOutput.ContainsKey($Name))
        {
            $Script:ModuleOutput[$Name] += $Line
        }

        $Script:CurrentModule = $null
    }
    else
    {
        if ($Script:CurrentModule -and $Script:ModuleOutput.ContainsKey($Script:CurrentModule))
        {
            $Script:ModuleOutput[$Script:CurrentModule] += $Line
        }
    }
}

function Update-LogTail
{
    $LogDir = Join-Path $AppRoot "Logs"

    if (-not (Test-Path $LogDir)) { return }

    $Newest = Get-ChildItem -Path $LogDir -Filter "Log_*.txt" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $Newest) { return }

    $Path = $Newest.FullName

    if ($Script:LastLogPath -ne $Path)
    {
        $Script:LastLogPath = $Path
        $Script:LastPos = 0
    }

    try
    {
        $FS = [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )

        try
        {
            if ($FS.Length -lt $Script:LastPos)
            {
                $Script:LastPos = 0
            }

            $FS.Position = $Script:LastPos

            $Reader = New-Object System.IO.StreamReader($FS, [System.Text.Encoding]::UTF8)
            $NewText = $Reader.ReadToEnd()
            $Script:LastPos = $FS.Position
            $Reader.Dispose()
        }
        finally
        {
            $FS.Dispose()
        }

        if ($NewText)
        {
            foreach ($Line in ($NewText -split "`r?`n"))
            {
                if ($Line -match "^\s*$") { continue }

                Add-LogLine -Line $Line
                Parse-LogLine -Line $Line
            }
        }
    }
    catch {}
}

# ----------------------------------------------------------
# Module detail window (click a module row)
# ----------------------------------------------------------

function Show-ModuleDetail
{
    param([string]$Name)

    $S = $Global:Strings.$Global:CurrentLang
    if (-not $S) { return }

    $Detail = New-Object System.Windows.Window
    $Detail.Title = ($S.ModuleOutput + " - " + $Name)
    $Detail.Width = 600
    $Detail.Height = 440
    $Detail.WindowStartupLocation = "CenterOwner"
    $Detail.Owner = $Window
    $Detail.Icon = $Window.Icon
    $Detail.Background = $Window.FindResource("Panel")
    $Detail.Foreground = $Window.FindResource("Text")
    $Detail.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe UI")

    $Root = New-Object System.Windows.Controls.DockPanel
    $Root.Margin = New-Object System.Windows.Thickness(14)

    $Title = New-Object System.Windows.Controls.TextBlock
    $Title.Text = $Name
    $Title.FontSize = 15
    $Title.FontWeight = "Bold"
    $Title.Foreground = $Window.FindResource("Accent")
    $Title.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    [System.Windows.Controls.DockPanel]::SetDock($Title, "Top")
    $Root.Children.Add($Title) | Out-Null

    $CloseBtn = New-Object System.Windows.Controls.Button
    $CloseBtn.Content = $S.CloseBtn
    $CloseBtn.Height = 30
    $CloseBtn.MinWidth = 90
    $CloseBtn.HorizontalAlignment = "Right"
    $CloseBtn.Margin = New-Object System.Windows.Thickness(0, 10, 0, 0)
    $CloseBtn.Background = $Window.FindResource("Accent")
    $CloseBtn.Foreground = "White"
    $CloseBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $CloseBtn.Cursor = "Hand"
    $CloseBtn.Add_Click({ $Detail.Close() })
    [System.Windows.Controls.DockPanel]::SetDock($CloseBtn, "Bottom")
    $Root.Children.Add($CloseBtn) | Out-Null

    $Box = New-Object System.Windows.Controls.TextBox
    $Box.IsReadOnly = $true
    $Box.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas")
    $Box.FontSize = 12
    $Box.Background = $Window.FindResource("Panel2")
    $Box.Foreground = $Window.FindResource("Text")
    $Box.BorderThickness = New-Object System.Windows.Thickness(0)
    $Box.Padding = New-Object System.Windows.Thickness(10, 8, 10, 8)
    $Box.VerticalScrollBarVisibility = "Auto"
    $Box.HorizontalScrollBarVisibility = "Auto"
    $Box.TextWrapping = "NoWrap"

    if ($Script:ModuleOutput.ContainsKey($Name) -and $Script:ModuleOutput[$Name].Count -gt 0)
    {
        $Box.Text = ($Script:ModuleOutput[$Name] -join "`r`n")
    }
    else
    {
        $Box.Text = $S.NoOutput
    }

    $Root.Children.Add($Box) | Out-Null

    $Detail.Content = $Root
    $Detail.Show()
}

# ----------------------------------------------------------
# Run summary screen (shown after each run finishes)
# ----------------------------------------------------------

function Show-RunSummary
{
    $S = $Global:Strings.$Global:CurrentLang
    if (-not $S) { return }

    # Overall verdict from the live module statuses
    $Statuses = foreach ($Name in $ModuleNames)
    {
        $Script:ModuleRows[$Name].Status.Text
    }

    $VerdictText  = $S.Healthy
    $VerdictBrush = $Script:BrushSuccess

    if ($Statuses -contains "FAILED")
    {
        $VerdictText  = $S.AttentionRequired
        $VerdictBrush = $Script:BrushFailed
    }
    elseif ($Statuses -contains "WARNING" -or $Statuses -contains "SKIPPED")
    {
        $VerdictText  = $S.AttentionRequired
        $VerdictBrush = $Script:BrushWarn
    }

    if (-not $Script:Running -and $Script:Proc -and $Script:Proc.ExitCode -ne 0)
    {
        $VerdictText  = $S.Aborted
        $VerdictBrush = $Script:BrushFailed
    }

    $Summary = New-Object System.Windows.Window
    $Summary.Title = $S.RunSummary
    $Summary.Width = 470
    $Summary.Height = 520
    $Summary.WindowStartupLocation = "CenterOwner"
    $Summary.Owner = $Window
    $Summary.Icon = $Window.Icon
    $Summary.Background = $Window.FindResource("Panel")
    $Summary.Foreground = $Window.FindResource("Text")
    $Summary.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe UI")
    $Summary.ResizeMode = "NoResize"

    $Root = New-Object System.Windows.Controls.StackPanel
    $Root.Margin = New-Object System.Windows.Thickness(18)

    $Title = New-Object System.Windows.Controls.TextBlock
    $Title.Text = $S.RunSummary
    $Title.FontSize = 18
    $Title.FontWeight = "Bold"
    $Title.Foreground = $Window.FindResource("Accent")
    $Root.Children.Add($Title) | Out-Null

    $VerdictRow = New-Object System.Windows.Controls.StackPanel
    $VerdictRow.Orientation = "Horizontal"
    $VerdictRow.Margin = New-Object System.Windows.Thickness(0, 14, 0, 10)

    $VerdictLabel = New-Object System.Windows.Controls.TextBlock
    $VerdictLabel.Text = ($S.OverallStatus + " : ")
    $VerdictLabel.Foreground = $Window.FindResource("Muted")
    $VerdictLabel.VerticalAlignment = "Center"

    $VerdictValue = New-Object System.Windows.Controls.TextBlock
    $VerdictValue.Text = $VerdictText
    $VerdictValue.FontWeight = "Bold"
    $VerdictValue.Foreground = $VerdictBrush
    $VerdictValue.Margin = New-Object System.Windows.Thickness(6, 0, 0, 0)
    $VerdictValue.VerticalAlignment = "Center"

    $VerdictRow.Children.Add($VerdictLabel) | Out-Null
    $VerdictRow.Children.Add($VerdictValue) | Out-Null
    $Root.Children.Add($VerdictRow) | Out-Null

    $RowsHost = New-Object System.Windows.Controls.StackPanel

    foreach ($Name in $Script:ModuleDisplayNames)
    {
        $Row = $Script:ModuleRows[$Name]

        $Grid = New-Object System.Windows.Controls.Grid
        $Grid.Margin = New-Object System.Windows.Thickness(0, 3, 0, 3)

        $Col1 = New-Object System.Windows.Controls.ColumnDefinition
        $Col1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $Col2 = New-Object System.Windows.Controls.ColumnDefinition
        $Col2.Width = New-Object System.Windows.GridLength(80)
        $Col3 = New-Object System.Windows.Controls.ColumnDefinition
        $Col3.Width = New-Object System.Windows.GridLength(50)

        $Grid.ColumnDefinitions.Add($Col1)
        $Grid.ColumnDefinitions.Add($Col2)
        $Grid.ColumnDefinitions.Add($Col3)

        $NameTB = New-Object System.Windows.Controls.TextBlock
        $NameTB.Text = $Name
        $NameTB.Foreground = $Window.FindResource("Text")
        $NameTB.VerticalAlignment = "Center"

        $StatTB = New-Object System.Windows.Controls.TextBlock
        $StatTB.Text = $Row.Status.Text
        $StatTB.Foreground = $Row.Status.Foreground
        $StatTB.HorizontalAlignment = "Right"
        $StatTB.VerticalAlignment = "Center"

        $DurTB = New-Object System.Windows.Controls.TextBlock
        $DurTB.Text = $Row.Duration.Text
        $DurTB.Foreground = $Window.FindResource("Muted")
        $DurTB.HorizontalAlignment = "Right"
        $DurTB.VerticalAlignment = "Center"

        $Grid.Children.Add($NameTB)  | Out-Null
        $Grid.Children.Add($StatTB)  | Out-Null
        $Grid.Children.Add($DurTB)   | Out-Null

        [System.Windows.Controls.Grid]::SetColumn($NameTB, 0)
        [System.Windows.Controls.Grid]::SetColumn($StatTB, 1)
        [System.Windows.Controls.Grid]::SetColumn($DurTB, 2)

        $RowsHost.Children.Add($Grid) | Out-Null
    }

    $Scroll = New-Object System.Windows.Controls.ScrollViewer
    $Scroll.VerticalScrollBarVisibility = "Auto"
    $Scroll.Content = $RowsHost
    $Root.Children.Add($Scroll) | Out-Null

    $CloseBtn = New-Object System.Windows.Controls.Button
    $CloseBtn.Content = $S.CloseBtn
    $CloseBtn.Height = 32
    $CloseBtn.Margin = New-Object System.Windows.Thickness(0, 14, 0, 0)
    $CloseBtn.HorizontalAlignment = "Right"
    $CloseBtn.MinWidth = 90
    $CloseBtn.Background = $Window.FindResource("Accent")
    $CloseBtn.Foreground = "White"
    $CloseBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $CloseBtn.Cursor = "Hand"
    $CloseBtn.Add_Click({ $Summary.Close() })
    $Root.Children.Add($CloseBtn) | Out-Null

    $Summary.Content = $Root
    $Summary.Show()
}

# ----------------------------------------------------------
# System tray (minimize to tray, background running)
# ----------------------------------------------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Script:Tray = New-Object System.Windows.Forms.NotifyIcon
$Script:Tray.Icon = New-Object System.Drawing.Icon($IconPath)
$Script:Tray.Text = "PC Doctor Portable"
$Script:Tray.Visible = $false
$Script:Quitting = $false

$Script:TrayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$Script:TrayOpen = New-Object System.Windows.Forms.ToolStripMenuItem("Open")
$Script:TrayExit = New-Object System.Windows.Forms.ToolStripMenuItem("Exit")

function Show-MainWindow
{
    $Window.Show()
    $Window.Activate()
    $Script:Tray.Visible = $false
}

$Script:TrayOpen.Add_Click({ Show-MainWindow })
$Script:TrayExit.Add_Click({
    $Script:Quitting = $true
    Save-Config
    if ($Script:Running) { Stop-Run }
    $Script:Tray.Dispose()
    $Window.Close()
})

$Script:TrayMenu.Items.Add($Script:TrayOpen) | Out-Null
$Script:TrayMenu.Items.Add($Script:TrayExit) | Out-Null
$Script:Tray.ContextMenuStrip = $Script:TrayMenu
$Script:Tray.add_DoubleClick({ Show-MainWindow })

# ----------------------------------------------------------
# Run control
# ----------------------------------------------------------

$Timer = New-Object System.Windows.Threading.DispatcherTimer
$Timer.Interval = [TimeSpan]::FromMilliseconds(400)

function Start-Run
{
    if ($Script:Running) { return }

    $Script:Running = $true
    $StartButton.IsEnabled = $false
    $AbortButton.IsEnabled = $true

    $LogBox.Document.Blocks.Clear()
    Reset-ModuleList
    Set-Progress -Completed 0 -Message $Global:Strings.$Global:CurrentLang.Starting

    Add-LogLine -Line "-----------------------------------------------"
    Add-LogLine -Line "PC Doctor Portable started (Auto Mode)"
    Add-LogLine -Line "-----------------------------------------------"

    # Save settings to the user-writable config copy, then run
    # the engine against it (works even when installed to
    # Program Files where the app-dir Config.json is read-only).
    # Sync the GUI language into the config so the child logs
    # module names in the same language the GUI displays.
    $Global:Config.General.Language = $Global:CurrentLang
    Save-Config

    $MainPath = Join-Path $AppRoot "Main.ps1"
    $Args = "-NoProfile -ExecutionPolicy Bypass -File `"$MainPath`" -Mode AUTO -ConfigPath `"$Script:RunConfigPath`""

    try
    {
        $Script:Proc = Start-Process `
            -FilePath "powershell.exe" `
            -ArgumentList $Args `
            -WorkingDirectory $AppRoot `
            -WindowStyle Hidden `
            -PassThru

        $Script:LastLogPath = $null
        $Script:LastPos = 0

        $Timer.Start()
    }
    catch
    {
        Add-LogLine -Line ("Could not start engine: " + $_.Exception.Message)
        $Script:Running = $false
        $StartButton.IsEnabled = $true
        $AbortButton.IsEnabled = $false
        Set-Progress -Completed 0 -Message "Start failed"
    }
}

function Stop-Run
{
    if ($Script:Proc -and -not $Script:Proc.HasExited)
    {
        try { Stop-Process -Id $Script:Proc.Id -Force } catch {}
    }

    $Timer.Stop()
    $Script:Running = $false
    $StartButton.IsEnabled = $true
    $AbortButton.IsEnabled = $false

    if ($Global:Strings -and $Global:Strings.$Global:CurrentLang)
    {
        Set-Progress -Completed $Script:CompletedCount -Message $Global:Strings.$Global:CurrentLang.RunAborted
    }
}

$Timer.Add_Tick({
    Complete-UpdateCheck
    Update-LogTail

    if ($Script:Proc -and $Script:Proc.HasExited)
    {
        $Timer.Stop()
        $Script:Running = $false
        $StartButton.IsEnabled = $true
        $AbortButton.IsEnabled = $false

        $S = $Global:Strings.$Global:CurrentLang

        if ($Script:Proc.ExitCode -eq 0)
        {
            Set-Progress -Completed $Script:CompletedCount -Message $S.RunFinished
        }
        else
        {
            Set-Progress -Completed $Script:CompletedCount -Message ($S.RunFinishedCode -f $Script:Proc.ExitCode)
        }

        Show-RunSummary

        # Dashboard health card reflects the latest run state
        Refresh-Dashboard
    }
})

$StartButton.Add_Click({ Start-Run })
$AbortButton.Add_Click({ Stop-Run })

$Window.Add_Closing({
    if (-not $Script:Quitting)
    {
        # Minimize to the system tray instead of quitting
        $_.Cancel = $true
        $Window.Hide()
        $Script:Tray.Visible = $true

        try
        {
            $S = $Global:Strings.$Global:CurrentLang
            if ($S)
            {
                $Script:Tray.ShowBalloonTip(2500, "PC Doctor Portable", $S.TrayStillRunning, [System.Windows.Forms.ToolTipIcon]::Info)
            }
        }
        catch {}

        return
    }

    Save-Config
    if ($Script:Running) { Stop-Run }
    $Script:Tray.Dispose()
})

# ----------------------------------------------------------
# Launch
# ----------------------------------------------------------

if ($SelfTest)
{
    # Validate the UI without pumping the WPF dispatcher (safe in
    # non-interactive sessions): XAML must parse, every named
    # control must exist, and the module list must build.
    $RequiredControls = @(
        "StartButton", "AbortButton", "ModulePanel", "LogBox", "HeaderLogo",
        "ProgressBar", "StatusText", "ProgressText",
        "SubtitleText", "ModeLabel", "ModeTitleText", "ModeNoteText",
        "ModulesLabel", "OutputLabel", "FooterText", "LangBox", "UpdateText",
        "ThemeButton", "DownloadButton", "BackButton",
        "NavDashboard", "NavModules", "NavSettings", "NavHistory",
        "NavDashboardText", "NavModulesText", "NavSettingsText", "NavHistoryText",
        "DashboardView", "ModulesView", "DashDot", "DashHealthText", "DashHealthNote",
        "DashOs", "DashCpu", "DashRam", "DashUptime", "DashLastRun", "DashNextRun", "DashVersion",
        "DashRamBar", "DashRamText", "DashDiskBar", "DashDiskText", "DashUpdates",
        "SettingsView", "SettingsList", "SettingsTitle", "SettingsHint",
        "ScheduleCheck", "ScheduleDayBox", "ScheduleHourBox", "ScheduleMinuteBox", "ScheduleNextText",
        "ScheduleDayLabel", "ScheduleTimeLabel", "ScheduleTaskButton", "ScheduleTaskStatus",
        "HistoryView", "HistoryList", "HistoryTitle", "HistoryHint",
        "HistoryRefreshButton", "HistoryBackButton", "FeedbackButton"
    )

    foreach ($ControlName in $RequiredControls)
    {
        if (-not $Window.FindName($ControlName))
        {
            Write-Host ("GUI self-test FAILED : missing control " + $ControlName)
            exit 1
        }
    }

    # Exercise Apply-Language so missing FindName lookups or
    # broken translation wiring fail the self-test too
    Apply-Language

    Build-ModuleList
    Reset-ModuleList

    if ($ModulePanel.Children.Count -ne $TotalModules)
    {
        Write-Host "GUI self-test FAILED : module list not built"
        exit 1
    }

    # Simulate the log-line parsing path
    Add-LogLine -Line "[12:00:00] [SUCCESS] Test line"
    Parse-LogLine -Line "Running : Windows Update"
    Parse-LogLine -Line "Result : Windows Update : SUCCESS : 00:45"

    # Settings panel: build it and verify a config round-trip
    Build-SettingsList

    if ($SettingsList.Children.Count -ne $Script:SettingDefs.Count)
    {
        Write-Host "GUI self-test FAILED : settings list not built"
        exit 1
    }

    # Run history list must build without throwing
    Build-HistoryList

    # Dashboard + navigation rail
    Set-ActiveView -Index 0

    if ($DashboardView.Visibility -ne "Visible")
    {
        Write-Host "GUI self-test FAILED : dashboard view not active"
        exit 1
    }

    if ($NavDashboard.Foreground -eq [System.Windows.Media.Brushes]::Transparent)
    {
        Write-Host "GUI self-test FAILED : nav state not applied"
        exit 1
    }

    # Scheduler: initialize and verify 8 day options
    Init-Scheduler
    Update-NextRunText

    if ($ScheduleDayBox.Items.Count -ne 8)
    {
        Write-Host ("GUI self-test FAILED : scheduler day options (count=" + $ScheduleDayBox.Items.Count + " strings=" + [bool]$Global:Strings + " lang=" + $Global:CurrentLang + ")")
        exit 1
    }

    $OldValue = Get-ConfigValue -Path "Restart.AutoRestart"
    Set-ConfigValue -Path "Restart.AutoRestart" -Value (-not $OldValue)
    $NewValue = Get-ConfigValue -Path "Restart.AutoRestart"
    Set-ConfigValue -Path "Restart.AutoRestart" -Value $OldValue

    if ($NewValue -eq $OldValue)
    {
        Write-Host "GUI self-test FAILED : config value round-trip"
        exit 1
    }

    Write-Host "GUI self-test OK (XAML, controls, module list, settings, parsing all work)"
    exit 0
}

Build-ModuleList
Reset-ModuleList

Apply-Language
Init-Scheduler
Update-NextRunText

# ----------------------------------------------------------
# Onboarding Wizard (first run only)
# ----------------------------------------------------------
$WizardDoneFile = Join-Path $Script:PrefsDir "wizard-done"
$ShowWizard = (-not (Test-Path $WizardDoneFile)) -and (-not $SelfTest) -and (-not $RenderShot)

if ($ShowWizard)
{
    New-Item -ItemType Directory -Path $Script:PrefsDir -Force | Out-Null

    $WizOverlay = New-Object System.Windows.Controls.Canvas
    $WizOverlay.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.Color]::FromArgb(0xCC, 0x0D, 0x11, 0x17))
    $WizOverlay.IsHitTestVisible = $true
    $WizOverlay.Visibility = "Visible"

    # Wizard card
    $WizCard = New-Object System.Windows.Controls.Border
    $WizCard.Width = 480
    $WizCard.MinHeight = 360
    $WizCard.CornerRadius = 14
    $WizCard.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.Color]::FromRgb(0x16, 0x1B, 0x22))
    $WizCard.BorderBrush = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.Color]::FromRgb(0x2D, 0x36, 0x44))
    $WizCard.BorderThickness = 1
    $WizCard.Padding = 30
    $WizCard.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
    $WizCard.Effect.BlurRadius = 30
    $WizCard.Effect.ShadowDepth = 0
    $WizCard.Effect.Opacity = 0.5
    $WizCard.Effect.Color = [System.Windows.Media.Color]::FromRgb(0x00, 0x00, 0x00)
    [System.Windows.Controls.Canvas]::SetLeft($WizCard, 260)
    [System.Windows.Controls.Canvas]::SetTop($WizCard, 80)
    $WizOverlay.Children.Add($WizCard) | Out-Null

    $WizStack = New-Object System.Windows.Controls.StackPanel
    $WizCard.Child = $WizStack

    # Title
    $WizTitle = New-Object System.Windows.Controls.TextBlock
    $WizTitle.Text = "Welcome to PC Doctor Portable"
    $WizTitle.FontSize = 20
    $WizTitle.FontWeight = "Bold"
    $WizTitle.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.Color]::FromRgb(0x4F, 0xC1, 0xFF))
    $WizTitle.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)
    $WizStack.Children.Add($WizTitle) | Out-Null

    # Subtitle
    $WizSub = New-Object System.Windows.Controls.TextBlock
    $WizSub.Text = "Windows Maintenance & Repair Tool - v1.2`
`nThis tool keeps your PC healthy by cleaning temp files, checking for updates, repairing Windows, and optimizing your system.`n`nClick Start below to run all maintenance modules automatically.`n`nYou can change settings, switch themes, and switch languages from the Settings panel."
    $WizSub.FontSize = 13
    $WizSub.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.Color]::FromRgb(0x8B, 0x98, 0xA9))
    $WizSub.TextWrapping = "Wrap"
    $WizSub.Margin = New-Object System.Windows.Thickness(0, 0, 0, 20)
    $WizStack.Children.Add($WizSub) | Out-Null

    # Feature bullets
    $WizFeatures = @(
        "Dashboard - Live system health, RAM/Disk usage, pending updates",
        "Modules - 19 maintenance modules (Cleanup, Repair, Update, etc.)",
        "Settings - Toggle modules on/off, theme, language, toast",
        "History - Browse past runs, logs, and reports",
        "Feedback - Report bugs or send diagnostics"
    )
    foreach ($F in $WizFeatures) {
        $Bullet = New-Object System.Windows.Controls.TextBlock
        $Bullet.Text = "  >  $F"
        $Bullet.FontSize = 12
        $Bullet.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.Color]::FromRgb(0x3D, 0xDC, 0x84))
        $Bullet.Margin = New-Object System.Windows.Thickness(0, 2, 0, 2)
        $WizStack.Children.Add($Bullet) | Out-Null
    }

    $WizSep = New-Object System.Windows.Controls.Separator
    $WizSep.Margin = New-Object System.Windows.Thickness(0, 12, 0, 12)
    $WizStack.Children.Add($WizSep) | Out-Null

    # Got It button
    $WizBtn = New-Object System.Windows.Controls.Button
    $WizBtn.Content = "Got it - let's go!"
    $WizBtn.Height = 36
    $WizBtn.FontSize = 13
    $WizBtn.FontWeight = "SemiBold"
    $WizBtn.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.Color]::FromRgb(0x4B, 0xE8, 0x9A))
    $WizBtn.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.Color]::FromRgb(0x0D, 0x11, 0x17))
    $WizBtn.BorderThickness = 0
    $WizBtn.Cursor = "Hand"
    $WizBtn.HorizontalAlignment = "Right"
    $WizBtn.Padding = New-Object System.Windows.Thickness(24, 0, 24, 0)
    $WizStack.Children.Add($WizBtn) | Out-Null

    $WizBtn.Add_Click({
        $WizOverlay.Visibility = "Collapsed"
        $Window.Content.Children.Remove($WizOverlay)
        # Mark wizard as done
        try { Set-Content -Path $WizardDoneFile -Value (Get-Date -Format 'o') -Force } catch {}
    })

    # Add overlay on top of everything
    $Window.Content.Children.Add($WizOverlay) | Out-Null
}

# Land on the Dashboard with the navigation rail highlighted
Set-ActiveView -Index 0

if ($RenderShot)
{
    if (-not $ShotPath) { $ShotPath = Join-Path $env:TEMP "pc-doctor-shot.png" }

    Set-ActiveView -Index $ShotView
    $Window.WindowState = "Normal"

    if ($ShotHeight -gt 0) { $Window.Height = $ShotHeight }

    $Window.Show()
    $Window.UpdateLayout()

    # Use actual DPI for sharp rendering (no blur)
    $Dpi = 96 * $Script:DpiScale
    $W = [int]($Window.ActualWidth * $Script:DpiScale)
    $H = [int]($Window.ActualHeight * $Script:DpiScale)

    $Bitmap = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(
        $W, $H, $Dpi, $Dpi,
        [System.Windows.Media.PixelFormats]::Pbgra32)
    $Bitmap.Render($Window)

    $Encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $Encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($Bitmap))

    $Stream = [System.IO.File]::Open($ShotPath, "Create")
    $Encoder.Save($Stream)
    $Stream.Close()

    Write-Host ("GUI render saved : " + $ShotPath + " (DPI=$([int]$Dpi))")
    exit 0
}

Start-UpdateCheck
$ScheduleTimer.Start()
$LiveTimer.Start()

$Window.ShowDialog() | Out-Null
