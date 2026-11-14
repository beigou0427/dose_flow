import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String keyId = '853IQM8TC6VX';
  const String draftSubId = '85ecb333-275e-4dd5-a722-4232aed84225';
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

  final http.Response incRes = await http.get(
    Uri.parse('$baseUrl/v1/subscriptions/6832587209?include=versions'),
    headers: headers,
  );
  stdout.writeln('🔍 include=versions [${incRes.statusCode}]: ${incRes.body}');

  final http.Response addLife = await http.post(
    Uri.parse('$baseUrl/v1/reviewSubmissionItems'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{
        'type': 'reviewSubmissionItems',
        'relationships': <String, dynamic>{
          'reviewSubmission': <String, dynamic>{
            'data': <String, dynamic>{
              'type': 'reviewSubmissions',
              'id': draftSubId,
            },
          },
          'inAppPurchaseV2': <String, dynamic>{
            'data': <String, dynamic>{
              'type': 'inAppPurchases',
              'id': lifetimeId,
            },
          },
        },
      },
    }),
  );
  stdout.writeln(
    '\n🔍 測試掛載 Lifetime (inAppPurchaseV2) 至草稿單 [${addLife.statusCode}]:\n${addLife.body}',
  );
}
