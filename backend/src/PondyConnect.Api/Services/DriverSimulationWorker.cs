namespace PondyConnect.Api.Services;

using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// Virtual Driver Swarm — generates 50 concurrent synthetic Captains running
/// on interpolated polylines across Pondicherry. Each simulated client dispatches
/// location updates every 5 seconds with ±1.5s jitter to evaluate database write
/// locks and in-memory location store latency under load.
///
/// Gated behind the "Simulation:Enabled" configuration flag. Only runs in
/// test/staging environments — never in production.
/// </summary>
public sealed class DriverSimulationWorker : BackgroundService
{
    /// <summary>Number of virtual captains to simulate.</summary>
    public const int VirtualDriverCount = 50;

    /// <summary>Base interval between telemetry pings (5 seconds).</summary>
    private static readonly TimeSpan BasePingInterval = TimeSpan.FromSeconds(5);

    /// <summary>Jitter range (±1.5 seconds) applied to each ping interval.</summary>
    private const double JitterSeconds = 1.5;

    /// <summary>Pondicherry city center (Rock Beach).</summary>
    private const double CityCenterLat = 11.9356;
    private const double CityCenterLng = 79.8301;

    /// <summary>Radius of the simulation area (km).</summary>
    private const double SimulationRadiusKm = 6.0;

    private readonly DriverLocationStore _locationStore;
    private readonly ILogger<DriverSimulationWorker> _logger;
    private readonly bool _isEnabled;
    private readonly List<VirtualDriver> _virtualDrivers = new();

    public DriverSimulationWorker(
        DriverLocationStore locationStore,
        IConfiguration configuration,
        ILogger<DriverSimulationWorker> logger)
    {
        _locationStore = locationStore;
        _logger = logger;
        _isEnabled = configuration.GetValue<bool>("Simulation:Enabled", false);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!_isEnabled)
        {
            _logger.LogInformation("DriverSimulationWorker: disabled (Simulation:Enabled=false)");
            return;
        }

        _logger.LogWarning(
            "DriverSimulationWorker: STARTING {Count} virtual captains with jittered telemetry",
            VirtualDriverCount);

        // Initialize virtual drivers with random starting positions
        var random = new Random(42); // Deterministic seed for reproducibility
        for (int i = 0; i < VirtualDriverCount; i++)
        {
            var driverId = Guid.NewGuid();
            var vehicleType = GetRandomVehicleType(random, i);
            var rating = 4.0 + random.NextDouble(); // 4.0–5.0
            var acceptanceRate = 0.7 + random.NextDouble() * 0.3; // 0.7–1.0

            // Generate a random route (polyline) within the simulation area
            var route = GenerateRandomRoute(random, 8 + random.Next(4, 10));

            var driver = new VirtualDriver(
                driverId,
                vehicleType,
                rating,
                acceptanceRate,
                route,
                routeProgress: 0.0,
                nextPingDelay: GetJitteredInterval(random));

            _virtualDrivers.Add(driver);

            // Register in the location store
            _locationStore.RegisterDriver(driverId, vehicleType, rating, acceptanceRate);
            _locationStore.SetOnline(driverId, isOnline: true);
            _locationStore.Update(driverId, route[0].Latitude, route[0].Longitude);
        }

        _logger.LogInformation(
            "DriverSimulationWorker: {Count} virtual captains registered and online",
            _virtualDrivers.Count);

        // Run telemetry loop — each driver pings independently with jitter
        while (!stoppingToken.IsCancellationRequested)
        {
            var now = DateTimeOffset.UtcNow;
            var tasks = new List<Task>(VirtualDriverCount);

            foreach (var driver in _virtualDrivers)
            {
                if (now >= driver.NextPingTime)
                {
                    tasks.Add(Task.Run(() => PingDriver(driver, random, stoppingToken), stoppingToken));
                }
            }

            if (tasks.Count > 0)
                await Task.WhenAll(tasks);

            // Short sleep before checking which drivers need to ping next
            await Task.Delay(500, stoppingToken);
        }

        // Cleanup: mark all virtual drivers offline
        foreach (var driver in _virtualDrivers)
        {
            _locationStore.SetOnline(driver.Id, isOnline: false);
            _locationStore.Remove(driver.Id);
        }

