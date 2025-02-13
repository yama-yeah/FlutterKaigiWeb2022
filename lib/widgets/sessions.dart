import 'dart:convert';

import 'package:confwebsite2022/entity/timetable_entity.dart';
import 'package:confwebsite2022/responsive_layout_builder.dart';
import 'package:confwebsite2022/theme.dart';
import 'package:confwebsite2022/widgets/divider_with_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const timeslotColor = Color(0x66F25D50);
const talkColor = Color(0x666200EE);
const sponsorColor = Color(0xffFFF275);

final sessionList = FutureProvider((_) async {
  var response = await http
      .get(Uri.parse('https://fortee.jp/flutterkaigi-2022/api/timetable'));
  if (response.statusCode == 200) {
    var responseBody = utf8.decode(response.bodyBytes);
    final parsed = TimetableEntity.fromJson(jsonDecode(responseBody)).timetable;
    return Future.value(parsed.where((e) => e.track.name == 'Live').toList());
  }
  return Future.value(const TimetableEntity().timetable);
});

final _selectedDayIndex = StateProvider((_) => 0);

class SessionList extends ConsumerWidget {
  const SessionList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionList);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: sessions.when(
        data: (list) => _SessionList(sessions: list),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

class _SessionList extends ConsumerWidget {
  final List<Timetable> sessions;

  const _SessionList({
    Key? key,
    required this.sessions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = AppLocalizations.of(context)!;
    final division = <int, List<Timetable>>{};
    final selectedDay = ref.watch(_selectedDayIndex);
    for (final session in sessions) {
      final date = session.startsAt;
      if (date == null) continue;
      if (division[date.day] == null) {
        division[date.day] = <Timetable>[];
      }
      division[date.day]!.add(session);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DividerWithTitle(text: appLocalizations.schedule),
        const Gap(24),
        ResponsiveLayoutBuilder(builder: (context, layout, _) {
          switch (layout) {
            case ResponsiveLayout.slim:
              return _DaySelectorSlim(
                current: selectedDay,
                max: division.length,
              );
            case ResponsiveLayout.wide:
            case ResponsiveLayout.ultrawide:
              return _DaySelectorWide(
                current: selectedDay,
                max: division.length,
              );
          }
        }),
        const Gap(24),
        for (final session in division.values.elementAt(selectedDay)) ...[
          session.type.when(
            timeslot: () => _Timeslot(item: session),
            talk: () => _Talk(item: session),
          ),
          const Gap(16),
        ],
      ],
    );
  }
}

class _DaySelectorWide extends ConsumerWidget {
  final int current;
  final int max;

  const _DaySelectorWide({
    required this.current,
    required this.max,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        for (var i = 0; i < max; i++) ...[
          Expanded(
            child: Material(
              color: current == i ? kBlue : Colors.white,
              child: InkWell(
                onTap: () => ref.read(_selectedDayIndex.notifier).state = i,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: kBlue, width: 2),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Day ${i + 1}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: current == i ? Colors.white : kBlue,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Gap(8),
        ],
      ],
    );
  }
}

class _DaySelectorSlim extends ConsumerWidget {
  final int current;
  final int max;

  const _DaySelectorSlim({
    required this.current,
    required this.max,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++) ...[
          Material(
            color: current == i ? kBlue : Colors.white,
            child: InkWell(
              onTap: () => ref.read(_selectedDayIndex.notifier).state = i,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: kBlue, width: 2),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Day ${i + 1}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: current == i ? Colors.white : kBlue,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Gap(8),
        ],
      ],
    );
  }
}

final timeFormatter = DateFormat.Hm('ja');

String createSessionTimeRange(Timetable item) {
  final startTime = item.startsAt?.toLocal();
  if (startTime == null) return '';
  final finishTime = startTime.add(Duration(minutes: item.lengthMin));
  return '${timeFormatter.format(startTime)} - ${timeFormatter.format(finishTime)}';
}

class _Timeslot extends StatelessWidget {
  final Timetable item;

  const _Timeslot({
    Key? key,
    required this.item,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sessionTimeRange = createSessionTimeRange(item);

    return Container(
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: timeslotColor, width: 2),
        ),
      ),
      width: double.infinity,
      child: Column(
        children: <Widget>[
          const Gap(20),
          Text(
            item.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Gap(40),
          Text(
            sessionTimeRange,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Gap(20),
        ],
      ),
    );
  }
}

class _Talk extends StatelessWidget {
  final Timetable item;

  const _Talk({
    Key? key,
    required this.item,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sessionTimeRange = createSessionTimeRange(item);
    final speakerName = Text(
      item.speaker.name,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    );

    return Material(
      color: item.isSponsored ? sponsorColor.withOpacity(0.4) : null,
      child: InkWell(
        onTap: () => launch(item.url, webOnlyWindowName: '_blank'),
        child: Container(
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(
                color: item.isSponsored ? sponsorColor : talkColor,
                width: 2,
              ),
            ),
          ),
          width: double.infinity,
          child: Column(
            children: <Widget>[
              const Gap(20),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(4),
              if (item.speaker.twitter.isNotEmpty)
                Tooltip(
                  message: 'Twitter: @${item.speaker.twitter}',
                  child: GestureDetector(
                    onTap: () => launch(
                      'https://twitter.com/${item.speaker.twitter}',
                      webOnlyWindowName: '_blank',
                    ),
                    child: speakerName,
                  ),
                )
              else
                speakerName,
              const Gap(40),
              Text(
                sessionTimeRange,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(20),
            ],
          ),
        ),
      ),
    );
  }
}
