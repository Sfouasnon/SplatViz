using System.Globalization;
using System.Text;
using SplatViz.Core.Mounts;

namespace SplatViz.Core.Export;

public static class MountScheduleExporter
{
    public static string ToCsv(IEnumerable<BoxTruss> trusses, IEnumerable<Stand> stands)
    {
        var sb = new StringBuilder();
        sb.AppendLine("id,type,x_mm,y_mm,z_mm,end_x_mm,end_y_mm,end_z_mm,length_mm,cross_section_mm,min_height_mm,max_height_mm,slot_spacing_mm,mountable_faces");
        foreach (var t in trusses)
        {
            var a = t.StartM.ToMillimeters();
            var b = t.EndM.ToMillimeters();
            sb.AppendLine(string.Join(',', new[] { t.Id, "box_truss", F(a.X), F(a.Y), F(a.Z), F(b.X), F(b.Y), F(b.Z), F(t.LengthM * 1000.0), F(t.CrossSectionMm), "", "", F(t.SlotSpacingMm), Escape(string.Join('|', t.MountableFaces)) }));
        }
        foreach (var s in stands)
        {
            var p = s.BasePositionM.ToMillimeters();
            sb.AppendLine(string.Join(',', new[] { s.Id, "stand", F(p.X), F(p.Y), F(p.Z), "", "", "", "", "", F(s.MinHeightMm), F(s.MaxHeightMm), F(s.HeightStepMm), "socket" }));
        }
        return sb.ToString();
    }
    private static string F(double value) => value.ToString("0.###", CultureInfo.InvariantCulture);
    private static string Escape(string s) => s.Contains(',') ? $"\"{s.Replace("\"", "\"\"")}\"" : s;
}
