using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.StaticFiles;
using Microsoft.Data.Sqlite;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls("http://0.0.0.0:51810");
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();
app.UseCors();
app.UseDefaultFiles();
var apkTypes = new FileExtensionContentTypeProvider();
apkTypes.Mappings[".apk"] = "application/vnd.android.package-archive";
app.UseStaticFiles(new StaticFileOptions { ContentTypeProvider = apkTypes });
app.MapGet("/download/spacemaker.apk", (IWebHostEnvironment env) =>
{
    var path = Path.Combine(env.WebRootPath, "apk", "spacemaker.apk");
    return File.Exists(path)
        ? Results.File(path, "application/vnd.android.package-archive", "spacemaker.apk")
        : Results.NotFound();
});

var dataDir = Path.Combine(app.Environment.ContentRootPath, "data");
Directory.CreateDirectory(dataDir);
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "apk"));
var dbPath = Path.Combine(dataDir, "spacemaker.db");

using (var db = Open(dbPath))
{
    Exec(db, """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            password_hash TEXT NOT NULL,
            token TEXT NOT NULL,
            is_plus INTEGER NOT NULL DEFAULT 0,
            plan TEXT,
            free_empties_left INTEGER NOT NULL DEFAULT 5,
            created_at TEXT NOT NULL
        );
        """);
    Seed(db);
}

app.MapGet("/api/health", () => Results.Ok(new
{
    ok = true,
    name = "SpaceMaker",
    tagline = "Swipe left for storage",
    lan = LanAddresses()
}));

app.MapPost("/api/auth/register", async (HttpRequest req) =>
{
    var body = await ReadJson(req);
    var email = Norm(body.Get("email"));
    var password = body.Get("password") ?? "";
    var name = (body.Get("name") ?? "Collector").Trim();
    if (!LooksLikeEmail(email) || password.Length < 8)
        return Results.BadRequest(new { error = "Use a valid email and a password of at least 8 characters." });

    using var db = Open(dbPath);
    if (FindByEmail(db, email) is not null)
        return Results.Conflict(new { error = "An account with this email already exists." });

    var user = InsertUser(db, email, name, password, isPlus: false, plan: null);
    return Results.Ok(AuthPayload(user));
});

app.MapPost("/api/auth/login", async (HttpRequest req) =>
{
    var body = await ReadJson(req);
    var email = Norm(body.Get("email"));
    var password = body.Get("password") ?? "";
    using var db = Open(dbPath);
    var user = FindByEmail(db, email);
    if (user is null || !Verify(password, user.PasswordHash))
        return Results.Json(new { error = "Wrong email or password." }, statusCode: 401);
    user.Token = NewToken();
    Exec(db, "UPDATE users SET token = $t WHERE id = $id", ("$t", user.Token), ("$id", user.Id));
    return Results.Ok(AuthPayload(user));
});

app.MapGet("/api/me", (HttpRequest req) =>
{
    using var db = Open(dbPath);
    var user = UserFromAuth(db, req);
    return user is null ? Results.Unauthorized() : Results.Ok(PublicUser(user));
});

app.MapPost("/api/subscription/activate", async (HttpRequest req) =>
{
    using var db = Open(dbPath);
    var user = UserFromAuth(db, req);
    if (user is null) return Results.Unauthorized();
    var body = await ReadJson(req);
    var plan = (body.Get("plan") ?? "yearly").ToLowerInvariant();
    if (plan is not ("weekly" or "monthly" or "yearly")) plan = "yearly";
    Exec(db, "UPDATE users SET is_plus = 1, plan = $p WHERE id = $id", ("$p", plan), ("$id", user.Id));
    user.IsPlus = true;
    user.Plan = plan;
    return Results.Ok(PublicUser(user));
});

app.MapPost("/api/subscription/empty", (HttpRequest req) =>
{
    using var db = Open(dbPath);
    var user = UserFromAuth(db, req);
    if (user is null) return Results.Unauthorized();
    if (user.IsPlus)
        return Results.Ok(new { allowed = true, remaining = -1, isPlus = true });
    if (user.FreeEmptiesLeft <= 0)
        return Results.Json(new { allowed = false, remaining = 0, isPlus = false, error = "plus_required" }, statusCode: 402);
    user.FreeEmptiesLeft -= 1;
    Exec(db, "UPDATE users SET free_empties_left = $n WHERE id = $id", ("$n", user.FreeEmptiesLeft), ("$id", user.Id));
    return Results.Ok(new { allowed = true, remaining = user.FreeEmptiesLeft, isPlus = false });
});

app.Run();

static SqliteConnection Open(string path)
{
    var c = new SqliteConnection($"Data Source={path}");
    c.Open();
    return c;
}

static void Exec(SqliteConnection db, string sql, params (string name, object? value)[] args)
{
    using var cmd = db.CreateCommand();
    cmd.CommandText = sql;
    foreach (var (name, value) in args)
        cmd.Parameters.AddWithValue(name, value ?? DBNull.Value);
    cmd.ExecuteNonQuery();
}

static void Seed(SqliteConnection db)
{
    if (FindByEmail(db, "test@spacemaker.app") is null)
        InsertUser(db, "test@spacemaker.app", "Test User", "SpaceMaker1!", isPlus: true, plan: "yearly");
    if (FindByEmail(db, "demo@spacemaker.app") is null)
        InsertUser(db, "demo@spacemaker.app", "Demo Free", "SpaceMaker1!", isPlus: false, plan: null);
}

