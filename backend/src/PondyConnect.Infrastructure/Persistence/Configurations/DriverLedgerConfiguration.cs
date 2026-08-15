namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class DriverLedgerConfiguration : IEntityTypeConfiguration<DriverLedgerEntry>
{
    public void Configure(EntityTypeBuilder<DriverLedgerEntry> builder)
    {
        builder.ToTable("driver_ledger_entries");

        builder.HasKey(e => e.Id);

        builder.Property(e => e.DriverId).IsRequired();
        builder.Property(e => e.Amount).HasPrecision(18, 2);
        builder.Property(e => e.TransactionType).HasConversion<string>().HasMaxLength(20);
        builder.Property(e => e.Reference).HasMaxLength(200);
        builder.Property(e => e.CreatedAt).HasColumnType("timestamptz");

        builder.HasIndex(e => e.DriverId);
        builder.HasIndex(e => e.CreatedAt);
    }
}
