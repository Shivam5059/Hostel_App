import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme.dart';
import 'platform_download.dart';

class CsvExportHelper {
  /// Converts a list of maps into a CSV string.
  static String convertToCsv(List<dynamic> data, List<String> columns, List<String> keys) {
    String csv = columns.join(',') + '\n';
    for (var item in data) {
      List<String> row = [];
      for (var key in keys) {
        String value = (item[key] ?? '').toString().replaceAll(',', ' '); // Remove commas to prevent breaking CSV
        row.add(value);
      }
      csv += row.join(',') + '\n';
    }
    return csv;
  }

  /// Shows a beautiful preview dialog with the generated CSV and a copy button.
  static void showExportDialog(BuildContext context, String title, String csvData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Export $title'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CSV data generated successfully.', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(csvData, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          
          // Copy to Clipboard
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvData));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV copied to clipboard!'), backgroundColor: Colors.green),
              );
            },
            icon: const Icon(Icons.copy_all, color: Colors.blue),
            tooltip: 'Copy to Clipboard',
          ),

          // Save/Share File
          ElevatedButton.icon(
            onPressed: () {
              downloadFile(title, csvData);
              if (context.mounted) Navigator.pop(ctx);
            },
            icon: Icon(kIsWeb ? Icons.download : Icons.share),
            label: Text(kIsWeb ? 'Download CSV' : 'Save/Share CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
