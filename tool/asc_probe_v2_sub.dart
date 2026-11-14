import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String keyId = '853IQM8TC6VX';
  const String subId = '35d3b2fa-9c25-44f2-a81b-a8685c4f92be';
  const String annualId = '6832587209';
  const String monthlyId = '6832586893';
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

  final http.Response itemsRes = await http.get(
    Uri.parse('$baseUrl/v1/reviewSubmissions/$subId/items'),
    headers: headers,
  );
  stdout.writeln('🔍 [1/4] 送審單 $subId 內含項目 [${itemsRes.statusCode}]:\n${itemsRes.body}');

  for (final String sid in <String>[annualId, monthlyId]) {
    final http.Response svRes = await http.get(
      Uri.parse('$baseUrl/v1/subscriptions/$sid/subscriptionVersions'),
      headers: headers,
    );
    stdout.writeln('\n🔍 [2/4] 訂閱 $sid subscriptionVersions [${svRes.statusCode}]:\n${svRes.body}');
  }

  final http.Response ivRes = await http.get(
    Uri.parse('$baseUrl/v2/inAppPurchases/$lifetimeId/inAppPurchaseVersions'),
    headers: headers,
  );
  stdout.writeln('\n🔍 [3/4] 終身版 $lifetimeId inAppPurchaseVersions [${ivRes.statusCode}]:\n${ivRes.body}');
}
