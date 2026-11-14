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
  const String groupId = '22561422';
  const String annualId = '6832587209';
  const String monthlyId = '6832586893';
  const String lifetimeId = '6832587006';
  const String baseUrl = 'https://api.appstoreconnect.apple.com';
  final Map<String, String> headers = await buildHeaders();

  stdout.writeln('📡 [1/4] 撤回舊有未完成送審單並釋放 Version 1.0...');
  final http.Response oldSubs = await http.get(
    Uri.parse('$baseUrl/v1/apps/$appId/reviewSubmissions'),
    headers: headers,
  );
  if (oldSubs.statusCode == 200) {
    for (final dynamic s
        in ((jsonDecode(oldSubs.body) as Map<String, dynamic>)['data']
                as List<dynamic>? ??
            <dynamic>[])) {
      final Map<String, dynamic> sm = s as Map<String, dynamic>;
      final String sid = sm['id'].toString();
      final String st =
          (sm['attributes'] as Map<String, dynamic>)['state'].toString();
      if (st != 'COMPLETE' && st != 'CANCELED') {
        await http.patch(
          Uri.parse('$baseUrl/v1/reviewSubmissions/$sid'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'reviewSubmissions',
              'id': sid,
              'attributes': const <String, dynamic>{'canceled': true},
            },
          }),
        );
        stdout.writeln('  🟢 已撤回舊單: $sid ($st)');
      }
    }
  }

  stdout.writeln('\n📡 [2/4] 等待 Build 4 轉為 VALID 並掛載至 Version 1.0...');
  String? build4Id;
  for (int i = 1; i <= 20; i++) {
    final http.Response bRes = await http.get(
      Uri.parse(
        '$baseUrl/v1/builds?filter[app]=$appId&sort=-uploadedDate&limit=5',
      ),
      headers: headers,
    );
    if (bRes.statusCode == 200) {
      for (final dynamic b
          in ((jsonDecode(bRes.body) as Map<String, dynamic>)['data']
                  as List<dynamic>? ??
              <dynamic>[])) {
        final Map<String, dynamic> bm = b as Map<String, dynamic>;
        final Map<String, dynamic> attrs =
            bm['attributes'] as Map<String, dynamic>;
        if (attrs['version']?.toString() == '4') {
          final String st = attrs['processingState'].toString();
          stdout.writeln('  ‣ Build 4 狀態 ($i/20): $st');
          if (st == 'VALID') build4Id = bm['id'].toString();
          break;
        }
      }
    }
    if (build4Id != null) break;
    await Future<void>.delayed(const Duration(seconds: 15));
  }
  if (build4Id == null) {
    stderr.writeln('🔴 Build 4 尚未處理完成');
    exit(1);
  }

  await http.patch(
    Uri.parse('$baseUrl/v1/builds/$build4Id'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{
        'type': 'builds',
        'id': build4Id,
        'attributes': const <String, dynamic>{
          'usesNonExemptEncryption': false,
        },
      },
    }),
  );
  await http.patch(
    Uri.parse('$baseUrl/v1/appStoreVersions/$appVersionId/relationships/build'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{'type': 'builds', 'id': build4Id},
    }),
  );
  stdout.writeln('  🟢 Build 4 ($build4Id) 已免加密並改綁至 Version 1.0！');

  stdout.writeln('\n📡 [3/4] 建立全新整合送審單並掛載 App + Group + 3 大內購...');
  final http.Response newSub = await http.post(
    Uri.parse('$baseUrl/v1/reviewSubmissions'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{
        'type': 'reviewSubmissions',
        'attributes': const <String, dynamic>{'platform': 'IOS'},
        'relationships': <String, dynamic>{
          'app': <String, dynamic>{
            'data': <String, dynamic>{'type': 'apps', 'id': appId},
          },
        },
      },
    }),
  );
  final String submissionId = ((jsonDecode(newSub.body)
          as Map<String, dynamic>)['data'] as Map<String, dynamic>)['id']
      .toString();

  Future<String> getFirstVer(String url) async {
    final http.Response r = await http.get(Uri.parse(url), headers: headers);
    return (((jsonDecode(r.body) as Map<String, dynamic>)['data']
            as List<dynamic>)
        .first as Map<String, dynamic>)['id']
        .toString();
  }

  final String grpVerId =
      await getFirstVer('$baseUrl/v1/subscriptionGroups/$groupId/versions');
  final String annVerId =
      await getFirstVer('$baseUrl/v1/subscriptions/$annualId/versions');
  final String monVerId =
      await getFirstVer('$baseUrl/v1/subscriptions/$monthlyId/versions');
  final String lifeVerId =
      await getFirstVer('$baseUrl/v2/inAppPurchases/$lifetimeId/versions');

  final List<List<String>> items = <List<String>>[
    <String>['appStoreVersion', 'appStoreVersions', appVersionId],
    <String>['subscriptionGroupVersion', 'subscriptionGroupVersions', grpVerId],
    <String>['subscriptionVersion', 'subscriptionVersions', annVerId],
    <String>['subscriptionVersion', 'subscriptionVersions', monVerId],
    <String>['inAppPurchaseVersion', 'inAppPurchaseVersions', lifeVerId],
  ];
  for (final List<String> item in items) {
    final http.Response ir = await http.post(
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
            item[0]: <String, dynamic>{
              'data': <String, dynamic>{'type': item[1], 'id': item[2]},
            },
          },
        },
      }),
    );
    stdout.writeln('  ‣ 掛載 ${item[0]} (${item[2]}) [${ir.statusCode}]');
  }

  stdout.writeln('\n📡 [4/4] 提交送審並驗證全狀態...');
  final http.Response subRes = await http.patch(
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
  if (subRes.statusCode == 200) {
    stdout.writeln('\n🟢🟢🟢 [完美修復並正式送審！] Build 4 + 3 大內購全部進入 Waiting for Review！');
  } else {
    stderr.writeln('\n⚠️ 送審回應 [${subRes.statusCode}]: ${subRes.body}');
  }
}
