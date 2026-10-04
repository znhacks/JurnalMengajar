import 'excel_picker_models.dart';
import 'excel_picker_stub.dart'
    if (dart.library.html) 'excel_picker_web.dart'
    if (dart.library.io) 'excel_picker_io.dart' as picker;

export 'excel_picker_models.dart';

Future<PickedExcelFile?> pickExcelFilePlatform() {
  return picker.pickExcelFile();
}
