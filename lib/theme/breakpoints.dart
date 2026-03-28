import 'package:flutter/material.dart';

enum SonoLayout { mobile, tablet, desktop }

SonoLayout layoutOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1200) return SonoLayout.desktop;
  if (width >= 600) return SonoLayout.tablet;
  return SonoLayout.mobile;
}
