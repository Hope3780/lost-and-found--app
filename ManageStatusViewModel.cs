namespace LostFoundAdmin.Models
{
    public class ManageStatusViewModel
    {
        public Guid Id { get; set; }
        public string Ref { get; set; } = "";
        public string ItemName { get; set; } = "";
        public string Type { get; set; } = "Found";   // "Found" or "Lost"
        public string CurrentStatusLabel { get; set; } = "";
        public string StatusKey { get; set; } = "pending";
        public string? StaffNote { get; set; }
        public string? ImageUrl { get; set; }
    }
}