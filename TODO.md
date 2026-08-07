# TODO

## Bugs

- [x] ~~main.dart uses db from test_page.dart as a global,
      inject it properly~~
- [x] ~~main.dart has a race condition between `sono.AudioService.instance.init()`
      and `AudioService.init()`~~
- [x] ~~audio_handler.dart never cleans up cover temp files, new one every song
      change~~
- [x] ~~audio_service.dart `_onTrackCompleted` + `skipNext()` can double-wrap on
      repeat all~~
- [x] ~~Player has brief silence/artifacts during playback (cache was fully
      disabled)~~
- [x] ~~Add to Queue / Play next isn't wired up with UI~~
- [x] ~~Skip to previous doesn't work when on the last song in the queue with loop all
      enabled~~
- [x] ~~Favorite Albums removed after forced rescan / sorting mode changed~~
- [x] ~~EQ and bass boost sometimes have no audible effect~~

## UI

- [x] ~~Create a design in Figma to create a clear direction~~
- [x] ~~Present finished design to community for feedback~~
- [x] ~~Create required theme files~~
- [x] ~~Create required widgets~~
- [x] ~~Create Home page~~
- [x] ~~Add Weblate support~~
- [x] ~~Create Fullscreen player and it's widgets~~
- [x] ~~Create Library Widges~~
- [x] ~~Create the different views (albums, artists, etc.)~~
- [x] ~~Create Library Page~~
- [x] ~~Create Search Page~~

## Features

- [ ] Custom shuffle: control playback priority for favorite albums, artists, and
      liked songs
- [ ] Crossfade: fade out the current song and fade in the next one at the end of
      the current
- [ ] Sleep timer: fade out or stop after N minutes / end of song / end of queue
- [ ] Volume controls: more options to control song volume
  - ReplayGain
  - ~~In-app volume slider~~
- [ ] Output sample rate: option to pin `audio-samplerate` instead of following
      the first played file, plus a toggle to trade fidelity for gapless across
      differently encoded files
- [ ] Tag editor:
  - Edit multiple songs at once
  - Change album cover
- [ ] Playlists:
  - Add a whole album or queue at once
  - Import / export (M3U)
- [x] ~~Backup: export / import app data (likes, favorites, playlists, settings,
      scan paths, etc.)~~
- [ ] Scrobbling Support (Last.fm, Libre.fm, etc.)

## Improvements (pre-UI)

- [x] ~~Reduce memory usage of player~~
- [x] ~~Fix player going silent when app stays in background for some time~~ **FIXED**
- [x] ~~Use `getSongsStream()` in scan_service to reduce peak memory~~
- [x] ~~Pass `onError` to scan so failed files dont just vanish~~
- [x] ~~Filter chain reapply causes audible glitch
      (the seek hack in audio_effects_service)~~
- [x] ~~Save/restore last playing queue and position on app restart~~
- [x] ~~Save/restore shuffle and repeat mode~~
- [x] ~~Clean up orphaned artists/albums after song deletion~~
- [x] ~~Add sorting options for songs list (title, artist, date added)~~
- [x] ~~Proper database migrations (version tracking, rollback strategy)~~

