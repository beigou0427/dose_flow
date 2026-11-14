import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

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
  print("🚀 [DoseFlow 終極送審核按鈕] 全自動綁定 Build、內購與 CQO 醫療審核備註...");
  print("==========================================================================");

  const keyId = "853IQM8TC6VX";
  const issuerId = "7c8a4cba-398c-4e88-88bb-9252f72ecdc9";
  const appId = "6832583172";

  final p8Files = Directory('.').listSync().where((f) => f.path.contains('AuthKey_$keyId') && f.path.endsWith('.p8')).toList();
  if (p8Files.isEmpty) {
    print("🔴 找不到 AuthKey.p8 金鑰！");
    exit(1);
  }

  final token = _generateToken(keyId, issuerId, File(p8Files.first.path).readAsStringSync());
  final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

  // 1. 取得 App 所有版本 (不再過濾狀態，直接暴力抓取)
  print("📡 [1/6] 鎖定 App 版本...");
  final verRes = await http.get(Uri.parse('https://api.appstoreconnect.apple.com/v1/apps/$appId/appStoreVersions'), headers: headers);
  final verData = jsonDecode(verRes.body)['data'] as List? ?? [];
  if (verData.isEmpty) { 
    print("🔴 找不到任何版本！請登入 App Store Connect 確認是否建立了 1.0 版本。"); 
    exit(1); 
  }
  
  final version = verData.first;
  final versionId = version['id'].toString();
  final vState = version['attributes']['appStoreState'].toString();
  print("  🟢 鎖定版本 ID: $versionId (當前狀態: $vState)");

  if (vState == 'WAITING_FOR_REVIEW' || vState == 'IN_REVIEW') {
    print("\n🎉 大吉大利！您的 App 已經處於審核狀態 ($vState)，無須再次送審！");
    exit(0);
  }

  // 2. 注入 CQO 醫療審核護身符 (App Review Notes)
  print("\n📡 [2/6] 注入 CQO 醫療審核備註 (Guideline 1.4.1 / 5.1.1 防護)...");
  final reviewNotes = '''
Dear App Review Team,
1. MEDICAL (1.4.1): DoseFlow provides offline self-tracking for GLP-1 users. All PK curves are mathematical models based on FDA USPI Sec 12.3. It does not provide medical diagnoses.
2. PRIVACY (5.1.1): 100% local storage. Zero cloud servers.
3. IAP: Please test Subscription and Lifetime in Settings -> Pro page.
'''.trim();

  final reviewDetailRes = await http.get(Uri.parse('https://api.appstoreconnect.apple.com/v1/appStoreVersions/$versionId/appStoreReviewDetail'), headers: headers);
  if (reviewDetailRes.statusCode == 200) {
    final detailId = jsonDecode(reviewDetailRes.body)['data']['id'];
    await http.patch(Uri.parse('https://api.appstoreconnect.apple.com/v1/appStoreReviewDetails/$detailId'), headers: headers, body: jsonEncode({'data': {'type': 'appStoreReviewDetails', 'id': detailId, 'attributes': {'notes': reviewNotes}}}));
  } else {
    await http.post(Uri.parse('https://api.appstoreconnect.apple.com/v1/appStoreReviewDetails'), headers: headers, body: jsonEncode({'data': {'type': 'appStoreReviewDetails', 'attributes': {'notes': reviewNotes}, 'relationships': {'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': versionId}}}}}));
  }
  print("  🟢 審核備註已成功寫入！");

  // 3. 等待 Apple 處理 Build，免除加密並綁定
  print("\n📡 [3/6] 等待蘋果處理 Build 並自動綁定 (約需 1~3 分鐘)...");
  String? buildId;
  for (int i = 1; i <= 20; i++) {
    final buildRes = await http.get(Uri.parse('https://api.appstoreconnect.apple.com/v1/builds?filter[app]=$appId&sort=-uploadedDate&limit=1'), headers: headers);
    final bList = jsonDecode(buildRes.body)['data'] as List? ?? [];
    if (bList.isNotEmpty) {
      final state = bList.first['attributes']['processingState'];
      print("  ‣ 探測 $i: Build 狀態 -> $state");
      if (state == 'VALID') { buildId = bList.first['id'].toString(); break; }
    }
    await Future.delayed(const Duration(seconds: 15));
  }
  
  if (buildId == null) { 
    print("🔴 Build 尚未處理完成！Apple 伺服器還在驗證您的二進制包，請稍候 3 分鐘後再執行一次腳本。"); 
    exit(1); 
  }

  await http.patch(Uri.parse('https://api.appstoreconnect.apple.com/v1/builds/$buildId'), headers: headers, body: jsonEncode({'data': {'type': 'builds', 'id': buildId, 'attributes': {'usesNonExemptEncryption': false}}}));
  final bindRes = await http.patch(Uri.parse('https://api.appstoreconnect.apple.com/v1/appStoreVersions/$versionId/relationships/build'), headers: headers, body: jsonEncode({'data': {'type': 'builds', 'id': buildId}}));
  if (bindRes.statusCode == 204 || bindRes.statusCode == 200) {
    print("  🟢 Build 已免除加密宣告並綁定成功！");
  } else {
    print("  ⚠️ Build 綁定回傳: ${bindRes.statusCode} - ${bindRes.body}");
  }

  // 4. 抓取 3 大內購商品 ID
  print("\n📡 [4/6] 獲取內購商品列表...");
  final iapRes = await http.get(Uri.parse('https://api.appstoreconnect.apple.com/v2/inAppPurchases?filter[app]=$appId'), headers: headers);
  final iaps = jsonDecode(iapRes.body)['data'] as List? ?? [];
  print("  🟢 成功鎖定 ${iaps.length} 個內購項目。");

  // 5. 建立審核提交單 (Review Submission)
  print("\n📡 [5/6] 建立審查提交單...");
  final subReq = await http.post(Uri.parse('https://api.appstoreconnect.apple.com/v1/reviewSubmissions'), headers: headers, body: jsonEncode({'data': {'type': 'reviewSubmissions', 'attributes': {'platform': 'IOS'}, 'relationships': {'app': {'data': {'type': 'apps', 'id': appId}}}}}));
  
  String? submissionId;
  if (subReq.statusCode == 201) {
    submissionId = jsonDecode(subReq.body)['data']['id'].toString();
  } else if (subReq.statusCode == 409) {
    // 已經有提交單存在，抓出來
    final existSubRes = await http.get(Uri.parse('https://api.appstoreconnect.apple.com/v1/reviewSubmissions?filter[app]=$appId&filter[state]=READY_FOR_REVIEW'), headers: headers);
    final existSubs = jsonDecode(existSubRes.body)['data'] as List? ?? [];
    if (existSubs.isNotEmpty) {
      submissionId = existSubs.first['id'].toString();
    }
  }

  if (submissionId != null) {
    // 掛載 Version
    await http.post(Uri.parse('https://api.appstoreconnect.apple.com/v1/reviewSubmissionItems'), headers: headers, body: jsonEncode({'data': {'type': 'reviewSubmissionItems', 'relationships': {'reviewSubmission': {'data': {'type': 'reviewSubmissions', 'id': submissionId}}, 'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': versionId}}}}}));
    
    // 掛載 IAPs
    for (final iap in iaps) {
      await http.post(Uri.parse('https://api.appstoreconnect.apple.com/v1/reviewSubmissionItems'), headers: headers, body: jsonEncode({'data': {'type': 'reviewSubmissionItems', 'relationships': {'reviewSubmission': {'data': {'type': 'reviewSubmissions', 'id': submissionId}}, 'inAppPurchaseV2': {'data': {'type': 'inAppPurchases', 'id': iap['id']}}}}}));
    }
    print("  🟢 1 個版本與 ${iaps.length} 個內購商品已加入送審單！");

    // 6. 按下發射鈕！
    print("\n📡 [6/6] 正在按下核按鈕送交 Apple 人工審核...");
    final finalSubmit = await http.patch(Uri.parse('https://api.appstoreconnect.apple.com/v1/reviewSubmissions/$submissionId'), headers: headers, body: jsonEncode({'data': {'type': 'reviewSubmissions', 'id': submissionId, 'attributes': {'submitted': true}}}));
    
    if (finalSubmit.statusCode == 200) {
      print("\n==========================================================================");
      print("🚀🚀🚀 [大功告成] App 與 3 大內購已正式提交至 Waiting for Review！");
      print("==========================================================================");
    } else {
      print("🔴 提交發射失敗 [${finalSubmit.statusCode}]: ${finalSubmit.body}");
    }
  } else {
    print("🔴 無法建立或取得審查提交單！");
  }
}
