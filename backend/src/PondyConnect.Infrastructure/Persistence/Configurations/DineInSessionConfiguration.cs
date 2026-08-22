namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class DineInSessionConfiguration : IEntityTypeConfiguration<DineInSession>
{
    public void Configure(EntityTypeBuilder<DineInSession> builder)
    {
        builder.ToTable("dine_in_sessions");

        builder.HasKey(s => s.Id);

        builder.Property(s => s.VenueId).IsRequired();
        builder.Property(s => s.VendorId).IsRequired();
        builder.Property(s => s.TableId).IsRequired();
        builder.Property(s => s.OpenedByUserId).IsRequired();
        builder.Property(s => s.RootOrderId);
        builder.Property(s => s.Status).HasConversion<int>().IsRequired();
        builder.Property(s => s.OpenedAt).HasColumnType("timestamptz").IsRequired();
        builder.Property(s => s.ClosedAt).HasColumnType("timestamptz");
        builder.Property(s => s.TotalSettled).HasColumnType("numeric(14,2)").IsRequired();
        builder.Property(s => s.CreatedAt).HasColumnType("timestamptz");
        builder.Property(s => s.UpdatedAt).HasColumnType("timestamptz");

        // One active session per table at a venue
        builder.HasIndex(s => new { s.VenueId, s.TableId, s.Status });
        builder.HasIndex(s => s.OpenedByUserId);
    }
}
