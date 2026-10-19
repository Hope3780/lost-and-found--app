using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using LostFoundAdmin.Services;

namespace LostFoundAdmin.Controllers;

[Authorize]
public class HomeController : Controller
{
    private readonly FoundItemService _service;

    public HomeController(FoundItemService service)
    {
        _service = service;
    }

    // GET /Home/Index  (or just "/")
    public async Task<IActionResult> Index()
    {
        var items = await _service.GetAllItemsAsync();
        return View(items);
    }

    // POST /Home/MarkReturned
    [HttpPost]
    public async Task<IActionResult> MarkReturned(Guid id)
    {
        await _service.MarkAsReturnedAsync(id);
        return RedirectToAction("Index");
    }
}