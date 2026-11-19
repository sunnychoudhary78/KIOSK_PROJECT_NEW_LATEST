
using System;
using System.Windows;

namespace AthenaOtaUpdater;

public partial class App : Application
{
    private void Application_Startup(object sender, StartupEventArgs e)
    {
        var window = new MainWindow();
        MainWindow = window;
        window.Show();
    }
}
