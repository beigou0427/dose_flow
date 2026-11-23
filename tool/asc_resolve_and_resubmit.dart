import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String keyId = '853IQM8TC6VX';
  const String subId = '0d07e7cb-3918-4b7b-8683-86f2f7dae834';
  const String baseUrl = 'https://api.appstoreconnect.apple.com';
  final String pem = '${File('./AuthKey_$keyId.p8').readAsStringSync().trim()}\n';
  final http.Response probe = await http.get(Uri.parse('$baseUrl/v1/apps'));
  final int epoch = (HttpDate.parse(probe.headers['date']!).toUtc().millisecondsSinceEpoch / 1000).floor();
  final String token = JWT(
    <String, dynamic>{'sub': 'user', 'iat': epoch - 30, 'exp': epoch + 1100, 'aud': 'appstoreconnect-v1'},
    header: const <String, dynamic>{'alg': 'ES256', 'kid': keyId, 'typ': 'JWT'},
  ).sign(ECPrivateKey(pem), algorithm: JWTAlgorithm.ES256, noIssueAt: true);
  final Map<String, String> h = <String, String>{'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

  final http.Response itemsRes = await http.get(Uri.parse('$baseUrl/v1/reviewSubmissions/$subId/items'), headers: h);
  final List<dynamic> items = ((jsonDecode(itemsRes.body) as Map<String, dynamic>)['data'] as List<dynamic>?) ?? <dynamic>[];
  for (final dynamic it in items) {
    final Map<String, dynamic> m = it as Map<String, dynamic>;
    final String itemId = m['id'].toString();
    final String st = (m['attributes'] as Map<String, dynamic>)['state'].toString();
    stdout.writeln('• Item $itemId -> $st');
    if (st != 'READY_FOR_REVIEW') {
      final http.Response pr = await http.patch(
        Uri.parse('$baseUrl/v1/reviewSubmissionItems/$itemId'),
        headers: h,
        body: jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{'type': 'reviewSubmissionItems', 'id': itemId, 'attributes': const <String, dynamic>{'resolved': true}},
        }),
      );
      stdout.writeln('  ‣ 標記 resolved [${pr.statusCode}]');
    }
  }

  final http.Response subPatch = await http.patch(
    Uri.parse('$baseUrl/v1/reviewSubmissions/$subId'),
    headers: h,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{'type': 'reviewSubmissions', 'id': subId, 'attributes': const <String, dynamic>{'submitted': true}},
    }),
  );
  if (subPatch.statusCode == 200) {
    stdout.writeln('🟢 已重新送審成功 (WAITING_FOR_REVIEW)！');
  } else {
    stderr.writeln('⚠️ 重送回應 [${subPatch.statusCode}]: ${subPatch.body}');
  }
}
