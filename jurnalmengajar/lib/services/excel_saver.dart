import 'excel_saver_stub.dart'
    if (dart.library.html) 'excel_saver_web.dart'
    if (dart.library.io) 'excel_saver_io.dart' as saver;

void downloadOrShareExcel(List<int> bytes, String fileName) {
  saver.saveOrDownloadExcelFile(bytes, fileName);
}
