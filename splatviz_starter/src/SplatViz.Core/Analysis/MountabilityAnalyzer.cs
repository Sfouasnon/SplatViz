using SplatViz.Core.Cameras;
using SplatViz.Core.Mounts;
using SplatViz.Core.Scene;

namespace SplatViz.Core.Analysis;

public static class MountabilityAnalyzer
{
    public static MountabilityReport Analyze(LayoutPlan plan)
    {
        var issues = new List<MountabilityIssue>();
        foreach (var camera in plan.Cameras)
        {
            if (camera.Mount.Type == "unassigned")
            {
                issues.Add(new MountabilityIssue("warning", camera.Id, camera.Mount.Id, "Camera has no physical mount assignment yet. Assign to box truss, stand, wall plate, or custom mount before field layout."));
                continue;
            }

            if (camera.Mount.Type == "stand" && !IsWithinStandEnvelope(camera, plan.Stands))
            {
                issues.Add(new MountabilityIssue("error", camera.Id, camera.Mount.Id, "Camera height is outside the declared stand height range."));
            }

            if (camera.Mount.Type == "box_truss" && !IsNearAnyTruss(camera, plan.Trusses))
            {
                issues.Add(new MountabilityIssue("warning", camera.Id, camera.Mount.Id, "Camera is assigned to box truss but is not physically near a declared truss span."));
            }
        }

        var mounted = plan.Cameras.Count(c => c.Mount.Type != "unassigned");
        var unassigned = plan.Cameras.Count - mounted;
        var summary = new List<string>
        {
            $"{mounted}/{plan.Cameras.Count} cameras have physical mount assignments.",
            unassigned == 0 ? "No unassigned virtual cameras remain." : $"{unassigned} cameras remain virtual/unassigned and need practical rigging decisions.",
            "Mountability is measured in real-world meters/mm and should be treated as a pre-CAD sanity pass, not final rig engineering."
        };

        return new MountabilityReport(plan.Tier.ToString(), plan.Name, plan.Cameras.Count, mounted, unassigned, issues, summary);
    }

    private static bool IsWithinStandEnvelope(CameraInstance camera, IReadOnlyList<Stand> stands)
    {
        var zMm = camera.PositionM.Z * 1000.0;
        return stands.Any(s => zMm >= s.MinHeightMm && zMm <= s.MaxHeightMm);
    }

    private static bool IsNearAnyTruss(CameraInstance camera, IReadOnlyList<BoxTruss> trusses)
    {
        return trusses.Any(t =>
        {
            var minX = System.Math.Min(t.StartM.X, t.EndM.X) - 0.35;
            var maxX = System.Math.Max(t.StartM.X, t.EndM.X) + 0.35;
            var minY = System.Math.Min(t.StartM.Y, t.EndM.Y) - 0.35;
            var maxY = System.Math.Max(t.StartM.Y, t.EndM.Y) + 0.35;
            var zOk = System.Math.Abs(camera.PositionM.Z - t.StartM.Z) < 0.9;
            return camera.PositionM.X >= minX && camera.PositionM.X <= maxX && camera.PositionM.Y >= minY && camera.PositionM.Y <= maxY && zOk;
        });
    }
}
