import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String keyId = '853IQM8TC6VX';
  const String appId = '6832583172';
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

  final http.Response infoRes = await http.get(
    Uri.parse('$baseUrl/v1/apps/$appId/appInfos'),
    headers: headers,
  );
  final String appInfoId =
      (((jsonDecode(infoRes.body) as Map<String, dynamic>)['data']
              as List<dynamic>)
          .first as Map<String, dynamic>)['id']
          .toString();

  final http.Response locRes = await http.get(
    Uri.parse('$baseUrl/v1/appInfos/$appInfoId/appInfoLocalizations'),
    headers: headers,
  );
  for (final dynamic item
      in ((jsonDecode(locRes.body) as Map<String, dynamic>)['data']
              as List<dynamic>? ??
          <dynamic>[])) {
    final Map<String, dynamic> map = item as Map<String, dynamic>;
    final Map<String, dynamic> attrs =
        map['attributes'] as Map<String, dynamic>;
    if (attrs['locale'] == 'zh-Hant') {
      final String locId = map['id'].toString();
      final http.Response patchRes = await http.patch(
        Uri.parse('$baseUrl/v1/appInfoLocalizations/$locId'),
        headers: headers,
        body: jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'type': 'appInfoLocalizations',
            'id': locId,
            'attributes': const <String, dynamic>{
              'name': '瘦瘦針紀錄 Pro - GLP-1 半衰期',
              'subtitle': '雙指數代謝曲線,防掉肌與部位輪替',
            },
          },
        }),
      );
      stdout.writeln(
        '🟢 zh-Hant 標題/副標去商標化完成 [${patchRes.statusCode}]: 瘦瘦針紀錄 Pro - GLP-1 半衰期',
      );
    }
  }
}
