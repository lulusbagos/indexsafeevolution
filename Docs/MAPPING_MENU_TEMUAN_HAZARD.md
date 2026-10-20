# 🗺️ Pemetaan Menu: Temuan Hazard (Indexsafe Evolution)

Dokumen ini memetakan seluruh file Dart, endpoint backend, dependensi SQLite offline, dan status penggunaan komponen untuk modul **Temuan Hazard**. Dokumen ini dibuat untuk memudahkan proses audit, pembersihan, dan penghapusan file-file `.dart` warisan (*legacy*) dari proyek Indexsafe lama yang sudah tidak digunakan.

---

## 📌 1. Ikhtisar Menu Temuan Hazard

- **Nama Menu**: Temuan Hazard (Pelaporan & Manajemen Bahaya K3 Pertambangan)
- **Fungsi Utama**: 
  - Pelaporan bahaya keselamatan kerja langsung dari lapangan (KTA vs TTA).
  - Klasifikasi 12 jenis bahaya dengan icon tematik & dropdown profesional.
  - Penilaian tingkat risiko 4 kotak (Rendah, Sedang, Tinggi, Ekstrim) dengan SLA & banner SWA (*Stop Work Authority*).
  - Integrasi Master Area Utama & Benchmark dari database `tbl_m_benchmark`.
  - Pencarian Penanggung Jawab Area (PJA) lintas perusahaan.
  - Mode Offline (SQLite) & sinkronisasi otomatis saat terhubung jaringan internet.

---

## 📂 2. Pemetaan File Dart (Active vs Legacy)

Berikut adalah status file di direktori `Mobile/lib/pages/hazard/`:

| Nama File | Path | Status | Deskripsi & Catatan |
| :--- | :--- | :---: | :--- |
| **`hazard_create_page.dart`** | `Mobile/lib/pages/hazard/hazard_create_page.dart` | **🟢 AKTIF (NEW)** | **Formulir utama pembuatan & edit laporan hazard**. Menggunakan UI modern lapangan, dropdown 12 jenis bahaya, 4 kotak tingkat risiko, KTA/TTA, GPS, dan offline storage. |
| **`hazard_hub_page.dart`** | `Mobile/lib/pages/hazard/hazard_hub_page.dart` | **🟢 AKTIF (NEW)** | **Dashboard / Hub Menu Hazard**. Menampilkan ringkasan statistik (Open, In Progress, Closed), filter status, dan navigasi pelaporan baru. |
| **`hazard_detail_page.dart`** | `Mobile/lib/pages/hazard/hazard_detail_page.dart` | **🟢 AKTIF (NEW)** | **Halaman rincian laporan**. Digunakan pengawas/PJA untuk melihat bukti foto before/after, lokasi GPS, dan approval tindak lanjut perbaikan. |
| **`hazard_form_page.dart`** | `Mobile/lib/pages/hazard/hazard_form_page.dart` | **🔴 LEGACY (Kandidat Hapus)** | *Formulir versi lama bawaan Indexsafe terdahulu*. Sudah digantikan sepenuhnya oleh `hazard_create_page.dart`. |
| **`hazard_page.dart`** | `Mobile/lib/pages/hazard/hazard_page.dart` | **🔴 LEGACY (Kandidat Hapus)** | *Tampilan list hazard versi lawas*. Sudah digantikan fungsinya oleh `hazard_hub_page.dart`. |

---

## 🔗 3. Dependensi File Pendukung (Services & Database)

File-file inti yang menyokong modul Temuan Hazard:

| Komponen | Path File | Fungsi Terkait |
| :--- | :--- | :--- |
| **API Client** | `Mobile/lib/services/api.dart` | Menyediakan fungsi HTTP `getMasterAreas()`, `getBenchmarksByArea()`, `createHazard()`, `searchPja()`, dan upload file bukti foto. |
| **Local SQLite** | `Mobile/lib/services/database_helper.dart` | Menyimpan draft hazard offline (`offline_hazards`), cache master benchmark, dan antrean sinkronisasi latar belakang. |
| **Global Theme** | `Mobile/lib/theme.dart` | Token warna K3, typography, radius sudut, dan elevation. |
| **Snackbar Helper** | `Mobile/lib/widgets/snackbar.dart` / `Mobile/lib/utils/snackbar_msg.dart` | Menampilkan notifikasi visual toast/alert kepada user lapangan. |

---

## 🌐 4. Integrasi Backend (C# .NET Core) & Database

Modul Temuan Hazard terhubung ke controller backend berikut:

