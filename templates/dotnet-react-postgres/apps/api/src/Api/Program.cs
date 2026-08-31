using Application;
using Domain;
using Infrastructure;
using Microsoft.AspNetCore.Http.HttpResults;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton(_ => Database.CreateDataSource());
builder.Services.AddScoped<IItemRepository, NpgsqlItemRepository>();
builder.Services.AddScoped<IItemService, ItemService>();
builder.Services.AddOpenApi();

var app = builder.Build();

// Serves /openapi/v1.json — scripts/generate-contracts.sh reads it to write
// the TypeScript types in packages/contracts.
app.MapOpenApi();

await Database.EnsureSchemaAsync(app.Services.GetRequiredService<NpgsqlDataSource>());

app.MapGet("/health", async (NpgsqlDataSource dataSource) =>
{
    await using var command = dataSource.CreateCommand("SELECT 1");
    var db = (int)(await command.ExecuteScalarAsync())!;
    return new HealthResponse("ok", db);
});

app.MapGet("/items", async (IItemService items, CancellationToken cancellationToken) =>
    await items.ListAsync(cancellationToken));

app.MapPost("/items", async Task<Results<Created<Item>, BadRequest<string>>> (
    CreateItemRequest request, IItemService items, CancellationToken cancellationToken) =>
{
    if (string.IsNullOrWhiteSpace(request.Name))
    {
        return TypedResults.BadRequest("name must not be empty");
    }

    var item = await items.AddAsync(request.Name, cancellationToken);
    return TypedResults.Created($"/items/{item.Id}", item);
});

app.Run();

public record CreateItemRequest(string? Name);

public record HealthResponse(string Status, int Db);
