# 04 - Desain Arsitektur Backend (ASP.NET Core & SQL Server)

Dokumen ini merancang arsitektur backend performa tinggi menggunakan **ASP.NET Core (.NET 8/9)** yang berjalan di atas **Windows Server** dengan database **Microsoft SQL Server**.

---

## 1. Topologi Sistem & Deployment di Windows Server

```
 [ Android / iOS Mobile ]
          │ (REST API / HTTPS)
          ▼
 ┌───────────────────────────────────────────────┐
 │ Windows Server (IIS / Windows Service)        │
 │                                               │
 │  ┌─────────────────────────────────────────┐  │
 │  │ ASP.NET Core (.NET 8/9) Web API        │  │
 │  │ - Kestrel / In-Process IIS Module       │  │
 │  │ - JWT Authentication & Authorization   │  │
 │  │ - Controllers & Idempotency Filter     │  │
 │  │ - Dapper / EF Core Data Layer           │  │
 │  │ - BackgroundService (Image Processor)   │  │
 │  └────────────────────┬────────────────────┘  │
 │                       │                       │
 │      ┌────────────────┴───────────────┐       │
 │      ▼                                ▼       │
 │ ┌─────────────────────────┐ ┌───────────────┐ │
 │ │ Microsoft SQL Server    │ │ Local Storage │ │
 │ │ (IndexsafeDB)           │ │ (Uploads)     │ │
 │ └─────────────────────────┘ └───────────────┘ │
 └───────────────────────────────────────────────┘
```

---

## 2. Struktur Proyek Backend yang Direkomendasikan

Menggunakan pola **Clean Architecture / Modular Service** di dalam folder `Backend/`:

```text
Backend/
├── Indexsafe.Api/                 # Web API Host, Controller, Middleware, Filter
│   ├── Controllers/
│   │   ├── AuthController.cs      # Login, Register, Profile, Change Password
│   │   ├── MasterController.cs    # GET /api/master/{name} (Cached)
│   │   ├── TransactionController.cs # POST /api/tran/{name}, /detail/{name}
│   │   ├── ActionPlanController.cs  # POST /api/action/{name}
│   │   └── FilesController.cs       # Upload & File streaming
│   ├── Middlewares/               # Idempotency, Global Exception Handler
│   ├── BackgroundJobs/            # Background Worker (Image Compression/Resize)
│   ├── appsettings.json           # Connection string & JWT configuration
│   └── Program.cs                 # Dependency Injection & Pipeline setup
│
├── Indexsafe.Core/                # Domain Entities, DTOs, Interfaces
│   ├── Entities/                  # Entity C# untuk setiap tabel SQL Server
│   └── DTOs/                      # Request / Response Models
│
└── Indexsafe.Infrastructure/      # SQL Server Context, Dapper Repositories, Migrations
    ├── Data/                      # Entity Framework Core DbContext
    ├── Repositories/              # Dapper Bulk Data Access (High Speed)
    └── Services/                  # File Storage Service
```

---

## 3. Strategi Menangani Transaksi Berat & Offline Sync

### A. Idempotency Key (Mencegah Duplikasi Data Saat Retry)
Pekerja di pit tambang sering mengalami sinyal timbul-tenggelam. Saat mobile mengirim `POST /api/tran/inspection`, request mungkin berhasil masuk ke server, tetapi responnya gagal sampai ke HP. Mobile akan otomatis mengirim ulang (retry).
- **Solusi**: Tambahkan header atau field `client_uuid` (atau kombinasi `employee_id` + `local_id` + `date`).
- **Di Backend**: Buat Unique Constraint di SQL Server pada `(employee_id, client_id, date)`. Jika record sudah ada, backend cukup mengembalikan ID yang sudah tersimpan tanpa melakukan *duplicate insert*.

### B. High-Speed Bulk Data Access (Dapper & SqlBulkCopy)
Untuk operasi baca data master (`GET /api/master/{name}?limit=10000`) dan batch insert:
- Gunakan **Dapper** atau `Microsoft.Data.SqlClient` mentah daripada ORM berat.
- Gunakan **In-Memory Cache (`IMemoryCache`)** untuk master data (`enum_masters`, `vehicle_masters`, `inspection_masters`). Karena data master jarang berubah, cache memory akan merespon request download master dalam waktu < 5 milidetik tanpa membebani SQL Server.

