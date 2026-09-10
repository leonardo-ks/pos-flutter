import 'package:flutter/material.dart' show DateTimeRange;

import '../../reports/repositories/report_repository.dart' show ReportRange;

/// One report panel's range + filter selection. The app has two: the main
/// sales/purchase report and the returns report. Pre-split these were ~20
/// duplicated `selectedReport*` / `selectedReturnReport*` fields.
class ReportFilterState {
  ReportRange range = ReportRange.today;
  DateTimeRange? customRange;
  int? productId;
  int? categoryId;
  int? customerId;
  int? supplierId;
  String type = 'all';

  void reset() {
    range = ReportRange.today;
    customRange = null;
    productId = null;
    categoryId = null;
    customerId = null;
    supplierId = null;
    type = 'all';
  }
}
