import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:sono/db/database.dart';
import 'package:sono/services/scrobble/account/account.dart';
import 'package:sono/services/scrobble/as/audioscrobbler_provider.dart';

abstract class ScrobbleAccountStore {
  Future<List<ScrobbleAccount>> load();
  Future<void> save(ScrobbleAccount account);
  Future<void> remove(String key);
}

abstract class ScrobbleSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureScrobbleSecretStore implements ScrobbleSecretStore {
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());

  const SecureScrobbleSecretStore();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class DbScrobbleAccountStore implements ScrobbleAccountStore {
  static const prefix = 'scrobble';

  final SonoDatabase _db;
  final ScrobbleSecretStore _secrets;

  const DbScrobbleAccountStore(this._db, this._secrets);

  @override
  Future<List<ScrobbleAccount>> load() async {
    final byAccount = <String, Map<String, String>>{};
    for (final entry in (await _db.getAllSettings()).entries) {
      final parts = entry.key.split('.');
      if (parts.length != 3 || parts.first != prefix) continue;
      (byAccount[parts[1]] ??= {})[parts[2]] = entry.value;
    }

    final accounts = <ScrobbleAccount>[];
    for (final entry in byAccount.entries) {
      final account = _fromFields(
        entry.key,
        entry.value,
        await _secrets.read(_sessionSecretKey(entry.key)),
      );
      if (account != null) accounts.add(account);
    }
    return accounts;
  }

  @override
  Future<void> save(ScrobbleAccount account) async {
    final id = account.key;
    await _db.setSetting('scrobble.$id.service', account.service.name);
    await _db.setSetting('scrobble.$id.username', account.username);
    await _db.setSetting('scrobble.$id.enabled', '${account.enabled}');
    await _db.setSetting(
      'scrobble.$id.linked_at',
      '${account.linkedAt.millisecondsSinceEpoch}',
    );
    await _db.setSetting('scrobble.$id.api_key', account.apiKey);
    await _db.setSetting('scrobble.$id.api_secret', account.apiSecret);
    if (account.service == ScrobbleService.custom) {
      await _db.setSetting('scrobble.$id.root', '${account.endpoints.root}');
      await _db.setSetting(
        'scrobble.$id.auth_root',
        '${account.endpoints.authRoot}',
      );
    }

    final session = account.sessionKey;
    if (session == null) {
      await _secrets.delete(_sessionSecretKey(account.key));
    } else {
      await _secrets.write(_sessionSecretKey(account.key), session);
    }
  }

  @override
  Future<void> remove(String key) async {
    final base = '$prefix.$key.';
    for (final setting in (await _db.getAllSettings()).keys) {
      if (setting.startsWith(base)) await _db.removeSetting(setting);
    }
    await _secrets.delete(_sessionSecretKey(key));
    await _db.clearScrobbles(key);
  }

  static String _sessionSecretKey(String key) => '$prefix.$key.session';

  ScrobbleAccount? _fromFields(
    String key,
    Map<String, String> fields,
    String? sessionKey,
  ) {
    final named = ScrobbleService.values.where(
      (s) => s.name == fields['service'],
    );
    final linkedAt = int.tryParse(fields['linked_at'] ?? '');
    if (named.isEmpty || linkedAt == null) return null;
    final service = named.first;

    final endpoints =
        ScrobbleAccount.endpointsFor(service) ?? _customEndpoints(fields);
    if (endpoints == null) return null;

    final defaults = ScrobbleApiDefaults.forService(service);
    final apiKey = fields['api_key'];
    final apiSecret = fields['api_secret'];

    return ScrobbleAccount(
      key: key,
      service: service,
      endpoints: endpoints,
      apiKey: apiKey == null || apiKey.isEmpty ? defaults.key : apiKey,
      apiSecret: apiSecret == null || apiSecret.isEmpty
          ? defaults.secret
          : apiSecret,
      username: fields['username'] ?? '',
      enabled: fields['enabled'] != 'false',
      linkedAt: DateTime.fromMillisecondsSinceEpoch(linkedAt),
      sessionKey: sessionKey,
    );
  }

  static AudioScrobblerEndpoints? _customEndpoints(Map<String, String> fields) {
    final root = Uri.tryParse(fields['root'] ?? '');
    final authRoot = Uri.tryParse(fields['auth_root'] ?? '');
    if (root == null || !root.hasScheme) return null;
    if (authRoot == null || !authRoot.hasScheme) return null;
    return AudioScrobblerEndpoints(root: root, authRoot: authRoot);
  }
}
