using SplatViz.Core.Cameras;
using SplatViz.Core.Math;
using SplatViz.Core.Scene;

namespace SplatViz.Core.Analysis;

public sealed class CoverageScorer
{
    private const int Bins = 24;

    public CoverageReport Score(IEnumerable<CameraInstance> cameraSet, CaptureVolume volume, PerformerEnvelope performer)
    {
        var cameras = cameraSet.ToList();
        var counts = Enumerable.Range(0, Bins).ToDictionary(x => x, _ => 0);
        var primary = cameras.ToDictionary(c => c.Id, _ => 0);
        var totalSeen = cameras.ToDictionary(c => c.Id, _ => 0);
        var viewersByBin = Enumerable.Range(0, Bins).ToDictionary(x => x, _ => new List<CameraInstance>());
        var binAngle = 360.0 / Bins;

        for (var bin = 0; bin < Bins; bin++)
        {
            var angleDeg = (bin * binAngle) + (binAngle / 2.0);
            var angleRad = angleDeg * System.Math.PI / 180.0;
            var sample = new Vec3d(
                volume.CenterM.X + (System.Math.Cos(angleRad) * performer.RadiusM),
                volume.CenterM.Y + (System.Math.Sin(angleRad) * performer.RadiusM),
                volume.CenterM.Z + (performer.HeightM * 0.5));

            var seeing = new List<(CameraInstance cam, double separation)>();
            foreach (var camera in cameras)
            {
                var toTarget = (sample - camera.PositionM).Normalized();
                var toAim = (camera.AimTargetM - camera.PositionM).Normalized();
                var dot = (toTarget.X * toAim.X) + (toTarget.Y * toAim.Y) + (toTarget.Z * toAim.Z);
                dot = System.Math.Max(-1, System.Math.Min(1, dot));
                var separation = System.Math.Acos(dot) * 180.0 / System.Math.PI;
                if (separation <= camera.HorizontalFovDegrees * 0.5)
                    seeing.Add((camera, separation));
            }

            counts[bin] = seeing.Count;
            viewersByBin[bin].AddRange(seeing.Select(x => x.cam));
            foreach (var cam in seeing) totalSeen[cam.cam.Id]++;
            if (seeing.Count > 0)
            {
                var primaryCam = seeing.OrderBy(x => x.separation).First().cam;
                primary[primaryCam.Id]++;
            }
        }

        var sectorInfos = Enumerable.Range(0, Bins)
            .Select(bin => MakeSector(bin, counts[bin], viewersByBin[bin]))
            .ToList();

        var missingSectors = sectorInfos.Where(x => x.Band == "missing").ToList();
        var weakSectors = sectorInfos.Where(x => x.Band == "weak").ToList();
        var usefulOverlapSectors = sectorInfos.Where(x => x.Band == "useful_overlap").ToList();
        var redundantSectors = sectorInfos.Where(x => x.Band == "true_redundant").ToList();

        var weakBins = missingSectors.Concat(weakSectors).Select(x => x.Bin).ToList();
        var redundantBins = redundantSectors.Select(x => x.Bin).ToList();
        var coveredFraction = counts.Values.Count(v => v > 0) / (double)Bins;
        var avgUsefulOverlap = counts.Values.Average(v => System.Math.Min(v, 3));
        var avgPxPerCm = cameras.Count == 0 ? 0 : cameras.Average(c => c.ApproxPixelsPerCmAtAim);
        var maxGap = FindMaxGapDegrees(counts, Bins);

        var moveSuggestions = BuildMoveSuggestions(cameras, missingSectors, weakSectors, redundantSectors, primary, totalSeen, viewersByBin);
        var contributions = cameras
            .Select(c => BuildContribution(c, primary[c.Id], totalSeen[c.Id], moveSuggestions))
            .OrderByDescending(c => c.ContributionScore)
            .ToList();

        var missingPenalty = missingSectors.Count * 4.0;
        var weakPenalty = weakSectors.Count * 1.5;
        var redundancyPenalty = redundantSectors.Count * 0.6;
        var score = System.Math.Round(
            (coveredFraction * 62.0)
            + (System.Math.Min(avgUsefulOverlap, 3.0) / 3.0 * 18.0)
            + (System.Math.Min(avgPxPerCm, 20.0) / 20.0 * 16.0)
            + System.Math.Max(0.0, 8.0 - (maxGap / 10.0))
            - missingPenalty
            - weakPenalty
            - redundancyPenalty,
            3);
        score = System.Math.Max(0, System.Math.Min(100, score));

        var portraitNotes = BuildPortraitRollNotes(cameras, performer);
        var recommendations = BuildRecommendations(cameras.Count, missingSectors, weakSectors, usefulOverlapSectors, redundantSectors, avgPxPerCm, cameras, moveSuggestions);

        return new CoverageReport(
            score,
            System.Math.Round(coveredFraction, 4),
            System.Math.Round(maxGap, 3),
            System.Math.Round(avgUsefulOverlap, 3),
            System.Math.Round(avgPxPerCm, 3),
            weakBins,
            redundantBins,
            counts,
            missingSectors,
            weakSectors,
            usefulOverlapSectors,
            redundantSectors,
            contributions,
            recommendations,
            portraitNotes,
            moveSuggestions);
    }

