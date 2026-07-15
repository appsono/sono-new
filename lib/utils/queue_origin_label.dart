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

import 'package:flutter/widgets.dart';

import 'package:sono/l10n/localizations.dart';
import 'package:sono/services/audio/audio_service.dart';

String queueOriginLabel({
  required BuildContext context,
  required QueueOrigin origin,
}) {
  //data driven label (album title, artist name, etc) wins
  if (origin.label != null) return origin.label!;
  final l = AppLocalizations.of(context);
  return switch (origin.source) {
    QueueSource.allSongs => l.playerOriginAllSongs,
    QueueSource.recentlyAdded => l.homeSectionRecentlyAdded,
    QueueSource.liked => l.playerOriginAllSongs,
    QueueSource.search => l.playerOriginAllSongs,
    //these should always carry a data label, just in-case fallback:
    QueueSource.album ||
    QueueSource.artist ||
    QueueSource.playlist => l.playerOriginAllSongs,
  };
}
