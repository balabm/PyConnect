namespace PondyConnect.Domain.Enums;

/// <summary>
/// Types of party services that vendors can offer.
/// </summary>
public enum PartyServiceCategory
{
    /// <summary>Disc jockey / music performance.</summary>
    DJ = 0,

    /// <summary>Bartender / mixology service.</summary>
    Bartender = 1,

    /// <summary>Catering / food service for events.</summary>
    Catering = 2,

    /// <summary>Sound system / PA equipment with operator.</summary>
    SoundSystem = 3,

    /// <summary>Lighting and visual effects.</summary>
    Lighting = 4,

    /// <summary>Photography / videography.</summary>
    Photography = 5,

    /// <summary>Decoration / event styling.</summary>
    Decoration = 6,

    /// <summary>Event host / MC / anchor.</summary>
    Host = 7,

    /// <summary>Generator / power backup.</summary>
    Power = 8,

    /// <summary>Valet / parking service.</summary>
    Valet = 9,

    /// <summary>Security / bouncers.</summary>
    Security = 10,

    /// <summary>Other party-related service.</summary>
    Other = 11,
}
