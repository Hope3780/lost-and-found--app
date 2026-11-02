using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Http;

namespace LostFoundAdmin.Models
{
    public class ReportFoundViewModel
    {
        public static readonly string[] Categories =
        {
            "Electronics", "Keys", "Cards & IDs", "Bags", "Clothing",
            "Books & Stationery", "Bottles & Lunchboxes", "Other"
        };

        [Required(ErrorMessage = "Please enter what the item is.")]
        [StringLength(120)]
        public string ItemName { get; set; } = "";

        public string Category { get; set; } = "Other";

        [StringLength(500)]
        public string? Description { get; set; }

        [Required(ErrorMessage = "Please enter where it was found.")]
        [StringLength(120)]
        public string Location { get; set; } = "";

        [DataType(DataType.Date)]
        public DateTime DateFound { get; set; } = DateTime.Today;

        public IFormFile? Photo { get; set; }
    }
}