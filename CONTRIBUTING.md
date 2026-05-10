# Contributing to Sono

Thanks for wanting to help. Sono is a solo project right now, so any contribution genuinely matters.

---

## Before you start

If you want to work on something bigger, **open an issue first**. It avoids you spending hours on something that might not fit the direction of the app. For small fixes (typos, obvious bugs), just open a PR directly.

Check [TODO.md](TODO.md) to see what's planned and what's already in progress. If something is listed there, it's fair game.

---

## Setting up the project

**Requirements:**

- Flutter SDK `^3.11.1`
- Dart SDK `^3.11.1`
- A device or emulator (Android, iOS, Linux, or Windows. macOS and web are not targets)

**Steps:**

```bash
git clone https://github.com/appsono/sono-new.git
cd sono-new
flutter pub get
flutter run --flavor dev
```

Use `flutter run --flavor prod` to test the app in production mode.

The app uses a local SQLite database via [Drift](https://drift.simonbinder.eu/). If you change any database table (`lib/db/tables.dart`), you need to regenerate the generated file:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Project structure

```
lib/
├── db/          # Drift database schema and generated code
├── helper/      # Small utility functions
├── pages/       # App pages (home, settings, auth, etc.)
├── services/    # Audio engine, scanner, Discord RPC, update checker
├── theme/       # Tokens, icons, theme config
└── widgets/     # Reusable UI components
```

The audio stack lives in `lib/services/audio/` and is the most complex part of the codebase. Be careful when making changes there. At least I think it's the most complex, I might be wrong...

---

## How to contribute

### Reporting a bug

Open an issue with:

- What you expected to happen
- What actually happened
- Your platform (Android / Linux / Windows / iOS)
- Steps to reproduce if you can

### Fixing a bug

- Branch off `main`
- Keep the fix focused. Don't refactor unrelated things in the same PR
- Test on at least the platform the bug affects

### Working on a feature

- Check TODO.md first. If it's listed, it's planned
- Open an issue to discuss it before building it
- Keep it small. Sono's goal is a focused local music player, not a kitchen sink (kanye ref btw)

### Working on UI

The design direction is set (Figma designs exist). If you're touching UI:

- Follow the existing theme system in `lib/theme/`
- Use `SonoColors`, `SonoTokens`, and `SonoTextStyles`. Don't hardcode values
- Use icons from `IconsSheet` in `lib/theme/icons.dart`

---

## Code style

- Run `dart format .` before committing. Unformatted PRs won't be merged
- Comments should follow the same styling as existing ones
- Use the existing commit style: `type(scope): description`
  - Types: `feat`, `fix`, `chore`, `refactor`, `perf`, `docs`, `style`, `test`
  - Example: `fix(audio): prevent stale state on pause`
- Keep commits focused. One thing per commit is ideal

---

## What's most needed right now

Based on TODO.md, the biggest open areas are:

- **Fullscreen player**: Phase 4 of the UI roadmap
- **Library page**: Phase 5 (album/artist views)
- **Sorting options**: songs list by title, artist, date added
- **Bug reports**: especially on Windows and iOS, which get less testing

If you're new to the codebase, `lib/widgets/` is the safest place to start. It's self-contained with a low risk of breaking things, again that's out of my point of view.

---

## Questions

Open an issue or join the [Discord](https://discord.sono.wtf) if you want to talk something through first.
