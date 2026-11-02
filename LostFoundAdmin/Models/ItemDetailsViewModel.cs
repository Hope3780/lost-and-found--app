namespace LostFoundAdmin.Models
{
    public class ItemDetailsViewModel
    {
        public Guid Id { get; set; }
        public string Ref { get; set; } = "";
        public string ItemName { get; set; } = "";
        public string Category { get; set; } = "";
        public string Type { get; set; } = "Found";
        public string Location { get; set; } = "";
        public string DateFound { get; set; } = "";
        public string Description { get; set; } = "";
        public string? ImageUrl { get; set; }
        public string StatusKey { get; set; } = "pending";
        public string? ReporterEmail { get; set; }
        public bool ReporterIsStaff { get; set; }
        public string? UpdatedByEmail { get; set; }
        public string? UpdatedAt { get; set; }
    }
}