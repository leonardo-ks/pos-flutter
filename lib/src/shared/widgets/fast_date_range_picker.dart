import 'package:flutter/material.dart';

Future<DateTimeRange?> showFastDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
}) {
  final today = _dateOnly(DateTime.now());
  return showDialog<DateTimeRange>(
    context: context,
    builder: (dialogContext) => _FastDateRangePickerDialog(
      firstDate: _dateOnly(firstDate),
      lastDate: _dateOnly(lastDate),
      initialRange: initialDateRange ?? DateTimeRange(start: today, end: today),
    ),
  );
}

class _FastDateRangePickerDialog extends StatefulWidget {
  const _FastDateRangePickerDialog({
    required this.firstDate,
    required this.lastDate,
    required this.initialRange,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange initialRange;

  @override
  State<_FastDateRangePickerDialog> createState() =>
      _FastDateRangePickerDialogState();
}

class _FastDateRangePickerDialogState
    extends State<_FastDateRangePickerDialog> {
  late DateTime _visibleMonth = DateTime(
    widget.initialRange.start.year,
    widget.initialRange.start.month,
  );
  late DateTime _start = _dateOnly(widget.initialRange.start);
  late DateTime _end = _dateOnly(widget.initialRange.end);
  bool _selectingEnd = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Pilih Tanggal'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_dateLabel(_start)} - ${_dateLabel(_end)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Bulan Sebelumnya',
                  onPressed: _canGoPrevious ? () => _moveMonth(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _monthLabel(_visibleMonth),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Bulan Berikutnya',
                  onPressed: _canGoNext ? () => _moveMonth(1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final day in ['S', 'S', 'R', 'K', 'J', 'S', 'M'])
                  Expanded(child: Center(child: Text(day))),
              ],
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                final date = _gridDate(index);
                final inMonth = date.month == _visibleMonth.month;
                final enabled =
                    !date.isBefore(widget.firstDate) &&
                    !date.isAfter(widget.lastDate);
                final selectedStart = date == _start;
                final selectedEnd = date == _end;
                final inRange = !date.isBefore(_start) && !date.isAfter(_end);
                final selected = selectedStart || selectedEnd;
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: enabled ? () => _selectDate(date) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.primary
                          : inRange
                          ? colors.primaryContainer
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: selected
                          ? Border.all(color: colors.primary)
                          : inRange
                          ? Border.all(color: colors.primaryContainer)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${date.day}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected
                            ? colors.onPrimary
                            : inRange
                            ? colors.onPrimaryContainer
                            : inMonth && enabled
                            ? colors.onSurface
                            : colors.onSurfaceVariant.withValues(alpha: 0.42),
                        fontWeight: selected || inRange
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(DateTimeRange(start: _start, end: _end)),
          child: const Text('Terapkan'),
        ),
      ],
    );
  }

  bool get _canGoPrevious {
    final previous = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    return !DateTime(
      previous.year,
      previous.month + 1,
      0,
    ).isBefore(widget.firstDate);
  }

  bool get _canGoNext {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    return !next.isAfter(widget.lastDate);
  }

  DateTime _gridDate(int index) {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
    final offset = firstOfMonth.weekday % 7;
    return firstOfMonth
        .subtract(Duration(days: offset))
        .add(Duration(days: index));
  }

  void _moveMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      if (!_selectingEnd || date.isBefore(_start)) {
        _start = date;
        _end = date;
        _selectingEnd = true;
      } else {
        _end = date;
        _selectingEnd = false;
      }
    });
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _dateLabel(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _monthLabel(DateTime date) {
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return '${months[date.month - 1]} ${date.year}';
}
