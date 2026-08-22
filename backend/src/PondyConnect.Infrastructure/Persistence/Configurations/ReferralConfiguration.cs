namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class ReferralConfiguration : IEntityTypeConfiguration<Referral>
{
    public void Configure(EntityTypeBuilder<Referral> builder)
    {
        builder.ToTable("referrals");

        builder.HasKey(r => r.Id);

        builder.Property(r => r.ReferrerId).IsRequired();
        builder.Property(r => r.ReferredUserId).IsRequired();
        builder.Property(r => r.ReferralCode).HasMaxLength(20).IsRequired();
        builder.Property(r => r.Status).HasConversion<int>().IsRequired();
        builder.Property(r => r.WelcomeCredit).HasColumnType("numeric(14,2)").IsRequired();
        builder.Property(r => r.ReferrerReward).HasColumnType("numeric(14,2)").IsRequired();
        builder.Property(r => r.CreatedAt).HasColumnType("timestamptz").IsRequired();
        builder.Property(r => r.CompletedAt).HasColumnType("timestamptz");
        builder.Property(r => r.TriggeringOrderId);
        builder.Property(r => r.UpdatedAt).HasColumnType("timestamptz");
        builder.Property(r => r.CreatedAt).HasColumnType("timestamptz");

        builder.HasIndex(r => r.ReferrerId);
        builder.HasIndex(r => r.ReferredUserId).IsUnique();
        builder.HasIndex(r => r.ReferralCode);
    }
}
