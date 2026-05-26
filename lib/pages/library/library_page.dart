import 'package:sono/l10n/localizations.dart';

import 'package:flutter/material.dart';
import 'package:sono/db/database.dart';
import 'package:sono/pages/library/library_cards.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/header.dart';

const double _bottomInset = SonoSizes.playerHeight * 2 + 22 + 16;

class _CardData {
  final String title;
  final String icon;
  final Color iconColor;
  final VoidCallback onTap;
  const _CardData(this.title, this.icon, this.iconColor, this.onTap);
}

class LibraryPage extends StatefulWidget {
  final SonoDatabase db;
  const LibraryPage({required this.db, super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  Profile? _profile;

  List<(_CardData, _CardData)> _cardRows(AppLocalizations l) {
    final c = context.sono;

    return [
      (
        _CardData(
          l.libraryCardGenres,
          IconsSheet.genreFilled,
          c.accentAmber,
          () {},
        ),
        _CardData(
          l.libraryCardPlaylists,
          IconsSheet.playlistFilled,
          c.accentBlue,
          () {},
        ),
      ),
      (
        _CardData(
          l.libraryCardLikedSongs,
          IconsSheet.heartFilled,
          c.primary,
          () {},
        ),
        _CardData(
          l.libraryCardFavoriteAlbums,
          IconsSheet.favoriteAlbumFilled,
          c.accentPurple,
          () {},
        ),
      ),
      (
        _CardData(
          l.libraryCardFavoriteArtists,
          IconsSheet.favoriteArtistFilled,
          c.accentRed,
          () {},
        ),
        _CardData(
          l.libraryCardArtists,
          IconsSheet.artistFilled,
          c.accentTeal,
          () {},
        ),
      ),
      (
        _CardData(
          l.libraryCardSongs,
          IconsSheet.songFilled,
          c.accentGreen,
          () {},
        ),
        _CardData(
          l.libraryCardAlbums,
          IconsSheet.albumFilled,
          c.accentOrange,
          () {},
        ),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await widget.db.getProfile();
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = _cardRows(l);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // ==== header ====
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: SonoHeader(
                  isHomePage: true,
                  username: _profile?.username.isEmpty == true
                      ? null
                      : _profile?.username,
                  avatar: _profile?.avatar,
                  onProfileTap: () {},
                  actions: [
                    SonoHeaderAction(
                      icon: IconsSheet.bellOutlined,
                      tooltip: 'News & Updates',
                      onTap: () {},
                    ),
                    SonoHeaderAction(
                      icon: IconsSheet.settingsOutlined,
                      tooltip: 'Settings',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),

            // ==== cards ====
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final (short, long) = rows[index];
                  return Row(
                    children: [
                      SizedBox(
                        width: SonoLibraryCards.shortWidth,
                        child: SonoLibraryCards(
                          title: short.title,
                          icon: short.icon,
                          iconColor: short.iconColor,
                          onTap: short.onTap,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SonoLibraryCards(
                          title: long.title,
                          icon: long.icon,
                          iconColor: long.iconColor,
                          onTap: long.onTap,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ==== bottom clearance ====
            SliverToBoxAdapter(child: SizedBox(height: _bottomInset)),
          ],
        ),
      ),
    );
  }
}
