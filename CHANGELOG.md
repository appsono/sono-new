# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

* Fixed Discord RPC showing as disconnected when reopening settings before the saved login finished loading
* Fixed "go to artist" doing nothing on the queue, player, and playlist song sheets for songs played from a playlist

### Changed

* Capped the Skia GPU resource cache by device memory tier (32 MB on low-RAM devices, 64 MB otherwise)
* Playlists can now have their description edited alongside their name (the rename action is now a full edit action)

## [0.7.2+5] - 2026-06-12

### Fixed

* Fixed severe memory growth when scrolling large libraries: cover tiles kept full-resolution art pinned in memory long after it was evicted from Sono's own caches, which could reach over 1GB on a few thousand songs. Cover tiles now hold only their small decoded image, and the system image cache is freed when the app goes to the background

## [0.7.1+5] - 2026-06-12

### Changed

* Sono now detects low-RAM devices and scales itself down: smaller cover caches, smaller audio buffers, lower thumbnail resolution, and a tighter player carousel on weak hardware
* Cover caches shrink automatically while the app is in the background and release memory when the system asks for it, making background playback much less likely to be killed on low-end devices
* Player colors are now extracted from cover thumbnails instead of full resolution art, cutting peak memory during song changes from up to ~40MB to ~1MB
* Cover scanning, thumbnail decoding, and tag-edit file copies no longer run on the Android main thread (sono_query 0.8.0), removing stutters during scrolling and song changes
* Cover thumbnails now work on devices without MediaStore thumbnails (Android 9 and below, filesystem-scanned libraries) via a memory-bounded native decode
* Good news: Sono now runs on a Samsung Galaxy Tab A6 from 2016 (slow on boot, but it gets there :D)
* On Windows, media overlay artwork goes through the thumbnail cache and timeline updates are pushed far less often

### Fixed

* Fixed a crash when the playback notification appeared on Android 12 and below

### Translation

