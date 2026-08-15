namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class PaymentSettlementConfiguration : IEntityTypeConfiguration<PaymentSettlement>
{
    public void Configure(EntityTypeBuilder<PaymentSettlement> builder)
    {
        builder.ToTable("payment_settlements");

        builder.HasKey(s => s.Id);

        builder.Property(s => s.PaymentId)
            .IsRequired();

        builder.HasIndex(s => s.PaymentId)
            .IsUnique();

        builder.HasOne<Payment>()
            .WithOne()
            .HasForeignKey<PaymentSettlement>(s => s.PaymentId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Property(s => s.GrossAmount)
            .HasColumnType("numeric(14,2)");

        builder.Property(s => s.VendorPayout)
            .HasColumnType("numeric(14,2)");

        builder.Property(s => s.DriverPayout)
            .HasColumnType("numeric(14,2)");

        builder.Property(s => s.PlatformFee)
            .HasColumnType("numeric(14,2)");

        builder.Property(s => s.SettlementStatus)
            .HasConversion<string>()
            .HasMaxLength(20)
            .HasDefaultValue(SettlementStatus.Pending);

        builder.Property(s => s.ProcessedAt)
            .HasColumnType("timestamptz");

        builder.Property(s => s.CreatedAt)
            .HasColumnType("timestamptz");

        builder.HasIndex(s => s.ServiceBookingId);
        builder.HasIndex(s => s.FoodOrderId);
        builder.HasIndex(s => s.RideRequestId);
        builder.HasIndex(s => s.ScooterRentalId);
    }
}
