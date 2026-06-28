# TODO

## Bugs

- ~~`main.dart` uses `db` from `test_page.dart` as a global,
  inject it properly~~ **FIXED**
- ~~`main.dart` has a race condition between `sono.AudioService.instance.init()`
  and `AudioService.init()`~~ **FIXED**
- ~~`audio_handler.dart` never cleans up cover temp files, new one every song
  change~~ **FIXED**
- ~~`audio_service.dart` `_onTrackCompleted` + `skipNext()` can double-wrap on
  repeat all~~ **FIXED**
- ~~Player has brief silence/artifacts during playback (cache was fully
  disabled)~~ **FIXED**
- Add to Queue / Play next isn't wired up with UI
- Skip to previous doesn't work when on the last song in the queue with loop all
  enabled

## UI

- ~~Create a design in Figma to create a clear direction~~ **DONE**
- ~~Present finished design to community for feedback~~ **DONE**
- ~~Create required theme files~~ **DONE**
- ~~Create required widgets~~ **DONE**
- ~~Create Home page~~ **DONE (for now)**
- ~~add Weblate support~~ **DONE**
- ~~Create Fullscreen player and it's widgets~~ **DONE**
- ~~Create Library Widgets~~ **DONE**
- ~~Create the different views (albums, artists, etc.)~~ **DONE**
- ~~Create Library Page~~ **DONE**
- ~~Create Search Page~~ **DONE**

## Features

- Custom shuffle: control playback priority for favorite albums, artists, and
  liked songs
- Crossfade: fade out the current song and fade in the next one at the end of
  the current
- Sleep timer: fade out or stop after N minutes / end of song / end of queue
- Volume controls: more options to control song volume
  - ReplayGain
  - In-app volume slider
- Tag editor:
  - Edit multiple songs at once
  - Change album cover
- Playlists:
  - Add a whole album or queue at once
  - Import / export (M3U)
- Backup: export / import app data (likes, favorites, playlists, settings,
  scan paths, etc.)

## Improvements (pre-UI)

- ~~Reduce memory usage of player~~ **FIXED**
- ~~Fix player going silent when app stays in background for some time~~ **FIXED**
- ~~Use `getSongsStream()` in scan_service to reduce peak memory~~ **FIXED**
- ~~Pass `onError` to scan so failed files dont just vanish~~ **FIXED**
- ~~Filter chain reapply causes audible glitch
  (the seek hack in audio_effects_service)~~ **FIXED**
- ~~Save/restore last playing queue and position on app restart~~ FIXED
- ~~Save/restore shuffle and repeat mode~~ **FIXED**
- ~~Clean up orphaned artists/albums after song deletion~~ **FIXED**
- ~~Add sorting options for songs list (title, artist, date added)~~ **ADDED**
- ~~Proper database migrations (version tracking, rollback strategy)~~ **FIXED**
