namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class DriverWithdrawalConfiguration : IEntityTypeConfiguration<DriverWithdrawal>
{
    public void Configure(EntityTypeBuilder<DriverWithdrawal> builder)
    {
        builder.ToTable("driver_withdrawals");

        builder.HasKey(w => w.Id);

        builder.Property(w => w.DriverId)
            .IsRequired();

        builder.Property(w => w.WalletId)
            .IsRequired();

        builder.Property(w => w.Amount)
            .HasPrecision(18, 2);

        builder.Property(w => w.Status)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        builder.Property(w => w.BankAccountNumber)
            .HasMaxLength(50);

        builder.Property(w => w.UpiId)
            .HasMaxLength(100);

        builder.Property(w => w.RequestedAt)
            .HasColumnType("timestamptz");

        builder.Property(w => w.ProcessedAt)
            .HasColumnType("timestamptz");

        builder.Property(w => w.AdminNote)
            .HasMaxLength(500);

        builder.Property(w => w.CreatedAt)
            .HasColumnType("timestamptz");

        builder.Property(w => w.UpdatedAt)
            .HasColumnType("timestamptz");

        builder.HasIndex(w => new { w.DriverId, w.Status });
        builder.HasIndex(w => w.Status);

        builder.HasOne(w => w.Driver)
            .WithMany()
            .HasForeignKey(w => w.DriverId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(w => w.Wallet)
            .WithMany()
            .HasForeignKey(w => w.WalletId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
