using NetTopologySuite.Geometries;

namespace PondyConnect.Domain.ValueObjects;

public sealed record GeoLocation(double Latitude, double Longitude)
{
    public static GeoLocation Zero => new(0, 0);

    public double DistanceKm(GeoLocation other)
    {
        const double earthRadiusKm = 6371.0;
        var dLat = (other.Latitude - Latitude) * Math.PI / 180.0;
        var dLon = (other.Longitude - Longitude) * Math.PI / 180.0;
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(Latitude * Math.PI / 180.0) * Math.Cos(other.Latitude * Math.PI / 180.0) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        return earthRadiusKm * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
    }

    public static GeoLocation Create(double latitude, double longitude)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(latitude, -90.0, nameof(latitude));
        ArgumentOutOfRangeException.ThrowIfGreaterThan(latitude, 90.0, nameof(latitude));
        ArgumentOutOfRangeException.ThrowIfLessThan(longitude, -180.0, nameof(longitude));
        ArgumentOutOfRangeException.ThrowIfGreaterThan(longitude, 180.0, nameof(longitude));
        return new GeoLocation(latitude, longitude);
    }

    public Point ToPoint(int srid = 4326)
        => new Point(Longitude, Latitude) { SRID = srid };

    public static GeoLocation FromPoint(Point point)
        => new(point.Y, point.X);
}