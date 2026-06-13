import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:sono/services/scanner/scan_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';

import 'package:sono/l10n/localizations.dart';
import 'package:sono/services/locale_service.dart';

import 'package:sono/services/scanner/scan_settings.dart';
import 'package:sono/services/audio/audio_effects_service.dart';
import 'package:sono/services/discord_rpc/discord_rpc_service.dart';
import 'package:sono/services/update_service.dart';

import 'package:sono/main.dart';
import 'package:sono/db/database.dart';
import 'package:sono/pages/auth/discord_login_page.dart';

import 'package:sono/theme/tokens.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';

import 'package:sono/widgets/bouncy_tap.dart';
import 'package:sono/widgets/contributors_sheet.dart';
import 'package:sono/widgets/kofi_button.dart';

import 'package:sono_query/sono_query.dart' hide Song;

const double _bottomInset = SonoSizes.playerHeight * 2 + 22 + 16;

class SettingsPage extends StatefulWidget {
  final SonoDatabase db;
  final VoidCallback? onRescan;
  const SettingsPage({required this.db, this.onRescan, super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ScanConfig? _config;
  AlbumGrouping _grouping = AlbumGrouping.tag;
  final _excludedPathCtrl = TextEditingController();
  final _additionalPathCtrl = TextEditingController();
  final _artistCtrl = TextEditingController();
  final _delimiterCtrl = TextEditingController();
  final _minDurationCtrl = TextEditingController();

  //profile state
  String _username = '';
  Uint8List? _avatar;
  final _usernameCtrl = TextEditingController();

  //discord RPC state
  bool _discordConnected = false;
  bool _discordEnabled = false;
  String? _discordUsername;
  bool _discordLoading = false;

  //update state
  bool _updateChecking = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadDiscord();
    _loadProfile();
  }

  @override
  void dispose() {
    _excludedPathCtrl.dispose();
    _additionalPathCtrl.dispose();
    _artistCtrl.dispose();
    _delimiterCtrl.dispose();
    _minDurationCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await ScanSettings(widget.db).load();
    final grouping = await ScanSettings(widget.db).loadAlbumGrouping();
    _minDurationCtrl.text = c.minDuration?.inSeconds.toString() ?? '';
    if (mounted) {
      setState(() {
        _config = c;
        _grouping = grouping;
      });
    }
  }

  Future<void> _save(ScanConfig c) async {
    await ScanSettings(widget.db).save(c);
    if (mounted) setState(() => _config = c);
    widget.onRescan?.call();
  }

  Future<void> _saveGrouping(AlbumGrouping g) async {
    await ScanSettings(widget.db).saveAlbumGrouping(g);
    if (mounted) setState(() => _grouping = g);
    widget.onRescan?.call();
  }

  Future<void> _loadDiscord() async {
    final rpc = DiscordRpcService.instance;
    await rpc.ready;
    final connected = rpc.isConnected;
    final enabled = rpc.isEnabled;
    String? username;
    if (connected) {
      username = await widget.db.getSetting('discord.username');
    }
    if (mounted) {
      setState(() {
        _discordConnected = connected;
        _discordEnabled = enabled;
        _discordUsername = username;
      });
    }
  }

  Future<void> _discordLogin() async {
    final token = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const DiscordLoginPage()),
    );
    if (token == null || !mounted) return;

