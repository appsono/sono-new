# Privacy Policy

Last updated: 4 October 2026

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

The following is stored only on your device and never sent anywhere,
except where a network feature below says otherwise:

- Music library metadata (titles, artists, albums, durations,
  cover art, file paths)
- Playback state (queue, position, shuffle, repeat, equalizer settings)
- Play history (which songs you played, when and for how long), used
  for Listening Stats and scrobbling
- Local profile (username and avatar, if set)
- Connected accounts (Discord username, display name and avatar URL;
  scrobbling service, username and server address)
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
- Scrobbling must be explicitly linked to an account. Nothing is sent
  until you do.
- Lyrics fetch when the fullscreen player is opened.
- The update check runs on builds distributed through GitHub,
  and runs on launch or when manually used by user.
- The contributors page loads its list when you open it.

### Discord Rich Presence

Connecting is entirely optional. When you connect, Sono:

- Opens Discord's own sign-in page in an in-app browser window and reads
  the resulting session token from it. Your Discord password is never
  seen, handled, or stored by Sono.
- Uses that token to authorize [PreMiD][premid]'s Discord application on
  your account (scopes `identify`, `activities.write`), which is what
  allows Sono to set your status. PreMiD then appears under Authorized
  Apps in your Discord settings. No data is sent to PreMiD itself.
- Stores the session token and the resulting access token in your
  platform's secure storage via `flutter_secure_storage` (Android
  Keystore on Android, libsecret on Linux, DPAPI on Windows, Keychain
  on iOS). The tokens are only ever sent to Discord.
- Fetches your Discord username, display name and avatar to show the
  connected account in Settings.
- Sends the current song title, artist, and, unless turned off in Settings,
  playback timestamps and a cover art reference to Discord
  for display on your profile.

If "Show album art" is on, Sono also:

- Uploads the current song's cover art to a temporary file host. The
  primary host is [uguu.se][uguu] (3 h expiry); if it fails, Sono falls
  back to [Litterbox][litterbox] (1 h expiry). Uploads contain only the
  image, with no filename, metadata, or identifier attached. While it
  exists, the uploaded file is reachable by anyone holding its URL,
  and it is deleted by the host when it expires.
- Registers that link with Discord, which fetches the image and keeps
  its own copy on its media proxy (`media.discordapp.net`). That copy is
  not affected by the temporary host's expiry and is kept according to
  Discord's own policies.
- Remembers the proxy link for up to 3 days so the same cover is not
  uploaded again and checks now and then whether Discord still serves it.

With "Show album art" off, nothing is uploaded.

The legal basis for this processing is your consent, given by connecting.
Disconnecting from Settings withdraws it: the stored tokens and account
details are deleted and all Discord traffic stops immediately.

### Scrobbling

Linking a scrobbling account is entirely optional. Sono supports
[Last.fm][lastfm], [Libre.fm][librefm] and self-hosted servers that use
the same API (such as GNU FM). When you link an account, Sono:

- Opens the service's own authorization page in your browser. You sign
  in there, so your password is never seen, handled, or stored by Sono.
  After you approve, Sono recieves a session key.
- Stores the session key in secure storage via `flutter_secure_storage`
  and the service, username and server address in the app database.
- Sends a "now playing" update when a song starts, containing its title,
  artist, album (when available) and duration.
- Sends a scrobble for each play that counts: songs longer than 30
  seconds, played for at least half their length or four minutes,
  whichever comes first. A scrobble contains the title, artist, album
  (when available), duration and the time the song started playing.
  Scrobbles are sent in batches every few minutes and on song changes
  and are retried later if you are offline.

Only plays from after you linked the account are sent. Plays older than
14 days are not sent and plays restored from a backup are never sent.
Each request carries Sono's API key and a signature, but no device
identifier. Pausing an account in Settings stops all requests to it;
plays from the pause are sent once you turn it back on, within the same
14 day limit.

With a self-hosted server, data goes to the server address you enter.
Whoever runs that server is responsible for it.

The legal basis for this processing is your consent, given by linking.
Unlinking from Settings withdraws it: the session key, the account
details and the record of what was already sent are deleted, and all
traffic to that service stops immediately. Scrobbles already sent stay
on your profile there and have to be deleted on the service itself.

