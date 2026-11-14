import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String keyId = '853IQM8TC6VX';
  const String lifetimeId = '6832587006';
  const String versionId = '277e9a5f-25ce-4e00-96e4-156eda75812c';
  const String baseUrl = 'https://api.appstoreconnect.apple.com';

  final String pem =
      '${File('./AuthKey_$keyId.p8').readAsStringSync().trim()}\n';
  final http.Response probe = await http.get(Uri.parse('$baseUrl/v1/apps'));
  final int epoch = (HttpDate.parse(probe.headers['date']!)
              .toUtc()
              .millisecondsSinceEpoch /
          1000)
      .floor();
  final String token = JWT(
    <String, dynamic>{
      'sub': 'user',
      'iat': epoch - 30,
      'exp': epoch + 1100,
      'aud': 'appstoreconnect-v1',
    },
    header: const <String, dynamic>{
      'alg': 'ES256',
      'kid': keyId,
      'typ': 'JWT',
    },
  ).sign(ECPrivateKey(pem), algorithm: JWTAlgorithm.ES256, noIssueAt: true);

  final Map<String, String> headers = <String, String>{
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  stdout.writeln('🔍 [1/2] 核驗 Apple 伺服器對 14 張截圖的真實判定 (COMPLETE vs FAILED):');
  final http.Response locRes = await http.get(
    Uri.parse(
      '$baseUrl/v1/appStoreVersions/$versionId/appStoreVersionLocalizations',
    ),
    headers: headers,
  );
  final List<dynamic> locs =
      ((jsonDecode(locRes.body) as Map<String, dynamic>)['data']
              as List<dynamic>?) ??
          <dynamic>[];

  for (final dynamic l in locs) {
    final Map<String, dynamic> lm = l as Map<String, dynamic>;
    final String locId = lm['id'].toString();
    final String locale =
        (lm['attributes'] as Map<String, dynamic>)['locale'].toString();
    final http.Response setRes = await http.get(
      Uri.parse(
        '$baseUrl/v1/appStoreVersionLocalizations/$locId/appScreenshotSets?include=appScreenshots',
      ),
      headers: headers,
    );
    final Map<String, dynamic> setDec =
        jsonDecode(setRes.body) as Map<String, dynamic>;
    final List<dynamic> sets = (setDec['data'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> shots =
        (setDec['included'] as List<dynamic>?) ?? <dynamic>[];

    stdout.writeln('\n  🌐 [$locale] 共 ${sets.length} 組 / ${shots.length} 張:');
    for (final dynamic sh in shots) {
      final Map<String, dynamic> shm = sh as Map<String, dynamic>;
      final Map<String, dynamic> attrs =
          shm['attributes'] as Map<String, dynamic>;
      final String fname = attrs['fileName'].toString();
      final Map<String, dynamic> ads =
          attrs['assetDeliveryState'] as Map<String, dynamic>? ??
              <String, dynamic>{};
      final String state = ads['state']?.toString() ?? 'UNKNOWN';
      final List<dynamic> errs =
          ads['errors'] as List<dynamic>? ?? <dynamic>[];
      final List<dynamic> warns =
          ads['warnings'] as List<dynamic>? ?? <dynamic>[];
      stdout.writeln(
        '    • $fname -> $state${errs.isNotEmpty ? " | 錯誤: $errs" : ""}${warns.isNotEmpty ? " | 警告: $warns" : ""}',
      );
    }
  }

  stdout.writeln('\n🔍 [2/2] 深度體檢終身版 IAP ($lifetimeId) 為何仍是 MISSING_METADATA:');
  final http.Response iapRes = await http.get(
    Uri.parse(
      '$baseUrl/v2/inAppPurchases/$lifetimeId?include=inAppPurchaseLocalizations,appStoreReviewScreenshot,iapPriceSchedule,inAppPurchaseAvailability',
    ),
    headers: headers,
  );
  if (iapRes.statusCode == 200) {
    final Map<String, dynamic> dec =
        jsonDecode(iapRes.body) as Map<String, dynamic>;
    final Map<String, dynamic> data = dec['data'] as Map<String, dynamic>;
    final Map<String, dynamic> attrs =
        data['attributes'] as Map<String, dynamic>;
    final List<dynamic> inc =
        dec['included'] as List<dynamic>? ?? <dynamic>[];
    final Map<String, int> counts = <String, int>{};
    for (final dynamic item in inc) {
      final String t = (item as Map<String, dynamic>)['type'].toString();
      counts[t] = (counts[t] ?? 0) + 1;
    }
    stdout.writeln('  • state: ${attrs['state']}');
    stdout.writeln('  • reviewNote: ${attrs['reviewNote']}');
    stdout.writeln('  • 已掛載子項目統計: $counts');
  }
}
