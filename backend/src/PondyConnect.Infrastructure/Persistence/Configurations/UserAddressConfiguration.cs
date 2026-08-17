namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.ValueObjects;

public sealed class UserAddressConfiguration : IEntityTypeConfiguration<UserAddress>
{
    public void Configure(EntityTypeBuilder<UserAddress> builder)
    {
        builder.ToTable("user_addresses");

        builder.HasKey(a => a.Id);

        builder.Property(a => a.UserId).IsRequired();

        builder.Property(a => a.DoorFlat)
            .HasMaxLength(50);

        builder.Property(a => a.Landmark)
            .HasMaxLength(200);

        builder.Property(a => a.Tag)
            .HasMaxLength(20)
            .IsRequired();

        builder.Property(a => a.FormattedAddress)
            .HasMaxLength(500)
            .IsRequired();

        builder.OwnsOne(a => a.Location, loc =>
        {
            loc.Property(l => l.Latitude).HasColumnName("latitude").HasColumnType("double precision");
            loc.Property(l => l.Longitude).HasColumnName("longitude").HasColumnType("double precision");
        });

        builder.Property(a => a.CreatedAt).HasColumnType("timestamptz");
        builder.Property(a => a.UpdatedAt).HasColumnType("timestamptz");

        builder.HasIndex(a => a.UserId);
    }
}
