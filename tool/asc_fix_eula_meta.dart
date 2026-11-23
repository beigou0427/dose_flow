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
  const String versionId = '277e9a5f-25ce-4e00-96e4-156eda75812c';
  const String reviewDetailId = 'd7c32fdf-3111-43e3-9710-51ac0791aec2';
  const String baseUrl = 'https://api.appstoreconnect.apple.com';
  final Map<String, String> headers = await buildHeaders();

  final http.Response vRes = await http.get(
    Uri.parse('$baseUrl/v1/appStoreVersions/$versionId'),
    headers: headers,
  );
  final String vState = ((jsonDecode(vRes.body) as Map<String, dynamic>)['data']
          as Map<String, dynamic>)['attributes']['appStoreState']
      .toString();
  stdout.writeln('📱 目前 Version 1.0 狀態: $vState');

  const String zhDesc = '''正在使用猛健樂 (Mounjaro)、週纖達 (Wegovy) 或胰妥讚 (Ozempic) 嗎？
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
• 隱私權政策：https://beigou0427.github.io/dose_flow/privacy.html''';

  const String enDesc = '''Taking Mounjaro, Zepbound, Wegovy, Ozempic, or Compounded Peptides?
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
- Privacy Policy: https://beigou0427.github.io/dose_flow/privacy.html''';

  final http.Response locRes = await http.get(
    Uri.parse(
      '$baseUrl/v1/appStoreVersions/$versionId/appStoreVersionLocalizations',
    ),
    headers: headers,
  );
  for (final dynamic item
      in ((jsonDecode(locRes.body) as Map<String, dynamic>)['data']
              as List<dynamic>? ??
          <dynamic>[])) {
    final Map<String, dynamic> m = item as Map<String, dynamic>;
    final String locId = m['id'].toString();
    final String locale =
        (m['attributes'] as Map<String, dynamic>)['locale'].toString();
    if (locale != 'zh-Hant' && locale != 'en-US') continue;

    final Map<String, dynamic> attrs = locale == 'zh-Hant'
        ? <String, dynamic>{
            'description': zhDesc,
            'keywords': '猛健樂,胰妥讚,善纖達,週纖達,減重,瘦身,蛋白,喝水,便秘,反胃,計算,自費',
          }
        : <String, dynamic>{
            'description': enDesc,
          };

    final http.Response patchRes = await http.patch(
      Uri.parse('$baseUrl/v1/appStoreVersionLocalizations/$locId'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'data': <String, dynamic>{
          'type': 'appStoreVersionLocalizations',
          'id': locId,
          'attributes': attrs,
        },
      }),
    );
    if (patchRes.statusCode == 200) {
      stdout.writeln('🟢 [$locale] 描述已成功補入 Apple 標準 EULA 與隱私連結！');
    } else {
      stderr.writeln(
        '⚠️ [$locale] 描述更新回應 [${patchRes.statusCode}]: ${patchRes.body}',
      );
    }
  }

  final http.Response rdPatch = await http.patch(
    Uri.parse('$baseUrl/v1/appStoreReviewDetails/$reviewDetailId'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{
        'type': 'appStoreReviewDetails',
        'id': reviewDetailId,
        'attributes': const <String, dynamic>{
          'notes':
              '1. PRICE CONFIRMATION: Yes, Lifetime Platinum Reserve (\$119.99 USD) is our exact intended price.\n2. EULA: Standard Apple Terms of Use (https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) has been added to all localized App Descriptions and in-app Paywall.\n3. MEDICAL (1.4.1): Offline personal health log calibrated to FDA USPI Sec 12.3.\n4. PRIVACY (5.1.1): 100% Local-First, zero cloud servers.',
        },
      },
    }),
  );
  stdout.writeln('🟢 App Review Notes 價格確認寫入回應 [${rdPatch.statusCode}]');

  // Check active reviewSubmissions
  final http.Response subRes = await http.get(
    Uri.parse('$baseUrl/v1/apps/$appId/reviewSubmissions'),
    headers: headers,
  );
  for (final dynamic s
      in ((jsonDecode(subRes.body) as Map<String, dynamic>)['data']
              as List<dynamic>? ??
          <dynamic>[])) {
    final Map<String, dynamic> sm = s as Map<String, dynamic>;
    final String st =
        (sm['attributes'] as Map<String, dynamic>)['state'].toString();
    if (st != 'CANCELED' && st != 'COMPLETE') {
      stdout.writeln('📋 當前進行中送審單 ${sm['id']} -> 狀態: $st');
    }
  }
}