    private static SectorInfo MakeSector(int bin, int coverageCount, IReadOnlyList<CameraInstance> viewers)
    {
        var width = 360.0 / Bins;
        var label = AngleLabeler.BinLabel(bin, Bins);
        var trueRedundant = IsTrueRedundant(viewers);

        if (coverageCount == 0)
            return new SectorInfo(bin, label, bin * width, (bin + 1) * width, coverageCount, "missing", "No camera directly resolves this azimuth band.");
        if (coverageCount == 1)
            return new SectorInfo(bin, label, bin * width, (bin + 1) * width, coverageCount, "weak", "Single-view coverage is fragile for occlusion and deformation.");
        if (coverageCount <= 4 || !trueRedundant)
            return new SectorInfo(bin, label, bin * width, (bin + 1) * width, coverageCount, "useful_overlap", "Overlap is useful for 4DGS view consistency and occlusion recovery.");

        return new SectorInfo(bin, label, bin * width, (bin + 1) * width, coverageCount, "true_redundant", "Multiple near-identical views contribute little new parallax.");
    }

    private static bool IsTrueRedundant(IReadOnlyList<CameraInstance> viewers)
    {
        if (viewers.Count < 5) return false;

        var angles = viewers.Select(CameraAzimuthDegrees).OrderBy(x => x).ToList();
        for (var i = 0; i < angles.Count; i++)
        {
            var cluster = 1;
            for (var j = i + 1; j < angles.Count; j++)
            {
                var gap = AngularDistance(angles[i], angles[j]);
                if (gap <= 10.0) cluster++;
            }
            if (cluster >= 3)
            {
                var clustered = viewers.Where(v => AngularDistance(CameraAzimuthDegrees(v), angles[i]) <= 10.0).ToList();
                var zSpread = clustered.Max(c => c.PositionM.Z) - clustered.Min(c => c.PositionM.Z);
                if (zSpread < 0.35) return true;
            }
        }

        return false;
    }

    private static CameraContribution BuildContribution(CameraInstance camera, int primaryBins, int totalBinsSeen, IReadOnlyList<string> moveSuggestions)
    {
        var score = System.Math.Round((primaryBins * 1.7) + (totalBinsSeen * 0.22) + (camera.PortraitRoll ? 0.3 : 0.0), 3);
        var band = score switch
        {
            >= 5.0 => "high",
            >= 2.5 => "medium",
            _ => "low"
        };

        var action = "Keep";
        var rationale = "Contributes useful parallax or view overlap.";
        var leanCandidate = false;

        var directSuggestion = moveSuggestions.FirstOrDefault(s => s.Contains(camera.Id, StringComparison.OrdinalIgnoreCase));
        if (directSuggestion is not null)
        {
            action = directSuggestion;
            rationale = "This camera is a practical adjustment target in the current layout.";
            leanCandidate = directSuggestion.Contains("remove", StringComparison.OrdinalIgnoreCase);
        }
        else if (primaryBins == 0 && totalBinsSeen > 0)
        {
            action = "Candidate to re-aim after weak-zone review";
            rationale = "It sees the performer but is rarely the primary view.";
        }

        return new CameraContribution(camera.Id, primaryBins, totalBinsSeen, score, band, leanCandidate, action, rationale);
    }

    private static IReadOnlyList<string> BuildMoveSuggestions(
        IReadOnlyList<CameraInstance> cameras,
        IReadOnlyList<SectorInfo> missing,
        IReadOnlyList<SectorInfo> weak,
        IReadOnlyList<SectorInfo> redundant,
        Dictionary<string, int> primary,
        Dictionary<string, int> totalSeen,
        Dictionary<int, List<CameraInstance>> viewersByBin)
    {
        var suggestions = new List<string>();
        var target = missing.FirstOrDefault() ?? weak.FirstOrDefault();

        if (target is not null)
        {
            var targetAngle = (target.StartDegrees + target.EndDegrees) * 0.5;
            var candidate = cameras
                .OrderBy(c => primary[c.Id])
                .ThenByDescending(c => AngularDistance(CameraAzimuthDegrees(c), targetAngle))
                .FirstOrDefault();
            if (candidate is not null)
            {
                var current = CameraAzimuthDegrees(candidate);
                var delta = SignedDeltaDegrees(current, targetAngle);
                suggestions.Add($"Move {candidate.Id} {System.Math.Abs(delta):0}° {(delta >= 0 ? "counter-clockwise" : "clockwise")} toward {target.Label}.");
            }
        }

        foreach (var sector in redundant.Take(3))
        {
            var candidate = viewersByBin[sector.Bin]
                .OrderBy(c => primary[c.Id])
                .ThenBy(c => totalSeen[c.Id])
                .FirstOrDefault();
            if (candidate is not null)
                suggestions.Add($"Remove or re-aim {candidate.Id} only for a lean build; {sector.Label} is true redundant.");
        }

        if (!suggestions.Any())
            suggestions.Add("No camera move required. Preserve useful overlap; do not remove cameras solely because they overlap.");

        return suggestions;
    }

