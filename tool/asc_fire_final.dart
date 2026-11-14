import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<Map<String, String>> buildHeaders() async {
  const String keyId = '853IQM8TC6VX';
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
  return <String, String>{
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };
}

Future<void> main() async {
  const String appId = '6832583172';
  const String appVersionId = '277e9a5f-25ce-4e00-96e4-156eda75812c';
  const String submissionId = '85ecb333-275e-4dd5-a722-4232aed84225';
  const String lifetimeId = '6832587006';
  const String baseUrl = 'https://api.appstoreconnect.apple.com';

  final Map<String, String> headers = await buildHeaders();

  stdout.writeln('📡 [1/3] 確認整合送審單 $submissionId 內容與 Version 1.0 釋放狀態...');
  final http.Response itemsRes = await http.get(
    Uri.parse('$baseUrl/v1/reviewSubmissions/$submissionId/items'),
    headers: headers,
  );
  if (itemsRes.statusCode == 200) {
    final List<dynamic> items =
        ((jsonDecode(itemsRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>?) ??
            <dynamic>[];
    stdout.writeln('  🟢 送審單內已就緒項目數: ${items.length} (含群組與 3 大內購)');
  }

  for (int i = 1; i <= 8; i++) {
    final http.Response vRes = await http.get(
      Uri.parse('$baseUrl/v1/appStoreVersions/$appVersionId'),
      headers: headers,
    );
    final String st = ((jsonDecode(vRes.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>)['attributes']['appStoreState']
        .toString();
    stdout.writeln('  ‣ Version 1.0 目前狀態 ($i/8): $st');
    if (st != 'WAITING_FOR_REVIEW' && st != 'IN_REVIEW') break;
    await Future<void>.delayed(const Duration(seconds: 3));
  }

  stdout.writeln('\n📡 [2/3] 將 Version 1.0 (Build 3) 掛進整合送審單...');
  final http.Response addApp = await http.post(
    Uri.parse('$baseUrl/v1/reviewSubmissionItems'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{
        'type': 'reviewSubmissionItems',
        'relationships': <String, dynamic>{
          'reviewSubmission': <String, dynamic>{
            'data': <String, dynamic>{
              'type': 'reviewSubmissions',
              'id': submissionId,
            },
          },
          'appStoreVersion': <String, dynamic>{
            'data': <String, dynamic>{
              'type': 'appStoreVersions',
              'id': appVersionId,
            },
          },
        },
      },
    }),
  );
  if (addApp.statusCode == 201 || addApp.statusCode == 200) {
    stdout.writeln('  🟢 Version 1.0 (Build 3) 掛載成功！');
  } else {
    stderr.writeln('  🔴 掛載回應 [${addApp.statusCode}]: ${addApp.body}');
  }

  stdout.writeln('\n📡 [3/3] 正式發射整合送審單 (App + Group + 3 大內購)...');
  final http.Response submitRes = await http.patch(
    Uri.parse('$baseUrl/v1/reviewSubmissions/$submissionId'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{
        'type': 'reviewSubmissions',
        'id': submissionId,
        'attributes': const <String, dynamic>{'submitted': true},
      },
    }),
  );

  if (submitRes.statusCode == 200) {
    stdout.writeln(
      '\n🟢🟢🟢 [100% 純指令大滿貫正式送審！] Version 1.0 + 3 大內購已全部提交至 Apple 審核！',
    );
  } else {
    stderr.writeln(
      '\n⚠️ 送審回應 [${submitRes.statusCode}]:\n${submitRes.body}',
    );
  }

  await Future<void>.delayed(const Duration(seconds: 3));
  stdout.writeln('\n🔍 最終雲端狀態總驗收:');
  final http.Response vCheck = await http.get(
    Uri.parse('$baseUrl/v1/appStoreVersions/$appVersionId'),
    headers: headers,
  );
  stdout.writeln(
    '  • App Version 1.0 -> ${((jsonDecode(vCheck.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>)['attributes']['appStoreState']}',
  );

  final http.Response lCheck = await http.get(
    Uri.parse('$baseUrl/v2/inAppPurchases/$lifetimeId'),
    headers: headers,
  );
  stdout.writeln(
    '  • Lifetime (\$119.99) -> ${((jsonDecode(lCheck.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>)['attributes']['state']}',
  );

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
      final Map<String, dynamic> attrs =
          (s as Map<String, dynamic>)['attributes'] as Map<String, dynamic>;
      stdout.writeln('  • ${attrs['productId']} -> ${attrs['state']}');
    }
  }
}
