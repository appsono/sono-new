import 'package:flutter/material.dart';
import 'package:sono/db/database.dart';
import 'package:sono/services/scan_settings.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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
