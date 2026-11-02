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

    // ---------- FOUND ITEMS ----------

    public async Task<List<FoundItem>> GetAllItemsAsync()
    {
        var items = new List<FoundItem>();
        await using var cmd = _dataSource.CreateCommand(
            @"SELECT f.id, f.item_name, f.description, f.photo_url, f.location_found,
                     f.date_found, f.status, f.claimed_by, f.logged_by, f.staff_note,
                     u.email, f.updated_by_email, f.updated_at, f.staff_reporter_email
              FROM found_items f
              LEFT JOIN auth.users u ON u.id = f.logged_by
              ORDER BY f.created_at DESC");
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
                StaffNote = reader.IsDBNull(9) ? null : reader.GetString(9),
                ReporterEmail = reader.IsDBNull(10) ? null : reader.GetString(10),
                UpdatedByEmail = reader.IsDBNull(11) ? null : reader.GetString(11),
                UpdatedAt = reader.IsDBNull(12) ? null : reader.GetDateTime(12),
                StaffReporterEmail = reader.IsDBNull(13) ? null : reader.GetString(13),
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

    public async Task AddFoundItemAsync(
    string itemName, string description, string location,
    DateTime dateFound, string? photoUrl, string adminEmail)
    {
        await using var cmd = _dataSource.CreateCommand(
            @"INSERT INTO found_items
                (item_name, description, location_found, date_found, status,
                 photo_url, updated_by_email, updated_at, staff_reporter_email)
              VALUES ($1, $2, $3, $4::date, 'pending', $5, $6, now(), $6)");
        cmd.Parameters.AddWithValue(itemName);
        cmd.Parameters.AddWithValue(description);
        cmd.Parameters.AddWithValue(location);
        cmd.Parameters.AddWithValue(DateTime.SpecifyKind(dateFound.Date, DateTimeKind.Unspecified));
        cmd.Parameters.AddWithValue((object?)photoUrl ?? DBNull.Value);
        cmd.Parameters.AddWithValue(adminEmail);
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task MarkAsReturnedAsync(Guid itemId, string? adminEmail = null)
    {
        await using var cmd = _dataSource.CreateCommand(
            "UPDATE found_items SET status = 'returned', updated_by_email = $1, updated_at = now() WHERE id = $2");
        cmd.Parameters.AddWithValue((object?)adminEmail ?? DBNull.Value);
        cmd.Parameters.AddWithValue(itemId);
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task UpdateStatusAsync(Guid itemId, string status, string? adminEmail = null)
    {
        await using var cmd = _dataSource.CreateCommand(
            "UPDATE found_items SET status = $1, updated_by_email = $2, updated_at = now() WHERE id = $3");
        cmd.Parameters.AddWithValue(status);
        cmd.Parameters.AddWithValue((object?)adminEmail ?? DBNull.Value);
        cmd.Parameters.AddWithValue(itemId);
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task UpdateStatusWithNoteAsync(Guid itemId, string status, string? note, string? adminEmail = null)
    {
        await using var cmd = _dataSource.CreateCommand(
            "UPDATE found_items SET status = $1, staff_note = $2, updated_by_email = $3, updated_at = now() WHERE id = $4");
        cmd.Parameters.AddWithValue(status);
        cmd.Parameters.AddWithValue((object?)note ?? DBNull.Value);
        cmd.Parameters.AddWithValue((object?)adminEmail ?? DBNull.Value);
        cmd.Parameters.AddWithValue(itemId);
        await cmd.ExecuteNonQueryAsync();
    }

    // ---------- LOST ITEMS ----------

    // Lost reports submitted from the student app
    public async Task<List<LostItem>> GetAllLostItemsAsync()
    {
        var items = new List<LostItem>();
        await using var cmd = _dataSource.CreateCommand(
            @"SELECT l.id, l.item_name, l.category, l.description, l.photo_url, l.status,
                     l.created_at, l.staff_note, u.email, l.updated_by_email, l.updated_at,
                     l.location_lost
              FROM lost_items l
              LEFT JOIN auth.users u ON u.id = l.reported_by
              ORDER BY l.created_at DESC");
        await using var reader = await cmd.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            items.Add(new LostItem
            {
                Id = reader.GetGuid(0),
                ItemName = reader.GetString(1),
                Category = reader.IsDBNull(2) ? "Other" : reader.GetString(2),
                Description = reader.IsDBNull(3) ? "" : reader.GetString(3),
                PhotoUrl = reader.IsDBNull(4) ? null : reader.GetString(4),
                Status = reader.GetString(5),
                CreatedAt = reader.GetDateTime(6),
                StaffNote = reader.IsDBNull(7) ? null : reader.GetString(7),
                ReporterEmail = reader.IsDBNull(8) ? null : reader.GetString(8),
                UpdatedByEmail = reader.IsDBNull(9) ? null : reader.GetString(9),
                UpdatedAt = reader.IsDBNull(10) ? null : reader.GetDateTime(10),
                LocationLost = reader.IsDBNull(11) ? null : reader.GetString(11),
            });
        }
        return items;
    }

    public async Task UpdateLostStatusAsync(Guid itemId, string status, string? adminEmail = null)
    {
        await using var cmd = _dataSource.CreateCommand(
            "UPDATE lost_items SET status = $1, updated_by_email = $2, updated_at = now() WHERE id = $3");
        cmd.Parameters.AddWithValue(status);
        cmd.Parameters.AddWithValue((object?)adminEmail ?? DBNull.Value);
        cmd.Parameters.AddWithValue(itemId);
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task UpdateLostStatusWithNoteAsync(Guid itemId, string status, string? note, string? adminEmail = null)
    {
        await using var cmd = _dataSource.CreateCommand(
            "UPDATE lost_items SET status = $1, staff_note = $2, updated_by_email = $3, updated_at = now() WHERE id = $4");
        cmd.Parameters.AddWithValue(status);
        cmd.Parameters.AddWithValue((object?)note ?? DBNull.Value);
        cmd.Parameters.AddWithValue((object?)adminEmail ?? DBNull.Value);
        cmd.Parameters.AddWithValue(itemId);
        await cmd.ExecuteNonQueryAsync();
    }
}
