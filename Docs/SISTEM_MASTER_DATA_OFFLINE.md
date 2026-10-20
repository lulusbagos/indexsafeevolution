# 📦 Panduan Sistem Master Data Offline & Standar Reusable UI (Indexsafe Evolution)

Dokumen ini adalah **panduan standar arsitektur offline-first** untuk seluruh pengembang dan modul UI berikutnya di aplikasi **Indexsafe Evolution** (misalnya: *Inspeksi*, *Observasi K3/STOP/TAK*, *Pelaporan Insiden*, *Permit to Work*, *SAP*, dan *JSA*).

Gunakan arsitektur dan pola kode di dokumen ini agar setiap halaman baru yang membutuhkan data master (Karyawan/PJA, Lokasi Area, Benchmark, Departemen, Perusahaan) dapat langsung berfungsi secara **offline**, memiliki **pencarian instan (<5ms)**, dan memiliki fitur **bebas ketik (manual fallback)** sehingga pengguna di lapangan tidak pernah terblokir akibat ketiadaan sinyal internet.

---

## 🏗️ 1. Arsitektur "Offline-First with Seamless Fallback"

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ALUR PENGAMBILAN DATA                           │
└────────────────────────────────────────────────────────────────────────┘

 [User Mengetik / Membuka Form]
              │
              ▼
    (1) Query SQLite Lokal  ──[< 5 ms]──►  Tampilkan Hasil Instan di UI
              │
       (Ada Internet?)
        ├── YA  ──► (2) Query Background API ──► Perbarui Hasil (Non-blocking)
        └── TIDAK (Offline)
              │
              ▼
    (3) Data Tidak Ditemukan di SQLite?
              │
              ▼
    ┌──────────────────────────────────────────────────────────────┐
    │  Tile: "Gunakan: '[NAMA]' (Mode Offline / Bebas Ketik)"     │
    │  ATAU Submit Form langsung mengadopsi teks yang diketik      │
    └──────────────────────────────────────────────────────────────┘
```

Prinsip Utama:
1. **Zero-Waiting UI**: Jangan pernah membuat pengguna menunggu loader online saat mengisi form di lapangan.
2. **Never Block Submissions**: Jika master data belum sempat disinkronkan atau karyawan baru belum terdaftar, izinkan input manual secara bebas.
3. **High-Speed Batch Ingestion**: Mengunduh dan menyimpan puluhan ribu data master menggunakan *Chunked Batch Insert* di SQLite.

---

## 🗄️ 2. Skema Tabel SQLite Lokal (`Mobile/lib/services/database.dart`)

Database lokal SQLite diinisialisasi melalui class `DatabaseHelper`. Berikut tabel-tabel master utama yang sudah siap pakai:

### A. Tabel Karyawan / PJA (`employees`)
Tersimpan di tabel `employees` dengan indeks komposit untuk pencarian cepat NIK dan Nama:

```sql
CREATE TABLE employees (
  nik TEXT PRIMARY KEY,
  no_nik TEXT,
  nama_lengkap TEXT,
  depart TEXT,
  departemen TEXT,
  posisi TEXT,
  jabatan TEXT,
  perusahaan TEXT,
  foto TEXT,
  created_at TEXT,
  updated_at TEXT
);

CREATE INDEX idx_emp_nik ON employees (no_nik);
CREATE INDEX idx_emp_nama ON employees (nama_lengkap);
```

### B. Tabel Area & Benchmark (`tbl_m_benchmark`)
Menyimpan area utama tambang beserta nama titik benchmark-nya:

```sql
CREATE TABLE tbl_m_benchmark (
  id INTEGER PRIMARY KEY,
  area_utama TEXT,
  nama_benchmark TEXT,
  perusahaan_id INTEGER
);

