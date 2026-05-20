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
    //TODO: adds keys for these when the feature ships
    QueueSource.liked => l.playerOriginAllSongs,
    QueueSource.search => l.playerOriginAllSongs,
    //these should always carry a data label, just in-case fallback:
    QueueSource.album ||
    QueueSource.artist ||
    QueueSource.playlist => l.playerOriginAllSongs,
  };
}
