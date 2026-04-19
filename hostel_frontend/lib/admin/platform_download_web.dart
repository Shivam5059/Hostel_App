import 'dart:html' as html;
import 'dart:convert';

void downloadFile(String fileName, String content) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", "$fileName.csv")
    ..click();
  html.Url.revokeObjectUrl(url);
}
