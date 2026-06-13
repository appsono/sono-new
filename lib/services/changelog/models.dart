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
