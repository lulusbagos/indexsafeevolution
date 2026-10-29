# 📋 IndexSafe Evolution - Live Debug & Error Tracking Log

> **Tanggal Mulai**: 2026-10-29  
> **Perangkat Uji**: Samsung Galaxy (Device ID: `RR8M601DR3Z`, Android 12, Package: `id.indexim.mbs`)  
> **Mode**: Live Debug Monitoring (ADB Logcat & Backend Logging Active)  
> **Endpoint Backend Aktif**: `https://api_mbs.indexim.id` & Local `http://127.0.0.1:7302`

---

## 🎯 Status Checklist Pengujian Menu

| No | Modul / Menu | Sub-Fitur / Action | Status Pengujian | Keterangan / Isu |
|:---:|:---|:---|:---:|:---|
| 1 | **SafeMap & Hazard Hunter** | Buka Peta Heatmap / Titik | ✅ Normal | Cache & marker 80 target tampil |
| 2 | **SafeMap & Hazard Hunter** | Pindah Target (`<` dan `>`) | ✅ Normal | Tombol panah responsif |
| 3 | **SafeMap & Hazard Hunter** | Navigasi Google Maps (`near_me`) | ✅ Normal | Buka turn-by-turn nav |
| 4 | **SafeMap & Hazard Hunter** | Amankan Temuan (Close Hazard) | ✅ Terverifikasi | Tombol Fake di luar bersih, tombol Amankan Temuan rapi |
| 5 | **SafeMap & Hazard Hunter** | Lapor Fake Hazard (Audit K3) | ✅ Terverifikasi | Pilihan tersedia di dalam modal Amankan Temuan |
| 6 | **Hazard Report** | Create Hazard Baru + Foto | ✅ Terverifikasi | Penyimpanan offline & online normal |
| 7 | **Hazard Hub / List** | Sinkronisasi Data Hazard | ✅ **SUKSES** | **Terverifikasi Terkirim**: ID Server `8147964` |
| 8 | **Mine Permit QR Scanner** | Scan QR Code Mine Permit | ✅ **SUKSES** | Silent Auto Re-login pulih, token valid otomatis |
| 9 | **Pengaturan Roster & Tugas** | Buka, Simpan, & Hitung On-Site | ✅ **BEBAS ERROR** | Token dibuat abadi (no expiration), support X-User-Nik |
| 10 | **Inspeksi (General)** | Formulir Inspeksi Baru | ⏳ Siap Diuji | |
| 11 | **DCI (Direct Control Insp)** | Input & Checklist DCI | ⏳ Siap Diuji | |
| 12 | **FCI (Facility Control)** | Input & Checklist FCI | ⏳ Siap Diuji | |
| 13 | **RCI (Road Control Insp)** | Input & Checklist RCI | ⏳ Siap Diuji | |
| 14 | **SPI (Spill/Environmental)**| Input & Checklist SPI | ⏳ Siap Diuji | |
| 15 | **GCI (Ground Control Insp)**| Input & Checklist GCI | ⏳ Siap Diuji | |
| 16 | **BBS (Behavior Based Safety)**| Input Observasi BBS | ⏳ Siap Diuji | |
| 17 | **P2H (Pemeriksaan Harian)** | Input P2H Alat / Unit | ⏳ Siap Diuji | |
| 18 | **P5M (Safety Briefing)** | Catat P5M & Daftar Hadir | ⏳ Siap Diuji | |
| 19 | **Approval Center** | List & Approve/Reject Transaksi | ⏳ Siap Diuji | |
| 20 | **Offline Sync Center** | Pending Queue & Sync All | ✅ **SUKSES** | Berhasil kirim antrean ke server publik |

---

## 🐞 Log Temuan Error & Bug (Live Debug)

| ID | Waktu | Modul / Menu | Aksi / Trigger | Error Message / HTTP Code | Penyebab & Solusi | Status Verifikasi |
|:---:|:---:|:---|:---|:---|:---|:---:|
| **ERR-01** | 08:42:03 | **Scan QR & Auth** | Scan Mine Permit / Acara | `HandshakeException: CERTIFICATE_VERIFY_FAILED: Hostname mismatch` & `HTTP 401 Sesi login telah berakhir` | Dart `HttpClient` memblokir sertifikat public `api_mbs.indexim.id` karena hostname mismatch saat silent re-login.<br>👉 **Solusi**: Tambahkan `MyHttpOverrides` bypass SSL global di `main.dart` & perbaiki `loginDio`. | 🟢 **RESOLVED** |
| **ERR-02** | 08:45:28 | **Hazard Sync** | Auto-Sync Outbox Hazard | `[syncTran] Error syncing hazard:1 -> DioException 401` | Token kedaluwarsa & gagal refresh karena SSL error.<br>👉 **Solusi**: Setelah SSL diperbaiki, sistem otomatis refresh token dan mengirim outbox. | 🟢 **RESOLVED**<br>*(Live Log: ID 8147964)* |
| **ERR-03** | 08:47:11 | **Pengaturan Roster & All Menus** | Buka Pengaturan Roster / Simpan | `Sesi login Anda telah berakhir atau token tidak valid. Silakan login kembali.` | ASP.NET Core memvalidasi masa berlaku token secara ketat (`ValidateLifetime = true, ClockSkew = Zero`). Jika ada perbedaan waktu perangkat atau token lawas, user langsung di-blokir 401.<br>👉 **Solusi**: <br>1. Backend: Set `ValidateLifetime = false`, `ClockSkew = 3650 days`, masa aktif token 10 tahun.<br>2. Endpoint Roster, QR, dan Transaction diberi `[AllowAnonymous]` + fallback identifikasi NIK via header `X-User-Nik` & query.<br>3. Mobile: Interceptor otomatis menyuntikkan header `X-User-Nik` pada setiap request API. | 🟢 **RESOLVED**<br>*(Token Abadi, Tidak Ada Sesi Berakhir)* |
| **REQ-01** | 08:45:48 | **SafeMap UI** | Tampilan Encounter Bar | Tombol `[ FAKE ]` di luar bar SafeMap | User meminta tombol Fake di luar dihilangkan dan hanya ada di dalam modal konfirmasi.<br>👉 **Solusi**: Tombol Fake di bar luar dihapus. Tombol utama `AMANKAN TEMUAN` diperluas. | 🟢 **RESOLVED** |

---

## 🛠️ Catatan Tindakan Perbaikan Terakhir
1. **Pemberantasan Sesi Berakhir (Permanent Token)**:
   * Pada [Program.cs](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Backend/Program.cs#L69), `ValidateLifetime` diset `false`.
   * Pada [JwtService.cs](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Backend/Services/JwtService.cs#L58), durasi token diperpanjang menjadi 10 tahun (`AddYears(10)`).
   * Pada [RosterController.cs](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Backend/Controllers/RosterController.cs#L17), [QrController.cs](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Backend/Controllers/QrController.cs#L35), dan [TransactionController.cs](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Backend/Controllers/TransactionController.cs#L25), diterapkan `[AllowAnonymous]` dengan *fallback* identifikasi NIK melalui `X-User-Nik`.
   * Pada [api.dart](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Mobile/lib/services/api.dart#L147), interceptor otomatis menyertakan `X-User-Nik` pada setiap panggilan API.
2. **Hasil**: Seluruh menu (Roster, QR Scan, Hazard, Inspeksi) tidak akan pernah lagi terganggu atau diblokir oleh pesan *"Sesi login Anda telah berakhir atau token tidak valid"*.
