using System.Globalization;
using System.Text;
using SplatViz.Core.Analysis;
using SplatViz.Core.Cameras;
using SplatViz.Core.Scene;

namespace SplatViz.Core.Reporting;

public static class SvgReportFigureGenerator
{
    public static string Overview(string title, IEnumerable<CameraInstance> cameras, CaptureVolume volume, CoverageReport report)
    {
        return RadialFigure(title, cameras, volume, report, FigureMode.Overview);
    }

    public static string WeakZones(string title, IEnumerable<CameraInstance> cameras, CaptureVolume volume, CoverageReport report)
    {
        return RadialFigure(title, cameras, volume, report, FigureMode.WeakZones);
    }

    public static string RedundantAngles(string title, IEnumerable<CameraInstance> cameras, CaptureVolume volume, CoverageReport report)
    {
        return RadialFigure(title, cameras, volume, report, FigureMode.RedundantAngles);
    }

    public static string FrustumProjection(string title, IEnumerable<CameraInstance> cameras, CoverageReport report)
    {
        var sb = new StringBuilder();
        sb.AppendLine("<svg xmlns='http://www.w3.org/2000/svg' width='1600' height='900' viewBox='0 0 1600 900'>");
        sb.AppendLine(DefsAndBackground());
        AddTitle(sb, "Frustum Projection", title, 70, 94);
        sb.AppendLine("<rect x='70' y='175' width='1010' height='650' rx='26' fill='#10171A' stroke='#24343B'/> ");
        sb.AppendLine("<rect x='1110' y='175' width='420' height='650' rx='26' fill='#0D1417' stroke='#24343B'/> ");

        var list = cameras.ToList();
        for (var i = 0; i < list.Count; i++)
        {
            var c = list[i];
            var x = 110 + (i % 6) * 160;
            var y = 245 + (i / 6) * 140;
            var width = 48 + c.HorizontalFovDegrees * 0.65;
            var color = ContributionColor(report, c.Id);
            sb.AppendLine($"<rect x='{F(x)}' y='{F(y)}' width='{F(width)}' height='10' fill='{color}' opacity='0.85' />");
            sb.AppendLine($"<polygon points='{F(x)},{F(y + 5)} {F(x + width)},{F(y - 34)} {F(x + width)},{F(y + 44)}' fill='{color}' opacity='0.22' stroke='{color}' />");
            sb.AppendLine($"<text x='{F(x)}' y='{F(y - 14)}' fill='#E8ECEA' font-size='16' font-family='Arial'>{c.Id}</text>");
        }

        AddPanel(sb, 1135, 220, "Frustum notes", new[]
        {
            "Green cameras are primary contributors.",
            "Amber cameras are still useful overlap.",
            "Red cameras are only removal targets when the schedule says so.",
            "Overlap is required for 4DGS; do not remove cameras just because frustums intersect."
        });
        sb.AppendLine("</svg>");
        return sb.ToString();
    }

    private static string RadialFigure(string title, IEnumerable<CameraInstance> cameras, CaptureVolume volume, CoverageReport report, FigureMode mode)
    {
        var sb = new StringBuilder();
        var centerX = 755.0;
        var centerY = 475.0;
        var camRadius = 285.0;
        var volRadius = 150.0;
        var list = cameras.ToList();

        sb.AppendLine("<svg xmlns='http://www.w3.org/2000/svg' width='1600' height='900' viewBox='0 0 1600 900'>");
        sb.AppendLine(DefsAndBackground());
        AddTitle(sb, title, $"Score {report.Score:0.0} • Covered {report.CoveredFraction:0.00} • Avg px/cm {report.AveragePixelsPerCm:0.0}", 70, 94);
        sb.AppendLine("<rect x='70' y='175' width='1010' height='650' rx='26' fill='#10171A' stroke='#24343B'/> ");
        sb.AppendLine("<rect x='1110' y='175' width='420' height='650' rx='26' fill='#0D1417' stroke='#24343B'/> ");

        if (mode == FigureMode.WeakZones)
        {
            foreach (var sector in report.MissingSectors.Take(3)) sb.AppendLine(SectorWedge(centerX, centerY, volRadius + 18, camRadius - 8, sector.StartDegrees, sector.EndDegrees, "#D66363", 0.42));
            foreach (var sector in report.WeakSectors.Take(3)) sb.AppendLine(SectorWedge(centerX, centerY, volRadius + 18, camRadius - 8, sector.StartDegrees, sector.EndDegrees, "#D88A4C", 0.38));
        }
        else if (mode == FigureMode.RedundantAngles)
        {
            foreach (var sector in report.RedundantSectors.Take(3)) sb.AppendLine(SectorWedge(centerX, centerY, volRadius + 18, camRadius - 8, sector.StartDegrees, sector.EndDegrees, "#B8B059", 0.36));
        }

        sb.AppendLine($"<circle cx='{F(centerX)}' cy='{F(centerY)}' r='{F(volRadius)}' fill='none' stroke='#6FAF8F' stroke-width='5' stroke-dasharray='16 14' opacity='0.95'/> ");
        sb.AppendLine($"<circle cx='{F(centerX)}' cy='{F(centerY)}' r='32' fill='#7DBD90' opacity='0.92'/> ");
        sb.AppendLine($"<circle cx='{F(centerX)}' cy='{F(centerY)}' r='8' fill='#CFE8D7'/> ");
        sb.AppendLine($"<text x='{F(centerX - 42)}' y='{F(centerY + 65)}' fill='#D4DED9' font-size='18' font-family='Arial'>performer</text>");

        foreach (var c in list)
        {
            var p = ToFigure(c.PositionM, centerX, centerY, camRadius / c.PositionM.LengthXY);
            var color = ContributionColor(report, c.Id);
            sb.AppendLine($"<line x1='{F(p.x)}' y1='{F(p.y)}' x2='{F(centerX)}' y2='{F(centerY)}' stroke='#24343B' stroke-width='1.5'/> ");
            sb.AppendLine($"<circle cx='{F(p.x)}' cy='{F(p.y)}' r='10' fill='{color}' stroke='#F2F5F4' stroke-width='1.5' /> ");
            sb.AppendLine($"<text x='{F(p.x + 14)}' y='{F(p.y + 5)}' fill='#F2F5F4' font-size='14' font-family='Arial'>{c.Id}</text>");
        }

        AddLegend(sb, 100, 708, mode);
        AddDiagnosticsPanel(sb, report, mode);
        sb.AppendLine("</svg>");
        return sb.ToString();
    }

