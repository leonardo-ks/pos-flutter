import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> saveExcelFile({
  required String name,
  required Uint8List bytes,
}) async {
  final directory =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final path = '${directory.path}${Platform.pathSeparator}$name.xlsx';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return path;
}
