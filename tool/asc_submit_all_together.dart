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

Future<String?> fetchOrCreateVersion({
  required Map<String, String> headers,
  required String getUrl,
  required String postUrl,
  required String postType,
  required String relKey,
  required String relType,
  required String relId,
  required String label,
}) async {
  final http.Response getRes = await http.get(
    Uri.parse(getUrl),
    headers: headers,
  );
  if (getRes.statusCode == 200) {
    final List<dynamic> list =
        ((jsonDecode(getRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>?) ??
            <dynamic>[];
    if (list.isNotEmpty) {
      final Map<String, dynamic> first = list.first as Map<String, dynamic>;
      final String id = first['id'].toString();
      stdout.writeln('  🟢 [$label] 取得既有版本 ID: $id (${first['attributes']})');
      return id;
    }
  } else {
    stdout.writeln('  ℹ️ [$label] GET versions 回應 [${getRes.statusCode}]: ${getRes.body}');
  }

  final http.Response postRes = await http.post(
    Uri.parse(postUrl),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{
        'type': postType,
        'relationships': <String, dynamic>{
          relKey: <String, dynamic>{
            'data': <String, dynamic>{'type': relType, 'id': relId},
          },
        },
      },
    }),
  );
  if (postRes.statusCode == 201 || postRes.statusCode == 200) {
    final String id = ((jsonDecode(postRes.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>)['id']
        .toString();
    stdout.writeln('  🟢 [$label] 新建版本 ID: $id');
    return id;
  }
  stderr.writeln(
    '  🔴 [$label] POST $postUrl 失敗 [${postRes.statusCode}]: ${postRes.body}',
  );
  return null;
}

Future<bool> attachToSubmission({
  required Map<String, String> headers,
  required String submissionId,
  required String relKey,
  required String relType,
  required String relId,
  required String label,
}) async {
  const String baseUrl = 'https://api.appstoreconnect.apple.com';
  final http.Response res = await http.post(
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
          relKey: <String, dynamic>{
            'data': <String, dynamic>{'type': relType, 'id': relId},
          },
        },
      },
    }),
  );
  if (res.statusCode == 201 || res.statusCode == 200) {
    stdout.writeln('  🟢 掛載 [$label] 至送審單成功！');
    return true;
  }
  stderr.writeln(
    '  🔴 掛載 [$label] 失敗 [${res.statusCode}]: ${res.body}',
  );
  return false;
}

