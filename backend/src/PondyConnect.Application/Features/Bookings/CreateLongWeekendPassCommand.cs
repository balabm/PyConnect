namespace PondyConnect.Application.Features.Bookings;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using System.Security.Cryptography;
using System.Text;

public sealed record CreateLongWeekendPassCommand(int Days = 3) : IRequest<LongWeekendPassResponse>;

public sealed record LongWeekendPassResponse(
    Guid BundleId,
    string Name,
    decimal TotalPrice,
    decimal DiscountedPrice,
    string PassToken,
    DateTimeOffset ExpiresAt,
    IReadOnlyList<LongWeekendPassItemResponse> Items);

public sealed record LongWeekendPassItemResponse(
    string ServiceName,
    decimal OriginalPrice,
    ExperienceCategory? Category);

public sealed class CreateLongWeekendPassHandler : IRequestHandler<CreateLongWeekendPassCommand, LongWeekendPassResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CreateLongWeekendPassHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<LongWeekendPassResponse> Handle(CreateLongWeekendPassCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");

        var days = Math.Clamp(request.Days, 1, 7);
        var expiresAt = DateTimeOffset.UtcNow.AddDays(days);

        var items = new List<(string Name, decimal Price, ExperienceCategory? Category)>
        {
            ("Scooter Rental (24h)", 300m, ExperienceCategory.LongTermScooterLease),
            ("Luggage Cloak (24h)", 80m, null),
            ("Venue Entry Pass", 200m, null),
            ("Transit Pickup", 150m, null)
        };

        var totalPrice = items.Sum(i => i.Price);
        var discountedPrice = Math.Round(totalPrice * 0.8m, 2);

        var bundle = BundleBooking.Create(
            userId: userId,
            name: $"Long Weekend Pass ({days} Day{(days > 1 ? "s" : "")})",
            totalPrice: totalPrice,
            discountedPrice: discountedPrice,
            description: "All-in-one pass: scooter rental, luggage cloak, venue entry, and transit pickup.",
            expiresAt: expiresAt,
            passType: PassType.WeekendPass);

        _context.BundleBookings.Add(bundle);
        await _context.SaveChangesAsync(cancellationToken);

        foreach (var (name, price, category) in items)
        {
            var item = BundleItem.Create(bundle.Id, name, price, experienceCategory: category);
            _context.BundleItems.Add(item);
            bundle.AddItem(item);
        }

        var passToken = WeekendPassIssuer.Issue(bundle.Id, userId, expiresAt);
        bundle.IssuePass(passToken);

        await _context.SaveChangesAsync(cancellationToken);

        var responseItems = items
            .Select(i => new LongWeekendPassItemResponse(i.Name, i.Price, i.Category))
            .ToList();

        return new LongWeekendPassResponse(
            bundle.Id,
            bundle.Name,
            bundle.TotalPrice,
            bundle.DiscountedPrice,
            bundle.PassToken!,
            bundle.ExpiresAt!.Value,
            responseItems);
    }
}

public static class WeekendPassIssuer
{
    private static readonly HMACSHA256 s_hmac =
        new(Encoding.UTF8.GetBytes("pondyconnect-weekendpass-v1"));

    public static string Issue(Guid bundleId, Guid userId, DateTimeOffset expiresAt)
    {
        var raw = Encoding.UTF8.GetBytes($"LWP|{bundleId:N}|{userId:N}|{expiresAt:O}");
        var hash = s_hmac.ComputeHash(raw);
        return Convert.ToBase64String(hash).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    }
}
