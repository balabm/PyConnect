namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class ModifierConfiguration : IEntityTypeConfiguration<Modifier>
{
    public void Configure(EntityTypeBuilder<Modifier> builder)
    {
        builder.ToTable("modifiers");

        builder.HasKey(m => m.Id);

        builder.Property(m => m.ModifierGroupId).IsRequired();
        builder.Property(m => m.Name).HasMaxLength(200).IsRequired();
        builder.Property(m => m.Price).HasPrecision(10, 2).HasDefaultValue(0m);
        builder.Property(m => m.IsAvailable).HasDefaultValue(true);
        builder.Property(m => m.SortOrder).HasDefaultValue(0);

        builder.HasOne(m => m.ModifierGroup)
            .WithMany(g => g.Modifiers)
            .HasForeignKey(m => m.ModifierGroupId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(m => m.ModifierGroupId);
    }
}
