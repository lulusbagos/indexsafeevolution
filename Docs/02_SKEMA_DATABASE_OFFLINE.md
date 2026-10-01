# 02 - Kamus Data & Skema Database Offline (SQLite)

Dokumen ini memuat spesifikasi struktur tabel lengkap dari database lokal SQLite mobile (`isafe18.db`) yang diekstrak langsung dari [`database.dart`](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Mobile/lib/services/database.dart).

Struktur ini adalah acuan langsung dalam merancang tabel di **Microsoft SQL Server**.

---

## 1. Tabel-Tabel Master (Disinkronkan dari Server ke Mobile)

Data master di-download sekali saat pertama login (`SyncPage`), lalu disimpan di SQLite agar aplikasi bisa memilih dropdown secara offline.

### 1.1 `enum_masters`
Menyimpan data enum/referensi umum (Area, Lokasi, Shift, Tipe Bahaya, dll).
- `id` (INTEGER PK)
- `code` (TEXT)
- `name` (TEXT)
- `type` (TEXT)
- `flag` (TEXT)
- `ref_id` (INTEGER) - Relasi ke parent enum
- `created_at`, `updated_at`, `deleted_at` (TEXT)

### 1.2 `enum_bridges`
Menghubungkan relasi many-to-many antar enum (misal Area ke Lokasi kerja).
- `id` (INTEGER PK)
- `flag` (TEXT)
- `primary_id` (INTEGER)
- `secondary_id` (INTEGER)
- `created_at`, `updated_at`, `deleted_at` (TEXT)

### 1.3 `inspection_masters`
Item kriteria checklist inspeksi K3.
- `id` (INTEGER PK)
- `code`, `name`, `type`, `flag` (TEXT)
- `level` (INTEGER)
- `yesno` (INTEGER) - 1: tipe checklist Ya/Tidak
- `categories` (TEXT)
- `ref_id` (INTEGER)
- `created_at`, `updated_at`, `deleted_at` (TEXT)

### 1.4 `hazard_masters`, `coaching_masters`, `k3_masters`, `observation_masters`, `p2h_masters`, `p5m_masters`, `safety_masters`
Struktur standar untuk seluruh master checklist K3:
- `id` (INTEGER PK)
- `code`, `name`, `type`, `flag` (TEXT)
- `level` (INTEGER) - Tingkatan hirarki checklist
- `yesno` (INTEGER, opsional di hazard/coaching)
- `ref_id` (INTEGER) - Parent master ID
- `created_at`, `updated_at`, `deleted_at` (TEXT)

### 1.5 `vehicle_masters`
Master data armada kendaraan dan alat berat.
- `id` (INTEGER PK)
- `code`, `name`, `type` (TEXT)
- `ellipse_code`, `unit`, `brand`, `company`, `chassis_no`, `engine_no`, `cn_type`, `license_plate` (TEXT)
- `year` (INTEGER)
- `remark` (TEXT)
- `employee_id` (INTEGER)
- `created_at`, `updated_at`, `deleted_at` (TEXT)

### 1.6 `employees`
Data karyawan (juga digunakan untuk autentikasi offline berbasis NIK).
- `id` (INTEGER PK)
- `no_nik`, `nama_lengkap`, `nama_alias` (TEXT)
- `tmp_lahir`, `tgl_lahir` (TEXT)
- `email_pribadi`, `email_kantor`, `hp` (TEXT)
- `depart`, `section`, `posisi`, `foto` (TEXT)
- `user_id` (INTEGER)
- `company_id` (INTEGER)
- `created_at`, `updated_at`, `deleted_at` (TEXT)

---

## 2. Tabel-Tabel Transaksi (Header)

Setiap transaksi memiliki `sync_id` (Server ID setelah di-upload) dan `ref_id`.

### 2.1 `inspection_trans`
Header kegiatan inspeksi K3.
- `id` (INTEGER PK AUTOINCREMENT) - ID lokal perangkat
- `code`, `title` (TEXT)
- `area_id`, `location_id` (INTEGER)
- `location_detail` (TEXT)
- `date`, `time` (TEXT)
- `inspection_id`, `shift_id` (INTEGER)
- `danger_level`, `remark`, `image`, `video`, `category` (TEXT)
- `status` (INTEGER)
- `inspektor1_id` s/d `inspektor5_id` (INTEGER) - Tim inspektor
- `pja_id`, `company_id`, `employee_id` (INTEGER)
- `ref_id` (INTEGER)
- `sync_id` (INTEGER) - **ID dari Server (NULL jika belum tersinkronisasi)**
- `created_at`, `updated_at`, `deleted_at` (TEXT)

