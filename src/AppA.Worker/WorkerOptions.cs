namespace AppA.Worker;

public sealed class WorkerOptions
{
    public const string SectionName = "Worker";

    public string TesterName { get; set; } = "unknown";

    public string Version { get; set; } = "0.0.0";

    public int IntervalSeconds { get; set; } = 5;
}
