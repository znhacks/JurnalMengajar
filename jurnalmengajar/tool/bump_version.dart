// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) async {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('❌ Error: pubspec.yaml tidak ditemukan di direktori saat ini.');
    exit(1);
  }

  String content = pubspecFile.readAsStringSync();
  final versionRegExp = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)', multiLine: true);
  final match = versionRegExp.firstMatch(content);

  if (match == null) {
    print('❌ Error: Format version di pubspec.yaml tidak ditemukan (harus X.Y.Z+B).');
    exit(1);
  }

  int major = int.parse(match.group(1)!);
  int minor = int.parse(match.group(2)!);
  int patch = int.parse(match.group(3)!);
  int build = int.parse(match.group(4)!);

  final oldVersion = '$major.$minor.$patch+$build';

  bool shouldBuild = !args.contains('--no-build');

  if (args.contains('--major')) {
    major += 1;
    minor = 0;
    patch = 0;
  } else if (args.contains('--minor')) {
    minor += 1;
    patch = 0;
  } else if (args.contains('--build-only')) {
    // hanya naikkan build number
  } else {
    // default: bump patch (+1)
    patch += 1;
  }

  build += 1; // Selalu naikkan build number

  final newVersion = '$major.$minor.$patch+$build';
  content = content.replaceFirst(match.group(0)!, 'version: $newVersion');
  pubspecFile.writeAsStringSync(content);

  print('🚀 [Auto Version Bumper]');
  print('✅ Versi berhasil dinaikkan dari: $oldVersion ➔ $newVersion');
  print('📄 pubspec.yaml diperbarui.\n');

  if (shouldBuild) {
    print('🔨 Memulai proses `flutter build apk --release`...\n');
    final process = await Process.start(
      'flutter',
      ['build', 'apk', '--release'],
      mode: ProcessStartMode.inheritStdio,
      runInShell: true,
    );
    final exitCode = await process.exitCode;
    if (exitCode == 0) {
      print('\n🎉 Build APK Release versi $newVersion sukses!');
    } else {
      print('\n❌ Build APK gagal dengan exit code $exitCode');
      exit(exitCode);
    }
  } else {
    print('ℹ️ Flag `--no-build` terdeteksi. Skip build APK.');
  }
}
