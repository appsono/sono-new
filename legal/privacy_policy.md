# Privacy Policy

Last updated: 24 July 2026

Sono is a local music player by the GitHub user mathiiiiiis, distributed as free,
open-source software under the GNU GPLv3.
<br>
Source: <https://github.com/appsono/sono-new>

This policy covers what data Sono handles and where it goes.
If something is not listed here, Sono does not collect it.

---

## Who is responsible

Sono is developed and published by Mathis Laarmanns, Germany.
For the limited processing described below, this is the controller
under the GDPR.

Contact: <sonosupport@gmail.com>

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
- **Foreground service / media playback**: Keep playback running in the
  background and show the media notification.
- **Wake lock**: Prevent the system from killing playback while the screen is off.
- **Internet**: Used only for the optional features below. Sono works fully
  offline without them.

---

## Network features

Sono works fully offline. The features below use the internet only when their
conditions apply.

- Discord must be explicitly connected. Nothing is sent or uploaded
  until you do.
- Lyrics fetch when the fullscreen player is opened.
- The update check runs on builds distributed through GitHub,
  and runs on launch or when manually used by user.

### Discord Rich Presence

Connecting is entirely optional. When you connect, Sono:

- Opens Discord's own sign-in page in an in-app browser window and reads
  the resulting session token from it. Your Discord password is never
  seen, handled, or stored by Sono.
- Stores that token in your platform's secure storage via
  `flutter_secure_storage` (Android Keystore on Android, libsecret on
  Linux, DPAPI on Windows, Keychain on iOS). The token never leaves
  your device.
- Sends the current song title, artist, playback timestamps, and a
  cover art URL to Discord for display on your profile.
- Uploads the current song's cover art to a temporary file host so
  Discord can fetch it. The primary host is [uguu.se][uguu]
  (3 h expiry); if it fails, Sono falls back to [Litterbox][litterbox]
  (1 h expiry. Uploads contain only the image, with no filename,
  metadata, or identifier attached. While it exists, the uploaded
  file is reachable by anyone holding its URL, and it is deleted by
  the host when it expires.

The Legal basis for this processing is your consent, given by connecting.
Disconnecting from Settings withdraws it: the stored token is deleted and
all Discord traffic stops immediately.

### Lyrics

When the fullscreen player is opened, Sono fetches lyrics from
[lrclib.net][lrclib] for the current song and pre-fetches lyrics for
the next few queued songs. Each request contains the song's title,
artist name, and (when available) album name, plus a User-Agent string
identifying Sono and its version. No account, device, or user identifier
is attached, and nothing beyond what lrclib logs for any HTTPS request
that is transmitted. Fetched lyrics are cached locally so the same song is
not re-requested.

### Update check

On builds distributed through GitHub, Sono fetches the latest release tag from
GitHub Releases API for `appsono/sono-new` on launch, and at most every
six hours. No identifiers are attached beyond what GitHub logs for any
HTTPS request. Nothing is downloaded automatically.

**This feature is disabled entirely in the Google Play build**, which
updates through Play instead. That build makes no request to GitHub.

---

## What Sono does not do

- No analytics, telemetry, crash reporting, or tracking SDKs
- No ads
- No server-side account system, as there is no "Sono server"
- No selling or sharing of personal data with third parties
- No profiling and no automated decision-making

---

## Third-party services

Sono has no servers of its own. The services below receive data only
when the corresponding feature is used, and they are outside Sono's
control. Some are located outside the EU, so using those features
involves an international transfer.

- **Discord** (United States): Rich Presence display.
  [Privacy policy][discord-privacy]
- **uguu.se** (Sweden): Transient cover art hosting (3 h expiry).
  [uguu.se][uguu]
- **Litterbox** (litterbox.catbox.moe, United States): Transient cover art
  hosting fallback (1 h expiry).
  [Litterbox][litterbox]
- **lrclib.net**: Open-source Lyrics database.
  [lrclib.net][lrclib]
- **GitHub** (United States): Update checks and source hosting.
  [Privacy statement][github-privacy]

[discord-privacy]: https://discord.com/privacy
[uguu]: https://uguu.se/
[litterbox]: https://litterbox.catbox.moe/
[lrclib]: https://lrclib.net/
[github-privacy]: https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement

## How long data is kept

- Local data stays until you delete it or uninstall Sono.
- The Discord token is kept until you disconnect or uninstall.
- Uploaded cover art is deleted by the host on expiry (3 h on uguu.se,
  1 h on Litterbox).
- Cached lyrics stay until you reset them from the lyrics menu or
  uninstall.

---

## Your rights

Under the GDPR you have the right to access, correct, delete, restrict,
and port your personal data, and to object to its processing.

Sono stores nothing on a server, so there is no account to request data
from and nothing held that you cannot reach yourself. In practice these
rights are exercised on your device: disconnect Discord to delete the
stored token, or uninstall Sono to remove everything else. Data held by
the third parties listed above is subject to their own policies, and
requests for it go to them directly.

You also have the right to ledge a complain with your local data
protection supervisory authority.

---

## Security

The Discord token is stored via `flutter_secure_storage`, backed by the
operating system's secure storage. All other local data is in an
app-private SQLite database inaccessible to other apps.

---

## Children

Sono is not directed at children and does not knowingly collect personal data
from them. You may use Sono if you meet the minimum age for digital
consent in your country, which is 16 in Germany and ranges from 13 to 16
across the EU. Connected services set their own minimums on top of that:
Discord requires you to be at least 13, and older where local laws say so.

Because no personal data is stored server-side, there is nothing to
delete beyond uninstalling the app or disconnecting Discord yourself.

---

## Changes

If this policy changes, the updated version is published at the same
URL with a new "Last updated" date. Material changes are noted in
the release notes on GitHub.

---

## Contact

- Email: <sonosupport@gmail.com>
- GitHub Issues: <https://github.com/appsono/sono-new/issues>
- Discord: <https://discord.gg/48fvsUCNwu>
- Nerimity: <https://nerimity.com/i/sono>
