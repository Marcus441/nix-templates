using Npgsql;

namespace Infrastructure;

// The connection comes from the libpq environment variables. Under devenv,
// PGHOST is the unix socket directory the postgres service exports, and Npgsql
// treats a path-valued Host as a socket. Under docker-compose the same
// variables carry a hostname, user and password instead. Only the database
// name has a fallback devenv does not export.
public static class Database
{
    public static NpgsqlDataSource CreateDataSource()
    {
        var builder = new NpgsqlConnectionStringBuilder
        {
            Host = Environment.GetEnvironmentVariable("PGHOST") ?? "127.0.0.1",
            Database = Environment.GetEnvironmentVariable("PGDATABASE") ?? "app",
        };

        if (int.TryParse(Environment.GetEnvironmentVariable("PGPORT"), out var port))
        {
            builder.Port = port;
        }

        if (Environment.GetEnvironmentVariable("PGUSER") is { Length: > 0 } user)
        {
            builder.Username = user;
        }

        if (Environment.GetEnvironmentVariable("PGPASSWORD") is { Length: > 0 } password)
        {
            builder.Password = password;
        }

        return NpgsqlDataSource.Create(builder);
    }

    public static async Task EnsureSchemaAsync(NpgsqlDataSource dataSource)
    {
        await using var command = dataSource.CreateCommand(
            "CREATE TABLE IF NOT EXISTS items (id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY, name text NOT NULL)");
        await command.ExecuteNonQueryAsync();
    }
}
