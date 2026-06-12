namespace SplatViz.Core.Cameras;

public sealed record RecordingMode(
    string Name,
    int WidthPx,
    int HeightPx,
    double FramesPerSecond,
    string Compression,
    double EstimatedDataRateMBps,
    string DataRateBasis)
{
    public static RecordingMode KomodoX6K60Hq() => new("6K 17:9 60fps HQ", 6144, 3240, 60, "HQ", 560, "planning_estimate_m05");
    public static RecordingMode KomodoX6K16x9_60Hq() => new("6K 16:9 60fps HQ", 6144, 3456, 60, "HQ", 560, "fdvc_red_rate_table");
    public static RecordingMode KomodoX6K48Mq() => new("6K 17:9 48fps MQ", 6144, 3240, 48, "MQ", 310, "planning_estimate_m05");
    public static RecordingMode KomodoX6K24Mq() => new("6K 17:9 24fps MQ", 6144, 3240, 24, "MQ", 155, "planning_estimate_m05");
    public static RecordingMode KomodoX6K24Lq() => new("6K 17:9 24fps LQ", 6144, 3240, 24, "LQ", 110, "planning_estimate_m05");
    public static RecordingMode KomodoX5K24Mq() => new("5K 17:9 24fps MQ", 5120, 2700, 24, "MQ", 108, "planning_estimate_m05");
    public static RecordingMode KomodoX4K24Lq() => new("4K 17:9 24fps LQ", 4096, 2160, 24, "LQ", 62, "planning_estimate_m05");

    public static IReadOnlyList<RecordingMode> PlanningProfiles() => new[]
    {
        KomodoX4K24Lq(),
        KomodoX5K24Mq(),
        KomodoX6K24Lq(),
        KomodoX6K24Mq(),
        KomodoX6K48Mq(),
        KomodoX6K60Hq(),
        KomodoX6K16x9_60Hq()
    };
}
