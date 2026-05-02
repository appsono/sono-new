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

  List<(_CardData, _CardData)> get _cardRows => [
    (
      _CardData(
        'Genres',
        IconsSheet.libraryFilled,
        context.sono.textPlaceholder,
        () {},
      ),
      _CardData(
        'Playlists',
        IconsSheet.addToPlaylistFilled,
        context.sono.textPlaceholder,
        () {},
      ),
    ),
    (
      _CardData(
        'Liked Songs',
        IconsSheet.heartFilled,
        context.sono.textPlaceholder,
        () {},
      ),
      _CardData(
        'Favorite Albums',
        IconsSheet.heartFilled,
        context.sono.textPlaceholder,
        () {},
      ),
    ),
    (
      _CardData(
        'Favorite Artists',
        IconsSheet.heartFilled,
        context.sono.textPlaceholder,
        () {},
      ),
      _CardData(
        'Artists',
        IconsSheet.profileFilled,
        context.sono.textPlaceholder,
        () {},
      ),
    ),
    (
      _CardData(
        'Songs',
        IconsSheet.libraryFilled,
        context.sono.textPlaceholder,
        () {},
      ),
      _CardData(
        'Albums',
        IconsSheet.libraryFilled,
        context.sono.textPlaceholder,
        () {},
      ),
    ),
  ];

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
                itemCount: _cardRows.length,
                itemBuilder: (context, index) {
                  final (short, long) = _cardRows[index];
                  return Row(
                    children: [
                      SonoLibraryCards(
                        title: short.title,
                        icon: short.icon,
                        iconColor: short.iconColor,
                        type: CardType.short,
                        onTap: short.onTap,
                      ),
                      const SizedBox(width: 12),
                      SonoLibraryCards(
                        title: long.title,
                        icon: long.icon,
                        iconColor: long.iconColor,
                        type: CardType.long,
                        onTap: long.onTap,
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
