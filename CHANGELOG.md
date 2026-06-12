# Changelog

## [0.7.2+5](https://github.com/appsono/sono-new/compare/v0.7.1+5...v0.7.2+5) (2026-06-12)

### Fixes

* Fixed severe memory growth when scrolling large libraries: cover tiles kept full-resolution art pinned in memory long after it was evicted from Sono's own caches, which could reach over 1GB on a few thousand songs. Cover tiles now hold only their small decoded image, and the system image cache is freed when the app goes to the background

## [0.7.1+5](https://github.com/appsono/sono-new/compare/v0.7.0+5...v0.7.1+5) (2026-06-12)

### Performance

* Sono now detects low-RAM devices and scales itself down: smaller cover caches, smaller audio buffers, lower thumbnail resolution, and a tighter player carousel on weak hardware
* Cover caches shrink automatically while the app is in the background and release memory when the system asks for it, making background playback much less likely to be killed on low-end devices
* Player colors are now extracted from cover thumbnails instead of full resolution art, cutting peak memory during song changes from up to ~40MB to ~1MB
* Cover scanning, thumbnail decoding, and tag-edit file copies no longer run on the Android main thread (sono_query 0.8.0), removing stutters during scrolling and song changes
* Cover thumbnails now work on devices without MediaStore thumbnails (Android 9 and below, filesystem-scanned libraries) via a memory-bounded native decode
* Good news: Sono now runs on a Samsung Galaxy Tab A6 from 2016 (slow on boot, but it gets there :D)
* On Windows, media overlay artwork goes through the thumbnail cache and timeline updates are pushed far less often

### Fixes

* Fixed a crash when the playback notification appeared on Android 12 and below

### Translation

* [Dan](https://hosted.weblate.org/user/kefir2105/) translated Sono into Ukrainian (100%)

## [0.7.0+5](https://github.com/appsono/sono-new/compare/v0.6.3+4...v0.7.0+5) (2026-06-11)

### Features

* Incremental rescans: files that haven't changed on disk are skipped using mtime+size fingerprints, so startup scans on an unchanged library finish in a fraction of the time
* Tag edits made by other apps are now picked up on normal rescans instead of requiring a force rescan
* Added a disc number field to tag editing

### Performance

* Unified all cover art loads behind a single byte-budgeted in-memory cache. Covers are read from disk once per song instead of up to five times per song change, and the cache can no longer balloon memory on libraries with large embedded art
* The notification, mini player background, and Discord RPC now use downscaled cover thumbnails instead of full resolution art
* Discord RPC remembers recently uploaded covers, so listening through an album no longer re-uploads the same image on every track
* Home page now loads with a fixed number of database queries instead of one per artist
* Library lists sort in SQL and use fixed-extent rendering for smoother scrolling on large libraries
* Cover tag parsing moved off the UI thread and concurrent loads are capped, fixing stutter while scrolling through long song and album lists
* Playback position updates are throttled to 4 per second across the UI, and the hidden lyrics view no longer does per-tick work behind the player
* The playback queue is only written to the database when it actually changes, and the resume position is persisted every 30 seconds instead of every 5
* The spinning cover and marquee pause when the app is in the background
* Non-critical services (Discord RPC, EQ restore, desktop media controls) now initialize after the first frame for a faster cold start
* Carousel and scan progress no longer trigger unnecessary rebuilds

### Fixes

* Fixed the startup scan freezing partway through when songs deleted from disk were still referenced by playlists or cached lyrics. Databases migrated up from older versions now get proper ON DELETE CASCADE on those tables
* Fixed songs not loading for some libraries
* Stopped the tag editor from writing empty genre fields

### Translation

* [Sasha Glazko](https://hosted.weblate.org/user/lenify/) translated Sono into Belarusian (100%) and Belarusian (be_TARASK) (100%)
* [Priit Jõerüüt](https://hosted.weblate.org/user/jrthwlate/) translated Sono into Estonian (100%)
* [Zartiny](https://hosted.weblate.org/user/Zartiny/) translated Sono into French (100%)
* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (100%)

## [0.6.3+4](https://github.com/appsono/sono-new/compare/v0.6.2+4...v0.6.3+4) (2026-06-08)

### Features

* Added tag editing for songs from the info tab of the song sheet, supporting title, artist, album, track number, year, and genres. Edit button shows on the song sheet from the library, the player, and the queue
* On Android, the system prompts for permission per file before writing tags

### Fixes

* Centralized album display-name choice in the database layer

### Translation

* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (100%)
* [Priit Jõerüüt](https://hosted.weblate.org/user/jrthwlate/) translated Sono into Estonian (94%)
* [Ado Listener](https://hosted.weblate.org/user/Ado_Listener/) started translating Sono into Kazakh (1%)

## [0.6.2+4](https://github.com/appsono/sono-new/compare/v0.6.1+4...v0.6.2+4) (2026-06-07)

### Features

* Added album detail page and artist detail pages
* Added genre pages and linked genres from the library
* Added indicators on artist pages
* Added album type inference and labels for albums, EPs, singles, compilations, and collaborations
* Added stacked cover artwork for collection cards
* Wired Home page sections, artist rows, song sheets, queue sheets, and player sheets to the new detail pages

### Fixes

* Fixed artist pages showing stale album favorite state after returning from an album page
* Fixed in-place regrouping so song rows are preserved when grouping settings change
* Fixed a library sheet key issue
* Removed lyrics debug logging

### Translation

* Added Kazakh to the language list
* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (100%)

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
