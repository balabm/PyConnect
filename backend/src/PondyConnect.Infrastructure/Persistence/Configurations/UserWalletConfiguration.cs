namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class UserWalletConfiguration : IEntityTypeConfiguration<UserWallet>
{
    public void Configure(EntityTypeBuilder<UserWallet> builder)
    {
        builder.ToTable("user_wallets");

        builder.HasKey(w => w.Id);

        builder.Property(w => w.UserId)
            .IsRequired();

        builder.HasIndex(w => w.UserId)
            .IsUnique();

        builder.HasOne<User>()
            .WithOne()
            .HasForeignKey<UserWallet>(w => w.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Property(w => w.PromoBalance)
            .HasColumnType("numeric(14,2)")
            .HasDefaultValue(0m);

        builder.Property(w => w.RealBalance)
            .HasColumnType("numeric(14,2)")
            .HasDefaultValue(0m);

        builder.Property(w => w.UpdatedAt)
            .HasColumnType("timestamptz");

        builder.Property(w => w.CreatedAt)
            .HasColumnType("timestamptz");
    }
}
