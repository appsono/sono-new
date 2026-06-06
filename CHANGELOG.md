# Changelog

## [0.6.1+4](https://github.com/appsono/sono-new/compare/v0.6.0+4...v0.6.1+4) (2026-06-06)

### Fixes

* Fixed manual rescans (via the rescan button in settings) wiping song likes and emptying playlists. Songs now stay in the database during a regroup and only their album link is recalculated.
* Database now enforces its own relationships: deleting a song automatically cleans up playlist entries and cached lyrics. Dangling rows left by the previous bug are cleaned up on first launch.

### Translation

* [Priit Jõerüüt](https://hosted.weblate.org/user/jrthwlate/) translated Sono into Estonian (100%)

## [0.6.0+4](https://github.com/appsono/sono-new/compare/v0.5.3+3...v0.6.0+3) (2026-06-06)

### Features

* Added the Library tab with subpages for Songs, Albums, Artists, Liked Songs, Favorite Albums, and Favorite Artists
* Added Playlists: create, rename, delete, reorder songs, add to playlist from any song sheet, remove from playlist
* Added playlist detail page with full-width cover, scroll-driven header, and reorder mode
* Added playlist mosaic cover (2x2 from the first 4 songs) for playlists without a custom cover
* Added folder-based album grouping as a settings toggle
* Added desktop OS media controls (Linux MPRIS, Windows SMTC)
* Added text field rows, keyboard-aware padding, and destructive and prominent action styles to the bottom modal sheet
* Sticky page header now only reveals its background when content scrolls underneath

### Fixes

* Fixed lyrics search using the folder path instead of the album's display title when folder-based album grouping is enabled
* Fixed snackbars staying on screen forever instead of auto-dismissing
* Fixed long playlist names wrapping to two lines in the page header
* Fixed playlist 2x2 cover overflowing by a couple of pixels
* Fixed a race between the song sheet closing and the add-to-playlist picker opening that could trigger a willPop assertion
* Fixed Discord RPC and secure storage erroring out on Linux
* Reduced mini player height from 90 to 70 px

### Translation

* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (100%)
* [Priit Jõerüüt](https://hosted.weblate.org/user/jrthwlate/) translated Sono into Estonian (83%)
* [Dan](https://hosted.weblate.org/user/kefir2105/) translated Sono into Ukrainian (80%)

## [0.5.3+3](https://github.com/appsono/sono-new/compare/v0.5.2+2...v0.5.3+3) (2026-05-26)

### Features

* Added new playlist and genre icons
* Re-design favorite album icon pair

### Fixes

* Fixed audio stutter when the app was backgrounded with EQ enabled (the filter chain now skips bands at unity gain instead of running all 11 biquads every sample)
* Fixed "Got to album" action in the queue song sheet using the artist icon
* Fixed lyrics view not jumping to the current line when opening

### Translation

* [Sasha Glazko](https://hosted.weblate.org/user/lenify) translated Sono into Belarusian (be_TARASK) (100%)

## [0.5.2+3](https://github.com/appsono/sono-new/compare/v0.5.1+2...v0.5.2+3) (2026-05-26)

### Features

* Added new album, artist, favorite album (no filled), favorite artist, last played, and song icons
* Updated pages to use the new icons
* All icons now use `currentColor` instead of hard-coded black value (i missed a few)

### Fixes

* Fixed lyrics view not resetting to the top when changing songs
* Fixed lyrics bottom right radius using the wrong border radius value

## [0.5.1+3](https://github.com/appsono/sono-new/compare/v0.5.0+2...v0.5.1+3) (2026-05-25)

### Features

* Lyrics lines are now tappable and seek to that part of the song
* Lyrics auto-scroll only follows the active line when it's already in view
* Lyrics provider credit moved to the end of the scroll area instead of being pinned

### Fixes

* Fixed missing translation percentage for Belarusian (be_TARASK) in the language picker

### Translation

* [Sasha Glazko](https://hosted.weblate.org/user/lenify) translated Sono into Belarusian (100%) and Belarusian (be_TARASK) (84%)
* [Priit Jõerüüt](https://hosted.weblate.org/user/jrthwlate/) translated Sono into Estonian (100%)
* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (100%)
* [Dan](https://hosted.weblate.org/user/kefir2105/) translated Sono into Ukrainian (100%)

## [0.5.0+3](https://github.com/appsono/sono-new/compare/v0.4.91+2...v0.5.0+3) (2026-05-24)

### Features

* Added Song Sheet widget
* Added Song sharing support
* Added new common/shared localization strings

### Fixes

* Fixed liked state not syncing across lyrics and queue views
* Fixed spinning cover jumping when looping
* Fixed bottom navigation label clipping with long translations
* Fixed icon alignment issues (home_outlined & home_filled)
* Replaces three dots with proper ellipses

### Docs

* Updated contribution documentation with new folder structure
* Added communities section and updated Discord link

### Translation

* [Sasha Glazko](https://hosted.weblate.org/user/lenify) translated Sono into Belarusian (78%) and Belarusian (be_TARASK) (78%)
* [Priit Jõerüüt](https://hosted.weblate.org/user/jrthwlate/) translated Sono into Estonian (78%)
* [Zartiny](https://hosted.weblate.org/user/Zartiny/) translated Sono into French (78%)
* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (78%)
* [Dan](https://hosted.weblate.org/user/kefir2105/) translated Sono into Ukrainian (78%)

## [0.4.91+2](https://github.com/appsono/sono-new/compare/v0.4.9+2...v0.4.91+2) (2026-05-22)

### Translation

* [Sasha Glazko](https://hosted.weblate.org/user/lenify/) translated Sono into Belarusian (100%) and Belarusian (be_TARASK) (100%)
* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (100%)
* [Dan](https://hosted.weblate.org/user/kefir2105/) translated Sono into Ukrainian (100%)

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

* [Sasha Glazko](https://hosted.weblate.org/user/lenify/) translated Sono into Belarusian (89%) and Belarusian (be_TARASK) (89%)
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
