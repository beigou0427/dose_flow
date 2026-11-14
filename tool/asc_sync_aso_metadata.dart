import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

String _generateToken(String keyId, String issuerId, String privateKeyPem) {
  final now = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
  final jwt = JWT({
    'iss': issuerId,
    'iat': now - 20,
    'exp': now + 1180,
    'aud': 'appstoreconnect-v1',
  }, header: {
    'alg': 'ES256',
    'kid': keyId,
    'typ': 'JWT',
  });
  return jwt.sign(ECPrivateKey(privateKeyPem), algorithm: JWTAlgorithm.ES256);
}

void main() async {
  print("\n==========================================================================");
  print("🚀 [ASO 專家元數據自動同步] 正在直連 Apple 官方 API 寫入美台雙語商店資料...");
  print("==========================================================================");

  const keyId = "853IQM8TC6VX";
  const issuerId = "7c8a4cba-398c-4e88-88bb-9252f72ecdc9";
  const appId = "6832583172";

  final p8Files = Directory('.').listSync().where((f) => f.path.contains('AuthKey_$keyId') && f.path.endsWith('.p8')).toList();
  final privateKeyPem = File(p8Files.first.path).readAsStringSync();
  final token = _generateToken(keyId, issuerId, privateKeyPem);
  final headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  const supportUrl = "https://github.com/beigou0427/dose_flow";

  final zhDesc = '''
正在使用猛健樂 (Mounjaro)、週纖達 (Wegovy)、胰妥讚 (Ozempic) 或善纖達 (Saxenda) 嗎？
「瘦瘦針紀錄 Pro」是專為 GLP-1 減重療程打造的 100% 離線隱私助手。

【核心特色】
1. 實時藥動學曲線：採用美國 FDA 仿單標準 Bateman 雙指數模型，精確預測 7 天半衰期衰退與波谷。
2. U-100 針筒換算器：乾粉胜肽混水一秒計算抽針刻度，徹底杜絕過量風險。
3. 8 大部位輪替地圖：自動避開肚臍 5 公分，預防皮下脂肪增生硬塊與瘀青。
4. 習慣達成環：每日蛋白質與補水目標追蹤，守護核心骨骼肌不流失。
5. 100% 離線隱私：無外部伺服器、免註冊帳號，所有健康數據僅存在您的裝置中。

【免責聲明】
本 App 僅供個人健康記錄與教育參考，所有代謝曲線均為數學推估，不代表實際血液測量值，亦不提供醫療建議或劑量調整指導。調整用藥前請務必諮詢您的處方主治醫師。
'''.trim();

  final enDesc = '''
Taking Mounjaro, Zepbound, Wegovy, Ozempic, or Compounded GLP-1 peptides?
DoseFlow is the #1 privacy-first companion built on clinical pharmacokinetics.

KEY FEATURES:
- Live Bateman PK Curve: Forecast your 7-day half-life decay and absorption peaks calibrated against FDA Prescribing Information.
- U-100 Syringe Calculator: Convert reconstituted peptide vials into exact insulin syringe units instantly.
- Smart 8-Quadrant Rotation: Rotate injection sites away from the navel to prevent bruising and lipohypertrophy.
- Anti-Muscle Loss Habits: Hit daily protein and hydration rings to preserve vital skeletal muscle.
- 100% Local-First Privacy: Zero external cloud servers. Zero account registration required.

DISCLAIMER:
DoseFlow is intended solely for personal health logging. All concentration curves are theoretical mathematical estimates derived from published FDA Prescribing Information (Section 12.3) and do not represent actual blood measurements. Always consult your prescribing physician before adjusting doses.
'''.trim();

  // 1. 同步 App 標題與副標題 (App Info Localizations)
  print("📡 [1/2] 正在同步 App 標題與副標題 (App Info)...");
  final appInfoRes = await http.get(
    Uri.parse('https://api.appstoreconnect.apple.com/v1/apps/$appId/appInfos'),
    headers: headers,
  );
  
  if (appInfoRes.statusCode == 200) {
    final appInfoList = jsonDecode(appInfoRes.body)['data'] as List? ?? [];
    if (appInfoList.isNotEmpty) {
      final appInfoId = appInfoList.first['id'].toString();
      
      final infoLocRes = await http.get(
        Uri.parse('https://api.appstoreconnect.apple.com/v1/appInfos/$appInfoId/appInfoLocalizations'),
        headers: headers,
      );
      final existingInfoLocs = jsonDecode(infoLocRes.body)['data'] as List? ?? [];
      
      final configs = [
        {
          'locale': 'zh-Hant',
          'name': '瘦瘦針紀錄 Pro - 猛健樂半衰期',
          'subtitle': 'GLP-1胰妥讚計算,防掉肌習慣與輪替',
        },
        {
          'locale': 'en-US',
          'name': 'DoseFlow: GLP-1 Shot Tracker',
          'subtitle': 'Peptide, Syringe & Dose Log',
        },
      ];

      for (final cfg in configs) {
        final loc = cfg['locale'] as String;
        final name = cfg['name'] as String;
        final subtitle = cfg['subtitle'] as String;
        
        final match = existingInfoLocs.where((l) => l['attributes']['locale'] == loc).toList();
        if (match.isNotEmpty) {
          final locId = match.first['id'];
          final patchRes = await http.patch(
            Uri.parse('https://api.appstoreconnect.apple.com/v1/appInfoLocalizations/$locId'),
            headers: headers,
            body: jsonEncode({
              'data': {
                'type': 'appInfoLocalizations',
                'id': locId,
                'attributes': {'name': name, 'subtitle': subtitle}
              }
            }),
          );
          if (patchRes.statusCode == 200) {
            print("  🟢 [$loc] 標題與副標題更新成功！(Name: $name)");
          } else {
            print("  ⚠️ [$loc] 標題更新回應 [${patchRes.statusCode}]: ${patchRes.body}");
          }
        } else {
          final postRes = await http.post(
            Uri.parse('https://api.appstoreconnect.apple.com/v1/appInfoLocalizations'),
            headers: headers,
            body: jsonEncode({
              'data': {
                'type': 'appInfoLocalizations',
                'attributes': {'locale': loc, 'name': name, 'subtitle': subtitle},
                'relationships': {
                  'appInfo': {'data': {'type': 'appInfos', 'id': appInfoId}}
                }
              }
            }),
          );
          if (postRes.statusCode == 201 || postRes.statusCode == 200) {
            print("  🟢 [$loc] 成功建立全新標題與副標題！(Name: $name)");
          }
        }
      }
    }
  }

  // 2. 同步版本關鍵字、描述與支援網址 (App Store Version Localizations)
  print("\n📡 [2/2] 正在同步關鍵字 (100 Bytes 極限卡位)、長描述與支援網址...");
  final verRes = await http.get(
    Uri.parse('https://api.appstoreconnect.apple.com/v1/apps/$appId/appStoreVersions?filter[platform]=IOS'),
    headers: headers,
  );

  if (verRes.statusCode == 200) {
    final verList = jsonDecode(verRes.body)['data'] as List? ?? [];
    if (verList.isNotEmpty) {
      final versionId = verList.first['id'].toString();
      
      final verLocRes = await http.get(
        Uri.parse('https://api.appstoreconnect.apple.com/v1/appStoreVersions/$versionId/appStoreVersionLocalizations'),
        headers: headers,
      );
      final existingVerLocs = jsonDecode(verLocRes.body)['data'] as List? ?? [];

      final versionConfigs = [
        {
          'locale': 'zh-Hant',
          'keywords': '瘦瘦針,猛健樂,胰妥讚,善纖達,減重,半衰期,劑量,蛋白質,便秘,副作用,計算機',
          'description': zhDesc,
        },
        {
          'locale': 'en-US',
          'keywords': 'mounjaro,zepbound,ozempic,wegovy,tirzepatide,semaglutide,peptide,u100,syringe,half,life,shotsy,compound',
          'description': enDesc,
        },
      ];

      for (final vcfg in versionConfigs) {
        final loc = vcfg['locale'] as String;
        final keywords = vcfg['keywords'] as String;
        final description = vcfg['description'] as String;

        final match = existingVerLocs.where((l) => l['attributes']['locale'] == loc).toList();
        if (match.isNotEmpty) {
          final locId = match.first['id'];
          final patchRes = await http.patch(
            Uri.parse('https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/$locId'),
            headers: headers,
            body: jsonEncode({
              'data': {
                'type': 'appStoreVersionLocalizations',
                'id': locId,
                'attributes': {
                  'keywords': keywords,
                  'description': description,
                  'supportUrl': supportUrl,
                  'marketingUrl': supportUrl,
                }
              }
            }),
          );
          if (patchRes.statusCode == 200) {
            print("  🟢 [$loc] 關鍵字 (${utf8.encode(keywords).length} Bytes) 與長描述同步成功！");
          } else {
            print("  ⚠️ [$loc] 版本描述更新回應 [${patchRes.statusCode}]: ${patchRes.body}");
          }
        } else {
          final postRes = await http.post(
            Uri.parse('https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations'),
            headers: headers,
            body: jsonEncode({
              'data': {
                'type': 'appStoreVersionLocalizations',
                'attributes': {
                  'locale': loc,
                  'keywords': keywords,
                  'description': description,
                  'supportUrl': supportUrl,
                  'marketingUrl': supportUrl,
                },
                'relationships': {
                  'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': versionId}}
                }
              }
            }),
          );
          if (postRes.statusCode == 201 || postRes.statusCode == 200) {
            print("  🟢 [$loc] 成功建立全新語系版本描述與關鍵字！");
          }
        }
      }
    }
  }

  print("\n==========================================================================");
  print("🎉 [ASO 專家元數據全部注入完成] 美台雙語商店頁面已達頂級出海競價標準！");
  print("==========================================================================");
}
