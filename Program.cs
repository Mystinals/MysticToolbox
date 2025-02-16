using Terminal.Gui;
using System.Text.Json;
using System.Management.Automation;

namespace MTB;

class SoftwareItem
{
    public string Name { get; set; } = string.Empty;
    public string ID { get; set; } = string.Empty;
    public string Section { get; set; } = string.Empty;
    public string Status { get; set; } = "Unknown";
    public string? Action { get; set; }
    public string? ErrorMessage { get; set; }
}

class Program
{
    private static List<SoftwareItem> software = new();
    private static ListView listView = null!;
    private static StatusBar statusBar = null!;
    private static Label statusLabel = null!;

    static async Task Main(string[] args)
    {
        Application.Init();
        Colors.Base.Normal = Application.Driver.MakeAttribute(Color.White, Color.Black);

        // Create main window
        var top = Application.Top;
        var win = new Window("MysticToolbox - Software Installation Menu")
        {
            X = 0,
            Y = 1,
            Width = Dim.Fill(),
            Height = Dim.Fill() - 1
        };

        // Create list view
        listView = new ListView()
        {
            X = 0,
            Y = 0,
            Width = Dim.Fill(),
            Height = Dim.Fill() - 2,
            ColorScheme = Colors.TopLevel
        };

        // Status label
        statusLabel = new Label("Loading software list...")
        {
            X = 0,
            Y = Pos.Bottom(win) - 2,  // Fixed: Changed Dim to Pos
            Width = Dim.Fill(),
            Height = 1
        };

        // Status bar
        statusBar = new StatusBar(new StatusItem[] {
            new StatusItem(Key.F1, "~F1~ Help", ShowHelp),
            new StatusItem(Key.I, "~I~ Install", ToggleInstall),
            new StatusItem(Key.U, "~U~ Uninstall", ToggleUninstall),
            new StatusItem(Key.R, "~R~ Refresh", async () => await RefreshStatus()),
            new StatusItem(Key.Enter, "~Enter~ Process", ProcessSelected),
            new StatusItem(Key.Q, "~Q~ Quit", () => Application.RequestStop())
        });

        win.Add(listView, statusLabel);
        top.Add(win, statusBar);

        // Load software list
        await LoadSoftwareList();
        await RefreshStatus();

        Application.Run();
    }

    private static async Task LoadSoftwareList()
    {
        try
        {
            var jsonPath = Path.Combine(Path.GetTempPath(), "software-list.json");
            var jsonContent = await File.ReadAllTextAsync(jsonPath);
            var data = JsonSerializer.Deserialize<JsonElement>(jsonContent);
            
            foreach (var section in data.GetProperty("sections").EnumerateArray())
            {
                var sectionName = section.GetProperty("name").GetString();
                foreach (var app in section.GetProperty("software").EnumerateArray())
                {
                    software.Add(new SoftwareItem
                    {
                        Name = app.GetProperty("name").GetString()!,
                        ID = app.GetProperty("id").GetString()!,
                        Section = sectionName!
                    });
                }
            }

            UpdateListView();
        }
        catch (Exception ex)
        {
            MessageBox.ErrorQuery("Error", $"Failed to load software list: {ex.Message}", "OK");
            Application.RequestStop();
        }
    }

    private static void UpdateListView()
    {
        var items = new List<string>();
        string? currentSection = null;

        foreach (var item in software)
        {
            if (currentSection != item.Section)
            {
                items.Add($"--- {item.Section} ---");
                currentSection = item.Section;
            }

            var prefix = item.Action == "install" ? "[√]" :
                        item.Action == "uninstall" ? "[X]" : "[ ]";
            var status = string.IsNullOrEmpty(item.Status) ? "" : $"[{item.Status}]";
            items.Add($"{prefix} {item.Name.PadRight(40)} {status}");

            if (!string.IsNullOrEmpty(item.ErrorMessage))
            {
                items.Add($"    {item.ErrorMessage}");
            }
        }

        listView.SetSource(items);
    }

    private static async Task RefreshStatus()
    {
        statusLabel.Text = "Checking installed software...";
        foreach (var item in software)
        {
            item.Status = "Checking...";
            item.ErrorMessage = null;
        }
        UpdateListView();

        try
        {
            using var ps = PowerShell.Create();
            ps.AddCommand("winget")
              .AddArgument("list")
              .AddArgument("--accept-source-agreements");

            var result = await Task.Run(() => ps.Invoke());
            var installedIds = new HashSet<string>();

            foreach (var line in result)
            {
                var text = line.ToString();
                if (text.Contains('.'))
                {
                    var parts = text.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                    if (parts.Length >= 2)
                    {
                        installedIds.Add(parts[1]);
                    }
                }
            }

            foreach (var item in software)
            {
                item.Status = installedIds.Contains(item.ID) ? "Installed" : "Not Installed";
            }
        }
        catch (Exception ex)
        {
            foreach (var item in software)
            {
                item.Status = "Check Failed";
                item.ErrorMessage = "Error checking installation status";
            }
            MessageBox.ErrorQuery("Error", $"Failed to check software status: {ex.Message}", "OK");
        }

        statusLabel.Text = "Ready";
        UpdateListView();
    }

    private static void ToggleInstall()
    {
        var selected = listView.SelectedItem;
        if (selected >= 0 && selected < software.Count)
        {
            var item = software[selected];
            item.Action = item.Action == "install" ? null : "install";
            UpdateListView();
        }
    }

    private static void ToggleUninstall()
    {
        var selected = listView.SelectedItem;
        if (selected >= 0 && selected < software.Count)
        {
            var item = software[selected];
            item.Action = item.Action == "uninstall" ? null : "uninstall";
            UpdateListView();
        }
    }

    private static async void ProcessSelected()
    {
        var itemsToProcess = software.Where(s => !string.IsNullOrEmpty(s.Action)).ToList();
        if (!itemsToProcess.Any())
        {
            MessageBox.Query("Info", "No software selected for processing.", "OK");
            return;
        }

        foreach (var item in itemsToProcess)
        {
            item.Status = item.Action == "install" ? "Installing..." : "Uninstalling...";
            item.ErrorMessage = null;
            UpdateListView();

            try
            {
                using var ps = PowerShell.Create();
                ps.AddCommand("winget")
                  .AddArgument(item.Action)
                  .AddArgument("--id")
                  .AddArgument(item.ID)
                  .AddArgument("--accept-source-agreements")
                  .AddArgument("--accept-package-agreements")
                  .AddArgument("--silent");

                var result = await Task.Run(() => ps.Invoke());
                var output = string.Join("\n", result.Select(r => r.ToString()));

                if (output.Contains("Successfully"))
                {
                    item.Status = item.Action == "install" ? "Installed" : "Not Installed";
                    item.Action = null;
                    item.ErrorMessage = null;
                }
                else
                {
                    item.Status = $"{item.Action} Error";
                    item.ErrorMessage = $"Error: {output}";
                }
            }
            catch (Exception ex)
            {
                item.Status = $"{item.Action} Error";
                item.ErrorMessage = $"Error: {ex.Message}";
            }

            UpdateListView();
        }

        await RefreshStatus();
    }

    private static void ShowHelp()
    {
        MessageBox.Query("Help", 
            "F1: Show this help\n" +
            "I: Mark/unmark for installation\n" +
            "U: Mark/unmark for uninstallation\n" +
            "R: Refresh software status\n" +
            "Enter: Process marked items\n" +
            "Q: Quit application", 
            "OK");
    }
}