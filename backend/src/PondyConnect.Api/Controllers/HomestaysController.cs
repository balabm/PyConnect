namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Homestays;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

[ApiController]
[Route("api/homestays")]
[Authorize]
public sealed class HomestaysController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IStorageService _storage;
    private readonly PondyConnect.Application.Features.Homestays.InventoryService _inventory;

    public HomestaysController(
        IMediator mediator,
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        IStorageService storage,
        PondyConnect.Application.Features.Homestays.InventoryService inventory)
    {
        _mediator = mediator;
        _context = context;
        _currentUser = currentUser;
        _storage = storage;
        _inventory = inventory;
    }

    [HttpGet("search")]
    [ProducesResponseType(typeof(IReadOnlyList<HomestaySearchResult>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<HomestaySearchResult>>> Search(
        [FromQuery] string checkIn,
        [FromQuery] string checkOut,
        [FromQuery] int guests = 1,
        CancellationToken cancellationToken = default)
    {
        if (!DateOnly.TryParse(checkIn, out var checkInDate))
            return BadRequest(new { Message = "Invalid checkIn date format. Use YYYY-MM-DD." });

        if (!DateOnly.TryParse(checkOut, out var checkOutDate))
            return BadRequest(new { Message = "Invalid checkOut date format. Use YYYY-MM-DD." });

        if (checkOutDate <= checkInDate)
            return BadRequest(new { Message = "Check-out date must be after check-in date." });

        var result = await _mediator.Send(new SearchHomestaysQuery(checkInDate, checkOutDate, guests), cancellationToken);
        return Ok(result);
    }

    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(HomestaySearchResult), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<HomestaySearchResult>> GetById(Guid id, CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new GetHomestayByIdQuery(id), cancellationToken);
        if (result is null)
            return NotFound(new { Message = "Homestay not found." });

        return Ok(result);
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<HomestaySearchResult>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<HomestaySearchResult>>> List(CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new ListVerifiedHomestaysQuery(), cancellationToken);
        return Ok(result);
    }

    [HttpPost("book")]
    [Authorize]
    [ProducesResponseType(typeof(BookHomestayResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<BookHomestayResponse>> Book(
        [FromBody] BookHomestayCommand command,
        CancellationToken cancellationToken)
    {
        try
        {
            var result = await _mediator.Send(command, cancellationToken);
            return CreatedAtAction(nameof(GetById), new { id = result.BookingId }, result);
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized(new { Message = "Authentication required." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    [HttpGet("my-bookings")]
    [HttpGet("bookings")]
    [ProducesResponseType(typeof(IReadOnlyList<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyList<object>>> MyBookings(CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId;
        if (userId is null)
            return Unauthorized(new { Message = "Authentication required." });

        var bookings = await _context.ServiceBookings
            .Where(b => b.UserId == userId && b.ServiceType == ServiceType.Homestay)
            .OrderByDescending(b => b.CreatedAt)
            .Select(b => new
            {
                id = b.Id,
                status = b.Status.ToString(),
                checkInDate = b.CheckInDate,
                checkOutDate = b.CheckOutDate,
                homestayId = b.HomestayId,
                totalAmount = b.TotalAmount,
                createdAt = b.CreatedAt,
            })
            .ToListAsync(cancellationToken);

        return Ok(bookings);
    }

    /// <summary>
    /// Places a pending inventory lock on the selected dates for a
    /// homestay. Called when the user selects dates on the calendar —
    /// before they proceed to payment. The lock is held for 10 minutes.
    /// If another user tries to select the same dates, they are blocked.
    /// If the user does not pay within 10 minutes, the lock expires.
    /// </summary>
    [HttpPost("{homestayId:guid}/lock-dates")]
    [ProducesResponseType(typeof(LockDatesResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> LockDates(
        Guid homestayId,
        [FromBody] LockDatesRequest request,
        CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "Authentication required." });

        if (!DateOnly.TryParse(request.CheckIn, out var checkIn))
            return BadRequest(new { Message = "Invalid checkIn date format. Use YYYY-MM-DD." });

        if (!DateOnly.TryParse(request.CheckOut, out var checkOut))
            return BadRequest(new { Message = "Invalid checkOut date format. Use YYYY-MM-DD." });

        if (checkOut <= checkIn)
            return BadRequest(new { Message = "Check-out must be after check-in." });

        try
        {
            await _inventory.PlacePendingLockAsync(homestayId, checkIn, checkOut, userId.Value, ct: ct);
            return Ok(new LockDatesResponse(true, "Dates locked for 10 minutes. Complete your booking to confirm."));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    /// <summary>
    /// Releases a pending inventory lock on the selected dates. Called
    /// when the user navigates away from the booking screen without paying.
    /// </summary>
    [HttpPost("{homestayId:guid}/unlock-dates")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> UnlockDates(
        Guid homestayId,
        [FromBody] LockDatesRequest request,
        CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "Authentication required." });

        if (!DateOnly.TryParse(request.CheckIn, out var checkIn) ||
            !DateOnly.TryParse(request.CheckOut, out var checkOut))
            return NoContent();

        await _inventory.ReleasePendingLockAsync(homestayId, checkIn, checkOut, userId.Value, ct);
        return NoContent();
    }

    /// <summary>
    /// Uploads digital check-in KYC documents (front + back of Govt ID)
    /// for a homestay/rental booking. The QR pass token is blocked until
    /// this is completed. Documents are stored in a private S3 bucket
    /// and can only be viewed by the Partner during the check-in window.
    /// </summary>
    [HttpPost("bookings/{bookingId:guid}/kyc")]
    [ProducesResponseType(typeof(KycUploadResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> UploadKyc(
        Guid bookingId,
        [FromForm] IFormFile idFront,
        [FromForm] IFormFile? idBack,
        [FromForm] string idType,
        CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "Authentication required." });

        // Validate the booking belongs to this user.
        var booking = await _context.ServiceBookings
            .FirstOrDefaultAsync(b => b.Id == bookingId && b.UserId == userId && b.ServiceType == ServiceType.Homestay, ct);
        if (booking is null)
            return NotFound(new { Message = "Booking not found or not owned by you." });

        if (idFront is null || idFront.Length == 0)
            return BadRequest(new { Message = "Front side of ID is required." });

        if (idFront.Length > 10 * 1024 * 1024)
            return BadRequest(new { Message = "ID photo must be under 10MB." });

        var allowedTypes = new[] { "image/jpeg", "image/png", "image/webp" };
        if (!allowedTypes.Contains(idFront.ContentType))
            return BadRequest(new { Message = "ID photo must be JPEG, PNG, or WebP." });

        // Upload front side to private S3 bucket.
        await using var frontStream = idFront.OpenReadStream();
        var frontUrl = await _storage.UploadFileAsync(frontStream, idFront.FileName, idFront.ContentType, isPrivate: true, cancellationToken: ct);

        // Upload back side if provided.
        string? backUrl = null;
        if (idBack is not null && idBack.Length > 0)
        {
            if (idBack.Length > 10 * 1024 * 1024)
                return BadRequest(new { Message = "ID back photo must be under 10MB." });

            if (!allowedTypes.Contains(idBack.ContentType))
                return BadRequest(new { Message = "ID back photo must be JPEG, PNG, or WebP." });

            await using var backStream = idBack.OpenReadStream();
            backUrl = await _storage.UploadFileAsync(backStream, idBack.FileName, idBack.ContentType, isPrivate: true, cancellationToken: ct);
        }

        // Find or create the GuestKyc record.
        var kyc = await _context.GuestKycs.FirstOrDefaultAsync(k => k.BookingId == bookingId, ct);
        if (kyc is null)
        {
            kyc = GuestKyc.Create(bookingId, userId.Value);
            _context.GuestKycs.Add(kyc);
        }

        kyc.MarkUploaded(frontUrl, backUrl, idType);
        await _context.SaveChangesAsync(ct);

        return Ok(new KycUploadResponse(bookingId, true, "KYC documents uploaded successfully."));
    }

    /// <summary>
    /// Returns the KYC status for a booking. Used by the Consumer app
    /// to determine whether the QR pass token can be generated.
    /// </summary>
    [HttpGet("bookings/{bookingId:guid}/kyc")]
    [ProducesResponseType(typeof(KycStatusResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetKycStatus(Guid bookingId, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "Authentication required." });

        var booking = await _context.ServiceBookings
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.Id == bookingId && b.UserId == userId && b.ServiceType == ServiceType.Homestay, ct);
        if (booking is null)
            return NotFound(new { Message = "Booking not found or not owned by you." });

        var kyc = await _context.GuestKycs.AsNoTracking().FirstOrDefaultAsync(k => k.BookingId == bookingId, ct);

        return Ok(new KycStatusResponse(
            bookingId,
            kyc?.IsUploaded ?? false,
            kyc?.IdType,
            kyc?.UploadedAt));
    }

    /// <summary>
    /// Returns presigned URLs for the KYC documents so the Partner/host
    /// can view them during the check-in window. The URLs expire after
    /// 60 minutes. Only the vendor who owns the homestay can access this.
    /// </summary>
    [HttpGet("bookings/{bookingId:guid}/kyc/view")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(KycViewResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> ViewKycDocuments(Guid bookingId, CancellationToken ct)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized(new { Message = "Authenticated phone not found." });

        // Resolve the vendor from the authenticated phone.
        var vendor = await _context.Vendors.AsNoTracking()
            .FirstOrDefaultAsync(v => v.ContactPhone == phone && v.IsApproved, ct);
        if (vendor is null)
            return NotFound(new { Message = "Vendor profile not found." });

        // Get the booking and verify it belongs to a homestay owned by this vendor.
        var booking = await _context.ServiceBookings
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.Id == bookingId && b.ServiceType == ServiceType.Homestay, ct);
        if (booking is null)
            return NotFound(new { Message = "Booking not found." });

        var homestay = await _context.Homestays.AsNoTracking()
            .FirstOrDefaultAsync(h => h.Id == booking.HomestayId && h.HostId == vendor.Id, ct);
        if (homestay is null)
            return Unauthorized(new { Message = "You are not authorized to view this booking's KYC." });

        var kyc = await _context.GuestKycs.FirstOrDefaultAsync(k => k.BookingId == bookingId, ct);
        if (kyc is null || !kyc.IsUploaded)
            return NotFound(new { Message = "KYC documents have not been uploaded yet." });

        // Generate presigned URLs (valid for 60 minutes).
        var frontUrl = await _storage.GetPresignedUrlAsync(kyc.IdFrontUrl!, expiryMinutes: 60, cancellationToken: ct);
        string? backUrl = null;
        if (!string.IsNullOrEmpty(kyc.IdBackUrl))
            backUrl = await _storage.GetPresignedUrlAsync(kyc.IdBackUrl!, expiryMinutes: 60, cancellationToken: ct);

        kyc.MarkViewedByPartner();
        await _context.SaveChangesAsync(ct);

        return Ok(new KycViewResponse(frontUrl, backUrl, kyc.IdType, kyc.UploadedAt));
    }
}

public sealed record KycUploadResponse(Guid BookingId, bool IsUploaded, string Message);

public sealed record KycStatusResponse(Guid BookingId, bool IsUploaded, string? IdType, DateTimeOffset? UploadedAt);

public sealed record KycViewResponse(string FrontUrl, string? BackUrl, string? IdType, DateTimeOffset? UploadedAt);

public sealed record LockDatesRequest(string CheckIn, string CheckOut);

public sealed record LockDatesResponse(bool Locked, string Message);
