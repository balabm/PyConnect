namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class ModifierGroupConfiguration : IEntityTypeConfiguration<ModifierGroup>
{
    public void Configure(EntityTypeBuilder<ModifierGroup> builder)
    {
        builder.ToTable("modifier_groups");

        builder.HasKey(mg => mg.Id);

        builder.Property(mg => mg.MenuItemId).IsRequired();
        builder.Property(mg => mg.Name).IsRequired().HasMaxLength(100);
        builder.Property(mg => mg.SortOrder).HasDefaultValue(0);

        // IsRequired is a computed read-only convenience flag derived from
        // MinSelections — it has no backing field and must not be mapped.
        builder.Ignore(mg => mg.IsRequired);

        builder.HasOne(mg => mg.MenuItem)
            .WithMany(m => m.ModifierGroups)
            .HasForeignKey(mg => mg.MenuItemId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Property(mg => mg.CreatedAt).HasColumnType("timestamptz");
        builder.Property(mg => mg.UpdatedAt).HasColumnType("timestamptz");
    }
}
