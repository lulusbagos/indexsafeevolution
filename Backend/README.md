# Backend Service - Indexsafe Evolution

Backend REST API performa tinggi berbasis **ASP.NET Core (.NET 10)** untuk aplikasi mobile **Indexsafe Evolution**.
Aplikasi ini terhubung langsung ke basis data operasional pertambangan **`DB_SAP`** di SQL Server dan mengadopsi seluruh aturan bisnis, skema hierarki perusahaan (*multi-tenant*), dan otentikasi dari aplikasi web **MBS_SAP** (`D:\4. PROJECT\2. Web\MBS_SAP`).

---

## 1. Konfigurasi Database & Port
- **Database**: Microsoft SQL Server
  - Server: `172.16.1.93`
  - Database: `DB_SAP`
- **Base URL Server API**: `http://localhost:5200` atau `http://<IP_KOMPUTER>:5200`
- **Dokumentasi Interaktif (OpenAPI + Scalar UI)**: Buka di browser: `http://localhost:5200/scalar/v1`

---

## 2. Cara Menjalankan Backend
Cukup jalankan file batch:
```cmd
START_BACKEND.bat
```
Atau via terminal:
```bash
cd Backend
dotnet run
```

---

## 3. Fitur Utama & Kepatuhan Bisnis

### A. Otentikasi & Hak Akses Role (Sesuai Web MBS_SAP)
- **Endpoint**: `POST /api/login` (atau `POST /api/auth/login`)
- **Mekanisme Validasi**:
  1. Memeriksa *password override* di `tbl_m_pengguna_sandi`.
  2. Memeriksa `vw_pengguna` di SQL Server.
  3. Mendukung *fallback password default* `123456` bagi karyawan aktif.
  4. Wajib terdaftar dan berstatus aktif (`StatusAktif == true`) di database karyawan (`vw_karyawan`).
  5. Memvalidasi perusahaan yang tidak dikecualikan (`ExcludedCompanies`).
  6. Mengidentifikasi role (*Admin*, *Owner*, *Maincon*, *Subcon*, *Vendor*, *Operator*) dan hierarki perusahaan induk-anak.
  7. Menghasilkan **JWT Bearer Token** dengan masa aktif 30 hari.

### B. Arsitektur Multi-Tenant & Hierarki Perusahaan
- Dilengkapi dengan [`CompanyHierarchyService`](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Backend/Services/CompanyHierarchyService.cs) untuk memastikan user hanya dapat melihat dan mengakses data dalam hierarki perusahaannya masing-masing.

### C. Mode Offline & Dukungan GPS
- **Offline Outbox Sync**:
  - `POST /api/tran/{name}`: Mengunggah transaksi dari antrean lokal SQLite mobile (`hazard`, `inspection`, `coaching`, `observation`, `p5m`, `safety`, `p2h`).
  - Menyematkan koordinat GPS (`latitude`, `longitude`, `gps_accuracy`) ke dalam transaksi dan penanda lokasi.
  - Mengunggah foto bukti temuan lapangan secara otomatis dengan kompresi gambar cerdas (*ImageSharp*) untuk menghemat kuota internet di pit tambang.
  - Otomatis membuat *Action Plan* terbuka dan men-trigger notifikasi ke PJA yang ditugaskan.
- **Detail Checklist Sync**:
  - `POST /api/detail/{name}` & `POST /api/files` untuk sinkronisasi item periksa dan lampiran file.
- **Action Plan Follow-up**:
  - `POST /api/action/{name}` untuk unggah foto hasil perbaikan dan penutupan temuan oleh PIC/PJA.

### D. Master Data Cache untuk Kesiapan Offline
- `GET /api/master/{name}?limit=10000`:
  - `area` & `location`: Daftar area utama dan benchmark kerja tambang.
  - `employee`: Daftar karyawan untuk tagging PIC dan PJA.
  - `vehicle`: Master armada unit LV dan alat berat.
  - `hazard` & `inspection`: Kategori KTA/TTA, tingkat resiko, dan tipe inspeksi.
- `GET /api/hierarchy/companies`: Daftar perusahaan dalam hierarki user.
