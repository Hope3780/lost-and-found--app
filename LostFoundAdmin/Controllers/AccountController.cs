using System.Net.Http.Json;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Npgsql;
using System.Security.Claims;

namespace LostFoundAdmin.Controllers;

public class AccountController : Controller
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IConfiguration _config;
    private readonly NpgsqlDataSource _dataSource;

    public AccountController(IHttpClientFactory httpClientFactory, IConfiguration config, NpgsqlDataSource dataSource)
    {
        _httpClientFactory = httpClientFactory;
        _config = config;
        _dataSource = dataSource;
    }

    [HttpGet]
    public IActionResult Login() => View();
    [HttpPost]
    public async Task<IActionResult> Login(string email, string password)
    {
        var supabaseUrl = _config["Supabase:Url"];
        var anonKey = _config["Supabase:AnonKey"];

        var client = _httpClientFactory.CreateClient();
        client.DefaultRequestHeaders.Add("apikey", anonKey);

        var response = await client.PostAsJsonAsync(
            $"{supabaseUrl}/auth/v1/token?grant_type=password",
            new { email, password });

        if (!response.IsSuccessStatusCode)
        {
            ViewBag.Error = "Incorrect email or password";
            return View();
        }

        var result = await response.Content.ReadFromJsonAsync<SupabaseAuthResponse>();
        var userId = result?.user?.id;
        var userEmail = (result?.user?.email ?? email).Trim().ToLowerInvariant();

        if (userId == null)
        {
            ViewBag.Error = "Login failed";
            return View();
        }

        // Check 1: only staff email addresses may use this portal
        if (!userEmail.EndsWith("@staff.cut.ac.za"))
        {
            ViewBag.Error = "This portal is for Protection Services staff only.";
            return View();
        }

        // Check 2: the account must be on the approved staff list
        await using var cmd = _dataSource.CreateCommand("SELECT is_staff FROM profiles WHERE id = $1");
        cmd.Parameters.AddWithValue(Guid.Parse(userId));
        var scalar = await cmd.ExecuteScalarAsync();
        var isStaff = scalar is bool b && b;

        if (!isStaff)
        {
            ViewBag.Error = "This account does not have staff access.";
            return View();
        }

        var claims = new List<Claim> { new Claim(ClaimTypes.Name, userEmail) };
        var identity = new ClaimsIdentity(claims, "StaffAuth");
        await HttpContext.SignInAsync("StaffAuth", new ClaimsPrincipal(identity));
        return RedirectToAction("Index", "Home");
    }
}

public class SupabaseAuthResponse
{
    public string? access_token { get; set; }
    public SupabaseUser? user { get; set; }
}

public class SupabaseUser
{
    public string? id { get; set; }
    public string? email { get; set; }
}