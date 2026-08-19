import 'dart:html' as html;

void downloadImage(String url) {
  html.AnchorElement anchorElement = html.AnchorElement(href: url);
  anchorElement.download = "qr-code.png";
  anchorElement.click();
}
