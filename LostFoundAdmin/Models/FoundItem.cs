namespace LostFoundAdmin.Models;

public class FoundItem
{
    public Guid Id { get; set; }
    public string ItemName { get; set; } = "";
    public string Description { get; set; } = "";
    public string? PhotoUrl { get; set; }
    public string LocationFound { get; set; } = "";
    public DateTime DateFound { get; set; }
    public string Status { get; set; } = "logged";
    public Guid? ClaimedBy { get; set; }
    public Guid? LoggedBy { get; set; }
}