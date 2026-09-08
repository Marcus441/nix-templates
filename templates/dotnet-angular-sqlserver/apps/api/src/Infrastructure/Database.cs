using Microsoft.Data.SqlClient;

namespace Infrastructure;

// The connection string comes from ConnectionStrings__Default and there is no
// default, because the SA password is generated per project rather than shipped
// — a constant here would be a credential in the artifact. The devenv process
// builds it with `mssql-connection-string`; docker-compose sets the same shape
// with `mssql` as the host. SQL Server has no unix socket, so unlike this
// collection's PostgreSQL templates the host and port are always real TCP.
public static class Database
{
    public static SqlServerConnectionFactory CreateConnectionFactory() =>
        new(Environment.GetEnvironmentVariable("ConnectionStrings__Default") is {Length: > 0} configured
            ? configured
            : throw new InvalidOperationException(
                "ConnectionStrings__Default is not set. Inside the devenv shell, run the API with: "
                + "ConnectionStrings__Default=\"$(mssql-connection-string)\" "
                + "dotnet run --project apps/api/src/Api"));

    // Creates the database and then the table, both idempotently. The devenv
    // process for SQL Server has a readiness probe, so the server is answering
    // before the API starts — the retry covers the gap between accepting a
    // connection on master and having finished recovery, which is seconds.
    public static async Task EnsureSchemaAsync(SqlServerConnectionFactory factory)
    {
        for (var attempt = 1; ; attempt++)
        {
            try
            {
                await EnsureDatabaseAsync(factory);
                await EnsureTableAsync(factory);
                return;
            }
            catch (SqlException) when (attempt < 30)
            {
                await Task.Delay(TimeSpan.FromSeconds(2));
            }
        }
    }

    private static async Task EnsureDatabaseAsync(SqlServerConnectionFactory factory)
    {
        await using var connection = await factory.OpenMasterAsync(CancellationToken.None);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            IF DB_ID(@name) IS NULL
            BEGIN
                DECLARE @sql nvarchar(max) = N'CREATE DATABASE ' + QUOTENAME(@name);
                EXEC sp_executesql @sql;
            END
            """;
        command.Parameters.AddWithValue("@name", factory.Database);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task EnsureTableAsync(SqlServerConnectionFactory factory)
    {
        await using var connection = await factory.OpenAsync(CancellationToken.None);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            IF OBJECT_ID(N'dbo.items', N'U') IS NULL
                CREATE TABLE dbo.items (
                    id int IDENTITY(1, 1) NOT NULL PRIMARY KEY,
                    name nvarchar(200) NOT NULL
                );
            """;
        await command.ExecuteNonQueryAsync();
    }
}
