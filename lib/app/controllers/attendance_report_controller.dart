import 'dart:io';

import 'package:dio/dio.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/attendance_api_client.dart';
import '../data/models/attendance_report_model.dart';

class AttendanceReportController extends GetxController {
  final startDate = Rx<DateTime?>(null);
  final endDate = Rx<DateTime?>(null);
  final isLoading = false.obs;
  final reports = <AttendanceReportModel>[].obs;

  // Computed unique dates for columns
  List<String> get uniqueDates {
    final dates = <String>{};
    for (var report in reports) {
      for (var record in report.dailyRecords) {
        dates.add(record.date);
      }
    }
    final sortedDates = dates.toList()..sort();
    return sortedDates;
  }

  void setStartDate(DateTime date) {
    startDate.value = date;
  }

  void setEndDate(DateTime date) {
    endDate.value = date;
  }

  Future<void> fetchReport() async {
    if (startDate.value == null || endDate.value == null) {
      Get.snackbar(
        'Validation Error',
        'Please select both start and end dates',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    if (startDate.value!.isAfter(endDate.value!)) {
      Get.snackbar(
        'Validation Error',
        'Start date cannot be after end date',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isLoading.value = true;
      final startStr = startDate.value!.toIso8601String().split('T').first;
      final endStr = endDate.value!.toIso8601String().split('T').first;

      final dio = Get.find<AttendanceApiClient>().dio;
      final response = await dio.get(
        '/api/v1/attendance/reports/weekly',
        queryParameters: {
          'branch_id': AppConstants.branchId,
          'start': startStr,
          'end': endStr,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        reports.value =
            data.map((json) => AttendanceReportModel.fromJson(json)).toList();

        if (reports.isEmpty) {
          Get.snackbar(
            'Report',
            'No attendance records found for the selected dates.',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    } on DioException catch (e) {
      Get.snackbar(
        'Error',
        e.response?.data?['detail'] ?? e.message ?? 'Failed to fetch report',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'An unexpected error occurred',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> exportToExcel() async {
    if (reports.isEmpty) {
      Get.snackbar(
        'Export Error',
        'No data available to export. Please fetch a report first.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Attendance Report'];
      excel.setDefaultSheet('Attendance Report');

      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final dates = uniqueDates;

      // Headers
      List<CellValue> headers = [
        TextCellValue('Employee Name'),
        ...dates.map((d) => TextCellValue(d)),
        TextCellValue('Total Hours'),
      ];
      sheetObject.appendRow(headers);

      // Rows
      for (var report in reports) {
        List<CellValue> row = [
          TextCellValue(report.employeeName),
        ];

        // Create a map for quick lookup
        final recordMap = {for (var r in report.dailyRecords) r.date: r.hours};

        for (var date in dates) {
          final hours = recordMap[date] ?? 0;
          row.add(DoubleCellValue(hours.toDouble()));
        }

        row.add(DoubleCellValue(report.total.hours.toDouble()));
        sheetObject.appendRow(row);
      }

      var fileBytes = excel.save();

      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${directory.path}/attendance_report_$timestamp.xlsx';

        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        Get.back(); // Close loading dialog

        // Share the file
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Attendance Report',
        );
      } else {
        Get.back();
        Get.snackbar('Error', 'Failed to generate Excel file');
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'Error',
        'Failed to export to Excel: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }
}
