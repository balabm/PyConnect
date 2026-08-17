namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

public sealed class DriverConfiguration : IEntityTypeConfiguration<Driver>
{
    public void Configure(EntityTypeBuilder<Driver> builder)
    {
        builder.ToTable("drivers");

        builder.HasKey(d => d.Id);

        builder.Property(d => d.UserId).IsRequired();
        builder.Property(d => d.Name).HasMaxLength(120).IsRequired();
        builder.Property(d => d.Phone).HasMaxLength(15).IsRequired();
        builder.Property(d => d.VehicleType).HasConversion<string>().HasMaxLength(20);
        builder.Property(d => d.VehiclePlate).HasMaxLength(20);
        builder.Property(d => d.Rating).HasPrecision(3, 2);
        builder.Property(d => d.AcceptanceRate).HasPrecision(5, 4).HasDefaultValue(1.0);
        builder.Property(d => d.CancellationRate).HasPrecision(5, 4).HasDefaultValue(0.0);
        builder.Property(d => d.IsOnRide).HasDefaultValue(false);
        builder.Property(d => d.CurrentRideId);
        builder.Property(d => d.LastLocationAt).HasColumnType("timestamptz");
        builder.Property(d => d.EmergencyContactName).HasMaxLength(120);
        builder.Property(d => d.EmergencyContactPhone).HasMaxLength(15);

        builder.OwnsOne(d => d.CurrentLocation, loc =>
        {
            loc.Property(l => l.Latitude).HasColumnName("location_lat").HasColumnType("double precision");
            loc.Property(l => l.Longitude).HasColumnName("location_lng").HasColumnType("double precision");
        });

        builder.Property(d => d.CreatedAt).HasColumnType("timestamptz");

        builder.Property(d => d.AadhaarUrl).HasMaxLength(500);
        builder.Property(d => d.DrivingLicenseUrl).HasMaxLength(500);
        builder.Property(d => d.RcUrl).HasMaxLength(500);
        builder.Property(d => d.UpiId).HasMaxLength(50);
        builder.Property(d => d.IsKycUploaded).HasDefaultValue(false);

        builder.Property(d => d.KycAutoApproved);
        builder.Property(d => d.KycConfidence).HasPrecision(3, 2);
        builder.Property(d => d.KycVerificationReason).HasMaxLength(500);
        builder.Property(d => d.KycParsedName).HasMaxLength(120);
        builder.Property(d => d.KycLicenseNumber).HasMaxLength(50);
        builder.Property(d => d.KycExpiryDate).HasColumnType("timestamptz");
        builder.Property(d => d.FcmDeviceToken).HasMaxLength(512);

        builder.HasIndex(d => d.UserId);
        builder.HasIndex(d => d.IsOnline);
        builder.HasIndex(d => d.IsApproved);
        builder.HasIndex(d => d.IsOnRide);
    }
}

