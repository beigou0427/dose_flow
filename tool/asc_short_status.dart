import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String keyId = '853IQM8TC6VX';
  const String appId = '6832583172';
  const String baseUrl = 'https://api.appstoreconnect.apple.com';
  final String pem = '${File('./AuthKey_$keyId.p8').readAsStringSync().trim()}\n';
  final http.Response probe = await http.get(Uri.parse('$baseUrl/v1/apps'));
  final int epoch = (HttpDate.parse(probe.headers['date']!).toUtc().millisecondsSinceEpoch / 1000).floor();
  final String token = JWT(
    <String, dynamic>{'sub': 'user', 'iat': epoch - 30, 'exp': epoch + 1100, 'aud': 'appstoreconnect-v1'},
    header: const <String, dynamic>{'alg': 'ES256', 'kid': keyId, 'typ': 'JWT'},
  ).sign(ECPrivateKey(pem), algorithm: JWTAlgorithm.ES256, noIssueAt: true);
  final Map<String, String> h = <String, String>{'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

  final http.Response vRes = await http.get(Uri.parse('$baseUrl/v1/apps/$appId/appStoreVersions?filter[platform]=IOS'), headers: h);
  for (final dynamic v in ((jsonDecode(vRes.body) as Map<String, dynamic>)['data'] as List<dynamic>? ?? <dynamic>[])) {
    final Map<String, dynamic> a = (v as Map<String, dynamic>)['attributes'] as Map<String, dynamic>;
    stdout.writeln('📱 Version ${a['versionString']} -> ${a['appStoreState']}');
  }

  final http.Response lRes = await http.get(Uri.parse('$baseUrl/v2/inAppPurchases/6832587006?include=versions'), headers: h);
  final Map<String, dynamic> lDec = jsonDecode(lRes.body) as Map<String, dynamic>;
  final String lState = (lDec['data'] as Map<String, dynamic>)['attributes']['state'].toString();
  final String lVerState = ((lDec['included'] as List<dynamic>?)?.firstOrNull as Map<String, dynamic>?)?['attributes']?['state']?.toString() ?? '-';
  stdout.writeln('💎 Lifetime -> $lState (ver: $lVerState)');

  for (final String sid in <String>['6832587209', '6832586893']) {
    final http.Response sRes = await http.get(Uri.parse('$baseUrl/v1/subscriptions/$sid?include=versions'), headers: h);
    final Map<String, dynamic> sDec = jsonDecode(sRes.body) as Map<String, dynamic>;
    final Map<String, dynamic> sa = (sDec['data'] as Map<String, dynamic>)['attributes'] as Map<String, dynamic>;
    final String svState = ((sDec['included'] as List<dynamic>?)?.firstOrNull as Map<String, dynamic>?)?['attributes']?['state']?.toString() ?? '-';
    stdout.writeln('🔥 ${sa['productId']} -> ${sa['state']} (ver: $svState)');
  }

  final http.Response rRes = await http.get(Uri.parse('$baseUrl/v1/apps/$appId/reviewSubmissions'), headers: h);
  for (final dynamic r in ((jsonDecode(rRes.body) as Map<String, dynamic>)['data'] as List<dynamic>? ?? <dynamic>[])) {
    final Map<String, dynamic> rm = r as Map<String, dynamic>;
    final Map<String, dynamic> ra = rm['attributes'] as Map<String, dynamic>;
    if (ra['state'] != 'CANCELED') {
      stdout.writeln('📋 Submission ${rm['id']} -> ${ra['state']}');
    }
  }
}
