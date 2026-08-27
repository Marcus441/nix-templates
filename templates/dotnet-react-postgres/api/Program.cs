using Npgsql;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// PGHOST is the unix socket directory devenv exports; Npgsql treats a
// path-valued Host as a socket. Delete this endpoint once you have your own.
app.MapGet("/health", async () =>
{
    var host = Environment.GetEnvironmentVariable("PGHOST");
    await using var connection = new NpgsqlConnection($"Host={host};Database=app");
    await connection.OpenAsync();
    await using var command = new NpgsqlCommand("SELECT 1", connection);
    var db = (int)(await command.ExecuteScalarAsync())!;
    return Results.Json(new { status = "ok", db });
});

app.Run();
