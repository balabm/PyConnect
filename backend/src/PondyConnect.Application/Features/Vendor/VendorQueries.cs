namespace PondyConnect.Application.Features.Vendor;

using MediatR;
using PondyConnect.Domain.Enums;

public sealed record GetVendorDashboardQuery(
    DateOnly? Date = null) : IRequest<VendorDashboardResponse>;

public sealed record VendorDashboardResponse(
    int TotalBookingsToday,
    int PendingBookings,
    int ConfirmedBookings,
    int CompletedBookings,
    decimal RevenueToday,
    IReadOnlyList<VendorBookingSummary> RecentBookings);

public sealed record VendorBookingSummary(
    Guid BookingId,
    string ServiceType,
    string CustomerName,
    string CustomerPhone,
    DateTimeOffset ScheduledFor,
    string Status,
    decimal Amount,
    string PaymentStatus);

public sealed record GetVendorBookingsQuery(
    DateOnly? Date = null,
    BookingStatus? Status = null,
    int Page = 1,
    int PageSize = 20) : IRequest<VendorBookingsResponse>;

public sealed record VendorBookingsResponse(
    IReadOnlyList<VendorBookingSummary> Bookings,
    int TotalCount);

public sealed record ListVendorsQuery(
    VendorCategory? Category = null,
    bool OnlyApproved = true,
    bool FoodVendorsOnly = false) : IRequest<IReadOnlyList<VendorResponse>>;

public sealed record VendorResponse(
    Guid Id,
    string Name,
    string Category,
    string? ContactPhone,
    string? MerchantReference,
    string? CuisineType,
    double? Rating,
    string? ImageUrl,
    string? Description,
    decimal? DeliveryFee,
    int? PrepTimeMinutes,
    int MenuItemCount);