static User InsertUser(SqliteConnection db, string email, string name, string password, bool isPlus, string? plan)
{
    var token = NewToken();
    using var cmd = db.CreateCommand();
    cmd.CommandText = """
        INSERT INTO users (email, name, password_hash, token, is_plus, plan, free_empties_left, created_at)
        VALUES ($e, $n, $p, $t, $plus, $plan, $free, $c);
        SELECT last_insert_rowid();
        """;
    cmd.Parameters.AddWithValue("$e", email);
    cmd.Parameters.AddWithValue("$n", name);
    cmd.Parameters.AddWithValue("$p", Hash(password));
    cmd.Parameters.AddWithValue("$t", token);
    cmd.Parameters.AddWithValue("$plus", isPlus ? 1 : 0);
    cmd.Parameters.AddWithValue("$plan", (object?)plan ?? DBNull.Value);
    cmd.Parameters.AddWithValue("$free", 5);
    cmd.Parameters.AddWithValue("$c", DateTime.UtcNow.ToString("o"));
    var id = Convert.ToInt64(cmd.ExecuteScalar());
    return new User(id, email, name, Hash(password), token, isPlus, plan, 5);
}

static User? FindByEmail(SqliteConnection db, string email)
{
    using var cmd = db.CreateCommand();
    cmd.CommandText = "SELECT id, email, name, password_hash, token, is_plus, plan, free_empties_left FROM users WHERE email = $e";
    cmd.Parameters.AddWithValue("$e", email);
    using var r = cmd.ExecuteReader();
    return r.Read() ? ReadUser(r) : null;
}

static User? FindByToken(SqliteConnection db, string token)
{
    using var cmd = db.CreateCommand();
    cmd.CommandText = "SELECT id, email, name, password_hash, token, is_plus, plan, free_empties_left FROM users WHERE token = $t";
    cmd.Parameters.AddWithValue("$t", token);
    using var r = cmd.ExecuteReader();
    return r.Read() ? ReadUser(r) : null;
}

static User ReadUser(SqliteDataReader r) => new(
    r.GetInt64(0), r.GetString(1), r.GetString(2), r.GetString(3), r.GetString(4),
    r.GetInt32(5) == 1, r.IsDBNull(6) ? null : r.GetString(6), r.GetInt32(7));

static User? UserFromAuth(SqliteConnection db, HttpRequest req)
{
    var header = req.Headers.Authorization.ToString();
    if (header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        return FindByToken(db, header["Bearer ".Length..].Trim());
    return null;
}

static object AuthPayload(User user) => new { token = user.Token, user = PublicUser(user) };

static object PublicUser(User user) => new
{
    id = user.Id,
    email = user.Email,
    name = user.Name,
    isPlus = user.IsPlus,
    plan = user.Plan,
    freeEmptiesLeft = user.FreeEmptiesLeft,
    weeklyPrice = 2.49,
    monthlyPrice = 5.99,
    yearlyPrice = 29.99
};

static string Hash(string password)
{
    var salt = SHA256.HashData(Encoding.UTF8.GetBytes("spacemaker.swipe.v1"));
    var bytes = Rfc2898DeriveBytes.Pbkdf2(password, salt, 120_000, HashAlgorithmName.SHA256, 32);
    return Convert.ToHexString(bytes);
}

static bool Verify(string password, string hash) =>
    CryptographicOperations.FixedTimeEquals(Convert.FromHexString(Hash(password)), Convert.FromHexString(hash));

static string NewToken() => Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant();
static string Norm(string? email) => (email ?? "").Trim().ToLowerInvariant();
static bool LooksLikeEmail(string email) => email.Contains('@') && email.Contains('.') && email.Length > 5;

static async Task<Dictionary<string, string?>> ReadJson(HttpRequest req)
{
    using var doc = await JsonDocument.ParseAsync(req.Body);
    var map = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
    foreach (var p in doc.RootElement.EnumerateObject())
        map[p.Name] = p.Value.ValueKind == JsonValueKind.String ? p.Value.GetString() : p.Value.ToString();
    return map;
}

static IEnumerable<string> LanAddresses()
{
    foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
    {
        if (ni.OperationalStatus != OperationalStatus.Up) continue;
        if (ni.NetworkInterfaceType is NetworkInterfaceType.Loopback) continue;
        foreach (var ip in ni.GetIPProperties().UnicastAddresses)
        {
            if (ip.Address.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(ip.Address))
                yield return ip.Address.ToString();
        }
    }
}

sealed class User
{
    public User(long id, string email, string name, string passwordHash, string token, bool isPlus, string? plan, int free)
    {
        Id = id; Email = email; Name = name; PasswordHash = passwordHash;
        Token = token; IsPlus = isPlus; Plan = plan; FreeEmptiesLeft = free;
    }
    public long Id { get; }
    public string Email { get; }
    public string Name { get; }
    public string PasswordHash { get; }
    public string Token { get; set; }
    public bool IsPlus { get; set; }
    public string? Plan { get; set; }
    public int FreeEmptiesLeft { get; set; }
}

file static class DictExt
{
    public static string? Get(this Dictionary<string, string?> d, string key) =>
        d.TryGetValue(key, out var v) ? v : null;
}
