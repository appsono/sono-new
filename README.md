## How will metadata handling work this time?

This time I won't rely on `on_audio_query`. Instead I will build
my own package.

For the base it will use [audio_metadata_reader](https://pub.dev/packages/audio_metadata_reader),
then I will just build the required public API, models, etc. and connect it with the
app.

This hopefully won't take that long.
The package will then be made available on the [GitHub Orga](https://github.com/appsono/) under the name:<br>
**`sono_query`**


### Why audio_metadata_reader?
It already supports a lot of platforms, which will make it easier for me to port the app
to Linux, Windows, iOS you name it. The reason why is, because it's written in pure
Dart so it has no native code, like `on_audio_query` did.