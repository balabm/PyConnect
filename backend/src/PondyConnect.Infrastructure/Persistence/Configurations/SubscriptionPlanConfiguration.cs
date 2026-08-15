namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class SubscriptionPlanConfiguration : IEntityTypeConfiguration<SubscriptionPlan>
{
    public void Configure(EntityTypeBuilder<SubscriptionPlan> builder)
    {
        builder.ToTable("subscription_plans");

        builder.HasKey(p => p.Id);

        builder.Property(p => p.Name)
            .IsRequired()
            .HasMaxLength(80);

        builder.Property(p => p.Description)
            .HasMaxLength(500);

        builder.Property(p => p.PlanType)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(p => p.Price)
            .HasPrecision(10, 2);

        builder.Property(p => p.DurationDays)
            .IsRequired();

        builder.Property(p => p.IsActive)
            .IsRequired();

        builder.Property(p => p.CreatedAt)
            .HasColumnType("timestamptz");

        builder.HasIndex(p => p.PlanType);
        builder.HasIndex(p => p.IsActive);
    }
}