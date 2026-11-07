import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 支援的 Apple HealthKit 數據類型
enum HealthDataType {
  bodyMass('HKQuantityTypeIdentifierBodyMass', 'kg'),
  dietaryProtein('HKQuantityTypeIdentifierDietaryProtein', 'g'),
  dietaryWater('HKQuantityTypeIdentifierDietaryWater', 'mL');

  const HealthDataType(this.identifier, this.defaultUnit);
  final String identifier;
  final String defaultUnit;
}

/// HealthKit 權限狀態枚舉
enum HealthAuthStatus {
  notDetermined,
  authorized,
  denied,
  restricted,
}

/// 健康數據樣本不可變載體
@immutable
class HealthDataSample {
  const HealthDataSample({
    required this.type,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.source = 'Apple Health',
  });

  final HealthDataType type;
  final double value;
  final String unit;
  final DateTime timestamp;
  final String source;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'identifier': type.identifier,
      'value': value,
      'unit': unit,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
    };
  }
}

/// Apple HealthKit 原生橋接與雙向同步引擎（符合 Apple HealthKit Review 規範）
class HealthKitService {
  HealthKitService._();

  static final HealthKitService instance = HealthKitService._();

  static const MethodChannel _channel =
      MethodChannel('com.doseflow.app/healthkit');

  HealthAuthStatus _authStatus = HealthAuthStatus.notDetermined;
  HealthAuthStatus get authStatus => _authStatus;

