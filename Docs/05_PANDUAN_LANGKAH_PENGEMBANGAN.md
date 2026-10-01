# 05 - Panduan Langkah Pengembangan (Roadmap Eksekusi)

Gunakan panduan ini sebagai peta jalan (*roadmap*) kapan saja Anda ingin melanjutkan pembuatan backend dan menghubungkannya dengan aplikasi mobile.

---

## 🧭 Roadmap Langkah demi Langkah

```
 [ Tahap 1: Inisialisasi ] ──► [ Tahap 2: Database & Auth ] ──► [ Tahap 3: Master Data ]
                                                                       │
 [ Tahap 6: Deployment ]   ◄── [ Tahap 5: Uji Offline Sync ] ◄── [ Tahap 4: Transaksi & File ]
```

---

### Tahap 1: Persiapan & Inisialisasi Proyek Backend
1. **Periksa Ketersediaan .NET SDK**:
   Pastikan .NET 8 atau .NET 9 SDK sudah terpasang di sistem dengan menjalankan:
   ```powershell
   dotnet --version
   ```
2. **Inisiasi Proyek ASP.NET Core di Folder `Backend/`**:
   Jalankan perintah berikut di direktori `Backend/`:
   ```powershell
   cd "d:\4. PROJECT\13. Mobile\Indexsafe Evolution\Backend"
   dotnet new webapi -n Indexsafe.Api --use-controllers
   ```
3. **Instal Package NuGet Esensial**:
   ```powershell
   dotnet add Indexsafe.Api package Microsoft.Data.SqlClient
   dotnet add Indexsafe.Api package Dapper
   dotnet add Indexsafe.Api package Microsoft.EntityFrameworkCore.SqlServer
   dotnet add Indexsafe.Api package Microsoft.AspNetCore.Authentication.JwtBearer
   ```

---

### Tahap 2: Setup Database SQL Server & Modul Autentikasi
1. Buat database baru di SQL Server Management Studio (SSMS):
   ```sql
   CREATE DATABASE IndexsafeDB;
   ```
2. Buat tabel pengguna (`users`) dan profil karyawan (`employees`).
3. Buat endpoint `POST /api/login`:
   - Menerima payload `{ email, password }`.
   - Menghasilkan token JWT dengan masa aktif yang sesuai (misal: 30 hari untuk kemudahan mobile).
   - Mengembalikan data pengguna sesuai format yang diharapkan oleh `AuthModel` di mobile.
4. Buat endpoint `GET /api/profile`:
   - Mengembalikan profil lengkap karyawan sesuai `ProfileModel`.

---

### Tahap 3: Modul Master Data (Download ke Mobile)
Aplikasi mobile membutuhkan endpoint ini saat pertama kali login di `SyncPage`:
1. Buat controller `MasterController` dengan route:
   ```csharp
   [HttpGet("/api/master/{name}")]
   public async Task<IActionResult> GetMaster(string name, [FromQuery] int limit = 10000)
   ```
2. Isi data master untuk 12 kategori:
   - `enum`, `bridges`, `inspection`, `hazard`, `coaching`, `k3`, `observation`, `p2h`, `p5m`, `safety`, `employee`, `vehicle`.
3. Pasang caching memory (`IMemoryCache`) agar query master data tidak menguras IOPS database.

---

### Tahap 4: Modul Transaksi Offline Sync & File Upload
1. Buat controller `TransactionController`:
   - `POST /api/tran/{name}`: Menyimpan data header inspeksi/hazard/p2h, mengembalikan `{ data: { id: <new_id> } }`.
   - `POST /api/detail/{name}`: Menyimpan item checklist yang berelasi ke header via `ref_id`.
   - `POST /api/action/{name}`: Menyimpan dan memperbarui rencana tindakan (*action plan*).
2. Buat controller `FilesController`:
   - `POST /api/files`: Menerima upload file multipart, menyimpannya di folder disk Windows Server (`wwwroot/uploads`), dan menyimpan relasinya di tabel `files`.

---

### Tahap 5: Pengujian Integrasi Mobile (End-to-End Test)
1. **Konfigurasi Base URL di Mobile**:
   Ubah konstanta `baseUrl` di [`Mobile/lib/services/api.dart`](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Mobile/lib/services/api.dart):
   ```dart
   // Ganti dengan IP komputer lokal / server lokal Anda
   final baseUrl = 'http://192.168.1.100:5000';
   ```
2. **Uji Kasus 1 - Sinkronisasi Awal**:
   - Buka aplikasi mobile, login online, pastikan progress bar di `SyncPage` berhasil mengunduh seluruh 12 tabel master hingga 100%.
3. **Uji Kasus 2 - Transaksi Mode Pesawat (Offline)**:
   - Aktifkan Airplane Mode di HP.
   - Buat laporan Hazard baru dan checklist P2H lengkap dengan foto.
   - Pastikan data tersimpan di SQLite lokal tanpa error.
4. **Uji Kasus 3 - Eksekusi Sinkronisasi (Kembali Online)**:
   - Matikan Airplane Mode.
   - Masuk ke menu Sinkronisasi atau tunggu timer background berjalan.
   - Verifikasi bahwa data di HP mendapat `sync_id` dan baris transaksi muncul di SQL Server.

---

### Tahap 6: Deployment Produksi di Windows Server (IIS)
1. Aktifkan fitur **IIS** dan pasang **ASP.NET Core Hosting Bundle** (.NET 8/9).
2. Publikasikan backend:
   ```powershell
   dotnet publish -c Release -o "C:\inetpub\wwwroot\indexsafe-api"
   ```
3. Tambahkan Application Pool di IIS dengan opsi *.NET CLR Version = No Managed Code*.
4. Pasang sertifikat SSL (HTTPS) dan konfigurasikan Firewall Windows untuk membuka port API.