### Lyrics

When the fullscreen player is opened, Sono fetches lyrics from
[lrclib.net][lrclib] for the current song and pre-fetches lyrics for
the next few queued songs. Each request contains the song's title,
artist name, and (when available) album name, plus a User-Agent string
identifying Sono and its version. No account, device, or user identifier
is attached, and nothing is transmitted beyond what lrclib logs for any
HTTPS request. Fetched lyrics are cached locally so the same song is
not re-requested.

### Update check

On builds distributed through GitHub, Sono fetches the latest release tag from
GitHub Releases API for `appsono/sono-new` on launch, and at most every
six hours. No identifiers are attached beyond what GitHub logs for any
HTTPS request. Nothing is downloaded automatically.

**This feature is disabled entirely in the Google Play build**, which
updates through Play instead. That build makes no request to GitHub.

### Contributors page

When you open the contributors page in Settings, Sono fetches the list
of contributors from the GitHub API and loads their profile pictures
from GitHub and, for translators, from [Weblate][weblate]. No
identifiers are attached beyond what those services log for any HTTPS
request.

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

- **Discord** (United States): Rich Presence display and cover art proxy.
  [Privacy policy][discord-privacy]
- **uguu.se** (Sweden): Transient cover art hosting (3 h expiry).
  [uguu.se][uguu]
- **Litterbox** (litterbox.catbox.moe, United States): Transient cover art
  hosting fallback (1 h expiry).
  [Litterbox][litterbox]
- **Last.fm** (United Kingdom): Scrobbling.
  [Privacy policy][lastfm-privacy]
- **Libre.fm**: Scrobbling.
  [Libre.fm][librefm]
- **lrclib.net**: Open-source Lyrics database.
  [lrclib.net][lrclib]
- **GitHub** (United States): Update checks, contributors page, and
  source hosting.
  [Privacy statement][github-privacy]
- **Weblate** (hosted.weblate.org): Translator profile pictures on the
  contributors page.
  [Weblate][weblate]

[discord-privacy]: https://discord.com/privacy
[premid]: https://premid.app/
[uguu]: https://uguu.se/
[litterbox]: https://litterbox.catbox.moe/
[lastfm]: https://www.last.fm/
[lastfm-privacy]: https://www.last.fm/legal/privacy
[librefm]: https://libre.fm/
[lrclib]: https://lrclib.net/
[github-privacy]: https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement
[weblate]: https://hosted.weblate.org/

## How long data is kept

- Local data stays until you delete it or uninstall Sono.
- The Discord tokens are kept until you disconnect or uninstall.
- Uploaded cover art is deleted by the host on expiry (3 h on uguu.se,
  1 h on Litterbox). Discord's proxied copy is kept according to
  Discord's own policies and Sono forgets its link after 3 days.
- Scrobbling session keys are kept until you unlink the account or
  uninstall. Scrobbles already sent stay on the service until you
  delete them there.
- Cached lyrics stay until you reset them from the lyrics menu or
  uninstall.

---

## Your rights

Under the GDPR you have the right to access, correct, delete, restrict,
and port your personal data, and to object to its processing.

Sono stores nothing on a server, so there is no account to request data
from and nothing held that you cannot reach yourself. In practice these
rights are exercised on your device: disconnect Discord or unlink a
scrobbling account to delete its stored credentials, or uninstall Sono
to remove everything else. Data held by the third parties listed above
is subject to their own policies, and requests for it go to them
directly.

You also have the right to lodge a complaint with your local data
protection supervisory authority.

---

## Security

The Discord tokens and scrobbling session keys are stored via
`flutter_secure_storage`, backed by the operating system's secure
storage. All other local data is in an app-private SQLite database
inaccessible to other apps.

---

## Children

Sono is not directed at children and does not knowingly collect personal data
from them. You may use Sono if you meet the minimum age for digital
consent in your country, which is 16 in Germany and ranges from 13 to 16
across the EU. Connected services set their own minimums on top of that:
Discord requires you to be at least 13, and older where local laws say so.

Because no personal data is stored server-side, there is nothing to
delete beyond uninstalling the app or disconnecting your accounts yourself.

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
- Stoat/Revolt: <https://stt.gg/3chxJMWT>