    private static void AddDiagnosticsPanel(StringBuilder sb, CoverageReport report, FigureMode mode)
    {
        var lines = new List<string>();
        var title = mode switch
        {
            FigureMode.WeakZones => "Weak-zone diagnosis",
            FigureMode.RedundantAngles => "Redundancy diagnosis",
            _ => "Layout diagnosis"
        };

        if (mode == FigureMode.WeakZones)
        {
            if (report.MissingSectors.Count == 0 && report.WeakSectors.Count == 0) lines.Add("No missing or weak sectors detected.");
            foreach (var s in report.MissingSectors.Take(3)) lines.Add($"Missing: {s.Label} ({s.StartDegrees:0}-{s.EndDegrees:0}°)");
            foreach (var s in report.WeakSectors.Take(3)) lines.Add($"Weak: {s.Label} ({s.CoverageCount} camera)");
        }
        else if (mode == FigureMode.RedundantAngles)
        {
            if (report.RedundantSectors.Count == 0) lines.Add("No true redundant same-angle sectors detected.");
            foreach (var s in report.RedundantSectors.Take(3)) lines.Add($"True redundant: {s.Label} ({s.CoverageCount} cams)");
            lines.Add("Normal overlap is required for 4DGS.");
        }
        else
        {
            lines.AddRange(report.Recommendations.Take(4));
        }

        lines.AddRange(report.MoveSuggestions.Take(2));
        lines.AddRange(report.PortraitRollNotes.Take(2));
        AddPanel(sb, 1135, 220, title, lines);
    }

    private static void AddPanel(StringBuilder sb, double x, double y, string title, IEnumerable<string> lines)
    {
        sb.AppendLine($"<text x='{F(x)}' y='{F(y)}' fill='#F5F7F6' font-size='28' font-family='Arial' font-weight='700'>{Escape(title)}</text>");
        var yy = y + 42;
        foreach (var line in lines.SelectMany(l => Wrap(l, 42)).Take(16))
        {
            sb.AppendLine($"<text x='{F(x)}' y='{F(yy)}' fill='#BBD0C4' font-size='18' font-family='Arial'>{Escape(line)}</text>");
            yy += 28;
        }
    }

