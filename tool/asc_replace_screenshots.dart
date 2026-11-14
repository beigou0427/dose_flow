import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
    if (locale != 'zh-Hant' && locale != 'en-US') continue;

    final http.Response setRes = await http.get(
      Uri.parse(
        '$baseUrl/v1/appStoreVersionLocalizations/$locId/appScreenshotSets?include=appScreenshots',
      ),
      headers: headers,
    );
    final Map<String, dynamic> setDec =
        jsonDecode(setRes.body) as Map<String, dynamic>;
    final List<dynamic> sets = (setDec['data'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> oldShots =
        (setDec['included'] as List<dynamic>?) ?? <dynamic>[];

    for (final dynamic os in oldShots) {
      final String oldId = (os as Map<String, dynamic>)['id'].toString();
      await http.delete(
        Uri.parse('$baseUrl/v1/appScreenshots/$oldId'),
        headers: headers,
      );
    }
    stdout.writeln('\n🧹 [$locale] 已清除 ${oldShots.length} 張舊概念圖');

    for (final dynamic s in sets) {
      final Map<String, dynamic> sm = s as Map<String, dynamic>;
      final String setId = sm['id'].toString();
      final String dtype =
          (sm['attributes'] as Map<String, dynamic>)['screenshotDisplayType']
              .toString();

      final List<String> files = dtype == 'APP_IPHONE_67'
          ? List<String>.generate(
              5,
              (int i) => 'tool/screenshots/${locale}_67_${i + 1}.jpg',
            )
          : <String>[
              'tool/screenshots/${locale}_duo_outer_1.jpg',
              'tool/screenshots/${locale}_duo_inner_1.jpg',
            ];

      for (final String path in files) {
        final Uint8List bytes = File(path).readAsBytesSync();
        final String md5Hex = Process.runSync('md5', <String>['-q', path])
            .stdout
            .toString()
            .trim();
        final http.Response res = await http.post(
          Uri.parse('$baseUrl/v1/appScreenshots'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'appScreenshots',
              'attributes': <String, dynamic>{
                'fileName': path.split('/').last,
                'fileSize': bytes.length,
              },
              'relationships': <String, dynamic>{
                'appScreenshotSet': <String, dynamic>{
                  'data': <String, dynamic>{
                    'type': 'appScreenshotSets',
                    'id': setId,
                  },
                },
              },
            },
          }),
        );
        if (res.statusCode != 201 && res.statusCode != 200) continue;
        final Map<String, dynamic> data =
            (jsonDecode(res.body) as Map<String, dynamic>)['data']
                as Map<String, dynamic>;
        final String shotId = data['id'].toString();
        final List<dynamic> ops = ((data['attributes']
                    as Map<String, dynamic>)['uploadOperations']
                as List<dynamic>?) ??
            <dynamic>[];
        for (final dynamic opRaw in ops) {
          final Map<String, dynamic> op = opRaw as Map<String, dynamic>;
          final int offset = (op['offset'] as num).toInt();
          final int length = (op['length'] as num).toInt();
          final Map<String, String> upHeaders = <String, String>{};
          for (final dynamic h
              in (op['requestHeaders'] as List<dynamic>? ?? <dynamic>[])) {
            final Map<String, dynamic> hm = h as Map<String, dynamic>;
            upHeaders[hm['name'].toString()] = hm['value'].toString();
          }
          await http.put(
            Uri.parse(op['url'].toString()),
            headers: upHeaders,
            body: bytes.sublist(offset, offset + length),
          );
        }
        await http.patch(
          Uri.parse('$baseUrl/v1/appScreenshots/$shotId'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'appScreenshots',
              'id': shotId,
              'attributes': <String, dynamic>{
                'sourceFileChecksum': md5Hex,
                'uploaded': true,
              },
            },
          }),
        );
        stdout.writeln('  🟢 [$locale / $dtype] 已上傳真機 UI 截圖: ${path.split('/').last}');
      }
    }
  }

  await Future<void>.delayed(const Duration(seconds: 6));
  stdout.writeln('\n🔍 驗貨 Apple 伺服器最新判定:');
  for (final dynamic l in locs) {
    final Map<String, dynamic> lm = l as Map<String, dynamic>;
    final String locId = lm['id'].toString();
    final String locale =
        (lm['attributes'] as Map<String, dynamic>)['locale'].toString();
    if (locale != 'zh-Hant' && locale != 'en-US') continue;
    final http.Response setRes = await http.get(
      Uri.parse(
        '$baseUrl/v1/appStoreVersionLocalizations/$locId/appScreenshotSets?include=appScreenshots',
      ),
      headers: headers,
    );
    final List<dynamic> shots =
        ((jsonDecode(setRes.body) as Map<String, dynamic>)['included']
                as List<dynamic>?) ??
            <dynamic>[];
    for (final dynamic sh in shots) {
      final Map<String, dynamic> attrs =
          (sh as Map<String, dynamic>)['attributes'] as Map<String, dynamic>;
      final Map<String, dynamic> ads =
          attrs['assetDeliveryState'] as Map<String, dynamic>? ??
              <String, dynamic>{};
      stdout.writeln('  • [$locale] ${attrs['fileName']} -> ${ads['state']}');
    }
  }

  stdout.writeln('\n🔍 診斷 Lifetime ($lifetimeId) 明細:');
  final http.Response iapRes = await http.get(
    Uri.parse(
      '$baseUrl/v2/inAppPurchases/$lifetimeId?include=inAppPurchaseLocalizations,appStoreReviewScreenshot',
    ),
    headers: headers,
  );
  if (iapRes.statusCode == 200) {
    final Map<String, dynamic> dec =
        jsonDecode(iapRes.body) as Map<String, dynamic>;
    stdout.writeln('  • attributes: ${(dec['data'] as Map<String, dynamic>)['attributes']}');
    for (final dynamic item in (dec['included'] as List<dynamic>? ?? <dynamic>[])) {
      final Map<String, dynamic> im = item as Map<String, dynamic>;
      stdout.writeln('  • ${im['type']}: ${im['attributes']}');
    }
  }
}
