using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;

namespace PondyConnect.Infrastructure.Services;

/// <summary>
/// OSRM-based routing service implementation. Calls an OSRM server to compute
/// road distance, duration, and route geometry. The default URL points to the
/// public OSRM demo server; for production, configure a self-hosted OSRM instance
/// with India OSM data via the "Osrm:BaseUrl" configuration key.
/// </summary>
public sealed class OsrmRoutingService : IRoutingService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<OsrmRoutingService> _logger;

    public OsrmRoutingService(HttpClient httpClient, ILogger<OsrmRoutingService> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task<RouteInfo?> GetRouteAsync(
        double startLat, double startLng,
        double endLat, double endLng,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // OSRM expects coordinates as longitude,latitude
            var coords = $"{startLng:F6},{startLat:F6};{endLng:F6},{endLat:F6}";
            var url = $"/route/v1/driving/{coords}?overview=full&geometries=geojson&steps=false";

            var response = await _httpClient.GetAsync(url, cancellationToken);
            response.EnsureSuccessStatusCode();

            var data = await response.Content.ReadFromJsonAsync<OsrmResponse>(cancellationToken);
            if (data?.Routes is null || data.Routes.Count == 0)
                return null;

            var route = data.Routes[0];
            var points = new List<(double Lat, double Lng)>();

            if (route.Geometry?.Coordinates is not null)
            {
                foreach (var coord in route.Geometry.Coordinates)
                {
                    if (coord.Count >= 2)
                        points.Add((coord[1], coord[0])); // GeoJSON is [lng, lat]
                }
            }

            return new RouteInfo(
                DistanceKm: route.Distance / 1000.0,
                DurationMin: (int)Math.Round(route.Duration / 60.0),
                Points: points);
        }
        catch (Exception ex)
        {
#pragma warning disable CA1848
            _logger.LogWarning("OSRM routing failed for {StartLat},{StartLng} -> {EndLat},{EndLng}: {Message}",
                startLat, startLng, endLat, endLng, ex.Message);
#pragma warning restore CA1848
            return null;
        }
    }
}

// --- OSRM JSON response models ---

file sealed class OsrmResponse
{
    [JsonPropertyName("code")]
    public string? Code { get; set; }

    [JsonPropertyName("routes")]
    public List<OsrmRoute>? Routes { get; set; }
}

file sealed class OsrmRoute
{
    [JsonPropertyName("distance")]
    public double Distance { get; set; } // meters

    [JsonPropertyName("duration")]
    public double Duration { get; set; } // seconds

    [JsonPropertyName("geometry")]
    public OsrmGeometry? Geometry { get; set; }
}

file sealed class OsrmGeometry
{
    [JsonPropertyName("type")]
    public string? Type { get; set; }

    [JsonPropertyName("coordinates")]
    public List<List<double>>? Coordinates { get; set; }
}
