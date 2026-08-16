namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class DriverWalletTransactionConfiguration : IEntityTypeConfiguration<DriverWalletTransaction>
{
    public void Configure(EntityTypeBuilder<DriverWalletTransaction> builder)
    {
        builder.ToTable("driver_wallet_transactions");

        builder.HasKey(t => t.Id);

        builder.Property(t => t.WalletId)
            .IsRequired();

        builder.Property(t => t.Type)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        builder.Property(t => t.Amount)
            .HasPrecision(18, 2);

        builder.Property(t => t.Description)
            .IsRequired()
            .HasMaxLength(300);

        builder.Property(t => t.ReferenceId)
            .HasMaxLength(200);

        builder.Property(t => t.CreatedAt)
            .HasColumnType("timestamptz");

        // Supports "recent transactions for a wallet" ordered by time.
        builder.HasIndex(t => new { t.WalletId, t.CreatedAt });

        builder.HasOne(t => t.Wallet)
            .WithMany()
            .HasForeignKey(t => t.WalletId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
