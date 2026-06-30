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

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

// ==== models ====

class Contributor {
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? profileUrl;

  const Contributor({
    required this.name,
    this.username,
    this.avatarUrl,
    this.profileUrl,
  });
}

// ==== service ====

/// Pulls contributor info from github
///
/// > code Contributor: github Contributor api, filtered to drop
///   mathiiiiiis (maintainer acc) and bot accs
/// > translators: scraped from git commits that match weblate
///   commit message pattern
///
/// If there is a better way, please open a PR or Issue. Thanks!
class ContributorsService {
  static const _githubOwner = 'appsono';
  static const _githubRepo = 'sono-new';
  static const _maintainerLogin = 'mathiiiiiis';
  static const _maintainerLogin2 = 'mathiiiiiiis';
  static const _timeout = Duration(seconds: 10);

  static Future<List<Contributor>> fetchContributors() async {
    try {
      final res = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$_githubOwner/$_githubRepo/contributors?per_page=100',
            ),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-Github-Api-Version': '2022-11-28',
            },
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return [];

      final decoded = jsonDecode(res.body);
      if (decoded is! List) return [];

      final out = <Contributor>[];
      for (final raw in decoded) {
        if (raw is! Map<String, dynamic>) continue;
        final login = raw['login'] as String?;
        final type = raw['type'] as String?;
        if (login == null) continue;
        final loginLower = login.toLowerCase();
        if (loginLower == _maintainerLogin.toLowerCase() ||
            loginLower == _maintainerLogin2) {
          continue;
        }
        if (type == 'Bot' || login.endsWith('[bot]')) continue;

        out.add(
          Contributor(
            name: login,
            username: login,
            avatarUrl: raw['avatar_url'] as String?,
            profileUrl: raw['html_url'] as String?,
          ),
        );
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Loads hand-maintained translator list from assets/app/translators.json
  static Future<Map<String, List<Contributor>>> loadTranslators() async {
    try {
      final raw = await rootBundle.loadString('assets/app/translators.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};

      final out = <String, List<Contributor>>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! List) continue;
        final translators = <Contributor>[];
        for (final item in value) {
          if (item is! Map<String, dynamic>) continue;
          final name = item['name'] as String?;
          if (name == null || name.isEmpty) continue;
          final username = item['username'] as String?;
          final avatarUrl = username != null && username.isNotEmpty
              ? 'https://hosted.weblate.org/avatar/128/$username.png'
              : null;
          translators.add(
            Contributor(
              name: name,
              username: username,
              avatarUrl: avatarUrl,
              profileUrl: item['profileUrl'] as String?,
            ),
          );
        }
        if (translators.isNotEmpty) out[entry.key] = translators;
      }
      return out;
    } catch (_) {
      return {};
    }
  }
}
