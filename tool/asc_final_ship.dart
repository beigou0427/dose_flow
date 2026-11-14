import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<Map<String, String>> getHeaders() async {
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
  const String versionId = '277e9a5f-25ce-4e00-96e4-156eda75812c';
  const String lifetimeId = '6832587006';
  const String baseUrl = 'https://api.appstoreconnect.apple.com';
  final Map<String, String> headers = await getHeaders();

  stdout.writeln('📡 [1/4] 檢查雲端 Build 2 (Xcode 27.2 / iOS 27.2 SDK) 狀態...');
  Future<Map<String, dynamic>?> findBuild2() async {
    final http.Response res = await http.get(
      Uri.parse(
        '$baseUrl/v1/builds?filter[app]=$appId&sort=-uploadedDate&limit=5',
      ),
      headers: headers,
    );
    if (res.statusCode != 200) return null;
    final List<dynamic> list =
        ((jsonDecode(res.body) as Map<String, dynamic>)['data']
                as List<dynamic>?) ??
            <dynamic>[];
    for (final dynamic b in list) {
      final Map<String, dynamic> bm = b as Map<String, dynamic>;
      final Map<String, dynamic> attrs =
          bm['attributes'] as Map<String, dynamic>;
      stdout.writeln(
        '  ‣ 雲端 Build ${attrs['version']} (ID: ${bm['id']} | 狀態: ${attrs['processingState']})',
      );
      if (attrs['version']?.toString() == '2') {
        return bm;
      }
    }
    return null;
  }

  Map<String, dynamic>? build2 = await findBuild2();
  if (build2 == null) {
    stdout.writeln('🚀 雲端尚未看到 Build 2，正在用 build/ios/ipa/dose_flow.ipa 補傳...');
    final ProcessResult up1 = Process.runSync('xcrun', <String>[
      'altool',
      '--upload-app',
      '--type',
      'ios',
      '-f',
      'build/ios/ipa/dose_flow.ipa',
      '--apiKey',
      'WC3YUQ44X5',
      '--apiIssuer',
      '7c8a4cba-398c-4e88-88bb-9252f72ecdc9',
    ]);
    stdout.writeln(up1.stdout.toString());
    if (up1.exitCode != 0) {
      stderr.writeln(up1.stderr.toString());
      final ProcessResult up2 = Process.runSync('xcrun', <String>[
        'altool',
        '--upload-app',
        '--type',
        'ios',
        '-f',
        'build/ios/ipa/dose_flow.ipa',
        '--apiKey',
        '853IQM8TC6VX',
        '--apiIssuer',
        '7c8a4cba-398c-4e88-88bb-9252f72ecdc9',
      ]);
      stdout.writeln(up2.stdout.toString());
      stderr.writeln(up2.stderr.toString());
    }
  }

  String? validBuild2Id;
  for (int i = 1; i <= 16; i++) {
    build2 = await findBuild2();
    if (build2 != null) {
      final String state = (build2['attributes']
              as Map<String, dynamic>)['processingState']
          .toString();
      if (state == 'VALID') {
        validBuild2Id = build2['id'].toString();
        break;
      }
    }
    stdout.writeln('  ⏳ 等待 Apple 驗證 Build 2 中 (第 $i/16 次，每 15 秒檢查)...');
    await Future<void>.delayed(const Duration(seconds: 15));
  }

  if (validBuild2Id == null) {
    stderr.writeln('🔴 Build 2 尚未轉為 VALID，請把上方 altool 訊息貼給我！');
    exit(1);
  }

  stdout.writeln('\n📡 [2/4] 免除加密宣告並把 Build 2 掛載至 Version 1.0...');
  await http.patch(
    Uri.parse('$baseUrl/v1/builds/$validBuild2Id'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{
        'type': 'builds',
        'id': validBuild2Id,
        'attributes': const <String, dynamic>{
          'usesNonExemptEncryption': false,
        },
      },
    }),
  );
  final http.Response bindRes = await http.patch(
    Uri.parse('$baseUrl/v1/appStoreVersions/$versionId/relationships/build'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{'type': 'builds', 'id': validBuild2Id},
    }),
  );
  stdout.writeln('  🟢 Build 2 ($validBuild2Id) 掛載回應 [${bindRes.statusCode}]');

  stdout.writeln('\n📡 [3/4] 檢查審查聯絡人 & 提交 3 大 IAP/訂閱...');
  final http.Response revRes = await http.get(
    Uri.parse('$baseUrl/v1/appStoreVersions/$versionId/appStoreReviewDetail'),
    headers: headers,
  );
  final dynamic revData =
      (jsonDecode(revRes.body) as Map<String, dynamic>)['data'];
  if (revData is Map<String, dynamic>) {
    final Map<String, dynamic> ra =
        revData['attributes'] as Map<String, dynamic>;
    stdout.writeln(
      '  • 目前聯絡人: ${ra['contactFirstName']} ${ra['contactLastName']} | ${ra['contactEmail']} | ${ra['contactPhone']}',
    );
  }

  final http.Response grpRes = await http.get(
    Uri.parse('$baseUrl/v1/apps/$appId/subscriptionGroups'),
    headers: headers,
  );
  final List<dynamic> groups =
      ((jsonDecode(grpRes.body) as Map<String, dynamic>)['data']
              as List<dynamic>?) ??
          <dynamic>[];
  for (final dynamic g in groups) {
    final String gId = (g as Map<String, dynamic>)['id'].toString();
    final http.Response subRes = await http.get(
      Uri.parse('$baseUrl/v1/subscriptionGroups/$gId/subscriptions'),
      headers: headers,
    );
    final List<dynamic> subs =
        ((jsonDecode(subRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>?) ??
            <dynamic>[];
    for (final dynamic s in subs) {
      final Map<String, dynamic> sm = s as Map<String, dynamic>;
      final String subId = sm['id'].toString();
      final Map<String, dynamic> attrs =
          sm['attributes'] as Map<String, dynamic>;
      stdout.writeln(
        '  • 訂閱 ${attrs['productId']} 狀態: ${attrs['state']}',
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
        stdout.writeln('    ‣ 訂閱提交回應 [${sr.statusCode}]');
      }
    }
  }

  stdout.writeln('\n📡 [4/4] 建立送審單 (Version 1.0 + Build 2 + Lifetime IAP)...');
  String? submissionId;
  final http.Response existSub = await http.get(
    Uri.parse(
      '$baseUrl/v1/reviewSubmissions?filter[app]=$appId&filter[state]=READY_FOR_REVIEW,UNRESOLVED_ISSUES',
    ),
    headers: headers,
  );
  if (existSub.statusCode == 200) {
    final List<dynamic> list =
        ((jsonDecode(existSub.body) as Map<String, dynamic>)['data']
                as List<dynamic>?) ??
            <dynamic>[];
    if (list.isNotEmpty) {
      submissionId = (list.first as Map<String, dynamic>)['id'].toString();
    }
  }
  if (submissionId == null) {
    final http.Response subCreate = await http.post(
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
    if (subCreate.statusCode == 201 || subCreate.statusCode == 200) {
      submissionId = ((jsonDecode(subCreate.body)
              as Map<String, dynamic>)['data'] as Map<String, dynamic>)['id']
          .toString();
    }
  }

  if (submissionId == null) {
    stderr.writeln('🔴 無法取得送審單 ID');
    exit(1);
  }
  stdout.writeln('  🟢 送審單 ID: $submissionId');

  final http.Response addVer = await http.post(
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
              'id': versionId,
            },
          },
        },
      },
    }),
  );
  stdout.writeln('  ‣ 掛載 Version 1.0 回應 [${addVer.statusCode}]');
  if (addVer.statusCode != 201 && addVer.statusCode != 200) {
    stderr.writeln('  ⚠️ Version 1.0 掛載明細: ${addVer.body}');
  }

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
              'id': submissionId,
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
  stdout.writeln('  ‣ 掛載 Lifetime ($lifetimeId) 回應 [${addLife.statusCode}]');

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
      '\n🟢🟢🟢 [正式送審成功！] DoseFlow (Xcode 27.2 Build 2 + iPhone Duo 認證截圖 + 3 大內購) 已進入 Waiting for Review！',
    );
  } else {
    stderr.writeln(
      '\n⚠️ 送審最後檢查點回報 [${submitRes.statusCode}]:\n${submitRes.body}',
    );
  }
}
