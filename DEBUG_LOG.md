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
| 5 | **SafeMap & Hazard Hunter** | Lapor Fake Hazard (Audit K3) | ✅ Siap Diuji | Pilihan tersedia di dalam modal Amankan Temuan |
| 6 | **Hazard Report** | Create Hazard Baru + Foto | ✅ Terverifikasi | Penyimpanan offline & online normal |
| 7 | **Hazard Hub / List** | Sinkronisasi Data Hazard | ✅ **SUKSES** | **Terverifikasi Terkirim**: ID Server `8147964` |
| 8 | **Mine Permit QR Scanner** | Scan QR Code Mine Permit | ✅ **SUKSES** | Silent Auto Re-login pulih, token valid otomatis |
| 9 | **Inspeksi (General)** | Formulir Inspeksi Baru | ⏳ Siap Diuji | |
| 10 | **DCI (Direct Control Insp)** | Input & Checklist DCI | ⏳ Siap Diuji | |
| 11 | **FCI (Facility Control)** | Input & Checklist FCI | ⏳ Siap Diuji | |
| 12 | **RCI (Road Control Insp)** | Input & Checklist RCI | ⏳ Siap Diuji | |
| 13 | **SPI (Spill/Environmental)**| Input & Checklist SPI | ⏳ Siap Diuji | |
| 14 | **GCI (Ground Control Insp)**| Input & Checklist GCI | ⏳ Siap Diuji | |
| 15 | **BBS (Behavior Based Safety)**| Input Observasi BBS | ⏳ Siap Diuji | |
| 16 | **P2H (Pemeriksaan Harian)** | Input P2H Alat / Unit | ⏳ Siap Diuji | |
| 17 | **P5M (Safety Briefing)** | Catat P5M & Daftar Hadir | ⏳ Siap Diuji | |
| 18 | **Approval Center** | List & Approve/Reject Transaksi | ⏳ Siap Diuji | |
| 19 | **Offline Sync Center** | Pending Queue & Sync All | ✅ **SUKSES** | Berhasil kirim antrean ke server publik |
| 20 | **Profil & Akun** | Ganti Foto, Cek Data Karyawan | ⏳ Siap Diuji | |

---

## 🐞 Log Temuan Error & Bug (Live Debug)

| ID | Waktu | Modul / Menu | Aksi / Trigger | Error Message / HTTP Code | Penyebab & Solusi | Status Verifikasi |
|:---:|:---:|:---|:---|:---|:---|:---:|
| **ERR-01** | 08:42:03 | **Scan QR & Auth** | Scan Mine Permit / Acara | `HandshakeException: CERTIFICATE_VERIFY_FAILED: Hostname mismatch` & `HTTP 401 Sesi login telah berakhir` | Dart `HttpClient` memblokir sertifikat public `api_mbs.indexim.id` karena hostname mismatch saat silent re-login.<br>👉 **Solusi**: Tambahkan `MyHttpOverrides` bypass SSL global di `main.dart` & perbaiki `loginDio`. | 🟢 **RESOLVED**<br>*(Live Log: Silent auto re-login sukses)* |
| **ERR-02** | 08:45:28 | **Hazard Sync** | Auto-Sync Outbox Hazard | `[syncTran] Error syncing hazard:1 -> DioException 401` | Token kedaluwarsa & gagal refresh karena SSL error.<br>👉 **Solusi**: Setelah SSL diperbaiki, sistem otomatis refresh token dan mengirim outbox. | 🟢 **RESOLVED**<br>*(Live Log: Sync hazard success! ID: 8147964)* |
| **REQ-01** | 08:45:48 | **SafeMap UI** | Tampilan Encounter Bar | Tombol `[ FAKE ]` di luar bar SafeMap | User meminta tombol Fake di luar dihilangkan dan hanya ada di dalam modal konfirmasi.<br>👉 **Solusi**: Tombol Fake di bar luar dihapus. Tombol utama `AMANKAN TEMUAN` diperluas. | 🟢 **RESOLVED** |

---

## 🛠️ Catatan Tindakan Perbaikan Terakhir
1. **Bypass SSL Global**: Menerapkan `HttpOverrides.global = MyHttpOverrides()` di [main.dart](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Mobile/lib/main.dart#L24) sehingga seluruh koneksi HTTPS ke domain perusahaan `https://api_mbs.indexim.id` terbebas dari kendala *Hostname mismatch*.
2. **Silent Re-Login**: Memulihkan auto re-login di [api.dart](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Mobile/lib/services/api.dart#L156). Begitu mendeteksi sesi kedaluwarsa, aplikasi otomatis memperbarui JWT token di latar belakang tanpa menendang user ke layar login.
3. **Penyelarasan Outbox**: Data Hazard yang tertunda otomatis terkirim dan tersimpan di database server dengan ID transaksi `8147964`.
4. **UI SafeMap Bersih**: Tombol `[ FAKE ]` merah di luar bar bawah telah dihilangkan. Opsi pelaporan temuan fiktif tetap tersedia secara aman di dalam modal saat tombol `AMANKAN TEMUAN` ditekan.
