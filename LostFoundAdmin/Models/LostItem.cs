namespace LostFoundAdmin.Models
{
    public class LostItem
    {
        public Guid Id { get; set; }
        public string ItemName { get; set; } = "";
        public string Category { get; set; } = "Other";
        public string Description { get; set; } = "";
        public string? PhotoUrl { get; set; }
        public string? LocationLost { get; set; }
        public string Status { get; set; } = "logged";
        public string? StaffNote { get; set; }
        public string? ReporterEmail { get; set; }
        public string? UpdatedByEmail { get; set; }
        public DateTime? UpdatedAt { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
