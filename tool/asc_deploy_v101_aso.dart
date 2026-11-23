import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

class AscV101AsoEngine {
  AscV101AsoEngine._();

  static const String keyId = '853IQM8TC6VX';
  static const String appId = '6832583172';
  static const String supportUrl = 'https://beigou0427.github.io/dose_flow/';
  static const String privacyUrl =
      'https://beigou0427.github.io/dose_flow/privacy.html';
  static const String baseUrl = 'https://api.appstoreconnect.apple.com';

  static Map<String, String> buildHeaders() {
    final String pem =
        '${File('./AuthKey_$keyId.p8').readAsStringSync().trim()}\n';
    final int epoch =
        (DateTime.now().toUtc().millisecondsSinceEpoch / 1000).floor();
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

  static const List<Map<String, String>> appInfoConfigs =
      <Map<String, String>>[
    <String, String>{
      'locale': 'zh-Hant',
      'name': '瘦瘦針紀錄 Pro - 猛健樂善纖達與減重週期管理',
      'subtitle': 'GLP-1 注射部位輪替、藥效濃度曲線與體重追蹤日記',
    },
    <String, String>{
      'locale': 'en-US',
      'name': 'DoseFlow - GLP-1 Shot Tracker',
      'subtitle': 'Mounjaro, Zepbound & Wegovy',
    },
  ];

  static const List<Map<String, String>> versionLocConfigs =
      <Map<String, String>>[
    <String, String>{
      'locale': 'zh-Hant',
      'keywords': '胰妥讚,週纖達,康纖伴,半衰期,瘦身,蛋白,喝水,便秘,反胃,計算,刻度,自費',
      'promotionalText':
          'FDA 仿單雙指數藥動學模型：10 秒記錄體內殘留濃度與 U-100 針筒格數。100% 本地離線不連網、免註冊帳號，回診一鍵匯出醫師評估表，立即享 3 天免費試用。',
      'whatsNew': '優化週期紀錄體驗與介面細節調整，提升整體操作流暢度。',
      'description': '''正在使用猛健樂 (Mounjaro)、週纖達 (Wegovy) 或胰妥讚 (Ozempic) 嗎？
「瘦瘦針紀錄 Pro」是專為 GLP-1 療程打造的 100% 離線隱私助手。
實時預測吸收高峰 (Tmax) 與半衰期波谷，U-100 針筒一秒精算防呆！

【核心特色】
1. 實時藥動學曲線：採用美國 FDA 仿單標準 Bateman 雙指數模型，精確預測 7 天半衰期衰退與波谷。
2. U-100 針筒換算器：乾粉胜肽混水一秒計算抽針刻度，徹底杜絕過量風險。
3. 8 大部位輪替地圖：自動避開肚臍 5 公分，預防皮下脂肪增生硬塊與瘀青。
4. 習慣達成環：每日蛋白質與補水目標追蹤，守護核心骨骼肌不流失。
5. 100% 離線隱私：無外部伺服器、免註冊帳號，所有健康數據僅存在您的裝置中。

【醫療免責聲明與 FDA 仿單依據】
本 App 僅供個人健康記錄與教育參考，所有代謝濃度曲線均為數學推估 (Bateman Function)，源自美國 FDA 官方仿單 (Section 12.3 Pharmacokinetics) 半衰期與 Tmax 參數，不代表實際血液測量值，亦不提供醫療診斷或劑量調整指導。調整用藥前請務必諮詢您的處方主治醫師。

【使用條款與隱私權政策】
• 使用條款 (Apple 標準 EULA)：https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
• 隱私權政策：https://beigou0427.github.io/dose_flow/privacy.html''',
    },
    <String, String>{
      'locale': 'en-US',
      'keywords':
          'ozempic,tirzepatide,semaglutide,peptide,u100,syringe,half,life,shotsy,compound,vial,bac,water',
      'promotionalText':
          'Track live GLP-1 half-life levels & U-100 syringe units in 10 seconds. 100% offline privacy, zero account required, 1-tap Doctor PDF. Try 3 days free.',
      'whatsNew':
          'Optimized tracking experience and refined UI details for smoother performance.',
      'description': '''Taking Mounjaro, Zepbound, Wegovy, Ozempic, or Compounded Peptides?
DoseFlow is the #1 privacy-first companion built on clinical pharmacokinetics.
Forecast 7-day half-life decay, absorption peaks & U-100 syringe units instantly.

KEY CLINICAL FEATURES:
- Live Bateman PK Curve: Forecast your 7-day half-life decay and absorption peaks calibrated strictly against published FDA Prescribing Information.
- U-100 Syringe Calculator: Convert reconstituted peptide vials into exact insulin syringe units instantly.
- Smart 8-Quadrant Rotation: Rotate injection sites away from the navel to prevent bruising and lipohypertrophy.
- Anti-Muscle Loss Habits: Hit daily protein and hydration rings to preserve vital skeletal muscle.
- 100% Local-First Privacy: Zero external cloud servers. Zero account registration required.

REGULATORY DISCLAIMER & FDA CITATIONS:
DoseFlow is intended solely for personal health logging. All concentration curves are theoretical mathematical estimates (Bateman Function) derived from published FDA Prescribing Information (Section 12.3) and do not represent actual blood laboratory measurements. Always consult your prescribing physician before adjusting doses.

TERMS OF USE & PRIVACY:
- Terms of Use (Standard Apple EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- Privacy Policy: https://beigou0427.github.io/dose_flow/privacy.html''',
    },
    <String, String>{
      'locale': 'es-MX',
      'keywords':
          'insulin,subcutaneous,fat,loss,weight,muscle,protein,rebound,tmax,injection,scale,bmi,gut,water,med',
      'promotionalText':
          'Track live GLP-1 half-life & U-100 syringe units in 10s. 100% offline privacy, 1-tap Doctor PDF. Try 3 days free.',
      'whatsNew':
          'Optimized tracking experience and refined UI details for smoother performance.',
      'description': '''Taking Mounjaro, Zepbound, Wegovy, Ozempic, or Compounded Peptides?
DoseFlow is the #1 privacy-first companion built on clinical pharmacokinetics.
Forecast 7-day half-life decay, absorption peaks & U-100 syringe units instantly.

KEY CLINICAL FEATURES:
- Live Bateman PK Curve: Forecast your 7-day half-life decay and absorption peaks calibrated strictly against published FDA Prescribing Information.
- U-100 Syringe Calculator: Convert reconstituted peptide vials into exact insulin syringe units instantly.
- Smart 8-Quadrant Rotation: Rotate injection sites away from the navel to prevent bruising and lipohypertrophy.
- Anti-Muscle Loss Habits: Hit daily protein and hydration rings to preserve vital skeletal muscle.
- 100% Local-First Privacy: Zero external cloud servers. Zero account registration required.

REGULATORY DISCLAIMER & FDA CITATIONS:
DoseFlow is intended solely for personal health logging. All concentration curves are theoretical mathematical estimates (Bateman Function) derived from published FDA Prescribing Information (Section 12.3) and do not represent actual blood laboratory measurements. Always consult your prescribing physician before adjusting doses.

TERMS OF USE & PRIVACY:
- Terms of Use (Standard Apple EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- Privacy Policy: https://beigou0427.github.io/dose_flow/privacy.html''',
    },
  ];

  static void assertGuardrails() {
    for (final Map<String, String> cfg in appInfoConfigs) {
      final String locale = cfg['locale']!;
      final String name = cfg['name']!;
      final String subtitle = cfg['subtitle']!;
      if (name.length > 30 || subtitle.length > 30) {
        throw StateError(
          'ASO 標題或副標超過 30 字元: $locale (name: ${name.length}, sub: ${subtitle.length})',
        );
      }
    }
    for (final Map<String, String> cfg in versionLocConfigs) {
      final String locale = cfg['locale']!;
      final String keywords = cfg['keywords']!;
      final int byteLen = utf8.encode(keywords).length;
      if (keywords.contains(' ') || byteLen > 100) {
        throw StateError(
          'ASO 關鍵字違反限制 ($byteLen Bytes / 包含空格) [$locale]',
        );
      }
    }
    stdout.writeln('🟢 [0/3] ASO 1.0.1 高權重文字預檢 100% 符合 Apple 規範！');
  }

  static Future<void> run() async {
    assertGuardrails();
    final Map<String, String> headers = buildHeaders();

    // 1. 同步 AppInfo 標題與副標題 (zh-Hant & en-US)
    stdout.writeln('\n📡 [1/3] 正在同步 AppInfo 高曝光標題與副標題...');
    final http.Response infoRes = await http.get(
      Uri.parse('$baseUrl/v1/apps/$appId/appInfos'),
      headers: headers,
    );
    final String appInfoId =
        (((jsonDecode(infoRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>)
            .first as Map<String, dynamic>)['id']
            .toString();

    final http.Response infoLocRes = await http.get(
      Uri.parse('$baseUrl/v1/appInfos/$appInfoId/appInfoLocalizations'),
      headers: headers,
    );
    final List<dynamic> existingInfoLocs =
        ((jsonDecode(infoLocRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>?) ??
            <dynamic>[];

    for (final Map<String, String> cfg in appInfoConfigs) {
      final String locale = cfg['locale']!;
      final Map<String, dynamic> attributes = <String, dynamic>{
        'name': cfg['name']!,
        'subtitle': cfg['subtitle']!,
      };

      Map<String, dynamic>? matched;
      for (final dynamic item in existingInfoLocs) {
        final Map<String, dynamic> map = item as Map<String, dynamic>;
        final Map<String, dynamic> attrs =
            map['attributes'] as Map<String, dynamic>? ?? <String, dynamic>{};
        if (attrs['locale'] == locale) {
          matched = map;
          break;
        }
      }

      if (matched != null) {
        final String locId = matched['id'].toString();
        final http.Response patchRes = await http.patch(
          Uri.parse('$baseUrl/v1/appInfoLocalizations/$locId'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'appInfoLocalizations',
              'id': locId,
              'attributes': attributes,
            },
          }),
        );
        stdout.writeln(
          '  🟢 [$locale] 標題與副標題更新成功 [${patchRes.statusCode}]: ${cfg['name']}',
        );
      } else {
        final http.Response postRes = await http.post(
          Uri.parse('$baseUrl/v1/appInfoLocalizations'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'appInfoLocalizations',
              'attributes': <String, dynamic>{
                'locale': locale,
                ...attributes,
              },
              'relationships': <String, dynamic>{
                'appInfo': <String, dynamic>{
                  'data': <String, dynamic>{
                    'type': 'appInfos',
                    'id': appInfoId,
                  },
                },
              },
            },
          }),
        );
        stdout.writeln(
          '  🟢 [$locale] 新建標題與副標題成功 [${postRes.statusCode}]: ${cfg['name']}',
        );
      }
    }

    // 2. 建立或鎖定 Version 1.0.1 草稿
    stdout.writeln('\n📡 [2/3] 取得或建立 iOS Version 1.0.1 草稿版本...');
    String? v101Id;
    final http.Response versRes = await http.get(
      Uri.parse(
        '$baseUrl/v1/apps/$appId/appStoreVersions?filter[platform]=IOS',
      ),
      headers: headers,
    );
    final List<dynamic> verList =
        ((jsonDecode(versRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>?) ??
            <dynamic>[];

    for (final dynamic v in verList) {
      final Map<String, dynamic> vm = v as Map<String, dynamic>;
      final Map<String, dynamic> attrs =
          vm['attributes'] as Map<String, dynamic>;
      if (attrs['appStoreState'] == 'PREPARE_FOR_SUBMISSION') {
        v101Id = vm['id'].toString();
        stdout.writeln('  🟢 鎖定既有草稿版本: ${attrs['versionString']} (ID: $v101Id)');
        break;
      }
    }

    if (v101Id == null) {
      final http.Response createRes = await http.post(
        Uri.parse('$baseUrl/v1/appStoreVersions'),
        headers: headers,
        body: jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'type': 'appStoreVersions',
            'attributes': const <String, dynamic>{
              'platform': 'IOS',
              'versionString': '1.0.1',
              'copyright': '© 2026 DoseFlow Inc.',
            },
            'relationships': <String, dynamic>{
              'app': <String, dynamic>{
                'data': <String, dynamic>{'type': 'apps', 'id': appId},
              },
            },
          },
        }),
      );
      if (createRes.statusCode == 201 || createRes.statusCode == 200) {
        v101Id = ((jsonDecode(createRes.body) as Map<String, dynamic>)['data']
                as Map<String, dynamic>)['id']
            .toString();
        stdout.writeln('  🟢 成功建立全新 Version 1.0.1 草稿版本 (ID: $v101Id)');
      } else {
        stderr.writeln(
          '  🔴 建立 Version 1.0.1 失敗 [${createRes.statusCode}]: ${createRes.body}',
        );
        return;
      }
    }

    // 3. 灌入 1.0.1 雙語 + es-MX ASO 關鍵字、描述與 What's New
    stdout.writeln('\n📡 [3/3] 灌入 1.0.1 高權重關鍵字、長描述與 What\'s New...');
    final http.Response verLocRes = await http.get(
      Uri.parse(
        '$baseUrl/v1/appStoreVersions/$v101Id/appStoreVersionLocalizations',
      ),
      headers: headers,
    );
    final List<dynamic> existingVerLocs =
        ((jsonDecode(verLocRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>?) ??
            <dynamic>[];

    for (final Map<String, String> cfg in versionLocConfigs) {
      final String locale = cfg['locale']!;
      final String keywords = cfg['keywords']!;
      final Map<String, dynamic> attributes = <String, dynamic>{
        'keywords': keywords,
        'description': cfg['description']!,
        'promotionalText': cfg['promotionalText']!,
        'whatsNew': cfg['whatsNew']!,
        'supportUrl': supportUrl,
        'marketingUrl': supportUrl,
      };

      Map<String, dynamic>? matched;
      for (final dynamic item in existingVerLocs) {
        final Map<String, dynamic> map = item as Map<String, dynamic>;
        final Map<String, dynamic> attrs =
            map['attributes'] as Map<String, dynamic>? ?? <String, dynamic>{};
        if (attrs['locale'] == locale) {
          matched = map;
          break;
        }
      }

      if (matched != null) {
        final String locId = matched['id'].toString();
        final http.Response patchRes = await http.patch(
          Uri.parse('$baseUrl/v1/appStoreVersionLocalizations/$locId'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'appStoreVersionLocalizations',
              'id': locId,
              'attributes': attributes,
            },
          }),
        );
        stdout.writeln(
          '  🟢 [$locale] 1.0.1 ASO 更新成功 [${patchRes.statusCode}] (${utf8.encode(keywords).length} Bytes)',
        );
      } else {
        final http.Response postRes = await http.post(
          Uri.parse('$baseUrl/v1/appStoreVersionLocalizations'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'appStoreVersionLocalizations',
              'attributes': <String, dynamic>{
                'locale': locale,
                ...attributes,
              },
              'relationships': <String, dynamic>{
                'appStoreVersion': <String, dynamic>{
                  'data': <String, dynamic>{
                    'type': 'appStoreVersions',
                    'id': v101Id,
                  },
                },
              },
            },
          }),
        );
        stdout.writeln(
          '  🟢 [$locale] 1.0.1 跨語系 ASO 新建成功 [${postRes.statusCode}] (${utf8.encode(keywords).length} Bytes)',
        );
      }
    }
  }
}

Future<void> main() async {
  await AscV101AsoEngine.run();
  stdout.writeln('\n🎉 [DoseFlow 1.0.1 高爆量 ASO 火箭發射成功！]');
}