public sealed class RideRequestConfiguration : IEntityTypeConfiguration<RideRequest>
{
    public void Configure(EntityTypeBuilder<RideRequest> builder)
    {
        builder.ToTable("ride_requests");

        builder.HasKey(r => r.Id);

        builder.Property(r => r.UserId).IsRequired();
        builder.Property(r => r.PickupAddress).HasMaxLength(300).IsRequired();
        builder.Property(r => r.DropoffAddress).HasMaxLength(300).IsRequired();
        builder.Property(r => r.DistanceKm).HasPrecision(8, 2);
        builder.Property(r => r.ActualDistanceKm).HasPrecision(8, 2);
        builder.Property(r => r.VehicleType).HasConversion<string>().HasMaxLength(20);
        builder.Property(r => r.Fare).HasPrecision(10, 2);
        builder.Property(r => r.PlatformBookingFee).HasPrecision(10, 2);
        builder.Property(r => r.TotalAmount).HasPrecision(10, 2);
        builder.Property(r => r.PaymentMethod).HasConversion<string>().HasMaxLength(20);
        builder.Property(r => r.Status).HasConversion<string>().HasMaxLength(25);
        builder.Property(r => r.CancelReason).HasMaxLength(300);
        builder.Property(r => r.CancelledBy).HasConversion<string>().HasMaxLength(20);
        builder.Property(r => r.CancellationFee).HasPrecision(10, 2).HasDefaultValue(0m);
        builder.Property(r => r.IsSos).HasDefaultValue(false);
        builder.Property(r => r.SosDriverPayout).HasPrecision(10, 2).HasDefaultValue(0m);
        builder.Property(r => r.PlatformEmergencyFee).HasPrecision(10, 2).HasDefaultValue(0m);

        // Surge pricing fields
        builder.Property(r => r.SurgeMultiplier).HasPrecision(3, 2).HasDefaultValue(1.0m);
        builder.Property(r => r.SurgeReason).HasMaxLength(200);
        builder.Property(r => r.BaseFare).HasPrecision(10, 2).HasDefaultValue(0m);
        builder.Property(r => r.DistanceFare).HasPrecision(10, 2).HasDefaultValue(0m);
        builder.Property(r => r.TimeFare).HasPrecision(10, 2).HasDefaultValue(0m);

        // OTP verification
        builder.Property(r => r.OtpCode).HasMaxLength(10);
        builder.Property(r => r.OtpVerifiedAt).HasColumnType("timestamptz");

        // Ratings
        builder.Property(r => r.RatingByRider);
        builder.Property(r => r.RatingByDriver);
        builder.Property(r => r.RiderFeedback).HasMaxLength(500);
        builder.Property(r => r.DriverFeedback).HasMaxLength(500);

        // Trip sharing
        builder.Property(r => r.TripShareToken);
        builder.HasIndex(r => r.TripShareToken).IsUnique().HasFilter("\"TripShareToken\" IS NOT NULL");

        builder.OwnsOne(r => r.PickupLocation, loc =>
        {
            loc.Property(l => l.Latitude).HasColumnName("pickup_lat").HasColumnType("double precision");
            loc.Property(l => l.Longitude).HasColumnName("pickup_lng").HasColumnType("double precision");
        });

        builder.OwnsOne(r => r.DropoffLocation, loc =>
        {
            loc.Property(l => l.Latitude).HasColumnName("dropoff_lat").HasColumnType("double precision");
            loc.Property(l => l.Longitude).HasColumnName("dropoff_lng").HasColumnType("double precision");
        });

        builder.Property(r => r.RequestedAt).HasColumnType("timestamptz");
        builder.Property(r => r.AcceptedAt).HasColumnType("timestamptz");
        builder.Property(r => r.DriverAssignedAt).HasColumnType("timestamptz");
        builder.Property(r => r.ArrivedAtPickupAt).HasColumnType("timestamptz");
        builder.Property(r => r.StartedAt).HasColumnType("timestamptz");
        builder.Property(r => r.CompletedAt).HasColumnType("timestamptz");
        builder.Property(r => r.CancelledAt).HasColumnType("timestamptz");

        builder.HasIndex(r => r.UserId);
        builder.HasIndex(r => r.DriverId);
        builder.HasIndex(r => r.Status);
    }
}

public sealed class RideEventConfiguration : IEntityTypeConfiguration<RideEvent>
{
    public void Configure(EntityTypeBuilder<RideEvent> builder)
    {
        builder.ToTable("ride_events");

        builder.HasKey(e => e.Id);

        builder.Property(e => e.RideId).IsRequired();
        builder.Property(e => e.EventType).HasConversion<string>().HasMaxLength(30);
        builder.Property(e => e.Timestamp).HasColumnType("timestamptz").IsRequired();
        builder.Property(e => e.ActorUserId);
        builder.Property(e => e.Metadata).HasColumnType("jsonb");

        builder.HasIndex(e => e.RideId);
        builder.HasIndex(e => e.Timestamp);
    }
}

public sealed class EmergencyContactConfiguration : IEntityTypeConfiguration<EmergencyContact>
{
    public void Configure(EntityTypeBuilder<EmergencyContact> builder)
    {
        builder.ToTable("emergency_contacts");

        builder.HasKey(e => e.Id);

        builder.Property(e => e.UserId).IsRequired();
        builder.Property(e => e.Name).HasMaxLength(120).IsRequired();
        builder.Property(e => e.Phone).HasMaxLength(15).IsRequired();
        builder.Property(e => e.Relationship).HasMaxLength(50);

        builder.HasIndex(e => e.UserId);
    }
}