CREATE INDEX idx_bm_area ON tbl_m_benchmark (area_utama);
```

### C. Tabel Master Generik (`masters`)
Tabel serbaguna untuk menampung master berbentuk *key-value* atau list sederhana (perusahaan, departemen, jenis bahaya, dll.):

```sql
CREATE TABLE masters (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT,
  data TEXT, -- JSON Payload
  synced_at TEXT
);
```

---

## 🔄 3. Mekanisme Sinkronisasi Master Data (Menu Profil)

Pengguna dapat mengunduh seluruh data master terbaru melalui menu:
**Profil ➔ Sinkronisasi Master Data (`SyncPage`)**.

### File Kunci:
1. `Mobile/lib/pages/sync_page.dart`
2. `Mobile/lib/services/sync.dart` (`SyncService`)
3. `Mobile/lib/services/api.dart` (`ApiService.getMaster`)

### Optimasi Performa (Chunked Batch Insert):
Untuk mencegah memory leak (*OOM*) dan *App Not Responding* (ANR) saat mengunduh 10.000+ data karyawan:
```dart
// Pola Batching di SyncService:
final batch = db.batch();
for (var i = 0; i < items.length; i++) {
  batch.insert(
    'employees',
    normalizedMap,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  // Commit setiap 400 row agar memori tetap ringan & cepat
  if ((i + 1) % 400 == 0) {
    await batch.commit(noResult: true);
  }
}
await batch.commit(noResult: true);
```

### Dukungan API JSON Array / List:
`ApiService.getMaster(name)` di `Mobile/lib/services/api.dart` secara otomatis mendeteksi apakah respon backend berupa `Map` (`{ data: [...] }`) atau `List` langsung (`[...]`), sehingga endpoint baru tidak akan menyebabkan *type cast error*.

---

## 💻 4. Pola Implementasi Siap Pakai di UI Berikutnya

### Pola 1: Pencarian Karyawan / PJA (Offline + Bebas Ketik)

Salin pola ini ke halaman baru (misal `inspeksi_form_page.dart` atau `incident_report_page.dart`):

```dart
// 1. Variabel State
final TextEditingController _karyawanSearchCtrl = TextEditingController();
Map<String, dynamic>? _selectedKaryawan;
List<Map<String, dynamic>> _karyawanResults = [];
bool _isSearching = false;

// 2. Logika Pencarian Cepat (Lokal SQLite Instan + Background Online)
Future<void> _searchKaryawan(String query) async {
  final cleanQ = query.trim();
  if (cleanQ.length < 2) {
    setState(() => _karyawanResults = []);
    return;
  }

  // A. Ambil langsung dari SQLite Lokal (< 5ms)
  final localResults = await _searchKaryawanLocal(cleanQ);
  if (mounted) {
    setState(() {
      _karyawanResults = localResults;
    });
  }

  // B. Refresh dari server jika sedang online (tanpa memblokir UI)
  try {
    final res = await ApiService.searchPja(cleanQ);
    if (res.statusCode == 200 && res.data != null) {
      final List remoteList = res.data is List ? res.data : (res.data['data'] ?? []);
      final List<Map<String, dynamic>> onlineResults = remoteList.map((e) => {
        'nik': e['no_nik'] ?? e['nik'] ?? '',
        'nama': e['nama_lengkap'] ?? e['nama'] ?? '',
        'departemen': e['departemen'] ?? e['depart'] ?? '',
        'perusahaan': e['perusahaan'] ?? '',
      }).toList();

      if (mounted && onlineResults.isNotEmpty) {
        setState(() => _karyawanResults = onlineResults);
      }
    }
  } catch (_) {
    // Mode offline: Abaikan error jaringan
  }
}

// 3. Query SQLite Lokal
Future<List<Map<String, dynamic>>> _searchKaryawanLocal(String query) async {
  try {
    final db = await DatabaseHelper.instance.database;
    final res = await db.rawQuery('''
      SELECT 
        COALESCE(no_nik, nik) as nik,
        nama_lengkap as nama,
        COALESCE(departemen, depart) as departemen,
        COALESCE(jabatan, posisi) as jabatan,
        perusahaan
      FROM employees
      WHERE no_nik LIKE ? OR nama_lengkap LIKE ?
      LIMIT 15
    ''', ['%$query%', '%$query%']);
    return res;
  } catch (e) {
    return [];
  }
}
```

### Widget UI Dropdown PJA / Karyawan (dengan Manual Tile):
```dart
// Tampilkan tile bebas ketik tepat di atas hasil pencarian:
if (_karyawanSearchCtrl.text.trim().isNotEmpty && _selectedKaryawan == null) ...[
  Container(
    margin: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      children: [
        // TILE MANUAL / BEBAS KETIK (OFFLINE HERO)
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
          ),
          title: Text(
            'Gunakan: "${_karyawanSearchCtrl.text.trim()}"',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
          ),
          subtitle: const Text(
            'Gunakan nama ini (Mode Offline / Bebas Ketik)',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          trailing: const Icon(Icons.check_circle, color: Color(0xFF2563EB), size: 20),
          onTap: () {
            setState(() {
              _selectedKaryawan = {
                'nik': 'MANUAL',
                'nama': _karyawanSearchCtrl.text.trim(),
                'departemen': 'LAPANGAN',
                'perusahaan': 'INTERNAL',
              };
              _karyawanResults.clear();
            });
          },
        ),

        // DAFTAR HASIL DARI DATABASE LOKAL
        ..._karyawanResults.map((emp) => ListTile(
          title: Text(emp['nama'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text('${emp['nik']} • ${emp['departemen'] ?? '-'}', style: const TextStyle(fontSize: 11)),
          onTap: () {
            setState(() {
              _selectedKaryawan = emp;
              _karyawanResults.clear();
            });
          },
        )),
      ],
    ),
  ),
]
```

### Validasi Form (Fallback Otomatis saat Submit):
```dart
// Saat tombol Simpan / Submit ditekan:
if (_selectedKaryawan == null) {
  final typedName = _karyawanSearchCtrl.text.trim();
  if (typedName.isNotEmpty) {
    // Otomatis adopsi teks yang diketik tanpa perlu memblokir user
    _selectedKaryawan = {
      'nik': 'MANUAL',
      'nama': typedName,
      'departemen': 'LAPANGAN',
      'perusahaan': 'INTERNAL',
    };
  } else {
    // Validasi gagal hanya jika input benar-benar kosong
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Harap masukkan nama penanggung jawab / karyawan!')),
    );
    return;
  }
}
```

---

### Pola 2: Dropdown Area & Cascading Benchmark (Lokal SQLite)

Untuk UI yang membutuhkan pilihan Lokasi Tambang (Area Utama dan Benchmark):

```dart
// 1. Ambil Semua Area Utama yang Unik
Future<List<String>> getAreaListLocal() async {
  final db = await DatabaseHelper.instance.database;
  final res = await db.rawQuery('''
    SELECT DISTINCT area_utama 
    FROM tbl_m_benchmark 
    WHERE area_utama IS NOT NULL AND area_utama != ''
    ORDER BY area_utama ASC
  ''');
  return res.map((r) => r['area_utama'].toString()).toList();
}

