namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// A business partner (luggage cloak shop, scooter rental, taxi operator,
/// pub/club, bakery, etc.) that fulfils ServiceBookings.
/// </summary>
public sealed class Vendor : BaseEntity
{
    public string Name { get; private set; } = string.Empty;

    public string? ContactPhone { get; private set; }

    public string? MerchantReference { get; private set; }

    public VendorCategory Category { get; private set; }

    public bool IsApproved { get; private set; }

    public bool IsActive { get; private set; } = true;

    /// <summary>
    /// Master toggle: when false, the vendor is not accepting new orders.
    /// Broadcasts in real-time to the consumer app via SignalR so cards are
    /// greyed out and "Add to Cart" is disabled instantly.
    /// </summary>
    public bool IsAcceptingOrders { get; private set; } = true;

    public SaaSTier SaaSTier { get; private set; } = SaaSTier.Free;

    public DateTimeOffset? SaaSPlanExpiry { get; private set; }

    public decimal MonthlyFee { get; private set; }

    public decimal CreditBalance { get; private set; }

    // Restaurant-specific metadata (nullable — only set for food vendors)
    public string? CuisineType { get; private set; }
    public double? Rating { get; private set; }
    public string? ImageUrl { get; private set; }
    public string? Description { get; private set; }
    public decimal? DeliveryFee { get; private set; }
    public int? PrepTimeMinutes { get; private set; }

    /// <summary>
    /// Dynamic prep buffer added to estimated delivery times when the
    /// kitchen is overloaded. Set by the KdsThrottlingWorker when 5+
    /// orders remain in Preparing state for >20 minutes. Reset to 0
    /// when the backlog clears.
    /// </summary>
    public int DynamicPrepBufferMinutes { get; private set; }

    /// <summary>
    /// Whether the vendor has manually enabled Busy Mode via the KDS.
    /// Temporarily raises the prep buffer and restricts incoming pings.
    /// </summary>
    public bool IsBusyMode { get; private set; }

    /// <summary>
    /// FCM device token for push notifications to the vendor's partner app.
    /// Updated when the vendor logs in and the Flutter app registers its token.
    /// </summary>
    public string? FcmDeviceToken { get; private set; }

    // --- Self-onboarding KYC & business documents ---

    /// <summary>FSSAI license number (food vendors).</summary>
    public string? FssaiNumber { get; private set; }

    /// <summary>GSTIN (Goods and Services Tax Identification Number).</summary>
    public string? GstNumber { get; private set; }

    /// <summary>PAN (Permanent Account Number).</summary>
    public string? PanNumber { get; private set; }

    /// <summary>Storage key for the FSSAI certificate image.</summary>
    public string? FssaiDocUrl { get; private set; }

    /// <summary>Storage key for the GST certificate image.</summary>
    public string? GstDocUrl { get; private set; }

    /// <summary>Storage key for the PAN card image.</summary>
    public string? PanDocUrl { get; private set; }

    /// <summary>Bank account number for payouts.</summary>
    public string? BankAccountNumber { get; private set; }

    /// <summary>IFSC code for the bank account.</summary>
    public string? BankIfsc { get; private set; }

    /// <summary>Name on the bank account.</summary>
    public string? BankAccountName { get; private set; }

    /// <summary>Whether the vendor has submitted onboarding documents.</summary>
    public bool IsKycSubmitted { get; private set; }

    private Vendor()
    {
        // EF Core constructor.
    }

    public static Vendor Create(
        string name,
        VendorCategory category,
        string? contactPhone = null,
        string? merchantReference = null,
        string? cuisineType = null,
        double? rating = null,
        string? imageUrl = null,
        string? description = null,
        decimal? deliveryFee = null,
        int? prepTimeMinutes = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        return new Vendor
        {
            Name = name,
            Category = category,
            ContactPhone = contactPhone,
            MerchantReference = merchantReference,
            CuisineType = cuisineType,
            Rating = rating,
            ImageUrl = imageUrl,
            Description = description,
            DeliveryFee = deliveryFee,
            PrepTimeMinutes = prepTimeMinutes
        };
    }

    /// <summary>
    /// Seed-specific factory that pins the identity so tests and the B2B
    /// portal can rely on a stable vendor id (e.g. Fuoco Pizzeria = 1).
    /// </summary>
    public static Vendor CreateForSeed(
        Guid id,
        string name,
        VendorCategory category,
        string? contactPhone = null,
        string? merchantReference = null,
        string? cuisineType = null,
        double? rating = null,
        string? imageUrl = null,
        string? description = null,
        decimal? deliveryFee = null,
        int? prepTimeMinutes = null)
    {
        var vendor = Create(name, category, contactPhone, merchantReference, cuisineType, rating, imageUrl, description, deliveryFee, prepTimeMinutes);
        vendor.SetExplicitId(id);
        return vendor;
    }

