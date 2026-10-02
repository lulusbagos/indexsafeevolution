using System;
using System.IO;
using System.Text;
using Indexsafe.Api.Data;
using Indexsafe.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.IdentityModel.Tokens;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(new WebApplicationOptions
{
    Args = args,
    ContentRootPath = AppContext.BaseDirectory
});

// Configure Kestrel to listen on 0.0.0.0 and port 7071 (or from config)
var configuredUrl = builder.Configuration["Urls"];
int port = 7071;
if (!string.IsNullOrEmpty(configuredUrl) && Uri.TryCreate(configuredUrl.Split(';')[0], UriKind.Absolute, out var parsedUri))
{
    port = parsedUri.Port;
}
else if (builder.Environment.IsDevelopment())
{
    port = 5200;
}

builder.WebHost.ConfigureKestrel(serverOptions =>
{
    serverOptions.AddServerHeader = false;
    serverOptions.Limits.MaxRequestBodySize = 52428800; // 50 MB
    serverOptions.Listen(System.Net.IPAddress.Any, port);
});


// 1. Connection string & SQL Server DbContext
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(connectionString, sqlServerOptionsAction =>
        sqlServerOptionsAction.EnableRetryOnFailure(
            maxRetryCount: 10,
            maxRetryDelay: TimeSpan.FromSeconds(3),
            errorNumbersToAdd: null)));

// 2. JWT Bearer Authentication
var jwtSecret = builder.Configuration["Jwt:Secret"] ?? "Indexsafe_Evolution_Secret_Key_2026_Enterprise_K3_Mining_Auth_Tokens_Min32Chars!";
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "Indexsafe.Api";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "Indexsafe.Mobile";

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = false;
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtIssuer,
        ValidAudience = jwtAudience,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
        ClockSkew = TimeSpan.Zero
    };
});

// 3. Dependency Injection Services
builder.Services.AddSingleton<SyncMonitorService>();
builder.Services.AddScoped<CompanyHierarchyService>();
builder.Services.AddScoped<JwtService>();
builder.Services.AddSingleton<ImageUploadService>();
builder.Services.AddScoped<PermitService>();

// 4. Controllers & JSON settings
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull;
    });

// 5. CORS configuration (allowing mobile apps, emulators, web clients)
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// 6. Native .NET 10 OpenAPI
builder.Services.AddOpenApi();

var app = builder.Build();

// Enable interactive API Documentation (Scalar UI) at /scalar/v1
app.MapOpenApi();
app.MapScalarApiReference(options =>
{
    options.WithTitle("Indexsafe Evolution API");
    options.WithTheme(ScalarTheme.Moon);
});

app.UseCors("AllowAll");

// Serve Default Files (index.html at root /) and Static Files
app.UseDefaultFiles();
app.UseStaticFiles();

// Also serve physical uploaded files from C:\MinePermitFiles\MBS if available
if (Directory.Exists(@"C:\MinePermitFiles\MBS"))
{
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(@"C:\MinePermitFiles\MBS"),
        RequestPath = "/uploads"
    });
}

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
