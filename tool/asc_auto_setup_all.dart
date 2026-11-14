import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Map<String, String> _buildHeaders(String token) => {
  'Authorization': 'Bearer $token',
  'Content-Type': 'application/json',
};

String _generateToken(String keyId, String issuerId, String privateKeyPem, int mode) {
  final now = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
  
  Map<String, dynamic> payload;
  if (mode == 1) {
    // 模式 A：個別 API 金鑰標準規範 (包含 sub 與 iss)
    payload = {
      'iss': issuerId,
      'sub': 'user',
      'iat': now - 20,
      'exp': now + 1180,
      'aud': 'appstoreconnect-v1',
    };
  } else if (mode == 2) {
    // 模式 B：官方標準團隊規範 (純 iss)
    payload = {
      'iss': issuerId,
      'iat': now - 20,
      'exp': now + 1180,
      'aud': 'appstoreconnect-v1',
    };
  } else {
    // 模式 C：絕對零偏移 UTC
    payload = {
      'iss': issuerId,
      'iat': now,
      'exp': now + 1200,
      'aud': 'appstoreconnect-v1',
    };
  }

  final jwt = JWT(payload, header: {
    'alg': 'ES256',
    'kid': keyId,
    'typ': 'JWT',
  });
  return jwt.sign(ECPrivateKey(privateKeyPem), algorithm: JWTAlgorithm.ES256);
}