    public void UpdateRestaurantDetails(
        string? cuisineType = null,
        double? rating = null,
        string? imageUrl = null,
        string? description = null,
        decimal? deliveryFee = null,
        int? prepTimeMinutes = null)
    {
        CuisineType = cuisineType ?? CuisineType;
        Rating = rating ?? Rating;
        ImageUrl = imageUrl ?? ImageUrl;
        Description = description ?? Description;
        DeliveryFee = deliveryFee ?? DeliveryFee;
        PrepTimeMinutes = prepTimeMinutes ?? PrepTimeMinutes;
        MarkUpdated();
    }

    public void Approve()
    {
        IsApproved = true;
        MarkUpdated();
    }

    public void Deactivate()
    {
        IsActive = false;
        MarkUpdated();
    }

    /// <summary>
    /// Toggles the master "Accepting Orders" switch. When set to false,
    /// the consumer app greys out the vendor card and disables ordering
    /// in real-time via SignalR.
    /// </summary>
    public void SetAcceptingOrders(bool isAcceptingOrders)
    {
        IsAcceptingOrders = isAcceptingOrders;
        MarkUpdated();
    }

    /// <summary>
    /// Sets the dynamic prep buffer minutes. Called by the
    /// KdsThrottlingWorker when the kitchen is overloaded.
    /// </summary>
    public void SetDynamicPrepBuffer(int bufferMinutes)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(bufferMinutes, nameof(bufferMinutes));
        DynamicPrepBufferMinutes = bufferMinutes;
        MarkUpdated();
    }

    /// <summary>
    /// Toggles Busy Mode. When enabled, raises the prep buffer by 30
    /// minutes and restricts incoming order pings.
    /// </summary>
    public void SetBusyMode(bool isBusy)
    {
        IsBusyMode = isBusy;
        DynamicPrepBufferMinutes = isBusy ? Math.Max(DynamicPrepBufferMinutes, 30) : 0;
        MarkUpdated();
    }

    public void SetSaaSTier(SaaSTier tier, decimal monthlyFee, int durationDays = 30)
    {
        SaaSTier = tier;
        MonthlyFee = monthlyFee;
        SaaSPlanExpiry = DateTimeOffset.UtcNow.AddDays(durationDays);
        MarkUpdated();
    }

    public void DeductCredit(decimal amount)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(amount, nameof(amount));
        if (amount > CreditBalance)
            throw new InvalidOperationException("Insufficient credit balance.");
        CreditBalance -= amount;
        MarkUpdated();
    }

    public void TopUpCredit(decimal amount)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(amount, nameof(amount));
        CreditBalance += amount;
        MarkUpdated();
    }

    public void UpdateFcmDeviceToken(string token)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(token);
        FcmDeviceToken = token;
        MarkUpdated();
    }

    public void ClearFcmDeviceToken()
    {
        FcmDeviceToken = null;
        MarkUpdated();
    }

    /// <summary>
    /// Submits self-onboarding KYC documents and business registration details.
    /// Called by the partner app during the self-registration flow.
    /// </summary>
    public void SubmitKyc(
        string? fssaiNumber,
        string? gstNumber,
        string? panNumber,
        string? fssaiDocUrl,
        string? gstDocUrl,
        string? panDocUrl,
        string? bankAccountNumber,
        string? bankIfsc,
        string? bankAccountName)
    {
        FssaiNumber = fssaiNumber;
        GstNumber = gstNumber;
        PanNumber = panNumber;
        FssaiDocUrl = fssaiDocUrl;
        GstDocUrl = gstDocUrl;
        PanDocUrl = panDocUrl;
        BankAccountNumber = bankAccountNumber;
        BankIfsc = bankIfsc;
        BankAccountName = bankAccountName;
        IsKycSubmitted = true;
        MarkUpdated();
    }

    /// <summary>
    /// Updates the vendor's operating hours stored as a JSON string.
    /// Format: { "mon": {"open": "09:00", "close": "22:00"}, ... }
    /// </summary>
    public void UpdateOperatingHours(string hoursJson)
    {
        OperatingHours = hoursJson;
        MarkUpdated();
    }

    /// <summary>JSON-encoded operating hours schedule.</summary>
    public string? OperatingHours { get; private set; }
}