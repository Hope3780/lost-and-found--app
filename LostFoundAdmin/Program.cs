using Npgsql;
using LostFoundAdmin.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("StaffAuth")
    .AddCookie("StaffAuth", options =>
    {
        options.LoginPath = "/Account/Login";
    });

builder.Services.AddHttpClient();
builder.Services.AddHttpClient<SupabaseStorageService>();

builder.Services.AddAuthorization();

builder.Services.AddControllersWithViews();

// Fail early with a clear message if the connection string is missing
var connectionString = builder.Configuration.GetConnectionString("Supabase");
if (string.IsNullOrWhiteSpace(connectionString))
    throw new InvalidOperationException(
        "Connection string 'Supabase' is missing. Check secrets.json (ConnectionStrings:Supabase).");

builder.Services.AddSingleton(new NpgsqlDataSourceBuilder(connectionString).Build());

builder.Services.AddScoped<FoundItemService>();

var app = builder.Build();   // <-- this line was missing

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
    pattern: "{controller=Account}/{action=Login}/{id?}");

app.Run();