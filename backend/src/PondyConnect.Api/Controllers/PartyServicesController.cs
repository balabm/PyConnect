namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

/// <summary>
/// Party services marketplace endpoints. Lets vendors list services
/// (DJ, bartender, catering, sound system, etc.) and consumers browse
/// and book them.
/// </summary>
[ApiController]
[Route("api/party-services")]
[Authorize]
public sealed class PartyServicesController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public PartyServicesController(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    // ── Consumer: Browse ──

    /// <summary>
    /// Browse available party services with optional category filter.
    /// </summary>
    [HttpGet("browse")]
    [ProducesResponseType(typeof(IReadOnlyList<PartyServiceBrowseDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<PartyServiceBrowseDto>>> Browse(
        [FromQuery] string? category, CancellationToken ct)
    {
        var query = _context.PartyServices.AsNoTracking()
            .Where(s => s.IsAvailable);

        if (!string.IsNullOrWhiteSpace(category) && Enum.TryParse<PartyServiceCategory>(category, true, out var cat))
            query = query.Where(s => s.Category == cat);

        var services = await query
            .OrderByDescending(s => s.CreatedAt)
            .Join(_context.Vendors.AsNoTracking(),
                s => s.VendorId,
                v => v.Id,
                (s, v) => new PartyServiceBrowseDto(
                    s.Id,
                    s.VendorId,
                    v.Name,
                    s.Category.ToString(),
                    s.Title,
                    s.Description,
                    s.BasePrice,
                    s.PricingUnit,
                    s.MinimumBooking,
                    s.ImageUrl,
                    s.Tags,
                    s.ServiceArea,
                    v.IsApproved))
            .ToListAsync(ct);

        return Ok(services);
    }

    // ── Consumer: Book ──

    /// <summary>
    /// Create a booking request for a party service.
    /// </summary>
    [HttpPost("bookings")]
    [ProducesResponseType(typeof(CreateBookingResult), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<CreateBookingResult>> CreateBooking(
        [FromBody] CreatePartyServiceBookingRequest request, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        var service = await _context.PartyServices
            .FirstOrDefaultAsync(s => s.Id == request.ServiceId && s.IsAvailable, ct);
        if (service is null)
            return NotFound(new { Message = "Service not found or unavailable." });

        if (request.Quantity < service.MinimumBooking)
            return BadRequest(new { Message = $"Minimum booking is {service.MinimumBooking} {service.PricingUnit}." });

        var totalAmount = service.BasePrice * request.Quantity;

        var booking = PartyServiceBooking.Create(
            serviceId: service.Id,
            vendorId: service.VendorId,
            userId: userId.Value,
            eventDate: request.EventDate,
            quantity: request.Quantity,
            totalAmount: totalAmount,
            eventAddress: request.EventAddress,
            notes: request.Notes);

        _context.PartyServiceBookings.Add(booking);
        await _context.SaveChangesAsync(ct);

        return CreatedAtAction(nameof(GetMyBookings), new { id = booking.Id },
            new CreateBookingResult(booking.Id, totalAmount, null));
    }

    /// <summary>
    /// Confirm a booking after successful Razorpay payment.
    /// </summary>
    [HttpPost("bookings/{id:guid}/confirm")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> ConfirmBooking(
        Guid id, [FromBody] ConfirmBookingRequest request, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null) return Unauthorized();

        var booking = await _context.PartyServiceBookings
            .FirstOrDefaultAsync(b => b.Id == id && b.UserId == userId, ct);
        if (booking is null)
            return NotFound(new { Message = "Booking not found." });

        booking.RecordPayment(request.RazorpayOrderId, request.RazorpayPaymentId);
        booking.Confirm();
        await _context.SaveChangesAsync(ct);

        return Ok(new { Message = "Booking confirmed." });
    }

    /// <summary>
    /// Get the current user's party service bookings.
    /// </summary>
    [HttpGet("bookings/my")]
    [ProducesResponseType(typeof(IReadOnlyList<PartyServiceBookingDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<PartyServiceBookingDto>>> GetMyBookings(CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null) return Unauthorized();

        var bookings = await _context.PartyServiceBookings.AsNoTracking()
            .Where(b => b.UserId == userId)
            .OrderByDescending(b => b.CreatedAt)
            .Join(_context.PartyServices.AsNoTracking(),
                b => b.ServiceId,
                s => s.Id,
                (b, s) => new PartyServiceBookingDto(
                    b.Id,
                    s.Title,
                    s.Category.ToString(),
                    b.EventDate,
                    b.Quantity,
                    b.TotalAmount,
                    b.Status,
                    b.PaymentStatus,
                    b.EventAddress,
                    b.Notes))
            .ToListAsync(ct);

        return Ok(bookings);
    }

    // ── Vendor: Manage Listings ──

    /// <summary>
    /// List the current vendor's party service listings.
    /// </summary>
    [HttpGet("my")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(IReadOnlyList<PartyServiceBrowseDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<PartyServiceBrowseDto>>> GetMyServices(CancellationToken ct)
    {
        var vendorId = await ResolveVendorIdAsync(ct);
        if (vendorId is null)
            return NotFound(new { Message = "Vendor profile not found." });

        var services = await _context.PartyServices.AsNoTracking()
            .Where(s => s.VendorId == vendorId)
            .OrderByDescending(s => s.CreatedAt)
            .Join(_context.Vendors.AsNoTracking(),
                s => s.VendorId,
                v => v.Id,
                (s, v) => new PartyServiceBrowseDto(
                    s.Id, s.VendorId, v.Name, s.Category.ToString(),
                    s.Title, s.Description, s.BasePrice, s.PricingUnit,
                    s.MinimumBooking, s.ImageUrl, s.Tags, s.ServiceArea, v.IsApproved))
            .ToListAsync(ct);

        return Ok(services);
    }

    /// <summary>
    /// Create a new party service listing.
    /// </summary>
    [HttpPost]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(PartyServiceBrowseDto), StatusCodes.Status201Created)]
    public async Task<ActionResult<PartyServiceBrowseDto>> CreateService(
        [FromBody] CreatePartyServiceRequest request, CancellationToken ct)
    {
        var vendorId = await ResolveVendorIdAsync(ct);
        if (vendorId is null)
            return NotFound(new { Message = "Vendor profile not found." });

        if (!Enum.TryParse<PartyServiceCategory>(request.Category, true, out var category))
            return BadRequest(new { Message = "Invalid category." });

        var service = PartyService.Create(
            vendorId: vendorId.Value,
            category: category,
            title: request.Title,
            basePrice: request.BasePrice,
            pricingUnit: request.PricingUnit ?? "per event",
            minimumBooking: request.MinimumBooking ?? 1,
            description: request.Description,
            imageUrl: request.ImageUrl,
            tags: request.Tags,
            serviceArea: request.ServiceArea);

        _context.PartyServices.Add(service);
        await _context.SaveChangesAsync(ct);

        return CreatedAtAction(nameof(GetMyServices), new { id = service.Id },
            new PartyServiceBrowseDto(
                service.Id, service.VendorId, "", service.Category.ToString(),
                service.Title, service.Description, service.BasePrice,
                service.PricingUnit, service.MinimumBooking, service.ImageUrl,
                service.Tags, service.ServiceArea, true));
    }

    /// <summary>
    /// Update a party service listing.
    /// </summary>
    [HttpPut("{id:guid}")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateService(
        Guid id, [FromBody] UpdatePartyServiceRequest request, CancellationToken ct)
    {
        var vendorId = await ResolveVendorIdAsync(ct);
        if (vendorId is null) return NotFound();

        var service = await _context.PartyServices
            .FirstOrDefaultAsync(s => s.Id == id && s.VendorId == vendorId, ct);
        if (service is null) return NotFound();

        service.Update(
            basePrice: request.BasePrice,
            title: request.Title,
            description: request.Description,
            imageUrl: request.ImageUrl,
            tags: request.Tags,
            serviceArea: request.ServiceArea,
            isAvailable: request.IsAvailable,
            minimumBooking: request.MinimumBooking);

        await _context.SaveChangesAsync(ct);
        return NoContent();
    }

    /// <summary>
    /// Get bookings for the current vendor's services.
    /// </summary>
    [HttpGet("bookings/vendor")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(IReadOnlyList<VendorBookingDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<VendorBookingDto>>> GetVendorBookings(
        [FromQuery] string? status, CancellationToken ct)
    {
        var vendorId = await ResolveVendorIdAsync(ct);
        if (vendorId is null) return NotFound();

        var query = _context.PartyServiceBookings.AsNoTracking()
            .Where(b => b.VendorId == vendorId);

        if (!string.IsNullOrWhiteSpace(status))
            query = query.Where(b => b.Status == status);

        var bookings = await query
            .OrderByDescending(b => b.CreatedAt)
            .Join(_context.PartyServices.AsNoTracking(),
                b => b.ServiceId,
                s => s.Id,
                (b, s) => new VendorBookingDto(
                    b.Id, s.Title, s.Category.ToString(),
                    b.EventDate, b.Quantity, b.TotalAmount,
                    b.Status, b.PaymentStatus, b.Notes, b.CreatedAt))
            .ToListAsync(ct);

        return Ok(bookings);
    }

    /// <summary>
    /// Update a booking status (confirm, complete, cancel).
    /// </summary>
    [HttpPut("bookings/{id:guid}/status")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateBookingStatus(
        Guid id, [FromBody] UpdateBookingStatusRequest request, CancellationToken ct)
    {
        var vendorId = await ResolveVendorIdAsync(ct);
        if (vendorId is null) return NotFound();

        var booking = await _context.PartyServiceBookings
            .FirstOrDefaultAsync(b => b.Id == id && b.VendorId == vendorId, ct);
        if (booking is null) return NotFound();

        switch (request.Status.ToLowerInvariant())
        {
            case "confirmed": booking.Confirm(); break;
            case "completed": booking.Complete(); break;
            case "cancelled": booking.Cancel(); break;
            default: return BadRequest(new { Message = "Invalid status. Use: confirmed, completed, cancelled." });
        }

        await _context.SaveChangesAsync(ct);
        return Ok(new { Message = "Status updated." });
    }

    // ── Helpers ──

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken ct)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone)) return null;
        return await _context.Vendors.AsNoTracking()
            .Where(v => v.ContactPhone == phone)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(ct);
    }
}

// ── DTOs ──

public sealed record PartyServiceBrowseDto(
    Guid Id,
    Guid VendorId,
    string VendorName,
    string Category,
    string Title,
    string? Description,
    decimal BasePrice,
    string PricingUnit,
    int MinimumBooking,
    string? ImageUrl,
    string? Tags,
    string? ServiceArea,
    bool IsApproved);

public sealed record CreatePartyServiceRequest(
    string Title,
    string Category,
    decimal BasePrice,
    string? PricingUnit = null,
    int? MinimumBooking = null,
    string? Description = null,
    string? ImageUrl = null,
    string? Tags = null,
    string? ServiceArea = null);

public sealed record UpdatePartyServiceRequest(
    decimal? BasePrice,
    string? Title,
    string? Description,
    string? ImageUrl,
    string? Tags,
    string? ServiceArea,
    bool? IsAvailable,
    int? MinimumBooking);

public sealed record CreatePartyServiceBookingRequest(
    Guid ServiceId,
    DateTimeOffset EventDate,
    int Quantity,
    string? EventAddress = null,
    string? Notes = null);

public sealed record ConfirmBookingRequest(
    string RazorpayOrderId,
    string RazorpayPaymentId);

public sealed record CreateBookingResult(
    Guid BookingId,
    decimal TotalAmount,
    string? RazorpayOrderId);

public sealed record PartyServiceBookingDto(
    Guid Id,
    string ServiceTitle,
    string Category,
    DateTimeOffset EventDate,
    int Quantity,
    decimal TotalAmount,
    string Status,
    string PaymentStatus,
    string? EventAddress,
    string? Notes);

public sealed record VendorBookingDto(
    Guid Id,
    string ServiceTitle,
    string Category,
    DateTimeOffset EventDate,
    int Quantity,
    decimal TotalAmount,
    string Status,
    string PaymentStatus,
    string? Notes,
    DateTimeOffset CreatedAt);

public sealed record UpdateBookingStatusRequest(string Status);
