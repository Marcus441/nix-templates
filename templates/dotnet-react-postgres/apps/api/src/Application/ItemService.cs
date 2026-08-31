using Domain;

namespace Application;

public sealed class ItemService(IItemRepository repository) : IItemService
{
    public Task<IReadOnlyList<Item>> ListAsync(CancellationToken cancellationToken) =>
        repository.ListAsync(cancellationToken);

    public Task<Item> AddAsync(string name, CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        return repository.AddAsync(name.Trim(), cancellationToken);
    }
}
