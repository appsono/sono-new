import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/list_row.dart';
import 'package:sono/widgets/mini_player.dart';
import 'package:sono/widgets/card_stack_cover.dart';
import 'package:sono/pages/library/subpages/genre_detail_page.dart';

enum GenresListSource { all, search }

const double _bottomInset = SonoSizes.playerHeight + 22 + 16;

class GenresPage extends StatefulWidget {
  final SonoDatabase db;
  final GenresListSource source;
  final String? query;
  final String? title;

  const GenresPage({
    required this.db,
    this.source = GenresListSource.all,
    this.query,
    this.title,
    super.key,
  });

  @override
  State<GenresPage> createState() => _GenresPageState();
}

class _GenresPageState extends State<GenresPage> {
  List<({String genre, int count, String firstPath})>? _genres;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final genres = switch (widget.source) {
      GenresListSource.all => await widget.db.getAllGenresWithCounts(),
      GenresListSource.search => await widget.db.searchGenres(
        widget.query ?? '',
      ),
    };
    if (!mounted) return;
    setState(() => _genres = genres);
  }

  String _title(AppLocalizations l) {
    if (widget.title != null) widget.title!;
    return switch (widget.source) {
      GenresListSource.all => l.libraryCardGenres,
      GenresListSource.search => widget.query ?? l.libraryCardGenres,
    };
  }

  void _openGenre(String genre) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GenreDetailPage(db: widget.db, genre: genre),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final genres = _genres;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SonoStickyHeader(
                child: SonoHeader(
                  backButton: true,
                  pageTitle: _title(l),
                  onBackTap: () => Navigator.of(context).pop(),
                  actions: const [],
                ),
              ),

              if (genres == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (genres.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(l.libraryEmptyGenres)),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList.separated(
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemCount: genres.length,
                    itemBuilder: (context, i) {
                      final g = genres[i];
                      return SonoListRow(
                        coverPath: '', //ignored when leading is provided
                        leading: SonoCardStackCover(
                          coverPath: g.firstPath,
                          size: SonoListRow.coverSize - 10,
                        ),
                        title: g.genre,
                        subtitle: l.commonSongsCount(g.count),
                        onTap: () => _openGenre(g.genre),
                      );
                    },
                  ),
                ),

              SliverToBoxAdapter(child: SizedBox(height: _bottomInset)),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 22,
            child: SonoMiniPlayer(db: widget.db, navBarVisible: false),
          ),
        ],
      ),
    );
  }
}
