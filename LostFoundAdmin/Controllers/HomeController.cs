using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using LostFoundAdmin.Models;
using LostFoundAdmin.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;

namespace LostFoundAdmin.Controllers;

[Authorize]

[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public class HomeController : Controller
{
    private readonly FoundItemService _service;
    private readonly SupabaseStorageService _storage;

    public HomeController(FoundItemService service, SupabaseStorageService storage)
    {
        _service = service;
        _storage = storage;
    }

    // Email of the admin who is signed in (saved with every status change)
    private string AdminEmail =>
        User.FindFirst(ClaimTypes.Email)?.Value
        ?? User.FindFirst("email")?.Value
        ?? User.Identity?.Name
        ?? "unknown";

    // One combined row (found item or lost report)
    private record Row(
        Guid Id, string Type, string ItemName, string Location, string Category,
        string Status, DateTime When, string? Photo, string Description, string? StaffNote,
        string? ReporterEmail, string? UpdatedByEmail, DateTime? UpdatedAt, bool ReporterIsStaff);

    // The apps save the category as the first line of the description ("Category: Keys").
    // This splits the two back apart.
    private static (string Category, string Description) SplitCategory(string? description)
    {
        var text = (description ?? "").Replace("\r\n", "\n").Trim();
        const string prefix = "Category:";

        if (!text.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
            return ("", text);

        var body = text[prefix.Length..].TrimStart();

        // Normal case: the category is on its own first line
        var newline = body.IndexOf('\n');
        if (newline >= 0)
            return (body[..newline].Trim(), body[(newline + 1)..].Trim());

        // Fallback: no line break, so match against the known category names
        foreach (var c in ReportFoundViewModel.Categories.OrderByDescending(c => c.Length))
        {
            if (body.StartsWith(c, StringComparison.OrdinalIgnoreCase))
                return (c, body[c.Length..].Trim());
        }

        return ("", text);
    }
    private async Task<List<Row>> GetRowsAsync()
    {
        var found = await _service.GetAllItemsAsync();
        var lost = await _service.GetAllLostItemsAsync();

        var foundRows = found.Select(i =>
        {
            var (category, description) = SplitCategory(i.Description);
            return new Row(i.Id, "Found", i.ItemName, i.LocationFound, category,
                i.Status, i.DateFound, i.PhotoUrl, description, i.StaffNote,
                // A student reporter wins; otherwise show the officer who reported it
                i.ReporterEmail ?? i.StaffReporterEmail,
                i.UpdatedByEmail, i.UpdatedAt,
                i.ReporterEmail == null && i.StaffReporterEmail != null);
        });

        var lostRows = lost.Select(l => new Row(l.Id, "Lost", l.ItemName,
            string.IsNullOrWhiteSpace(l.LocationLost) ? "—" : l.LocationLost,
            l.Category,
            l.Status, l.CreatedAt, l.PhotoUrl, l.Description ?? "", l.StaffNote,
            l.ReporterEmail, l.UpdatedByEmail, l.UpdatedAt, false));

        return foundRows
            .Concat(lostRows)
            .OrderByDescending(r => r.When)
            .ToList();
    }

    private static ReportedItemViewModel ToReport(Row r, int n) => new()
    {
        Id = r.Id.ToString(),
        Ref = "#" + (n + 1).ToString("D3"),
        ItemName = r.ItemName,
        Type = r.Type,
        Location = r.Location,
        Status = StatusLabel(r.Status),
        StatusKey = r.Status,
        ReporterEmail = r.ReporterEmail,
        ReporterIsStaff = r.ReporterIsStaff,
        UpdatedByEmail = r.UpdatedByEmail
    };

    private static string NormalizeType(string? type) =>
        string.Equals(type, "lost", StringComparison.OrdinalIgnoreCase) ? "Lost" : "Found";

    private static string StatusLabel(string? status) => status switch
    {
        "logged" or "pending" => "Pending",
        "claim_pending" => "Claim Pending",
        "under_review" => "Under Review",
        "item_found" => "Item Found",
        "verified" => "Verified",
        "available_for_collection" => "Available for Collection",
        "rejected" => "Rejected",
        "returned" => "Collected",
        _ => "Pending"
    };

    // GET /Home/Index
    public async Task<IActionResult> Index()
    {
        var rows = await GetRowsAsync();
        var list = rows.Select((r, n) => ToReport(r, n)).ToList();
        return View(list);
    }

    // GET /Home/ReportedItems
    public async Task<IActionResult> ReportedItems()
    {
        var rows = await GetRowsAsync();
        var list = rows.Select((r, n) => ToReport(r, n)).ToList();
        return View(list);
    }

    // GET /Home/Details/{id}?type=Found|Lost
    public async Task<IActionResult> Details(Guid id, string? type)
    {
        type = NormalizeType(type);
        var rows = await GetRowsAsync();
        var index = rows.FindIndex(r => r.Id == id && r.Type == type);
        if (index < 0)
            return NotFound();

        var r = rows[index];

        var vm = new ItemDetailsViewModel
        {
            Id = r.Id,
            Ref = "#" + (index + 1).ToString("D3"),
            ItemName = r.ItemName,
            Category = r.Category,
            Type = r.Type,
            Location = r.Location,
            DateFound = r.When.ToString("dd MMM yyyy"),
            Description = r.Description,
            ImageUrl = r.Photo,
            StatusKey = r.Status == "logged" ? "pending" : r.Status,
            ReporterEmail = r.ReporterEmail,
            ReporterIsStaff = r.ReporterIsStaff,
            UpdatedByEmail = r.UpdatedByEmail,
            UpdatedAt = r.UpdatedAt?.ToLocalTime().ToString("dd MMM yyyy HH:mm")
        };

        return View(vm);
    }

    // POST /Home/UpdateStatus  (main button / Reject / dropdown on the details page)
    [HttpPost]
    public async Task<IActionResult> UpdateStatus(Guid id, string status, string? type)
    {
        type = NormalizeType(type);

        var allowed = type == "Lost"
            ? new[] { "pending", "under_review", "item_found", "rejected" }
            : new[] { "pending", "under_review", "verified", "rejected" };

        if (!allowed.Contains(status))
            return BadRequest();

        if (type == "Lost")
            await _service.UpdateLostStatusAsync(id, status, AdminEmail);
        else
            await _service.UpdateStatusAsync(id, status, AdminEmail);

        TempData["Message"] = "Status updated to " + StatusLabel(status) + ".";
        return RedirectToAction("Details", new { id, type });
    }

    // GET /Home/ManageItems  (found items AND lost reports)
    public async Task<IActionResult> ManageItems()
    {
        var rows = await GetRowsAsync();
        var list = rows.Select((r, n) => ToReport(r, n)).ToList();
        return View(list);
    }

    // GET /Home/EditStatus/{id}?type=Found|Lost
    public async Task<IActionResult> EditStatus(Guid id, string? type)
    {
        type = NormalizeType(type);
        var rows = await GetRowsAsync();
        var index = rows.FindIndex(r => r.Id == id && r.Type == type);
        if (index < 0)
            return NotFound();

        var r = rows[index];

        var vm = new ManageStatusViewModel
        {
            Id = r.Id,
            Ref = "#" + (index + 1).ToString("D3"),
            ItemName = r.ItemName,
            Type = r.Type,
            CurrentStatusLabel = StatusLabel(r.Status),
            StaffNote = r.StaffNote,
            ImageUrl = r.Photo,
            StatusKey = r.Status == "logged" ? "pending" : r.Status
        };

        return View(vm);
    }

    // POST /Home/SaveStatus
    [HttpPost]
    public async Task<IActionResult> SaveStatus(Guid id, string status, string? staffNote, string? type)
    {
        type = NormalizeType(type);

        // The four statuses staff can pick on this page...
        var allowed = new List<string> { "pending", "under_review", "available_for_collection", "returned" };

        // ...plus the item's current status, so a note can be saved without changing it
        var rows = await GetRowsAsync();
        var current = rows.FirstOrDefault(r => r.Id == id && r.Type == type)?.Status;
        if (current != null)
            allowed.Add(current);

        if (!allowed.Contains(status))
            return BadRequest();

        staffNote = string.IsNullOrWhiteSpace(staffNote) ? null : staffNote.Trim();
        if (staffNote != null && staffNote.Length > 500)
            staffNote = staffNote[..500];

        if (type == "Lost")
            await _service.UpdateLostStatusWithNoteAsync(id, status, staffNote, AdminEmail);
        else
            await _service.UpdateStatusWithNoteAsync(id, status, staffNote, AdminEmail);

        TempData["Message"] = "Status saved as " + StatusLabel(status) + ".";
        return RedirectToAction("ManageItems");
    }

    // GET /Home/ReportFound
    [HttpGet]
    public IActionResult ReportFound() => View(new ReportFoundViewModel());

    // POST /Home/ReportFound
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ReportFound(ReportFoundViewModel model)
    {
        if (model.DateFound.Date > DateTime.Today)
            ModelState.AddModelError(nameof(model.DateFound), "The date can't be in the future.");

        if (!ReportFoundViewModel.Categories.Contains(model.Category))
            model.Category = "Other";

        // Check the photo (optional): size and real image type
        (string Ext, string Mime)? imageType = null;
        var photo = model.Photo;
        if (photo is { Length: > 0 })
        {
            if (photo.Length > 6 * 1024 * 1024)
                ModelState.AddModelError(nameof(model.Photo), "The photo must be smaller than 6 MB.");
            else
            {
                imageType = await DetectImageAsync(photo);
                if (imageType == null)
                    ModelState.AddModelError(nameof(model.Photo), "Please choose a JPG, PNG, GIF or WebP image.");
            }
        }

        if (!ModelState.IsValid)
            return View(model);

        try
        {
            string? photoUrl = null;
            if (imageType != null)
            {
                await using var stream = photo!.OpenReadStream();
                photoUrl = await _storage.UploadAsync(stream, imageType.Value.Mime, imageType.Value.Ext);
            }

            // Same format the student app uses: category on the first line
            var description = (model.Description ?? "").Trim();
            if (model.Category != "Other")
                description = description.Length == 0
                    ? $"Category: {model.Category}"
                    : $"Category: {model.Category}\n{description}";

            await _service.AddFoundItemAsync(
                model.ItemName.Trim(), description, model.Location.Trim(),
                model.DateFound, photoUrl, AdminEmail);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Report found failed: {ex}");
            ModelState.AddModelError(string.Empty,
                "Could not save the item. Please try again, or contact the system administrator.");
            return View(model);
        }

        TempData["Message"] = "Found item reported. It now appears in the student app.";
        return RedirectToAction("ManageItems");
    }

    // Works out the real image type from the file's first bytes
    private static async Task<(string Ext, string Mime)?> DetectImageAsync(IFormFile file)
    {
        var b = new byte[12];
        await using var s = file.OpenReadStream();
        var n = await s.ReadAsync(b, 0, b.Length);

        if (n >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return ("jpg", "image/jpeg");
        if (n >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return ("png", "image/png");
        if (n >= 4 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return ("gif", "image/gif");
        if (n >= 12 && b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46
            && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) return ("webp", "image/webp");
        return null;
    }

    // POST /Home/Logout
    // POST /Home/Logout
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Logout()
    {
        // Your login cookie scheme is registered as "StaffAuth"
        await HttpContext.SignOutAsync("StaffAuth");

        // [Authorize] on this controller sends signed-out users to the login page
        return RedirectToAction("Index");
    }

    // POST /Home/MarkReturned  ("Confirm Collected" on the dashboard)
    [HttpPost]
    public async Task<IActionResult> MarkReturned(Guid id, string? type)
    {
        if (NormalizeType(type) == "Lost")
            await _service.UpdateLostStatusAsync(id, "returned", AdminEmail);
        else
            await _service.MarkAsReturnedAsync(id, AdminEmail);

        return RedirectToAction("Index");
    }
}