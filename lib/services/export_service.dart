import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

class ExportService {
  static Future<File> exportCSV(List data) async {
    List<List<dynamic>> rows = [
      ['Tanggal', 'Total', 'Metode'],
    ];

    for (var d in data) {
      rows.add([d['created_at'], d['total'], d['payment_method']]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/laporan.csv');
    return file.writeAsString(csv);
  }
}
