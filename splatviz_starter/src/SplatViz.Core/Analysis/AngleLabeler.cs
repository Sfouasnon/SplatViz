namespace SplatViz.Core.Analysis;

public static class AngleLabeler
{
    public static string BinLabel(int bin, int totalBins)
    {
        var center = (bin + 0.5) * 360.0 / totalBins;
        string horiz = center switch
        {
            >= 337.5 or < 22.5 => "front",
            >= 22.5 and < 67.5 => "front-right",
            >= 67.5 and < 112.5 => "right",
            >= 112.5 and < 157.5 => "rear-right",
            >= 157.5 and < 202.5 => "rear",
            >= 202.5 and < 247.5 => "rear-left",
            >= 247.5 and < 292.5 => "left",
            _ => "front-left"
        };

        return $"{horiz} sector {bin}";
    }
}
