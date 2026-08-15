namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class DispatchTaskConfiguration : IEntityTypeConfiguration<DispatchTask>
{
    public void Configure(EntityTypeBuilder<DispatchTask> builder)
    {
        builder.ToTable("dispatch_tasks");

        builder.HasKey(t => t.Id);

        builder.Property(t => t.TaskType).HasConversion<string>().HasMaxLength(20);
        builder.Property(t => t.SourceEntityId);
        builder.Property(t => t.DriverId);
        builder.Property(t => t.PickupAddress).HasMaxLength(300).IsRequired();
        builder.Property(t => t.DropoffAddress).HasMaxLength(300).IsRequired();
        builder.Property(t => t.DriverEarnings).HasPrecision(10, 2);
        builder.Property(t => t.Status).HasConversion<string>().HasMaxLength(20).HasDefaultValue(DispatchTaskStatus.Available);
        builder.Property(t => t.CreatedAt).HasColumnType("timestamptz");

        builder.OwnsOne(t => t.PickupLocation, loc =>
        {
            loc.Property(l => l.Latitude).HasColumnName("pickup_lat").HasColumnType("double precision");
            loc.Property(l => l.Longitude).HasColumnName("pickup_lng").HasColumnType("double precision");
        });

        builder.OwnsOne(t => t.DropoffLocation, loc =>
        {
            loc.Property(l => l.Latitude).HasColumnName("dropoff_lat").HasColumnType("double precision");
            loc.Property(l => l.Longitude).HasColumnName("dropoff_lng").HasColumnType("double precision");
        });

        builder.HasIndex(t => t.DriverId);
        builder.HasIndex(t => t.Status);
        builder.HasIndex(t => t.TaskType);
    }
}
