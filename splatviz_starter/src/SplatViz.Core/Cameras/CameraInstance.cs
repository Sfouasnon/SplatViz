using SplatViz.Core.Math;
using SplatViz.Core.Mounts;

namespace SplatViz.Core.Cameras;

public sealed record CameraInstance(
    string Id,
    Vec3d PositionM,
    Vec3d AimTargetM,
    CameraBody Body,
    Lens Lens,
    RecordingMode RecordingMode,
    bool PortraitRoll,
    MountBinding Mount)
{
    public double DistanceToAimM => Vec3d.Distance(PositionM, AimTargetM);

    public double HorizontalFovDegrees
    {
        get
        {
            var sensorMm = PortraitRoll ? Body.SensorHeightMm : Body.SensorWidthMm;
            return 2.0 * System.Math.Atan(sensorMm / (2.0 * Lens.FocalLengthMm)) * 180.0 / System.Math.PI;
        }
    }

    public double VerticalFovDegrees
    {
        get
        {
            var sensorMm = PortraitRoll ? Body.SensorWidthMm : Body.SensorHeightMm;
            return 2.0 * System.Math.Atan(sensorMm / (2.0 * Lens.FocalLengthMm)) * 180.0 / System.Math.PI;
        }
    }

    public double ApproxPixelsPerCmAtAim
    {
        get
        {
            var coverageWidthM = 2.0 * DistanceToAimM * System.Math.Tan(HorizontalFovDegrees * System.Math.PI / 360.0);
            var px = PortraitRoll ? RecordingMode.HeightPx : RecordingMode.WidthPx;
            return px / (coverageWidthM * 100.0);
        }
    }
}
