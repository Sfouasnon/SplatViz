using System.Globalization;
using System.Text;
using SplatViz.Core.Analysis;
using SplatViz.Core.Cameras;

namespace SplatViz.Core.Export;

public static class CameraScheduleExporter
{
    public static string ToCsv(IEnumerable<CameraInstance> cameras, IEnumerable<CameraContribution> contributions)
    {
        var map = contributions.ToDictionary(x => x.CameraId, x => x);
        var sb = new StringBuilder();
        sb.AppendLine("id,x_mm,y_mm,z_mm,aim_x_mm,aim_y_mm,aim_z_mm,mount_id,mount_type,mount_offset_mm,mount_face,lens,recording,portrait_roll,distance_to_aim_m,h_fov_deg,v_fov_deg,px_per_cm,primary_bins,total_bins_seen,contribution_score,contribution_band,lean_removal_candidate,suggested_action,rationale");
        foreach (var c in cameras)
        {
            var p = c.PositionM.ToMillimeters();
            var a = c.AimTargetM.ToMillimeters();
            var cc = map[c.Id];
            sb.AppendLine(string.Join(',', new[]
            {
                c.Id, F(p.X), F(p.Y), F(p.Z), F(a.X), F(a.Y), F(a.Z), c.Mount.Id, c.Mount.Type, F(c.Mount.OffsetMm), c.Mount.Face,
                Escape(c.Lens.Name), Escape(c.RecordingMode.Name), c.PortraitRoll.ToString().ToLowerInvariant(), F(c.DistanceToAimM), F(c.HorizontalFovDegrees), F(c.VerticalFovDegrees), F(c.ApproxPixelsPerCmAtAim),
                cc.PrimaryBins.ToString(CultureInfo.InvariantCulture), cc.TotalBinsSeen.ToString(CultureInfo.InvariantCulture), F(cc.ContributionScore), cc.ContributionBand,
                cc.LeanRemovalCandidate.ToString().ToLowerInvariant(), Escape(cc.SuggestedAction), Escape(cc.Rationale)
            }));
        }
        return sb.ToString();
    }

    private static string F(double value) => value.ToString("0.###", CultureInfo.InvariantCulture);
    private static string Escape(string s) => s.Contains(',') ? $"\"{s.Replace("\"", "\"\"")}\"" : s;
}
