namespace LostFoundAdmin.Models
{
    public class FoundItem
    {
        public Guid Id { get; set; }
        public string ItemName { get; set; } = "";
        public string? Description { get; set; }
        public string? PhotoUrl { get; set; }
        public string LocationFound { get; set; } = "";
        public DateTime DateFound { get; set; }
        public string Status { get; set; } = "";
        public Guid? ClaimedBy { get; set; }
        public Guid? LoggedBy { get; set; }
        public string? StaffNote { get; set; }
        public string? ReporterEmail { get; set; }

        public string? StaffReporterEmail { get; set; }
        public string? UpdatedByEmail { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }
}
