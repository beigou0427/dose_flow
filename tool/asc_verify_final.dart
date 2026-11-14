import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String keyId = '853IQM8TC6VX';
  const String appId = '6832583172';
  const String lifetimeId = '6832587006';
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

  final http.Response verRes = await http.get(
    Uri.parse('$baseUrl/v1/apps/$appId/appStoreVersions?filter[platform]=IOS'),
    headers: headers,
  );
  for (final dynamic v
      in ((jsonDecode(verRes.body) as Map<String, dynamic>)['data']
              as List<dynamic>? ??
          <dynamic>[])) {
    final Map<String, dynamic> attrs =
        (v as Map<String, dynamic>)['attributes'] as Map<String, dynamic>;
    stdout.writeln(
      '📱 App Version ${attrs['versionString']} 狀態 -> ${attrs['appStoreState']}',
    );
  }

  final http.Response lifeRes = await http.get(
    Uri.parse('$baseUrl/v2/inAppPurchases/$lifetimeId'),
    headers: headers,
  );
  if (lifeRes.statusCode == 200) {
    final Map<String, dynamic> attrs = ((jsonDecode(lifeRes.body)
            as Map<String, dynamic>)['data'] as Map<String, dynamic>)['attributes']
        as Map<String, dynamic>;
    stdout.writeln(
      '💎 ${attrs['productId']} 狀態 -> ${attrs['state']}',
    );
  }

  final http.Response grpRes = await http.get(
    Uri.parse('$baseUrl/v1/apps/$appId/subscriptionGroups'),
    headers: headers,
  );
  for (final dynamic g
      in ((jsonDecode(grpRes.body) as Map<String, dynamic>)['data']
              as List<dynamic>? ??
          <dynamic>[])) {
    final String gId = (g as Map<String, dynamic>)['id'].toString();
    final http.Response subRes = await http.get(
      Uri.parse('$baseUrl/v1/subscriptionGroups/$gId/subscriptions'),
      headers: headers,
    );
    for (final dynamic s
        in ((jsonDecode(subRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>? ??
            <dynamic>[])) {
      final Map<String, dynamic> sm = s as Map<String, dynamic>;
      final String subId = sm['id'].toString();
      final Map<String, dynamic> attrs =
          sm['attributes'] as Map<String, dynamic>;
      stdout.writeln(
        '🔥 ${attrs['productId']} 狀態 -> ${attrs['state']}',
      );
      if (attrs['state'] == 'READY_TO_SUBMIT') {
        final http.Response sr = await http.post(
          Uri.parse('$baseUrl/v1/subscriptionSubmissions'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'subscriptionSubmissions',
              'relationships': <String, dynamic>{
                'subscription': <String, dynamic>{
                  'data': <String, dynamic>{
                    'type': 'subscriptions',
                    'id': subId,
                  },
                },
              },
            },
          }),
        );
        stdout.writeln('  ‣ 訂閱提交明細 [${sr.statusCode}]: ${sr.body}');
      }
    }
  }
}
