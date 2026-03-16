import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:media_kit/media_kit.dart';
import 'package:sono/db/database.dart';

/// 10-band superequalizer center frequencies and octave widths
/// > uses ffmpegs parametric equalizer
const List<({double freq, double width, String label})> eqBands = [
  (freq: 32, width: 1.0, label: '32'),
  (freq: 64, width: 1.0, label: '64'),
  (freq: 125, width: 1.0, label: '125'),
  (freq: 250, width: 1.0, label: '250'),
  (freq: 500, width: 1.0, label: '500'),
  (freq: 1000, width: 1.0, label: '1k'),
  (freq: 2000, width: 1.0, label: '2k'),
  (freq: 4000, width: 1.0, label: '4k'),
  (freq: 8000, width: 1.0, label: '8k'),
  (freq: 16000, width: 1.0, label: '16k'),
];

const int bandCount = 10;

class AudioEffectsService {
  AudioEffectsService._();
  static final AudioEffectsService instance = AudioEffectsService._();

  Player? _player;
  SonoDatabase? _db;
  Timer? _saveDebounce;

  /// EQ gains per band in dB. Range: -12.0 to +12.0, 0.0 = flat
  final List<double> _eqGains = List.filled(bandCount, 0.0);

  bool _eqEnabled = false;
  double _bassBoost = 0.0; //dB
  double _speed = 1.0;
  double _pitch = 1.0;
  Timer? _applyDebounce;

  /// ===========================
  ///           getters
  /// ===========================
  List<double> get eqGains => List.unmodifiable(_eqGains);
  bool get eqEnabled => _eqEnabled;
  double get bassBoost => _bassBoost;
  double get speed => _speed;
  double get pitch => _pitch;

  /// Bind Player instance :D
  /// (gets  called once after player creation)
  void attach(Player player) {
    _player = player;
  }

  /// Bind database
  void attachDb(SonoDatabase db) {
    _db = db;
  }

  /// Load saved settings from database
  Future<void> loadSettings() async {
    final db = _db;
    if (db == null) return;

    final all = await db.getAllSettings();

    _eqEnabled = all['fx.eq_enabled'] == 'true';
    _bassBoost = double.tryParse(all['fx.bass_boost'] ?? '') ?? 0.0;
    _speed = double.tryParse(all['fx.speed'] ?? '') ?? 1.0;
    _pitch = double.tryParse(all['fx.pitch'] ?? '') ?? 1.0;

    final gainsJson = all['fx.eq_gains'];
    if (gainsJson != null) {
      try {
        final decoded = jsonDecode(gainsJson) as List;
        for (int i = 0; i < bandCount && i < decoded.length; i++) {
          _eqGains[i] = (decoded[i] as num).toDouble().clamp(-12.0, 12.0);
        }
      } catch (_) {}
    }

    //apply loaded speed/pitch
    await _player?.setRate(_speed);
    await _player?.setPitch(_pitch);
    if (_eqEnabled || _bassBoost.abs() > 0.1) {
      await _applyFilterChain();
    }
  }

  /// Persist current settings to database
  void _saveSettings() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () {
      _saveSettingsNow();
    });
  }

  Future<void> _saveSettingsNow() async {
    final db = _db;
    if (db == null) return;

    await db.setSetting('fx.eq_enabled', _eqEnabled.toString());
    await db.setSetting('fx.eq_gains', jsonEncode(_eqGains));
    await db.setSetting('fx.bass_bost', _bassBoost.toString());
    await db.setSetting('fx.speed', _speed.toString());
    await db.setSetting('fx.pitch', _pitch.toString());
  }

  /// ===========================
  ///         equalizer
  /// ===========================

  /// Set single band gain in dB
  /// [band] 0-9, [gain] -12.0 to +12.0
  Future<void> setEqBand(int band, double gain) async {
    if (band < 0 || band >= bandCount) return;
    _eqGains[band] = gain.clamp(-12.0, 12.0);
    if (_eqEnabled) await _applyFilterChain();
    _saveSettings();
  }

  /// Set all bands at once
  Future<void> setEqGains(List<double> gains) async {
    for (int i = 0; i < bandCount && i < gains.length; i++) {
      _eqGains[i] = gains[i].clamp(-12.0, 12.0);
    }
    if (_eqEnabled) await _applyFilterChain();
    _saveSettings();
  }

  /// Reset all EQ bands to unity (aka 1.0)
  Future<void> resetEq() async {
    for (int i = 0; i < bandCount; i++) {
      _eqGains[i] = 0.0;
    }
    if (_eqEnabled) await _applyFilterChain();
    _saveSettings();
  }

  // Toogle EQ on/off
  Future<void> setEnabled(bool enabled) async {
    _eqEnabled = enabled;
    await _applyFilterChain();
    _saveSettings();
  }

  /// ===========================
  ///         Bass Boost
  /// ===========================

  /// Set bass boost in dB
  /// 0 = off, positive = boost
  Future<void> setBassBoost(double db) async {
    _bassBoost = db.clamp(0.0, 20.0);
    await _applyFilterChain();
    _saveSettings();
  }

  /// ===========================
  ///      Speed and Pitch
  /// ===========================

  Future<void> setSpeed(double rate) async {
    _speed = rate.clamp(0.25, 4.0);
    await _player?.setRate(_speed);
    _saveSettings();
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.25, 4.0);
    await _player?.setPitch(_pitch);
    _saveSettings();
  }

  /// ===========================
  /// Build & apply filter chain
  /// ===========================

  Future<void> _applyFilterChain() async {
    _applyDebounce?.cancel();
    final completer = Completer<void>();
    _applyDebounce = Timer(const Duration(milliseconds: 80), () async {
      await _applyFilterChainNow();
      completer.complete();
    });
    return completer.future;
  }

  /// Applies current EQ + bass boost filter chain
  Future<void> _applyFilterChainNow() async {
    final player = _player;
    if (player == null) return;

    final platform = player.platform;
    if (platform is! NativePlayer) {
      dev.log('AudioEffects: not NativePlayer, skipping', name: 'sono.fx');
      return;
    }

    final afValue = _buildAfString();
    dev.log('AudioEffects: settings af="$afValue"', name: 'sono.fx');

    try {
      await platform.setProperty('af', afValue);
      dev.log('AudioEffects: af applied', name: 'sono.fx');
    } catch (e) {
      dev.log('AudioEffects: failed to set af: $e', name: 'sono.fx');
    }
  }

  /// Build full af string
  String _buildAfString() {
    final graphParts = <String>[];

    for (int i = 0; i < bandCount; i++) {
      final band = eqBands[i];
      final gain = _eqEnabled ? _eqGains[i] : 0.0;
      graphParts.add(
        'equalizer@eq$i=f=${band.freq}:width_type=o:w=${band.width}:g=${gain.toStringAsFixed(1)}',
      );
    }

    final bassGain = _bassBoost.abs() > 0.1 ? _bassBoost : 0.0;
    graphParts.add(
      'equalizer@bass=f=80:width_type=o:w=2.0:g=${bassGain.toStringAsFixed(1)}',
    );

    if (graphParts.isEmpty) return '';
    return 'lavfi=[${graphParts.join(',')}]';
  }

  /// Resets all effects to default
  Future<void> resetAll() async {
    _eqEnabled = false;
    _bassBoost = 0.0;
    _speed = 1.0;
    _pitch = 1.0;
    for (int i = 0; i < bandCount; i++) {
      _eqGains[i] = 0.0;
    }
    await _player?.setRate(1.0);
    await _player?.setPitch(1.0);
    await _applyFilterChain();
    _saveSettings();
  }
}
