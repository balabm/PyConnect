namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class PayoutRequestConfiguration : IEntityTypeConfiguration<PayoutRequest>
{
    public void Configure(EntityTypeBuilder<PayoutRequest> builder)
    {
        builder.ToTable("payout_requests");

        builder.HasKey(p => p.Id);

        builder.Property(p => p.RecipientType).HasConversion<int>().IsRequired();
        builder.Property(p => p.RecipientId).IsRequired();
        builder.Property(p => p.Amount).HasColumnType("numeric(14,2)").IsRequired();
        builder.Property(p => p.TdsDeducted).HasColumnType("numeric(14,2)").IsRequired();
        builder.Property(p => p.NetAmount).HasColumnType("numeric(14,2)").IsRequired();
        builder.Property(p => p.Status).HasConversion<int>().IsRequired();
        builder.Property(p => p.DestinationAccount).HasMaxLength(50);
        builder.Property(p => p.DestinationIfsc).HasMaxLength(20);
        builder.Property(p => p.DestinationUpi).HasMaxLength(100);
        builder.Property(p => p.ProviderPayoutId).HasMaxLength(100);
        builder.Property(p => p.UtrNumber).HasMaxLength(50);
        builder.Property(p => p.FailureReason).HasMaxLength(500);
        builder.Property(p => p.SettlementIds).HasMaxLength(2000);
        builder.Property(p => p.ProcessedAt).HasColumnType("timestamptz");
        builder.Property(p => p.FailedAt).HasColumnType("timestamptz");
        builder.Property(p => p.UpdatedAt).HasColumnType("timestamptz");
        builder.Property(p => p.CreatedAt).HasColumnType("timestamptz");

        builder.HasIndex(p => p.RecipientId);
        builder.HasIndex(p => p.Status);
        builder.HasIndex(p => p.ProviderPayoutId);
    }
}
