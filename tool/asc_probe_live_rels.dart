import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String keyId = '853IQM8TC6VX';
  const String appId = '6832583172';
  const String annualId = '6832587209';
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
  };

  final http.Response rsRes = await http.get(
    Uri.parse('$baseUrl/v1/apps/$appId/reviewSubmissions?include=items'),
    headers: headers,
  );
  stdout.writeln('🔍 [1/4] 線上所有 ReviewSubmissions:\n${rsRes.body}');

  final http.Response subRes = await http.get(
    Uri.parse('$baseUrl/v1/subscriptions/$annualId'),
    headers: headers,
  );
  if (subRes.statusCode == 200) {
    final Map<String, dynamic> dec =
        jsonDecode(subRes.body) as Map<String, dynamic>;
    final Map<String, dynamic> rels =
        (dec['data'] as Map<String, dynamic>)['relationships']
            as Map<String, dynamic>;
    stdout.writeln('\n🔍 [2/4] Subscription relationships: ${rels.keys.toList()}');
  }

  final http.Response grpRes = await http.get(
    Uri.parse('$baseUrl/v1/apps/$appId/subscriptionGroups'),
    headers: headers,
  );
  if (grpRes.statusCode == 200) {
    final List<dynamic> list =
        ((jsonDecode(grpRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>?) ??
            <dynamic>[];
    if (list.isNotEmpty) {
      final Map<String, dynamic> g = list.first as Map<String, dynamic>;
      stdout.writeln(
        '\n🔍 [3/4] SubscriptionGroup (${g['id']}) relationships: ${(g['relationships'] as Map<String, dynamic>).keys.toList()}',
      );
    }
  }

  final http.Response iapRes = await http.get(
    Uri.parse('$baseUrl/v2/inAppPurchases/$lifetimeId'),
    headers: headers,
  );
  if (iapRes.statusCode == 200) {
    final Map<String, dynamic> dec =
        jsonDecode(iapRes.body) as Map<String, dynamic>;
    final Map<String, dynamic> rels =
        (dec['data'] as Map<String, dynamic>)['relationships']
            as Map<String, dynamic>;
    stdout.writeln('\n🔍 [4/4] InAppPurchaseV2 relationships: ${rels.keys.toList()}');
  }
}
