namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class LedgerEntryConfiguration : IEntityTypeConfiguration<LedgerEntry>
{
    public void Configure(EntityTypeBuilder<LedgerEntry> builder)
    {
        builder.ToTable("ledger_entries");

        builder.HasKey(e => e.Id);

        builder.Property(e => e.TransactionId).IsRequired();
        builder.Property(e => e.Account).HasConversion<int>().IsRequired();
        builder.Property(e => e.IsDebit).IsRequired();
        builder.Property(e => e.Amount).HasColumnType("numeric(14,2)").IsRequired();
        builder.Property(e => e.ReferenceType).HasMaxLength(50).IsRequired();
        builder.Property(e => e.ReferenceId).IsRequired();
        builder.Property(e => e.Description).HasMaxLength(500).IsRequired();
        builder.Property(e => e.UpdatedAt).HasColumnType("timestamptz");
        builder.Property(e => e.CreatedAt).HasColumnType("timestamptz");

        builder.HasIndex(e => e.TransactionId);
        builder.HasIndex(e => new { e.Account, e.ReferenceType });
        builder.HasIndex(e => e.VendorId);
        builder.HasIndex(e => e.DriverId);
    }
}
