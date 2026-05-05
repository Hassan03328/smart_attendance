import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Service to generate PDF reports
class PdfService {

  // Generate lecture report as PDF
  static Future<void> generateLectureReport({
    required String lectureName,
    required List<Map<String, dynamic>> data,
  }) async {

    // Create new PDF document
    final pdf = pw.Document();

    // Add page to PDF
    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              // Title of report
              pw.Text(
                'Lecture Report: $lectureName',
                style: pw.TextStyle(fontSize: 20),
              ),

              pw.SizedBox(height: 20),

              // Create table from data
              pw.Table.fromTextArray(

                // Table headers
                headers: ['Name', 'Email', 'Status', 'Percentage'],

                // Convert each student data into table row
                data: data.map((e) {
                  return [
                    e['student_name'] ?? '', // student name
                    e['student_email'] ?? '', // student email
                    e['status'] ?? '', // attendance status
                    '${(e['attendance_percentage'] ?? 0).toStringAsFixed(1)}%', // percentage
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    // Open print / save PDF screen
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }
}