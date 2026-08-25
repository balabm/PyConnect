namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class SplitPaymentPoolConfiguration : IEntityTypeConfiguration<SplitPaymentPool>
{
    public void Configure(EntityTypeBuilder<SplitPaymentPool> builder)
    {
        builder.ToTable("split_payment_pools");

        builder.HasKey(p => p.Id);

        builder.Property(p => p.CreatorUserId).IsRequired();

        builder.Property(p => p.TotalAmount)
            .HasColumnType("numeric(12,2)")
            .IsRequired();

        builder.Property(p => p.CollectedAmount)
            .HasColumnType("numeric(12,2)")
            .IsRequired();

        builder.Property(p => p.Description)
            .IsRequired()
            .HasMaxLength(500);

        builder.Property(p => p.ReferenceType).HasMaxLength(50);
        builder.Property(p => p.ReferenceId);

        builder.Property(p => p.DeepLinkSlug)
            .IsRequired()
            .HasMaxLength(120);

        builder.Property(p => p.Status)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        builder.Property(p => p.PerShareAmount)
            .HasColumnType("numeric(12,2)")
            .IsRequired();

        builder.Property(p => p.MaxShares).IsRequired();
        builder.Property(p => p.ClaimedShares).IsRequired();

        builder.Property(p => p.CreatedAt).HasColumnType("timestamptz");
        builder.Property(p => p.UpdatedAt).HasColumnType("timestamptz");
        builder.Property(p => p.ExpiresAt).HasColumnType("timestamptz").IsRequired();

        builder.HasIndex(p => p.DeepLinkSlug).IsUnique();
        builder.HasIndex(p => p.CreatorUserId);
        builder.HasIndex(p => p.Status);
    }
}

public sealed class SplitPaymentContributorConfiguration : IEntityTypeConfiguration<SplitPaymentContributor>
{
    public void Configure(EntityTypeBuilder<SplitPaymentContributor> builder)
    {
        builder.ToTable("split_payment_contributors");

        builder.HasKey(c => c.Id);

        builder.Property(c => c.PoolId).IsRequired();
        builder.Property(c => c.UserId).IsRequired();

        builder.Property(c => c.ShareAmount)
            .HasColumnType("numeric(12,2)")
            .IsRequired();

        builder.Property(c => c.PaidAmount)
            .HasColumnType("numeric(12,2)")
            .IsRequired();

        builder.Property(c => c.Status)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        builder.Property(c => c.PaidAt).HasColumnType("timestamptz");
        builder.Property(c => c.CreatedAt).HasColumnType("timestamptz");
        builder.Property(c => c.UpdatedAt).HasColumnType("timestamptz");

        builder.HasIndex(c => c.PoolId);
        builder.HasIndex(c => c.UserId);
        builder.HasIndex(c => new { c.PoolId, c.UserId }).IsUnique();
    }
}
