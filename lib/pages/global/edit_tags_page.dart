import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/main.dart';
import 'package:sono_query/sono_query.dart' hide Song;

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/cover_art.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/services/scanner/scan_service.dart';
import 'package:sono/services/scanner/scan_settings.dart';

/// Full-screen song tag editor
///
/// Opens above song sheet and returns true on save and pops
/// fields: title, artist, album, track number, year genres
/// (cover comes later)
class EditTagsPage extends StatefulWidget {
  final String path;
  final SonoDatabase db;

  const EditTagsPage({required this.path, required this.db, super.key});

  // ==== open helper
  // slide-up route, mirrors mini- to fullscreen-player
  static Future<bool?> open(
    BuildContext context,
    String path,
    SonoDatabase db,
  ) {
    return Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, _, _) => EditTagsPage(path: path, db: db),
        transitionsBuilder: (_, anim, _, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  State<EditTagsPage> createState() => _EditTagsPageState();
}

class _EditTagsPageState extends State<EditTagsPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;
  late final TextEditingController _albumCtrl;
  late final TextEditingController _trackCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _genresCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final meta = MetadataReader.readSync(widget.path);
    _titleCtrl = TextEditingController(text: meta.title);
    _artistCtrl = TextEditingController(text: meta.artist ?? '');
    _albumCtrl = TextEditingController(text: meta.album ?? '');
    _trackCtrl = TextEditingController(
      text: meta.trackNumber?.toString() ?? '',
    );
    _yearCtrl = TextEditingController(
      text: meta.releaseDate?.year.toString() ?? '',
    );
    _genresCtrl = TextEditingController(text: meta.genre ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    _trackCtrl.dispose();
    _yearCtrl.dispose();
    _genresCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final l = AppLocalizations.of(context);
    final messenger = SonoApp.messengerKey.currentState;

    //parse numerc/list fields. blanl == leave tag untouched
    final yearInt = int.tryParse(_yearCtrl.text.trim());
    final year = yearInt != null ? DateTime(yearInt) : null;
    final track = int.tryParse(_trackCtrl.text.trim());
    final genresInput = _genresCtrl.text
        .split(',')
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toList();
    final genres = genresInput.isEmpty ? null : genresInput;

    //writeSync is synchronous and returns false on unsupprted format or io error
    final wrote = await MetadataReader.writeAsync(
      widget.path,
      title: _titleCtrl.text.trim(),
      artist: _artistCtrl.text.trim(),
      album: _albumCtrl.text.trim(),
      trackNumber: track,
      year: year,
      genres: genres,
    );

    if (!wrote) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger?.showSnackBar(SnackBar(content: Text(l.editTagsSaveFailed)));
      return;
    }

    //sync DB with freshly written file
    try {
      final config = await ScanSettings(widget.db).load();
      final grouping = await ScanSettings(widget.db).loadAlbumGrouping();
      await ScanService(
        widget.db,
      ).rescanSingleSong(widget.path, config: config, grouping: grouping);
    } catch (e) {
      debugPrint('rescanSingleSong failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      messenger?.showSnackBar(SnackBar(content: Text(l.editTagsSaveFailed)));
      return;
    }

    if (!mounted) return;
    Navigator.of(context).maybePop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.sono;

    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==== header ====
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: SonoHeader(
                backButton: true,
                pageTitle: l.editTagsTitle,
                onBackTap: () => Navigator.of(context).maybePop(),
                actions: [
                  SonoHeaderAction(
                    icon: IconsSheet.checkOutlined,
                    tooltip: l.commonSave,
                    onTap: _saving ? () {} : _save,
                  ),
                ],
              ),
            ),

            // ==== body ====
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    //cover
                    Center(
                      child: SonoCoverArt(
                        path: widget.path,
                        size: 96,
                        shape: CoverShape.rounded,
                        borderRadius: 18,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _FieldLabel(text: l.commonTitle),
                    const SizedBox(height: 6),
                    _Field(controller: _titleCtrl, enabled: !_saving),
                    const SizedBox(height: 16),

                    _FieldLabel(text: l.commonArtist),
                    const SizedBox(height: 6),
                    _Field(controller: _artistCtrl, enabled: !_saving),
                    const SizedBox(height: 16),

                    _FieldLabel(text: l.commonAlbum),
                    const SizedBox(height: 6),
                    _Field(controller: _albumCtrl, enabled: !_saving),
                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _FieldLabel(text: l.editTagsFieldTrackNumber),
                              const SizedBox(height: 6),
                              _Field(
                                controller: _trackCtrl,
                                enabled: !_saving,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _FieldLabel(text: l.editTagsFieldYear),
                              const SizedBox(height: 6),
                              _Field(
                                controller: _yearCtrl,
                                enabled: !_saving,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _FieldLabel(text: l.editTagsFieldGenres),
                    const SizedBox(height: 6),
                    _Field(
                      controller: _genresCtrl,
                      enabled: !_saving,
                      hint: l.editTagsGenresHint,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==== field label ====
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: SonoFonts.primary,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: c.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ==== field ====
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? hint;

  const _Field({
    required this.controller,
    this.enabled = true,
    this.keyboardType,
    this.inputFormatters,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    {
      final c = context.sono;
      return Container(
        decoration: BoxDecoration(
          color: c.bgContainer,
          borderRadius: BorderRadius.circular(SonoSizes.borderRadius),
          border: Border.all(color: c.borderLight10, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(
            fontFamily: SonoFonts.primary,
            fontSize: 15,
            color: c.textPrimary,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: SonoFonts.primary,
              fontSize: 14,
              color: c.textSecondary.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }
  }
}
