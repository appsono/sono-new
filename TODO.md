# TODO

## Bugs

- ~~`main.dart` uses `db` from `test_page.dart` as a global, inject it properly~~ **FIXED**
- ~~`main.dart` has a race condition between `sono.AudioService.instance.init()` and `AudioService.init()`~~ **FIXED**
- ~~`audio_handler.dart` never cleans up cover temp files, new one every song change~~ **FIXED**
- ~~`audio_service.dart` `_onTrackCompleted` + `skipNext()` can double-wrap on repeat all~~ **FIXED**
- ~~Player has brief silence/artifacts during playback (cache was fully disabled)~~ **FIXED**

## Before UI

- ~~Reduce memory usage of player~~ **FIXED**
- ~~Fix player going silent when app stays in background for some time~~ **FIXED**
- ~~Use `getSongsStream()` in scan_service to reduce peak memory~~ **FIXED**
- ~~Pass `onError` to scan so failed files dont just vanish~~ **FIXED**
- ~~Filter chain reapply causes audible glitch (the seek hack in audio_effects_service)~~ **FIXED**
- ~~Save/restore last playing queue and position on app restart~~ FIXED
- ~~Save/restore shuffle and repeat mode~~ **FIXED**
- ~~Clean up orphaned artists/albums after song deletion~~ **FIXED**
- Add sorting options for songs list (title, artist, date added)
- ~~Proper database migrations (version tracking, rollback strategy)~~ **FIXED**

## UI

### Phase 1

- ~~Create a design in Figma to create a clear direction~~ **DONE**
- ~~Present finished design to community for feedback~~ **DONE**

### Phase 2

- ~~Create required theme files~~ **DONE**
- ~~Create required widgets~~ **DONE**

### Phase 3

- ~~Create Home page~~ **DONE (for now)**

### --- Stop ---

- ~~add Weblate support~~ **DONE**

### --- Continue ---

### Phase 4

- Create Fullscreen player and it's widgets

### Phase 5

- Create Library Widgets
- Create the different views (albums, artists, etc.)
- Create Library Page

### Phase 6

- Create Search Page

<br>

The rest will follow in the future.
