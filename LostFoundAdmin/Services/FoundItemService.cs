using Npgsql;
using LostFoundAdmin.Models;

namespace LostFoundAdmin.Services;

public class FoundItemService
{
    private readonly NpgsqlDataSource _dataSource;

    public FoundItemService(NpgsqlDataSource dataSource)
    {
        _dataSource = dataSource;
    }

    public async Task<List<FoundItem>> GetAllItemsAsync()
    {
        var items = new List<FoundItem>();
        await using var cmd = _dataSource.CreateCommand(
            "SELECT id, item_name, description, photo_url, location_found, date_found, status, claimed_by, logged_by FROM found_items ORDER BY created_at DESC");
        await using var reader = await cmd.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            items.Add(new FoundItem
            {
                Id = reader.GetGuid(0),
                ItemName = reader.GetString(1),
                Description = reader.IsDBNull(2) ? "" : reader.GetString(2),
                PhotoUrl = reader.IsDBNull(3) ? null : reader.GetString(3),
                LocationFound = reader.IsDBNull(4) ? "" : reader.GetString(4),
                DateFound = reader.GetDateTime(5),
                Status = reader.GetString(6),
                ClaimedBy = reader.IsDBNull(7) ? null : reader.GetGuid(7),
                LoggedBy = reader.IsDBNull(8) ? null : reader.GetGuid(8),
            });
        }
        return items;
    }

    public async Task LogNewItemAsync(string itemName, string description, string location)
    {
        await using var cmd = _dataSource.CreateCommand(
            "INSERT INTO found_items (item_name, description, location_found, date_found, status) VALUES ($1, $2, $3, CURRENT_DATE, 'logged')");
        cmd.Parameters.AddWithValue(itemName);
        cmd.Parameters.AddWithValue(description);
        cmd.Parameters.AddWithValue(location);
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task MarkAsReturnedAsync(Guid itemId)
    {
        await using var cmd = _dataSource.CreateCommand(
            "UPDATE found_items SET status = 'returned' WHERE id = $1");
        cmd.Parameters.AddWithValue(itemId);
        await cmd.ExecuteNonQueryAsync();
    }
}