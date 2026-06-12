using SplatViz.Core.Scene;

namespace SplatViz.Core.Analysis;

public static class SplatabilityPlanner
{
    private sealed record ResolutionProfile(string Name, int Width, int Height, string Aspect, double DetailFactor);

    private static readonly ResolutionProfile[] Profiles =
    {
        new("4K 16:9", 4096, 2304, "16:9", 0.78),
        new("5K 16:9", 5120, 2880, "16:9", 0.90),
        new("6K 16:9", 6144, 3456, "16:9", 1.00)
    };

    private static readonly double[] DistancesM = { 3.0, 3.5, 3.8, 4.0, 4.5, 5.0 };

    public static IReadOnlyList<SplatabilityCandidate> Plan(LayoutPlan plan, CoverageReport report)
    {
        var averageNeighborGap = 360.0 / plan.Cameras.Count;
        var list = new List<SplatabilityCandidate>();
        foreach (var profile in Profiles)
        {
            foreach (var distance in DistancesM)
            {
                list.Add(Build(plan, report, profile, distance, averageNeighborGap));
            }
        }
        return list
            .OrderByDescending(x => x.SplatabilityScore + x.ProductionFeasibilityScore * 0.35)
            .ToList();
    }

    public static SplatabilityCandidate Recommended(IEnumerable<SplatabilityCandidate> candidates)
    {
        return candidates
            .Where(x => x.Verdict is "safe" or "solve_test_recommended")
            .OrderByDescending(x => x.SplatabilityScore * 0.65 + x.ProductionFeasibilityScore * 0.35)
            .FirstOrDefault()
            ?? candidates.OrderByDescending(x => x.SplatabilityScore).First();
    }

    public static IReadOnlyDictionary<string, SplatabilityCandidate?> SolveTestCandidates(IEnumerable<SplatabilityCandidate> candidates)
    {
        var list = candidates.ToList();
        return new Dictionary<string, SplatabilityCandidate?>
        {
            ["safest_technical"] = list.Where(x => x.Verdict == "safe").OrderByDescending(x => x.SplatabilityScore + x.FocusBoxConfidenceScore * 0.25).FirstOrDefault(),
            ["five_k_challenger"] = list.Where(x => x.ResolutionName.StartsWith("5K") && (x.Verdict == "safe" || x.Verdict == "solve_test_recommended")).OrderByDescending(x => x.SplatabilityScore + x.ProductionFeasibilityScore * 0.25).FirstOrDefault(),
            ["lowest_viable_4k"] = list.Where(x => x.ResolutionName.StartsWith("4K") && (x.Verdict == "safe" || x.Verdict == "solve_test_recommended" || x.Verdict == "splat_viable_but_production_risky")).OrderByDescending(x => x.SplatabilityScore + x.ProductionFeasibilityScore * 0.15).FirstOrDefault()
        };
    }

