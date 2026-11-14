import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String keyId = '853IQM8TC6VX';
  const String appId = '6832583172';
  const String versionId = '277e9a5f-25ce-4e00-96e4-156eda75812c';
  const String baseUrl = 'https://api.appstoreconnect.apple.com';

  final String pem =
      '${File('./AuthKey_$keyId.p8').readAsStringSync().trim()}\n';
  final http.Response probe = await http.get(Uri.parse('$baseUrl/v1/apps'));
  final int epoch = (HttpDate.parse(probe.headers['date']!).toUtc()
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

  stdout.writeln('🔍 [1/3] 檢查訂閱商品狀態、雙語文案與審核截圖掃描進度...');
  final http.Response grpRes = await http.get(
    Uri.parse('$baseUrl/v1/apps/$appId/subscriptionGroups'),
    headers: headers,
  );
  final List<dynamic> groups =
      ((jsonDecode(grpRes.body) as Map<String, dynamic>)['data']
              as List<dynamic>?) ??
          <dynamic>[];
  for (final dynamic g in groups) {
    final String gId = (g as Map<String, dynamic>)['id'].toString();
    final http.Response subRes = await http.get(
      Uri.parse(
        '$baseUrl/v1/subscriptionGroups/$gId/subscriptions?include=subscriptionLocalizations,appStoreReviewScreenshot',
      ),
      headers: headers,
    );
    final Map<String, dynamic> subDec =
        jsonDecode(subRes.body) as Map<String, dynamic>;
    final List<dynamic> subs =
        (subDec['data'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> included =
        (subDec['included'] as List<dynamic>?) ?? <dynamic>[];

    for (final dynamic s in subs) {
      final Map<String, dynamic> sm = s as Map<String, dynamic>;
      final String subId = sm['id'].toString();
      final Map<String, dynamic> attrs =
          sm['attributes'] as Map<String, dynamic>;
      final String pid = attrs['productId'].toString();
      final String state = attrs['state'].toString();

      final Set<String> locales = <String>{};
      String ssState = 'NONE';
      for (final dynamic inc in included) {
        final Map<String, dynamic> im = inc as Map<String, dynamic>;
        if (im['type'] == 'subscriptionLocalizations') {
          final Map<String, dynamic>? relSub =
              ((im['relationships'] as Map<String, dynamic>?)?['subscription']
                  as Map<String, dynamic>?)?['data'] as Map<String, dynamic>?;
          if (relSub != null && relSub['id'] == subId) {
            locales.add((im['attributes'] as Map<String, dynamic>)['locale']
                .toString());
          }
        } else if (im['type'] == 'subscriptionAppStoreReviewScreenshots') {
          final Map<String, dynamic>? relSub =
              ((im['relationships'] as Map<String, dynamic>?)?['subscription']
                  as Map<String, dynamic>?)?['data'] as Map<String, dynamic>?;
          if (relSub != null && relSub['id'] == subId) {
            final Map<String, dynamic>? ads =
                (im['attributes'] as Map<String, dynamic>)['assetDeliveryState']
                    as Map<String, dynamic>?;
            ssState = ads?['state']?.toString() ?? 'UNKNOWN';
          }
        }
      }
      stdout.writeln(
        '  • $pid | 狀態: $state | 語系: $locales | 截圖掃描: $ssState',
      );
    }
  }

  stdout.writeln('\n🔍 [2/3] 檢查終身版 IAP 狀態與審核截圖掃描進度...');
  final http.Response iapRes = await http.get(
    Uri.parse(
      '$baseUrl/v1/apps/$appId/inAppPurchasesV2?include=inAppPurchaseLocalizations,appStoreReviewScreenshot',
    ),
    headers: headers,
  );
  final Map<String, dynamic> iapDec =
      jsonDecode(iapRes.body) as Map<String, dynamic>;
  final List<dynamic> iaps = (iapDec['data'] as List<dynamic>?) ?? <dynamic>[];
  final List<dynamic> iapInc =
      (iapDec['included'] as List<dynamic>?) ?? <dynamic>[];
  for (final dynamic i in iaps) {
    final Map<String, dynamic> im = i as Map<String, dynamic>;
    final String iapId = im['id'].toString();
    final Map<String, dynamic> attrs = im['attributes'] as Map<String, dynamic>;
    final Set<String> locales = <String>{};
    String ssState = 'NONE';
    for (final dynamic inc in iapInc) {
      final Map<String, dynamic> m = inc as Map<String, dynamic>;
      if (m['type'] == 'inAppPurchaseLocalizations') {
        locales.add(
            (m['attributes'] as Map<String, dynamic>)['locale'].toString());
      } else if (m['type'] == 'inAppPurchaseAppStoreReviewScreenshots') {
        final Map<String, dynamic>? ads =
            (m['attributes'] as Map<String, dynamic>)['assetDeliveryState']
                as Map<String, dynamic>?;
        ssState = ads?['state']?.toString() ?? 'UNKNOWN';
      }
    }
    stdout.writeln(
      '  • ${attrs['productId']} ($iapId) | 狀態: ${attrs['state']} | 語系: $locales | 截圖掃描: $ssState',
    );
  }

  stdout.writeln('\n🔍 [3/3] 檢查 Version 1.0 App Store 螢幕截圖與審查聯絡人...');
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
    stdout.writeln(
      '  • [$locale] 截圖群組數: ${sets.length} | 已上傳螢幕截圖張數: ${shots.length}',
    );
  }

  final http.Response revRes = await http.get(
    Uri.parse('$baseUrl/v1/appStoreVersions/$versionId/appStoreReviewDetail'),
    headers: headers,
  );
  final dynamic revData =
      (jsonDecode(revRes.body) as Map<String, dynamic>)['data'];
  if (revData is Map<String, dynamic>) {
    final Map<String, dynamic> ra =
        revData['attributes'] as Map<String, dynamic>;
    stdout.writeln(
      '  • 審查聯絡人: ${ra['contactFirstName']} ${ra['contactLastName']} | ${ra['contactEmail']} | ${ra['contactPhone']}',
    );
  }
}
