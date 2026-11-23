import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String keyId = '853IQM8TC6VX';
  const String appId = '6832583172';
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

  // 1. 取得或建立 1.0.1 可編輯版本
  String? targetVersionId;
  final http.Response versRes = await http.get(
    Uri.parse('$baseUrl/v1/apps/$appId/appStoreVersions?filter[platform]=IOS'),
    headers: headers,
  );
  for (final dynamic v
      in ((jsonDecode(versRes.body) as Map<String, dynamic>)['data']
              as List<dynamic>? ??
          <dynamic>[])) {
    final Map<String, dynamic> vm = v as Map<String, dynamic>;
    final String st =
        (vm['attributes'] as Map<String, dynamic>)['appStoreState'].toString();
    if (st == 'PREPARE_FOR_SUBMISSION') {
      targetVersionId = vm['id'].toString();
      break;
    }
  }
  if (targetVersionId == null) {
    final http.Response createV = await http.post(
      Uri.parse('$baseUrl/v1/appStoreVersions'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'data': <String, dynamic>{
          'type': 'appStoreVersions',
          'attributes': const <String, dynamic>{
            'platform': 'IOS',
            'versionString': '1.0.1',
          },
          'relationships': <String, dynamic>{
            'app': <String, dynamic>{
              'data': <String, dynamic>{'type': 'apps', 'id': appId},
            },
          },
        },
      }),
    );
    if (createV.statusCode != 201 && createV.statusCode != 200) {
      stderr.writeln('ℹ️ 須等 1.0 過審上架後才能開 1.0.1 版本 [${createV.statusCode}]');
      return;
    }
    targetVersionId = ((jsonDecode(createV.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>)['id']
        .toString();
  }

  // 2. 注入「猛健樂,胰妥讚」回台灣關鍵字槽 + 開通 es-MX 美區 200% 流量池
  final Map<String, Map<String, String>> vLocPacks =
      <String, Map<String, String>>{
    'zh-Hant': <String, String>{
      'keywords': '猛健樂,胰妥讚,善纖達,週纖達,減重,瘦身,蛋白,喝水,便秘,反胃,計算,自費',
      'promotionalText':
          'FDA 仿單雙指數藥動學模型：10 秒記錄體內殘留濃度與 U-100 針筒格數。100% 本地離線不連網、免註冊帳號，回診一鍵匯出醫師評估表，立即享 3 天免費試用。',
      'whatsNew': '優化 iPhone Duo 雙屏體驗與 StoreKit 2 本地幣別即時顯示。',
    },
    'en-US': <String, String>{
      'keywords':
          'mounjaro,zepbound,ozempic,wegovy,tirzepatide,semaglutide,half,life,shotsy,compound,vial,bac,water',
      'promotionalText':
          'Track live GLP-1 half-life levels & U-100 syringe units in 10 seconds. 100% offline privacy, zero account required, 1-tap Doctor PDF. Try 3 days free.',
      'whatsNew': 'Enhanced iPhone Duo support and localized StoreKit 2 pricing.',
    },
    'es-MX': <String, String>{
      'keywords':
          'insulin,subcutaneous,fat,loss,weight,muscle,protein,rebound,tmax,injection,scale,bmi,gut,water,med',
      'promotionalText':
          'Track live GLP-1 half-life & U-100 syringe units in 10s. 100% offline privacy, 1-tap Doctor PDF. Try 3 days free.',
      'whatsNew': 'Enhanced iPhone Duo support and localized StoreKit 2 pricing.',
    },
  };

  final http.Response locRes = await http.get(
    Uri.parse(
      '$baseUrl/v1/appStoreVersions/$targetVersionId/appStoreVersionLocalizations',
    ),
    headers: headers,
  );
  final Map<String, String> existingIds = <String, String>{};
  for (final dynamic item
      in ((jsonDecode(locRes.body) as Map<String, dynamic>)['data']
              as List<dynamic>? ??
          <dynamic>[])) {
    final Map<String, dynamic> m = item as Map<String, dynamic>;
    existingIds[(m['attributes'] as Map<String, dynamic>)['locale'].toString()] =
        m['id'].toString();
  }

  for (final MapEntry<String, Map<String, String>> entry
      in vLocPacks.entries) {
    final String loc = entry.key;
    final Map<String, String> attrs = entry.value;
    if (existingIds.containsKey(loc)) {
      await http.patch(
        Uri.parse(
          '$baseUrl/v1/appStoreVersionLocalizations/${existingIds[loc]}',
        ),
        headers: headers,
        body: jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'type': 'appStoreVersionLocalizations',
            'id': existingIds[loc],
            'attributes': attrs,
          },
        }),
      );
      stdout.writeln('🟢 [$loc] 1.0.1 ASO 關鍵字火箭包更新完成！');
    } else {
      await http.post(
        Uri.parse('$baseUrl/v1/appStoreVersionLocalizations'),
        headers: headers,
        body: jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'type': 'appStoreVersionLocalizations',
            'attributes': <String, dynamic>{'locale': loc, ...attrs},
            'relationships': <String, dynamic>{
              'appStoreVersion': <String, dynamic>{
                'data': <String, dynamic>{
                  'type': 'appStoreVersions',
                  'id': targetVersionId,
                },
              },
            },
          },
        }),
      );
      stdout.writeln('🟢 [$loc] 1.0.1 跨語系流量池建立完成！');
    }
  }
}
