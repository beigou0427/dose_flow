import 'package:flutter/foundation.dart';

/// =========================================================================
/// 【艾克羅夫與 HIPAA 精神實踐】零知識脫敏錯誤攔截引擎
/// =========================================================================
class ZeroKnowledgeCrashMonitor {
  ZeroKnowledgeCrashMonitor._();
  
  static final ZeroKnowledgeCrashMonitor instance = ZeroKnowledgeCrashMonitor._();
  bool _isInitialized = false;

  /// 【洗敏脫資正則】：安全標記取代 `(?i)`
  static final RegExp _piiStripperRegex = RegExp(
    r'(weight|kg|lbs|mg|dose|unit(s)?)\s*[:=]*\s*[0-9\.]+|tirzepatide|semaglutide|liraglutide|ozempic|mounjaro|wegovy|zepbound',
    caseSensitive: false,
  );
  
  static const String _safeRedactedLabel = '[HEALTH-DATA-REDACTED]';
  final List<String> _localAnonymousFaultQueue = <String>[];
  
  List<String> get currentAnonymousFaultLogs => List<String>.unmodifiable(_localAnonymousFaultQueue);

  void initializeGlobalHooks() {
    if (_isInitialized) return;
    final FlutterExceptionHandler? originalOnError = FlutterError.onError;

    FlutterError.onError = (FlutterErrorDetails details) {
      _interceptAndMask(
        errorPayload: details.exceptionAsString(),
        stackInfo: details.stack,
        faultContext: 'FlutterUI/RenderingError',
      );
      if (kDebugMode && originalOnError != null) originalOnError(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _interceptAndMask(
        errorPayload: error.toString(),
        stackInfo: stack,
        faultContext: 'DartPlatformAsyncError',
      );
      return true; // 生吞防止 OS 層強制閃退
    };

    _isInitialized = true;
  }

  void _interceptAndMask({
    required String errorPayload,
    StackTrace? stackInfo,
    required String faultContext,
  }) {
    try {
      final String sanitizedPayload = errorPayload.replaceAll(_piiStripperRegex, _safeRedactedLabel);
      final String briefStack = (stackInfo ?? StackTrace.empty).toString().split('\n').take(5).join('\n');
      final String isoTimestamp = DateTime.now().toIso8601String();
      final String safetyReport = '[$isoTimestamp][$faultContext] EX: $sanitizedPayload | TRC: $briefStack';

      if (_localAnonymousFaultQueue.length >= 20) {
        _localAnonymousFaultQueue.removeAt(0); 
      }
      _localAnonymousFaultQueue.add(safetyReport);

      if (kDebugMode) debugPrint('🥷 零知識隱私護盾啟用: $safetyReport');
    } catch (_) {} // 終極墜機靜默，斷尾自救！
  }
}