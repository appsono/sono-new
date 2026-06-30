// Copyright (C) 2026 mathiiiiiis
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.

class ChangelogSection {
  final String title;
  final List<String> entries;
  const ChangelogSection(this.title, this.entries);
}

class ChangelogRelease {
  final String version;
  final String? date;
  final List<ChangelogSection> sections;
  const ChangelogRelease({
    required this.version,
    required this.date,
    required this.sections,
  });
}
