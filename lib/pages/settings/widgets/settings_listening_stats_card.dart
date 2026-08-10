// Copyright (C) 2026 mathiiiiiis
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';

typedef _Stats = ({
  int totalMs,
  int plays,
  ({String title, String? artist, int plays})? topSong,
  ({String artist, int plays})? topArtist,
  List<({DateTime day, int totalMs})> days,
});

/// Listening stats for current week
class ListeningStatsCard extends StatefulWidget {
  const ListeningStatsCard({required this.db, super.key});

  final SonoDatabase db;

  @override
  State<ListeningStatsCard> createState() => _ListeningStatsCardState();
}

class _ListeningStatsCardState extends State<ListeningStatsCard> {
  late final Future<_Stats> _future = _load();

  static const _barHeight = 46.0;
  static const _barMinHeight = 4.0;

  static const _skeleton = (
    totalMs: 3600000,
    plays: 0,
    topSong: (title: ' ', artist: ' ', plays: 1),
    topArtist: (artist: ' ', plays: 1),
    days: <({DateTime day, int totalMs})>[],
  );

  /// Monday 00:00 of current local week
  DateTime get _weekStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  Future<_Stats> _load() async {
    final since = _weekStart;
    final db = widget.db;
    final summary = await db.getListeningSummary(since);
    return (
      totalMs: summary.totalMs,
      plays: summary.plays,
      topSong: await db.getTopSong(since),
      topArtist: await db.getTopArtist(since),
      days: await db.getDailyListening(since),
    );
  }

  String _duration(BuildContext context, int ms) {
    final l = AppLocalizations.of(context);
    final total = Duration(milliseconds: ms);
    final minutes = total.inMinutes.remainder(60);
    if (total.inHours == 0) return l.settingsProfileStatsMinutes('$minutes');
    return l.settingsProfileStatsHoursMinutes(
      '${total.inHours}',
      minutes.toString().padLeft(2, '0'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sono;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: c.bgContainer,
        borderRadius: BorderRadius.circular(SonoSizes.borderRadiusLg),
        border: Border.all(
          color: c.borderLight10,
          width: SonoSizes.borderWidth,
        ),
      ),
      child: FutureBuilder<_Stats>(
        future: _future,
        builder: (context, snapshot) {
          final stats = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              const SizedBox(height: 18),
              if (stats == null)
                Opacity(opacity: 0, child: _body(context, _skeleton))
              else if (stats.plays == 0 && stats.totalMs == 0)
                _empty(context)
              else
                _body(context, stats),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.settingsProfileStats,
          style: TextStyle(
            fontFamily: SonoFonts.heading,
            fontSize: 19,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l.settingsProfileStatsWindow,
          style: TextStyle(
            fontFamily: SonoFonts.primary,
            fontSize: 12.5,
            color: c.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        l.settingsProfileStatsEmpty,
        style: TextStyle(
          fontFamily: SonoFonts.primary,
          fontSize: 13,
          height: 1.5,
          color: c.textTertiary,
        ),
      ),
    );
  }

  Widget _body(BuildContext context, _Stats stats) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _duration(context, stats.totalMs),
          style: TextStyle(
            fontFamily: SonoFonts.heading,
            fontSize: 38,
            height: 1.1,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _stat(
                context,
                label: l.settingsProfileStatsPlays,
                value: '${stats.plays}',
              ),
            ),
            Expanded(
              child: _stat(
                context,
                label: l.settingsProfileStatsTopArtist,
                value: stats.topArtist?.artist ?? l.settingsProfileStatsNone,
                muted: stats.topArtist == null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _stat(
          context,
          label: l.settingsProfileStatsTopSong,
          value: stats.topSong?.title ?? l.settingsProfileStatsNone,
          muted: stats.topSong == null,
          footnote: stats.topSong == null
              ? null
              : [
                  stats.topSong!.artist,
                  l.settingsProfileStatsPlayCount(stats.topSong!.plays),
                ].whereType<String>().join(' • '),
        ),
        const SizedBox(height: 22),
        _week(context, stats.days),
      ],
    );
  }

  Widget _stat(
    BuildContext context, {
    required String label,
    required String value,
    String? footnote,
    bool muted = false,
  }) {
    final c = context.sono;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: SonoFonts.primary,
            fontSize: 12.5,
            color: c.textTertiary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: SonoFonts.heading,
            fontSize: 20,
            color: muted ? c.textTertiary : c.textPrimary,
          ),
        ),
        if (footnote != null) ...[
          const SizedBox(height: 2),
          Text(
            footnote,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 12,
              color: c.textTertiary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _week(BuildContext context, List<({DateTime day, int totalMs})> days) {
    final c = context.sono;
    final locale = Localizations.localeOf(context).toString();
    final label = DateFormat.E(locale);

    final start = _weekStart;
    final byDay = {for (final d in days) _key(d.day): d.totalMs};
    final week = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
    final peak = byDay.values.fold(0, (a, b) => a > b ? a : b);
    final today = _key(DateTime.now());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in week)
          Expanded(
            child: _bar(
              context,
              ms: byDay[_key(day)] ?? 0,
              peak: peak,
              label: label.format(day),
              isToday: _key(day) == today,
              accent: c.accentPurple,
            ),
          ),
      ],
    );
  }

  Widget _bar(
    BuildContext context, {
    required int ms,
    required int peak,
    required String label,
    required bool isToday,
    required Color accent,
  }) {
    final c = context.sono;
    final fill = peak == 0 ? 0.0 : ms / peak;
    final height = _barMinHeight + (_barHeight - _barMinHeight) * fill;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _barHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: ms == 0 ? c.borderLight20 : accent,
                borderRadius: BorderRadius.circular(SonoSizes.borderRadiusSm),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontFamily: SonoFonts.primary,
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
            color: isToday ? c.textSecondary : c.textTertiary,
          ),
        ),
      ],
    );
  }

  static String _key(DateTime at) => '${at.year}-${at.month}-${at.day}';
}
