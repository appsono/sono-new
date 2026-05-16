import 'package:flutter/material.dart';

// ==== bouncy press wrapper ====
//
// Scales child to pressScale on tap down, springs back via elasticOut
// on release. Same feel as SonoMediaCard mweh
class BouncyTap extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final double pressScale;

  const BouncyTap({
    required this.onTap,
    required this.child,
    this.pressScale = 0.92, // ignore: unused_element_parameter
    super.key,
  });

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) setState(() => _pressed = false);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressScale : 1.0,
        duration: _pressed
            ? const Duration(milliseconds: 100)
            : const Duration(milliseconds: 700),
        curve: _pressed ? Curves.easeIn : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}