        _logger.LogInformation("DriverSimulationWorker: stopped, all virtual drivers offline");
    }

    private void PingDriver(VirtualDriver driver, Random random, CancellationToken ct)
    {
        try
        {
            // Advance along the route
            driver.RouteProgress += 0.05 + random.NextDouble() * 0.05; // 5–10% per ping

            // Loop back to start if route completed
            if (driver.RouteProgress >= 1.0)
                driver.RouteProgress -= 1.0;

            // Interpolate position along the polyline
            var (lat, lng) = InterpolatePosition(driver.Route, driver.RouteProgress);

            // Add small GPS noise (±0.0002 degrees ≈ ±22 meters)
            lat += (random.NextDouble() - 0.5) * 0.0004;
            lng += (random.NextDouble() - 0.5) * 0.0004;

            // Calculate heading (bearing to next point)
            var heading = CalculateHeading(driver.Route, driver.RouteProgress);

            // Update the in-memory location store
            _locationStore.Update(driver.Id, lat, lng, heading);

            // Schedule next ping with jitter
            driver.NextPingTime = DateTimeOffset.UtcNow + GetJitteredInterval(random);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "DriverSimulationWorker: error pinging virtual driver {DriverId}", driver.Id);
        }
    }

    /// <summary>
    /// Generates a random route (polyline) within the simulation area.
    /// Returns a list of waypoints forming a loop.
    /// </summary>
    private static List<GeoLocation> GenerateRandomRoute(Random random, int waypointCount)
    {
        var route = new List<GeoLocation>(waypointCount);

        for (int i = 0; i < waypointCount; i++)
        {
            // Random point within SimulationRadiusKm of city center
            var angle = random.NextDouble() * 2 * Math.PI;
            var distance = random.NextDouble() * SimulationRadiusKm;

            var lat = CityCenterLat + (distance / 111.0) * Math.Sin(angle);
            var lng = CityCenterLng + (distance / (111.0 * Math.Cos(CityCenterLat * Math.PI / 180.0))) * Math.Cos(angle);

            route.Add(GeoLocation.Create(lat, lng));
        }

        // Close the loop (last point connects back to first)
        return route;
    }

    /// <summary>
    /// Interpolates a position along a polyline at a given progress (0.0–1.0).
    /// </summary>
    private static (double Lat, double Lng) InterpolatePosition(List<GeoLocation> route, double progress)
    {
        if (route.Count == 0)
            return (CityCenterLat, CityCenterLng);

        if (route.Count == 1)
            return (route[0].Latitude, route[0].Longitude);

        // Map progress [0,1] to segment index
        var totalSegments = route.Count; // Loop: last→first
        var segmentProgress = progress * totalSegments;
        var segmentIndex = (int)segmentProgress;
        var segmentFraction = segmentProgress - segmentIndex;

        var from = route[segmentIndex % route.Count];
        var to = route[(segmentIndex + 1) % route.Count];

        var lat = from.Latitude + (to.Latitude - from.Latitude) * segmentFraction;
        var lng = from.Longitude + (to.Longitude - from.Longitude) * segmentFraction;

        return (lat, lng);
    }

    /// <summary>
    /// Calculates the heading (bearing) at a given progress along the route.
    /// </summary>
    private static double CalculateHeading(List<GeoLocation> route, double progress)
    {
        if (route.Count < 2)
            return 0;

        var totalSegments = route.Count;
        var segmentProgress = progress * totalSegments;
        var segmentIndex = (int)segmentProgress;

        var from = route[segmentIndex % route.Count];
        var to = route[(segmentIndex + 1) % route.Count];

        var dLng = to.Longitude - from.Longitude;
        var y = Math.Sin(dLng * Math.PI / 180) * Math.Cos(to.Latitude * Math.PI / 180);
        var x = Math.Cos(from.Latitude * Math.PI / 180) * Math.Sin(to.Latitude * Math.PI / 180) -
                Math.Sin(from.Latitude * Math.PI / 180) * Math.Cos(to.Latitude * Math.PI / 180) * Math.Cos(dLng * Math.PI / 180);
        var heading = Math.Atan2(y, x) * 180 / Math.PI;
        return (heading + 360) % 360;
    }

    /// <summary>
    /// Returns a jittered interval: 5s ± 1.5s (3.5s to 6.5s).
    /// </summary>
    private static TimeSpan GetJitteredInterval(Random random)
    {
        var jitter = (random.NextDouble() - 0.5) * 2 * JitterSeconds;
        return BasePingInterval + TimeSpan.FromSeconds(jitter);
    }

    private static VehicleType GetRandomVehicleType(Random random, int index)
    {
        // Distribute: 60% bike, 25% auto, 15% car
        var pct = random.NextDouble();
        if (pct < 0.60) return VehicleType.Bike;
        if (pct < 0.85) return VehicleType.Auto;
        return VehicleType.Car;
    }

    /// <summary>
    /// Represents a single virtual captain with its route and state.
    /// </summary>
    private sealed class VirtualDriver
    {
        public Guid Id { get; }
        public VehicleType VehicleType { get; }
        public double Rating { get; }
        public double AcceptanceRate { get; }
        public List<GeoLocation> Route { get; }
        public double RouteProgress { get; set; }
        public DateTimeOffset NextPingTime { get; set; }

        public VirtualDriver(
            Guid id,
            VehicleType vehicleType,
            double rating,
            double acceptanceRate,
            List<GeoLocation> route,
            double routeProgress,
            TimeSpan nextPingDelay)
        {
            Id = id;
            VehicleType = vehicleType;
            Rating = rating;
            AcceptanceRate = acceptanceRate;
            Route = route;
            RouteProgress = routeProgress;
            NextPingTime = DateTimeOffset.UtcNow + nextPingDelay;
        }
    }
}
