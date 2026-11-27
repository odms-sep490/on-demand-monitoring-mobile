import 'package:material_ui/material_ui.dart';

import '../../shared/mobile_ui.dart';
import '../../shared/strings.dart';

class MissionFilters extends StatelessWidget {
  const MissionFilters({
    super.key,
    required this.dates,
    required this.selectedDate,
    required this.tab,
    required this.counts,
    required this.onDateChanged,
    required this.onTabChanged,
    required this.onQueryChanged,
  });

  final List<DateTime> dates;
  final DateTime? selectedDate;
  final int tab;
  final ({int pending, int upcoming, int history}) counts;
  final ValueChanged<DateTime?> onDateChanged;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (dates.isNotEmpty)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: Text(context.tr('All days', 'Tất cả ngày')),
                selected: selectedDate == null,
                onSelected: (_) => onDateChanged(null),
              ),
              for (final date in dates)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(
                      MaterialLocalizations.of(context).formatShortDate(date),
                    ),
                    selected: DateUtils.isSameDay(selectedDate, date),
                    onSelected: (_) => onDateChanged(date),
                  ),
                ),
            ],
          ),
        ),
      SectionCard(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            for (final (index, label, count) in [
              (0, context.tr('Awaiting reply', 'Chờ phản hồi'), counts.pending),
              (1, context.tr('Upcoming', 'Sắp tới'), counts.upcoming),
              (2, context.tr('History', 'Lịch sử'), counts.history),
            ])
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onTabChanged(index),
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      vertical: 11,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tab == index
                          ? odmsBlue.withValues(alpha: .08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tab == index ? odmsBlue : odmsMuted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$count',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: tab == index ? odmsBlue : odmsMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: context.tr('Search missions', 'Tìm nhiệm vụ'),
        ),
        onChanged: onQueryChanged,
      ),
    ],
  );
}
