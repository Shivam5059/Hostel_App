import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class FileSaver {
  static Future<void> saveAndShareCsv(String fileName, String csvData) async {
    if (kIsWeb) {
      // We'll handle web separately via JS/html if needed, 
      // but for now let's see if we can use a simpler approach.
      // Actually, standard web download:
      return; 
    }

    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/$fileName.csv';
      final file = File(path);
      await file.writeAsString(csvData);

      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Export $fileName',
        text: 'CSV report for $fileName',
      );
    } catch (e) {
      print('Error saving/sharing file: $e');
    }
  }
}
