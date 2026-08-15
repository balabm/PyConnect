namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class RoomAvailabilityConfiguration : IEntityTypeConfiguration<RoomAvailability>
{
    public void Configure(EntityTypeBuilder<RoomAvailability> builder)
    {
        builder.ToTable("room_availability");

        builder.HasKey(r => r.Id);

        builder.Property(r => r.HomestayId).IsRequired();
        builder.HasIndex(r => r.HomestayId);

        builder.Property(r => r.Date).IsRequired();

        builder.Property(r => r.IsBooked).HasDefaultValue(false);

        builder.Property(r => r.LockedByBookingId);

        builder.HasIndex(r => new { r.HomestayId, r.Date }).IsUnique();
    }
}
