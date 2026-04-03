import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> generateLectureReport({
    required String lectureName,
    required List<Map<String, dynamic>> data,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Lecture Report: $lectureName',
                style: pw.TextStyle(fontSize: 20),
              ),
              pw.SizedBox(height: 20),

              pw.Table.fromTextArray(
                headers: ['Name', 'Email', 'Status', 'Percentage'],
                data: data.map((e) {
                  return [
                    e['student_name'] ?? '',
                    e['student_email'] ?? '',
                    e['status'] ?? '',
                    '${(e['attendance_percentage'] ?? 0).toStringAsFixed(1)}%',
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }
}