    private static IReadOnlyList<string> BuildRecommendations(
        int cameraCount,
        IReadOnlyList<SectorInfo> missing,
        IReadOnlyList<SectorInfo> weak,
        IReadOnlyList<SectorInfo> usefulOverlap,
        IReadOnlyList<SectorInfo> redundant,
        double avgPxPerCm,
        IReadOnlyList<CameraInstance> cameras,
        IReadOnlyList<string> moveSuggestions)
    {
        var lines = new List<string>();
        if (missing.Count == 0 && weak.Count == 0)
            lines.Add("Coverage is continuous around the performer envelope.");
        else
            lines.Add($"Coverage risk appears in {string.Join(", ", missing.Concat(weak).Take(3).Select(x => x.Label))}.");

        if (usefulOverlap.Count > 0)
            lines.Add("2–4 camera overlap is treated as useful for 4DGS, not waste.");

        if (redundant.Count > 0)
            lines.Add($"True redundant same-angle coverage appears in {string.Join(", ", redundant.Take(3).Select(x => x.Label))}.");
        else
            lines.Add("No true redundant same-angle sectors detected.");

        if (avgPxPerCm < 10)
            lines.Add("Per-subject resolution is low. Reduce subject distance or use a denser layout before raising frame rate.");
        else
            lines.Add("Per-subject resolution is viable for a synthetic preflight pass.");

        lines.Add(moveSuggestions.First());
        lines.Add(cameraCount switch
        {
            <= 16 => "Lean layout: fastest laptop preflight; expect lower occlusion resilience.",
            <= 24 => "Recommended layout: best starting point for one performer in a controlled volume.",
            _ => "Premium layout: use when wardrobe, props, or fast motion increase occlusion risk."
        });
        return lines;
    }

    private static IReadOnlyList<string> BuildPortraitRollNotes(IReadOnlyList<CameraInstance> cameras, PerformerEnvelope performer)
    {
        var portraitCount = cameras.Count(c => c.PortraitRoll);
        var landscapeCount = cameras.Count - portraitCount;
        var notes = new List<string>
        {
            $"Portrait roll count: {portraitCount}; landscape count: {landscapeCount}.",
            "Do not roll every camera 90°. Use selected rolled cameras to improve vertical body coverage while keeping landscape views for horizontal parallax.",
            performer.HeightM > 1.7
                ? "Performer envelope is human-height; selected portrait cameras are useful for head-to-toe coverage."
                : "Performer envelope is compact; landscape capture should dominate unless the action is vertical."
        };
        return notes;
    }

    private static double FindMaxGapDegrees(IReadOnlyDictionary<int, int> counts, int bins)
    {
        var longestRun = 0;
        var current = 0;
        for (var i = 0; i < bins * 2; i++)
        {
            var idx = i % bins;
            if (counts[idx] == 0)
            {
                current++;
                longestRun = System.Math.Max(longestRun, current);
            }
            else current = 0;
        }
        longestRun = System.Math.Min(longestRun, bins);
        return longestRun * 360.0 / bins;
    }

    private static double CameraAzimuthDegrees(CameraInstance camera)
    {
        var deg = System.Math.Atan2(camera.PositionM.Y, camera.PositionM.X) * 180.0 / System.Math.PI;
        return NormalizeDegrees(deg);
    }

    private static double NormalizeDegrees(double degrees)
    {
        var result = degrees % 360.0;
        return result < 0 ? result + 360.0 : result;
    }

    private static double AngularDistance(double a, double b)
    {
        var diff = System.Math.Abs(NormalizeDegrees(a) - NormalizeDegrees(b));
        return System.Math.Min(diff, 360.0 - diff);
    }

    private static double SignedDeltaDegrees(double from, double to)
    {
        var delta = (NormalizeDegrees(to) - NormalizeDegrees(from) + 540.0) % 360.0 - 180.0;
        return delta;
    }
}
