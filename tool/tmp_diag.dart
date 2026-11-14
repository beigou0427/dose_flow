import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String keyId = '853IQM8TC6VX';
  const String lifetimeId = '6832587006';
  const String baseUrl = 'https://api.appstoreconnect.apple.com';
  final String pem = '${File('./AuthKey_$keyId.p8').readAsStringSync().trim()}\n';
  final http.Response probe = await http.get(Uri.parse('$baseUrl/v1/apps'));
  final int epoch = (HttpDate.parse(probe.headers['date']!).toUtc().millisecondsSinceEpoch / 1000).floor();
  final String token = JWT(
    <String, dynamic>{'sub': 'user', 'iat': epoch - 30, 'exp': epoch + 1100, 'aud': 'appstoreconnect-v1'},
    header: const <String, dynamic>{'alg': 'ES256', 'kid': keyId, 'typ': 'JWT'},
  ).sign(ECPrivateKey(pem), algorithm: JWTAlgorithm.ES256, noIssueAt: true);
  final Map<String, String> headers = <String, String>{'Authorization': 'Bearer $token'};

  final http.Response psRes = await http.get(
    Uri.parse('$baseUrl/v2/inAppPurchases/$lifetimeId/iapPriceSchedule?include=manualPrices,baseTerritory'),
    headers: headers,
  );
  stdout.writeln('🔍 Lifetime PriceSchedule [${psRes.statusCode}]: ${psRes.body}');

  final http.Response avRes = await http.get(
    Uri.parse('$baseUrl/v2/inAppPurchases/$lifetimeId/inAppPurchaseAvailability'),
    headers: headers,
  );
  stdout.writeln('🔍 Lifetime Availability [${avRes.statusCode}]: ${avRes.body}');
}
