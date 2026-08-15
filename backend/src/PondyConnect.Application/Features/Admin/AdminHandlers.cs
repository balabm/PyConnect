namespace PondyConnect.Application.Features.Admin;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using System.IO;

public sealed record ForceSoldOutCommand(Guid VenueId, bool SoldOut) : IRequest<Unit>;

public sealed class ForceSoldOutHandler : IRequestHandler<ForceSoldOutCommand, Unit>
{
    private readonly IApplicationDbContext _context;

    public ForceSoldOutHandler(IApplicationDbContext context) => _context = context;

    public async Task<Unit> Handle(ForceSoldOutCommand request, CancellationToken cancellationToken)
    {
        var venue = await _context.Venues.FirstOrDefaultAsync(v => v.Id == request.VenueId, cancellationToken)
            ?? throw new InvalidOperationException("Venue not found.");

        if (request.SoldOut)
            venue.ForceSoldOut();
        else
            venue.Reopen();

        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

public sealed record SetSurgeModeCommand(SurgeMode Mode) : IRequest<SurgeModeResponse>;

public sealed record SurgeModeResponse(SurgeMode Mode, decimal FeeMultiplier, string Label);

public sealed class SetSurgeModeHandler : IRequestHandler<SetSurgeModeCommand, SurgeModeResponse>
{
    public Task<SurgeModeResponse> Handle(SetSurgeModeCommand request, CancellationToken cancellationToken)
    {
        var multiplier = request.Mode switch
        {
            SurgeMode.Normal => 1.0m,
            SurgeMode.Monsoon => 1.2m,
            SurgeMode.FestivalSurge => 1.2m,
            _ => 1.0m
        };

        var label = request.Mode switch
        {
            SurgeMode.Normal => "Normal Operations",
            SurgeMode.Monsoon => "Monsoon Mode (+20% fees)",
            SurgeMode.FestivalSurge => "Festival Surge (+20% fees)",
            _ => "Normal"
        };

        SurgeState.CurrentMode = request.Mode;
        SurgeState.FeeMultiplier = multiplier;

        return Task.FromResult(new SurgeModeResponse(request.Mode, multiplier, label));
    }
}

public sealed record GetSosEventsQuery() : IRequest<IReadOnlyList<SosEventResponse>>;

public sealed record SosEventResponse(
    Guid Id,
    Guid UserId,
    string UserName,
    double Latitude,
    double Longitude,
    string Message,
    DateTimeOffset CreatedAt,
    bool IsResolved);

public sealed class GetSosEventsHandler : IRequestHandler<GetSosEventsQuery, IReadOnlyList<SosEventResponse>>
{
    private readonly IApplicationDbContext _context;

    public GetSosEventsHandler(IApplicationDbContext context) => _context = context;

    public async Task<IReadOnlyList<SosEventResponse>> Handle(GetSosEventsQuery request, CancellationToken cancellationToken)
    {
        // Query real SOS alerts from the database, joining with users for names.
        var alerts = await (
            from a in _context.SosAlerts
            join u in _context.Users on a.UserId equals u.Id into users
            from u in users.DefaultIfEmpty()
            orderby a.CreatedAt descending
            select new SosEventResponse(
                a.Id,
                a.UserId,
                u != null ? u.Name : "Unknown",
                a.Location != null ? a.Location.Latitude : 0,
                a.Location != null ? a.Location.Longitude : 0,
                "SOS Alert",
                a.CreatedAt,
                a.Status == Domain.Enums.SosStatus.Resolved))
            .Take(50)
            .ToListAsync(cancellationToken);

        return alerts;
    }
}

public enum SurgeMode
{
    Normal = 0,
    Monsoon = 1,
    FestivalSurge = 2
}

public static class SurgeState
{
    private static readonly object _lock = new();
    private static SurgeMode _currentMode = SurgeMode.Normal;
    private static decimal _feeMultiplier = 1.0m;
    private static string _persistPath = Path.Combine(AppContext.BaseDirectory, "surge-state.json");
    private static bool _loaded;

    public static SurgeMode CurrentMode
    {
        get { EnsureLoaded(); return _currentMode; }
        set { _currentMode = value; Persist(); }
    }

    public static decimal FeeMultiplier
    {
        get { EnsureLoaded(); return _feeMultiplier; }
        set { _feeMultiplier = value; Persist(); }
    }

    private static void EnsureLoaded()
    {
        if (_loaded) return;
        lock (_lock)
        {
            if (_loaded) return;
            try
            {
                if (File.Exists(_persistPath))
                {
                    var json = File.ReadAllText(_persistPath);
                    var parts = json.Split('|');
                    if (parts.Length == 2 && Enum.TryParse<SurgeMode>(parts[0], out var mode))
                    {
                        _currentMode = mode;
                        _feeMultiplier = decimal.TryParse(parts[1], out var m) ? m : 1.0m;
                    }
                }
            }
            catch { /* ignore file errors, use defaults */ }
            _loaded = true;
        }
    }

    private static void Persist()
    {
        try
        {
            File.WriteAllText(_persistPath, $"{_currentMode}|{_feeMultiplier}");
        }
        catch { /* ignore file errors */ }
    }
}

// === Vendor Onboarding ===

public sealed record OnboardVendorCommand(
    string Name,
    string ContactPhone,
    string Category,
    string? CuisineType = null,
    string? Description = null,
    decimal? DeliveryFee = null,
    int? PrepTimeMinutes = null) : IRequest<OnboardVendorResponse>;

public sealed record OnboardVendorResponse(
    Guid VendorId,
    Guid UserId,
    string Name,
    string ContactPhone,
    string Category,
    bool IsApproved,
    string Message);

public sealed class OnboardVendorHandler : IRequestHandler<OnboardVendorCommand, OnboardVendorResponse>
{
    private readonly IApplicationDbContext _context;

    public OnboardVendorHandler(IApplicationDbContext context) => _context = context;

    public async Task<OnboardVendorResponse> Handle(OnboardVendorCommand request, CancellationToken cancellationToken)
    {
        // Parse category
        if (!Enum.TryParse<VendorCategory>(request.Category, true, out var category))
            throw new InvalidOperationException($"Invalid vendor category: {request.Category}");

        // Check if a user with this phone already exists
        var existingUser = await _context.Users
            .FirstOrDefaultAsync(u => u.Phone == request.ContactPhone, cancellationToken);

        User user;
        if (existingUser != null)
        {
            // Upgrade existing user to Vendor role if they're a Tourist
            if (existingUser.Role == UserRole.Tourist)
            {
                existingUser.ChangeRole(UserRole.Vendor);
            }
            user = existingUser;
        }
        else
        {
            user = User.Create(request.Name, request.ContactPhone, UserRole.Vendor);
            _context.Users.Add(user);
        }

        // Check if a vendor with this phone already exists
        var existingVendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.ContactPhone == request.ContactPhone, cancellationToken);

        if (existingVendor != null)
            throw new InvalidOperationException($"A vendor with phone {request.ContactPhone} already exists.");

        // Create the vendor profile
        var vendor = Vendor.Create(
            request.Name,
            category,
            contactPhone: request.ContactPhone,
            cuisineType: request.CuisineType,
            description: request.Description,
            deliveryFee: request.DeliveryFee,
            prepTimeMinutes: request.PrepTimeMinutes);

        vendor.Approve(); // Admin-onboarded vendors are pre-approved

        _context.Vendors.Add(vendor);
        await _context.SaveChangesAsync(cancellationToken);

        return new OnboardVendorResponse(
            vendor.Id,
            user.Id,
            vendor.Name,
            vendor.ContactPhone ?? request.ContactPhone,
            vendor.Category.ToString(),
            vendor.IsApproved,
            "Vendor onboarded successfully. They can now log in with their phone number via the Vendor app.");
    }
}

// === List All Vendors (Admin) ===

public sealed record ListAllVendorsQuery(bool? IsApproved = null, string? Category = null) : IRequest<IReadOnlyList<VendorSummaryResponse>>;

public sealed record VendorSummaryResponse(
    Guid Id,
    string Name,
    string? ContactPhone,
    string Category,
    bool IsApproved,
    bool IsActive,
    string? CuisineType,
    double? Rating,
    string? FssaiNumber,
    string? GstNumber,
    string? PanNumber,
    string? FssaiDocUrl,
    string? GstDocUrl,
    string? PanDocUrl);

public sealed class ListAllVendorsHandler : IRequestHandler<ListAllVendorsQuery, IReadOnlyList<VendorSummaryResponse>>
{
    private readonly IApplicationDbContext _context;

    public ListAllVendorsHandler(IApplicationDbContext context) => _context = context;

    public async Task<IReadOnlyList<VendorSummaryResponse>> Handle(ListAllVendorsQuery request, CancellationToken cancellationToken)
    {
        var query = _context.Vendors.AsNoTracking();

        if (request.IsApproved.HasValue)
            query = query.Where(v => v.IsApproved == request.IsApproved.Value);

        if (!string.IsNullOrWhiteSpace(request.Category)
            && Enum.TryParse<VendorCategory>(request.Category, ignoreCase: true, out var category))
            query = query.Where(v => v.Category == category);

        return await query
            .OrderByDescending(v => v.IsApproved)
            .ThenBy(v => v.Name)
            .Select(v => new VendorSummaryResponse(
                v.Id,
                v.Name,
                v.ContactPhone,
                v.Category.ToString(),
                v.IsApproved,
                v.IsActive,
                v.CuisineType,
                v.Rating,
                v.FssaiNumber,
                v.GstNumber,
                v.PanNumber,
                v.FssaiDocUrl,
                v.GstDocUrl,
                v.PanDocUrl))
            .ToListAsync(cancellationToken);
    }
}
