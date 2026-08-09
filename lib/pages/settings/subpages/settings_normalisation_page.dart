import 'package:flutter/material.dart';

import 'package:sono/db/database.dart';
import 'package:sono/l10n/localizations.dart';

import 'package:sono/services/audio/audio_effects_service.dart';

import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';

import 'package:sono/widgets/header.dart';

import 'package:sono/pages/settings/widgets/settings_group.dart';
import 'package:sono/pages/settings/widgets/settings_row.dart';
import 'package:sono/pages/settings/widgets/settings_scaffold.dart';

class SettingsNormalisationPage extends StatefulWidget {
  final SonoDatabase db;

  const SettingsNormalisationPage({required this.db, super.key});

  @override
  State<SettingsNormalisationPage> createState() =>
      _SettingsNormalisationPageState();
}

class _SettingsNormalisationPageState extends State<SettingsNormalisationPage> {
  final _fx = AudioEffectsService.instance;

  late NormalisationMode _mode;
  late double _preamp;
  late bool _preventClipping;

  @override
  void initState() {
    super.initState();
    _mode = _fx.normalisation;
    _preamp = _fx.normalisationPreamp;
    _preventClipping = _fx.preventClipping;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return SettingsScaffold(
      db: widget.db,
      title: l.settingsPlaybackNormalisation,
      actions: [
        SonoHeaderAction(
          icon: IconsSheet.updateOutlined,
          tooltip: l.normalisationResetTooltip,
          onTap: _reset,
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroupLabel(text: l.normalisationSectionMode),
                SettingsGroup(
                  children: [
                    SettingsCheckRow(
                      label: l.normalisationOff,
                      selected: _mode == NormalisationMode.off,
                      onTap: () => _setMode(NormalisationMode.off),
                    ),
                    SettingsCheckRow(
                      label: l.normalisationTrack,
                      subtitle: l.normalisationTrackSubtitle,
                      selected: _mode == NormalisationMode.track,
                      onTap: () => _setMode(NormalisationMode.track),
                    ),
                    SettingsCheckRow(
                      label: l.normalisationAlbum,
                      subtitle: l.normalisationAlbumSubtitle,
                      selected: _mode == NormalisationMode.album,
                      onTap: () => _setMode(NormalisationMode.album),
                    ),
                  ],
                ),

                SettingsGroupLabel(text: l.normalisationSectionTuning),
                SettingsGroup(
                  children: [
                    SettingsSliderRow(
                      label: l.normalisationPreamp,
                      value: l.normalisationPreampValue(
                        _preamp.toStringAsFixed(1),
                      ),
                      current: _preamp,
                      min: -15,
                      max: 15,
                      divisions: 60,
                      onChanged: (value) {
                        setState(() => _preamp = value);
                        _fx.setNormalisationPreamp(value);
                      },
                    ),
                    SettingsRow(
                      icon: IconsSheet.volumeHighOutlined,
                      accent: c.accentPurple,
                      label: l.normalisationPreventClipping,
                      subtitle: l.normalisationPreventClippingSubtitle,
                      toggle: _preventClipping,
                      onToggle: (value) {
                        setState(() => _preventClipping = value);
                        _fx.setPreventClipping(value);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _setMode(NormalisationMode mode) {
    setState(() => _mode = mode);
    _fx.setNormalisation(mode);
  }

  Future<void> _reset() async {
    await _fx.resetNormalisation();
    if (!mounted) return;
    setState(() {
      _mode = _fx.normalisation;
      _preamp = _fx.normalisationPreamp;
      _preventClipping = _fx.preventClipping;
    });
  }
}
