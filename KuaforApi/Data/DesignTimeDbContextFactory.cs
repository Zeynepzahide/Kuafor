using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace KuaforApi.Data
{
    public class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
    {
        public AppDbContext CreateDbContext(string[] args)
        {
            var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();

            var connectionString =
                Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection")
                ?? "Host=dpg-d85fgnjbc2fs73bpa39g-a.frankfurt-postgres.render.com;Port=5432;Database=kuafor_db_hs1b;Username=kuafor_db_hs1b_user;Password=rhxwiuImsCwRZa30z5DcfMXNw9uK12oi;SSL Mode=Require;Trust Server Certificate=true";

            optionsBuilder.UseNpgsql(connectionString);

            return new AppDbContext(optionsBuilder.Options);
        }
    }
}