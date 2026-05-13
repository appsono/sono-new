import 'package:flutter/material.dart';

/// ===========================
///        Marquee Text
/// ===========================

class SonoMarqueeText extends StatefulWidget {
  final String title;
  final TextStyle titleStyle;
  final String subtitle;
  final TextStyle subtitleStyle;
  final double gap;
  final Duration startDelay;
  final double pixelsPerSecond;

  const SonoMarqueeText({
    required this.title,
    required this.titleStyle,
    required this.subtitle,
    required this.subtitleStyle,
    this.gap = 60, // ignore: unused_element_parameter
    this.startDelay = const Duration(milliseconds: 1500),
    this.pixelsPerSecond = 40,
    super.key,
  });

  @override
  State<SonoMarqueeText> createState() => _SonoMarqueeTextState();
}

class _SonoMarqueeTextState extends State<SonoMarqueeText>
    with TickerProviderStateMixin {
  AnimationController? _anim;
  double _containerWidth = 0;
  double _titleWidth = 0;
  double _subtitleWidth = 0;
  double _scrollDistance = 0;
  bool _needsScroll = false;
  bool _measured = false;

  final _titleKey = GlobalKey();
  final _subtitleKey = GlobalKey();

  @override
  void didUpdateWidget(SonoMarqueeText old) {
    super.didUpdateWidget(old);
    if (old.title != widget.title || old.subtitle != widget.subtitle) {
      _anim?.dispose();
      _anim = null;
      _needsScroll = false;
      _measured = false;
      setState(() {});
    }
  }

  double _measureText(String text, TextStyle style, BuildContext context) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return tp.width;
  }

  void _onLayout(double width, BuildContext context) {
    if (_measured && _containerWidth == width) return;
    _containerWidth = width;
    _measured = true;

    _titleWidth = _measureText(widget.title, widget.titleStyle, context);
    _subtitleWidth = _measureText(
      widget.subtitle,
      widget.subtitleStyle,
      context,
    );

    final longestWidth = _titleWidth > _subtitleWidth
        ? _titleWidth
        : _subtitleWidth;

    _needsScroll = longestWidth > width;

    _anim?.dispose();
    _anim = null;

    if (_needsScroll) {
      _scrollDistance = longestWidth + widget.gap + 2;
      final scrollMs = (_scrollDistance / widget.pixelsPerSecond * 1000)
          .round();

      _anim = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: scrollMs),
      );

      _runLoop(_anim!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _remeasureActual();
      setState(() {});
    });
  }

  void _remeasureActual() {
    bool changed = false;

    final titleBox = _titleKey.currentContext?.findRenderObject() as RenderBox?;
    if (titleBox != null && titleBox.hasSize) {
      final w = titleBox.size.width;
      if ((w - _titleWidth).abs() > 0.1) {
        _titleWidth = w;
        changed = true;
      }
    }

    final subtitleBox =
        _subtitleKey.currentContext?.findRenderObject() as RenderBox?;
    if (subtitleBox != null && subtitleBox.hasSize) {
      final w = subtitleBox.size.width;
      if ((w - _subtitleWidth).abs() > 0.1) {
        _subtitleWidth = w;
        changed = true;
      }
    }

    if (!changed || !_needsScroll) return;

    final longest = _titleWidth > _subtitleWidth ? _titleWidth : _subtitleWidth;
    _scrollDistance = longest + widget.gap + 2;
    final scrollMs = (_scrollDistance / widget.pixelsPerSecond * 1000).round();
    _anim?.duration = Duration(milliseconds: scrollMs);
  }

  Future<void> _runLoop(AnimationController controller) async {
    await Future.delayed(widget.startDelay);
    while (mounted && _anim == controller) {
      try {
        await controller.forward(from: 0.0).orCancel;
      } on TickerCanceled {
        return;
      }
      if (!mounted || _anim != controller) return;
      await Future.delayed(widget.startDelay);
      if (!mounted || _anim != controller) return;
      controller.value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleHeight = widget.titleStyle.fontSize! * 1.4;
    final subtitleHeight = widget.subtitleStyle.fontSize! * 1.4;

    return SizedBox(
      height: titleHeight + subtitleHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _onLayout(constraints.maxWidth, context);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLine(
                text: widget.title,
                style: widget.titleStyle,
                height: titleHeight,
                textWidth: _titleWidth,
                scrollKey: _titleKey,
              ),
              _buildLine(
                text: widget.subtitle,
                style: widget.subtitleStyle,
                height: subtitleHeight,
                textWidth: _subtitleWidth,
                scrollKey: _subtitleKey,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLine({
    required String text,
    required TextStyle style,
    required double height,
    required double textWidth,
    GlobalKey? scrollKey,
  }) {
    final overflows = textWidth > _containerWidth;

    if (!overflows || _anim == null) {
      return SizedBox(
        height: height,
        child: Text(
          text,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    final effectiveGap = (_scrollDistance - textWidth).clamp(
      widget.gap,
      double.infinity,
    );

    return SizedBox(
      width: _containerWidth,
      height: height,
      child: ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0.08, 0.75, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: AnimatedBuilder(
          animation: _anim!,
          builder: (_, _) {
            final offset = _anim!.value * _scrollDistance;

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: -offset,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        text,
                        key: scrollKey,
                        style: style,
                        maxLines: 1,
                        softWrap: false,
                      ),
                      SizedBox(width: effectiveGap),
                      Text(text, style: style, maxLines: 1, softWrap: false),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _anim?.dispose();
    super.dispose();
  }
}
