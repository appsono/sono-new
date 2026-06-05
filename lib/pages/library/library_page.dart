import 'package:sono/l10n/localizations.dart';

import 'package:flutter/material.dart';
import 'package:sono/db/database.dart';
import 'package:sono/pages/library/library_cards.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/widgets/header.dart';

import 'package:sono/pages/library/subpages/albums_page.dart';
import 'package:sono/pages/library/subpages/artists_page.dart';
import 'package:sono/pages/library/subpages/songs_page.dart';

const double _bottomInset = SonoSizes.playerHeight * 2 + 22 + 16;

class _CardData {
  final String title;
  final String icon;
  final Color iconColor;
  final VoidCallback onTap;
  const _CardData(this.title, this.icon, this.iconColor, this.onTap);
}

typedef _Row = ({_CardData short, _CardData long, bool shortFirst});

class LibraryPage extends StatefulWidget {
  final SonoDatabase db;
  const LibraryPage({required this.db, super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  List<_Row> _cardRows(AppLocalizations l) {
    final c = context.sono;

    return [
      (
        short: _CardData(
          l.libraryCardPlaylists,
          IconsSheet.playlistFilled,
          c.accentBlue,
          () {},
        ),
        long: _CardData(
          l.libraryCardLikedSongs,
          IconsSheet.heartFilled,
          c.primary,
          () {},
        ),
        shortFirst: true,
      ),
      (
        short: _CardData(
          l.libraryCardAlbums,
          IconsSheet.albumFilled,
          c.accentOrange,
          () => _push(AlbumsPage(db: widget.db)),
        ),
        long: _CardData(
          l.libraryCardFavoriteAlbums,
          IconsSheet.favoriteAlbumFilled,
          c.accentPurple,
          () {},
        ),
        shortFirst: false,
      ),
      (
        short: _CardData(
          l.libraryCardArtists,
          IconsSheet.artistFilled,
          c.accentTeal,
          () => _push(ArtistsPage(db: widget.db)),
        ),
        long: _CardData(
          l.libraryCardFavoriteArtists,
          IconsSheet.favoriteArtistFilled,
          c.accentRed,
          () {},
        ),
        shortFirst: true,
      ),
      (
        short: _CardData(
          l.libraryCardGenres,
          IconsSheet.genreFilled,
          c.accentAmber,
          () {},
        ),
        long: _CardData(
          l.libraryCardSongs,
          IconsSheet.songFilled,
          c.accentGreen,
          () => _push(SongsPage(db: widget.db)),
        ),
        shortFirst: false,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = _cardRows(l);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ==== header ====
          StreamBuilder<Profile?>(
            stream: widget.db.watchProfile(),
            builder: (context, snap) {
              final profile = snap.data;
              return SonoStickyHeader(
                child: SonoHeader(
                  pageTitle: l.libraryPageTitle,
                  avatar: profile?.avatar,
                  onProfileTap: () {
                    //will open sidebar later
                  },
                  actions: [
                    SonoHeaderAction(
                      icon: IconsSheet.bellOutlined,
                      tooltip: l.homeHeaderNewsAndUpdates,
                      onTap: () {
                        //navigate to "changelog" page
                      },
                    ),
                    SonoHeaderAction(
                      icon: IconsSheet.settingsOutlined,
                      tooltip: l.homeHeaderSettings,
                      onTap: () {
                        //navigate to settings page
                      },
                    ),
                  ],
                ),
              );
            },
          ),

          // ==== cards ====
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];

                final shortCard = SizedBox(
                  width: SonoLibraryCards.shortWidth,
                  child: SonoLibraryCards(
                    title: row.short.title,
                    icon: row.short.icon,
                    iconColor: row.short.iconColor,
                    onTap: row.short.onTap,
                  ),
                );

                final longCard = Expanded(
                  child: SonoLibraryCards(
                    title: row.long.title,
                    icon: row.long.icon,
                    iconColor: row.long.iconColor,
                    onTap: row.long.onTap,
                  ),
                );

                return Row(
                  children: row.shortFirst
                      ? [shortCard, const SizedBox(width: 12), longCard]
                      : [longCard, const SizedBox(width: 12), shortCard],
                );
              },
            ),
          ),

          // ==== bottom clearance ====
          SliverToBoxAdapter(child: SizedBox(height: _bottomInset)),
        ],
      ),
    );
  }
}
