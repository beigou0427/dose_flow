import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

class AscAssetUploader {
  AscAssetUploader._();

  static const String keyId = '853IQM8TC6VX';
  static const String lifetimeId = '6832587006';
  static const String versionId = '277e9a5f-25ce-4e00-96e4-156eda75812c';
  static const String baseUrl = 'https://api.appstoreconnect.apple.com';

  static Future<Map<String, String>> buildAuthHeaders() async {
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

  static String computeMd5(String path) {
    return Process.runSync('md5', <String>['-q', path]).stdout.toString().trim();
  }

  static Future<void> fixLifetimeIap(Map<String, String> headers) async {
    stdout.writeln('\n📡 [1/2] 修復終身版 IAP ($lifetimeId) 雙語文案並檢查狀態...');
    final http.Response locRes = await http.get(
      Uri.parse(
        '$baseUrl/v2/inAppPurchases/$lifetimeId/inAppPurchaseLocalizations',
      ),
      headers: headers,
    );
    final Set<String> existing = <String>{};
    if (locRes.statusCode == 200) {
      final List<dynamic> data =
          ((jsonDecode(locRes.body) as Map<String, dynamic>)['data']
                  as List<dynamic>?) ??
              <dynamic>[];
      for (final dynamic item in data) {
        final Map<String, dynamic> attrs =
            (item as Map<String, dynamic>)['attributes'] as Map<String, dynamic>;
        existing.add(attrs['locale'].toString());
      }
    }

    for (final Map<String, String> cfg in <Map<String, String>>[
      <String, String>{
        'locale': 'zh-Hant',
        'name': '終身買斷尊爵版',
        'description': '一次付費永久解鎖 GLP-1 代謝曲線與針筒工具',
      },
      <String, String>{
        'locale': 'en-US',
        'name': 'Lifetime Platinum Reserve',
        'description': 'Lifetime access to all GLP-1 PK curves and tools',
      },
    ]) {
      if (!existing.contains(cfg['locale'])) {
        final http.Response postRes = await http.post(
          Uri.parse('$baseUrl/v1/inAppPurchaseLocalizations'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'inAppPurchaseLocalizations',
              'attributes': <String, dynamic>{
                'locale': cfg['locale'],
                'name': cfg['name'],
                'description': cfg['description'],
              },
              'relationships': <String, dynamic>{
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
        stdout.writeln(
          '  ‣ 建立終身版語系 ${cfg['locale']} [${postRes.statusCode}]',
        );
      }
    }

    final http.Response check = await http.get(
      Uri.parse('$baseUrl/v2/inAppPurchases/$lifetimeId'),
      headers: headers,
    );
    if (check.statusCode == 200) {
      final String state =
          (((jsonDecode(check.body) as Map<String, dynamic>)['data']
                  as Map<String, dynamic>)['attributes']
              as Map<String, dynamic>)['state']
              .toString();
      stdout.writeln('  🟢 com.doseflow.app.lifetime 最新狀態 -> $state');
    }
  }

  static Future<String?> ensureScreenshotSet(
    Map<String, String> headers,
    String verLocId,
    String displayType,
  ) async {
    final http.Response getRes = await http.get(
      Uri.parse(
        '$baseUrl/v1/appStoreVersionLocalizations/$verLocId/appScreenshotSets',
      ),
      headers: headers,
    );
    if (getRes.statusCode == 200) {
      final List<dynamic> sets =
          ((jsonDecode(getRes.body) as Map<String, dynamic>)['data']
                  as List<dynamic>?) ??
              <dynamic>[];
      for (final dynamic s in sets) {
        final Map<String, dynamic> sm = s as Map<String, dynamic>;
        final Map<String, dynamic> attrs =
            sm['attributes'] as Map<String, dynamic>;
        if (attrs['screenshotDisplayType'] == displayType) {
          return sm['id'].toString();
        }
      }
    }

    final http.Response postRes = await http.post(
      Uri.parse('$baseUrl/v1/appScreenshotSets'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'data': <String, dynamic>{
          'type': 'appScreenshotSets',
          'attributes': <String, dynamic>{
            'screenshotDisplayType': displayType,
          },
          'relationships': <String, dynamic>{
            'appStoreVersionLocalization': <String, dynamic>{
              'data': <String, dynamic>{
                'type': 'appStoreVersionLocalizations',
                'id': verLocId,
              },
            },
          },
        },
      }),
    );
    if (postRes.statusCode == 201 || postRes.statusCode == 200) {
      final String setId = ((jsonDecode(postRes.body)
              as Map<String, dynamic>)['data'] as Map<String, dynamic>)['id']
          .toString();
      stdout.writeln('  🟢 建立截圖群組 $displayType 成功 (ID: $setId)');
      return setId;
    } else {
      stdout.writeln(
        '  ℹ️ 群組 $displayType 回應 [${postRes.statusCode}]: ${postRes.body}',
      );
      return null;
    }
  }

  static Future<void> uploadOneScreenshot(
    Map<String, String> headers,
    String setId,
    String filePath,
  ) async {
    final File file = File(filePath);
    if (!file.existsSync()) return;
    final Uint8List bytes = file.readAsBytesSync();
    final String fileName = filePath.split('/').last;
    final String md5Hex = computeMd5(filePath);

    final http.Response res = await http.post(
      Uri.parse('$baseUrl/v1/appScreenshots'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'data': <String, dynamic>{
          'type': 'appScreenshots',
          'attributes': <String, dynamic>{
            'fileName': fileName,
            'fileSize': bytes.length,
          },
          'relationships': <String, dynamic>{
            'appScreenshotSet': <String, dynamic>{
              'data': <String, dynamic>{
                'type': 'appScreenshotSets',
                'id': setId,
              },
            },
          },
        },
      }),
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      stderr.writeln('    🔴 預約截圖 $fileName 失敗 [${res.statusCode}]: ${res.body}');
      return;
    }

    final Map<String, dynamic> data =
        (jsonDecode(res.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final String shotId = data['id'].toString();
    final List<dynamic> ops = ((data['attributes']
            as Map<String, dynamic>)['uploadOperations'] as List<dynamic>?) ??
        <dynamic>[];

    for (final dynamic opRaw in ops) {
      final Map<String, dynamic> op = opRaw as Map<String, dynamic>;
      final int offset = (op['offset'] as num).toInt();
      final int length = (op['length'] as num).toInt();
      final Map<String, String> upHeaders = <String, String>{};
      for (final dynamic h
          in (op['requestHeaders'] as List<dynamic>? ?? <dynamic>[])) {
        final Map<String, dynamic> hm = h as Map<String, dynamic>;
        upHeaders[hm['name'].toString()] = hm['value'].toString();
      }
      await http.put(
        Uri.parse(op['url'].toString()),
        headers: upHeaders,
        body: bytes.sublist(offset, offset + length),
      );
    }

    final http.Response commit = await http.patch(
      Uri.parse('$baseUrl/v1/appScreenshots/$shotId'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'data': <String, dynamic>{
          'type': 'appScreenshots',
          'id': shotId,
          'attributes': <String, dynamic>{
            'sourceFileChecksum': md5Hex,
            'uploaded': true,
          },
        },
      }),
    );
    if (commit.statusCode == 200) {
      stdout.writeln('    🟢 上傳完成: $fileName');
    } else {
      stderr.writeln(
        '    ⚠️ 提交截圖 $fileName 回應 [${commit.statusCode}]: ${commit.body}',
      );
    }
  }

  static Future<void> uploadAllAppScreenshots(
    Map<String, String> headers,
  ) async {
    stdout.writeln('\n📡 [2/2] 上傳雙語 iPhone 6.7" 截圖 ＋ 實測 iPhone Duo 認證截圖...');
    final http.Response locRes = await http.get(
      Uri.parse(
        '$baseUrl/v1/appStoreVersions/$versionId/appStoreVersionLocalizations',
      ),
      headers: headers,
    );
    final List<dynamic> locs =
        ((jsonDecode(locRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>?) ??
            <dynamic>[];

    for (final dynamic l in locs) {
      final Map<String, dynamic> lm = l as Map<String, dynamic>;
      final String locId = lm['id'].toString();
      final String locale =
          (lm['attributes'] as Map<String, dynamic>)['locale'].toString();
      if (locale != 'zh-Hant' && locale != 'en-US') continue;
      stdout.writeln('\n  🌐 處理語系 [$locale] 截圖:');

      final String? set67 =
          await ensureScreenshotSet(headers, locId, 'APP_IPHONE_67');
      if (set67 != null) {
        final http.Response existingShots = await http.get(
          Uri.parse('$baseUrl/v1/appScreenshotSets/$set67/appScreenshots'),
          headers: headers,
        );
        final List<dynamic> cur = ((jsonDecode(existingShots.body)
                as Map<String, dynamic>)['data'] as List<dynamic>?) ??
            <dynamic>[];
        if (cur.isEmpty) {
          for (int i = 1; i <= 5; i++) {
            await uploadOneScreenshot(
              headers,
              set67,
              'tool/screenshots/${locale}_67_$i.jpg',
            );
          }
        } else {
          stdout.writeln('    🟢 APP_IPHONE_67 已有 ${cur.length} 張截圖');
        }
      }

      final String? setDuo =
          await ensureScreenshotSet(headers, locId, 'APP_IPHONE_DUO');
      if (setDuo != null) {
        final http.Response existingDuo = await http.get(
          Uri.parse('$baseUrl/v1/appScreenshotSets/$setDuo/appScreenshots'),
          headers: headers,
        );
        final List<dynamic> curDuo = ((jsonDecode(existingDuo.body)
                as Map<String, dynamic>)['data'] as List<dynamic>?) ??
            <dynamic>[];
        if (curDuo.isEmpty) {
          await uploadOneScreenshot(
            headers,
            setDuo,
            'tool/screenshots/${locale}_duo_outer_1.jpg',
          );
          await uploadOneScreenshot(
            headers,
            setDuo,
            'tool/screenshots/${locale}_duo_inner_1.jpg',
          );
        } else {
          stdout.writeln('    🟢 APP_IPHONE_DUO 已有 ${curDuo.length} 張截圖');
        }
      }
    }
  }
}

Future<void> main() async {
  stdout.writeln('🚀 啟動 DoseFlow 終身版 IAP 修復 ＋ 雙語/iPhone Duo 截圖全自動上傳...');
  final Map<String, String> headers =
      await AscAssetUploader.buildAuthHeaders();
  await AscAssetUploader.fixLifetimeIap(headers);
  await AscAssetUploader.uploadAllAppScreenshots(headers);
  stdout.writeln('\n🎉 [截圖與 IAP 修復完成] 請把輸出貼給我，立即執行審查聯絡人與最後送審！');
}