    private static SplatabilityCandidate Build(LayoutPlan plan, CoverageReport report, ResolutionProfile profile, double distanceM, double neighborGap)
    {
        const double focalMm = 24.0;
        const double sensorWidthMm = 27.03;
        const double sensorHeightMm = 15.20; // 16:9 crop approximation for KOMODO-X comparator.
        const double tStop = 5.6;
        const double circleOfConfusionMm = 0.020;
        const double focusBoxHalfDepthM = 0.75; // Tape-box default: performer stays +/- 0.75m fore/aft from eye focus plane.

        var performerHeightM = plan.PerformerEnvelope.HeightM;
        var captureRadiusM = plan.CaptureVolume.RadiusM;
        var actionDepthM = focusBoxHalfDepthM * 2.0;

        var hFovRad = 2.0 * System.Math.Atan(sensorWidthMm / (2.0 * focalMm));
        var vFovRad = 2.0 * System.Math.Atan(sensorHeightMm / (2.0 * focalMm));
        var viewWidthM = 2.0 * distanceM * System.Math.Tan(hFovRad / 2.0);
        var viewHeightM = 2.0 * distanceM * System.Math.Tan(vFovRad / 2.0);
        var pxPerCm = profile.Width / (viewWidthM * 100.0);
        var bodyFrameHeightPercent = performerHeightM / viewHeightM * 100.0;

        var pxScore = ClampScore((pxPerCm - 7.0) / (13.0 - 7.0) * 100.0);
        var idealFill = 72.0;
        var fillError = System.Math.Abs(bodyFrameHeightPercent - idealFill);
        var bodyMarginScore = ClampScore(100.0 - fillError * 2.2);
        if (bodyFrameHeightPercent > 88.0) bodyMarginScore -= 18.0;
        if (bodyFrameHeightPercent < 45.0) bodyMarginScore -= 12.0;
        bodyMarginScore = ClampScore(bodyMarginScore);

        var parallaxScore = NeighborParallaxScore(neighborGap, distanceM);
        var dof = DepthOfField(focalMm, tStop, circleOfConfusionMm, distanceM);
        var acceptableFocusPass = dof.nearM <= distanceM - focusBoxHalfDepthM && dof.farM >= distanceM + focusBoxHalfDepthM;
        var dofRangeM = dof.farM >= 999.0 ? 999.0 : dof.farM - dof.nearM;
        var dofSafetyScore = ClampScore((dofRangeM / actionDepthM) * 85.0);
        if (!acceptableFocusPass) dofSafetyScore -= 24.0;
        dofSafetyScore = ClampScore(dofSafetyScore);

        var critical = CriticalSharpnessZone(distanceM, profile.DetailFactor, focusBoxHalfDepthM);
        var eyePlaneConfidence = EyePlaneConfidence(pxPerCm, profile);
        var focusBoxConfidence = ClampScore(critical.coverageScore * 0.62 + eyePlaneConfidence * 0.28 + bodyMarginScore * 0.10);
        var criticalSharpnessScore = ClampScore(critical.coverageScore * 0.70 + eyePlaneConfidence * 0.30);

        var rigLightingInterferenceScore = RigLightingInterferenceSafetyScore(distanceM, plan);
        var angularScore = report.CoveredFraction >= 0.98 ? 96.0 : report.Score;

        var splatScore = ClampScore(
            pxScore * 0.29 +
            bodyMarginScore * 0.17 +
            parallaxScore * 0.17 +
            focusBoxConfidence * 0.19 +
            angularScore * 0.18);

        var feasibility = ClampScore(
            rigLightingInterferenceScore * 0.40 +
            bodyMarginScore * 0.20 +
            focusBoxConfidence * 0.22 +
            MountabilityScore(plan) * 0.18);

        var verdict = Verdict(splatScore, feasibility, focusBoxConfidence, rigLightingInterferenceScore, bodyFrameHeightPercent, pxPerCm, distanceM);
        var notes = Notes(profile, distanceM, pxPerCm, bodyFrameHeightPercent, parallaxScore, focusBoxConfidence, criticalSharpnessScore, rigLightingInterferenceScore, verdict, acceptableFocusPass);

        return new SplatabilityCandidate(
            plan.Tier.ToString(),
            plan.Name,
            profile.Name,
            profile.Width,
            profile.Height,
            distanceM,
            Round(pxPerCm),
            Round(bodyFrameHeightPercent),
            Round(bodyMarginScore),
            Round(parallaxScore),
            Round(dof.nearM),
            dof.farM >= 999.0 ? 999.0 : Round(dof.farM),
            Round(dofSafetyScore),
            acceptableFocusPass,
            Round(critical.nearM),
            Round(critical.farM),
            Round(criticalSharpnessScore),
            Round(focusBoxConfidence),
            Round(eyePlaneConfidence),
            Round(rigLightingInterferenceScore),
            Round(rigLightingInterferenceScore),
            Round(splatScore),
            Round(feasibility),
            verdict,
            notes);
    }

    private static (double nearM, double farM, double coverageScore) CriticalSharpnessZone(double focusDistanceM, double detailFactor, double focusBoxHalfDepthM)
    {
        // This is intentionally narrower than textbook DOF. It approximates the taped zone where detail resolves well for reconstruction.
        var halfDepthM = focusDistanceM * 0.22 * detailFactor;
        halfDepthM = System.Math.Max(0.42, System.Math.Min(0.95, halfDepthM));
        var near = System.Math.Max(0.25, focusDistanceM - halfDepthM);
        var far = focusDistanceM + halfDepthM;
        var coverage = ClampScore((halfDepthM / focusBoxHalfDepthM) * 100.0);
        return (near, far, coverage);
    }

    private static double EyePlaneConfidence(double pxPerCm, ResolutionProfile profile)
    {
        var px = pxPerCm >= 12.0 ? 100.0 : pxPerCm >= 10.0 ? 90.0 : pxPerCm >= 9.0 ? 78.0 : 58.0;
        var resPenalty = profile.Name.StartsWith("4K") ? -6.0 : profile.Name.StartsWith("5K") ? -2.0 : 0.0;
        return ClampScore(px + resPenalty);
    }

