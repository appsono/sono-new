# Changelog

## [0.4.9+2](https://github.com/appsono/sono-new/compare/v0.4.8+2...v0.4.9+2) (2026-05-22)

### Features

* Added 4 new languages (Belarusian, Belarusian (be_TARASK), French, Polish)
* Added two button at the bottom of Settings (Contributors, Support Me)
* Added Contributors Modal (Code Commits [github], Translations [manual])
* Added a translation progress indicator to language picker

### Fixes

* Remove unnecessary string interpolation in offset formatting (lib/pages/player/player_lyrics_view.dart)
* Moved language picker under Text so both have full width

### Translation

* [Sasha Galzko](https://hosted.weblate.org/user/lenify/) translated Sono into Belarusian (89%) and Belarusian (be_TARASK) (89%)
* [Zartiny](https://hosted.weblate.org/user/Zartiny/) translated Sono into French (89%)
* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (89%)
* [prlz](https://hosted.weblate.org/user/prlz/) translated Sono into Polish (89%)

## [0.4.8+2](https://github.com/appsono/sono-new/compare/v0.3.6+1...v0.4.8+2) (2026-05-20)

### Features

* Multi-language support: The app now provides full UI localization in English and German
* Language selector: New language preference option in Settings to choose your preferred language or follow system default

### Chores

* Updated dependencies to support localization infrastructure

## [0.4.0+1](https://github.com/appsono/sono-new/compare/v0.3.6+1...v0.4.0+1) (2026-05-03)

### Features

* **player:** add color extraction from song cover ([4b11cb5](https://github.com/appsono/sono-new/commit/4b11cb546de2a632bc02acf8209dd6e072de7eda))
* **player:** WIP Fullscreen Player that shows extracted cover colors ([77cdaa2](https://github.com/appsono/sono-new/commit/77cdaa254deb8e3c28445727270411f0c3e37f6d))

### Bug Fixes

* **ci:** only upload artifacts when a release is actually created ([0afa6eb](https://github.com/appsono/sono-new/commit/0afa6eb806e3a9846f25cba6453ea3f449297f03))
