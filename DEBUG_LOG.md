# 📋 IndexSafe Evolution - Live Debug & Error Tracking Log

> **Tanggal Mulai**: 2026-10-29  
> **Perangkat Uji**: Samsung Galaxy (Device ID: `RR8M601DR3Z`, Android 12, Package: `id.indexim.mbs`)  
> **Mode**: Live Debug Monitoring (ADB Logcat & Backend Logging Active)  
> **Endpoint Backend Aktif**: `https://api_mbs.indexim.id` & Local `http://127.0.0.1:7302`

---

## 🎯 Status Checklist Pengujian Menu

| No | Modul / Menu | Sub-Fitur / Action | Status Pengujian | Keterangan / Isu |
|:---:|:---|:---|:---:|:---|
| 1 | **SafeMap & Hazard Hunter** | Buka Peta Heatmap / Titik | ✅ Normal | Cache & marker tampil normal |
| 2 | **SafeMap & Hazard Hunter** | Pindah Target (`<` dan `>`) | ✅ Normal | Tombol panah responsif |
| 3 | **SafeMap & Hazard Hunter** | Navigasi Google Maps (`near_me`) | ✅ Normal | Buka turn-by-turn nav |
| 4 | **SafeMap & Hazard Hunter** | Amankan Temuan (Close Hazard) | 🟡 Diperbaiki | Tombol Fake di luar dihapus, dipindah ke dalam modal |
| 5 | **SafeMap & Hazard Hunter** | Lapor Fake Hazard (Audit K3) | 🟡 Diperbaiki | Tersedia di dalam dialog Amankan Temuan |
| 6 | **Hazard Report** | Create Hazard Baru + Foto | 🟡 Diperbaiki | 1 antrean offline tersimpan di perangkat |
| 7 | **Hazard Hub / List** | Sinkronisasi Data Hazard | 🔴 Gagal -> Diperbaiki | Error 401 akibat SSL Hostname Mismatch pada re-login |
| 8 | **Mine Permit QR Scanner** | Scan QR Code Mine Permit | 🔴 Gagal -> Diperbaiki | Error Sesi Berakhir (401) akibat kegagalan handshake SSL |
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
| 19 | **Offline Sync Center** | Pending Queue & Sync All | ⏳ Siap Diuji | |
| 20 | **Profil & Akun** | Ganti Foto, Cek Data Karyawan | ⏳ Siap Diuji | |

---

## 🐞 Log Temuan Error & Bug

| ID | Waktu | Modul / Menu | Aksi / Trigger | Error Message / HTTP Code | Penyebab & Rencana Perbaikan | Status |
|:---:|:---:|:---|:---|:---|:---|:---:|
| **ERR-01** | 08:42:03 | **Scan QR & Auth** | Scan Mine Permit / Acara | `HandshakeException: CERTIFICATE_VERIFY_FAILED: Hostname mismatch` & `HTTP 401 Sesi login telah berakhir` | Dart `HttpClient` memblokir sertifikat public `api_mbs.indexim.id` karena hostname mismatch saat silent auto re-login. **Solusi**: Tambahkan `HttpOverrides.global` di `main.dart` & `badCertificateCallback` di `loginDio`. | 🟢 Fixed |
| **ERR-02** | 08:45:28 | **Hazard Sync** | Auto-Sync Outbox Hazard | `[syncTran] Error syncing hazard:1 -> DioException [bad response]: status code 401` | Token kedaluwarsa dan gagal diperbarui otomatis karena silent re-login terblokir SSL mismatch. Sinkronisasi outbox terhenti. **Solusi**: Perbaiki handshake SSL dan flow silent login. | 🟢 Fixed |
| **REQ-01** | 08:45:48 | **SafeMap UI** | Tampilan Encounter Bar | Tombol `[ FAKE ]` terlalu mencolok di luar | User meminta tombol Fake di luar dihilangkan dan hanya ditempatkan di dalam pilihan modal "Amankan Temuan". **Solusi**: Hapus tombol Fake dari card bar luar, rapikan tata letak tombol utama. | 🟢 Fixed |

---

## 🛠️ Catatan Tindakan Perbaikan
1. **`Mobile/lib/main.dart`**: Menerapkan kelas `MyHttpOverrides` dengan bypass `badCertificateCallback` global agar seluruh koneksi ke `api_mbs.indexim.id` tidak terhenti akibat `CERTIFICATE_VERIFY_FAILED: Hostname mismatch`.
2. **`Mobile/lib/services/api.dart`**: Memperbaiki instance `loginDio` pada interceptor 401 dengan `IOHttpClientAdapter` dan `badCertificateCallback`, menghapus duplikasi kode penanganan 401, serta menambah timeout.
3. **`Mobile/lib/pages/dashboard_page.dart`**: Menghapus tombol `[ FAKE ]` dari luar card; aksi lapor Fake Hazard kini hanya dapat dipilih setelah menekan `[ AMANKAN TEMUAN ]` di dalam dialog konfirmasi.
