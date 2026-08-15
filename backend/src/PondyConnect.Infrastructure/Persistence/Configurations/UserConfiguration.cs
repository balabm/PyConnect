namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("users");

        builder.HasKey(u => u.Id);

        builder.Property(u => u.Name)
            .IsRequired()
            .HasMaxLength(120);

        builder.Property(u => u.Phone)
            .IsRequired()
            .HasMaxLength(15);

        builder.HasIndex(u => u.Phone)
            .IsUnique();

        builder.Property(u => u.Email)
            .HasMaxLength(256);

        builder.HasIndex(u => u.Email)
            .IsUnique();

        builder.Property(u => u.GoogleId)
            .HasMaxLength(64);

        builder.HasIndex(u => u.GoogleId)
            .IsUnique();

        builder.Property(u => u.PictureUrl)
            .HasMaxLength(500);

        builder.Property(u => u.IsEmailVerified)
            .HasDefaultValue(false);

        builder.Property(u => u.Role)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(u => u.CreatedAt)
            .HasColumnType("timestamptz");

        builder.Property(u => u.LastLoginAt)
            .HasColumnType("timestamptz");

        builder.Property(u => u.ProMemberUntil)
            .HasColumnType("timestamptz");

        builder.Property(u => u.IsProMember)
            .HasDefaultValue(false);

        builder.Property(u => u.IsVerifiedLocal)
            .HasDefaultValue(false);

        builder.Property(u => u.AadhaarHash)
            .HasMaxLength(128);

        builder.Property(u => u.VerifiedAt)
            .HasColumnType("timestamptz");

        builder.Property(u => u.HasAcceptedLiabilityWaiver)
            .HasDefaultValue(false);

        builder.Property(u => u.WaiverAcceptedAt)
            .HasColumnType("timestamptz");

        builder.Property(u => u.DrivingLicenseNumber)
            .HasMaxLength(50);

        builder.Property(u => u.KycVerificationStatus)
            .HasConversion<string>()
            .HasMaxLength(20)
            .HasDefaultValue(KycVerificationStatus.Pending);

        builder.Property(u => u.FcmDeviceToken)
            .HasMaxLength(256);
    }
}