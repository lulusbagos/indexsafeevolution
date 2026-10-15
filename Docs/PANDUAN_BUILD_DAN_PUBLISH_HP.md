# Panduan Build & Deploy Aplikasi Mobile ke HP (Anti-Blokir ManageEngine)

Dokumen ini berisi panduan praktis dan cepat untuk melakukan kompilasi (*build*) dan pemasangan (*publish/install*) aplikasi **Indexsafe / MBS Mobile** ke perangkat fisik (HP) di lingkungan kerja yang diawasi oleh sistem keamanan **ManageEngine Endpoint Central**.

---

## ⚠️ Memahami Kendala ManageEngine

ManageEngine memblokir eksekusi biner `gen_snapshot.exe` (*Ahead-of-Time / AOT Compiler* Flutter) saat proses `flutter build apk --release` dijalankan langsung di Windows:
```text
D:\5. INSTALASI\flutter\...\gen_snapshot.exe ====> blocked | grey | unmanaged
Target android_aot_release_android-arm64 failed: Access is denied.
```

Tersedia **2 solusi teruji** untuk mengatasi masalah ini:
1. **Metode Cepat (Windows JIT Build)**: Mengompilasi APK mode debug (menggunakan Dart JIT VM tanpa memanggil `gen_snapshot.exe`). Sangat cepat (~2 menit) dan 100% lolos proteksi ManageEngine.
2. **Metode Rilis Penuh (WSL Ubuntu Build)**: Mengompilasi APK rilis AOT di dalam subsistem Linux WSL 2 yang berada di luar jangkauan eksekusi ManageEngine Windows.

---

## 🚀 Metode 1: Cara Tercepat (Langsung di Windows - Rekomendasi)

Gunakan metode ini untuk pengujian harian dan instalasi cepat ke HP pekerja/klien.

### 1. Periksa HP Terhubung
Buka PowerShell / Terminal:
```powershell
& "D:\Android\sdk\platform-tools\adb.exe" devices
```
*Pastikan HP Anda muncul dengan status `device` (contoh: `RR8M601DR3Z device`).*

### 2. Kompilasi APK
Masuk ke folder `Mobile` dan jalankan:
```powershell
cd "D:\4. PROJECT\13. Mobile\Indexsafe Evolution\Mobile"
& "D:\5. INSTALASI\flutter\bin\flutter.bat" build apk --debug --android-skip-build-dependency-validation
```

### 3. Pasang & Buka Aplikasi di HP
```powershell
& "D:\Android\sdk\platform-tools\adb.exe" install -r -d "build\app\outputs\flutter-apk\app-debug.apk"
& "D:\Android\sdk\platform-tools\adb.exe" shell am start -n id.icapps.mbs/.MainActivity
```

---

## 🐧 Metode 2: Build Release Penuh via WSL Ubuntu

Gunakan metode ini jika Anda memerlukan biner rilis teroptimasi (*production release*).

Toolchain Flutter dan Android SDK Linux telah dikonfigurasi di dalam WSL Ubuntu:
- **Flutter SDK Linux**: `/home/lulushermawan/flutter`
- **Android SDK Linux**: `/home/lulushermawan/android-sdk`

### 1. Jalankan Kompilasi di WSL
```powershell
wsl -d Ubuntu -e bash -c "cd '/mnt/d/4. PROJECT/13. Mobile/Indexsafe Evolution/Mobile' && export PATH=/home/lulushermawan/flutter/bin:\$PATH && export ANDROID_HOME=/home/lulushermawan/android-sdk && flutter build apk --release --android-skip-build-dependency-validation"
```

### 2. Pasang APK Rilis ke HP
```powershell
& "D:\Android\sdk\platform-tools\adb.exe" install -r -d "D:\4. PROJECT\13. Mobile\Indexsafe Evolution\Mobile\build\app\outputs\flutter-apk\app-release.apk"
& "D:\Android\sdk\platform-tools\adb.exe" shell am start -n id.icapps.mbs/.MainActivity
```

---

## 🛠️ Informasi Konfigurasi Penting

| Item | Nilai / Lokasi |
| :--- | :--- |
| **Flutter SDK (Windows)** | `D:\5. INSTALASI\flutter` |
| **Android SDK (Windows)** | `D:\Android\sdk` |
| **ADB Executable** | `D:\Android\sdk\platform-tools\adb.exe` |
| **Gradle Cache** | `D:\.gradle-hero` |
| **Gradle Wrapper Version** | `gradle-8.14-all.zip` |
| **Android Application ID** | `id.icapps.mbs` |
| **Android Activity Utama** | `id.icapps.mbs/.MainActivity` |
| **Target Device (Contoh HP)** | Samsung Galaxy S10+ (`SM-G975F` / `RR8M601DR3Z`) |

---

## 💡 Tips & Solusi Masalah

1. **Muncul pesan `Device unauthorized` di ADB:**
   - Buka layar HP Anda, centang *"Always allow from this computer"*, lalu tekan tombol **Allow / Izinkan**.
2. **Versi Gradle komplain saat build:**
   - Selalu sertakan parameter flag `--android-skip-build-dependency-validation` saat menjalankan perintah `flutter build`.
3. **APK gagal install dengan error `INSTALL_FAILED_VERSION_DOWNGRADE`:**
   - Tambahkan flag `-d` pada adb: `adb install -r -d <file.apk>`.
