using SplatViz.Core.Analysis;
using SplatViz.Core.Cameras;
using SplatViz.Core.Math;
using SplatViz.Core.Mounts;
using SplatViz.Core.Scene;
using Xunit;

namespace SplatViz.Core.Tests;

public class CoverageScorerTests
{
    [Fact]
    public void SampleFactory_builds_three_tiers()
    {
        var plans = SampleLayoutFactory.BuildDefaultThreeTierPlans();
        Assert.Equal(3, plans.Count);
        Assert.Contains(plans, p => p.Tier == LayoutTier.Lean && p.Cameras.Count == 16);
        Assert.Contains(plans, p => p.Tier == LayoutTier.Recommended && p.Cameras.Count == 24);
        Assert.Contains(plans, p => p.Tier == LayoutTier.Premium && p.Cameras.Count == 36);
    }

    [Fact]
    public void Coverage_scorer_reports_fraction_between_zero_and_one()
    {
        var plan = SampleLayoutFactory.BuildDefaultThreeTierPlans().First(p => p.Tier == LayoutTier.Recommended);
        var report = new CoverageScorer().Score(plan.Cameras, plan.CaptureVolume, plan.PerformerEnvelope);
        Assert.InRange(report.CoveredFraction, 0.0, 1.0);
        Assert.True(report.Score > 0);
    }

    [Fact]
    public void Camera_instance_computes_positive_pixels_per_cm()
    {
        var cam = new CameraInstance(
            "C01",
            new Vec3d(4.2, 0, 1.55),
            new Vec3d(0, 0, 1.1),
            CameraBody.RedKomodoX(),
            Lens.Rokinon24mm(),
            RecordingMode.KomodoX6K48Mq(),
            false,
            new MountBinding("m1", "stand", 0, "socket"));
        Assert.True(cam.HorizontalFovDegrees > 0);
        Assert.True(cam.VerticalFovDegrees > 0);
        Assert.True(cam.ApproxPixelsPerCmAtAim > 0);
    }

    [Fact]
    public void Sparse_layout_produces_at_least_one_recommendation()
    {
        var body = CameraBody.RedKomodoX();
        var lens = Lens.Rokinon24mm();
        var mode = RecordingMode.KomodoX6K24Lq();
        var cameras = new List<CameraInstance>();
        for (var i = 0; i < 4; i++)
        {
            var angle = i * (System.Math.PI / 2.0);
            cameras.Add(new CameraInstance($"C{i+1:00}", new Vec3d(System.Math.Cos(angle) * 4.5, System.Math.Sin(angle) * 4.5, 1.6), new Vec3d(0,0,1.1), body, lens, mode, false, new MountBinding("m", "stand", 0, "socket")));
        }

        var report = new CoverageScorer().Score(cameras, new CaptureVolume(new Vec3d(0,0,1.1), 1.45, 2.4), PerformerEnvelope.SingleHumanDefault());
        Assert.NotEmpty(report.Recommendations);
    }
}
