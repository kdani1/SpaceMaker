using Microsoft.AspNetCore.StaticFiles;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls("http://0.0.0.0:42579");
var app = builder.Build();

var apkSource = Path.GetFullPath(Path.Combine(app.Environment.ContentRootPath, "..", "dist", "spacemaker.apk"));
var webRoot = Path.Combine(app.Environment.ContentRootPath, "wwwroot");
Directory.CreateDirectory(webRoot);
var apkPublic = Path.Combine(webRoot, "spacemaker.apk");
if (File.Exists(apkSource))
{
    File.Copy(apkSource, apkPublic, overwrite: true);
}

var types = new FileExtensionContentTypeProvider();
types.Mappings[".apk"] = "application/vnd.android.package-archive";
app.UseDefaultFiles();
app.UseStaticFiles(new StaticFileOptions
{
    ContentTypeProvider = types,
    ServeUnknownFileTypes = true,
    OnPrepareResponse = ctx =>
    {
        if (ctx.File.Name.EndsWith(".apk", StringComparison.OrdinalIgnoreCase))
        {
            ctx.Context.Response.Headers.ContentDisposition = "attachment; filename=\"spacemaker.apk\"";
            ctx.Context.Response.Headers.CacheControl = "no-store";
        }
    }
});

app.MapGet("/health", () => Results.Ok(new { ok = true, apk = File.Exists(apkPublic) }));

app.Run();