// 2. Ambil Benchmark Berdasarkan Area yang Dipilih
Future<List<String>> getBenchmarksByAreaLocal(String selectedArea) async {
  final db = await DatabaseHelper.instance.database;
  final res = await db.rawQuery('''
    SELECT nama_benchmark 
    FROM tbl_m_benchmark 
    WHERE area_utama = ? AND nama_benchmark IS NOT NULL
    ORDER BY nama_benchmark ASC
  ''', [selectedArea]);
  return res.map((r) => r['nama_benchmark'].toString()).toList();
}
```

---

## 📋 5. Checklist Verifikasi Saat Membuat UI Baru

Saat Anda atau developer lain membuat halaman baru:

- [ ] **Data Master dari SQLite**: Apakah dropdown atau autocomplete membaca dari `DatabaseHelper.instance.database` terlebih dahulu?
- [ ] **Non-blocking Online Refresh**: Apakah pemanggilan API dibungkus `try/catch` dan tidak menampilkan full-screen loading blocker?
- [ ] **Bebas Ketik Manual**: Apakah ada tile `"Gunakan: '[NAMA]' (Manual)"` jika data belum ada di database?
- [ ] **Form Submit Fallback**: Jika user lupa memilih dari dropdown namun sudah mengetik nama, apakah form otomatis mengadopsi teks yang diketik?
- [ ] **Sinkronisasi Terdaftar**: Jika modul baru membutuhkan master data tambahan dari backend, apakah sudah didaftarkan ke `_masters` di `Mobile/lib/pages/sync_page.dart`?

---
*Dibuat untuk arsitektur terintegrasi **Indexsafe Evolution Mobile**.*