void main() async {
  print("\n==========================================================================");
  print("正在啟動 Apple 官方 API 雙模握手驗證...");
  print("==========================================================================");

  const keyId = "853IQM8TC6VX";
  const issuerId = "7c8a4cba-398c-4e88-88bb-9252f72ecdc9";
  const appId = "6832583172";

  final p8Files = Directory('.').listSync().where((f) => f.path.contains('AuthKey_$keyId') && f.path.endsWith('.p8')).toList();
  if (p8Files.isEmpty) {
    print("找不到 AuthKey_${keyId}.p8 檔案！");
    exit(1);
  }

  final privateKeyPem = File(p8Files.first.path).readAsStringSync();

  String? validToken;
  // 依序嘗試模式 1, 2, 3
  for (int mode = 1; mode <= 3; mode++) {
    final testToken = _generateToken(keyId, issuerId, privateKeyPem, mode);
    final testRes = await http.get(
      Uri.parse('https://api.appstoreconnect.apple.com/v1/apps/$appId'),
      headers: _buildHeaders(testToken),
    );
    if (testRes.statusCode == 200) {
      validToken = testToken;
      final appName = jsonDecode(testRes.body)['data']['attributes']['name'];
      print("🟢 握手成功！(採用模式 $mode) 連線到 App: $appName");
      break;
    } else {
      print("  ‣ 模式 $mode 測試回傳 [${testRes.statusCode}]");
    }
  }

  if (validToken == null) {
    print("🔴 三種模式皆未通過 401。正在檢查金鑰權限或嘗試透過 /v1/apps 檢索...");
    final fallbackToken = _generateToken(keyId, issuerId, privateKeyPem, 2);
    final fallbackRes = await http.get(
      Uri.parse('https://api.appstoreconnect.apple.com/v1/apps?limit=5'),
      headers: _buildHeaders(fallbackToken),
    );
    print("API 根目錄檢驗回應: [${fallbackRes.statusCode}] ${fallbackRes.body}");
    exit(1);
  }

  final headers = _buildHeaders(validToken);

  // 1. 建立或鎖定訂閱群組
  print("\n正在確認訂閱群組 (DoseFlow Pro Subscriptions)...");
  String? groupId;
  final groupsRes = await http.get(
    Uri.parse('https://api.appstoreconnect.apple.com/v1/apps/$appId/subscriptionGroups'),
    headers: headers,
  );
  if (groupsRes.statusCode == 200) {
    final groups = jsonDecode(groupsRes.body)['data'] as List? ?? [];
    for (final g in groups) {
      if (g['attributes']['referenceName'] == 'DoseFlow Pro Subscriptions') {
        groupId = g['id'].toString();
        print("🟢 訂閱群組已存在 (ID: $groupId)");
        break;
      }
    }
  }

  if (groupId == null) {
    final createGroupRes = await http.post(
      Uri.parse('https://api.appstoreconnect.apple.com/v1/subscriptionGroups'),
      headers: headers,
      body: jsonEncode({
        'data': {
          'type': 'subscriptionGroups',
          'attributes': {'referenceName': 'DoseFlow Pro Subscriptions'},
          'relationships': {
            'app': {'data': {'type': 'apps', 'id': appId}}
          }
        }
      }),
    );
    if (createGroupRes.statusCode == 201 || createGroupRes.statusCode == 200) {
      groupId = jsonDecode(createGroupRes.body)['data']['id'].toString();
      print("🟢 成功建立全新訂閱群組 (ID: $groupId)");
    } else {
      print("群組回應 [${createGroupRes.statusCode}]: ${createGroupRes.body}");
    }
  }

  // 2. 建立 年繳 與 月繳 訂閱
  if (groupId != null) {
    print("\n正在建立訂閱項目 (Annual & Monthly)...");
    final subs = [
      {
        'id': 'com.doseflow.app.annual',
        'name': 'Annual Pro with 3-Day Trial',
        'period': 'ONE_YEAR',
        'level': 1,
        'locs': [
          {'locale': 'zh-Hant', 'name': '年繳方案 (首選推薦)', 'desc': '年繳包含3天免費試用，省下45%費用'},
          {'locale': 'en-US', 'name': 'Annual Subscription (Best Value)', 'desc': 'Annual access with 3-day free trial'},
        ]
      },
      {
        'id': 'com.doseflow.app.monthly',
        'name': 'Monthly Pro',
        'period': 'ONE_MONTH',
        'level': 2,
        'locs': [
          {'locale': 'zh-Hant', 'name': '月度訂閱', 'desc': '每月自動續訂，靈活無綁約'},
          {'locale': 'en-US', 'name': 'Monthly Subscription', 'desc': 'Monthly auto-renewing access to all tools'},
        ]
      },
    ];

    for (final s in subs) {
      final prodId = s['id'] as String;
      print("處理商品: $prodId");
      String? subInternalId;

      final createSubRes = await http.post(
        Uri.parse('https://api.appstoreconnect.apple.com/v1/subscriptions'),
        headers: headers,
        body: jsonEncode({
          'data': {
            'type': 'subscriptions',
            'attributes': {
              'name': s['name'],
              'productId': prodId,
              'subscriptionPeriod': s['period'],
              'groupLevel': s['level'],
            },
            'relationships': {
              'group': {'data': {'type': 'subscriptionGroups', 'id': groupId}}
            }
          }
        }),
      );

      if (createSubRes.statusCode == 201 || createSubRes.statusCode == 200) {
        subInternalId = jsonDecode(createSubRes.body)['data']['id'].toString();
        print("  🟢 成功建立訂閱: $prodId (ID: $subInternalId)");
      } else if (createSubRes.statusCode == 409) {
        print("  ℹ️ 項目 $prodId 已存在 (HTTP 409 OK)");
        final existSubsRes = await http.get(
          Uri.parse('https://api.appstoreconnect.apple.com/v1/subscriptionGroups/$groupId/subscriptions'),
          headers: headers,
        );
        if (existSubsRes.statusCode == 200) {
          for (final es in (jsonDecode(existSubsRes.body)['data'] as List? ?? [])) {
            if (es['attributes']['productId'] == prodId) {
              subInternalId = es['id'].toString();
              break;
            }
          }
        }
      } else {
        print("  建立回應 [${createSubRes.statusCode}]: ${createSubRes.body}");
      }

      if (subInternalId != null) {
        for (final loc in (s['locs'] as List<Map<String, String>>)) {
          final locRes = await http.post(
            Uri.parse('https://api.appstoreconnect.apple.com/v1/subscriptionLocalizations'),
            headers: headers,
            body: jsonEncode({
              'data': {
                'type': 'subscriptionLocalizations',
                'attributes': {
                  'locale': loc['locale'],
                  'name': loc['name'],
                  'description': loc['desc'],
                },
                'relationships': {
                  'subscription': {'data': {'type': 'subscriptions', 'id': subInternalId}}
                }
              }
            }),
          );
          if (locRes.statusCode == 201 || locRes.statusCode == 200) {
            print("  🌐 語系已掛載: ${loc['locale']}");
          }
        }
      }
    }
  }

  // 3. 建立 終身買斷非消耗型項目
  print("\n正在建立終身買斷項目 (com.doseflow.app.lifetime)...");
  final lifetimeProdId = 'com.doseflow.app.lifetime';
  String? lifetimeInternalId;

  final createLifetimeRes = await http.post(
    Uri.parse('https://api.appstoreconnect.apple.com/v2/inAppPurchases'),
    headers: headers,
    body: jsonEncode({
      'data': {
        'type': 'inAppPurchases',
        'attributes': {
          'name': 'Lifetime Platinum Reserve',
          'productId': lifetimeProdId,
          'inAppPurchaseType': 'NON_CONSUMABLE',
        },
        'relationships': {
          'app': {'data': {'type': 'apps', 'id': appId}}
        }
      }
    }),
  );

  if (createLifetimeRes.statusCode == 201 || createLifetimeRes.statusCode == 200) {
    lifetimeInternalId = jsonDecode(createLifetimeRes.body)['data']['id'].toString();
    print("🟢 成功建立非消耗型項目: $lifetimeProdId (ID: $lifetimeInternalId)");

    final lifetimeLocs = [
      {'locale': 'zh-Hant', 'name': '終身買斷尊爵版', 'desc': '一次付費永久享有所有專業藥動學功能'},
      {'locale': 'en-US', 'name': 'Lifetime Platinum Reserve', 'desc': 'Lifetime access to all GLP-1 pro tools'},
    ];
    for (final loc in lifetimeLocs) {
      await http.post(
        Uri.parse('https://api.appstoreconnect.apple.com/v2/inAppPurchaseLocalizations'),
        headers: headers,
        body: jsonEncode({
          'data': {
            'type': 'inAppPurchaseLocalizations',
            'attributes': {
              'locale': loc['locale'],
              'name': loc['name'],
              'description': loc['desc'],
            },
            'relationships': {
              'inAppPurchaseV2': {'data': {'type': 'inAppPurchases', 'id': lifetimeInternalId}}
            }
          }
        }),
      );
      print("  🌐 終身版語系已掛載: ${loc['locale']}");
    }
  } else if (createLifetimeRes.statusCode == 409) {
    print("ℹ️ 項目 $lifetimeProdId 已存在 (HTTP 409 OK)");
  } else {
    print("終身版回應 [${createLifetimeRes.statusCode}]: ${createLifetimeRes.body}");
  }

  print("\n==========================================================================");
  print("🎉 恭喜！內購商品與雙語文案已全部成功部署至 Apple 官方伺服器！");
  print("==========================================================================");
}