* [Dan](https://hosted.weblate.org/user/kefir2105/) translated Sono into Ukrainian (100%)

## [0.7.0+5] - 2026-06-11

### Added

* Incremental rescans: files that haven't changed on disk are skipped using mtime+size fingerprints, so startup scans on an unchanged library finish in a fraction of the time
* Added a disc number field to tag editing

### Changed

* Tag edits made by other apps are now picked up on normal rescans instead of requiring a force rescan
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

### Fixed

* Fixed the startup scan freezing partway through when songs deleted from disk were still referenced by playlists or cached lyrics. Databases migrated up from older versions now get proper ON DELETE CASCADE on those tables
* Fixed songs not loading for some libraries
* Stopped the tag editor from writing empty genre fields

### Translation

* [Sasha Glazko](https://hosted.weblate.org/user/lenify/) translated Sono into Belarusian (100%) and Belarusian (be_TARASK) (100%)
* [Priit Jõerüüt](https://hosted.weblate.org/user/jrthwlate/) translated Sono into Estonian (100%)
* [Zartiny](https://hosted.weblate.org/user/Zartiny/) translated Sono into French (100%)
* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (100%)

## [0.6.3+4] - 2026-06-08

### Added

* Added tag editing for songs from the info tab of the song sheet, supporting title, artist, album, track number, year, and genres. Edit button shows on the song sheet from the library, the player, and the queue
* On Android, the system prompts for permission per file before writing tags

### Changed

* Centralized album display-name choice in the database layer

### Translation

* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (100%)
* [Priit Jõerüüt](https://hosted.weblate.org/user/jrthwlate/) translated Sono into Estonian (94%)
* [Ado Listener](https://hosted.weblate.org/user/Ado_Listener/) started translating Sono into Kazakh (1%)

## [0.6.2+4] - 2026-06-07

### Added

* Added album detail page and artist detail pages
* Added genre pages and linked genres from the library
* Added indicators on artist pages
* Added album type inference and labels for albums, EPs, singles, compilations, and collaborations
* Added stacked cover artwork for collection cards
* Wired Home page sections, artist rows, song sheets, queue sheets, and player sheets to the new detail pages
* Added Kazakh to the language list

### Removed

* Removed lyrics debug logging

### Fixed

* Fixed artist pages showing stale album favorite state after returning from an album page
* Fixed in-place regrouping so song rows are preserved when grouping settings change
* Fixed a library sheet key issue

### Translation

* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (100%)

## [0.6.1+4] - 2026-06-06

### Fixed

* Fixed manual rescans (via the rescan button in settings) wiping song likes and emptying playlists. Songs now stay in the database during a regroup and only their album link is recalculated.
* Database now enforces its own relationships: deleting a song automatically cleans up playlist entries and cached lyrics. Dangling rows left by the previous bug are cleaned up on first launch.

### Translation

* [Priit Jõerüüt](https://hosted.weblate.org/user/jrthwlate/) translated Sono into Estonian (100%)

## [0.6.0+4] - 2026-06-06

### Added

* Added the Library tab with subpages for Songs, Albums, Artists, Liked Songs, Favorite Albums, and Favorite Artists
* Added Playlists: create, rename, delete, reorder songs, add to playlist from any song sheet, remove from playlist
* Added playlist detail page with full-width cover, scroll-driven header, and reorder mode
* Added playlist mosaic cover (2x2 from the first 4 songs) for playlists without a custom cover
* Added folder-based album grouping as a settings toggle
* Added desktop OS media controls (Linux MPRIS, Windows SMTC)
* Added text field rows, keyboard-aware padding, and destructive and prominent action styles to the bottom modal sheet

### Changed

* Sticky page header now only reveals its background when content scrolls underneath
* Reduced mini player height from 90 to 70 px

### Fixed

* Fixed lyrics search using the folder path instead of the album's display title when folder-based album grouping is enabled
* Fixed snackbars staying on screen forever instead of auto-dismissing
* Fixed long playlist names wrapping to two lines in the page header
* Fixed playlist 2x2 cover overflowing by a couple of pixels
* Fixed a race between the song sheet closing and the add-to-playlist picker opening that could trigger a willPop assertion
* Fixed Discord RPC and secure storage erroring out on Linux

### Translation

* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (100%)
* [Priit Jõerüüt](https://hosted.weblate.org/user/jrthwlate/) translated Sono into Estonian (83%)
* [Dan](https://hosted.weblate.org/user/kefir2105/) translated Sono into Ukrainian (80%)

## [0.5.3+3] - 2026-05-26

### Added

* Added new playlist and genre icons

### Changed

* Re-designed favorite album icon pair

### Fixed

* Fixed audio stutter when the app was backgrounded with EQ enabled (the filter chain now skips bands at unity gain instead of running all 11 biquads every sample)
* Fixed "Go to album" action in the queue song sheet using the artist icon
* Fixed lyrics view not jumping to the current line when opening

### Translation

* [Sasha Glazko](https://hosted.weblate.org/user/lenify) translated Sono into Belarusian (be_TARASK) (100%)

## [0.5.2+3] - 2026-05-26

### Added

* Added new album, artist, favorite album (not filled), favorite artist, last played, and song icons

### Changed

* Updated pages to use the new icons
* All icons now use `currentColor` instead of a hard-coded black value

### Fixed

* Fixed lyrics view not resetting to the top when changing songs
* Fixed lyrics bottom right radius using the wrong border radius value

## [0.5.1+3] - 2026-05-25

### Added

* Lyrics lines are now tappable and seek to that part of the song

### Changed

* Lyrics auto-scroll only follows the active line when it's already in view
* Lyrics provider credit moved to the end of the scroll area instead of being pinned

### Fixed

* Fixed missing translation percentage for Belarusian (be_TARASK) in the language picker

### Translation

* [Sasha Glazko](https://hosted.weblate.org/user/lenify) translated Sono into Belarusian (100%) and Belarusian (be_TARASK) (84%)
* [Priit Jõerüüt](https://hosted.weblate.org/user/jrthwlate/) translated Sono into Estonian (100%)
* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (100%)
* [Dan](https://hosted.weblate.org/user/kefir2105/) translated Sono into Ukrainian (100%)

## [0.5.0+3] - 2026-05-24

### Added

* Added Song Sheet widget
* Added song sharing support
* Added new common/shared localization strings

### Changed

* Replaced three dots with proper ellipses
* Updated contribution documentation with new folder structure
* Added communities section and updated Discord link

### Fixed

* Fixed liked state not syncing across lyrics and queue views
* Fixed spinning cover jumping when looping
* Fixed bottom navigation label clipping with long translations
* Fixed icon alignment issues (home_outlined and home_filled)

### Translation

* [Sasha Glazko](https://hosted.weblate.org/user/lenify) translated Sono into Belarusian (78%) and Belarusian (be_TARASK) (78%)
* [Priit Jõerüüt](https://hosted.weblate.org/user/jrthwlate/) translated Sono into Estonian (78%)
* [Zartiny](https://hosted.weblate.org/user/Zartiny/) translated Sono into French (78%)
* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (78%)
* [Dan](https://hosted.weblate.org/user/kefir2105/) translated Sono into Ukrainian (78%)

## [0.4.91+2] - 2026-05-22

### Translation

* [Sasha Glazko](https://hosted.weblate.org/user/lenify/) translated Sono into Belarusian (100%) and Belarusian (be_TARASK) (100%)
* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (100%)
* [Dan](https://hosted.weblate.org/user/kefir2105/) translated Sono into Ukrainian (100%)

## [0.4.9+2] - 2026-05-22

### Added

* Added 4 new languages (Belarusian, Belarusian (be_TARASK), French, Polish)
* Added two buttons at the bottom of Settings (Contributors, Support Me)
* Added Contributors modal (code commits from GitHub, translations maintained manually)
* Added a translation progress indicator to the language picker

### Changed

* Removed unnecessary string interpolation in offset formatting
* Moved the language picker under its label so both have full width

### Translation

* [Sasha Glazko](https://hosted.weblate.org/user/lenify/) translated Sono into Belarusian (89%) and Belarusian (be_TARASK) (89%)
* [Zartiny](https://hosted.weblate.org/user/Zartiny/) translated Sono into French (89%)
* [mathis](https://hosted.weblate.org/user/mathiiiiiis/) translated Sono into German (89%)
* [prlz](https://hosted.weblate.org/user/prlz/) translated Sono into Polish (89%)

## [0.4.8+2] - 2026-05-20

### Added

* Multi-language support: the app now provides full UI localization in English and German
* Language selector: new language preference option in Settings to choose your preferred language or follow the system default

### Changed

* Updated dependencies to support localization infrastructure

### Fixed

* Inverted the lyrics sync offset sign

## [0.4.7+2] - 2026-05-18

### Added

* Discord cover uploads now use uguu (primary) with a litterbox fallback instead of tmpfiles

### Changed

* Dropped the Discord cover cache TTL to 1 hour
* Updated the privacy policy for lyrics and the new upload hosts

### Fixed

* Fixed the lyrics view toggling repeat-all instead of repeat-one

## [0.4.6+2] - 2026-05-18

### Added

* Added bottom controls to the lyrics view
* Added a global bottom modal sheet

## [0.4.5+2] - 2026-05-17

### Added

* Added an idle progress bar to the lyrics view

### Changed

* Improved the lyrics idle state behavior

### Fixed

* Animate the idle bar transition and absorb blank LRC gaps
* Fixed lyrics not preloading correctly
* Bumped the lyrics service timeout

## [0.4.5+1] - 2026-05-17

### Added

* Added the lyrics view with synced lines, a page header, and a version switcher
* Added lyrics preloading and caching (new LyricsCache table, schema v9)
* Added a lyrics service backed by lrclib
* Added a queue button row (skip, loop, playlist, pause/play) and a scroll-to-current button
* Made BouncyTap and the header card global widgets, with an optional border radius on widgets

### Changed

* Queue auto-scrolls to the new song

### Fixed

* Fixed wrong lyrics showing for a song
* The currently playing song can no longer be moved in the queue
* The queue now closes when dragged from the top
* Marquee text re-animates whenever it overflows

## [0.4.4+1] - 2026-05-15

### Added

* Added a work-in-progress queue view
* Added a global cover cache (CoverCache)
* Added a drag handle icon

### Changed

* Cover art performance improvements and smoother scrolling

## [0.4.3+1] - 2026-05-14

### Added

* Added queue reordering
* Added secondary player controls
* Added tooltips for accessibility

### Fixed

* Fixed "All Song" label typo to "All Songs"

## [0.4.2+1] - 2026-05-13

### Added

* Added player controls with bouncy animations
* Added a progress bar to the player
* Added a player title row (title, artist, like button)
* Added a liked column to the songs table
* Extracted marquee text into a standalone widget

### Changed

* Mini player now uses the shared marquee text widget

## [0.4.1+1] - 2026-05-12

### Added

* Added a cover carousel and top bar to the fullscreen player
* Added queue origin for the fullscreen player

### Changed

* Cover art now supports external bytes and optional async loading

### Fixed

* Fixed a queue issue

## [0.4.0+1] - 2026-05-11

### Added

* Added an optional thin border on media card covers

### Changed

* Header overlays the avatar border when an image is set

### Fixed

* Use the correct setting key for theme and a light border in both themes

## [0.3.93+1] - 2026-05-11

### Added

* Persist theme mode in the database

## [0.3.91+1] - 2026-05-10

### Added

* Added a profile section in Settings for username and avatar

### Changed

* Home watches profile changes via a Drift stream

### Fixed

* Added bottom clearance so the player no longer overlaps content

## [0.3.9+1] - 2026-05-10

### Added

* Added a playback section in Settings
* Added a privacy policy

## [0.3.8+3] - 2026-05-07

### Changed

* Release workflow adjustments

## [0.3.8+2] - 2026-05-06

### Added

* Added dev and prod build flavors on Android
* Cache extracted color palettes

### Changed

* Moved color extraction off the main isolate

### Fixed

* Reset the palette to fallback when a song has no cover
* Dedupe in-flight color extractions
* Handle rapid song changes during color extraction

## [0.3.7+1] - 2026-05-04

### Added

* Added color extraction from song covers
* Added a work-in-progress fullscreen player that shows extracted cover colors

### Fixed

* CI now only uploads artifacts when a release is actually created

## [0.3.6+1] - 2026-05-02

### Added

* Added CONTRIBUTING.md, issue templates, and a PR template
* Added FUNDING.yml

### Changed

* Battery and memory optimizations

## [0.3.5+1] - 2026-04-30

### Added

* Added gapless playback

## [0.3.4+1] - 2026-04-28

### Added

* Save and restore the last playing queue and position on restart

### Fixed

* The recently added section now plays in the correct order

## [0.3.3+1] - 2026-04-26

### Added

* Added a work-in-progress home page

### Fixed

* Fixed track number always being NULL

## [0.3.2+2] - 2026-04-25

### Changed

* Switched the cover cache to a 3-slot LRU and capped the external image cache with LRU eviction
* Settings writes now use transactions

### Fixed

* Persist the discord.enabled setting
* Fixed the Discord token never refreshing and storage inconsistencies
* Fixed audio not playing on Windows
* Fixed the player luminance formula
* Moved the database out of the cache directory
* Fixed overlapping greeting hours
* Fixed a stale interruption flag causing unwanted resume

## [0.3.2+1] - 2026-04-24

### Added

* Added 18 new icons

### Changed

* Icons now use `currentColor` instead of black
* Aligned the header profile icon and updated fallback phrases

## [0.3.1+1] - 2026-04-22

### Added

* Added IconsSheet with all custom SVG icons (bell, heart, pause, play, profile, queue, repeat, settings, shuffle, skip)
* Added SonoHeader with a time-based greeting, profile circle, and action pill
* Added a local account table

### Changed

* Migrated icons to IconsSheet and reorganized audio and scanner services into subdirectories

## [0.3.0+2] - 2026-04-21

### Added

* Added an iOS folder notice in Settings

### Fixed

* Hide the additional paths section on non-desktop devices

## [0.3.0+1] - 2026-04-21

### Added

* Added an update checker

## [0.2.9+1] - 2026-04-20

### Changed

* Migrated Discord tokens from the database to secure storage

### Fixed

* Sync buffering state and seek position to the media notification
* Discord now deletes all data before a fresh login
* Force-rescan clears songs explicitly
* Clean up stale temp cover art
* Let the media session resolve the new URI before the old file is deleted
* Fixed a missing comma in the EQ filter string

## [0.2.8+3] - 2026-04-17

### Added

* Added an iOS build to the release workflow with background audio mode and file sharing for music import

### Fixed

* Removed the iOS permission check and created the readme in the documents directory

## [0.2.8+2] - 2026-04-16

### Fixed

* Custom icons are no longer deleted during builds

## [0.2.8+1] - 2026-04-16

### Added

* Added a README with logo and project details

### Changed

* Linux build uses find_library for mimalloc instead of pkg-config

### Fixed

* Discord fully cleans up state on disconnect
* Discord shows a disabled state instead of "not connected" when toggled off
* Added the INTERNET permission to the Android manifest

## [0.2.7+1] - 2026-04-09

### Added

* Added Discord Rich Presence integration
* Added shuffle and repeat controls to the notification

### Changed

* Throttle notification position updates to every 5 seconds

### Fixed

* Show featured artists for songs
* Reload the song list on rescan

## [0.2.6+1] - 2026-04-07

### Added

* Added a settings page
* Added scan config loading with a progress bar during scans
* Added a ScanSettings service for persisting scan config
* Added main-artist detection from parsed artists

### Fixed

* Preserve cover rotation angle across pause and resume
* Force a rescan on change

## [0.2.5+1] - 2026-04-03

### Fixed

* Fixed a marquee loop seam caused by TextPainter width underestimation
* Fixed the mini player inner clip radius
* Reduced box shadow intensity in light mode
* Fixed the overlay being too dark in light mode
* Section arrow button colors now swap based on theme brightness

## [0.2.2+1] - 2026-03-31

### Added

* Added light mode support
* Added an early mini player
* Added bottom navigation and an app shell to control navigation
* Added nav icons with variants

## [0.2.1+1] - 2026-03-29

### Added

* Added widgets for cover art, media cards, and sections
* Added Poppins as the primary font and a primary color

### Fixed

* Fixed playAt ignoring shuffle order
* Fixed the notification showing stale song info when removing songs quickly
* Fixed queue add/remove re-shuffling the entire upcoming order

## [0.2.0+2] - 2026-03-27

### Added

* Added ProGuard keep rules for media_kit and audio_service

### Fixed

* Fixed the notification showing the previous song's cover art on song change
* Fixed a release-build crash on song switch and a stripped notification icon
* Fixed the wrong song playing when starting playback with shuffle enabled
* Fixed RepeatMode not persisting across restarts

## [0.1.9+3] - 2026-03-16

### Added

* First tracked build with a playback queue, metadata sheet, and playback controls
* Persist shuffle and repeat mode across restarts
* Persist audio effects (EQ) settings via a key-value settings table
* Chunked scan insertion for the music library

### Changed

* Reworked background audio handling and audio focus

### Fixed

* Clean up orphaned artists and albums after a scan
* Cap mpv memory and throttle position updates
* Re-enable the audio cache with a 10s buffer to prevent playback dropouts
* Prevent double-advance on track completion with repeat-all
* Clean up the previous cover temp file on song change

[unreleased]: https://github.com/appsono/sono-new/compare/v0.7.2+5...HEAD
[0.7.2+5]: https://github.com/appsono/sono-new/compare/v0.7.1+5...v0.7.2+5
[0.7.1+5]: https://github.com/appsono/sono-new/compare/v0.7.0+5...v0.7.1+5
[0.7.0+5]: https://github.com/appsono/sono-new/compare/v0.6.3+4...v0.7.0+5
[0.6.3+4]: https://github.com/appsono/sono-new/compare/v0.6.2+4...v0.6.3+4
[0.6.2+4]: https://github.com/appsono/sono-new/compare/v0.6.1+4...v0.6.2+4
[0.6.1+4]: https://github.com/appsono/sono-new/compare/v0.6.0+4...v0.6.1+4
[0.6.0+4]: https://github.com/appsono/sono-new/compare/v0.5.3+3...v0.6.0+3
[0.5.3+3]: https://github.com/appsono/sono-new/compare/v0.5.2+2...v0.5.3+3
[0.5.2+3]: https://github.com/appsono/sono-new/compare/v0.5.1+2...v0.5.2+3
[0.5.1+3]: https://github.com/appsono/sono-new/compare/v0.5.0+2...v0.5.1+3
[0.5.0+3]: https://github.com/appsono/sono-new/compare/v0.4.91+2...v0.5.0+3
[0.4.91+2]: https://github.com/appsono/sono-new/compare/v0.4.9+2...v0.4.91+2
[0.4.9+2]: https://github.com/appsono/sono-new/compare/v0.4.8+2...v0.4.9+2
[0.4.8+2]: https://github.com/appsono/sono-new/compare/v0.4.7+2...v0.4.8+2
[0.4.7+2]: https://github.com/appsono/sono-new/compare/v0.4.6+2...v0.4.7+2
[0.4.6+2]: https://github.com/appsono/sono-new/compare/v0.4.5+2...v0.4.6+2
[0.4.5+2]: https://github.com/appsono/sono-new/compare/v0.4.5+1...v0.4.5+2
[0.4.5+1]: https://github.com/appsono/sono-new/compare/v0.4.4+1...v0.4.5+1
[0.4.4+1]: https://github.com/appsono/sono-new/compare/v0.4.3+1...v0.4.4+1
[0.4.3+1]: https://github.com/appsono/sono-new/compare/v0.4.2+1...v0.4.3+1
[0.4.2+1]: https://github.com/appsono/sono-new/compare/v0.4.1+1...v0.4.2+1
[0.4.1+1]: https://github.com/appsono/sono-new/compare/v0.4.0+1...v0.4.1+1
[0.4.0+1]: https://github.com/appsono/sono-new/compare/v0.3.93+1...v0.4.0+1
[0.3.93+1]: https://github.com/appsono/sono-new/compare/v0.3.91+1...v0.3.93+1
[0.3.91+1]: https://github.com/appsono/sono-new/compare/v0.3.9+1...v0.3.91+1
[0.3.9+1]: https://github.com/appsono/sono-new/compare/v0.3.8+3...v0.3.9+1
[0.3.8+3]: https://github.com/appsono/sono-new/compare/v0.3.8+2...v0.3.8+3
[0.3.8+2]: https://github.com/appsono/sono-new/compare/v0.3.7+1...v0.3.8+2
[0.3.7+1]: https://github.com/appsono/sono-new/compare/v0.3.6+1...v0.3.7+1
[0.3.6+1]: https://github.com/appsono/sono-new/compare/v0.3.5+1...v0.3.6+1
[0.3.5+1]: https://github.com/appsono/sono-new/compare/v0.3.4+1...v0.3.5+1
[0.3.4+1]: https://github.com/appsono/sono-new/compare/v0.3.3+1...v0.3.4+1
[0.3.3+1]: https://github.com/appsono/sono-new/compare/v0.3.2+2...v0.3.3+1
[0.3.2+2]: https://github.com/appsono/sono-new/compare/v0.3.2+1...v0.3.2+2
[0.3.2+1]: https://github.com/appsono/sono-new/compare/v0.3.1+1...v0.3.2+1
[0.3.1+1]: https://github.com/appsono/sono-new/compare/v0.3.0+2...v0.3.1+1
[0.3.0+2]: https://github.com/appsono/sono-new/compare/v0.3.0+1...v0.3.0+2
[0.3.0+1]: https://github.com/appsono/sono-new/compare/v0.2.9+1...v0.3.0+1
[0.2.9+1]: https://github.com/appsono/sono-new/compare/v0.2.8+3...v0.2.9+1
[0.2.8+3]: https://github.com/appsono/sono-new/compare/v0.2.8+2...v0.2.8+3
[0.2.8+2]: https://github.com/appsono/sono-new/compare/v0.2.8+1...v0.2.8+2
[0.2.8+1]: https://github.com/appsono/sono-new/compare/v0.2.7+1...v0.2.8+1
[0.2.7+1]: https://github.com/appsono/sono-new/compare/v0.2.6+1...v0.2.7+1
[0.2.6+1]: https://github.com/appsono/sono-new/compare/v0.2.5+1...v0.2.6+1
[0.2.5+1]: https://github.com/appsono/sono-new/compare/v0.2.2+1...v0.2.5+1
[0.2.2+1]: https://github.com/appsono/sono-new/compare/v0.2.1+1...v0.2.2+1
[0.2.1+1]: https://github.com/appsono/sono-new/compare/v0.2.0+2...v0.2.1+1
[0.2.0+2]: https://github.com/appsono/sono-new/compare/v0.1.9+3...v0.2.0+2
[0.1.9+3]: https://github.com/appsono/sono-new/releases/tag/v0.1.9+3