| Endpoint Backend | Controller | Sumber Tabel Database | Deskripsi |
| :--- | :--- | :--- | :--- |
| `GET /api/master/benchmark/areas` | `MasterController.cs` | `[DB_SAP].[dbo].[tbl_m_benchmark]` (DISTINCT `area_utama`) | Mengambil daftar area utama berdasarkan `perusahaan_id` pengguna yang login. |
| `GET /api/master/benchmark/by-area` | `MasterController.cs` | `[DB_SAP].[dbo].[tbl_m_benchmark]` | Mengambil daftar nama benchmark untuk area yang dipilih. |
| `POST /api/master/benchmark/create` | `MasterController.cs` | `[DB_SAP].[dbo].[tbl_m_benchmark]` | Menambahkan benchmark baru secara langsung dari aplikasi mobile bila lokasi belum ada. |
| `POST /api/hazard/create` | `HazardController.cs` | `[DB_SAP].[dbo].[tbl_t_hazard]` | Menyimpan laporan temuan hazard baru beserta koordinat GPS, KTA/TTA, dan foto bukti. |
| `GET /api/user/pja/search` | `UserController.cs` | `[DB_SAP].[dbo].[tbl_m_karyawan]` | Pencarian NIK, nama, departemen, dan perusahaan penanggung jawab area. |

---

## 🎨 5. Struktur Data Komponen Baru (hazard_create_page.dart)

### A. 4 Kotak Tingkat Risiko (2x2 Grid Berimbang)
Menggunakan `IntrinsicHeight` dan `CrossAxisAlignment.stretch` agar proporsi 4 kotak seragam di seluruh resolusi layar smartphone:
1. **Rendah (L)**: `Color(0xFF059669)` • Icon `Icons.verified_user_rounded` • SLA: *Rutin / Berkala*.
2. **Sedang (M)**: `Color(0xFFD97706)` • Icon `Icons.info_outline_rounded` • SLA: *Maks. 3 Hari*.
3. **Tinggi (H)**: `Color(0xFFEA580C)` • Icon `Icons.warning_amber_rounded` • SLA: *Maks. 24 Jam*.
4. **Ekstrim (E)**: `Color(0xFFDC2626)` • Icon `Icons.dangerous_rounded` • SLA: *STOP KERJA! (SWA)*.

### B. Dropdown Profesional 12 Jenis Bahaya
Menggunakan `DropdownButton` dengan `selectedItemBuilder`:
- Menampilkan icon spesifik berlatar warna tematik lembut.
- Menampilkan judul tebal nama bahaya keselamatan pertambangan.
- Menampilkan baris kedua berisikan contoh kasus lapangan konkret (misal: *Limbah B3, jalan hauling amblas, kabel terkelupas, getaran alat kerja*).
- Menjamin tidak ada teks terpotong (*zero overflow*).

### C. Segmented Card Kategori Bahaya
- **Kondisi Tidak Aman (KTA)**: Fokus pada fisik peralatan, jalan tambang, atau fasilitas kerja.
### D. Integrasi Notifikasi ([DB_SAP].[dbo].[tbl_t_notifications])
Tabel ini digunakan untuk sistem notifikasi penugasan dan peringatan K3:
- Kolom tabel: `id`, `recipient_nik`, `title`, `message`, `url`, `is_read`, `created_at`, `notif_type`, `is_actioned`.
- **Aturan Filter**: Notifikasi yang sudah complete (`is_actioned == 1` atau bertipe `hazard_completed`/`hazard_closed`) **tidak ditampilkan** pada daftar notifikasi mobile (`/api/notifications`) maupun counter badge dashboard.
- **Deep Linking (`url`)**: Mengarahkan user langsung ke menu terkait (misal: `/Hazard/Index` diarahkan langsung ke `HazardHubPage`).
- **Aksi Selesai**: Saat laporan ditindaklanjuti/take-up atau ditutup oleh PJA, `is_actioned` di-set menjadi `1`, sehingga notifikasi otomatis keluar dari antrean tugas aktif.

---

## 🗑️ 6. Rekomendasi Langkah Pembersihan (*Pruning*) Selanjutnya

Untuk menghapus file `.dart` yang tidak terpakai tanpa merusak build:
1. **Verifikasi Referensi**:
   Cek apakah `hazard_form_page.dart` atau `hazard_page.dart` masih di-import di `Mobile/lib/pages/dashboard_page.dart` atau file routing lainnya.
2. **Alihkan Routing**:
   Pastikan tombol *"Temuan Hazard"* di Dashboard membuka `HazardHubPage()` atau `HazardCreatePage()`.
3. **Penghapusan Aman**:
   Hapus `Mobile/lib/pages/hazard/hazard_form_page.dart` dan `Mobile/lib/pages/hazard/hazard_page.dart`.
4. **Lanjutkan ke Modul Lain**:
   Lakukan pemetaan serupa untuk modul P5M, Inspeksi, BBS, P2H, dan Coaching secara bertahap.
