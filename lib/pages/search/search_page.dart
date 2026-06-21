import 'package:flutter/material.dart';

import 'package:sono/l10n/localizations.dart';

import 'package:sono/db/database.dart';
import 'package:sono/theme/icons.dart';
import 'package:sono/theme/theme.dart';
import 'package:sono/theme/tokens.dart';
import 'package:sono/widgets/header.dart';
import 'package:sono/widgets/changelog_sheet.dart';

const double _bottomInset = SonoSizes.playerHeight + 22 + 16;

class SearchPage extends StatefulWidget {
  final SonoDatabase db;
  final VoidCallback? onOpenSettings;
  const SearchPage({required this.db, this.onOpenSettings, super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    //TODO:debounced search wired when implemented
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.trim().isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ==== header ====
          StreamBuilder<Profile?>(
            stream: widget.db.watchProfile(),
            builder: (context, snap) {
              final l = AppLocalizations.of(context);
              final profile = snap.data;
              return SonoStickyHeader(
                child: SonoHeader(
                  pageTitle: l.searchPageTitle,
                  avatar: profile?.avatar,
                  onProfileTap: () {
                    //will open sidebar later
                  },
                  actions: [
                    SonoHeaderAction(
                      icon: IconsSheet.bellOutlined,
                      tooltip: l.homeHeaderNewsAndUpdates,
                      onTap: () => ChangelogSheet.show(context),
                    ),
                    SonoHeaderAction(
                      icon: IconsSheet.settingsOutlined,
                      tooltip: l.homeHeaderSettings,
                      onTap: () => widget.onOpenSettings?.call(),
                    ),
                  ],
                ),
              );
            },
          ),

          //sticky header search, so sticky :P
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: _SearchField(
                controller: _controller,
                focusNode: _focus,
                showClear: hasQuery,
                onChanged: _onChanged,
                onClear: _clear,
              ),
            ),
          ),

          // ==== bottom clearance ====
          SliverToBoxAdapter(child: SizedBox(height: _bottomInset)),
        ],
      ),
    );
  }
}

/// ==== Pill search field ====
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showClear;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.showClear,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    final l = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        return Container(
          height: 54,
          decoration: BoxDecoration(
            color: c.bgContainer,
            borderRadius: BorderRadius.circular(27),
            border: Border.all(
              color: focused ? c.primary : c.borderLight10,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              IconsSheet.svg(
                IconsSheet.searchOutlined,
                size: 22,
                color: c.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  cursorColor: c.primary,
                  style: TextStyle(
                    fontFamily: SonoFonts.primary,
                    fontSize: 15,
                    color: c.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: l.searchFieldHint,
                    hintStyle: TextStyle(
                      fontFamily: SonoFonts.primary,
                      fontSize: 15,
                      color: c.textPlaceholder,
                    ),
                  ),
                ),
              ),
              if (showClear) ...[
                const SizedBox(width: 8),
                _ClearButton(onTap: onClear),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sono;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: c.bgSurface, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: IconsSheet.svg(
          IconsSheet.closeOutlined,
          size: 14,
          color: c.textSecondary,
        ),
      ),
    );
  }
}
