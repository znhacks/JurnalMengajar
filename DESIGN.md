# DESIGN.md

Arah visual Jurnal Mengajar. Isi file ini diambil dari sistem desain yang sudah dipakai aplikasi, bukan dari gaya baru. Sumber utama: `jurnalmengajar/lib/core/theme/app_theme.dart`, `jurnalmengajar/lib/screens/auth/login_screen.dart`, `jurnalmengajar/lib/widgets/web_responsive_container.dart`, dan `jurnalmengajar/lib/widgets/animated_widgets.dart`.

## Identitas

- Produk: Jurnal Mengajar, aplikasi jurnal mengajar untuk guru dan admin sekolah di Indonesia.
- Karakter: rapi, tenang, akademik, dan dapat dipercaya.
- Kesan yang dituju: alat kerja sekolah yang serius tetapi tidak kaku. Bukan produk startup yang ramai, bukan pula panel developer yang gelap dan penuh efek.
- Yang dihindari: gradien ungu-biru, glow, blob, grid latar, glassmorphism, ikon sparkle, dan tiruan visual Linear, Vercel, Stripe, atau Notion.

Alasan: aplikasi dipakai berulang untuk mencatat data kelas. Ketenangan dan keterbacaan lebih penting daripada kesan teknologi.

## Palet

- Biru utama: `#2563EB` untuk aksi utama, status aktif, dan identitas.
- Biru aksen: `#3B82F6` untuk aksen sekunder, hover, dan indikator.
- Slate: `#0F172A` teks utama, `#475569` teks sekunder, `#64748B` teks pendukung, `#94A3B8` outline, `#E2E8F0` garis, `#F8FAFC` latar, `#FFFFFF` permukaan.
- Amber: `#D97706` untuk peringatan, bukan untuk aksi utama.
- Rose: `#E11D48` untuk error, hapus, dan bahaya.

Alasan: biru sudah menjadi identitas aplikasi dan memberi kontras kuat pada tombol utama. Amber dan rose dipakai sebagai warna semantik, bukan dekorasi. Palet aktif dibatasi pada biru, amber, dan rose, dengan slate sebagai netral.

## Tipografi

- Jenis huruf: Hanken Grotesk untuk seluruh UI, dimuat lewat `google_fonts`.
- Ukuran dan bobot:
  - Judul layar: 28, w800.
  - Judul bagian: 18, w800.
  - Subjudul: 16, w700.
  - Tombol utama: 15, w600.
  - Tombol sekunder: 14, w600.
  - Body: 14, w500.
  - Body sekunder: 13, w500.
  - Label kecil: 11, w700.

Alasan: Hanken Grotesk adalah grotesk humanis yang tetap jelas pada ukuran 11 sampai 14, dipakai aplikasi untuk data padat. Huruf ini juga tidak memakai kesan terminal atau monospace yang mudah terlihat generik.

## Bentuk dan Elevasi

- Radius kartu: 16.
- Radius tombol dan input: 12.
- Radius bottom sheet bagian atas: 24.
- Chip: `StadiumBorder`, hanya untuk status atau filter.
- Elevasi default: 0. Pemisah utama adalah garis 1px `#E2E8F0` dan perbedaan warna permukaan.
- Shadow hanya untuk lapisan yang benar-benar mengambang, misalnya frame web atau modal.

Alasan: variasi radius membentuk hierarki. Tidak semua elemen dibuat pill. Garis tipis lebih tenang daripada shadow pada layar data yang padat.

## Layout

- Mobile first. Target sentuh minimal 44px.
- Web dan desktop: konten dibatasi maksimal 900px lalu dipusatkan. Pada lebar 1024px ke atas, navigasi memakai sidebar permanen selebar 288px. Di bawah itu, navigasi tetap memakai drawer atau bottom navigation.
- Jarak memakai skala 8, 12, 16, dan 24, bukan satu padding seragam untuk semua bagian.
- Setiap layar punya satu fokus utama. Kartu statistik dan aksi sekunder tidak boleh bersaing dengan aksi utama.
- Data padat tetap diberi ruang napas. Tabel dan daftar boleh rapat, tetapi judul, filter, dan aksi harus terpisah jelas.

Alasan: aplikasi berjalan di ponsel guru dan browser desktop admin. Batas 900px menjaga komposisi tetap terbaca di layar lebar tanpa meregangkan formulir.

## Gerak

- Transisi halaman mengikuti `CupertinoPageTransitionsBuilder`.
- Umpan balik tekan memakai `ScaleTap` dengan skala 0.96 dan durasi 120ms.
- Konten masuk memakai `FadeSlideIn` 400ms hanya untuk elemen yang perlu diarahkan perhatiannya.
- Tidak ada parallax, animasi berulang, atau gerakan dekoratif.

Alasan: gerak dipakai untuk umpan balik dan orientasi, bukan untuk mengisi halaman. Aplikasi ini alat kerja, bukan portofolio.

## Motif Identitas

- Gelombang biru solid pada header autentikasi (`WaveClipper`) adalah satu-satunya gestur dekoratif besar.
- Bahasa visual lainnya: bidang putih, garis tipis, dan blok biru solid.
- Tidak menambah blob, grid, noise, atau glow baru.

Alasan: gelombang sudah menjadi penanda layar masuk dan cukup dipakai sekali. Mengulangnya di setiap layar akan mengubah identitas menjadi hiasan.

## Dial

ENERGY 2 / RHYTHM 2 / MOTION 2

Alasan: energi sedang karena aksi utama jelas tetapi tidak berteriak. Ritme cukup konsisten dengan beberapa variasi pada layar ringkasan dan autentikasi. Gerak terbatas pada transisi dan umpan balik.

## Batasan

- Bahasa UI: Indonesia, mengikuti layar yang sudah ada. Istilah teknis yang lazim (email, password, PDF, Excel) tetap ditulis apa adanya.
- Jangan mengarang statistik, testimoni, logo sekolah, atau foto orang. Gunakan placeholder yang diberi label.
- Setiap layar data harus punya keadaan kosong, memuat, dan error.
- Jangan mengubah token warna, radius, atau tipografi di `app_theme.dart` tanpa alasan yang dicatat.
- Jangan menambah halaman atau tautan navigasi yang belum benar-benar ada.
