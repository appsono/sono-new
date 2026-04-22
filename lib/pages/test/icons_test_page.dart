import 'package:flutter/material.dart';
import 'package:sono/theme/icons.dart';

class IconsTestPage extends StatelessWidget {
  const IconsTestPage({super.key});

  static const Map<String, String> allIcons = {
    'Bell Outlined': IconsSheet.bellOutlined,
    'Bell Filled': IconsSheet.bellFilled,

    'Heart Outlined': IconsSheet.heartOutlined,
    'Heart Filled': IconsSheet.heartFilled,

    'Home Outlined': IconsSheet.homeOutlined,
    'Home Filled': IconsSheet.homeFilled,

    'Library Outlined': IconsSheet.libraryOutlined,
    'Library Filled': IconsSheet.libraryFilled,

    'Pause Outlined': IconsSheet.pauseOutlined,
    'Pause Filled': IconsSheet.pauseFilled,

    'Play Outlined': IconsSheet.playOutlined,
    'Play Filled': IconsSheet.playFilled,

    'Profile Outlined': IconsSheet.profileOutlined,
    'Profile Filled': IconsSheet.profileFilled,

    'Queue Outlined': IconsSheet.queueOutlined,
    'Queue Filled': IconsSheet.queueFilled,

    'Repeat Outlined': IconsSheet.repeatOutlined,
    'Repeat Filled': IconsSheet.repeatFilled,

    'Search Outlined': IconsSheet.searchOutlined,
    'Search Filled': IconsSheet.searchFilled,

    'Settings Outlined': IconsSheet.settingsOutlined,
    'Settings Filled': IconsSheet.settingsFilled,

    'Shuffle Outlined': IconsSheet.shuffleOutlined,
    'Shuffle Filled': IconsSheet.shuffleFilled,

    'Skip Next Outlined': IconsSheet.skipNextOutlined,
    'Skip Next Filled': IconsSheet.skipNextFilled,

    'Skip Previous Outlined': IconsSheet.skipPreviousOutlined,
    'Skip Previous Filled': IconsSheet.skipPreviousFilled,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: allIcons.length,
        itemBuilder: (context, index) {
          final path = allIcons.values.elementAt(index);

          return Column(
            children: [
              Expanded(
                child: Container(
                  child: IconsSheet.svg(path, size: 24, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
