import 'dart:typed_data';
import 'package:printing/printing.dart';

void saveOrDownloadExcelFile(List<int> bytes, String fileName) {
  final uint8Bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  Printing.sharePdf(bytes: uint8Bytes, filename: fileName);
}
