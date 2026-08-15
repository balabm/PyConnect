namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class WaitlistEntryConfiguration : IEntityTypeConfiguration<WaitlistEntry>
{
    public void Configure(EntityTypeBuilder<WaitlistEntry> builder)
    {
        builder.ToTable("waitlist_entries");

        builder.HasKey(w => w.Id);

        builder.Property(w => w.PhoneNumber)
            .IsRequired()
            .HasMaxLength(15);

        builder.HasIndex(w => w.PhoneNumber)
            .IsUnique();

        builder.Property(w => w.SourceQrCodeLocation)
            .HasMaxLength(200);

        builder.Property(w => w.CreatedAt)
            .HasColumnType("timestamptz");

        builder.Property(w => w.ConvertedAt)
            .HasColumnType("timestamptz");

        builder.Property(w => w.IsConverted)
            .HasDefaultValue(false);
    }
}
