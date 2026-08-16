namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class DriverWalletConfiguration : IEntityTypeConfiguration<DriverWallet>
{
    public void Configure(EntityTypeBuilder<DriverWallet> builder)
    {
        builder.ToTable("driver_wallets");

        builder.HasKey(w => w.Id);

        builder.Property(w => w.DriverId)
            .IsRequired();

        // One wallet per driver.
        builder.HasIndex(w => w.DriverId)
            .IsUnique();

        builder.HasOne(w => w.Driver)
            .WithOne()
            .HasForeignKey<DriverWallet>(w => w.DriverId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Property(w => w.Balance)
            .HasPrecision(18, 2)
            .HasDefaultValue(0m);

        builder.Property(w => w.HardLimit)
            .HasPrecision(18, 2)
            .HasDefaultValue(-1000.00m);

        builder.Property(w => w.Currency)
            .IsRequired()
            .HasMaxLength(3)
            .HasDefaultValue("INR");

        builder.Property(w => w.Suspended)
            .HasDefaultValue(false);

        builder.Property(w => w.LastSettledAt)
            .HasColumnType("timestamptz");

        builder.Property(w => w.CreatedAt)
            .HasColumnType("timestamptz");

        builder.Property(w => w.UpdatedAt)
            .HasColumnType("timestamptz");
    }
}
