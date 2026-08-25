namespace PondyConnect.Application.Features.GeoFence;

using Microsoft.Extensions.Options;
using PondyConnect.Domain.ValueObjects;

public sealed class ServiceAreaOptions
{
    public double CenterLatitude { get; set; } = 11.9356;
    public double CenterLongitude { get; set; } = 79.8301;
    public double RadiusKm { get; set; } = 50.0;
}

public sealed class ServiceAreaValidator
{
    private readonly ServiceAreaOptions _options;

    public ServiceAreaValidator(IOptions<ServiceAreaOptions> options)
    {
        _options = options.Value;
    }

    public (bool IsWithinZone, double DistanceKm) ValidateLocation(GeoLocation location)
    {
        var center = GeoLocation.Create(_options.CenterLatitude, _options.CenterLongitude);
        var distance = location.DistanceKm(center);
        return (distance <= _options.RadiusKm, distance);
    }

    public void EnsureWithinZone(GeoLocation location)
    {
        var (isWithin, distance) = ValidateLocation(location);
        if (!isWithin)
            throw new ServiceAreaException(distance, _options.RadiusKm);
    }

    public GeoLocation Center => GeoLocation.Create(_options.CenterLatitude, _options.CenterLongitude);
    public double RadiusKm => _options.RadiusKm;
}

public sealed class ServiceAreaException : Exception
{
    public double DistanceKm { get; }
    public double RadiusKm { get; }

    public ServiceAreaException(double distanceKm, double radiusKm)
        : base($"Service is currently available within {radiusKm:F0}km of Pondicherry. " +
               $"You are {distanceKm:F1}km away.")
    {
        DistanceKm = distanceKm;
        RadiusKm = radiusKm;
    }
}
