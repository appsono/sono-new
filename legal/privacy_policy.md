# Privacy Policy

Last updated: 18 May 2026

Sono is a local music player by Mathis, distributed as free,
open-source software under the GNU GPLv3.
<br>
Source: <https://github.com/appsono/sono-new>

This policy covers what data Sono handles and where it goes.
If something is not listed here, Sono does not collect it.

---

## Data stored locally

The following is stored only on your device and never sent anywhere:

- Music library metadata (titles, artists, albums, durations,
  cover art, file paths)
- Playback state (queue, position, shuffle, repeat, equalizer settings)
- Local profile (username and avatar, if set)
- App settings (scan paths, parser config, etc.)

All of it lives in Sono's app-private database and is removed
when you uninstall.

---

## Permissions

- **`READ_MEDIA_AUDIO` / `READ_EXTERNAL_STORAGE`**: Find and play local music files.
- **Foreground service / media playback**: Keep playback running in the background and show the media notification.
- **Wake lock**: Prevent the system from killing playback while the screen is off.
- **Internet**: Used only for the optional features below. Sono works fully offline without them.

---

## Network features

Sono works fully offline. The features below use the internet only when their conditions apply.

- Discord must be explicitly connected.
- Lyrics fetch when the fullscreen player is opened.
- The update check runs on launch or when manually used by user.

### Discord Rich Presence

When enabled, Sono:

- Stores your Discord token locally via `flutter_secure_storage`
  (Android Keystore). The token never leaves your device.
- Sends the current song title, artist, playback timestamps, and a
  cover art URL to Discord for display on your profile.
- Uploads the current song's cover art to a temporary file host so
  Discord can fetch it. The primary host is [uguu.se][uguu]
  (3 h expiry); if it fails, Sono falls back to [Litterbox][litterbox]
  (1 h expiry). Uploads contain only them image.

Disconnecting from Settings deletes the stored token and stops all
Discord traffic immediately.

### Lyrics

When the fullscreen player is opened, Sono fetches lyrics from
[lrclib.net][lrclib] for the current song and pre-fetches lyrics for
the next few queued songs. Each request contains the song's title,
artist name, and (when available) album name, plus a User-Agent string
identifying Sono and its version. Fetched lyrics are cached locally so
the same song is not re-requested. No identifiers are attached beyond
what lrclib logs for any HTTPS request.

### Update check

On launch (and at most every six hours), Sono fetches the latest
release tag from the GitHub Releases API for `appsono/sono-new`.
No identifiers are attached beyond what GitHub logs for any HTTPS
request. Nothing is downloaded automatically.

---

## What Sono does not do

- No analytics, telemetry, crash reporting, or tracking SDKs
- No ads
- No server-side account system, as there is no "Sono server"
- No selling or sharing of personal data with third parties

---

## Third-party services

- **Discord**: Rich Presence display.
[Privacy policy][discord-privacy]
- **uguu.se**: Transient cover art hosting (3 h expiry).
[uguu.se][uguu]
- **Litterbox** (litterbox.catbox.moe): Transient cover art hosting fallback (1 h expiry).
[Litterbox][litterbox]
- **lrclib.net**: Open-source Lyrics database.
[lrclib.net][lrclib]
- **GitHub**: Update checks and source hosting.
[Privacy statement][github-privacy]

[discord-privacy]: https://discord.com/privacy
[uguu]: https://uguu.se/
[litterbox]: https://litterbox.catbox.moe/
[lrclib]: https://lrclib.net/
[github-privacy]: https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement

---

## Security

The Discord token is stored via `flutter_secure_storage`
(Android Keystore). All other local data is in an app-private
SQLite database inaccessible to other apps.

---

## Children

Sono is not directed at children under 13 and does not knowingly
collect personal data from them. Because no personal data is stored
server-side, there is nothing to delete beyond uninstalling the app
or disconnecting Discord yourself.

---

## Changes

If this policy changes, the updated version is published at the same
URL with a new "Last updated" date. Material changes are noted in
the release notes on GitHub.

---

## Contact

- GitHub Issues: <https://github.com/appsono/sono-new/issues>
- Discord: <https://discord.gg/48fvsUCNwu>
- Nerimity: <https://nerimity.com/i/sono>