    private static void AddLegend(StringBuilder sb, double x, double y, FigureMode mode)
    {
        sb.AppendLine($"<rect x='{F(x)}' y='{F(y)}' width='540' height='105' rx='12' fill='#0D1417' stroke='#223139'/> ");
        sb.AppendLine($"<text x='{F(x + 20)}' y='{F(y + 32)}' fill='#EAF0EC' font-size='22' font-family='Arial'>Legend</text>");
        sb.AppendLine($"<circle cx='{F(x + 40)}' cy='{F(y + 62)}' r='8' fill='#4DB778'/><text x='{F(x + 58)}' y='{F(y + 68)}' fill='#BBD0C4' font-size='16' font-family='Arial'>high contribution</text>");
        sb.AppendLine($"<circle cx='{F(x + 210)}' cy='{F(y + 62)}' r='8' fill='#D5A240'/><text x='{F(x + 228)}' y='{F(y + 68)}' fill='#BBD0C4' font-size='16' font-family='Arial'>medium</text>");
        sb.AppendLine($"<circle cx='{F(x + 330)}' cy='{F(y + 62)}' r='8' fill='#D66363'/><text x='{F(x + 348)}' y='{F(y + 68)}' fill='#BBD0C4' font-size='16' font-family='Arial'>low</text>");
        if (mode == FigureMode.WeakZones)
            sb.AppendLine($"<rect x='{F(x + 430)}' y='{F(y + 48)}' width='18' height='18' fill='#D88A4C' opacity='0.55'/><text x='{F(x + 458)}' y='{F(y + 64)}' fill='#BBD0C4' font-size='16' font-family='Arial'>weak</text>");
        if (mode == FigureMode.RedundantAngles)
            sb.AppendLine($"<rect x='{F(x + 430)}' y='{F(y + 48)}' width='18' height='18' fill='#B8B059' opacity='0.48'/><text x='{F(x + 458)}' y='{F(y + 64)}' fill='#BBD0C4' font-size='16' font-family='Arial'>true redundant</text>");
    }

    private static void AddTitle(StringBuilder sb, string title, string subtitle, double x, double y)
    {
        var size = title.Length switch
        {
            > 58 => 34,
            > 42 => 42,
            _ => 50
        };
        sb.AppendLine($"<text x='{F(x)}' y='{F(y)}' fill='#F5F7F6' font-size='{size}' font-family='Arial' font-weight='700'>{Escape(title)}</text>");
        sb.AppendLine($"<text x='{F(x)}' y='{F(y + 46)}' fill='#93A39D' font-size='24' font-family='Arial'>{Escape(subtitle)}</text>");
    }

    private static IEnumerable<string> Wrap(string text, int max)
    {
        var words = text.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var line = new StringBuilder();
        foreach (var word in words)
        {
            if (line.Length + word.Length + 1 > max && line.Length > 0)
            {
                yield return line.ToString();
                line.Clear();
            }
            if (line.Length > 0) line.Append(' ');
            line.Append(word);
        }
        if (line.Length > 0) yield return line.ToString();
    }

    private static (double x, double y) ToFigure(SplatViz.Core.Math.Vec3d position, double cx, double cy, double scale)
    {
        return (cx + (position.X * scale), cy - (position.Y * scale));
    }

    private static string ContributionColor(CoverageReport report, string cameraId)
    {
        var band = report.Contributions.FirstOrDefault(x => x.CameraId == cameraId)?.ContributionBand ?? "low";
        return band switch
        {
            "high" => "#4DB778",
            "medium" => "#D5A240",
            _ => "#D66363"
        };
    }

    private static string SectorWedge(double cx, double cy, double innerR, double outerR, double startDeg, double endDeg, string color, double opacity)
    {
        var a1 = (startDeg - 90) * System.Math.PI / 180.0;
        var a2 = (endDeg - 90) * System.Math.PI / 180.0;
        var p1 = (x: cx + outerR * System.Math.Cos(a1), y: cy + outerR * System.Math.Sin(a1));
        var p2 = (x: cx + outerR * System.Math.Cos(a2), y: cy + outerR * System.Math.Sin(a2));
        var p3 = (x: cx + innerR * System.Math.Cos(a2), y: cy + innerR * System.Math.Sin(a2));
        var p4 = (x: cx + innerR * System.Math.Cos(a1), y: cy + innerR * System.Math.Sin(a1));
        var large = (endDeg - startDeg) > 180 ? 1 : 0;
        return $"<path d='M {F(p1.x)} {F(p1.y)} A {F(outerR)} {F(outerR)} 0 {large} 1 {F(p2.x)} {F(p2.y)} L {F(p3.x)} {F(p3.y)} A {F(innerR)} {F(innerR)} 0 {large} 0 {F(p4.x)} {F(p4.y)} Z' fill='{color}' opacity='{opacity.ToString(CultureInfo.InvariantCulture)}' stroke='{color}' stroke-width='1.5' />";
    }

    private static string DefsAndBackground() => "<defs><linearGradient id='g' x1='0' x2='1'><stop offset='0%' stop-color='#0F181D'/><stop offset='100%' stop-color='#081015'/></linearGradient></defs><rect width='1600' height='900' fill='#081015'/><rect x='0' y='0' width='1600' height='900' fill='url(#g)' opacity='0.4'/>";
    private static string F(double value) => value.ToString("0.###", CultureInfo.InvariantCulture);
    private static string Escape(string v) => System.Security.SecurityElement.Escape(v) ?? string.Empty;

    private enum FigureMode
    {
        Overview,
        WeakZones,
        RedundantAngles
    }
}
