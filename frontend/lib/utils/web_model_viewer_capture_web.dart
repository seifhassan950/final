import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

Future<Uint8List?> captureModelViewerPngImpl(String elementId) async {
  final element = html.document.querySelector('#$elementId');
  if (element == null) return null;
  final dataUrl = js_util.callMethod<String?>(element, 'toDataURL', const []);
  if (dataUrl == null || dataUrl.isEmpty) return null;
  final parts = dataUrl.split(',');
  if (parts.length < 2) return null;
  return base64Decode(parts[1]);
}
