import 'package:flutter/material.dart';
import 'package:sono/db/database.dart';
import 'package:sono/pages/auth/discord_login_page.dart';
import 'package:sono/services/scan_settings.dart';
import 'package:sono/services/discord_rpc/discord_rpc_service.dart';
import 'package:sono_query/sono_query.dart' hide Song;

class SettingsPage extends StatefulWidget {
  final SonoDatabase db;
  final VoidCallback? onRescan;
  const SettingsPage({required this.db, this.onRescan, super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ScanConfig? _config;
  final _excludedPathCtrl = TextEditingController();
  final _additionalPathCtrl = TextEditingController();
  final _artistCtrl = TextEditingController();
  final _delimiterCtrl = TextEditingController();

  //discord RPC state
  bool _discordConnected = false;
  bool _discordEnabled = false;
  String? _discordUsername;
  bool _discordLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadDiscord();
  }

  @override
  void dispose() {
    _excludedPathCtrl.dispose();
    _additionalPathCtrl.dispose();
    _artistCtrl.dispose();
    _delimiterCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await ScanSettings(widget.db).load();
    setState(() => _config = c);
  }

  Future<void> _save(ScanConfig c) async {
    await ScanSettings(widget.db).save(c);
    setState(() => _config = c);
    widget.onRescan?.call();
  }

  Future<void> _loadDiscord() async {
    final rpc = DiscordRpcService.instance;
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

  @override
  Widget build(BuildContext context) {
    final c = _config;
    if (c == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 60),

        //min dur
        Row(
          children: [
            const Text('min duration (sec)'),
            const Spacer(),
            SizedBox(
              width: 64,
              child: TextField(
                controller: TextEditingController(
                  text: c.minDuration?.inSeconds.toString() ?? '',
                ),
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
        const SizedBox(height: 16),

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
              setState(() => _discordEnabled = val);
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
