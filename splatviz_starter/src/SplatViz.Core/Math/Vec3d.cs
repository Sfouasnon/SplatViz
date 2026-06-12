namespace SplatViz.Core.Math;

public readonly record struct Vec3d(double X, double Y, double Z)
{
    public static Vec3d operator +(Vec3d a, Vec3d b) => new(a.X + b.X, a.Y + b.Y, a.Z + b.Z);
    public static Vec3d operator -(Vec3d a, Vec3d b) => new(a.X - b.X, a.Y - b.Y, a.Z - b.Z);
    public static Vec3d operator *(Vec3d a, double s) => new(a.X * s, a.Y * s, a.Z * s);
    public double Length => System.Math.Sqrt((X * X) + (Y * Y) + (Z * Z));
    public double LengthXY => System.Math.Sqrt((X * X) + (Y * Y));
    public Vec3d Normalized() => Length == 0 ? this : new(X / Length, Y / Length, Z / Length);
    public Vec3d ToMillimeters() => new(X * 1000.0, Y * 1000.0, Z * 1000.0);
    public static double Distance(Vec3d a, Vec3d b) => (a - b).Length;
}
