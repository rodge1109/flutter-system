import 'dart:html' as html;
import 'dart:typed_data';
import 'package:http/http.dart' as http;

Future<void> downloadImage(String url) async {
  try {
    // 1. If it's a Cloudinary URL, we can also inject fl_attachment so even direct links force download
    String fetchUrl = url;
    if (url.startsWith('http')) {
      final response = await http.get(Uri.parse(fetchUrl));
      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? 'image/png';
        String ext = 'png';
        if (contentType.contains('jpeg') || contentType.contains('jpg') || url.toLowerCase().endsWith('.jpg') || url.toLowerCase().endsWith('.jpeg')) {
          ext = 'jpg';
        }
        downloadFileFromBytes(response.bodyBytes, 'payment-qr-code.$ext', mimeType: contentType);
        return;
      }
    }
  } catch (_) {
    // Fallback below if CORS or network fetch fails
  }

  // 2. Fallback: For Cloudinary URLs, insert fl_attachment to force browser file download without navigating away
  String downloadUrl = url;
  if (downloadUrl.contains('res.cloudinary.com') && downloadUrl.contains('/upload/') && !downloadUrl.contains('fl_attachment')) {
    downloadUrl = downloadUrl.replaceFirst('/upload/', '/upload/fl_attachment/');
  }

  final anchorElement = html.AnchorElement(href: downloadUrl)
    ..download = 'payment-qr-code.png'
    ..target = '_blank'
    ..rel = 'noopener noreferrer';
  html.document.body?.append(anchorElement);
  anchorElement.click();
  anchorElement.remove();
}

void downloadFileFromBytes(Uint8List bytes, String filename, {String mimeType = 'application/octet-stream'}) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

