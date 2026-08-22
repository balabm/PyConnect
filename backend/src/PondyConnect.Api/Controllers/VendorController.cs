namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Api.Hubs;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.FoodDelivery;
using PondyConnect.Application.Features.Luggage;
using PondyConnect.Application.Features.Notifications;
using PondyConnect.Application.Features.Vendor;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

[ApiController]
[Route("api/vendor")]
[Authorize(Roles = "Vendor")] // Default: all endpoints require Vendor role
public sealed class VendorController : ControllerBase
{
    private static readonly string[] AllowedImageTypes = { "image/jpeg", "image/png", "image/webp" };
    private const long MaxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

    private readonly IMediator _mediator;
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IStorageService _storage;
    private readonly IPaymentGateway _paymentGateway;
    private readonly IHubContext<VendorHub> _hubContext;
    private readonly INotificationService _notifications;

    public VendorController(
        IMediator mediator,
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        IStorageService storage,
        IPaymentGateway paymentGateway,
        IHubContext<VendorHub> hubContext,
        INotificationService notifications)
    {
        _mediator = mediator;
        _context = context;
        _currentUser = currentUser;
        _storage = storage;
        _paymentGateway = paymentGateway;
        _hubContext = hubContext;
        _notifications = notifications;
    }

    /// <summary>
    /// Validates that an uploaded file is an image within the allowed types
    /// and size limit. Returns an error message if validation fails, null if OK.
    /// </summary>
    private static string? ValidateImageFile(IFormFile? file, string fieldName)
    {
        if (file is null) return null; // Optional fields are OK
        if (file.Length > MaxFileSizeBytes)
            return $"{fieldName} file exceeds the 10 MB size limit.";
        if (!AllowedImageTypes.Contains(file.ContentType))
            return $"{fieldName} file must be JPEG, PNG, or WebP.";
        return null;
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
            return BadRequest(new { Message = "A vendor with this phone number already exists." });

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
    [AllowAnonymous]
    [ProducesResponseType(typeof(VendorKycResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<VendorKycResponse>> UploadKyc(
        Guid vendorId,
        [FromForm] VendorKycUploadRequest request,
        CancellationToken cancellationToken = default)
    {
        // Self-onboarding: the vendor is not yet approved and has no JWT,
        // so we trust the vendorId returned from the anonymous registration call.
        var vendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.Id == vendorId, cancellationToken);
        if (vendor == null)
            return NotFound(new { Message = "Vendor not found." });

        // Validate file types and sizes for any uploaded documents.
        foreach (var (file, name) in new[] { (request.FssaiDoc, "FSSAI"), (request.GstDoc, "GST"), (request.PanDoc, "PAN") })
        {
            var error = ValidateImageFile(file, name);
            if (error is not null)
                return BadRequest(new { Message = error });
        }

        // Upload KYC documents to private storage — they contain sensitive
        // business information and must never be publicly accessible.
        string? fssaiUrl = null;
        string? gstUrl = null;
        string? panUrl = null;
        if (request.FssaiDoc != null)
            fssaiUrl = await _storage.UploadFileAsync(
                request.FssaiDoc.OpenReadStream(), request.FssaiDoc.FileName, request.FssaiDoc.ContentType,
                isPrivate: true, cancellationToken: cancellationToken);
        if (request.GstDoc != null)
            gstUrl = await _storage.UploadFileAsync(
                request.GstDoc.OpenReadStream(), request.GstDoc.FileName, request.GstDoc.ContentType,
                isPrivate: true, cancellationToken: cancellationToken);
        if (request.PanDoc != null)
            panUrl = await _storage.UploadFileAsync(
                request.PanDoc.OpenReadStream(), request.PanDoc.FileName, request.PanDoc.ContentType,
                isPrivate: true, cancellationToken: cancellationToken);

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
            vendor.IsActive,
            vendor.IsAcceptingOrders));
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

    /// <summary>
    /// Master "Accepting Orders" emergency toggle. When set to false, the
    /// consumer app instantly greys out the vendor card and disables
    /// "Add to Cart" via a SignalR <c>VendorStatusChanged</c> broadcast.
    /// </summary>
    [HttpPut("status")]
    [ProducesResponseType(typeof(ToggleVendorStatusResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ToggleVendorStatusResponse>> ToggleStatus(
        [FromBody] ToggleVendorStatusRequest request,
        CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized();

        var vendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.ContactPhone == phone, cancellationToken);

        if (vendor is null)
            return NotFound(new { Message = "Vendor not found." });

        vendor.SetAcceptingOrders(request.IsAcceptingOrders);
        await _context.SaveChangesAsync(cancellationToken);

        // Broadcast via SignalR so the consumer app reacts in real-time.
        await _hubContext.Clients.All.SendAsync("VendorStatusChanged", new
        {
            vendorId = vendor.Id,
            isAcceptingOrders = request.IsAcceptingOrders,
        }, cancellationToken);

        return Ok(new ToggleVendorStatusResponse(vendor.IsAcceptingOrders));
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
        if (result is null) return NotFound(new { Message = "Dashboard not available." });
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
        if (result is null) return NotFound(new { Message = "Bookings not available." });
        return Ok(result);
    }

    [HttpGet("venues")]
    [ProducesResponseType(typeof(IReadOnlyList<VendorVenueResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<VendorVenueResponse>>> ListVenues(CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new ListVendorVenuesQuery(), cancellationToken);
        if (result is null) return Ok(Array.Empty<VendorVenueResponse>());
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

        _ = _hubContext.Clients.All.SendAsync("OrderUpdated", new
        {
            orderId = result.Id,
            status = result.Stage,
        }, cancellationToken);

        return Ok(result);
    }

    /// <summary>
    /// Returns all checked-in bookings (live tables) for the authenticated
    /// vendor. Each entry includes the guest name, guest count, cover charge
    /// amount, and available credit. Used by the Partner app's "Live Tables"
    /// tab so waitstaff can track prepaid cover charge against the final bill.
    /// </summary>
    [HttpGet("live-tables")]
    [ProducesResponseType(typeof(List<LiveTableEntry>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<List<LiveTableEntry>>> GetLiveTables(CancellationToken cancellationToken)
    {
        try
        {
            var result = await _mediator.Send(new GetLiveTablesQuery(), cancellationToken);
            return Ok(result);
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized(new { Message = "Vendor authentication required." });
        }
    }

    /// <summary>
    /// Validates a QR ticket pass for a booking owned by the authenticated
    /// vendor. Returns success for valid, confirmed, paid passes and marks
    /// the booking as scanned. Returns 400 if the pass was already used.
    /// </summary>
    [HttpPost("validate-ticket")]
    [ProducesResponseType(typeof(TicketValidationResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<TicketValidationResponse>> ValidateTicket(
        [FromBody] ValidateTicketRequest request,
        CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized(new { Message = "Authenticated phone not found." });

        var vendor = await _context.Vendors.AsNoTracking()
            .FirstOrDefaultAsync(v => v.ContactPhone == phone && v.IsApproved, cancellationToken);

        if (vendor is null)
            return NotFound(new { Message = "Vendor profile not found." });

        if (string.IsNullOrWhiteSpace(request.QrPayload))
            return BadRequest(new { Message = "QR payload is required." });

        var booking = await _context.ServiceBookings
            .FirstOrDefaultAsync(b => b.PassToken == request.QrPayload, cancellationToken);

        if (booking is not null)
        {
            if (booking.VendorId != vendor.Id)
                return Forbid();

            if (booking.Status == BookingStatus.CheckedIn || booking.Status == BookingStatus.Completed)
                return BadRequest(new { Message = "Already scanned" });

            if (booking.PaymentStatus != PaymentStatus.Captured)
                return BadRequest(new { Message = "Payment not captured." });

            if (booking.Status != BookingStatus.Confirmed)
                return BadRequest(new { Message = "Booking not confirmed." });

            booking.CheckIn();

            if (booking.VenueId is { } venueId && booking.SeatCount > 0)
            {
                var venue = await _context.Venues
                    .FirstOrDefaultAsync(v => v.Id == venueId, cancellationToken);
                if (venue is not null)
                    venue.IncrementCheckedIn(booking.SeatCount);
            }

            await _context.SaveChangesAsync(cancellationToken);

            var user = await _context.Users.AsNoTracking()
                .FirstOrDefaultAsync(u => u.Id == booking.UserId, cancellationToken);

            return Ok(new TicketValidationResponse(
                true,
                booking.ServiceType.ToString(),
                user?.Name ?? "Unknown",
                "Valid ticket."));
        }

        var bundle = await _context.BundleBookings
            .FirstOrDefaultAsync(b => b.PassToken == request.QrPayload, cancellationToken);

        if (bundle is not null)
        {
            if (bundle.Status == BundleStatus.FullyRedeemed)
                return BadRequest(new { Message = "Already scanned" });

            if (bundle.Status == BundleStatus.Cancelled)
                return BadRequest(new { Message = "Pass cancelled." });

            bundle.MarkPartiallyRedeemed();
            await _context.SaveChangesAsync(cancellationToken);

            var user = await _context.Users.AsNoTracking()
                .FirstOrDefaultAsync(u => u.Id == bundle.UserId, cancellationToken);

            return Ok(new TicketValidationResponse(
                true,
                "Long Weekend Pass",
                user?.Name ?? "Unknown",
                "Valid pass."));
        }

        return BadRequest(new { Message = "Unknown ticket." });
    }

    /// <summary>
    /// Uploads a vendor image (menu item, promotion, etc.). The image is
    /// validated and compressed on the client then stored via the configured
    /// storage provider and a public URL is returned.
    /// </summary>
    [HttpPost("upload-image")]
    [ProducesResponseType(typeof(UploadImageResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<UploadImageResponse>> UploadImage(
        IFormFile image,
        CancellationToken cancellationToken = default)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized(new { Message = "Authenticated phone not found." });

        var vendor = await _context.Vendors.AsNoTracking()
            .FirstOrDefaultAsync(v => v.ContactPhone == phone && v.IsApproved, cancellationToken);

        if (vendor is null)
            return NotFound(new { Message = "Vendor profile not found." });

        if (image is null || image.Length == 0)
            return BadRequest(new { Message = "Image file is required." });

        var validation = ValidateImageFile(image, "Image");
        if (validation is not null)
            return BadRequest(new { Message = validation });

        using var stream = image.OpenReadStream();
        var imageUrl = await _storage.UploadFileAsync(
            stream, image.FileName, image.ContentType, isPrivate: false, cancellationToken);

        return Ok(new UploadImageResponse(imageUrl));
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

    [HttpPut("fcm-token")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateFcmToken(
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

        return NoContent();
    }

    [HttpDelete("fcm-token")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> ClearFcmToken(CancellationToken cancellationToken)
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

    // ── Live occupancy reporting (vendor-facing) ──

    /// <summary>
    /// Updates the live occupancy percentage for a venue owned by the
    /// authenticated vendor. The percentage is translated to a current
    /// capacity count against the venue's max capacity.
    /// </summary>
    [HttpPost("occupancy")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> UpdateOccupancy(
        [FromBody] UpdateOccupancyRequest request,
        CancellationToken cancellationToken = default)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized(new { Message = "Authenticated phone not found." });

        var vendorId = await _context.Vendors.AsNoTracking()
            .Where(v => v.ContactPhone == phone)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (vendorId == Guid.Empty)
            return NotFound(new { Message = "Vendor profile not found." });

        var venue = await _context.Venues
            .FirstOrDefaultAsync(v => v.Id == request.VenueId, cancellationToken);

        if (venue is null)
            return NotFound(new { Message = "Venue not found." });

        // Validate ownership — only the venue's vendor can update occupancy.
        if (venue.VendorId != vendorId)
            return Forbid();

        try
        {
            venue.SetOccupancyPercentage(request.OccupancyPercentage);
        }
        catch (ArgumentOutOfRangeException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }

        await _context.SaveChangesAsync(cancellationToken);
        return Ok(new { Message = "Occupancy updated.", venue.Id, OccupancyPercentage = request.OccupancyPercentage });
    }

    // ── Claim check generation (luggage cloak vendors) ──

    /// <summary>
    /// Generates a claim check for a walk-in luggage drop-off. Creates a
    /// LuggageDropOff record with a unique claim check ID and returns a QR
    /// payload encoding that ID for the customer to scan at pickup.
    /// </summary>
    [HttpPost("claim-check")]
    [ProducesResponseType(typeof(ClaimCheckResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ClaimCheckResponse>> CreateClaimCheck(
        [FromBody] CreateClaimCheckRequest request,
        CancellationToken cancellationToken = default)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized(new { Message = "Authenticated phone not found." });

        var vendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.ContactPhone == phone && v.IsApproved, cancellationToken);

        if (vendor is null)
            return NotFound(new { Message = "Vendor profile not found." });

        if (string.IsNullOrWhiteSpace(request.CustomerName))
            return BadRequest(new { Message = "Customer name is required." });
        if (request.BagCount <= 0)
            return BadRequest(new { Message = "Bag count must be at least 1." });

        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");

        var now = DateTimeOffset.UtcNow;
        var dropOff = LuggageDropOff.Create(
            userId,
            vendor.Id,
            scheduledFor: now,
            droppedAt: now,
            bagCount: request.BagCount,
            ratePerHour: 0m,
            notes: request.CustomerName);

        // Immediately mark as dropped — the luggage is handed over now.
        dropOff.MarkDropped();

        _context.LuggageDropOffs.Add(dropOff);
        await _context.SaveChangesAsync(cancellationToken);

        var qrPayload = $"pyconnect:claim-check:{dropOff.Id}";

        return Ok(new ClaimCheckResponse(
            dropOff.Id,
            request.CustomerName,
            request.BagCount,
            qrPayload));
    }

    // ── Photo-Verified Custody (luggage cloak) ──

    /// <summary>
    /// Receives bags at the partner location. The Partner must photograph
    /// the bags with security tags to protect against liability disputes.
    /// The intake photo is uploaded to S3 and displayed on the Consumer
    /// app for transparency. Transitions the status from Reserved to Dropped.
    /// </summary>
    [HttpPost("luggage/{dropOffId:guid}/receive")]
    [ProducesResponseType(typeof(ReceiveBagsResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> ReceiveBags(
        Guid dropOffId,
        [FromForm] IFormFile? intakePhoto,
        CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized(new { Message = "Vendor not authenticated." });

        var vendor = await _context.Vendors.AsNoTracking()
            .FirstOrDefaultAsync(v => v.ContactPhone == phone && v.IsApproved, cancellationToken);
        if (vendor is null)
            return NotFound(new { Message = "Vendor profile not found." });

        var dropOff = await _context.LuggageDropOffs
            .FirstOrDefaultAsync(d => d.Id == dropOffId, cancellationToken);
        if (dropOff is null)
            return NotFound(new { Message = "Drop-off not found." });

        if (dropOff.VendorId != vendor.Id)
            return Forbid();

        // Upload intake photo if provided.
        string? intakeUrl = null;
        if (intakePhoto is not null && intakePhoto.Length > 0)
        {
            if (intakePhoto.Length > 10 * 1024 * 1024)
                return BadRequest(new { Message = "Photo must be under 10MB." });

            var allowedTypes = new[] { "image/jpeg", "image/png", "image/webp" };
            if (!allowedTypes.Contains(intakePhoto.ContentType))
                return BadRequest(new { Message = "Photo must be JPEG, PNG, or WebP." });

            await using var stream = intakePhoto.OpenReadStream();
            intakeUrl = await _storage.UploadFileAsync(stream, intakePhoto.FileName, intakePhoto.ContentType, isPrivate: false, cancellationToken: cancellationToken);
        }

        try
        {
            dropOff.MarkDropped(intakeUrl);
            await _context.SaveChangesAsync(cancellationToken);

            // Notify the consumer that their bags are secured.
            await _notifications.SendTargetedPushAsync(
                dropOff.UserId,
                "Bags Secured",
                "Your luggage has been received and secured. Show your retrieval PIN at pickup.",
                dataPayload: new() { ["type"] = "luggage_dropped", ["dropOffId"] = dropOff.Id.ToString() },
                cancellationToken: cancellationToken);

            return Ok(new ReceiveBagsResponse(dropOff.Id, "Bags received and secured.", intakeUrl));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    /// <summary>
    /// Collects bags using the retrieval PIN. The Partner scans the
    /// Consumer's QR code or manually enters the 6-digit PIN. Closes
    /// the liability loop. Transitions the status from Dropped to Collected.
    /// </summary>
    [HttpPost("luggage/{dropOffId:guid}/collect")]
    [ProducesResponseType(typeof(CollectBagsResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> CollectBags(
        Guid dropOffId,
        [FromBody] CollectBagsRequest request,
        CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized(new { Message = "Vendor not authenticated." });

        var vendor = await _context.Vendors.AsNoTracking()
            .FirstOrDefaultAsync(v => v.ContactPhone == phone && v.IsApproved, cancellationToken);
        if (vendor is null)
            return NotFound(new { Message = "Vendor profile not found." });

        var dropOff = await _context.LuggageDropOffs
            .FirstOrDefaultAsync(d => d.Id == dropOffId, cancellationToken);
        if (dropOff is null)
            return NotFound(new { Message = "Drop-off not found." });

        if (dropOff.VendorId != vendor.Id)
            return Forbid();

        try
        {
            dropOff.CollectWithPin(request.Pin);
            await _context.SaveChangesAsync(cancellationToken);

            // Notify the consumer that their bags have been collected.
            await _notifications.SendTargetedPushAsync(
                dropOff.UserId,
                "Bags Returned",
                "Your luggage has been successfully returned. Thank you for using PY Connect!",
                dataPayload: new() { ["type"] = "luggage_collected", ["dropOffId"] = dropOff.Id.ToString() },
                cancellationToken: cancellationToken);

            return Ok(new CollectBagsResponse(dropOff.Id, "Bags successfully returned."));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    // ── Transit trip driver assignment (taxi operator vendors) ──

    /// <summary>
    /// Assigns a driver and optional vehicle plate to a transit trip
    /// owned by the authenticated vendor. Used by taxi operators to
    /// manage their fleet dispatch.
    /// </summary>
    [HttpPut("transit/{tripId:guid}/assign-driver")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> AssignTransitDriver(
        Guid tripId,
        [FromBody] AssignTransitDriverRequest request,
        CancellationToken cancellationToken = default)
    {
        try
        {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized(new { Message = "Authenticated phone not found." });

        var vendorId = await _context.Vendors.AsNoTracking()
            .Where(v => v.ContactPhone == phone)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);
        if (vendorId == Guid.Empty)
            return NotFound(new { Message = "Vendor profile not found." });

        var trip = await _context.TransitTrips
            .FirstOrDefaultAsync(t => t.Id == tripId, cancellationToken);
        if (trip is null)
            return NotFound(new { Message = "Transit trip not found." });
        if (trip.VendorId != vendorId)
            return Forbid();

        trip.AssignDriver(request.DriverName, request.VehiclePlate);
        await _context.SaveChangesAsync(cancellationToken);

        return Ok(new { Message = "Driver assigned.", trip.Id, request.DriverName, request.VehiclePlate });
    }
    catch (InvalidOperationException ex)
    {
        return BadRequest(new { Message = ex.Message });
    }
    }

    // -----------------------------------------------------------------------
    // Partial fulfillment: vendor marks an item out of stock and auto-refunds
    // -----------------------------------------------------------------------

    /// <summary>
    /// Removes an item from a food order and triggers a partial refund for
    /// the item's price. Used when a vendor discovers an item is out of
    /// stock after accepting the order. The rest of the order stays active.
    /// </summary>
    [HttpPost("orders/{orderId:guid}/partial-refund")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> PartialRefund(Guid orderId, [FromBody] PartialRefundRequest request, CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized(new { Message = "Authenticated phone not found." });

        var vendorId = await _context.Vendors.AsNoTracking()
            .Where(v => v.ContactPhone == phone)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);
        if (vendorId == Guid.Empty)
            return NotFound(new { Message = "Vendor profile not found." });

        var order = await _context.FoodOrders
            .Include(f => f.Items)
            .FirstOrDefaultAsync(f => f.Id == orderId, cancellationToken);
        if (order is null)
            return NotFound(new { Message = "Food order not found." });
        if (order.VendorId != vendorId)
            return Forbid();

        try
        {
            // Remove the item from the order and get the refund amount.
            var refundAmount = order.RemoveItem(request.ItemId);
            await _context.SaveChangesAsync(cancellationToken);

            // If the order was paid online, trigger a partial refund via Razorpay.
            if (order.PaymentStatus == PaymentStatus.Captured)
            {
                var payment = await _context.Payments
                    .FirstOrDefaultAsync(p => p.FoodOrderId == order.Id && p.Status == PaymentStatus.Captured, cancellationToken);
                if (payment?.ProviderPaymentId is not null)
                {
                    var refundResult = await _paymentGateway.RefundAsync(
                        payment.ProviderPaymentId,
                        refundAmount,
                        $"Item out of stock: {request.ItemId}",
                        cancellationToken);
                    if (!refundResult.Success)
                        return BadRequest(new { Message = $"Refund failed: {refundResult.ErrorMessage}" });
                }
            }

            // Notify the consumer in real-time that the order has been updated.
            _ = _hubContext.Clients.All.SendAsync("OrderUpdated", new
            {
                orderId = order.Id,
                status = order.Status.ToString(),
                refundAmount,
                newTotal = order.TotalAmount,
            }, cancellationToken);

            return Ok(new
            {
                Message = "Item removed and refund processed.",
                RefundAmount = refundAmount,
                NewTotal = order.TotalAmount,
            });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

}

public sealed record PartialRefundRequest(Guid ItemId);

public sealed record ValidateTicketRequest(string QrPayload);
public sealed record ActivatePriorityRequest(Guid VenueId);

public sealed record CreateFlashPromoRequest(decimal DiscountPercentage, int DurationMinutes, string? Title = null, string? Description = null);

public sealed record VendorWalletResponse(decimal Balance, decimal TotalEarned, decimal TotalSpent);
public sealed record VendorWalletTransactionResponse(string Id, string Type, decimal Amount, string Description, string Timestamp);
public sealed record UpdateVendorBookingStatusRequest(string ServiceType, string NewStatus);
public sealed record UpdateVendorDeviceTokenRequest(string Token);

// --- Occupancy & claim check request/response records ---

public sealed record UpdateOccupancyRequest(Guid VenueId, int OccupancyPercentage);

public sealed record CreateClaimCheckRequest(string CustomerName, int BagCount);

public sealed record ClaimCheckResponse(Guid ClaimCheckId, string CustomerName, int BagCount, string QrPayload);

public sealed record ReceiveBagsResponse(Guid DropOffId, string Message, string? IntakeImageUrl);
public sealed record CollectBagsRequest(string Pin);
public sealed record CollectBagsResponse(Guid DropOffId, string Message);

public sealed record AssignTransitDriverRequest(string? DriverName, string? VehiclePlate);

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
    bool IsActive,
    bool IsAcceptingOrders = true);

public sealed record UpdateVendorProfileRequest(string? Description);
public sealed record SetVenueAvailabilityRequest(bool? IsActive);

public sealed record ToggleActiveResponse(bool IsActive);

public sealed record ToggleVendorStatusRequest(bool IsAcceptingOrders);
public sealed record ToggleVendorStatusResponse(bool IsAcceptingOrders);

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

public sealed record UploadImageResponse(string ImageUrl);