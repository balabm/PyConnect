namespace PondyConnect.Application.Common.Geo;

public static class GeoCalculator
{
    private const double EarthRadiusMeters = 6371000.0;
    private const double EarthRadiusKm = 6371.0;

    public static double HaversineDistance(double lat1, double lng1, double lat2, double lng2)
    {
        var dLat = ToRadians(lat2 - lat1);
        var dLon = ToRadians(lng2 - lng1);

        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
              + Math.Cos(ToRadians(lat1)) * Math.Cos(ToRadians(lat2))
              * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);

        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return EarthRadiusMeters * c;
    }

    public static double Bearing(double lat1, double lng1, double lat2, double lng2)
    {
        var phi1 = ToRadians(lat1);
        var phi2 = ToRadians(lat2);
        var deltaLambda = ToRadians(lng2 - lng1);

        var x = Math.Sin(deltaLambda) * Math.Cos(phi2);
        var y = Math.Cos(phi1) * Math.Sin(phi2)
              - Math.Sin(phi1) * Math.Cos(phi2) * Math.Cos(deltaLambda);

        var bearing = ToDegrees(Math.Atan2(x, y));
        return (bearing + 360.0) % 360.0;
    }

    public static double AngleDifference(double b1, double b2)
    {
        var diff = Math.Abs((b1 - b2 + 360.0) % 360.0);
        if (diff > 180.0)
            diff = 360.0 - diff;
        return diff;
    }

    private static double ToRadians(double degrees) => degrees * Math.PI / 180.0;
    private static double ToDegrees(double radians) => radians * 180.0 / Math.PI;
}