Future<void> main() async {
  const String appId = '6832583172';
  const String appVersionId = '277e9a5f-25ce-4e00-96e4-156eda75812c';
  const String groupId = '22561422';
  const String annualId = '6832587209';
  const String monthlyId = '6832586893';
  const String lifetimeId = '6832587006';
  const String oldSubmissionId = '4242d661-405f-4005-a12a-627e32bbb31a';
  const String baseUrl = 'https://api.appstoreconnect.apple.com';

  final Map<String, String> headers = await buildHeaders();

  stdout.writeln('📡 [1/4] 取得 / 建立 2026 API 訂閱群組與 3 大內購版本...');
  final String? grpVerId = await fetchOrCreateVersion(
    headers: headers,
    getUrl: '$baseUrl/v1/subscriptionGroups/$groupId/versions',
    postUrl: '$baseUrl/v1/subscriptionGroupVersions',
    postType: 'subscriptionGroupVersions',
    relKey: 'subscriptionGroup',
    relType: 'subscriptionGroups',
    relId: groupId,
    label: 'SubscriptionGroup',
  );

  final String? annVerId = await fetchOrCreateVersion(
    headers: headers,
    getUrl: '$baseUrl/v1/subscriptions/$annualId/versions',
    postUrl: '$baseUrl/v1/subscriptionVersions',
    postType: 'subscriptionVersions',
    relKey: 'subscription',
    relType: 'subscriptions',
    relId: annualId,
    label: 'Annual',
  );

  final String? monVerId = await fetchOrCreateVersion(
    headers: headers,
    getUrl: '$baseUrl/v1/subscriptions/$monthlyId/versions',
    postUrl: '$baseUrl/v1/subscriptionVersions',
    postType: 'subscriptionVersions',
    relKey: 'subscription',
    relType: 'subscriptions',
    relId: monthlyId,
    label: 'Monthly',
  );

  String? lifeVerId = await fetchOrCreateVersion(
    headers: headers,
    getUrl: '$baseUrl/v2/inAppPurchases/$lifetimeId/versions',
    postUrl: '$baseUrl/v1/inAppPurchaseVersions',
    postType: 'inAppPurchaseVersions',
    relKey: 'inAppPurchaseV2',
    relType: 'inAppPurchases',
    relId: lifetimeId,
    label: 'Lifetime',
  );

  if (grpVerId == null || annVerId == null || monVerId == null) {
    stderr.writeln('⚠️ 尚無法取得全部版本 ID，已保留原送審單不動。');
    exit(1);
  }

  stdout.writeln('\n📡 [2/4] 鎖定草稿送審單並預先掛載群組與 3 大內購...');
  String draftSubId = '85ecb333-275e-4dd5-a722-4232aed84225';
  final http.Response draftCheck = await http.get(
    Uri.parse('$baseUrl/v1/reviewSubmissions/$draftSubId'),
    headers: headers,
  );
  if (draftCheck.statusCode != 200 ||
      ((jsonDecode(draftCheck.body) as Map<String, dynamic>)['data']
              as Map<String, dynamic>)['attributes']['state'] !=
          'READY_FOR_REVIEW') {
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
    draftSubId = ((jsonDecode(newSub.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>)['id']
        .toString();
  }
  stdout.writeln('  🟢 使用草稿送審單: $draftSubId');

  final bool okGrp = await attachToSubmission(
    headers: headers,
    submissionId: draftSubId,
    relKey: 'subscriptionGroupVersion',
    relType: 'subscriptionGroupVersions',
    relId: grpVerId,
    label: 'SubscriptionGroupVersion',
  );
  final bool okAnn = await attachToSubmission(
    headers: headers,
    submissionId: draftSubId,
    relKey: 'subscriptionVersion',
    relType: 'subscriptionVersions',
    relId: annVerId,
    label: 'AnnualVersion',
  );
  final bool okMon = await attachToSubmission(
    headers: headers,
    submissionId: draftSubId,
    relKey: 'subscriptionVersion',
    relType: 'subscriptionVersions',
    relId: monVerId,
    label: 'MonthlyVersion',
  );

  bool okLife = false;
  if (lifeVerId != null) {
    okLife = await attachToSubmission(
      headers: headers,
      submissionId: draftSubId,
      relKey: 'inAppPurchaseVersion',
      relType: 'inAppPurchaseVersions',
      relId: lifeVerId,
      label: 'LifetimeVersion',
    );
  } else {
    okLife = await attachToSubmission(
      headers: headers,
      submissionId: draftSubId,
      relKey: 'inAppPurchaseV2',
      relType: 'inAppPurchases',
      relId: lifetimeId,
      label: 'LifetimeV2',
    );
  }

  if (!okGrp || !okAnn || !okMon || !okLife) {
    stderr.writeln('⚠️ 部分項目掛載未通過，已保留原送審單 $oldSubmissionId 不動！');
    exit(1);
  }

  stdout.writeln('\n📡 [3/4] 註銷舊單並掛載 Version 1.0 (Build 3) 至整合送審單...');
  final http.Response cancelRes = await http.patch(
    Uri.parse('$baseUrl/v1/reviewSubmissions/$oldSubmissionId'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{
        'type': 'reviewSubmissions',
        'id': oldSubmissionId,
        'attributes': const <String, dynamic>{'canceled': true},
      },
    }),
  );
  stdout.writeln('  🟢 舊單釋放回應 [${cancelRes.statusCode}]');

  final bool okApp = await attachToSubmission(
    headers: headers,
    submissionId: draftSubId,
    relKey: 'appStoreVersion',
    relType: 'appStoreVersions',
    relId: appVersionId,
    label: 'AppVersion 1.0 (Build 3)',
  );
  if (!okApp) exit(1);

  stdout.writeln('\n📡 [4/4] 正式按下 submitted: true 一鍋提交全部...');
  final http.Response submitRes = await http.patch(
    Uri.parse('$baseUrl/v1/reviewSubmissions/$draftSubId'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{
        'type': 'reviewSubmissions',
        'id': draftSubId,
        'attributes': const <String, dynamic>{'submitted': true},
      },
    }),
  );
  if (submitRes.statusCode == 200) {
    stdout.writeln(
      '\n🟢🟢🟢 [100% 純指令大滿貫成功！] Version 1.0 (Build 3) + SubscriptionGroup + Annual + Monthly + Lifetime 已全部送交 Apple Waiting for Review！',
    );
  } else {
    stderr.writeln(
      '\n⚠️ 提交回應 [${submitRes.statusCode}]:\n${submitRes.body}',
    );
  }
}
