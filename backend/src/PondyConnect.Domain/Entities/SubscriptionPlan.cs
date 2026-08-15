namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;
using System.Collections.Generic;

/// <summary>
/// A subscription plan (Pro / Weekend) with associated perks.
/// </summary>
public sealed class SubscriptionPlan : BaseEntity
{
    public string Name { get; private set; } = string.Empty;

    public string? Description { get; private set; }

    public SubscriptionPlanType PlanType { get; private set; }

    public decimal Price { get; private set; }

    public int DurationDays { get; private set; }

    public bool IsActive { get; private set; } = true;

    public IReadOnlyList<PerkType> Perks => _perks.AsReadOnly();

    private readonly List<PerkType> _perks = [];

    private SubscriptionPlan()
    {
        // EF Core
    }

    public static SubscriptionPlan Create(
        string name,
        SubscriptionPlanType planType,
        decimal price,
        int durationDays,
        string? description = null,
        IEnumerable<PerkType>? perks = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentOutOfRangeException.ThrowIfNegative(price);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(durationDays);

        var plan = new SubscriptionPlan
        {
            Name = name,
            PlanType = planType,
            Price = price,
            DurationDays = durationDays,
            Description = description
        };

        if (perks != null)
            plan._perks.AddRange(perks);

        return plan;
    }

    public void AddPerk(PerkType perk)
    {
        if (!_perks.Contains(perk))
        {
            _perks.Add(perk);
            MarkUpdated();
        }
    }

    public void RemovePerk(PerkType perk)
    {
        if (_perks.Remove(perk))
            MarkUpdated();
    }

    public void SetActive(bool active)
    {
        IsActive = active;
        MarkUpdated();
    }
}