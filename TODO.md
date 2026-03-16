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
- Save/restore last playing queue and position on app restart
- Save/restore shuffle and repeat mode
- Clean up orphaned artists/albums after song deletion
- Add sorting options for songs list (title, artist, date added)
- ~~Proper database migrations (version tracking, rollback strategy)~~ **DONE**

## UI

### Phase 1
- Create a design in Figma to create a clear direction
- Present finished design to community for feedback

### Phase 2
- Create required theme files
- Create required widgets

### Phase 3
- Create Home page

<br>

The rest will follow in the future.