### C. Pemrosesan Foto di Background Channel
Upload foto transaksi lapangan dari HP beresolusi tinggi dapat memperlambat respon sync:
- Simpan file mentah langsung ke disk (`FileStream`).
- Masukkan path gambar ke antrian internal `System.Threading.Channels`.
- Berikan respon HTTP `200 OK` seketika kepada mobile agar proses sinkronisasi cepat selesai.
- `BackgroundService` di server akan mengompres/watermark foto secara asynchronous di thread terpisah.

---

## 4. DDL Skema Inti SQL Server (Contoh Tabel Transaksi)

```sql
-- Database: IndexsafeDB
CREATE DATABASE IndexsafeDB;
GO
USE IndexsafeDB;
GO

-- 1. Header Inspeksi
CREATE TABLE [dbo].[inspection_trans] (
    [id] BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    [code] NVARCHAR(100) NULL,
    [title] NVARCHAR(255) NULL,
    [area_id] INT NULL,
    [location_id] INT NULL,
    [location_detail] NVARCHAR(500) NULL,
    [date] DATE NOT NULL,
    [time] NVARCHAR(20) NULL,
    [inspection_id] INT NULL,
    [shift_id] INT NULL,
    [danger_level] NVARCHAR(50) NULL,
    [remark] NVARCHAR(MAX) NULL,
    [image_url] NVARCHAR(500) NULL,
    [video_url] NVARCHAR(500) NULL,
    [status] INT DEFAULT 1,
    [category] NVARCHAR(100) NULL,
    [inspektor1_id] INT NULL,
    [inspektor2_id] INT NULL,
    [pja_id] INT NULL,
    [company_id] INT NOT NULL,
    [employee_id] INT NOT NULL,
    [client_uuid] NVARCHAR(100) NULL, -- Idempotency key dari mobile
    [created_at] DATETIME2 DEFAULT SYSUTCDATETIME(),
    [updated_at] DATETIME2 NULL,
    [deleted_at] DATETIME2 NULL
);
CREATE NONCLUSTERED INDEX [IX_inspection_trans_emp_date] 
ON [dbo].[inspection_trans] ([company_id], [employee_id], [date]);

-- 2. Detail Item Checklist Inspeksi
CREATE TABLE [dbo].[inspection_details] (
    [id] BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    [tran_id] BIGINT NOT NULL, -- Relasi ke [inspection_trans].[id]
    [name] NVARCHAR(255) NULL,
    [point_id] INT NULL,
    [level] INT NULL,
    [yesno] INT NULL, -- 1: Aman / Sesuai, 0: Temuan Bahaya
    [remark] NVARCHAR(MAX) NULL,
    [image_url] NVARCHAR(500) NULL,
    [status] INT DEFAULT 1,
    [repair] INT DEFAULT 0,
    [repair_remark] NVARCHAR(MAX) NULL,
    [repair_image_url] NVARCHAR(500) NULL,
    [created_at] DATETIME2 DEFAULT SYSUTCDATETIME(),
    [updated_at] DATETIME2 NULL,
    CONSTRAINT [FK_inspection_details_tran] FOREIGN KEY ([tran_id]) 
        REFERENCES [dbo].[inspection_trans]([id]) ON DELETE CASCADE
);
CREATE NONCLUSTERED INDEX [IX_inspection_details_tran_id] 
ON [dbo].[inspection_details] ([tran_id]);
```

---

## 5. Konfigurasi Connection String SQL Server Optimal

Di `appsettings.json`:
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=IndexsafeDB;User Id=sa;Password=YourStrongPassword!;TrustServerCertificate=True;MultipleActiveResultSets=True;Max Pool Size=200;Min Pool Size=10;Connect Timeout=30;"
  }
}
```
- `Max Pool Size=200`: Memungkinkan hingga 200 koneksi database simultan saat lonjakan sinkronisasi pergantian shift kerja.
- `Min Pool Size=10`: Menjaga koneksi selalu siap pakai tanpa latency pembuatan koneksi baru.
