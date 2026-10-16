import 'dart:html' as html;
import 'dart:typed_data';

void downloadImage(String url) {
  html.AnchorElement anchorElement = html.AnchorElement(href: url);
  anchorElement.download = "qr-code.png";
  anchorElement.click();
}

void downloadFileFromBytes(Uint8List bytes, String filename, {String mimeType = 'application/octet-stream'}) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..target = 'blank'
    ..download = filename;
  anchor.click();
  html.Url.revokeObjectUrl(url);
}
