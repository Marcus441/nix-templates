using Application;
using Domain;
using Npgsql;

namespace Infrastructure;

public sealed class NpgsqlItemRepository(NpgsqlDataSource dataSource) : IItemRepository
{
    public async Task<IReadOnlyList<Item>> ListAsync(CancellationToken cancellationToken)
    {
        var items = new List<Item>();
        await using var command = dataSource.CreateCommand("SELECT id, name FROM items ORDER BY id");
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            items.Add(new Item(reader.GetInt32(0), reader.GetString(1)));
        }

        return items;
    }

    public async Task<Item> AddAsync(string name, CancellationToken cancellationToken)
    {
        await using var command = dataSource.CreateCommand("INSERT INTO items (name) VALUES ($1) RETURNING id");
        command.Parameters.AddWithValue(name);
        var id = (int)(await command.ExecuteScalarAsync(cancellationToken))!;
        return new Item(id, name);
    }
}
