// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'excel_picker_models.dart';

Future<PickedExcelFile?> pickExcelFile() async {
  final completer = Completer<PickedExcelFile?>();
  final uploadInput = html.FileUploadInputElement()
    ..accept = '.xlsx, .xls, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/vnd.ms-excel';

  uploadInput.onChange.listen((e) async {
    final files = uploadInput.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.first;
    final reader = html.FileReader();

    reader.onLoadEnd.listen((e) {
      final result = reader.result;
      if (result is Uint8List) {
        if (!completer.isCompleted) {
          completer.complete(PickedExcelFile(name: file.name, bytes: result));
        }
      } else if (result is List<int>) {
        if (!completer.isCompleted) {
          completer.complete(PickedExcelFile(name: file.name, bytes: Uint8List.fromList(result)));
        }
      } else {
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    reader.onError.listen((err) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Gagal membaca file: $err'));
      }
    });

    reader.readAsArrayBuffer(file);
  });

  uploadInput.click();
  return completer.future;
}
