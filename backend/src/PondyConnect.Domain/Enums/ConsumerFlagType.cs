namespace PondyConnect.Domain.Enums;

/// <summary>
/// Categorises the reason a consumer was flagged for fraud prevention.
/// </summary>
public enum ConsumerFlagType
{
    /// <summary>Consumer cancels rides frequently after a driver is assigned.</summary>
    HighCancellationRate = 1,

    /// <summary>Consumer exhibited fraudulent behaviour (e.g. fake orders, abuse).</summary>
    FraudulentBehavior = 2,

    /// <summary>Consumer has an unresolved payment dispute.</summary>
    PaymentDispute = 3,
}
