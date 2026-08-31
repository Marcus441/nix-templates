using Domain;

namespace Application;

public interface IItemService
{
    Task<IReadOnlyList<Item>> ListAsync(CancellationToken cancellationToken);

    Task<Item> AddAsync(string name, CancellationToken cancellationToken);
}
