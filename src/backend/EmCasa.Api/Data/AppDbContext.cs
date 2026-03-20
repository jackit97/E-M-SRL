using EmCasa.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace EmCasa.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<HouseRequest> HouseRequests => Set<HouseRequest>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("emcasa");

        modelBuilder.HasPostgresEnum<UserRole>("emcasa", "user_role");
        modelBuilder.HasPostgresEnum<HouseRequestStatus>("emcasa", "request_status");

        modelBuilder.Entity<AppUser>()
            .HasIndex(user => user.Email)
            .IsUnique();

        modelBuilder.Entity<AppUser>()
            .Property(user => user.Role)
            .HasColumnType("user_role");

        modelBuilder.Entity<AppUser>()
            .Property(user => user.SubscriptionExpiresAtUtc)
            .HasColumnName("subscription_expires_at_utc");

        modelBuilder.Entity<AppUser>()
            .Property(user => user.CreatedAt)
            .HasColumnName("created_at");

        modelBuilder.Entity<HouseRequest>()
            .Property(request => request.Status)
            .HasColumnType("request_status");

        modelBuilder.Entity<HouseRequest>()
            .Property(request => request.BudgetMin)
            .HasPrecision(12, 2);

        modelBuilder.Entity<HouseRequest>()
            .Property(request => request.BudgetMax)
            .HasPrecision(12, 2);

        modelBuilder.Entity<HouseRequest>()
            .Property(request => request.CreatedAt)
            .HasColumnName("created_at");

        modelBuilder.Entity<HouseRequest>()
            .Property(request => request.UpdatedAt)
            .HasColumnName("updated_at");

        modelBuilder.Entity<HouseRequest>()
            .HasOne(request => request.User)
            .WithMany(user => user.HouseRequests)
            .HasForeignKey(request => request.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        base.OnModelCreating(modelBuilder);
    }
}
