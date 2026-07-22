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

import 'package:sono/l10n/localizations.dart';

import 'package:sono/theme/icons.dart';
import 'package:sono/theme/tokens.dart';

/// Where a search result lives
///
/// Root is for settings without a subpage
enum SettingsDestination {
  root,
  profile,
  appearance,
  language,
  playback,
  equalizer,
  library,
  discord,
  backup,
  about,
}

class SettingsSearchEntry {
  final String label;
  final SettingsDestination destination;

  const SettingsSearchEntry(this.label, this.destination);
}

/// Every searchable settings
///
/// Built per call so labels stay localized
List<SettingsSearchEntry> settingsSearchIndex(AppLocalizations l) {
  const profile = SettingsDestination.profile;
  const appearance = SettingsDestination.appearance;
  const language = SettingsDestination.language;
  const playback = SettingsDestination.playback;
  const equalizer = SettingsDestination.equalizer;
  const library = SettingsDestination.library;
  const discord = SettingsDestination.discord;
  const backup = SettingsDestination.backup;
  const about = SettingsDestination.about;
  const root = SettingsDestination.root;

  return [
    SettingsSearchEntry(l.settingsProfileName, profile),
    SettingsSearchEntry(l.settingsProfileStats, profile),

    SettingsSearchEntry(l.settingsAppearance, appearance),
    SettingsSearchEntry(l.settingsThemeSystem, appearance),
    SettingsSearchEntry(l.settingsThemeLight, appearance),
    SettingsSearchEntry(l.settingsThemeDark, appearance),
    SettingsSearchEntry(l.settingsAppearanceColourFromArt, appearance),
    SettingsSearchEntry(l.settingsAppearanceBlurredBackdrops, appearance),
    SettingsSearchEntry(l.settingsAppearanceReduceMotion, appearance),
    SettingsSearchEntry(l.settingsAppearanceGridDensity, appearance),
    SettingsSearchEntry(l.settingsAppearanceTrackNumbers, appearance),

    SettingsSearchEntry(l.settingsLanguage, language),
    SettingsSearchEntry(l.settingsLanguageHelpTranslate, language),

    SettingsSearchEntry(l.settingsPlayback, playback),
    SettingsSearchEntry(l.settingsPlaybackGapless, playback),
    SettingsSearchEntry(l.settingsPlaybackCrossfade, playback),
    SettingsSearchEntry(l.settingsPlaybackFadeOnPause, playback),
    SettingsSearchEntry(l.settingsPlaybackNormalisation, playback),
    SettingsSearchEntry(l.settingsPlaybackVolume, playback),
    SettingsSearchEntry(l.settingsPlaybackSectionTransitions, playback),
    SettingsSearchEntry(l.settingsPlaybackResumeOnConnect, playback),
    SettingsSearchEntry(l.settingsPlaybackPauseOnDisconnect, playback),

    SettingsSearchEntry(l.settingsEqualizer, equalizer),
    SettingsSearchEntry(l.settingsEqBassBoost, equalizer),
    SettingsSearchEntry(l.settingsEqSpeed, equalizer),
    SettingsSearchEntry(l.settingsEqPitch, equalizer),
    SettingsSearchEntry(l.settingsEqResetAll, equalizer),

    SettingsSearchEntry(l.settingsLibrary, library),
    SettingsSearchEntry(l.settingsLibraryMusicFolders, library),
    SettingsSearchEntry(l.settingsLibraryExcludedFolders, library),
    SettingsSearchEntry(l.settingsLibraryMinLength, library),
    SettingsSearchEntry(l.settingsLibraryGroupByFolder, library),
    SettingsSearchEntry(l.settingsLibraryIgnoreLeadingThe, library),
    SettingsSearchEntry(l.settingsLibrarySplitArtists, library),
    SettingsSearchEntry(l.settingsLibraryDelimiters, library),
    SettingsSearchEntry(l.settingsLibraryProtectedArtists, library),
    SettingsSearchEntry(l.settingsLibraryRescan, library),

    SettingsSearchEntry(l.settingsDiscord, discord),
    SettingsSearchEntry(l.settingsDiscordShowSong, discord),
    SettingsSearchEntry(l.settingsDiscordShowArt, discord),
    SettingsSearchEntry(l.settingsDiscordShowElapsed, discord),
    SettingsSearchEntry(l.settingsDiscordShowButton, discord),
    SettingsSearchEntry(l.settingsDiscordOnlyWhilePlaying, discord),

    SettingsSearchEntry(l.settingsBackup, backup),
    SettingsSearchEntry(l.settingsBackupExport, backup),
    SettingsSearchEntry(l.settingsBackupImport, backup),
    SettingsSearchEntry(l.settingsBackupWeekly, backup),

    SettingsSearchEntry(l.settingsAbout, about),
    SettingsSearchEntry(l.changelogTitle, about),
    SettingsSearchEntry(l.settingsContributors, about),
    SettingsSearchEntry(l.settingsAboutSourceCode, about),
    SettingsSearchEntry(l.settingsAboutLicences, about),
    SettingsSearchEntry(l.settingsSupportKofi, about),

    SettingsSearchEntry(l.settingsUpdates, root),
    SettingsSearchEntry(l.settingsStorage, root),
  ];
}

/// Matches on setting and its page name
List<SettingsSearchEntry> searchSettings(AppLocalizations l, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];

  return settingsSearchIndex(l)
      .where(
        (e) =>
            e.label.toLowerCase().contains(needle) ||
            destinationLabel(l, e.destination).toLowerCase().contains(needle),
      )
      .toList();
}

// ==== destination presentation ====
String destinationLabel(AppLocalizations l, SettingsDestination d) {
  return switch (d) {
    SettingsDestination.root => l.settingsPageTitle,
    SettingsDestination.profile => l.settingsProfileTitle,
    SettingsDestination.appearance => l.settingsAppearance,
    SettingsDestination.language => l.settingsLanguage,
    SettingsDestination.playback => l.settingsPlayback,
    SettingsDestination.equalizer => l.settingsEqualizer,
    SettingsDestination.library => l.settingsLibrary,
    SettingsDestination.discord => l.settingsDiscord,
    SettingsDestination.backup => l.settingsBackup,
    SettingsDestination.about => l.settingsAbout,
  };
}

String destinationIcon(SettingsDestination d) {
  return switch (d) {
    SettingsDestination.root => IconsSheet.settingsOutlined,
    SettingsDestination.profile => IconsSheet.profileOutlined,
    SettingsDestination.appearance => IconsSheet.appearanceOutlined,
    SettingsDestination.language => IconsSheet.globusOutlined,
    SettingsDestination.playback => IconsSheet.songOutlined,
    SettingsDestination.equalizer => IconsSheet.equalizerOutlined,
    SettingsDestination.library => IconsSheet.libraryOutlined,
    SettingsDestination.discord => SonoBrands.discord,
    SettingsDestination.backup => IconsSheet.backupOutlined,
    SettingsDestination.about => IconsSheet.infoOutlined,
  };
}

Color destinationAccent(SonoColors c, SettingsDestination d) {
  return switch (d) {
    SettingsDestination.root => c.textSecondary,
    SettingsDestination.profile => c.accentBlue,
    SettingsDestination.appearance => c.accentPurple,
    SettingsDestination.language => c.accentBlue,
    SettingsDestination.playback => c.accentGreen,
    SettingsDestination.equalizer => c.accentAmber,
    SettingsDestination.library => c.accentTeal,
    SettingsDestination.discord => c.accentLightBlue,
    SettingsDestination.backup => c.accentOrange,
    SettingsDestination.about => c.accentRed,
  };
}
