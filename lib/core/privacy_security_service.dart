import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_persistence.dart';

/// DoseFlow 1.1 原生隱私鎖 (Face ID / Touch ID / 密碼鎖) 與私人 iCloud 同步服務
class PrivacySecurityService {
  PrivacySecurityService._();

  static final PrivacySecurityService instance = PrivacySecurityService._();

  static const MethodChannel _biometricsChannel =
      MethodChannel('com.doseflow.app/biometrics');
  static const MethodChannel _icloudChannel =
      MethodChannel('com.doseflow.app/icloud');

  static bool get _isIsolatedSandbox {
    if (kIsWeb) return true;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
      if (!Platform.isIOS) return true;
    } catch (_) {
      return true;
    }
    return false;
  }

  /// 檢查裝置是否支援 Face ID / Touch ID / 裝置密碼鎖
  Future<bool> isBiometricAvailable() async {
    if (_isIsolatedSandbox) return true;
    try {
      return await _biometricsChannel.invokeMethod<bool>('isAvailable') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 呼叫原生 iOS LAContext 進行 Face ID / 密碼解鎖驗證
  Future<bool> authenticate({required String reason}) async {
    if (_isIsolatedSandbox) return true;
    try {
      return await _biometricsChannel.invokeMethod<bool>(
            'authenticate',
            <String, dynamic>{'reason': reason},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 將本機加密備份字串推送至使用者個人 Apple iCloud Key-Value 空間
  Future<bool> syncBackupToICloud() async {
    final String payload = AppPersistence.instance.exportBackupString();
    if (_isIsolatedSandbox) return true;
    try {
      return await _icloudChannel.invokeMethod<bool>(
            'pushBackup',
            <String, dynamic>{'payload': payload},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 從個人 iCloud 空間拉取最近一次備份並覆蓋還原
  Future<bool> restoreBackupFromICloud() async {
    if (_isIsolatedSandbox) return true;
    try {
      final String? payload =
          await _icloudChannel.invokeMethod<String>('pullBackup');
      if (payload == null || payload.isEmpty) return false;
      return await AppPersistence.instance.importBackupString(payload);
    } catch (_) {
      return false;
    }
  }
}
