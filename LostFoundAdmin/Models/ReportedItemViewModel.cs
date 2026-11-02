namespace LostFoundAdmin.Models
{
    public class ReportedItemViewModel
    {
        public string Id { get; set; } = "";
        public string Ref { get; set; } = "";
        public string ItemName { get; set; } = "";
        public string Type { get; set; } = "Found";   // "Lost" or "Found"
        public string Location { get; set; } = "";
        public string Status { get; set; } = "";      // label shown on screen
        public string StatusKey { get; set; } = "pending"; // raw database value
        public string? ReporterEmail { get; set; }
        public bool ReporterIsStaff { get; set; }
        public string? UpdatedByEmail { get; set; }
    }
}