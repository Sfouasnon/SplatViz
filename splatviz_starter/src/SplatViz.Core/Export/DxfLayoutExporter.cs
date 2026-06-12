using System.Globalization;
using System.Text;
using SplatViz.Core.Analysis;
using SplatViz.Core.Cameras;
using SplatViz.Core.Mounts;
using SplatViz.Core.Scene;

namespace SplatViz.Core.Export;

public static class DxfLayoutExporter
{
    public static string Export(Room room, CaptureVolume volume, IEnumerable<CameraInstance> cameras, IEnumerable<BoxTruss> trusses, IEnumerable<Stand> stands, CoverageReport report)
    {
        var sb = new StringBuilder();
        sb.AppendLine("0\nSECTION\n2\nHEADER\n0\nENDSEC");
        sb.AppendLine("0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER\n70\n8");
        foreach (var layer in new[] { "ROOM", "CAPTURE_VOLUME", "TRUSS", "STANDS", "CAMERAS", "FRUSTUMS", "WEAK_ZONES", "REDUNDANT_ANGLES" })
        {
            sb.AppendLine($"0\nLAYER\n2\n{layer}\n70\n0\n62\n7\n6\nCONTINUOUS");
        }
        sb.AppendLine("0\nENDTAB\n0\nENDSEC");
        sb.AppendLine("0\nSECTION\n2\nENTITIES");

        var size = room.SizeM.ToMillimeters();
        AddRect(sb, "ROOM", -size.X / 2, -size.Y / 2, size.X / 2, size.Y / 2);
        AddCircle(sb, "CAPTURE_VOLUME", volume.CenterM.X * 1000, volume.CenterM.Y * 1000, volume.RadiusM * 1000);

        foreach (var t in trusses)
        {
            var a = t.StartM.ToMillimeters(); var b = t.EndM.ToMillimeters();
            AddLine(sb, "TRUSS", a.X, a.Y, b.X, b.Y);
        }
        foreach (var s in stands)
        {
            var p = s.BasePositionM.ToMillimeters();
            AddCircle(sb, "STANDS", p.X, p.Y, 80);
        }
        foreach (var c in cameras)
        {
            var p = c.PositionM.ToMillimeters(); var a = c.AimTargetM.ToMillimeters();
            AddCircle(sb, "CAMERAS", p.X, p.Y, 55);
            AddLine(sb, "FRUSTUMS", p.X, p.Y, a.X, a.Y);
        }
        foreach (var s in report.MissingSectors.Concat(report.WeakSectors))
        {
            AddSectorMarker(sb, "WEAK_ZONES", s.StartDegrees, s.EndDegrees, volume.RadiusM * 1300);
        }
        foreach (var s in report.RedundantSectors)
        {
            AddSectorMarker(sb, "REDUNDANT_ANGLES", s.StartDegrees, s.EndDegrees, volume.RadiusM * 1550);
        }

        sb.AppendLine("0\nENDSEC\n0\nEOF");
        return sb.ToString();
    }

    private static void AddRect(StringBuilder sb, string layer, double x1, double y1, double x2, double y2)
    {
        AddLine(sb, layer, x1, y1, x2, y1); AddLine(sb, layer, x2, y1, x2, y2); AddLine(sb, layer, x2, y2, x1, y2); AddLine(sb, layer, x1, y2, x1, y1);
    }
    private static void AddLine(StringBuilder sb, string layer, double x1, double y1, double x2, double y2)
    {
        sb.AppendLine($"0\nLINE\n8\n{layer}\n10\n{F(x1)}\n20\n{F(y1)}\n30\n0\n11\n{F(x2)}\n21\n{F(y2)}\n31\n0");
    }
    private static void AddCircle(StringBuilder sb, string layer, double x, double y, double r)
    {
        sb.AppendLine($"0\nCIRCLE\n8\n{layer}\n10\n{F(x)}\n20\n{F(y)}\n30\n0\n40\n{F(r)}");
    }
    private static void AddSectorMarker(StringBuilder sb, string layer, double startDeg, double endDeg, double radius)
    {
        var a1 = startDeg * System.Math.PI / 180.0;
        var a2 = endDeg * System.Math.PI / 180.0;
        AddLine(sb, layer, 0, 0, System.Math.Cos(a1) * radius, System.Math.Sin(a1) * radius);
        AddLine(sb, layer, 0, 0, System.Math.Cos(a2) * radius, System.Math.Sin(a2) * radius);
    }
    private static string F(double v) => v.ToString("0.###", CultureInfo.InvariantCulture);
}
