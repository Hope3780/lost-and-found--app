using System.Net.Http.Headers;

namespace LostFoundAdmin.Services;

public class SupabaseStorageService
{
    private const string Bucket = "item-photos";
    private readonly HttpClient _http;
    private readonly string _url;

    public SupabaseStorageService(HttpClient http, IConfiguration config)
    {
        _http = http;
        _url = (config["Supabase:Url"]
                ?? throw new InvalidOperationException("Supabase:Url is not set")).TrimEnd('/');

        var key = config["Supabase:ServiceKey"]
                  ?? throw new InvalidOperationException("Supabase:ServiceKey is not set");

        _http.DefaultRequestHeaders.Add("apikey", key);
        // Older JWT-style keys also go in the Authorization header
        if (key.StartsWith("eyJ"))
            _http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", key);
    }

    // Uploads the photo and returns its public URL
    public async Task<string> UploadAsync(Stream data, string contentType, string ext)
    {
        var fileName = $"admin_{DateTime.UtcNow:yyyyMMddHHmmss}_{Guid.NewGuid():N}.{ext}";

        using var content = new StreamContent(data);
        content.Headers.ContentType = new MediaTypeHeaderValue(contentType);

        var res = await _http.PostAsync($"{_url}/storage/v1/object/{Bucket}/{fileName}", content);
        if (!res.IsSuccessStatusCode)
        {
            var body = await res.Content.ReadAsStringAsync();
            throw new InvalidOperationException($"Photo upload failed ({(int)res.StatusCode}): {body}");
        }

        return $"{_url}/storage/v1/object/public/{Bucket}/{fileName}";
    }
}