### 2.2 `hazard_trans`
Laporan temuan bahaya dan tindakan perbaikan langsung (Direct Repair).
- `id` (INTEGER PK AUTOINCREMENT)
- `code`, `title` (TEXT)
- `area_id`, `location_id` (INTEGER)
- `location_detail` (TEXT)
- `date`, `time` (TEXT)
- `hazard_id`, `hazard_type_id`, `hazard_subtype_id`, `hazard_danger_id` (INTEGER)
- `remark`, `image`, `video` (TEXT)
- `status` (INTEGER)
- **Field Perbaikan Langsung**:
  - `repair` (INTEGER) - 1: Selesai diperbaiki, 0: Belum
  - `repair_remark` (TEXT)
  - `repair_image`, `repair_video` (TEXT)
  - `repair_date`, `repair_time` (TEXT)
- `pja_id`, `company_id`, `employee_id` (INTEGER)
- `ref_id`, `sync_id` (INTEGER)
- `created_at`, `updated_at`, `deleted_at` (TEXT)

### 2.3 `p2h_trans`
Pemeriksaan harian kendaraan / alat berat sebelum operasi.
- `id` (INTEGER PK AUTOINCREMENT)
- `code`, `title` (TEXT)
- `area_id`, `location_id` (INTEGER)
- `location_detail` (TEXT)
- `date`, `time` (TEXT)
- `vehicle_id` (INTEGER)
- `hm`, `km` (REAL) - Catatan Hour Meter & Odometer KM
- `no_lambung`, `merek`, `remark`, `image`, `video` (TEXT)
- `status` (INTEGER)
- `simper` (INTEGER) - Validasi Surat Izin Mengemudi Perusahaan
- `company_id`, `employee_id` (INTEGER)
- `ref_id`, `sync_id` (INTEGER)
- `created_at`, `updated_at`, `deleted_at` (TEXT)

### 2.4 Transaksi Lainnya (`coaching_trans`, `k3_trans`, `observation_trans`, `p5m_trans`, `safety_trans`)
- Pola kolom identik: Area, Lokasi, Tanggal, Jam, Kategori/Topik, Status, Gambar, Video, `employee_id`, `company_id`, `sync_id`.
- Khusus `k3_trans`: Memiliki field tanda tangan `inductor_sign` & `employee_sign` (Base64 / Path File).

---

## 3. Tabel-Tabel Detail (Checklist Items)

Menyimpan status checklist per baris pertanyaan (misal pada Inspeksi atau P2H ada 20–40 item pengecekan).

Tabel: `inspection_details`, `p2h_details`, `k3_details`, `observation_details`, `coaching_details`, `p5m_details`, `safety_details`.

Kolom Umum:
- `id` (INTEGER PK AUTOINCREMENT) - ID lokal
- `name`, `type`, `flag` (TEXT)
- `level` (INTEGER)
- `yesno` (INTEGER) - Jawaban (1: Ya / Aman, 0: Tidak / Temuan)
- `remark` (TEXT)
- `image`, `video` (TEXT)
- `status` (INTEGER)
- `tran_id` (INTEGER) - Relasi ke ID header transaksi LOKAL
- `point_id` (INTEGER) - Relasi ke Master checklist
- `ref_id` (INTEGER) - **Server ID dari header transaksi (diisi setelah header disinkronkan)**
- `sync_id` (INTEGER) - **Server ID dari item detail ini**
- Field perbaikan khusus (misal pada `inspection_details`): `repair`, `repair_remark`, `repair_image`, `repair_video`.

---

## 4. Tabel Action Plan & Files

### 4.1 `action_plans`
Tindak lanjut temuan bahaya/deviasi.
- `id` (INTEGER PK)
- `code`, `title` (TEXT)
- `area_id`, `location_id`, `location_detail` (TEXT/INTEGER)
- `date`, `time`, `remark`, `image`, `video`, `status` (TEXT/INTEGER)
- `pja_id`, `pic_id` (INTEGER) - Penanggung jawab perbaikan
- `plan` (TEXT), `plan_date` (TEXT) - Rencana tindakan dan tenggat
- `overdue` (INTEGER), `reason` (TEXT) - Keterangan jika terlambat
- `action` (TEXT), `action_date` (TEXT), `action_image`, `action_video` (TEXT) - Realisasi tindakan
- `table` (TEXT) - Nama tabel asal (`inspection`, `hazard`, dll)
- `category` (TEXT)
- `tran_id`, `detail_id` (INTEGER)
- `company_id`, `employee_id` (INTEGER)
- `created_at`, `updated_at`, `deleted_at` (TEXT)

### 4.2 `files`
Attachment foto/dokumen pendukung yang diunggah ke server secara berkala.
- `id` (INTEGER PK AUTOINCREMENT)
- `name` (TEXT) - Nama/path file fisik di perangkat
- `type`, `table`, `category` (TEXT)
- `point_id`, `sync_id`, `tran_id`, `detail_id` (INTEGER)
- `created_at`, `updated_at`, `deleted_at` (TEXT)
