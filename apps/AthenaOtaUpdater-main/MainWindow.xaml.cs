
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using AthenaOtaUpdater.Services;

namespace AthenaOtaUpdater;

public partial class MainWindow : Window
{

private readonly UpdateCoordinator _coordinator;

public MainWindow()
{
    InitializeComponent();

    _coordinator = new UpdateCoordinator(
        Path.Combine(AppContext.BaseDirectory, "appsettings.json"),
        message => Dispatcher.Invoke(() => StatusText.Text = message),
        percent => Dispatcher.Invoke(() => Progress.Value = percent));

    Loaded += MainWindow_Loaded;
    Closed += (_, _) => _coordinator.Dispose();

    // Hide the updater window when it starts.
    ShowInTaskbar = true;
    WindowState = WindowState.Minimized;
}


    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        StatusText.Text = "Athena OTA Updater started. Initializing...";

        // Allow WPF to render the window before starting network operations.
        await Task.Yield();
        //Hide();

        await Task.Run(async () =>
        {
            await _coordinator.StartAsync();
        });
    }

    private async void CheckNow_Click(object sender, RoutedEventArgs e)
    {
        await _coordinator.CheckOnceAsync(forceIdle: false);
    }

    private void Minimize_Click(object sender, RoutedEventArgs e)
    {
        WindowState = WindowState.Minimized;
    }
}
