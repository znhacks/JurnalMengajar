import 'dart:typed_data';

class PickedExcelFile {
  final String name;
  final Uint8List bytes;

  PickedExcelFile({
    required this.name,
    required this.bytes,
  });
}