    setState(() => _discordLoading = true);
    try {
      final user = await DiscordRpcService.instance.login(token);
      await widget.db.setSetting('discord.username', '@${user.username}');
      if (mounted) {
        setState(() {
          _discordConnected = true;
          _discordEnabled = true;
          _discordUsername = '@${user.username}';
          _discordLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _discordLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Discord login failed: $e')));
      }
    }
  }

  Future<void> _discordLogout() async {
    await DiscordRpcService.instance.logout();
    if (mounted) {
      setState(() {
        _discordConnected = false;
        _discordEnabled = false;
        _discordUsername = null;
      });
    }
  }

  Future<void> _loadProfile() async {
    final p = await widget.db.getProfile();
    if (!mounted) return;
    setState(() {
      _username = p?.username ?? '';
      _avatar = p?.avatar;
      _usernameCtrl.text = _username;
    });
  }

  Future<void> _pickAvatar() async {
    final res = await FilePicker.pickFiles(
      type: FileType.image,
      //yes, we could use "custom" to guard file formats, but I hate the SAF document picker ui
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final file = res.files.first;
    final bytes = res.files.first.bytes;
    if (bytes == null) return;

    //extension guard
    const allowed = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'};
    final ext = file.extension?.toLowerCase();
    if (ext == null || !allowed.contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('only images pwease :)'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    //verify its a decodable image
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      codec.dispose();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('that file there..is NOT a valid image, hmph'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await widget.db.upsertProfile(avatar: Value(bytes));
    if (mounted) setState(() => _avatar = bytes);
  }

  Future<void> _clearAvatar() async {
    await widget.db.upsertProfile(avatar: const Value(null));
    if (mounted) setState(() => _avatar = null);
  }

  Future<void> _checkForUpdatesManual() async {
    if (_updateChecking) return;
    setState(() => _updateChecking = true);

    final info = await UpdateService.instance.checkForUpdates(force: true);

    if (!mounted) return;
    setState(() => _updateChecking = false);

    if (info == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('you are up to date :D')));
      return;
    }

    //show dialog with view/dismiss
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update available'),
        content: Text('${info.currentVersion} > ${info.latestVersion}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'dismiss'),
            child: const Text('Dismiss'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'view'),
            child: const Text('View release'),
          ),
        ],
      ),
    );

    if (action == 'view') {
      await UpdateService.instance.dismiss(info.latestVersion);
      await launchUrl(
        Uri.parse(info.releaseUrl),
        mode: LaunchMode.externalApplication,
      );
    } else if (action == 'dismiss') {
      await UpdateService.instance.dismiss(info.latestVersion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _config;
    if (c == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      children: [
        const SizedBox(height: 60),

        if (Platform.isIOS) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'To add music, copy your audio files into Sono\'s folder using the Files app.',
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => launchUrl(
                          Uri.parse('shareddocuments:///'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('Open Files app'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ==== profile ====
        const _SectionHeader(label: 'Profile'),
        const SizedBox(height: 12),
        Row(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                backgroundImage: _avatar != null ? MemoryImage(_avatar!) : null,
                child: _avatar == null
                    ? IconsSheet.svg(
                        IconsSheet.profileFilled,
                        color: context.sono.textSecondary,
                        size: 26,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _usernameCtrl,
                textInputAction: TextInputAction.done,
                autofocus: false,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'username',
                  hintText: 'your name',
                ),
                onSubmitted: (val) {
                  final v = _usernameCtrl.text.trim();
                  if (v == _username) return;
                  _username = v;
                  widget.db.upsertProfile(username: v);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('username updated :D'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
            if (_avatar != null)
              IconButton(
                icon: IconsSheet.svg(
                  IconsSheet.closeOutlined,
                  color: context.sono.textSecondary,
                  size: SonoSizes.iconSm,
                ),
                tooltip: 'Remove Avatar',
                onPressed: _clearAvatar,
              ),
          ],
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 12),

        // ==== language ====
        _SectionHeader(label: 'Language'),
        const SizedBox(height: 12),
        const _LanguageSection(),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 12),

        // ==== appearance ====
        const _SectionHeader(label: 'Appearance'),
        const SizedBox(height: 4),
        ValueListenableBuilder<SonoColors>(
          valueListenable: SonoApp.themeNotifier,
          builder: (_, colors, _) {
            final isDark = colors == SonoColors.dark;
            return SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark mode'),
              value: isDark,
              onChanged: (val) {
                SonoApp.themeNotifier.value = val
                    ? SonoColors.dark
                    : SonoColors.light;
              },
            );
          },
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 12),

        // ==== playback effects ====
        const _SectionHeader(label: 'Playback'),
        const SizedBox(height: 12),
        const _EffectsSection(),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 12),

        // ==== library / scan ====
        const _SectionHeader(label: 'Library'),
        const SizedBox(height: 12),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('group by folder'),
          subtitle: const Text('use song folder instead of album tag'),
          value: _grouping == AlbumGrouping.folder,
          onChanged: (on) =>
              _saveGrouping(on ? AlbumGrouping.folder : AlbumGrouping.tag),
        ),
        const SizedBox(height: 16),

        //min dur
        Row(
          children: [
            const Text('min duration (sec)'),
            const Spacer(),
            SizedBox(
              width: 64,
              child: TextField(
                controller: _minDurationCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'off',
                ),
                onSubmitted: (val) {
                  final s = int.tryParse(val);
                  _save(
                    ScanConfig(
                      excludedPaths: c.excludedPaths,
                      additionalPaths: c.additionalPaths,
                      minDuration: s != null ? Duration(seconds: s) : null,
                      artistParser: c.artistParser,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        //excluded paths
        _chipList(
          'excluded paths',
          c.excludedPaths,
          _excludedPathCtrl,
          'e.g. /storage/.../Ringtones',
          onAdd: (val) => _save(
            ScanConfig(
              excludedPaths: [...c.excludedPaths, val],
              additionalPaths: c.additionalPaths,
              minDuration: c.minDuration,
              artistParser: c.artistParser,
            ),
          ),
          onRemove: (i) => _save(
            ScanConfig(
              excludedPaths: [...c.excludedPaths]..removeAt(i),
              additionalPaths: c.additionalPaths,
              minDuration: c.minDuration,
              artistParser: c.artistParser,
            ),
          ),
        ),
        const SizedBox(height: 16),

        //additional paths
        if (Platform.isLinux || Platform.isWindows)
          _chipList(
            'additional paths',
            c.additionalPaths,
            _additionalPathCtrl,
            'e.g. /home/user/Downloads',
            onAdd: (val) => _save(
              ScanConfig(
                excludedPaths: c.excludedPaths,
                additionalPaths: [...c.additionalPaths, val],
                minDuration: c.minDuration,
                artistParser: c.artistParser,
              ),
            ),
            onRemove: (i) => _save(
              ScanConfig(
                excludedPaths: c.excludedPaths,
                additionalPaths: [...c.additionalPaths]..removeAt(i),
                minDuration: c.minDuration,
                artistParser: c.artistParser,
              ),
            ),
          ),
        if (Platform.isLinux || Platform.isWindows) const SizedBox(height: 16),

        //artist parser toggle
        SwitchListTile(
          title: const Text('multi-artist parsing'),
          contentPadding: EdgeInsets.zero,
          value: c.artistParser != null,
          onChanged: (on) => _save(
            ScanConfig(
              excludedPaths: c.excludedPaths,
              additionalPaths: c.additionalPaths,
              minDuration: c.minDuration,
              artistParser: on
                  ? (c.artistParser ?? const ArtistParserConfig())
                  : null,
            ),
          ),
        ),

        if (c.artistParser != null) ...[
          //delimiters
          _chipList(
            'delimiters',
            c.artistParser!.delimiters,
            _delimiterCtrl,
            'e.g. " / " or ";"',
            onAdd: (val) => _save(
              ScanConfig(
                excludedPaths: c.excludedPaths,
                additionalPaths: c.additionalPaths,
                minDuration: c.minDuration,
                artistParser: ArtistParserConfig(
                  delimiters: [...c.artistParser!.delimiters, val],
                  excludedArtists: c.artistParser!.excludedArtists,
                ),
              ),
            ),
            onRemove: (i) => _save(
              ScanConfig(
                excludedPaths: c.excludedPaths,
                additionalPaths: c.additionalPaths,
                minDuration: c.minDuration,
                artistParser: ArtistParserConfig(
                  delimiters: [...c.artistParser!.delimiters]..removeAt(i),
                  excludedArtists: c.artistParser!.excludedArtists,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          //protected artists
          _chipList(
            'protected artists',
            c.artistParser!.excludedArtists,
            _artistCtrl,
            'e.g. Tyler, The Creator',
            onAdd: (val) => _save(
              ScanConfig(
                excludedPaths: c.excludedPaths,
                additionalPaths: c.additionalPaths,
                minDuration: c.minDuration,
                artistParser: ArtistParserConfig(
                  delimiters: c.artistParser!.delimiters,
                  excludedArtists: [...c.artistParser!.excludedArtists, val],
                ),
              ),
            ),
            onRemove: (i) => _save(
              ScanConfig(
                excludedPaths: c.excludedPaths,
                additionalPaths: c.additionalPaths,
                minDuration: c.minDuration,
                artistParser: ArtistParserConfig(
                  delimiters: c.artistParser!.delimiters,
                  excludedArtists: [...c.artistParser!.excludedArtists]
                    ..removeAt(i),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 12),

        // ==== discord ====
        if (Platform.isAndroid || Platform.isIOS) ...[
          const _SectionHeader(label: 'Discord RPC'),
          const SizedBox(height: 12),
          if (_discordLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_discordConnected) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_discordUsername ?? 'Connected'),
              trailing: TextButton(
                onPressed: _discordLogout,
                child: const Text('Disconnect'),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enabled'),
              value: _discordEnabled,
              onChanged: (val) async {
                await DiscordRpcService.instance.setEnabled(val);
                if (mounted) setState(() => _discordEnabled = val);
              },
            ),
          ] else
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Connect Discord'),
              subtitle: const Text('to show current song on discord.'),
              trailing: FilledButton(
                onPressed: _discordLogin,
                child: const Text('Sign in'),
              ),
            ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 12),
        ],

        // ==== updates checker ====
        const _SectionHeader(label: 'Updates'),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Check for updates'),
          subtitle: const Text('looks at the github releases page.'),
          trailing: _updateChecking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: _checkForUpdatesManual,
                  child: const Text('Check'),
                ),
        ),

        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 12),

        // ==== contributors & support ====
        Row(
          children: [
            Expanded(child: _ContributorsButton(label: l.settingsContributors)),
            const SizedBox(width: 10),
            Expanded(
              child: KofiButton(
                url: 'https://ko-fi.com/mathiiis',
                label: l.settingsSupportKofi,
              ),
            ),
          ],
        ),

        // ==== bottom clearance ====
        SizedBox(height: _bottomInset),
      ],
    );
  }

  Widget _chipList(
    String label,
    List<String> items,
    TextEditingController ctrl,
    String hint, {
    required void Function(String) onAdd,
    required void Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Wrap(
          spacing: 6,
          children: [
            for (var i = 0; i < items.length; i++)
              Chip(
                label: Text(items[i], style: const TextStyle(fontSize: 12)),
                onDeleted: () => onRemove(i),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(isDense: true, hintText: hint),
          onSubmitted: (val) {
            if (val.trim().isEmpty) return;
            onAdd(val.trim());
            ctrl.clear();
          },
        ),
      ],
    );
  }
}

// ==== section header ====
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontFamily: SonoFonts.heading),
    );
  }
}

// ==== language section ====
class _LanguageSection extends StatelessWidget {
  const _LanguageSection();

  String _labelFor(Locale locale) {
    final name = LocaleService.nativeNameOf(locale);
    final pct = LocaleService.completionFor(locale);
    if (pct == null || pct >= 1.0) return name;
    return '$name (${(pct * 100).round()}%)';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleService.notifier,
      builder: (_, current, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('App language'),
            const SizedBox(height: 8),
            DropdownButton<Locale?>(
              value: current,
              underline: const SizedBox.shrink(),
              dropdownColor: context.sono.bgNav,
              items: [
                const DropdownMenuItem<Locale?>(
                  value: null,
                  child: Text('System default'),
                ),
                for (final locale in LocaleService.supportedLocales)
                  if ((LocaleService.completionFor(locale) ?? 0) > 0)
                    DropdownMenuItem<Locale?>(
                      value: locale,
                      child: Text(_labelFor(locale)),
                    ),
              ],
              onChanged: (locale) => LocaleService.instance.setLocale(locale),
            ),
          ],
        );
      },
    );
  }
}

// ==== effects section ====
class _EffectsSection extends StatefulWidget {
  const _EffectsSection();

  @override
  State<_EffectsSection> createState() => _EffectsSectionState();
}

class _EffectsSectionState extends State<_EffectsSection> {
  final _fx = AudioEffectsService.instance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==== equalizer header ====
        Row(
          children: [
            const Text('EQ'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.restart_alt_rounded, size: 20),
              tooltip: 'Reset EQ',
              color: Colors.orange,
              onPressed: () async {
                await _fx.resetEq();
                setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Reset All',
              color: Colors.red,
              onPressed: () async {
                await _fx.resetAll();
                setState(() {});
              },
            ),
            Switch(
              value: _fx.eqEnabled,
              onChanged: (v) async {
                await _fx.setEnabled(v);
                setState(() {});
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ==== eq bands ====
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(bandCount, (i) {
              return Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: Slider(
                          value: _fx.eqGains[i],
                          min: -12.0,
                          max: 12.0,
                          onChanged: _fx.eqEnabled
                              ? (v) async {
                                  _fx.setEqBand(i, v);
                                  setState(() {});
                                }
                              : null,
                        ),
                      ),
                    ),
                    Text(eqBands[i].label, style: const TextStyle(fontSize: 9)),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),

        // ==== bass boost ====
        _EffectRow(
          label: 'Bass boost',
          valueLabel: '${_fx.bassBoost.toStringAsFixed(1)} dB',
          value: _fx.bassBoost,
          min: 0.0,
          max: 20.0,
          onChanged: (v) async {
            _fx.setBassBoost(v);
            setState(() {});
          },
        ),
        const SizedBox(height: 8),

        // ==== speed ====
        _EffectRow(
          label: 'Speed',
          valueLabel: '${_fx.speed.toStringAsFixed(2)}x',
          value: _fx.speed,
          min: 0.25,
          max: 4.0,
          onChanged: (v) async {
            _fx.setSpeed(v);
            setState(() {});
          },
        ),
        const SizedBox(height: 8),

        // ==== pitch ====
        _EffectRow(
          label: 'Pitch',
          valueLabel: '${_fx.pitch.toStringAsFixed(2)}x',
          value: _fx.pitch,
          min: 0.25,
          max: 4.0,
          onChanged: (v) async {
            _fx.setPitch(v);
            setState(() {});
          },
        ),
      ],
    );
  }
}

class _EffectRow extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _EffectRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(
          width: 52,
          child: Text(
            valueLabel,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ==== contributors button ====
class _ContributorsButton extends StatelessWidget {
  final String label;
  const _ContributorsButton({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    return BouncyTap(
      onTap: () => ContributorsSheet.show(context),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
          border: Border.all(color: c.borderLight20, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconsSheet.svg(
              IconsSheet.profileFilled,
              size: SonoSizes.iconSm,
              color: c.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SonoFonts.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
