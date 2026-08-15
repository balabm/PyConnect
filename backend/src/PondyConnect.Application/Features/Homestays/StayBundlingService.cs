namespace PondyConnect.Application.Features.Homestays;

public sealed record AddOnSuggestion(
    string Name,
    string Description,
    decimal Price,
    bool IsFree,
    decimal DiscountPercentage);

public sealed class StayBundlingService
{
    public static readonly TimeSpan StandardCheckInTime = new(12, 0, 0);

    public static List<AddOnSuggestion> GenerateAddOnSuggestions(
        DateTimeOffset checkIn,
        bool hasTransitBooking,
        bool hasLuggageBooking)
    {
        var suggestions = new List<AddOnSuggestion>();

        if (!hasTransitBooking)
        {
            suggestions.Add(new AddOnSuggestion(
                Name: "Scooter Pick-up at Bus Stand",
                Description: "Get picked up at the bus stand on your scooter. 10% discount when bundled with your stay.",
                Price: 270m,
                IsFree: false,
                DiscountPercentage: 10m));
        }

        if (!hasLuggageBooking)
        {
            suggestions.Add(new AddOnSuggestion(
                Name: "Early Arrival Luggage Cloak",
                Description: "Drop your bags early before check-in. Free when bundled with your stay.",
                Price: 0m,
                IsFree: true,
                DiscountPercentage: 0m));
        }

        return suggestions;
    }
}
