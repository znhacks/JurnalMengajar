import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'excel_picker_models.dart';

Future<PickedExcelFile?> pickExcelFile() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    Uint8List? bytes = file.bytes;

    if (bytes == null && file.path != null) {
      final localFile = File(file.path!);
      if (await localFile.exists()) {
        bytes = await localFile.readAsBytes();
      }
    }

    if (bytes == null || bytes.isEmpty) {
      throw Exception('File Excel kosong atau tidak dapat dibaca.');
    }

    return PickedExcelFile(name: file.name, bytes: bytes);
  } catch (e) {
    throw Exception('Gagal memilih file: $e');
  }
}
