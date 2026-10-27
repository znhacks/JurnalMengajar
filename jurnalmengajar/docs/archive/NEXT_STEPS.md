# 🎯 NEXT STEPS - Untuk Menjalankan Aplikasi

Aplikasi **sudah siap** untuk diintegrasikan dengan Supabase. Ikuti langkah-langkah di bawah untuk menjalankannya.

---

## ⏱️ Estimasi Waktu: 30 Menit

---

## STEP 1: Setup Supabase Project (10 menit)

### 1. Buat Project Baru
1. Buka https://supabase.com
2. Login atau daftar akun
3. Click "New Project"
4. Fill form:
   - Organization: (Pilih atau buat baru)
   - Project name: `jurnalmengajar`
   - Database password: (Simpan password ini!)
   - Region: (Pilih region terdekat, misal Singapore)
5. Click "Create new project" (tunggu ~2 menit)

### 2. Dapatkan Credentials
1. Setelah project selesai, buka **Settings** → **API**
2. Copy:
   - **Project URL**: `https://xxxx.supabase.co`
   - **Anon/Public key**: `eyJhbGc...` (panjang)

Simpan credentials ini untuk step selanjutnya!

---

## STEP 2: Setup Database (15 menit)

### 1. Buka SQL Editor
1. Di dashboard Supabase, click **SQL Editor**
2. Click **New Query**

### 2. Copy & Run SQL Scripts
1. Buka file: `SUPABASE_SETUP.md` di project
2. Copy SEMUA SQL script
3. Paste di SQL Editor Supabase
4. Click **Run** (ikon play biru)
5. Tunggu hingga selesai (biasanya 5-10 detik)

**Jika berhasil**: Anda akan lihat 8 tabel di sidebar kiri Supabase

### 3. Verifikasi Tabel
```
users ✅
periods ✅
subjects ✅
lesson_hours ✅
classes ✅
schedules ✅
journals ✅
settings ✅
```

---

## STEP 3: Setup Storage Bucket (2 menit)

### 1. Buka Storage
1. Di dashboard Supabase, click **Storage**
2. Click **Create new bucket**

### 2. Buat Bucket
- Bucket name: `journal-attachments`
- Make it public: ✅ (Check this)
- Click **Create bucket**

**Verifikasi**: Anda harus melihat bucket `journal-attachments` di list

---

## STEP 4: Update Credentials di Flutter (2 menit)

### 1. Edit `lib/main.dart`
1. Buka file: `lib/main.dart`
2. Cari bagian ini:
   ```dart
   await Supabase.initialize(
     url: 'YOUR_SUPABASE_URL',
     anonKey: 'YOUR_SUPABASE_ANON_KEY',
   );
   ```

3. Ganti dengan credentials dari Step 1:
   ```dart
   await Supabase.initialize(
     url: 'https://xxxxxxxxxxxx.supabase.co',
     anonKey: 'eyJhbGciOiJIUzI1NiIsInR5...',
   );
   ```

4. **SAVE FILE** (Ctrl+S)

---

## STEP 5: Jalankan Aplikasi (1 menit)

### Terminal Commands
```bash
# Go to project directory
cd c:\Jordi\JurnalMengajar\jurnalmengajar

# Get dependencies
flutter pub get

# Run app
flutter run
```

Atau gunakan VSCode:
1. Buka project di VSCode
2. Click **Run** → **Start Debugging** (F5)

---

## STEP 6: Test Aplikasi

### Login Test
1. **Register akun baru**
   - Email: `test@example.com`
   - Password: `Test123!`
   - Lengkapi data diri
   - Click Register

2. **Atau login dengan test account**
   - Email: `sri@jurnal.com` (Guru)
   - Atau: `admin@jurnal.com` (Admin)
   - Password: (check SUPABASE_SETUP.md)

3. **Jika berhasil**: Anda akan melihat Dashboard

### Test Features
- [ ] View schedules
- [ ] Create journal entry
- [ ] Upload attachment
- [ ] View journal list
- [ ] Logout

---

## 📋 Setup Checklist

- [ ] Create Supabase project
- [ ] Copy URL dan Anon Key
- [ ] Run SQL scripts
- [ ] Create storage bucket
- [ ] Update credentials di `lib/main.dart`
- [ ] Run `flutter pub get`
- [ ] Run `flutter run`
- [ ] Test login/register
- [ ] Test create journal
- [ ] Test upload file

---

## ❌ Troubleshooting

### Error: "Connection refused"
```
❌ Problem: Supabase URL salah atau internet mati
✅ Solution: 
   - Check internet connection
   - Verify URL di main.dart is correct
   - Copy-paste lagi dari Supabase dashboard
```

### Error: "Anonymous access denied"
```
❌ Problem: RLS policy blokir akses
✅ Solution:
   - Di Supabase, go to Auth → Policies
   - Disable RLS untuk development (temporary)
   - Atau setup proper RLS policies
```

### Error: "Undefined table"
```
❌ Problem: SQL scripts tidak selesai atau gagal
✅ Solution:
   - Check di Supabase SQL Editor, error apa?
   - Run SQL scripts lagi
   - Verifikasi 8 tabel exist
```

### Error: "File upload failed"
```
❌ Problem: Bucket tidak ada atau permission salah
✅ Solution:
   - Check bucket "journal-attachments" exist
   - Check bucket marked as "public"
   - Check file size < 50MB
```

### Project tidak compile
```
❌ Problem: Dependency belum terinstall
✅ Solution:
   - Run: flutter pub get
   - Run: flutter clean
   - Run: flutter pub get lagi
```

---

## 🎯 Setelah Setup Selesai

### Option A: Lanjut Development
```bash
flutter run
# Then make changes and hot-reload (Ctrl+S)
```

### Option B: Build APK (Android)
```bash
flutter build apk
# APK ada di: build/app/outputs/flutter-apk/app-release.apk
```

### Option C: Build iOS
```bash
flutter build ios
# Buka di Xcode untuk test atau deploy
```

---

## 📚 Dokumentasi Referensi

Jika ada pertanyaan atau butuh info lebih detail, baca file ini:

1. **GET_STARTED.md** - Penjelasan lengkap
2. **SUPABASE_SETUP.md** - Database schema & SQL
3. **QUICKSTART.md** - Quick reference
4. **IMPLEMENTATION_SUMMARY.md** - Technical details
5. **COMPLETION_CHECKLIST.md** - Full requirements

---

## 🔗 Useful Links

- Supabase Dashboard: https://supabase.com/dashboard
- Supabase Docs: https://supabase.com/docs
- Flutter Docs: https://flutter.dev/docs
- Dart Docs: https://dart.dev/guides

---

## ✅ Jika Berhasil

Anda akan melihat:
1. ✅ Login screen berfungsi
2. ✅ Dashboard tampil dengan data
3. ✅ Bisa create journal
4. ✅ Bisa upload file
5. ✅ Data tersimpan di Supabase

---

## 🎉 Selamat!

Aplikasi Jurnal Mengajar sudah terhubung dengan Supabase dan siap untuk digunakan!

Jika ada masalah, cek **Troubleshooting** section di atas atau baca dokumentasi detail di files lain.

---

**Status**: Ready to Setup
**Time Required**: ~30 menit
**Difficulty**: Easy ⭐⭐☆☆☆

Good luck! 🚀
