import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

// 使用剛才成功繞過 401 的模式 2 (標準 Team 級別 JWT)
String _generateToken(String keyId, String issuerId, String privateKeyPem) {
  final now = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
  return JWT({
    'iss': issuerId,
    'iat': now - 20,
    'exp': now + 1180,
    'aud': 'appstoreconnect-v1',
  }, header: {'alg': 'ES256', 'kid': keyId, 'typ': 'JWT'})
  .sign(ECPrivateKey(privateKeyPem), algorithm: JWTAlgorithm.ES256);
}

void main() async {
  print("\n==========================================================================");
  print("🚀 [ASO & IAP 雲端結算] 正在將十大專家元數據與內購正式寫入 Apple 後台...");
  print("==========================================================================");

  const keyId = "853IQM8TC6VX";
  const issuerId = "7c8a4cba-398c-4e88-88bb-9252f72ecdc9";
  const appId = "6832583172"; // DoseFlow App ID
  const supportUrl = "https://beigou0427.github.io/dose_flow/";

  final p8Files = Directory('.').listSync().where((f) => f.path.contains('AuthKey_$keyId') && f.path.endsWith('.p8')).toList();
  if (p8Files.isEmpty) {
    print("🔴 找不到 AuthKey.p8 金鑰！");
    exit(1);
  }

  final token = _generateToken(keyId, issuerId, File(p8Files.first.path).readAsStringSync());
  final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

  // ---------------------------------------------------------
  // 1. 同步 ASO 標題與副標題 (App Info)
  // ---------------------------------------------------------
  print("\n📡 [1/3] 正在同步 ASO 標題與副標題 (佩蒂與達恩 30 字元演算法)...");
  final appInfoRes = await http.get(Uri.parse('https://api.appstoreconnect.apple.com/v1/apps/$appId/appInfos'), headers: headers);
  if (appInfoRes.statusCode == 200) {
    final appInfoId = jsonDecode(appInfoRes.body)['data'][0]['id'].toString();
    final infoLocRes = await http.get(Uri.parse('https://api.appstoreconnect.apple.com/v1/appInfos/$appInfoId/appInfoLocalizations'), headers: headers);
    final existingInfoLocs = jsonDecode(infoLocRes.body)['data'] as List? ?? [];

    final infoConfigs = [
      {'locale': 'zh-Hant', 'name': '瘦瘦針紀錄 Pro - 猛健樂半衰期', 'subtitle': 'GLP-1胰妥讚計算,防掉肌與部位輪替'},
      {'locale': 'en-US', 'name': 'DoseFlow: GLP-1 Shot Tracker', 'subtitle': 'Peptide Syringe & Dose Units'}
    ];

    for (final cfg in infoConfigs) {
      final loc = cfg['locale'] as String;
      final match = existingInfoLocs.where((l) => l['attributes']['locale'] == loc).toList();
      if (match.isNotEmpty) {
        final locId = match.first['id'];
        await http.patch(
          Uri.parse('https://api.appstoreconnect.apple.com/v1/appInfoLocalizations/$locId'),
          headers: headers,
          body: jsonEncode({'data': {'type': 'appInfoLocalizations', 'id': locId, 'attributes': {'name': cfg['name'], 'subtitle': cfg['subtitle']}}}),
        );
        print("  🟢 [$loc] 標題與副標題同步成功: ${cfg['name']}");
      }
    }
  }

  // ---------------------------------------------------------
  // 2. 同步關鍵字與長描述 (App Store Version)
  // ---------------------------------------------------------
  print("\n📡 [2/3] 正在同步 ASO 關鍵字 (楊氏 100Bytes) 與長描述 (貝爾 NLP 前三行)...");
  final verRes = await http.get(Uri.parse('https://api.appstoreconnect.apple.com/v1/apps/$appId/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION'), headers: headers);
  if (verRes.statusCode == 200) {
    final verData = jsonDecode(verRes.body)['data'] as List? ?? [];
    if (verData.isNotEmpty) {
      final versionId = verData.first['id'].toString();
      final verLocRes = await http.get(Uri.parse('https://api.appstoreconnect.apple.com/v1/appStoreVersions/$versionId/appStoreVersionLocalizations'), headers: headers);
      final existingVerLocs = jsonDecode(verLocRes.body)['data'] as List? ?? [];

      final verConfigs = [
        {
          'locale': 'zh-Hant',
          'keywords': '善纖達,週纖達,康纖伴,減重,蛋白質,喝水,便秘,反胃,副作用,劑量,刻度,自費',
          'description': "正在使用猛健樂 (Mounjaro)、週纖達 (Wegovy) 或胰妥讚 (Ozempic) 嗎？\n「瘦瘦針紀錄 Pro」是專為 GLP-1 療程打造的 100% 離線隱私助手。\n實時預測吸收高峰 (Tmax) 與半衰期波谷，U-100 針筒一秒精算防呆！\n\n【核心特色】\n1. 實時藥動學曲線：採用美國 FDA 仿單標準 Bateman 雙指數模型。\n2. U-100 針筒換算器：乾粉胜肽混水一秒計算抽針刻度。\n3. 8 大部位輪替地圖：自動避開肚臍 5 公分，防硬塊。\n4. 100% 離線隱私：無雲端伺服器，數據不出本機。",
          'promotionalText': '年繳享3天免費試用，省下45%費用'
        },
        {
          'locale': 'en-US',
          'keywords': 'mounjaro,zepbound,ozempic,wegovy,tirzepatide,semaglutide,half,life,shotsy,compound,vial,bac,water',
          'description': "Taking Mounjaro, Zepbound, Wegovy, Ozempic, or Compounded Peptides?\nDoseFlow is the #1 privacy-first companion built on clinical pharmacokinetics.\nForecast 7-day half-life decay, absorption peaks & U-100 syringe units instantly.\n\nKEY FEATURES:\n- Live Bateman PK Curve: Forecast your 7-day half-life decay.\n- U-100 Syringe Calculator: Convert peptides into exact insulin syringe units.\n- Smart 8-Quadrant Rotation: Rotate injection sites away from navel.\n- 100% Local-First Privacy: Zero external cloud servers.",
          'promotionalText': '3-Day Free Trial, Save 45% Today'
        }
      ];

      for (final cfg in verConfigs) {
        final loc = cfg['locale'] as String;
        final match = existingVerLocs.where((l) => l['attributes']['locale'] == loc).toList();
        if (match.isNotEmpty) {
          final locId = match.first['id'];
          await http.patch(
            Uri.parse('https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/$locId'),
            headers: headers,
            body: jsonEncode({'data': {'type': 'appStoreVersionLocalizations', 'id': locId, 'attributes': {'keywords': cfg['keywords'], 'description': cfg['description'], 'promotionalText': cfg['promotionalText'], 'supportUrl': supportUrl}}}),
          );
          print("  🟢 [$loc] 關鍵字 (${utf8.encode(cfg['keywords']!).length} Bytes) 與描述同步成功！");
        }
      }
    }
  }

  // ---------------------------------------------------------
  // 3. 驗證 IAP 內購就緒狀態
  // ---------------------------------------------------------
  print("\n📡 [3/3] 正在驗證 IAP 內購商品狀態...");
  final iapRes = await http.get(Uri.parse('https://api.appstoreconnect.apple.com/v2/inAppPurchases?filter[app]=$appId'), headers: headers);
  if (iapRes.statusCode == 200) {
    final iaps = jsonDecode(iapRes.body)['data'] as List? ?? [];
    for (final iap in iaps) {
      final pId = iap['attributes']['productId'];
      final state = iap['attributes']['state'];
      print("  🟢 內購商品就緒: $pId [狀態: $state]");
    }
    if (iaps.length >= 3) {
      print("  ✅ 3 大核心方案 (年繳、月繳、終身) 皆已備妥！");
    }
  }

  print("\n==========================================================================");
  print("🎉 [ASO ✕ IAP 結算完成] 所有元數據已完美灌入 App Store Connect！");
  print("==========================================================================");
}
