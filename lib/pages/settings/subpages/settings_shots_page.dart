import 'package:flutter/material.dart';

import 'package:sono/db/database.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/widgets/header.dart';

const String kShotsBentoKey = 'shots.bentoAlbums';
const int kShotsBentoSlots = 4;
final ValueNotifier<int> kShotsBentoVersion = ValueNotifier(0);

// ==== picker row ====
const double _coverSize = 44;
const double _badgeRadius = 13;
const double _fullOpacity = 0.4;

// ==== shots album picker ====
// screenshot mode only, so every string here is hardcoded on pupose
class SettingsShotsPage extends StatefulWidget {
  final SonoDatabase db;

  const SettingsShotsPage({required this.db, super.key});

  @override
  State<SettingsShotsPage> createState() => _SettingsShotsPageState();
}

class _SettingsShotsPageState extends State<SettingsShotsPage> {
  List<AlbumWithArtistViewData>? _albums;
  Map<int, String> _covers = {};
  List<int> _picked = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final albums = await widget.db.getAllAlbumsWithArtists();
    final covers = await widget.db.getAlbumCoverPaths();
    final raw = await widget.db.getSetting(kShotsBentoKey) ?? '';

    final live = {for (final a in albums) a.id};
    final picked = <int>[];
    for (final part in raw.split(',')) {
      final id = int.tryParse(part.trim());
      if (id == null) continue;
      if (!live.contains(id) || !covers.containsKey(id)) continue;
      if (picked.contains(id)) continue;
      picked.add(id);
      if (picked.length == kShotsBentoSlots) break;
    }

    //only rewrite when stored was not already canonical
    final canonical = picked.join(',');
    if (canonical != raw && canonical.isNotEmpty) {
      await widget.db.setSetting(kShotsBentoKey, canonical);
    }

    if (!mounted) return;
    setState(() {
      _albums = albums..sort((a, b) => a.title.compareTo(b.title));
      _covers = covers;
      _picked = picked;
    });
  }

  Future<void> _toggle(int id) async {
    setState(() {
      if (_picked.contains(id)) {
        _picked.remove(id);
      } else if (_picked.length < kShotsBentoSlots) {
        _picked.add(id);
      }
    });
    await widget.db.setSetting(kShotsBentoKey, _picked.join(','));
    kShotsBentoVersion.value++;
  }

  Future<void> _clear() async {
    setState(() => _picked = []);
    await widget.db.setSetting(kShotsBentoKey, '');
    kShotsBentoVersion.value++;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final albums = _albums;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SonoStickyHeader(
            child: SonoHeader(
              backButton: true,
              pageTitle: 'Screenshot mode',
              onBackTap: () => Navigator.of(context).pop(),
              actions: [
                SonoHeaderAction(
                  icon: IconsSheet.closeOutlined,
                  tooltip: 'Clear selection',
                  onTap: _clear,
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                'Pick up to $kShotsBentoSlots albums in order. '
                'Leave empty for random.\n\n'
                'Selected ${_picked.length}/$kShotsBentoSlots',
                style: TextStyle(
                  fontFamily: SonoFonts.primary,
                  fontSize: 13,
                  color: c.textSecondary,
                ),
              ),
            ),
          ),

          if (albums == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else
            SliverList.builder(
              itemCount: albums.length,
              itemBuilder: (context, i) {
                final a = albums[i];
                final slot = _picked.indexOf(a.id);
                final full = slot < 0 && _picked.length >= kShotsBentoSlots;

                return Opacity(
                  opacity: full ? _fullOpacity : 1,
                  child: ListTile(
                    onTap: full ? null : () => _toggle(a.id),
                    leading: SonoCoverArt(
                      path: _covers[a.id] ?? '',
                      size: _coverSize,
                      borderRadius: SonoSizes.borderRadiusSm,
                    ),
                    title: Text(
                      a.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: SonoFonts.primary,
                        fontSize: 14,
                        color: c.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      a.artistName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: SonoFonts.primary,
                        fontSize: 12,
                        color: c.textSecondary,
                      ),
                    ),
                    trailing: slot < 0
                        ? null
                        : CircleAvatar(
                            radius: _badgeRadius,
                            backgroundColor: c.primary,
                            child: Text(
                              '${slot + 1}',
                              style: TextStyle(
                                fontFamily: SonoFonts.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: c.textLight,
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: SonoSizes.playerHeight * 2),
          ),
        ],
      ),
    );
  }
}