  /// 十大防雷鐵律 06：測試沙盒與 Web 環境物理絕緣保護盾
  static bool get _isShielded {
    if (kIsWeb) return true;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
    } catch (_) {
      return true;
    }
    return false;
  }

  /// 虛擬記憶體健康數據庫（供測試沙盒與非 iOS 開發平台使用）
  final Map<HealthDataType, List<HealthDataSample>> _virtualStore =
      <HealthDataType, List<HealthDataSample>>{
    HealthDataType.bodyMass: <HealthDataSample>[],
    HealthDataType.dietaryProtein: <HealthDataSample>[],
    HealthDataType.dietaryWater: <HealthDataSample>[],
  };

  /// 向 Apple HealthKit 請求體重、蛋白質與飲水之讀寫權限
  Future<HealthAuthStatus> requestAuthorization() async {
    if (_isShielded) {
      _authStatus = HealthAuthStatus.authorized;
      return _authStatus;
    }

    try {
      final String? result =
          await _channel.invokeMethod<String>('requestAuthorization', <String, dynamic>{
        'readTypes': HealthDataType.values.map((HealthDataType t) => t.identifier).toList(),
        'writeTypes': HealthDataType.values.map((HealthDataType t) => t.identifier).toList(),
      });
      if (result == 'authorized') {
        _authStatus = HealthAuthStatus.authorized;
      } else if (result == 'denied') {
        _authStatus = HealthAuthStatus.denied;
      } else {
        _authStatus = HealthAuthStatus.restricted;
      }
    } catch (_) {
      _authStatus = HealthAuthStatus.notDetermined;
    }
    return _authStatus;
  }

  /// 讀取 Apple Health 中最新的一筆體重紀錄 (kg)
  Future<double?> fetchLatestWeightKg() async {
    if (_isShielded) {
      final List<HealthDataSample> samples =
          _virtualStore[HealthDataType.bodyMass]!;
      if (samples.isNotEmpty) {
        return samples.last.value;
      }
      return null;
    }

    try {
      final double? weight = await _channel.invokeMethod<double>(
        'fetchLatestSample',
        <String, dynamic>{
          'identifier': HealthDataType.bodyMass.identifier,
        },
      );
      return weight;
    } catch (_) {
      return null;
    }
  }

  /// 讀取今日自 HealthKit 累計攝取的蛋白質 (g)
  Future<int> fetchTodayProteinGrams() async {
    if (_isShielded) {
      final List<HealthDataSample> samples =
          _virtualStore[HealthDataType.dietaryProtein]!;
      final DateTime now = DateTime.now();
      int total = 0;
      for (final HealthDataSample s in samples) {
        if (s.timestamp.year == now.year &&
            s.timestamp.month == now.month &&
            s.timestamp.day == now.day) {
          total += s.value.round();
        }
      }
      return total;
    }

    try {
      final int? protein = await _channel.invokeMethod<int>(
        'fetchTodayCumulative',
        <String, dynamic>{
          'identifier': HealthDataType.dietaryProtein.identifier,
        },
      );
      return protein ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 讀取今日自 HealthKit 累計的飲水量 (mL)
  Future<int> fetchTodayWaterMl() async {
    if (_isShielded) {
      final List<HealthDataSample> samples =
          _virtualStore[HealthDataType.dietaryWater]!;
      final DateTime now = DateTime.now();
      int total = 0;
      for (final HealthDataSample s in samples) {
        if (s.timestamp.year == now.year &&
            s.timestamp.month == now.month &&
            s.timestamp.day == now.day) {
          total += s.value.round();
        }
      }
      return total;
    }

    try {
      final int? water = await _channel.invokeMethod<int>(
        'fetchTodayCumulative',
        <String, dynamic>{
          'identifier': HealthDataType.dietaryWater.identifier,
        },
      );
      return water ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 雙向回寫體重紀錄至 Apple Health
  Future<bool> writeWeightSampleKg(double weightKg, DateTime timestamp) async {
    final HealthDataSample sample = HealthDataSample(
      type: HealthDataType.bodyMass,
      value: weightKg,
      unit: 'kg',
      timestamp: timestamp,
    );

    if (_isShielded) {
      _virtualStore[HealthDataType.bodyMass]!.add(sample);
      return true;
    }

    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'writeSample',
        sample.toMap(),
      );
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 雙向回寫飲水紀錄至 Apple Health
  Future<bool> writeWaterSampleMl(int waterMl, DateTime timestamp) async {
    final HealthDataSample sample = HealthDataSample(
      type: HealthDataType.dietaryWater,
      value: waterMl.toDouble(),
      unit: 'mL',
      timestamp: timestamp,
    );

    if (_isShielded) {
      _virtualStore[HealthDataType.dietaryWater]!.add(sample);
      return true;
    }

    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'writeSample',
        sample.toMap(),
      );
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 雙向回寫蛋白質紀錄至 Apple Health
  Future<bool> writeProteinSampleGrams(int proteinGrams, DateTime timestamp) async {
    final HealthDataSample sample = HealthDataSample(
      type: HealthDataType.dietaryProtein,
      value: proteinGrams.toDouble(),
      unit: 'g',
      timestamp: timestamp,
    );

    if (_isShielded) {
      _virtualStore[HealthDataType.dietaryProtein]!.add(sample);
      return true;
    }

    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'writeSample',
        sample.toMap(),
      );
      return success ?? false;
    } catch (_) {
      return false;
    }
  }
}

/// HealthKit 響應式自動同步中樞（繼承 ChangeNotifier，可與 UI 體重/微習慣無縫連動）
class HealthSyncController extends ChangeNotifier {
  HealthSyncController._();

  static final HealthSyncController instance = HealthSyncController._();

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  double? _latestSyncedWeightKg;
  int _todaySyncedProteinGrams = 0;
  int _todaySyncedWaterMl = 0;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  double? get latestSyncedWeightKg => _latestSyncedWeightKg;
  int get todaySyncedProteinGrams => _todaySyncedProteinGrams;
  int get todaySyncedWaterMl => _todaySyncedWaterMl;
  HealthAuthStatus get authStatus => HealthKitService.instance.authStatus;

  /// 執行全量雙向同步（拉取最新體重、當日蛋白質與飲水累計）
  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      if (authStatus != HealthAuthStatus.authorized) {
        await HealthKitService.instance.requestAuthorization();
      }

      final double? weight =
          await HealthKitService.instance.fetchLatestWeightKg();
      if (weight != null) {
        _latestSyncedWeightKg = weight;
      }

      _todaySyncedProteinGrams =
          await HealthKitService.instance.fetchTodayProteinGrams();
      _todaySyncedWaterMl =
          await HealthKitService.instance.fetchTodayWaterMl();
      _lastSyncTime = DateTime.now();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// 記錄並雙向同步體重至 HealthKit
  Future<bool> recordWeight(double weightKg, {DateTime? timestamp}) async {
    final DateTime time = timestamp ?? DateTime.now();
    final bool success =
        await HealthKitService.instance.writeWeightSampleKg(weightKg, time);
    if (success) {
      _latestSyncedWeightKg = weightKg;
      _lastSyncTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  /// 記錄並雙向同步飲水量至 HealthKit
  Future<bool> recordWater(int waterMl, {DateTime? timestamp}) async {
    final DateTime time = timestamp ?? DateTime.now();
    final bool success =
        await HealthKitService.instance.writeWaterSampleMl(waterMl, time);
    if (success) {
      _todaySyncedWaterMl += waterMl;
      _lastSyncTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  /// 記錄並雙向同步蛋白質攝取量至 HealthKit
  Future<bool> recordProtein(int proteinGrams, {DateTime? timestamp}) async {
    final DateTime time = timestamp ?? DateTime.now();
    final bool success = await HealthKitService.instance
        .writeProteinSampleGrams(proteinGrams, time);
    if (success) {
      _todaySyncedProteinGrams += proteinGrams;
      _lastSyncTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }
}
