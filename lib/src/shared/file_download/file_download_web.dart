import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String> saveExcelFile({
  required String name,
  required Uint8List bytes,
}) async {
  final content = base64Encode(bytes);
  final anchor = web.HTMLAnchorElement()
    ..href =
        'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$content'
    ..download = '$name.xlsx'
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  return '$name.xlsx';
}
