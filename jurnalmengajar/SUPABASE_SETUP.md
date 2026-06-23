# Supabase Integration Guide

## Konfigurasi Supabase

### 1. Setup Credentials

Edit `lib/main.dart` dan ganti placeholder credentials:

```dart
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);
```

Dapatkan credentials dari:
- Dashboard Supabase → Project Settings → API
- Copy URL dan anon key ke nilai di atas

### 2. Database Schema

Pastikan membuat tabel-tabel berikut di Supabase:

#### users
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email VARCHAR UNIQUE NOT NULL,
  full_name VARCHAR NOT NULL,
  role VARCHAR NOT NULL,
  phone_number VARCHAR,
  position VARCHAR,
  address TEXT,
  photo_url TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

#### periods
```sql
CREATE TABLE periods (
  id UUID PRIMARY KEY,
  name VARCHAR NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);
```

#### subjects
```sql
CREATE TABLE subjects (
  id UUID PRIMARY KEY,
  name VARCHAR NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);
```

#### lesson_hours
```sql
CREATE TABLE lesson_hours (
  id UUID PRIMARY KEY,
  teaching_hour INTEGER NOT NULL UNIQUE,
  start_time VARCHAR NOT NULL,
  end_time VARCHAR NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);
```

#### classes
```sql
CREATE TABLE classes (
  id UUID PRIMARY KEY,
  period_id UUID NOT NULL REFERENCES periods(id),
  name VARCHAR NOT NULL,
  student_count INTEGER NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);
```

#### schedules
```sql
CREATE TABLE schedules (
  id UUID PRIMARY KEY,
  period_id UUID NOT NULL REFERENCES periods(id),
  date DATE NOT NULL,
  teaching_hour INTEGER NOT NULL,
  class_id UUID NOT NULL REFERENCES classes(id),
  subject_id UUID NOT NULL REFERENCES subjects(id),
  teacher_id UUID NOT NULL REFERENCES users(id),
  note TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);
```

#### journals
```sql
CREATE TABLE journals (
  id UUID PRIMARY KEY,
  schedule_id UUID NOT NULL REFERENCES schedules(id),
  date DATE NOT NULL,
  teaching_hour INTEGER NOT NULL,
  class_id UUID NOT NULL REFERENCES classes(id),
  subject_id UUID NOT NULL REFERENCES subjects(id),
  teacher_id UUID NOT NULL REFERENCES users(id),
  material TEXT NOT NULL,
  sick_count INTEGER DEFAULT 0,
  permission_count INTEGER DEFAULT 0,
  alpha_count INTEGER DEFAULT 0,
  note TEXT,
  status VARCHAR DEFAULT 'pending',
  attachment_url TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

#### settings
```sql
CREATE TABLE settings (
  id VARCHAR PRIMARY KEY,
  max_journal_input_days INTEGER DEFAULT 3,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### 3. Storage Setup

Buat bucket di Supabase Storage:
- Nama: `journal-attachments`
- Akses publik untuk read, private untuk write

### 4. Authentication

Supabase Auth sudah terintegrasi untuk:
- Sign up
- Sign in
- Password reset
- Logout

User yang register otomatis dibuat di tabel `users`.

### 5. Relasi Database

Pastikan foreign keys sudah setup dengan benar:
- `users` → `schedules.teacher_id`
- `periods` → `classes.period_id`
- `classes` → `schedules.class_id`
- `subjects` → `schedules.subject_id`
- `lesson_hours` (teaching_hour) → `schedules.teaching_hour`
- `schedules` → `journals.schedule_id`

### 6. RLS (Row Level Security)

Jika menggunakan RLS, pastikan policy sudah setup untuk:
- Users hanya bisa baca/update profil mereka sendiri
- Guru hanya bisa lihat schedules dan journals mereka
- Admin bisa lihat semua data

## Repository Usage

### Auth Repository
```dart
// Login
await authRepo.login(email, password);

// Register
await authRepo.register(userModel, password);

// Reset Password
await authRepo.resetPassword(email);

// Logout
await authRepo.logout();

// Get Current User
final user = await authRepo.getCurrentUser();
```

### Schedule Repository
```dart
// Get schedules for teacher
final schedules = await scheduleRepo.getSchedulesForTeacher(teacherId, date);
```

### Journal Repository with File Upload
```dart
// Upload attachment
final url = await journalRepo.uploadAttachment(file, journalId);

// Update attachment URL
await journalRepo.updateAttachmentUrl(journalId, url);

// Verify/Approve journal
await journalRepo.verifyJournal(journalId, 'approved');
```

## Testing

Gunakan Mock Data Supabase atau manual testing dengan:
1. Buat test account di Supabase
2. Login dan test CRUD operations
3. Test file upload untuk attachments
4. Verify approval workflow

## Troubleshooting

- **Error: Anonymous access denied**: Setup RLS policies di Supabase
- **Error: File upload failed**: Pastikan bucket `journal-attachments` exist dan policy allow upload
- **Error: Connection failed**: Check internet dan Supabase URL/Key
