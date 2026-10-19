using Npgsql;
using LostFoundAdmin.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("StaffAuth")
    .AddCookie("StaffAuth", options =>
    {
        options.LoginPath = "/Account/Login";
    });

builder.Services.AddHttpClient();

builder.Services.AddAuthorization();

builder.Services.AddControllersWithViews();

builder.Services.AddSingleton(new NpgsqlDataSourceBuilder(
    builder.Configuration.GetConnectionString("Supabase")).Build());

builder.Services.AddScoped<FoundItemService>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();