using Application;
using Domain;

namespace Infrastructure;

public sealed class SqlServerItemRepository(SqlServerConnectionFactory factory) : IItemRepository
{
    public async Task<IReadOnlyList<Item>> ListAsync(CancellationToken cancellationToken)
    {
        var items = new List<Item>();
        await using var connection = await factory.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT id, name FROM dbo.items ORDER BY id";
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            items.Add(new Item(reader.GetInt32(0), reader.GetString(1)));
        }

        return items;
    }

    public async Task<Item> AddAsync(string name, CancellationToken cancellationToken)
    {
        await using var connection = await factory.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = "INSERT INTO dbo.items (name) OUTPUT INSERTED.id VALUES (@name)";
        command.Parameters.AddWithValue("@name", name);
        var id = (int)(await command.ExecuteScalarAsync(cancellationToken))!;
        return new Item(id, name);
    }
}
