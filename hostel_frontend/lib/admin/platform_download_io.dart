import 'file_saver.dart';

void downloadFile(String fileName, String content) {
  FileSaver.saveAndShareCsv(fileName, content);
}
