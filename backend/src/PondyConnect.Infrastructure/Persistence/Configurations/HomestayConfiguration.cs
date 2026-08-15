namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class HomestayConfiguration : IEntityTypeConfiguration<Homestay>
{
    public void Configure(EntityTypeBuilder<Homestay> builder)
    {
        builder.ToTable("homestays");

        builder.HasKey(h => h.Id);

        builder.Property(h => h.HostId).IsRequired();
        builder.HasIndex(h => h.HostId);

        builder.Property(h => h.Name).IsRequired().HasMaxLength(200);
        builder.Property(h => h.Description).IsRequired().HasMaxLength(2000);
        builder.Property(h => h.LocationArea).IsRequired().HasMaxLength(100);

        builder.Property(h => h.Latitude).IsRequired();
        builder.Property(h => h.Longitude).IsRequired();

        builder.Property(h => h.NightlyRate).IsRequired().HasPrecision(10, 2);

        builder.Property(h => h.MaxGuests).IsRequired();

        builder.Property(h => h.HasWifi).HasDefaultValue(false);
        builder.Property(h => h.IsVerified).HasDefaultValue(false);
    }
}
