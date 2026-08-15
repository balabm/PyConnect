namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.FoodDelivery;
using PondyConnect.Application.Features.Luggage;
using PondyConnect.Application.Features.Vendor;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

[ApiController]
[Route("api/vendor")]
[Authorize(Roles = "Vendor")] // Default: all endpoints require Vendor role
public sealed class VendorController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public VendorController(IMediator mediator, IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _mediator = mediator;
        _context = context;
        _currentUser = currentUser;
    }

    // -----------------------------------------------------------------------
    // Self-onboarding endpoints (anonymous — no Vendor role required yet)
    // -----------------------------------------------------------------------

    /// <summary>
    /// Self-registers a new vendor/partner. Creates a pending vendor record
    /// that the admin must approve before the partner can log in.
    /// </summary>
    [HttpPost("register")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(VendorRegistrationResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<VendorRegistrationResponse>> SelfRegister(
        [FromBody] VendorSelfRegistrationRequest request,
        CancellationToken cancellationToken = default)
    {
        // Check if a vendor with the same phone already exists
        var existing = await _context.Vendors
            .FirstOrDefaultAsync(v => v.ContactPhone == request.ContactPhone, cancellationToken);
        if (existing != null)
            return BadRequest(new { message = "A vendor with this phone number already exists." });

        // Create or upgrade the user account to Vendor role so they can log in
        // via the vendor auth flow once approved.
        var existingUser = await _context.Users
            .FirstOrDefaultAsync(u => u.Phone == request.ContactPhone, cancellationToken);

        if (existingUser != null)
        {
            if (existingUser.Role == UserRole.Tourist)
                existingUser.ChangeRole(UserRole.Vendor);
        }
        else
        {
            var newUser = Domain.Entities.User.Create(request.BusinessName, request.ContactPhone, UserRole.Vendor);
            _context.Users.Add(newUser);
        }

        var category = Enum.Parse<VendorCategory>(request.Category, ignoreCase: true);
        var vendor = Vendor.Create(
            request.BusinessName,
            category,
            request.ContactPhone,
            description: request.Description);
        // Self-registered vendors start as unapproved
        // (IsApproved defaults to false)
        _context.Vendors.Add(vendor);
        await _context.SaveChangesAsync(cancellationToken);

        return CreatedAtAction(
            nameof(SelfRegister),
            new VendorRegistrationResponse(vendor.Id.ToString(), "Pending admin approval"));
    }

    /// <summary>
    /// Uploads KYC documents (FSSAI, GST, PAN) for a self-registered vendor.
    /// Uses multipart form data. Files are stored in private storage.
    /// </summary>
    [HttpPost("{vendorId:guid}/kyc")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(VendorKycResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<VendorKycResponse>> UploadKyc(
        Guid vendorId,
        [FromForm] VendorKycUploadRequest request,
        CancellationToken cancellationToken = default)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized(new { Message = "Authenticated phone not found." });

        // Validate ownership: the vendor must belong to the authenticated user.
        var vendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.Id == vendorId && v.ContactPhone == phone, cancellationToken);
        if (vendor == null)
            return NotFound();

        // For now, store the file names as URLs. In production, these would
        // be uploaded to S3/private storage and the keys stored here.
        var fssaiUrl = request.FssaiDoc != null ? $"vendor-kyc/{vendorId}/fssai-{Guid.NewGuid()}" : null;
        var gstUrl = request.GstDoc != null ? $"vendor-kyc/{vendorId}/gst-{Guid.NewGuid()}" : null;
        var panUrl = request.PanDoc != null ? $"vendor-kyc/{vendorId}/pan-{Guid.NewGuid()}" : null;

        vendor.SubmitKyc(
            request.FssaiNumber,
            request.GstNumber,
            request.PanNumber,
            fssaiUrl,
            gstUrl,
            panUrl,
            request.BankAccountNumber,
            request.BankIfsc,
            request.BankAccountName);

        await _context.SaveChangesAsync(cancellationToken);

        return Ok(new VendorKycResponse(vendor.Id.ToString(), vendor.IsKycSubmitted));
    }

    /// <summary>
    /// Updates operating hours for a vendor. The hours are stored as a JSON
    /// string keyed by day abbreviation.
    /// </summary>
    [HttpPut("{vendorId:guid}/operating-hours")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> UpdateOperatingHours(
        Guid vendorId,
        [FromBody] UpdateOperatingHoursRequest request,
        CancellationToken cancellationToken = default)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized(new { Message = "Authenticated phone not found." });

        // Validate ownership.
        var vendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.Id == vendorId && v.ContactPhone == phone, cancellationToken);
        if (vendor == null)
            return NotFound();

        vendor.UpdateOperatingHours(request.HoursJson);
        await _context.SaveChangesAsync(cancellationToken);

        return Ok();
    }

    // -----------------------------------------------------------------------
    // Existing vendor endpoints (require Vendor role)
    // -----------------------------------------------------------------------

    [HttpGet("profile")]
    [ProducesResponseType(typeof(VendorProfileResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<VendorProfileResponse>> GetProfile(CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized();

        var vendor = await _context.Vendors.AsNoTracking()
            .FirstOrDefaultAsync(v => v.ContactPhone == phone, cancellationToken);

        if (vendor is null)
            return NotFound();

        return Ok(new VendorProfileResponse(
            vendor.Id,
            vendor.Name,
            vendor.Category.ToString(),
            vendor.ContactPhone,
            vendor.Description,
            vendor.IsApproved,
            vendor.IsActive));
    }

    [HttpPut("profile")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateVendorProfileRequest request, CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized();

        var vendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.ContactPhone == phone, cancellationToken);

        if (vendor is null)
            return NotFound();

        if (!string.IsNullOrWhiteSpace(request.Description))
            vendor.UpdateRestaurantDetails(description: request.Description);

        await _context.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpPut("toggle-active")]
    [ProducesResponseType(typeof(ToggleActiveResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ToggleActiveResponse>> ToggleActive(CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized();

        var vendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.ContactPhone == phone, cancellationToken);

        if (vendor is null)
            return NotFound();

        if (vendor.IsActive)
            vendor.Deactivate();
        else
            vendor.Approve();

        await _context.SaveChangesAsync(cancellationToken);

        return Ok(new ToggleActiveResponse(vendor.IsActive));
    }

    [HttpGet("venues/{venueId:guid}")]
    [ProducesResponseType(typeof(VendorVenueResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<VendorVenueResponse>> GetVenue(Guid venueId, CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized();

        var vendorId = await _context.Vendors.AsNoTracking()
            .Where(v => v.ContactPhone == phone)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (vendorId == Guid.Empty)
            return NotFound();

        var venue = await _context.Venues.AsNoTracking()
            .FirstOrDefaultAsync(v => v.Id == venueId && v.VendorId == vendorId, cancellationToken);

        if (venue is null)
            return NotFound();

        return Ok(new VendorVenueResponse(
            venue.Id,
            venue.Name,
            venue.Category.ToString(),
            venue.Address,
            venue.MaxCapacity,
            venue.CurrentCapacity > 0));
    }

    [HttpGet("orders/{orderId:guid}")]
    [ProducesResponseType(typeof(FoodOrderDetailResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<FoodOrderDetailResponse>> GetOrderDetail(Guid orderId, CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized();

        var vendorId = await _context.Vendors.AsNoTracking()
            .Where(v => v.ContactPhone == phone)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (vendorId == Guid.Empty)
            return NotFound();

        var order = await _context.FoodOrders.AsNoTracking()
            .FirstOrDefaultAsync(o => o.Id == orderId && o.VendorId == vendorId, cancellationToken);

        if (order is null)
            return NotFound();

        return Ok(new FoodOrderDetailResponse(
            order.Id,
            order.VendorId,
            order.Status.ToString(),
            order.TotalAmount,
            order.DeliveryAddress,
            order.PlacedAt,
            order.DeliveredAt));
    }

    [HttpGet("dashboard")]
    [ProducesResponseType(typeof(VendorDashboardResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<VendorDashboardResponse>> GetDashboard(
        [FromQuery] DateOnly? date = null,
        CancellationToken cancellationToken = default)
    {
        var result = await _mediator.Send(new GetVendorDashboardQuery(date), cancellationToken);
        return Ok(result);
    }

    [HttpGet("bookings")]
    [ProducesResponseType(typeof(VendorBookingsResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<VendorBookingsResponse>> GetBookings(
        [FromQuery] DateOnly? date = null,
        [FromQuery] BookingStatus? status = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        var result = await _mediator.Send(new GetVendorBookingsQuery(date, status, page, pageSize), cancellationToken);
        return Ok(result);
    }

    [HttpGet("venues")]
    [ProducesResponseType(typeof(IReadOnlyList<VendorVenueResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<VendorVenueResponse>>> ListVenues(CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new ListVendorVenuesQuery(), cancellationToken);
        return Ok(result);
    }

    [HttpPost("venues")]
    [ProducesResponseType(typeof(CreateVendorVenueResponse), StatusCodes.Status201Created)]
    public async Task<ActionResult<CreateVendorVenueResponse>> CreateVenue([FromBody] CreateVendorVenueCommand command, CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(command, cancellationToken);
        return CreatedAtAction(nameof(ListVenues), new { id = result.VenueId }, result);
    }

    [HttpPut("venues/{venueId:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> UpdateVenue(Guid venueId, [FromBody] UpdateVendorVenueCommand command, CancellationToken cancellationToken)
    {
        await _mediator.Send(command with { VenueId = venueId }, cancellationToken);
        return NoContent();
    }

    [HttpDelete("venues/{venueId:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> DeactivateVenue(Guid venueId, CancellationToken cancellationToken)
    {
        await _mediator.Send(new DeactivateVendorVenueCommand(venueId), cancellationToken);
        return NoContent();
    }

    [HttpPut("venues/{venueId:guid}/availability")]
    [ProducesResponseType(typeof(ToggleVenueAvailabilityResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ToggleVenueAvailabilityResponse>> ToggleVenueAvailability(
        Guid venueId,
        [FromBody] SetVenueAvailabilityRequest? request,
        CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new ToggleVenueAvailabilityCommand(venueId, request?.IsActive), cancellationToken);
        return Ok(result);
    }

    [HttpGet("promotions")]
    [ProducesResponseType(typeof(IReadOnlyList<VendorPromotionResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<VendorPromotionResponse>>> ListPromotions(CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new ListVendorPromotionsQuery(), cancellationToken);
        return Ok(result);
    }

    [HttpPost("promotions")]
    [ProducesResponseType(typeof(CreateVendorPromotionResponse), StatusCodes.Status201Created)]
    public async Task<ActionResult<CreateVendorPromotionResponse>> CreatePromotion([FromBody] CreateVendorPromotionCommand command, CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(command, cancellationToken);
        return CreatedAtAction(nameof(ListPromotions), new { id = result.PromotionId }, result);
    }

    [HttpPost("flash-promos")]
    [ProducesResponseType(typeof(FlashPromoResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<FlashPromoResponse>> CreateFlashPromo([FromBody] CreateFlashPromoRequest request, CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new CreateFlashPromoCommand(request.DiscountPercentage, request.DurationMinutes, request.Title, request.Description), cancellationToken);
        return Ok(result);
    }

    [HttpGet("flash-promos")]
    [ProducesResponseType(typeof(IReadOnlyList<FlashPromoResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<FlashPromoResponse>>> ListVendorFlashPromos(CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new ListVendorFlashPromosQuery(), cancellationToken);
        return Ok(result);
    }

    // ── KDS (Kitchen Display System) ──

    [HttpGet("kds/orders")]
    [ProducesResponseType(typeof(IReadOnlyList<KdsOrderResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<KdsOrderResponse>>> GetKdsOrders(CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new GetKdsOrdersQuery(), cancellationToken);
        return Ok(result);
    }

    [HttpPost("kds/orders/{id:guid}/advance")]
    [ProducesResponseType(typeof(KdsOrderResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<KdsOrderResponse>> AdvanceKdsOrder(Guid id, CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new AdvanceKdsOrderCommand(id), cancellationToken);
        return Ok(result);
    }

    [HttpPost("validate-ticket")]
    [ProducesResponseType(typeof(TicketValidationResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<TicketValidationResponse>> ValidateTicket([FromBody] ValidateTicketRequest request, CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new ValidateTicketCommand(request.QrPayload), cancellationToken);
        return Ok(result);
    }

    [HttpPost("activate-priority")]
    [ProducesResponseType(typeof(ActivatePriorityResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ActivatePriorityResponse>> ActivatePriority([FromBody] ActivatePriorityRequest request, CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new ActivatePriorityPingCommand(request.VenueId), cancellationToken);
        return Ok(result);
    }

    // ── Booking Status Management ──

    [HttpPut("bookings/{id:guid}/status")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> UpdateBookingStatus(Guid id, [FromBody] UpdateVendorBookingStatusRequest request, CancellationToken cancellationToken)
    {
        try
        {
            await _mediator.Send(new UpdateVendorBookingStatusCommand(id, request.ServiceType, request.NewStatus), cancellationToken);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized(new { Message = "Vendor profile not found." });
        }
    }

    // ── Wallet / Credits ──

    [HttpPost("device-token")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateDeviceToken(
        [FromBody] UpdateVendorDeviceTokenRequest request,
        CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            return Unauthorized();

        var vendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.ContactPhone == userPhone && v.IsApproved, cancellationToken);

        if (vendor is null)
            return NotFound(new { Message = "Vendor not found." });

        vendor.UpdateFcmDeviceToken(request.Token);
        await _context.SaveChangesAsync(cancellationToken);

        return Ok(new { Message = "Device token updated." });
    }

    [HttpDelete("device-token")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> ClearDeviceToken(CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            return Unauthorized();

        var vendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.ContactPhone == userPhone && v.IsApproved, cancellationToken);

        if (vendor is null)
            return NotFound(new { Message = "Vendor not found." });

        vendor.ClearFcmDeviceToken();
        await _context.SaveChangesAsync(cancellationToken);

        return NoContent();
    }

    [HttpGet("wallet")]
    [ProducesResponseType(typeof(VendorWalletResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<VendorWalletResponse>> GetWallet(CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            return Unauthorized();

        var vendor = await _context.Vendors
            .AsNoTracking()
            .FirstOrDefaultAsync(v => v.ContactPhone == userPhone && v.IsApproved, cancellationToken);

        if (vendor is null)
            return Unauthorized();

        return Ok(new VendorWalletResponse(
            vendor.CreditBalance,
            vendor.CreditBalance,
            0m));
    }

    [HttpGet("wallet/transactions")]
    [ProducesResponseType(typeof(IReadOnlyList<VendorWalletTransactionResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<VendorWalletTransactionResponse>>> GetWalletTransactions(CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            return Unauthorized();

        var vendor = await _context.Vendors
            .AsNoTracking()
            .FirstOrDefaultAsync(v => v.ContactPhone == userPhone && v.IsApproved, cancellationToken);

        if (vendor is null)
            return Unauthorized();

        var venues = await _context.Venues
            .AsNoTracking()
            .Where(v => v.VendorId == vendor.Id && v.IsPriorityPingActive)
            .ToListAsync(cancellationToken);

        var transactions = new List<VendorWalletTransactionResponse>();
        foreach (var venue in venues)
        {
            if (venue.PriorityPingExpiry is { } expiry)
            {
                transactions.Add(new VendorWalletTransactionResponse(
                    venue.Id.ToString(),
                    "debit",
                    499m,
                    $"Priority Ping — {venue.Name}",
                    expiry.AddDays(-7).ToString("O")));
            }
        }

        transactions.Add(new VendorWalletTransactionResponse(
            vendor.Id.ToString(),
            "credit",
            vendor.CreditBalance + transactions.Sum(t => t.Amount),
            "Initial credit grant",
            vendor.CreatedAt.ToString("O")));

        return Ok(transactions);
    }

    // ── Luggage Cloak Management (vendor-facing) ──

    [HttpGet("luggage")]
    [ProducesResponseType(typeof(IReadOnlyList<LuggageDropOffResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<LuggageDropOffResponse>>> ListLuggageDropOffs(
        [FromQuery] LuggageStatus? status = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var result = await _mediator.Send(new ListVendorLuggageQuery(status), cancellationToken);
            return Ok(result);
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized(new { Message = "Vendor profile not found." });
        }
    }

    [HttpPost("luggage/{id:guid}/collect")]
    [ProducesResponseType(typeof(LuggageDropOffResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<LuggageDropOffResponse>> MarkLuggageCollected(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var result = await _mediator.Send(new MarkLuggageCollectedCommand(id), cancellationToken);
            return Ok(result);
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized(new { Message = "Vendor profile not found." });
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

}

public sealed record ValidateTicketRequest(string QrPayload);
public sealed record ActivatePriorityRequest(Guid VenueId);

public sealed record CreateFlashPromoRequest(decimal DiscountPercentage, int DurationMinutes, string? Title = null, string? Description = null);

public sealed record VendorWalletResponse(decimal Balance, decimal TotalEarned, decimal TotalSpent);
public sealed record VendorWalletTransactionResponse(string Id, string Type, decimal Amount, string Description, string Timestamp);
public sealed record UpdateVendorBookingStatusRequest(string ServiceType, string NewStatus);
public sealed record UpdateVendorDeviceTokenRequest(string Token);

// --- Self-onboarding request/response records ---

public sealed record VendorSelfRegistrationRequest(
    string BusinessName,
    string Category,
    string ContactPhone,
    string? Description = null);

public sealed record VendorRegistrationResponse(string VendorId, string Status);

public sealed record VendorKycUploadRequest(
    string? FssaiNumber,
    string? GstNumber,
    string? PanNumber,
    IFormFile? FssaiDoc,
    IFormFile? GstDoc,
    IFormFile? PanDoc,
    string? BankAccountNumber,
    string? BankIfsc,
    string? BankAccountName);

public sealed record VendorKycResponse(string VendorId, bool IsKycSubmitted);

public sealed record UpdateOperatingHoursRequest(string HoursJson);

// --- Vendor profile & venue management DTOs ---

public sealed record VendorProfileResponse(
    Guid Id,
    string Name,
    string Category,
    string? ContactPhone,
    string? Description,
    bool IsApproved,
    bool IsActive);

public sealed record UpdateVendorProfileRequest(string? Description);
public sealed record SetVenueAvailabilityRequest(bool? IsActive);

public sealed record ToggleActiveResponse(bool IsActive);

public sealed record VendorVenueResponse(
    Guid Id,
    string Name,
    string Category,
    string? Address,
    int MaxCapacity,
    bool IsOpen);

public sealed record FoodOrderDetailResponse(
    Guid Id,
    Guid VendorId,
    string Status,
    decimal TotalAmount,
    string DeliveryAddress,
    DateTimeOffset PlacedAt,
    DateTimeOffset? DeliveredAt);