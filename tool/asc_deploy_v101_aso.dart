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
      'name': '瘦瘦針紀錄 Pro - GLP-1 減重週期管理',
      'subtitle': '注射部位輪替、藥效濃度曲線與體重追蹤日記',
    },
    <String, String>{
      'locale': 'en-US',
      'name': 'DoseFlow - GLP-1 Shot Tracker',
      'subtitle': 'Peptide Half-Life & U-100 Calc',
    },
  ];

  static const List<Map<String, String>> versionLocConfigs =
      <Map<String, String>>[
    <String, String>{
      'locale': 'zh-Hant',
      'keywords':
          '瘦瘦筆,減肥,打針,針筒,刻度,半衰期,劑量,提醒,日曆,蛋白質,喝水,便秘,反胃,隱私,離線,計算,自費,瘦身,減脂,代謝,排程,食慾,噁心,掉肌,肌肉,回診,PDF,換算,混水,胜肽,體脂,BMI',
      'promotionalText':
          '每週打針總忘記上次打哪一邊？10 秒視覺化輪替部位、即時推估體內藥效曲線與 U-100 針筒刻度。本機優先隱私＋Face ID 鎖與回診 PDF，立即享 3 天免費試用。',
      'whatsNew':
          '全新 1.1 深色醫療科技介面升級：新增視覺化人體部位輪替地圖、即時藥效濃度百分比儀表、智慧週期打卡日曆與推播提醒，以及 Face ID 隱私鎖與個人 iCloud 備份。',
      'description': '''每週打針總忘記上次打哪一邊、或搞不清楚體內藥效還剩多少嗎？
「瘦瘦針紀錄 Pro」是專為 GLP-1 體重管理療程打造的本機優先隱私助手。
依據美國 FDA 官方仿單參數，即時視覺化吸收高峰 (Tmax) 與半衰期趨勢，U-100 針筒刻度一秒輔助換算！

【核心特色】
1. 視覺化部位輪替地圖：自動標示避開肚臍 5 公分區域並提示下次建議位置，協助輪替部位、降低重複施打造成的不適。
2. 即時藥動學曲線與濃度儀表：採用美國 FDA 仿單 Bateman 雙指數模型，視覺化 7 天半衰期變化與估計濃度比例。
3. U-100 針筒輔助換算器：支援現成藥液與乾粉混水雙模式，協助核對抽針刻度，減少手動換算失誤。
4. 智慧週期打卡日曆與提醒：自訂每週施打日與換針消毒提醒，不錯過每次排程。
5. 劑量與體重趨勢追蹤：對照每次調劑階段變化，搭配蛋白質與補水目標環，維持日常健康習慣。
6. 本機優先隱私保護：免註冊、無第三方伺服器，資料僅存於您的裝置與可選個人加密 iCloud 備份；支援 Face ID 密碼鎖與一鍵匯出回診 PDF 報告。

【訂閱與自動續訂說明】
• 提供年繳（含 3 天免費試用）、月繳與終身買斷方案；確認購買時將由您的 Apple ID 扣款。
• 訂閱將於試用期或當期結束前 24 小時自動續訂，您可隨時於 iPhone「設定」> Apple ID >「訂閱項目」取消。

【醫療免責聲明與 FDA 仿單依據】
本 App 僅供個人健康記錄與教育參考，所有代謝濃度曲線均為數學推估 (Bateman Function)，源自美國 FDA 官方仿單 (Section 12.3 Pharmacokinetics) 半衰期與 Tmax 參數，不代表實際血液測量值，亦不提供醫療診斷或劑量調整指導。調整用藥前請務必諮詢您的處方主治醫師。

【使用條款與隱私權政策】
• 使用條款 (Apple 標準 EULA)：https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
• 隱私權政策：https://beigou0427.github.io/dose_flow/privacy.html''',
    },
    <String, String>{
      'locale': 'en-US',
      'keywords':
          'tirzepatide,semaglutide,syringe,compound,vial,bac,rotation,log,dosage,site,schedule,reminder,diary',
      'promotionalText':
          'Never guess where to inject next. Track site rotation, GLP-1 half-life curves & U-100 units in 10s. Local-first privacy, Face ID lock & Doctor PDF. Try 3 days free.',
      'whatsNew':
          'v1.1 Deep Medical Dark UI upgrade: Visual body injection site rotation map, live concentration gauge, smart weekly reminder calendar, Face ID privacy lock, and private iCloud backup.',
      'description': '''Ever forget which side you injected last week—or wonder where you are in your 7-day cycle?
DoseFlow is a dedicated local-first privacy companion for weekly Tirzepatide, Semaglutide, and Peptide routines.
Visualize estimated half-life curves, absorption peaks, and U-100 syringe units in seconds.

KEY FEATURES:
- Visual Site Rotation Map: Guided rotation away from the navel to help minimize repeated-site discomfort.
- Live Bateman PK Curve & Gauge: Visualize estimated 7-day half-life decay and absorption peaks based on published FDA Prescribing Information.
- U-100 Syringe Unit Helper: Quickly calculate syringe units for premixed or reconstituted vials to help reduce manual math errors.
- Smart Weekly Reminder Calendar: Schedule weekly shot-day and fresh needle prep alerts so you stay right on track.
- Daily Protein & Hydration Rings: Track weight milestones alongside daily protein and water goals to support healthy lean habits.
- Local-First Privacy: No account required and zero external servers—data stays on your iPhone with optional private iCloud backup, Face ID lock, and 1-tap Doctor PDF export.

SUBSCRIPTION & AUTO-RENEWAL INFO:
- Annual (with 3-day free trial), Monthly, and Lifetime options available. Payment is charged to your Apple ID at confirmation.
- Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period in iOS Settings > Apple ID > Subscriptions.

REGULATORY DISCLAIMER & FDA CITATIONS:
DoseFlow is intended solely for personal health logging and educational reference. All concentration curves are theoretical mathematical estimates (Bateman Function) derived from published FDA Prescribing Information (Section 12.3) and do not represent actual blood laboratory measurements. Always consult your prescribing physician before adjusting doses.

TERMS OF USE & PRIVACY:
- Terms of Use (Standard Apple EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- Privacy Policy: https://beigou0427.github.io/dose_flow/privacy.html''',
    },
    <String, String>{
      'locale': 'es-MX',
      'keywords':
          'insulin,subcutaneous,fat,loss,weight,muscle,protein,rebound,tmax,injection,scale,bmi,gut,water,med',
      'promotionalText':
          'Never guess where to inject next. Track site rotation, GLP-1 half-life & U-100 units in 10s. Local-first privacy, Face ID lock & Doctor PDF. Try 3 days free.',
      'whatsNew':
          'v1.1 Deep Medical Dark UI upgrade: Visual body injection site rotation map, live concentration gauge, smart weekly reminder calendar, Face ID privacy lock, and private iCloud backup.',
      'description': '''Ever forget which side you injected last week—or wonder where you are in your 7-day cycle?
DoseFlow is a dedicated local-first privacy companion for weekly Tirzepatide, Semaglutide, and Peptide routines.
Visualize estimated half-life curves, absorption peaks, and U-100 syringe units in seconds.

KEY FEATURES:
- Visual Site Rotation Map: Guided rotation away from the navel to help minimize repeated-site discomfort.
- Live Bateman PK Curve & Gauge: Visualize estimated 7-day half-life decay and absorption peaks based on published FDA Prescribing Information.
- U-100 Syringe Unit Helper: Quickly calculate syringe units for premixed or reconstituted vials to help reduce manual math errors.
- Smart Weekly Reminder Calendar: Schedule weekly shot-day and fresh needle prep alerts so you stay right on track.
- Daily Protein & Hydration Rings: Track weight milestones alongside daily protein and water goals to support healthy lean habits.
- Local-First Privacy: No account required and zero external servers—data stays on your iPhone with optional private iCloud backup, Face ID lock, and 1-tap Doctor PDF export.

SUBSCRIPTION & AUTO-RENEWAL INFO:
- Annual (with 3-day free trial), Monthly, and Lifetime options available. Payment is charged to your Apple ID at confirmation.
- Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period in iOS Settings > Apple ID > Subscriptions.

REGULATORY DISCLAIMER & FDA CITATIONS:
DoseFlow is intended solely for personal health logging and educational reference. All concentration curves are theoretical mathematical estimates (Bateman Function) derived from published FDA Prescribing Information (Section 12.3) and do not represent actual blood laboratory measurements. Always consult your prescribing physician before adjusting doses.

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
      final String promo = cfg['promotionalText']!;
      final String desc = cfg['description']!;
      if (keywords.contains(' ') || keywords.length > 100) {
        throw StateError(
          'ASO 關鍵字違反限制 (${keywords.length} chars / 包含空格) [$locale]',
        );
      }
      if (promo.length > 170) {
        throw StateError(
          'ASO 行銷文字超過 170 字元 (${promo.length} chars) [$locale]',
        );
      }
      if (keywords.toLowerCase().contains('shotsy') ||
          desc.contains('#1') ||
          desc.contains('徹底杜絕')) {
        throw StateError('ASO 合規檢查失敗：包含競品字、#1 宣稱或絕對化醫療詞 [$locale]');
      }
      // Verify zero duplicate terms inside keywords itself
      final List<String> terms =
          keywords.split(',').map((String t) => t.toLowerCase()).toList();
      if (terms.toSet().length != terms.length) {
        throw StateError('ASO 關鍵字內部有重複詞 [$locale]');
      }
    }
    stdout.writeln('🟢 [0/3] ASO 100 分合規與去重預檢全數通過！');
  }

  static Future<void> run() async {
    assertGuardrails();
    final Map<String, String> headers = buildHeaders();

    // 1. 同步 AppInfo 標題與副標題 (優先挑選可編輯的 PREPARE_FOR_SUBMISSION AppInfo)
    stdout.writeln('\n📡 [1/3] 正在同步 AppInfo 高曝光標題與副標題...');
    final http.Response infoRes = await http.get(
      Uri.parse('$baseUrl/v1/apps/$appId/appInfos'),
      headers: headers,
    );
    final List<dynamic> appInfos =
        ((jsonDecode(infoRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>?) ??
            <dynamic>[];
    Map<String, dynamic> selectedInfo = appInfos.first as Map<String, dynamic>;
    for (final dynamic item in appInfos) {
      final Map<String, dynamic> m = item as Map<String, dynamic>;
      final String state =
          ((m['attributes'] as Map<String, dynamic>?)?['appStoreState'] ?? '')
              .toString();
      if (state == 'PREPARE_FOR_SUBMISSION' ||
          state == 'DEVELOPER_REJECTED' ||
          state == 'REJECTED') {
        selectedInfo = m;
        break;
      }
    }
    final String appInfoId = selectedInfo['id'].toString();
    final String infoState =
        ((selectedInfo['attributes'] as Map<String, dynamic>?)?['appStoreState'] ??
                'UNKNOWN')
            .toString();
    stdout.writeln('  ℹ️ 鎖定 AppInfo: $appInfoId (狀態: $infoState)');

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
        final String icon = patchRes.statusCode >= 200 && patchRes.statusCode < 300 ? '🟢' : '⚠️';
        stdout.writeln(
          '  $icon [$locale] 標題與副標題回應 [${patchRes.statusCode}]: ${cfg['name']}',
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
        final String icon = postRes.statusCode >= 200 && postRes.statusCode < 300 ? '🟢' : '⚠️';
        stdout.writeln(
          '  $icon [$locale] 新建標題與副標題回應 [${postRes.statusCode}]: ${cfg['name']}',
        );
      }
    }

    // 2. 建立或鎖定並對齊 iOS Version 1.1.0 草稿
    const String targetVersion = '1.1.0';
    stdout.writeln('\n📡 [2/3] 取得或建立 iOS Version $targetVersion 草稿版本...');
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
        final String currentVer = attrs['versionString'].toString();
        stdout.writeln('  🟢 鎖定既有草稿版本: $currentVer (ID: $v101Id)');
        if (currentVer != targetVersion) {
          final http.Response patchVerRes = await http.patch(
            Uri.parse('$baseUrl/v1/appStoreVersions/$v101Id'),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'type': 'appStoreVersions',
                'id': v101Id,
                'attributes': <String, dynamic>{
                  'versionString': targetVersion,
                },
              },
            }),
          );
          final String icon =
              patchVerRes.statusCode >= 200 && patchVerRes.statusCode < 300
                  ? '🟢'
                  : '⚠️';
          stdout.writeln(
            '  $icon 草稿版本號同步 $currentVer → $targetVersion 回應 [${patchVerRes.statusCode}]',
          );
        }
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
              'versionString': targetVersion,
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
        stdout.writeln('  🟢 成功建立全新 Version $targetVersion 草稿版本 (ID: $v101Id)');
      } else {
        stderr.writeln(
          '  🔴 建立 Version $targetVersion 失敗 [${createRes.statusCode}]: ${createRes.body}',
        );
        return;
      }
    }

    // 3. 灌入 1.1.0 雙語 + es-MX 零重複高權重關鍵字、描述與 What's New
    stdout.writeln('\n📡 [3/3] 灌入 $targetVersion 零重複高權重關鍵字、長描述與 What\'s New...');
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
        final String icon = patchRes.statusCode >= 200 && patchRes.statusCode < 300 ? '🟢' : '⚠️';
        stdout.writeln(
          '  $icon [$locale] ASO 更新回應 [${patchRes.statusCode}] (${keywords.length}/100 chars)',
        );
        if (patchRes.statusCode >= 400) {
          stdout.writeln('    ↳ ${patchRes.body}');
        }
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
        final String icon = postRes.statusCode >= 200 && postRes.statusCode < 300 ? '🟢' : '⚠️';
        stdout.writeln(
          '  $icon [$locale] 跨語系 ASO 新建回應 [${postRes.statusCode}] (${keywords.length}/100 chars)',
        );
        if (postRes.statusCode >= 400) {
          stdout.writeln('    ↳ ${postRes.body}');
        }
      }
    }
  }
}

Future<void> main() async {
  await AscV101AsoEngine.run();
  stdout.writeln('\n🎉 [DoseFlow 1.0.1 高爆量 ASO 火箭發射成功！]');
}