public sealed class SosAlertConfiguration : IEntityTypeConfiguration<SosAlert>
{
    public void Configure(EntityTypeBuilder<SosAlert> builder)
    {
        builder.ToTable("sos_alerts");

        builder.HasKey(s => s.Id);

        builder.Property(s => s.RideId).IsRequired();
        builder.Property(s => s.UserId).IsRequired();
        builder.Property(s => s.TriggeredAt).HasColumnType("timestamptz").IsRequired();
        builder.Property(s => s.ResolvedAt).HasColumnType("timestamptz");
        builder.Property(s => s.ResolvedBy);
        builder.Property(s => s.Status).HasConversion<string>().HasMaxLength(20).HasDefaultValue(SosStatus.Active);
        builder.Property(s => s.Notes).HasMaxLength(500);

        builder.OwnsOne(s => s.Location, loc =>
        {
            loc.Property(l => l.Latitude).HasColumnName("location_lat").HasColumnType("double precision");
            loc.Property(l => l.Longitude).HasColumnName("location_lng").HasColumnType("double precision");
        });

        builder.HasIndex(s => s.RideId);
        builder.HasIndex(s => s.Status);
    }
}

public sealed class SavedLocationConfiguration : IEntityTypeConfiguration<SavedLocation>
{
    public void Configure(EntityTypeBuilder<SavedLocation> builder)
    {
        builder.ToTable("saved_locations");

        builder.HasKey(s => s.Id);

        builder.Property(s => s.UserId).IsRequired();
        builder.Property(s => s.Label).HasMaxLength(50).IsRequired();
        builder.Property(s => s.Address).HasMaxLength(300).IsRequired();
        builder.Property(s => s.CreatedAt).HasColumnType("timestamptz");

        builder.OwnsOne(s => s.Location, loc =>
        {
            loc.Property(l => l.Latitude).HasColumnName("latitude").HasColumnType("double precision");
            loc.Property(l => l.Longitude).HasColumnName("longitude").HasColumnType("double precision");
        });

        builder.HasIndex(s => s.UserId);
    }
}

public sealed class ScheduledRideConfiguration : IEntityTypeConfiguration<ScheduledRide>
{
    public void Configure(EntityTypeBuilder<ScheduledRide> builder)
    {
        builder.ToTable("scheduled_rides");

        builder.HasKey(s => s.Id);

        builder.Property(s => s.UserId).IsRequired();
        builder.Property(s => s.PickupAddress).HasMaxLength(300).IsRequired();
        builder.Property(s => s.DropoffAddress).HasMaxLength(300).IsRequired();
        builder.Property(s => s.DistanceKm).HasPrecision(8, 2);
        builder.Property(s => s.VehicleType).HasConversion<string>().HasMaxLength(20);
        builder.Property(s => s.PaymentMethod).HasConversion<string>().HasMaxLength(20);
        builder.Property(s => s.ScheduledAt).HasColumnType("timestamptz").IsRequired();
        builder.Property(s => s.Status).HasConversion<string>().HasMaxLength(20);
        builder.Property(s => s.ResultingRideId);
        builder.Property(s => s.CreatedAt).HasColumnType("timestamptz");
        builder.Property(s => s.EstimatedFare).HasPrecision(10, 2);

        builder.OwnsOne(s => s.PickupLocation, loc =>
        {
            loc.Property(l => l.Latitude).HasColumnName("pickup_lat").HasColumnType("double precision");
            loc.Property(l => l.Longitude).HasColumnName("pickup_lng").HasColumnType("double precision");
        });

        builder.OwnsOne(s => s.DropoffLocation, loc =>
        {
            loc.Property(l => l.Latitude).HasColumnName("dropoff_lat").HasColumnType("double precision");
            loc.Property(l => l.Longitude).HasColumnName("dropoff_lng").HasColumnType("double precision");
        });

        builder.HasIndex(s => s.UserId);
        builder.HasIndex(s => s.Status);
        builder.HasIndex(s => s.ScheduledAt);
    }
}
