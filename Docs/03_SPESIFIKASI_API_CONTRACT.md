# 03 - Spesifikasi Kontrak REST API (Mobile ke Backend)

Dokumen ini mendefinisikan seluruh kontrak REST API yang digunakan oleh aplikasi mobile Flutter ([`api.dart`](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Mobile/lib/services/api.dart) & [`sync.dart`](file:///d:/4.%20PROJECT/13.%20Mobile/Indexsafe%20Evolution/Mobile/lib/services/sync.dart)).

---

## 1. Konvensi Header & Protokol

Seluruh permintaan HTTP dari mobile menyertakan header default:
```http
Accept: application/json
Connection: Keep-Alive
company: IC
```
Untuk endpoint yang membutuhkan autentikasi:
```http
Authorization: Bearer <token_jwt_atau_sanctum>
```

Format respon standar untuk penanganan error (sesuai parser `errorHandler` di `api.dart`):
```json
{
  "message": "Pesan kesalahan deskriptif",
  "detail": "Keterangan teknis opsional",
  "errors": {
    "password": ["Password minimal 8 karakter"]
  }
}
```

---

## 2. Autentikasi & Profil Karyawan

### 2.1 Login
- **URL**: `POST /api/login`
- **Body** (JSON):
  ```json
  {
    "email": "IC12345678",
    "password": "password_user"
  }
  ```
  *(Catatan: Mobile secara otomatis menggabungkan prefix `company` dengan input user, contoh: `IC` + NIK).*
- **Response Sukses (200 OK)**:
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "name": "Budi Santoso",
      "email": "IC12345678",
      "created_at": "2026-01-01 08:00:00"
    }
  }
  ```

### 2.2 Register
- **URL**: `POST /api/register`
- **Body** (JSON):
  ```json
  {
    "name": "Budi Santoso",
    "email": "budi@indexim.co.id",
    "password": "SecretPassword123",
    "password_confirmation": "SecretPassword123"
  }
  ```

### 2.3 Logout
- **URL**: `POST /api/logout`
- **Header**: `Authorization: Bearer <token>`
- **Response**: `{ "message": "Successfully logged out" }`

### 2.4 Get Profile
- **URL**: `GET /api/profile`
- **Response Sukses (200 OK)**:
  ```json
  {
    "id": 105,
    "no_nik": "12345678",
    "nama_lengkap": "Budi Santoso",
    "nama_alias": "Budi",
    "company": "IC",
    "company_id": 1,
    "user_id": 1,
    "depart": "HSE",
    "section": "Safety Pit",
    "posisi": "Safety Officer",
    "foto": "https://apiis.idcapps.net/storage/avatars/budi.jpg"
  }
  ```

### 2.5 Update Foto Profil
- **URL**: `POST /api/profile`
- **Content-Type**: `multipart/form-data`
- **Form Data**:
  - `foto`: [Binary File Image]

### 2.6 Ubah Password
- **URL**: `POST /api/change-password`
- **Body** (JSON):
  ```json
  {
    "old_password": "old_password",
    "new_password": "new_password",
    "new_password_confirmation": "new_password"
  }
  ```

---

## 3. Master Data Sync (`GET /api/master/{name}`)

Digunakan oleh `SyncPage` saat sinkronisasi data master.

- **URL**: `GET /api/master/{name}?limit=10000`
- **Parameter `{name}`**:
  - `enum` (Data enum_masters)
  - `bridges` (Data enum_bridges)
  - `inspection` (Master kriteria inspeksi)
  - `hazard` (Master tipe & kategori bahaya)
  - `coaching` (Master coaching)
  - `k3` (Master K3)
  - `observation` (Master observasi)
  - `p2h` (Master checklist P2H alat)
  - `p5m` (Master topik P5M)
  - `safety` (Master safety talk)
  - `employee` (Daftar seluruh karyawan untuk tagging & offline login)
  - `vehicle` (Daftar armada & alat berat)
- **Response Sukses (200 OK)**:
  ```json
  {
    "data": [
      {
        "id": 1,
        "code": "AR01",
        "name": "Pit West",
        "type": "area",
        "created_at": "2026-01-01 00:00:00"
      }
    ]
  }
  ```

---

## 4. Sinkronisasi Transaksi Offline

### 4.1 Upload Transaksi Header
- **URL**: `POST /api/tran/{name}`
  - `{name}` dapat bernilai: `inspection`, `hazard`, `coaching`, `k3`, `observation`, `p2h`, `p5m`, `safety`.
- **Content-Type**: `multipart/form-data`
- **Form Data**: Seluruh field baris lokal dari tabel `${name}_trans` (misal `code`, `area_id`, `location_id`, `date`, `time`, `remark`, dll).
- **File Uploads (Multipart)**:
  - `image` (Foto kondisi awal)
  - `repair_image` (Foto bukti perbaikan langsung, jika ada)
  - `action_image` (Foto tindak lanjut)
- **Response Wajib (200/201 OK)**:
  ```json
  {
    "status": true,
    "data": {
      "id": 8801,
      "code": "HZ-20260930-001"
    }
  }
  ```
  *(PENTING: Field `data.id` dari respon ini akan disimpan mobile sebagai `sync_id` dan disematkan ke detail item sebagai `ref_id`).*

### 4.2 Upload Item Detail Checklist
- **URL**: `POST /api/detail/{name}`
- **Content-Type**: `multipart/form-data`
- **Form Data**:
  - `ref_id`: `8801` (ID header di server yang didapat dari langkah 4.1)
  - Seluruh field item detail (`name`, `point_id`, `yesno`, `remark`, `status`)
  - File multipart: `image`, `repair_image`, `action_image`
- **Response Wajib**:
  ```json
  {
    "status": true,
    "data": {
      "id": 9502
    }
  }
  ```

### 4.3 Upload & Update Action Plan
- **URL**: `POST /api/action/{name}`
- **Content-Type**: `multipart/form-data`
- **Form Data**: Field `action_plans` (`plan`, `plan_date`, `action`, `action_date`, `pic_id`, dll).
- **Response**:
  ```json
  {
    "status": true,
    "data": {
      "id": 501,
      "updated_at": "2026-09-30 20:00:00"
    }
  }
  ```

### 4.4 Upload File Attachment Tambahan
- **URL**: `POST /api/files`
- **Content-Type**: `multipart/form-data`
- **Form Data**:
  - `name`: [Binary File Image/Video]
  - `tran_id`: `8801`
  - `detail_id`: `9502`
  - `type`, `table`, `category`
- **Response**:
  ```json
  {
    "status": true,
    "data": {
      "id": 1201
    }
  }
  ```
