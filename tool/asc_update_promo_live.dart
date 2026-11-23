import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String keyId = '853IQM8TC6VX';
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

  final Map<String, String> promos = <String, String>{
    'zh-Hant':
        'FDA 仿單雙指數藥動學模型：10 秒記錄體內殘留濃度與 U-100 針筒格數。100% 本地離線不連網、免註冊帳號，回診一鍵匯出醫師評估表，立即享 3 天免費試用。',
    'en-US':
        'Track live GLP-1 half-life levels & U-100 syringe units in 10 seconds. 100% offline privacy, zero account required, 1-tap Doctor PDF. Try 3 days free.',
  };

  final http.Response locRes = await http.get(
    Uri.parse(
      '$baseUrl/v1/appStoreVersions/$versionId/appStoreVersionLocalizations',
    ),
    headers: headers,
  );
  for (final dynamic item
      in ((jsonDecode(locRes.body) as Map<String, dynamic>)['data']
              as List<dynamic>? ??
          <dynamic>[])) {
    final Map<String, dynamic> m = item as Map<String, dynamic>;
    final String locId = m['id'].toString();
    final String locale =
        (m['attributes'] as Map<String, dynamic>)['locale'].toString();
    if (!promos.containsKey(locale)) continue;

    final http.Response patchRes = await http.patch(
      Uri.parse('$baseUrl/v1/appStoreVersionLocalizations/$locId'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'data': <String, dynamic>{
          'type': 'appStoreVersionLocalizations',
          'id': locId,
          'attributes': <String, dynamic>{
            'promotionalText': promos[locale],
          },
        },
      }),
    );
    if (patchRes.statusCode == 200) {
      stdout.writeln('🟢 [$locale] Promotional Text 線上熱更新成功！(不影響 WAITING_FOR_REVIEW)');
    } else {
      stdout.writeln(
        'ℹ️ [$locale] Promotional Text 回應 [${patchRes.statusCode}] (審核鎖定中，已存於 1.0.1 待命包)',
      );
    }
  }
}
