namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class DisputeTicketConfiguration : IEntityTypeConfiguration<DisputeTicket>
{
    public void Configure(EntityTypeBuilder<DisputeTicket> builder)
    {
        builder.ToTable("dispute_tickets");

        builder.HasKey(t => t.Id);

        builder.Property(t => t.UserId)
            .IsRequired()
            .HasMaxLength(64);

        builder.HasIndex(t => t.UserId);

        builder.HasIndex(t => t.OrderId);

        builder.Property(t => t.OrderType)
            .HasMaxLength(50);

        builder.Property(t => t.Category)
            .HasConversion<string>()
            .HasMaxLength(50);

        builder.Property(t => t.Subject)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(t => t.Description)
            .IsRequired()
            .HasMaxLength(4000);

        builder.Property(t => t.PhotoUrl)
            .HasMaxLength(1000);

        builder.Property(t => t.Status)
            .HasConversion<string>()
            .HasMaxLength(50);

        builder.Property(t => t.ResolutionAmount)
            .HasPrecision(18, 2);

        builder.Property(t => t.ResolutionNote)
            .HasMaxLength(1000);

        builder.Property(t => t.CreatedAt).HasColumnType("timestamptz");
        builder.Property(t => t.UpdatedAt).HasColumnType("timestamptz");
        builder.Property(t => t.ResolvedAt).HasColumnType("timestamptz");
    }
}
