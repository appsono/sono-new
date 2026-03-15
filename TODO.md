# TODO

## Bugs
- ~~`main.dart` uses `db` from `test_page.dart` as a global, inject it properly~~ **FIXED**
- ~~`main.dart` has a race condition between `sono.AudioService.instance.init()` and `AudioService.init()`~~ **FIXED**
- ~~`audio_handler.dart` never cleans up cover temp files, new one every song change~~ **FIXED**
- ~~`audio_service.dart` `_onTrackCompleted` + `skipNext()` can double-wrap on repeat all~~ **FIXED**

## Before UI
- Reduce memory usage of player
- Fix player going silent when app stays in background for some time
- Use `getSongsStream()` in scan_service to reduce peak memory
- Pass `onError` to scan so failed files dont just vanish
- Filter chain reapply causes audible glitch (the seek hack in audio_effects_service)

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
