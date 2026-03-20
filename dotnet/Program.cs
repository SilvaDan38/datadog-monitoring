// Program.cs — .NET 8 ASP.NET Core CRUD com Datadog
// Datadog.Trace auto-instrumenta: ASP.NET Core, EntityFramework Core, HttpClient

using Datadog.Trace;
using Datadog.Trace.Configuration;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Serilog.Formatting.Json;

// ─── Serilog — logs estruturados compatíveis com Datadog ─────────────────────
Log.Logger = new LoggerConfiguration()
    .Enrich.WithProperty("dd_service", Environment.GetEnvironmentVariable("DD_SERVICE") ?? "dotnet-crud")
    .Enrich.WithProperty("dd_env",     Environment.GetEnvironmentVariable("DD_ENV")     ?? "local")
    .Enrich.WithProperty("dd_version", "1.0.0")
    .WriteTo.Console(new JsonFormatter())
    .CreateLogger();

var builder = WebApplication.CreateBuilder(args);
builder.Host.UseSerilog();

// ─── Datadog Tracer ───────────────────────────────────────────────────────────
var settings = TracerSettings.FromDefaultSources();
settings.ServiceName       = Environment.GetEnvironmentVariable("DD_SERVICE") ?? "dotnet-crud";
settings.Environment       = Environment.GetEnvironmentVariable("DD_ENV")     ?? "local";
settings.ServiceVersion    = "1.0.0";
settings.LogsInjectionEnabled   = true;
Tracer.Configure(settings);

// ─── EF Core + PostgreSQL ─────────────────────────────────────────────────────
var connStr = builder.Configuration.GetConnectionString("DefaultConnection")
              ?? Environment.GetEnvironmentVariable("DATABASE_URL")
              ?? "Host=localhost;Database=crud_db;Username=user;Password=password";

builder.Services.AddDbContext<AppDbContext>(opts =>
    opts.UseNpgsql(connStr));

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Migrations automáticas na inicialização
using (var scope = app.Services.CreateScope()) {
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();
}

if (app.Environment.IsDevelopment()) {
    app.UseSwagger();
    app.UseSwaggerUI();
}

// ─── Health Check ─────────────────────────────────────────────────────────────
app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "dotnet-crud", version = "1.0.0" }));

// ─── CRUD Endpoints ───────────────────────────────────────────────────────────

// GET /products
app.MapGet("/products", async (AppDbContext db, int skip = 0, int limit = 100) => {
    using var scope = Tracer.Instance.StartActive("products.list");
    scope.Span.SetTag("query.skip", skip);
    scope.Span.SetTag("query.limit", limit);

    var products = await db.Products.Skip(skip).Take(limit).ToListAsync();
    scope.Span.SetTag("results.count", products.Count);
    Log.Information("Listed {Count} products", products.Count);
    return Results.Ok(products);
});

// GET /products/{id}
app.MapGet("/products/{id}", async (int id, AppDbContext db) => {
    using var scope = Tracer.Instance.StartActive("products.get");
    scope.Span.SetTag("product.id", id);

    var product = await db.Products.FindAsync(id);
    return product is null ? Results.NotFound() : Results.Ok(product);
});

// POST /products
app.MapPost("/products", async (ProductCreateDto dto, AppDbContext db) => {
    using var scope = Tracer.Instance.StartActive("products.create");
    scope.Span.SetTag("product.name", dto.Name);
    scope.Span.SetTag("product.price", dto.Price);

    var product = new Product {
        Name     = dto.Name,
        Category = dto.Category ?? "general",
        Price    = dto.Price,
        Stock    = dto.Stock,
        CreatedAt = DateTime.UtcNow,
        UpdatedAt = DateTime.UtcNow
    };
    db.Products.Add(product);
    await db.SaveChangesAsync();

    scope.Span.SetTag("product.id", product.Id);
    Log.Information("Created product {Id} - {Name}", product.Id, product.Name);
    return Results.Created($"/products/{product.Id}", product);
});

// PUT /products/{id}
app.MapPut("/products/{id}", async (int id, ProductCreateDto dto, AppDbContext db) => {
    using var scope = Tracer.Instance.StartActive("products.update");
    scope.Span.SetTag("product.id", id);

    var product = await db.Products.FindAsync(id);
    if (product is null) return Results.NotFound();

    product.Name      = dto.Name ?? product.Name;
    product.Category  = dto.Category ?? product.Category;
    product.Price     = dto.Price != 0 ? dto.Price : product.Price;
    product.Stock     = dto.Stock;
    product.UpdatedAt = DateTime.UtcNow;

    await db.SaveChangesAsync();
    Log.Information("Updated product {Id}", id);
    return Results.Ok(product);
});

// DELETE /products/{id}
app.MapDelete("/products/{id}", async (int id, AppDbContext db) => {
    using var scope = Tracer.Instance.StartActive("products.delete");
    scope.Span.SetTag("product.id", id);

    var product = await db.Products.FindAsync(id);
    if (product is null) return Results.NotFound();

    db.Products.Remove(product);
    await db.SaveChangesAsync();
    Log.Information("Deleted product {Id}", id);
    return Results.Ok(new { message = $"Product {id} deleted" });
});

app.Run();

// ─── Models & DbContext ───────────────────────────────────────────────────────

public class Product {
    public int    Id        { get; set; }
    public string Name      { get; set; } = "";
    public string Category  { get; set; } = "general";
    public double Price     { get; set; }
    public int    Stock     { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public record ProductCreateDto(string Name, string? Category, double Price, int Stock = 0);

public class AppDbContext : DbContext {
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) {}
    public DbSet<Product> Products => Set<Product>();
}
