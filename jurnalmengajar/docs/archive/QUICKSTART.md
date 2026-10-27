# Jurnal Mengajar - Supabase Integration

Aplikasi Flutter untuk pencatatan jurnal mengajar di sekolah dengan backend Supabase.

## 🚀 Quick Start

### 1. Prerequisites
- Flutter 3.11.5+
- Dart 3.11.5+
- Supabase Account (free tier available)

### 2. Supabase Setup

#### Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Sign in or create account
3. Create new project
4. Get your credentials:
   - Project URL
   - Anon Key (Public)

#### Database Setup
1. Open SQL Editor in Supabase
2. Copy SQL from `SUPABASE_SETUP.md`
3. Run all SQL scripts to create tables

#### Storage Setup
1. Go to Storage
2. Create bucket named: `journal-attachments`
3. Set to public (for read access)

### 3. Flutter Setup

```bash
# Clone or navigate to project
cd jurnalmengajar

# Get dependencies
flutter pub get

# Add your Supabase credentials to lib/main.dart
# Find these lines and replace YOUR_SUPABASE_URL and YOUR_SUPABASE_ANON_KEY:
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);

# Run the app
flutter run
```

## 📱 Default Credentials

Gunakan data dari `SUPABASE_SETUP.md` untuk test:

- Email: `budi@jurnal.com` (Guru Matematika)
- Email: `sri@jurnal.com` (Guru Bahasa Inggris)
- Email: `admin@jurnal.com` (Admin)

## 🏗️ Architecture

### Repository Pattern
```
Models → Repositories (Abstract) → Supabase Repositories → Supabase Backend
```

### Provider Pattern
```
UI Widgets → Providers (ChangeNotifier) → Repositories
```

### Data Flow
1. **UI** → Calls Provider methods
2. **Provider** → Manages loading/error state, calls Repository
3. **Repository** → Handles business logic, calls Supabase
4. **Supabase** → Database/Storage operations

## 📁 Project Structure

```
lib/
├── core/
│   ├── constants/
│   │   └── supabase_constants.dart    # Table & field names
│   ├── router/
│   │   └── app_router.dart            # Navigation
│   ├── theme/
│   │   └── app_theme.dart             # UI Theme
│   └── utils/
├── models/
│   ├── user_model.dart
│   ├── schedule_model.dart
│   ├── journal_model.dart
│   ├── period_model.dart
│   ├── subject_model.dart
│   ├── hour_model.dart
│   ├── class_model.dart
│   ├── teacher_model.dart
│   ├── settings_model.dart
│   └── journal_attachment_model.dart
├── repositories/
│   ├── auth_repository.dart           # Abstract
│   ├── supabase_auth_repository.dart
│   ├── schedule_repository.dart       # Abstract
│   ├── supabase_schedule_repository.dart
│   ├── journal_repository.dart        # Abstract
│   ├── supabase_journal_repository.dart
│   ├── period_repository.dart         # Abstract
│   ├── supabase_period_repository.dart
│   ├── subject_repository.dart        # Abstract
│   ├── supabase_subject_repository.dart
│   ├── hour_repository.dart           # Abstract
│   ├── supabase_hour_repository.dart
│   ├── class_repository.dart          # Abstract
│   ├── supabase_class_repository.dart
│   ├── teacher_repository.dart        # Abstract
│   ├── supabase_teacher_repository.dart
│   ├── settings_repository.dart       # Abstract
│   └── supabase_settings_repository.dart
├── providers/
│   ├── auth_provider.dart
│   ├── master_data_provider.dart
│   ├── schedule_provider.dart
│   ├── journal_provider.dart
│   └── settings_provider.dart
├── screens/
│   ├── admin/
│   ├── teacher/
│   ├── auth/
│   └── ...
├── widgets/
└── main.dart
```

## 🔑 Key Features

### ✅ Authentication
- Login/Register with email & password
- Password reset
- Current user detection
- Profile update

### ✅ Master Data Management
- Periods (Tahun Ajaran)
- Subjects (Mata Pelajaran)
- Lesson Hours (Jam Pelajaran)
- Classes (Kelas)

### ✅ Schedule Management
- View teacher schedules
- Create/Update/Delete schedules
- Filter by date and teacher

### ✅ Journal Management
- Create journal entries
- Upload file attachments
- Update journal content
- Approve/Reject journal
- Status tracking (pending/approved/rejected)

### ✅ Error Handling
- Loading states
- Error messages
- Graceful error recovery
- Network error handling

## 🧪 Testing

### Manual Testing
1. Login dengan test account
2. Navigate ke Schedule
3. Create new journal
4. Upload attachment
5. Submit journal
6. Approve sebagai admin

### Testing File Upload
1. Pilih file dari device
2. Upload akan ditampilkan di storage
3. URL akan tersimpan di database

## 🔒 Security

### Recommended Security Setup

1. **Environment Variables**
   - Store Supabase URL dan Key di env
   - Use `flutter_dotenv` package

2. **RLS (Row Level Security)**
   - Enable RLS di Supabase
   - Set policies untuk row-level access control

3. **API Keys**
   - Use separate anon key untuk public access
   - Use service role key hanya untuk backend

4. **CORS**
   - Configure CORS di Supabase

## 📊 Database Schema

### Main Tables
- **users** - User accounts (Auth + Profile)
- **periods** - Tahun ajaran (e.g., 2025/2026 Ganjil)
- **subjects** - Mata pelajaran (e.g., Matematika, Bahasa Inggris)
- **lesson_hours** - Jam pelajaran (e.g., Jam 1: 07:00-07:45)
- **classes** - Kelas (e.g., Kelas X-A)
- **schedules** - Jadwal mengajar (relasi: teacher + class + subject + hour + date)
- **journals** - Jurnal mengajar (relasi: schedule + attachments)
- **settings** - App settings

### Storage
- **journal-attachments** - File uploads untuk lampiran jurnal

## 🐛 Troubleshooting

### Error: "Anonymous access denied"
- Setup RLS policies di Supabase
- Ensure anon key has correct permissions

### Error: "File upload failed"
- Check bucket exists (`journal-attachments`)
- Check bucket policies allow upload
- Check file size limits

### Error: "Connection timeout"
- Check internet connection
- Verify Supabase URL adalah correct
- Check firewall rules

### Error: "User not found"
- Ensure user dibuat saat register
- Check users table di Supabase

## 📚 Documentation

- `SUPABASE_SETUP.md` - Complete Supabase setup guide
- `IMPLEMENTATION_SUMMARY.md` - What was implemented
- This README - Quick start guide

## 🤝 Contributing

For bugs or features, create issues in the repository.

## 📝 License

This project is part of school system.

---

**Last Updated**: June 2024
**Status**: Ready for Production (with proper Supabase credentials)
