using Microsoft.Data.SqlClient;

namespace Infrastructure;

// Microsoft.Data.SqlClient has no NpgsqlDataSource equivalent, so this is the
// smallest stand-in: one connection string, opened on demand, pooled by the
// driver. MasterConnectionString points at the same server with the database
// swapped, which is what lets EnsureSchemaAsync create the database itself.
public sealed class SqlServerConnectionFactory(string connectionString)
{
    public string Database { get; } = new SqlConnectionStringBuilder(connectionString).InitialCatalog;

    private string MasterConnectionString { get; } =
        new SqlConnectionStringBuilder(connectionString) { InitialCatalog = "master" }.ConnectionString;

    public Task<SqlConnection> OpenAsync(CancellationToken cancellationToken) =>
        OpenAsync(connectionString, cancellationToken);

    public Task<SqlConnection> OpenMasterAsync(CancellationToken cancellationToken) =>
        OpenAsync(MasterConnectionString, cancellationToken);

    private static async Task<SqlConnection> OpenAsync(string target, CancellationToken cancellationToken)
    {
        var connection = new SqlConnection(target);
        try
        {
            await connection.OpenAsync(cancellationToken);
            return connection;
        }
        catch
        {
            await connection.DisposeAsync();
            throw;
        }
    }
}
