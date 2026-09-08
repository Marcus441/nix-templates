using Application;
using Domain;
using Xunit;

namespace Api.Tests;

public class ItemServiceTests
{
    [Fact]
    public async Task AddAsync_trims_the_name_and_stores_the_item()
    {
        var service = new ItemService(new FakeItemRepository());

        var item = await service.AddAsync("  smoke  ", CancellationToken.None);

        Assert.Equal("smoke", item.Name);
        var items = await service.ListAsync(CancellationToken.None);
        var stored = Assert.Single(items);
        Assert.Equal(item, stored);
    }

    private sealed class FakeItemRepository : IItemRepository
    {
        private readonly List<Item> items = new();

        public Task<IReadOnlyList<Item>> ListAsync(CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<Item>>(items);

        public Task<Item> AddAsync(string name, CancellationToken cancellationToken)
        {
            var item = new Item(items.Count + 1, name);
            items.Add(item);
            return Task.FromResult(item);
        }
    }
}
