import '../../shared/workspace_hero.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/mobile_ui.dart';
import '../../shared/portal_scaffold.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../auth/session.dart';

class StaffMissionsPage extends ConsumerStatefulWidget {
  const StaffMissionsPage({super.key});
  @override
  ConsumerState<StaffMissionsPage> createState() => _StaffMissionsPageState();
}

class _StaffMissionsPageState extends ConsumerState<StaffMissionsPage> {
  int tab = 0;
  DateTime? selectedDate;
  String query = '';
  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider), user = ref.watch(sessionProvider).user!;
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('My missions', 'Nhiệm vụ của tôi')),
      ),
      body: RemoteView(
        load: () async {
          final missions = records(await api.request('/api/missions/mine'));
          final enriched = await Future.wait(
            missions.map((mission) async {
              try {
                return {
                  ...mission,
                  '_permissions': await api.request(
                    '/api/missions/${segment('${mission['id']}')}/permissions',
                  ),
                };
              } catch (_) {
                return {...mission, '_permissions': <String, dynamic>{}};
              }
            }),
          );
          Object? licenses, licenseError;
          try {
            licenses = await api.request(
              '/api/staff-licenses/users/${segment(user.id)}',
            );
          } catch (error) {
            licenseError = error;
          }
          return {
            'missions': enriched,
            'licenses': licenses,
            'licenseError': licenseError,
          };
        },
        builder: (context, value, reload) {
          final data = object(value),
              missions = records(object(value)['missions']);
          final now = DateTime.now();
          bool terminal(Json mission) =>
              ['COMPLETED', 'FAILED', 'CANCELLED'].contains(mission['status']);
          bool pending(Json mission) =>
              !terminal(mission) &&
              object(mission['_permissions'])['canRespond'] == true;
          final pendingItems = missions.where(pending).toList(),
              history = missions.where(terminal).toList(),
              upcoming = missions
                  .where((e) => !terminal(e) && !pending(e))
                  .toList();
          final dates =
              missions
                  .map(
                    (item) => DateTime.tryParse('${item['scheduledStartAt']}'),
                  )
                  .whereType<DateTime>()
                  .map((time) => DateUtils.dateOnly(time.toLocal()))
                  .toSet()
                  .toList()
                ..sort();
          final filtered = [pendingItems, upcoming, history][tab]
              .where(
                (item) =>
                    selectedDate == null ||
                    DateUtils.isSameDay(
                      DateTime.tryParse('${item['scheduledStartAt']}')
                          ?.toLocal(),
                      selectedDate,
                    ),
              )
              .where(
                (item) =>
                    '${recordTitle(item)} ${item['orderCode']} ${item['address']}'
                        .toLowerCase()
                        .contains(query.toLowerCase()),
              )
              .toList();
          final today = missions.where((e) {
            final time = DateTime.tryParse('${e['scheduledStartAt']}');
            return time != null && DateUtils.isSameDay(time.toLocal(), now);
          }).length;
          final week = missions.where((e) {
            final time = DateTime.tryParse('${e['scheduledStartAt']}');
            return !terminal(e) &&
                time != null &&
                time.isAfter(now) &&
                time.isBefore(now.add(const Duration(days: 7)));
          }).length;
          final validLicenses = records(data['licenses'])
              .where(
                (e) =>
                    e['licenseStatus'] == 'ACTIVE' &&
                    e['verificationStatus'] == 'VERIFIED' &&
                    (e['expiryDate'] == null ||
                        !DateTime.parse('${e['expiryDate']}')
                            .isBefore(DateUtils.dateOnly(now))),
              )
              .length;
          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                WorkspaceHero(
                  title: context.tr(
                    'Your assigned missions',
                    'Nhiệm vụ được giao',
                  ),
                  eyebrow: user.fullName,
                  description: MaterialLocalizations.of(context)
                      .formatFullDate(now),
                  action: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => context.go('/staff/availability'),
                          icon: const Icon(
                            Icons.calendar_month_outlined,
                            size: 17,
                          ),
                          label: Text(context.tr('Availability', 'Lịch bận')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/staff/maintenance'),
                          icon: const Icon(Icons.build_outlined, size: 17),
                          label: Text(context.tr('Maintenance', 'Bảo trì')),
                        ),
                      ),
                    ],
                  ),
                ),
                if (dates.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text(context.tr('All days', 'Tất cả ngày')),
                          selected: selectedDate == null,
                          onSelected: (_) =>
                              setState(() => selectedDate = null),
                        ),
                        for (final date in dates)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              label: Text(
                                MaterialLocalizations.of(context)
                                    .formatShortDate(date),
                              ),
                              selected: DateUtils.isSameDay(selectedDate, date),
                              onSelected: (_) =>
                                  setState(() => selectedDate = date),
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
                        (
                          0,
                          context.tr('Awaiting reply', 'Chờ phản hồi'),
                          pendingItems.length,
                        ),
                        (1, context.tr('Upcoming', 'Sắp tới'), upcoming.length),
                        (2, context.tr('History', 'Lịch sử'), history.length),
                      ])
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => tab = index),
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
                                      color: tab == index
                                          ? odmsBlue
                                          : odmsMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '$count',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: tab == index
                                          ? odmsBlue
                                          : odmsMuted,
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
                  onChanged: (value) => setState(() => query = value),
                ),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  SectionCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.assignment_outlined,
                            size: 40,
                            color: odmsMuted,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            context.tr(
                              'No missions in this group.',
                              'Chưa có nhiệm vụ trong mục này.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final mission in filtered)
                  _ScheduledMissionRow(
                    start: DateTime.tryParse('${mission['scheduledStartAt']}')
                        ?.toLocal(),
                    item: mission,
                    onTap: () async {
                      await context.push(
                        '/staff/missions/${segment('${mission['id']}')}',
                      );
                      reload();
                    },
                  ),
                StatGrid(
                  children: [
                    StatTile(
                      label: context.tr('Awaiting reply', 'Chờ phản hồi'),
                      value: '${pendingItems.length}',
                      icon: Icons.mark_email_unread_outlined,
                      color: const Color(0xFFF59E0B),
                    ),
                    StatTile(
                      label: context.tr('Today', 'Hôm nay'),
                      value: '$today',
                      icon: Icons.today_outlined,
                    ),
                    StatTile(
                      label: context.tr(
                        'Upcoming this week',
                        'Sắp tới trong tuần',
                      ),
                      value: '$week',
                      icon: Icons.date_range_outlined,
                    ),
                    StatTile(
                      label: context.tr(
                        'Valid qualifications',
                        'Chứng chỉ còn hiệu lực',
                      ),
                      value: data['licenseError'] == null
                          ? '$validLicenses'
                          : '—',
                      icon: Icons.verified_outlined,
                      color: const Color(0xFF16A34A),
                      note: data['licenseError'] == null
                          ? null
                          : context.tr(
                              'Could not load qualifications',
                              'Chưa tải được chứng chỉ',
                            ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScheduledMissionRow extends StatelessWidget {
  const _ScheduledMissionRow({
    required this.start,
    required this.item,
    required this.onTap,
  });
  final DateTime? start;
  final Json item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = this.start;
    if (start == null) return DomainCard(item: item, onTap: onTap);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(start));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              time,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
        Expanded(
          child: DomainCard(item: item, onTap: onTap),
        ),
      ],
    );
  }
}
