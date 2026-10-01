# Dokumentasi Proyek Indexsafe Evolution

Selamat datang di direktori dokumentasi resmi **Indexsafe Evolution**.
Dokumentasi ini disusun secara terstruktur berdasarkan hasil analisis mendalam terhadap source code aplikasi Flutter Mobile ([`Mobile/`](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Mobile)) dan kebutuhan arsitektur backend performa tinggi dengan **Microsoft SQL Server di Windows Server**.

---

## 📚 Daftar Isi Dokumen

| No | Dokumen | Deskripsi |
| :--- | :--- | :--- |
| **01** | [**01_SISTEM_DAN_ALUR_KERJA.md**](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Docs/01_SISTEM_DAN_ALUR_KERJA.md) | Ringkasan arsitektur sistem, fitur K3/HSE mobile, alur kerja Offline-First, dan mekanisme sinkronisasi data. |
| **02** | [**02_SKEMA_DATABASE_OFFLINE.md**](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Docs/02_SKEMA_DATABASE_OFFLINE.md) | Kamus data lengkap SQLite lokal (`isafe18.db`), mencakup 12 tabel master, 8 tabel transaksi, 6 tabel detail, tabel action plan, dan file attachment. |
| **03** | [**03_SPESIFIKASI_API_CONTRACT.md**](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Docs/03_SPESIFIKASI_API_CONTRACT.md) | Kontrak REST API lengkap yang dibutuhkan oleh mobile client: Endpoint, HTTP Method, Headers, Payload JSON/FormData, format response, dan penanganan error. |
| **04** | [**04_DESAIN_BACKEND_ASPNET_SQLSERVER.md**](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Docs/04_DESAIN_BACKEND_ASPNET_SQLSERVER.md) | Cetak biru arsitektur backend **ASP.NET Core (.NET 8/9)** teroptimasi untuk beban transaksi berat di **SQL Server Windows Server** (Bulk insert, Idempotency, Background Service). |
| **05** | [**05_PANDUAN_LANGKAH_PENGEMBANGAN.md**](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Docs/05_PANDUAN_LANGKAH_PENGEMBANGAN.md) | Panduan langkah demi langkah (roadmap) praktis untuk memulai pembuatan backend kapan saja Anda siap. |

---

## 🎯 Struktur Folder Workspace Saat Ini
```text
Indexsafe Evolution/
├── Docs/             # Folder dokumentasi komprehensif (Anda berada di sini)
│   ├── INDEX.md
│   ├── 01_SISTEM_DAN_ALUR_KERJA.md
│   ├── 02_SKEMA_DATABASE_OFFLINE.md
│   ├── 03_SPESIFIKASI_API_CONTRACT.md
│   ├── 04_DESAIN_BACKEND_ASPNET_SQLSERVER.md
│   └── 05_PANDUAN_LANGKAH_PENGEMBANGAN.md
├── Mobile/           # Kode aplikasi Flutter (ditarik dari GitHub alfiraodeng/icmbsmobile)
└── Backend/          # Folder target pengembangan backend
    └── README.md
```