    private static double NeighborParallaxScore(double gapDeg, double distanceM)
    {
        var ideal = distanceM <= 3.3 ? 12.0 : distanceM <= 4.2 ? 14.0 : 16.0;
        var error = System.Math.Abs(gapDeg - ideal);
        var score = 100.0 - error * 4.0;
        if (gapDeg < 7.0) score -= 18.0;
        if (gapDeg > 24.0) score -= 20.0;
        return ClampScore(score);
    }

    private static (double nearM, double farM) DepthOfField(double focalMm, double tStop, double cocMm, double subjectDistanceM)
    {
        var s = subjectDistanceM * 1000.0;
        var h = (focalMm * focalMm) / (tStop * cocMm) + focalMm;
        var near = (h * s) / (h + (s - focalMm));
        var farDenom = h - (s - focalMm);
        var far = farDenom <= 0 ? 999000.0 : (h * s) / farDenom;
        return (near / 1000.0, far / 1000.0);
    }

    private static double RigLightingInterferenceSafetyScore(double distanceM, LayoutPlan plan)
    {
        var score = 100.0;
        if (distanceM < 3.2) score -= 44.0;
        else if (distanceM < 3.6) score -= 28.0;
        else if (distanceM < 3.9) score -= 12.0;
        else if (distanceM < 4.05) score -= 4.0;

        var lowCameras = plan.Cameras.Count(c => c.PositionM.Z < 1.25);
        score -= lowCameras * 2.0;

        var unassigned = plan.Cameras.Count(c => c.Mount.Type == "unassigned");
        score -= System.Math.Min(18.0, unassigned * 0.8);
        return ClampScore(score);
    }

    private static double MountabilityScore(LayoutPlan plan)
    {
        var unassigned = plan.Cameras.Count(c => c.Mount.Type == "unassigned");
        return ClampScore(100.0 - unassigned * 2.2);
    }

    private static string Verdict(double splatScore, double feasibility, double focusBox, double rigLighting, double fill, double pxPerCm, double distanceM)
    {
        if (splatScore >= 88.0 && feasibility >= 78.0 && focusBox >= 84.0 && fill <= 86.0) return "safe";
        if (splatScore >= 76.0 && focusBox >= 68.0 && pxPerCm >= 9.0 && feasibility >= 68.0) return "solve_test_recommended";
        if (splatScore >= 72.0 && pxPerCm >= 9.0 && (feasibility < 68.0 || rigLighting < 66.0 || fill > 88.0 || distanceM < 3.4)) return "splat_viable_but_production_risky";
        return "not_preferred";
    }

    private static IReadOnlyList<string> Notes(ResolutionProfile profile, double distanceM, double pxPerCm, double fill, double parallax, double focusBox, double critical, double rigLighting, string verdict, bool acceptableFocusPass)
    {
        var notes = new List<string>();
        if (pxPerCm >= 12.0) notes.Add("strong projected subject detail");
        else if (pxPerCm >= 9.0) notes.Add("projected detail is likely viable but should be solve-tested");
        else notes.Add("projected detail is the limiting factor");

        if (fill > 88.0) notes.Add("tight body margin; hands/feet/action may clip");
        else if (fill < 48.0) notes.Add("loose frame; resolution may be underused");
        else notes.Add("body fill has usable motion margin");

        if (!acceptableFocusPass) notes.Add("traditional DOF does not fully contain the taped focus box");
        if (critical < 75.0 || focusBox < 75.0) notes.Add("critical sharpness zone is narrower than the taped focus box");
        if (parallax < 70.0) notes.Add("neighbor parallax is outside the preferred continuity band");
        if (rigLighting < 70.0) notes.Add("closer distance raises rig, stand, truss, and lighting-interference risk at T5.6 / 90° / ISO 800");
        if (verdict == "solve_test_recommended") notes.Add("export synthetic stills and verify with a quick gsplat solve before committing");
        if (verdict == "splat_viable_but_production_risky") notes.Add("splat viability depends on production tradeoffs; test before committing");
        if (profile.Name.StartsWith("4K", StringComparison.OrdinalIgnoreCase) && distanceM > 4.2) notes.Add("4K becomes marginal at this distance unless the subject is larger in frame");
        return notes;
    }

    private static double ClampScore(double v) => System.Math.Max(0.0, System.Math.Min(100.0, v));
    private static double Round(double v) => System.Math.Round(v, 3);
}
