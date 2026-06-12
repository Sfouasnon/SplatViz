using SplatViz.Core.Cameras;
using SplatViz.Core.Math;
using SplatViz.Core.Mounts;

namespace SplatViz.Core.Scene;

public static class SampleLayoutFactory
{
    public static IReadOnlyList<LayoutPlan> BuildDefaultThreeTierPlans()
    {
        var room = Room.NozStage1();
        var volume = new CaptureVolume(new Vec3d(0, 0, 1.1), 1.45, 2.4);
        var performer = PerformerEnvelope.SingleHumanDefault();
        var body = CameraBody.RedKomodoX();
        var lens = Lens.Rokinon24mm();

        return new[]
        {
            BuildPlan("Lean 16-Camera Preflight", LayoutTier.Lean, 16, 3.8, RecordingMode.KomodoX6K24Lq(), room, volume, performer, body, lens, "Fast synthetic preflight layout for a laptop workflow."),
            BuildPlan("Recommended 24-Camera Two-Tier Ring", LayoutTier.Recommended, 24, 4.2, RecordingMode.KomodoX6K48Mq(), room, volume, performer, body, lens, "Balanced layout intended for most 4DGS preproduction decisions."),
            BuildPlan("Premium 36-Camera Dense Ring", LayoutTier.Premium, 36, 3.81, RecordingMode.KomodoX6K16x9_60Hq(), room, volume, performer, body, lens, "Default NOZ Stage #1 production array: 36 KOMODO-X cameras at roughly 12–13 ft with 24mm Rokinon lenses.")
        };
    }

    private static LayoutPlan BuildPlan(string name, LayoutTier tier, int cameraCount, double radiusM, RecordingMode mode, Room room, CaptureVolume volume, PerformerEnvelope performer, CameraBody body, Lens lens, string intent)
    {
        var trusses = new List<BoxTruss>
        {
            new("truss_main", new Vec3d(-3.5, 0, 3.2), new Vec3d(3.5, 0, 3.2), 290, 250, new [] {"front", "rear", "bottom"})
        };
        var stands = new List<Stand>
        {
            new("stand_a", new Vec3d(-2.6, -2.8, 0), 1200, 2600),
            new("stand_b", new Vec3d(2.6, -2.8, 0), 1200, 2600)
        };

        var cameras = new List<CameraInstance>();
        for (var i = 0; i < cameraCount; i++)
        {
            var t = i / (double)cameraCount;
            var angle = t * System.Math.PI * 2.0;
            var z = (i % 2 == 0) ? 1.55 : 2.45;
            var pos = new Vec3d(System.Math.Cos(angle) * radiusM, System.Math.Sin(angle) * radiusM, z);
            var portrait = i % 4 == 0 || i % 7 == 0;

            MountBinding mount = i switch
            {
                < 10 => new($"truss_main_slot_{i + 1:00}", "box_truss", 0, (i % 2 == 0) ? "front" : "bottom"),
                < 13 => new($"stand_a_head_{i - 9:00}", "stand", 0, "socket"),
                < 16 => new($"stand_b_head_{i - 12:00}", "stand", 0, "socket"),
                _ => new($"virtual_mount_{i + 1:00}", "unassigned", 0, "none")
            };

            cameras.Add(new CameraInstance($"C{i + 1:00}", pos, volume.CenterM, body, lens, mode, portrait, mount));
        }

        return new LayoutPlan(name, tier, room, volume, performer, cameras, trusses, stands, intent);
    }
}
