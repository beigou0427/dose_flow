import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

class AscUploadEngine {
  AscUploadEngine._();

  static const String keyId = '853IQM8TC6VX';
  static const String issuerId = '7c8a4cba-398c-4e88-88bb-9252f72ecdc9';
  static const String appId = '6832583172';
  static const String lifetimeId = '6832587006';
  static const String supportUrl = 'https://beigou0427.github.io/dose_flow/';
  static const String privacyUrl =
      'https://beigou0427.github.io/dose_flow/privacy.html';
  static const String baseUrl = 'https://api.appstoreconnect.apple.com';

  static String loadPrivateKeyPem() {
    final List<FileSystemEntity> p8Files = Directory('.')
        .listSync()
        .where((FileSystemEntity f) =>
            f.path.contains('AuthKey_$keyId') && f.path.endsWith('.p8'))
        .toList();
    if (p8Files.isEmpty) {
      stderr.writeln('🔴 找不到 AuthKey_$keyId.p8，請確認位於 ~/Desktop/dose_flow');
      exit(1);
    }
    final String content = File(p8Files.first.path).readAsStringSync().trim();
    stdout.writeln('🟢 金鑰鎖定: ${p8Files.first.path} (${content.length} bytes)');
    return '$content\n';
  }

  static Future<int> fetchAppleServerEpochSeconds() async {
    final int localEpoch =
        (DateTime.now().toUtc().millisecondsSinceEpoch / 1000).floor();
    try {
      final http.Response probe = await http
          .get(Uri.parse('$baseUrl/v1/apps'))
          .timeout(const Duration(seconds: 8));
      final String? dateHeader = probe.headers['date'];
      if (dateHeader != null && dateHeader.isNotEmpty) {
        final DateTime appleUtc = HttpDate.parse(dateHeader).toUtc();
        return (appleUtc.millisecondsSinceEpoch / 1000).floor();
      }
    } catch (_) {}
    return localEpoch;
  }

  static String generateJwt({
    required String privateKeyPem,
    required int epochSeconds,
    required int mode,
  }) {
    late final Map<String, dynamic> payload;
    if (mode == 2) {
      payload = <String, dynamic>{
        'sub': 'user',
        'iat': epochSeconds - 30,
        'exp': epochSeconds + 1100,
        'aud': 'appstoreconnect-v1',
      };
    } else if (mode == 1) {
      payload = <String, dynamic>{
        'iss': issuerId,
        'iat': epochSeconds - 30,
        'exp': epochSeconds + 1100,
        'aud': 'appstoreconnect-v1',
      };
    } else {
      payload = <String, dynamic>{
        'iss': issuerId,
        'sub': 'user',
        'iat': epochSeconds - 30,
        'exp': epochSeconds + 1100,
        'aud': 'appstoreconnect-v1',
      };
    }

    final JWT jwt = JWT(
      payload,
      header: const <String, dynamic>{
        'alg': 'ES256',
        'kid': keyId,
        'typ': 'JWT',
      },
    );
    return jwt.sign(
      ECPrivateKey(privateKeyPem),
      algorithm: JWTAlgorithm.ES256,
      noIssueAt: true,
    );
  }

  static Future<Map<String, String>?> negotiateAuthHeaders(
    String privateKeyPem,
  ) async {
    final int appleEpoch = await fetchAppleServerEpochSeconds();
    for (final int mode in <int>[2, 1, 3]) {
      final String token = generateJwt(
        privateKeyPem: privateKeyPem,
        epochSeconds: appleEpoch,
        mode: mode,
      );
      final Map<String, String> headers = <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final http.Response res = await http
          .get(Uri.parse('$baseUrl/v1/apps/$appId'), headers: headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final Map<String, dynamic> decoded =
            jsonDecode(res.body) as Map<String, dynamic>;
        final Map<String, dynamic> data =
            decoded['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final Map<String, dynamic> attrs =
            data['attributes'] as Map<String, dynamic>? ?? <String, dynamic>{};
        stdout.writeln(
          '🟢 Apple 認證通過 (Mode $mode) -> App: ${attrs['name']}',
        );
        return headers;
      }
    }
    stderr.writeln('🔴 認證失敗，請檢查金鑰與網路狀態。');
    return null;
  }

  static Future<String?> fetchAppInfoId(Map<String, String> headers) async {
    final http.Response res = await http.get(
      Uri.parse('$baseUrl/v1/apps/$appId/appInfos'),
      headers: headers,
    );
    if (res.statusCode != 200) return null;
    final Map<String, dynamic> decoded =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> list =
        decoded['data'] as List<dynamic>? ?? <dynamic>[];
    if (list.isEmpty) return null;
    return (list.first as Map<String, dynamic>)['id'].toString();
  }

  static Future<Map<String, String>?> findEditableVersion(
    Map<String, String> headers,
  ) async {
    final http.Response verRes = await http.get(
      Uri.parse('$baseUrl/v1/apps/$appId/appStoreVersions?filter[platform]=IOS'),
      headers: headers,
    );
    if (verRes.statusCode != 200) return null;
    final Map<String, dynamic> decoded =
        jsonDecode(verRes.body) as Map<String, dynamic>;
    final List<dynamic> versions =
        decoded['data'] as List<dynamic>? ?? <dynamic>[];
    if (versions.isEmpty) return null;

    Map<String, dynamic> selected = versions.first as Map<String, dynamic>;
    for (final dynamic item in versions) {
      final Map<String, dynamic> ver = item as Map<String, dynamic>;
      final Map<String, dynamic> attrs =
          ver['attributes'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final String state = attrs['appStoreState']?.toString() ?? '';
      if (state == 'PREPARE_FOR_SUBMISSION' ||
          state == 'DEVELOPER_REJECTED' ||
          state == 'REJECTED' ||
          state == 'METADATA_REJECTED') {
        selected = ver;
        break;
      }
    }

    final Map<String, dynamic> attrs =
        selected['attributes'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return <String, String>{
      'id': selected['id'].toString(),
      'state': attrs['appStoreState']?.toString() ?? '',
      'versionString': attrs['versionString']?.toString() ?? '',
    };
  }

  static Future<void> syncAgeRatingDeclaration(
    Map<String, String> headers,
    String? appInfoId,
    String versionId,
  ) async {
    stdout.writeln('\n📡 [1/5] 鎖定年齡分級 22 項必填宣告 (Age Rating)...');
    http.Response ageRes = await http.get(
      Uri.parse('$baseUrl/v1/appStoreVersions/$versionId/ageRatingDeclaration'),
      headers: headers,
    );
    if (ageRes.statusCode != 200 && appInfoId != null) {
      ageRes = await http.get(
        Uri.parse('$baseUrl/v1/appInfos/$appInfoId/ageRatingDeclaration'),
        headers: headers,
      );
    }
    if (ageRes.statusCode != 200) {
      stderr.writeln('  ⚠️ 無法讀取 Age Rating [${ageRes.statusCode}]');
      return;
    }

    final Map<String, dynamic> decoded =
        jsonDecode(ageRes.body) as Map<String, dynamic>;
    final Map<String, dynamic> data =
        decoded['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final String ageId = data['id']?.toString() ?? '';
    if (ageId.isEmpty) return;

    const Map<String, dynamic> requiredAttrs = <String, dynamic>{
      'advertising': false,
      'ageAssurance': false,
      'alcoholTobaccoOrDrugUseOrReferences': 'NONE',
      'contests': 'NONE',
      'gambling': false,
      'gamblingSimulated': 'NONE',
      'gunsOrOtherWeapons': 'NONE',
      'healthOrWellnessTopics': true,
      'horrorOrFearThemes': 'NONE',
      'lootBox': false,
      'matureOrSuggestiveThemes': 'NONE',
      'medicalOrTreatmentInformation': 'INFREQUENT_OR_MILD',
      'messagingAndChat': false,
      'parentalControls': false,
      'profanityOrCrudeHumor': 'NONE',
      'sexualContentGraphicAndNudity': 'NONE',
      'sexualContentOrNudity': 'NONE',
      'socialMedia': false,
      'unrestrictedWebAccess': false,
      'userGeneratedContent': false,
      'violenceCartoonOrFantasy': 'NONE',
      'violenceRealistic': 'NONE',
      'violenceRealisticProlongedGraphicOrSadistic': 'NONE',
    };

    final http.Response patchRes = await http.patch(
      Uri.parse('$baseUrl/v1/ageRatingDeclarations/$ageId'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'data': <String, dynamic>{
          'type': 'ageRatingDeclarations',
          'id': ageId,
          'attributes': requiredAttrs,
        },
      }),
    );
    if (patchRes.statusCode == 200) {
      stdout.writeln('  🟢 年齡分級 23 項屬性全數寫入成功！(已標註 Health/Medical 4+/12+)');
    } else {
      stderr.writeln(
        '  🔴 年齡分級 PATCH 失敗 [${patchRes.statusCode}]: ${patchRes.body}',
      );
    }
  }

  static Future<void> syncAppStoreReviewDetails(
    Map<String, String> headers,
    String versionId,
  ) async {
    stdout.writeln('\n📡 [2/5] 寫入審查聯絡人與 Guideline 1.4.1 / 5.1.1 備註...');
    const String reviewNotes = '''
Dear Apple App Review Team,
1. GUIDELINE 1.4.1 (MEDICAL DISCLAIMER): DoseFlow is an independent personal health log. All pharmacokinetic curves use a theoretical Bateman dual-exponential model calibrated against official FDA Prescribing Information (Section 12.3: Tirzepatide t1/2 ~120h, Semaglutide t1/2 ~168h, Liraglutide t1/2 ~13h). The app is NOT a medical device and never recommends dose changes.
2. GUIDELINE 5.1.1 (PRIVACY): 100% Local-First architecture. Zero external servers, zero user accounts, and zero third-party ad trackers.
3. GUIDELINE 3.1.2 (IAP & SUBSCRIPTIONS): Monthly (\$6.99), Annual with 3-day free trial (\$39.99), and Lifetime (\$119.99) can be tested in the Pro settings tab. No login is required.
''';

    final http.Response getRes = await http.get(
      Uri.parse('$baseUrl/v1/appStoreVersions/$versionId/appStoreReviewDetail'),
      headers: headers,
    );

    String detailId = '';
    Map<String, dynamic> existingAttrs = <String, dynamic>{};
    if (getRes.statusCode == 200) {
      final Map<String, dynamic> decoded =
          jsonDecode(getRes.body) as Map<String, dynamic>;
      final dynamic rawData = decoded['data'];
      if (rawData is Map<String, dynamic>) {
        detailId = rawData['id']?.toString() ?? '';
        existingAttrs =
            rawData['attributes'] as Map<String, dynamic>? ?? <String, dynamic>{};
      }
    }

    final Map<String, dynamic> envContact = <String, dynamic>{
      if ((Platform.environment['ASC_CONTACT_FIRST'] ?? '').isNotEmpty)
        'contactFirstName': Platform.environment['ASC_CONTACT_FIRST'],
      if ((Platform.environment['ASC_CONTACT_LAST'] ?? '').isNotEmpty)
        'contactLastName': Platform.environment['ASC_CONTACT_LAST'],
      if ((Platform.environment['ASC_CONTACT_EMAIL'] ?? '').isNotEmpty)
        'contactEmail': Platform.environment['ASC_CONTACT_EMAIL'],
      if ((Platform.environment['ASC_CONTACT_PHONE'] ?? '').isNotEmpty)
        'contactPhone': Platform.environment['ASC_CONTACT_PHONE'],
    };

    if (detailId.isNotEmpty) {
      final http.Response patchRes = await http.patch(
        Uri.parse('$baseUrl/v1/appStoreReviewDetails/$detailId'),
        headers: headers,
        body: jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'type': 'appStoreReviewDetails',
            'id': detailId,
            'attributes': <String, dynamic>{
              'demoAccountRequired': false,
              'notes': reviewNotes.trim(),
              ...envContact,
            },
          },
        }),
      );
      if (patchRes.statusCode == 200) {
        stdout.writeln('  🟢 App Review 備註更新成功 (ID: $detailId)');
      } else {
        stderr.writeln(
          '  🔴 Review Details PATCH 失敗 [${patchRes.statusCode}]: ${patchRes.body}',
        );
      }
      if ((existingAttrs['contactEmail']?.toString() ?? '').isEmpty &&
          !envContact.containsKey('contactEmail')) {
        stderr.writeln(
          '  ⚠️ 注意：審查聯絡人資訊尚空，若送審缺聯絡人請帶環境變數 ASC_CONTACT_FIRST=... ASC_CONTACT_LAST=... ASC_CONTACT_EMAIL=... ASC_CONTACT_PHONE=... 執行',
        );
      }
    } else {
      final http.Response postRes = await http.post(
        Uri.parse('$baseUrl/v1/appStoreReviewDetails'),
        headers: headers,
        body: jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'type': 'appStoreReviewDetails',
            'attributes': <String, dynamic>{
              'demoAccountRequired': false,
              'notes': reviewNotes.trim(),
              ...envContact,
            },
            'relationships': <String, dynamic>{
              'appStoreVersion': <String, dynamic>{
                'data': <String, dynamic>{
                  'type': 'appStoreVersions',
                  'id': versionId,
                },
              },
            },
          },
        }),
      );
      if (postRes.statusCode == 201 || postRes.statusCode == 200) {
        stdout.writeln('  🟢 App Review 備註新建成功！');
      } else {
        stderr.writeln(
          '  ⚠️ Review Details POST 需要聯絡人欄位 [${postRes.statusCode}]: ${postRes.body}',
        );
      }
    }
  }

  static Future<List<String>> fetchAllTerritoryIds(
    Map<String, String> headers,
  ) async {
    final List<String> ids = <String>[];
    String? nextUrl = '$baseUrl/v1/territories?limit=200';
    while (nextUrl != null) {
      final http.Response res = await http.get(
        Uri.parse(nextUrl),
        headers: headers,
      );
      if (res.statusCode != 200) break;
      final Map<String, dynamic> decoded =
          jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> data =
          decoded['data'] as List<dynamic>? ?? <dynamic>[];
      for (final dynamic item in data) {
        ids.add((item as Map<String, dynamic>)['id'].toString());
      }
      final Map<String, dynamic> links =
          decoded['links'] as Map<String, dynamic>? ?? <String, dynamic>{};
      nextUrl = links['next']?.toString();
    }
    return ids;
  }

  static Uint8List buildReviewPng640x920() {
    const int width = 640;
    const int height = 920;
    const int stride = 1 + width * 3;
    final Uint8List raw = Uint8List(stride * height);

    for (int y = 0; y < height; y++) {
      final int rowStart = y * stride;
      raw[rowStart] = 0;
      for (int x = 0; x < width; x++) {
        final int px = rowStart + 1 + x * 3;
        final bool inCard = x >= 48 && x <= 592 && y >= 140 && y <= 780;
        final bool inButton = x >= 88 && x <= 552 && y >= 620 && y <= 700;
        final bool inBadge = x >= 88 && x <= 320 && y >= 180 && y <= 230;
        if (inButton) {
          raw[px] = 14;
          raw[px + 1] = 165;
          raw[px + 2] = 233;
        } else if (inBadge) {
          raw[px] = 16;
          raw[px + 1] = 185;
          raw[px + 2] = 129;
        } else if (inCard) {
          raw[px] = 255;
          raw[px + 1] = 255;
          raw[px + 2] = 255;
        } else {
          raw[px] = 15;
          raw[px + 1] = 23;
          raw[px + 2] = 42;
        }
      }
    }

    final List<int> ihdrData = <int>[
      (width >> 24) & 0xff,
      (width >> 16) & 0xff,
      (width >> 8) & 0xff,
      width & 0xff,
      (height >> 24) & 0xff,
      (height >> 16) & 0xff,
      (height >> 8) & 0xff,
      height & 0xff,
      8,
      2,
      0,
      0,
      0,
    ];
    final List<int> compressed = zlib.encode(raw);

    final BytesBuilder png = BytesBuilder();
    png.add(<int>[137, 80, 78, 71, 13, 10, 26, 10]);
    png.add(_pngChunk('IHDR', ihdrData));
    png.add(_pngChunk('IDAT', compressed));
    png.add(_pngChunk('IEND', <int>[]));
    return png.toBytes();
  }

  static List<int> _pngChunk(String type, List<int> data) {
    final BytesBuilder out = BytesBuilder();
    final int len = data.length;
    out.add(<int>[
      (len >> 24) & 0xff,
      (len >> 16) & 0xff,
      (len >> 8) & 0xff,
      len & 0xff,
    ]);
    final List<int> typeAndData = <int>[...utf8.encode(type), ...data];
    out.add(typeAndData);
    final int crc = _crc32(typeAndData);
    out.add(<int>[
      (crc >> 24) & 0xff,
      (crc >> 16) & 0xff,
      (crc >> 8) & 0xff,
      crc & 0xff,
    ]);
    return out.toBytes();
  }

  static int _crc32(List<int> bytes) {
    int crc = 0xffffffff;
    for (final int b in bytes) {
      crc ^= b;
      for (int i = 0; i < 8; i++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0xedb88320;
        } else {
          crc >>= 1;
        }
      }
    }
    return crc ^ 0xffffffff;
  }

  static Future<String> ensureReviewPngFile() async {
    const String path = 'tool/.iap_review_640x920.png';
    final File file = File(path);
    if (!file.existsSync()) {
      file.writeAsBytesSync(buildReviewPng640x920());
    }
    return path;
  }

  static String computeMacMd5(String filePath) {
    final ProcessResult res =
        Process.runSync('md5', <String>['-q', filePath]);
    return res.stdout.toString().trim();
  }

  static Future<void> uploadAssetOperations({
    required List<dynamic> uploadOperations,
    required Uint8List fileBytes,
  }) async {
    for (final dynamic opRaw in uploadOperations) {
      final Map<String, dynamic> op = opRaw as Map<String, dynamic>;
      final String url = op['url'].toString();
      final String method = op['method'].toString();
      final int offset = (op['offset'] as num).toInt();
      final int length = (op['length'] as num).toInt();
      final List<dynamic> reqHeadersRaw =
          op['requestHeaders'] as List<dynamic>? ?? <dynamic>[];
      final Map<String, String> upHeaders = <String, String>{};
      for (final dynamic h in reqHeadersRaw) {
        final Map<String, dynamic> hm = h as Map<String, dynamic>;
        upHeaders[hm['name'].toString()] = hm['value'].toString();
      }
      final Uint8List chunk = fileBytes.sublist(offset, offset + length);
      if (method.toUpperCase() == 'PUT') {
        await http.put(Uri.parse(url), headers: upHeaders, body: chunk);
      }
    }
  }

  static Future<String?> findPricePointId({
    required Map<String, String> headers,
    required String firstPageUrl,
    required double targetUsd,
  }) async {
    String? nextUrl = firstPageUrl;
    String? bestId;
    double bestDiff = double.infinity;

    while (nextUrl != null) {
      final http.Response res = await http.get(
        Uri.parse(nextUrl),
        headers: headers,
      );
      if (res.statusCode != 200) break;
      final Map<String, dynamic> decoded =
          jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> list =
          decoded['data'] as List<dynamic>? ?? <dynamic>[];
      for (final dynamic item in list) {
        final Map<String, dynamic> map = item as Map<String, dynamic>;
        final Map<String, dynamic> attrs =
            map['attributes'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final double? price =
            double.tryParse(attrs['customerPrice']?.toString() ?? '');
        if (price == null) continue;
        final double diff = (price - targetUsd).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          bestId = map['id'].toString();
        }
        if (diff < 0.01) {
          return bestId;
        }
      }
      final Map<String, dynamic> links =
          decoded['links'] as Map<String, dynamic>? ?? <String, dynamic>{};
      nextUrl = links['next']?.toString();
    }
    return bestId;
  }

  static Future<void> configureSubscriptions(
    Map<String, String> headers,
    List<String> territories,
    String pngPath,
  ) async {
    stdout.writeln('\n📡 [3/5] 自動配置訂閱群組、\$39.99 年繳(3天試用)/\$6.99 月繳、區域與審核圖...');
    final http.Response grpRes = await http.get(
      Uri.parse('$baseUrl/v1/apps/$appId/subscriptionGroups'),
      headers: headers,
    );
    if (grpRes.statusCode != 200) {
      stderr.writeln('  🔴 無法讀取訂閱群組 [${grpRes.statusCode}]');
      return;
    }

    final Map<String, dynamic> grpDecoded =
        jsonDecode(grpRes.body) as Map<String, dynamic>;
    final List<dynamic> groups =
        grpDecoded['data'] as List<dynamic>? ?? <dynamic>[];
    final Uint8List pngBytes = File(pngPath).readAsBytesSync();
    final String md5Hex = computeMacMd5(pngPath);

    for (final dynamic g in groups) {
      final Map<String, dynamic> gMap = g as Map<String, dynamic>;
      final String groupId = gMap['id'].toString();

      // 1. 確保 Subscription Group Localization (zh-Hant & en-US)
      final http.Response gLocRes = await http.get(
        Uri.parse('$baseUrl/v1/subscriptionGroups/$groupId/subscriptionGroupLocalizations'),
        headers: headers,
      );
      final Set<String> existingGLocs = <String>{};
      if (gLocRes.statusCode == 200) {
        final Map<String, dynamic> gLocDec =
            jsonDecode(gLocRes.body) as Map<String, dynamic>;
        for (final dynamic l in (gLocDec['data'] as List<dynamic>? ?? <dynamic>[])) {
          final Map<String, dynamic> lm = l as Map<String, dynamic>;
          final Map<String, dynamic> attrs =
              lm['attributes'] as Map<String, dynamic>? ?? <String, dynamic>{};
          existingGLocs.add(attrs['locale']?.toString() ?? '');
        }
      }
      for (final Map<String, String> cfg in <Map<String, String>>[
        <String, String>{
          'locale': 'zh-Hant',
          'name': 'DoseFlow Pro 專業訂閱',
          'customAppName': '瘦瘦針紀錄 Pro',
        },
        <String, String>{
          'locale': 'en-US',
          'name': 'DoseFlow Pro',
          'customAppName': 'DoseFlow',
        },
      ]) {
        if (!existingGLocs.contains(cfg['locale'])) {
          final http.Response postGLoc = await http.post(
            Uri.parse('$baseUrl/v1/subscriptionGroupLocalizations'),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'type': 'subscriptionGroupLocalizations',
                'attributes': <String, dynamic>{
                  'locale': cfg['locale'],
                  'name': cfg['name'],
                  'customAppName': cfg['customAppName'],
                },
                'relationships': <String, dynamic>{
                  'subscriptionGroup': <String, dynamic>{
                    'data': <String, dynamic>{
                      'type': 'subscriptionGroups',
                      'id': groupId,
                    },
                  },
                },
              },
            }),
          );
          stdout.writeln(
            '  ‣ 訂閱群組語系 ${cfg['locale']} 建立 [${postGLoc.statusCode}]',
          );
        }
      }

      // 2. 遍歷群組內訂閱
      final http.Response subRes = await http.get(
        Uri.parse('$baseUrl/v1/subscriptionGroups/$groupId/subscriptions'),
        headers: headers,
      );
      if (subRes.statusCode != 200) continue;
      final Map<String, dynamic> subDec =
          jsonDecode(subRes.body) as Map<String, dynamic>;
      final List<dynamic> subs =
          subDec['data'] as List<dynamic>? ?? <dynamic>[];

      for (final dynamic s in subs) {
        final Map<String, dynamic> sMap = s as Map<String, dynamic>;
        final String subId = sMap['id'].toString();
        final Map<String, dynamic> attrs =
            sMap['attributes'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final String productId = attrs['productId']?.toString() ?? '';
        final String currentState = attrs['state']?.toString() ?? '';
        final bool isAnnual = productId.contains('annual');
        final double targetUsd = isAnnual ? 39.99 : 6.99;

        stdout.writeln(
          '\n  🔧 處理訂閱: $productId (ID: $subId | 目標: \$$targetUsd | 現狀: $currentState)',
        );

        // 2a. Review Note
        await http.patch(
          Uri.parse('$baseUrl/v1/subscriptions/$subId'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'subscriptions',
              'id': subId,
              'attributes': const <String, dynamic>{
                'reviewNote':
                    'Unlocks live GLP-1 Bateman PK curve, unlimited U-100 syringe calculator, and doctor PDF summary.',
              },
            },
          }),
        );

        // 2b. 確保區域上架 (MUST come before pricing!)
        final http.Response availGet = await http.get(
          Uri.parse('$baseUrl/v1/subscriptions/$subId/subscriptionAvailability'),
          headers: headers,
        );
        if (availGet.statusCode != 200 && territories.isNotEmpty) {
          final http.Response availPost = await http.post(
            Uri.parse('$baseUrl/v1/subscriptionAvailabilities'),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'type': 'subscriptionAvailabilities',
                'attributes': const <String, dynamic>{
                  'availableInNewTerritories': true,
                },
                'relationships': <String, dynamic>{
                  'subscription': <String, dynamic>{
                    'data': <String, dynamic>{
                      'type': 'subscriptions',
                      'id': subId,
                    },
                  },
                  'availableTerritories': <String, dynamic>{
                    'data': territories
                        .map((String t) => <String, dynamic>{
                              'type': 'territories',
                              'id': t,
                            })
                        .toList(),
                  },
                },
              },
            }),
          );
          stdout.writeln('    ‣ 全區上架設定回應 [${availPost.statusCode}]');
        } else {
          stdout.writeln('    🟢 全區上架狀態已就緒');
        }

        // 2c. 設定全區價格 (USA 基準自動平衡到全球 175 國)
        final http.Response pricesGet = await http.get(
          Uri.parse('$baseUrl/v1/subscriptions/$subId/prices?filter[territory]=USA'),
          headers: headers,
        );
        final Map<String, dynamic> pricesDec = pricesGet.statusCode == 200
            ? jsonDecode(pricesGet.body) as Map<String, dynamic>
            : <String, dynamic>{};
        final List<dynamic> existingPrices =
            pricesDec['data'] as List<dynamic>? ?? <dynamic>[];

        if (existingPrices.isEmpty) {
          final String? usaPpId = await findPricePointId(
            headers: headers,
            firstPageUrl:
                '$baseUrl/v1/subscriptions/$subId/pricePoints?filter[territory]=USA&limit=200',
            targetUsd: targetUsd,
          );
          if (usaPpId != null) {
            final List<String> eqIds = <String>[usaPpId];
            String? nextEq =
                '$baseUrl/v1/subscriptionPricePoints/$usaPpId/equalizations?limit=200';
            while (nextEq != null) {
              final http.Response eqRes = await http.get(
                Uri.parse(nextEq),
                headers: headers,
              );
              if (eqRes.statusCode != 200) break;
              final Map<String, dynamic> eqDec =
                  jsonDecode(eqRes.body) as Map<String, dynamic>;
              for (final dynamic e
                  in (eqDec['data'] as List<dynamic>? ?? <dynamic>[])) {
                eqIds.add((e as Map<String, dynamic>)['id'].toString());
              }
              final Map<String, dynamic> links =
                  eqDec['links'] as Map<String, dynamic>? ??
                      <String, dynamic>{};
              nextEq = links['next']?.toString();
            }

            final List<String> uniqueEqIds = eqIds.toSet().toList();
            final List<Map<String, dynamic>> relPrices =
                <Map<String, dynamic>>[];
            final List<Map<String, dynamic>> incPrices =
                <Map<String, dynamic>>[];
            for (int i = 0; i < uniqueEqIds.length; i++) {
              final String tempId = '\${price_$i}';
              relPrices.add(<String, dynamic>{
                'type': 'subscriptionPrices',
                'id': tempId,
              });
              incPrices.add(<String, dynamic>{
                'type': 'subscriptionPrices',
                'id': tempId,
                'attributes': const <String, dynamic>{'startDate': null},
                'relationships': <String, dynamic>{
                  'subscriptionPricePoint': <String, dynamic>{
                    'data': <String, dynamic>{
                      'type': 'subscriptionPricePoints',
                      'id': uniqueEqIds[i],
                    },
                  },
                },
              });
            }

            final http.Response patchPrices = await http.patch(
              Uri.parse('$baseUrl/v1/subscriptions/$subId'),
              headers: headers,
              body: jsonEncode(<String, dynamic>{
                'data': <String, dynamic>{
                  'type': 'subscriptions',
                  'id': subId,
                  'relationships': <String, dynamic>{
                    'prices': <String, dynamic>{'data': relPrices},
                  },
                },
                'included': incPrices,
              }),
            );
            if (patchPrices.statusCode == 200) {
              stdout.writeln(
                '    🟢 全球 ${uniqueEqIds.length} 個國家/地區價格寫入成功 (\$$targetUsd 基準)！',
              );
            } else {
              stderr.writeln(
                '    ⚠️ 價格批量寫入回應 [${patchPrices.statusCode}]: ${patchPrices.body}',
              );
            }
          }
        } else {
          stdout.writeln('    🟢 訂閱價格已設定完成');
        }

        // 2d. 年繳 3 天免費試用 (Introductory Offer)
        if (isAnnual) {
          final http.Response introGet = await http.get(
            Uri.parse('$baseUrl/v1/subscriptions/$subId/introductoryOffers'),
            headers: headers,
          );
          final Map<String, dynamic> introDec = introGet.statusCode == 200
              ? jsonDecode(introGet.body) as Map<String, dynamic>
              : <String, dynamic>{};
          final List<dynamic> existingIntros =
              introDec['data'] as List<dynamic>? ?? <dynamic>[];
          if (existingIntros.isEmpty) {
            int okCount = 0;
            const int batchSize = 15;
            for (int i = 0; i < territories.length; i += batchSize) {
              final List<String> batch = territories.sublist(
                i,
                (i + batchSize) > territories.length
                    ? territories.length
                    : (i + batchSize),
              );
              final List<Future<http.Response>> futures = batch
                  .map((String terr) => http.post(
                        Uri.parse('$baseUrl/v1/subscriptionIntroductoryOffers'),
                        headers: headers,
                        body: jsonEncode(<String, dynamic>{
                          'data': <String, dynamic>{
                            'type': 'subscriptionIntroductoryOffers',
                            'attributes': const <String, dynamic>{
                              'duration': 'THREE_DAYS',
                              'numberOfPeriods': 1,
                              'offerMode': 'FREE_TRIAL',
                              'startDate': null,
                              'endDate': null,
                            },
                            'relationships': <String, dynamic>{
                              'subscription': <String, dynamic>{
                                'data': <String, dynamic>{
                                  'type': 'subscriptions',
                                  'id': subId,
                                },
                              },
                              'territory': <String, dynamic>{
                                'data': <String, dynamic>{
                                  'type': 'territories',
                                  'id': terr,
                                },
                              },
                            },
                          },
                        }),
                      ))
                  .toList();
              final List<http.Response> results = await Future.wait(futures);
              for (final http.Response r in results) {
                if (r.statusCode == 201 || r.statusCode == 200) {
                  okCount++;
                }
              }
            }
            stdout.writeln('    🟢 年繳 3 天免費試用已寫入 $okCount 個國家/地區！');
          } else {
            stdout.writeln('    🟢 年繳 3 天免費試用已設定');
          }
        }

        // 2e. 訂閱審核截圖 (Review Screenshot)
        final http.Response ssGet = await http.get(
          Uri.parse('$baseUrl/v1/subscriptions/$subId/appStoreReviewScreenshot'),
          headers: headers,
        );
        final dynamic ssData = ssGet.statusCode == 200
            ? (jsonDecode(ssGet.body) as Map<String, dynamic>)['data']
            : null;
        if (ssData == null) {
          final http.Response ssReserve = await http.post(
            Uri.parse('$baseUrl/v1/subscriptionAppStoreReviewScreenshots'),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'type': 'subscriptionAppStoreReviewScreenshots',
                'attributes': <String, dynamic>{
                  'fileName': 'doseflow_paywall_640x920.png',
                  'fileSize': pngBytes.length,
                },
                'relationships': <String, dynamic>{
                  'subscription': <String, dynamic>{
                    'data': <String, dynamic>{
                      'type': 'subscriptions',
                      'id': subId,
                    },
                  },
                },
              },
            }),
          );
          if (ssReserve.statusCode == 201 || ssReserve.statusCode == 200) {
            final Map<String, dynamic> resDec =
                jsonDecode(ssReserve.body) as Map<String, dynamic>;
            final Map<String, dynamic> resData =
                resDec['data'] as Map<String, dynamic>;
            final String ssId = resData['id'].toString();
            final Map<String, dynamic> ssAttrs =
                resData['attributes'] as Map<String, dynamic>;
            final List<dynamic> ops =
                ssAttrs['uploadOperations'] as List<dynamic>? ?? <dynamic>[];
            await uploadAssetOperations(
              uploadOperations: ops,
              fileBytes: pngBytes,
            );
            final http.Response commitRes = await http.patch(
              Uri.parse('$baseUrl/v1/subscriptionAppStoreReviewScreenshots/$ssId'),
              headers: headers,
              body: jsonEncode(<String, dynamic>{
                'data': <String, dynamic>{
                  'type': 'subscriptionAppStoreReviewScreenshots',
                  'id': ssId,
                  'attributes': <String, dynamic>{
                    'sourceFileChecksum': md5Hex,
                    'uploaded': true,
                  },
                },
              }),
            );
            stdout.writeln(
              '    🟢 訂閱審核截圖上傳完成 [${commitRes.statusCode}]',
            );
          } else {
            stderr.writeln(
              '    ⚠️ 訂閱審核截圖預約回應 [${ssReserve.statusCode}]: ${ssReserve.body}',
            );
          }
        } else {
          stdout.writeln('    🟢 訂閱審核截圖已存在');
        }

        // 2f. 檢查最終訂閱狀態
        final http.Response subFinal = await http.get(
          Uri.parse('$baseUrl/v1/subscriptions/$subId'),
          headers: headers,
        );
        if (subFinal.statusCode == 200) {
          final Map<String, dynamic> fd =
              jsonDecode(subFinal.body) as Map<String, dynamic>;
          final String finalState =
              ((fd['data'] as Map<String, dynamic>)['attributes']
                      as Map<String, dynamic>)['state']
                  .toString();
          stdout.writeln('    📌 $productId 最新狀態 -> $finalState');
        }
      }
    }
  }

  static Future<List<String>> configureLifetimeIap(
    Map<String, String> headers,
    List<String> territories,
    String pngPath,
  ) async {
    stdout.writeln('\n📡 [4/5] 自動配置終身版 IAP ($lifetimeId: \$119.99)、全區上架與審核圖...');
    final List<String> readyIapIds = <String>[];

    final http.Response listRes = await http.get(
      Uri.parse('$baseUrl/v1/apps/$appId/inAppPurchasesV2'),
      headers: headers,
    );
    if (listRes.statusCode != 200) {
      stderr.writeln(
        '  ⚠️ 讀取 inAppPurchasesV2 失敗 [${listRes.statusCode}]: ${listRes.body}',
      );
      return readyIapIds;
    }

    final Map<String, dynamic> listDec =
        jsonDecode(listRes.body) as Map<String, dynamic>;
    final List<dynamic> iaps =
        listDec['data'] as List<dynamic>? ?? <dynamic>[];
    final Uint8List pngBytes = File(pngPath).readAsBytesSync();
    final String md5Hex = computeMacMd5(pngPath);

    for (final dynamic item in iaps) {
      final Map<String, dynamic> iap = item as Map<String, dynamic>;
      final String iapId = iap['id'].toString();
      final Map<String, dynamic> attrs =
          iap['attributes'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final String productId = attrs['productId']?.toString() ?? '';
      final String state = attrs['state']?.toString() ?? '';
      stdout.writeln('  🔧 處理 IAP: $productId (ID: $iapId | 現狀: $state)');

      // 1. Review Note
      await http.patch(
        Uri.parse('$baseUrl/v2/inAppPurchases/$iapId'),
        headers: headers,
        body: jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'type': 'inAppPurchases',
            'id': iapId,
            'attributes': const <String, dynamic>{
              'reviewNote':
                  'Lifetime unlock for all DoseFlow Pro pharmacokinetics curves and U-100 syringe tools.',
            },
          },
        }),
      );

      // 2. Availability
      final http.Response availGet = await http.get(
        Uri.parse('$baseUrl/v2/inAppPurchases/$iapId/inAppPurchaseAvailability'),
        headers: headers,
      );
      if (availGet.statusCode != 200 && territories.isNotEmpty) {
        final http.Response availPost = await http.post(
          Uri.parse('$baseUrl/v1/inAppPurchaseAvailabilities'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'inAppPurchaseAvailabilities',
              'attributes': const <String, dynamic>{
                'availableInNewTerritories': true,
              },
              'relationships': <String, dynamic>{
                'inAppPurchase': <String, dynamic>{
                  'data': <String, dynamic>{
                    'type': 'inAppPurchases',
                    'id': iapId,
                  },
                },
                'availableTerritories': <String, dynamic>{
                  'data': territories
                      .map((String t) => <String, dynamic>{
                            'type': 'territories',
                            'id': t,
                          })
                      .toList(),
                },
              },
            },
          }),
        );
        stdout.writeln('    ‣ IAP 全區上架設定回應 [${availPost.statusCode}]');
      } else {
        stdout.writeln('    🟢 IAP 全區上架狀態已就緒');
      }

      // 3. Price Schedule ($119.99)
      final http.Response psGet = await http.get(
        Uri.parse('$baseUrl/v2/inAppPurchases/$iapId/iapPriceSchedule'),
        headers: headers,
      );
      if (psGet.statusCode != 200) {
        final String? usaPpId = await findPricePointId(
          headers: headers,
          firstPageUrl:
              '$baseUrl/v2/inAppPurchases/$iapId/pricePoints?filter[territory]=USA&limit=200',
          targetUsd: 119.99,
        );
        if (usaPpId != null) {
          const String tempPriceId = r'${iap_price_1}';
          final http.Response psPost = await http.post(
            Uri.parse('$baseUrl/v1/inAppPurchasePriceSchedules'),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'type': 'inAppPurchasePriceSchedules',
                'relationships': <String, dynamic>{
                  'baseTerritory': <String, dynamic>{
                    'data': <String, dynamic>{
                      'type': 'territories',
                      'id': 'USA',
                    },
                  },
                  'inAppPurchase': <String, dynamic>{
                    'data': <String, dynamic>{
                      'type': 'inAppPurchases',
                      'id': iapId,
                    },
                  },
                  'manualPrices': <String, dynamic>{
                    'data': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'type': 'inAppPurchasePrices',
                        'id': tempPriceId,
                      },
                    ],
                  },
                },
              },
              'included': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'inAppPurchasePrices',
                  'id': tempPriceId,
                  'attributes': const <String, dynamic>{
                    'startDate': null,
                    'endDate': null,
                  },
                  'relationships': <String, dynamic>{
                    'inAppPurchasePricePoint': <String, dynamic>{
                      'data': <String, dynamic>{
                        'type': 'inAppPurchasePricePoints',
                        'id': usaPpId,
                      },
                    },
                    'inAppPurchaseV2': <String, dynamic>{
                      'data': <String, dynamic>{
                        'type': 'inAppPurchases',
                        'id': iapId,
                      },
                    },
                  },
                },
              ],
            }),
          );
          if (psPost.statusCode == 201 || psPost.statusCode == 200) {
            stdout.writeln('    🟢 終身版價格排程設定完成 (\$119.99 全球自動對齊)！');
          } else {
            stderr.writeln(
              '    ⚠️ 終身版價格排程回應 [${psPost.statusCode}]: ${psPost.body}',
            );
          }
        }
      } else {
        stdout.writeln('    🟢 終身版價格排程已存在');
      }

      // 4. Review Screenshot
      final http.Response ssGet = await http.get(
        Uri.parse('$baseUrl/v2/inAppPurchases/$iapId/appStoreReviewScreenshot'),
        headers: headers,
      );
      final dynamic ssData = ssGet.statusCode == 200
          ? (jsonDecode(ssGet.body) as Map<String, dynamic>)['data']
          : null;
      if (ssData == null) {
        final http.Response ssReserve = await http.post(
          Uri.parse('$baseUrl/v1/inAppPurchaseAppStoreReviewScreenshots'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'inAppPurchaseAppStoreReviewScreenshots',
              'attributes': <String, dynamic>{
                'fileName': 'doseflow_lifetime_640x920.png',
                'fileSize': pngBytes.length,
              },
              'relationships': <String, dynamic>{
                'inAppPurchaseV2': <String, dynamic>{
                  'data': <String, dynamic>{
                    'type': 'inAppPurchases',
                    'id': iapId,
                  },
                },
              },
            },
          }),
        );
        if (ssReserve.statusCode == 201 || ssReserve.statusCode == 200) {
          final Map<String, dynamic> resDec =
              jsonDecode(ssReserve.body) as Map<String, dynamic>;
          final Map<String, dynamic> resData =
              resDec['data'] as Map<String, dynamic>;
          final String ssId = resData['id'].toString();
          final Map<String, dynamic> ssAttrs =
              resData['attributes'] as Map<String, dynamic>;
          final List<dynamic> ops =
              ssAttrs['uploadOperations'] as List<dynamic>? ?? <dynamic>[];
          await uploadAssetOperations(
            uploadOperations: ops,
            fileBytes: pngBytes,
          );
          final http.Response commitRes = await http.patch(
            Uri.parse(
              '$baseUrl/v1/inAppPurchaseAppStoreReviewScreenshots/$ssId',
            ),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'type': 'inAppPurchaseAppStoreReviewScreenshots',
                'id': ssId,
                'attributes': <String, dynamic>{
                  'sourceFileChecksum': md5Hex,
                  'uploaded': true,
                },
              },
            }),
          );
          stdout.writeln('    🟢 IAP 審核截圖上傳完成 [${commitRes.statusCode}]');
        } else {
          stderr.writeln(
            '    ⚠️ IAP 審核截圖預約回應 [${ssReserve.statusCode}]: ${ssReserve.body}',
          );
        }
      } else {
        stdout.writeln('    🟢 IAP 審核截圖已存在');
      }

      // 5. Re-check final state
      final http.Response recheck = await http.get(
        Uri.parse('$baseUrl/v2/inAppPurchases/$iapId'),
        headers: headers,
      );
      if (recheck.statusCode == 200) {
        final Map<String, dynamic> rcDec =
            jsonDecode(recheck.body) as Map<String, dynamic>;
        final String finalState =
            ((rcDec['data'] as Map<String, dynamic>)['attributes']
                    as Map<String, dynamic>)['state']
                .toString();
        stdout.writeln('    📌 $productId 最新狀態 -> $finalState');
        if (finalState == 'READY_TO_SUBMIT') {
          readyIapIds.add(iapId);
        }
      }
    }
    return readyIapIds;
  }

  static Future<void> bindBuildAndAttemptSubmit(
    Map<String, String> headers,
    String versionId,
    String versionState,
    List<String> readyIapIds,
  ) async {
    stdout.writeln('\n📡 [5/5] 確認 Build 1 免除加密與審查送審檢查...');
    final http.Response buildsRes = await http.get(
      Uri.parse(
        '$baseUrl/v1/builds?filter[app]=$appId&sort=-uploadedDate&limit=3',
      ),
      headers: headers,
    );
    String? validBuildId;
    if (buildsRes.statusCode == 200) {
      final Map<String, dynamic> dec =
          jsonDecode(buildsRes.body) as Map<String, dynamic>;
      final List<dynamic> list = dec['data'] as List<dynamic>? ?? <dynamic>[];
      for (final dynamic b in list) {
        final Map<String, dynamic> bm = b as Map<String, dynamic>;
        final Map<String, dynamic> attrs =
            bm['attributes'] as Map<String, dynamic>? ?? <String, dynamic>{};
        if (attrs['processingState'] == 'VALID') {
          validBuildId = bm['id'].toString();
          break;
        }
      }
    }

    if (validBuildId != null) {
      await http.patch(
        Uri.parse('$baseUrl/v1/builds/$validBuildId'),
        headers: headers,
        body: jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'type': 'builds',
            'id': validBuildId,
            'attributes': const <String, dynamic>{
              'usesNonExemptEncryption': false,
            },
          },
        }),
      );
      stdout.writeln(
        '  🟢 Build $validBuildId 已鎖定 usesNonExemptEncryption: false',
      );
    }

    if (versionState == 'WAITING_FOR_REVIEW' || versionState == 'IN_REVIEW') {
      stdout.writeln('  🟢 版本已在審核佇列 ($versionState)');
      return;
    }

    String? submissionId;
    final http.Response subCreate = await http.post(
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
    if (subCreate.statusCode == 201 || subCreate.statusCode == 200) {
      submissionId = ((jsonDecode(subCreate.body)
              as Map<String, dynamic>)['data'] as Map<String, dynamic>)['id']
          .toString();
    } else if (subCreate.statusCode == 409) {
      final http.Response exist = await http.get(
        Uri.parse(
          '$baseUrl/v1/reviewSubmissions?filter[app]=$appId&filter[state]=READY_FOR_REVIEW',
        ),
        headers: headers,
      );
      if (exist.statusCode == 200) {
        final List<dynamic> list = ((jsonDecode(exist.body)
                as Map<String, dynamic>)['data'] as List<dynamic>?) ??
            <dynamic>[];
        if (list.isNotEmpty) {
          submissionId = (list.first as Map<String, dynamic>)['id'].toString();
        }
      }
    }

    if (submissionId == null) {
      stderr.writeln('  ⚠️ 送審單建立失敗 [${subCreate.statusCode}]: ${subCreate.body}');
      return;
    }

    final http.Response addVer = await http.post(
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
            'appStoreVersion': <String, dynamic>{
              'data': <String, dynamic>{
                'type': 'appStoreVersions',
                'id': versionId,
              },
            },
          },
        },
      }),
    );
    if (addVer.statusCode == 201 || addVer.statusCode == 200) {
      stdout.writeln('  🟢 已將 Version 1.0 加入送審單');
    } else {
      stderr.writeln(
        '  ⚠️ 加入 Version 1.0 遭到 Apple 條件檢查攔截 [${addVer.statusCode}]:\n${addVer.body}',
      );
    }

    for (final String iapId in readyIapIds) {
      final http.Response addIap = await http.post(
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
              'inAppPurchaseV2': <String, dynamic>{
                'data': <String, dynamic>{
                  'type': 'inAppPurchases',
                  'id': iapId,
                },
              },
            },
          },
        }),
      );
      stdout.writeln('  ‣ 掛載 IAP ($iapId) 至送審單 [${addIap.statusCode}]');
    }

    final http.Response submitRes = await http.patch(
      Uri.parse('$baseUrl/v1/reviewSubmissions/$submissionId'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'data': <String, dynamic>{
          'type': 'reviewSubmissions',
          'id': submissionId,
          'attributes': const <String, dynamic>{'submitted': true},
        },
      }),
    );
    if (submitRes.statusCode == 200) {
      stdout.writeln(
        '\n🟢🟢🟢 [大功告成] DoseFlow 與內購已正式送交 Apple Waiting for Review！',
      );
    } else {
      stderr.writeln(
        '\n⚠️ 送審最後關卡回報 [${submitRes.statusCode}]:\n${submitRes.body}',
      );
    }
  }
}

Future<void> main() async {
  stdout.writeln('🚀 啟動 DoseFlow 年齡分級、審查備註與 3 大 IAP 全自動精算配置...');
  final String privateKeyPem = AscUploadEngine.loadPrivateKeyPem();
  final Map<String, String>? headers =
      await AscUploadEngine.negotiateAuthHeaders(privateKeyPem);
  if (headers == null) exit(1);

  final String? appInfoId = await AscUploadEngine.fetchAppInfoId(headers);
  final Map<String, String>? versionInfo =
      await AscUploadEngine.findEditableVersion(headers);
  if (versionInfo == null) exit(1);

  final String versionId = versionInfo['id']!;
  final String versionState = versionInfo['state']!;

  await AscUploadEngine.syncAgeRatingDeclaration(headers, appInfoId, versionId);
  await AscUploadEngine.syncAppStoreReviewDetails(headers, versionId);

  final List<String> territories =
      await AscUploadEngine.fetchAllTerritoryIds(headers);
  stdout.writeln('\n🟢 已載入 Apple 全球 ${territories.length} 個國家/地區代碼');

  final String pngPath = await AscUploadEngine.ensureReviewPngFile();
  await AscUploadEngine.configureSubscriptions(headers, territories, pngPath);
  final List<String> readyIapIds =
      await AscUploadEngine.configureLifetimeIap(headers, territories, pngPath);

  await AscUploadEngine.bindBuildAndAttemptSubmit(
    headers,
    versionId,
    versionState,
    readyIapIds,
  );

  stdout.writeln('\n🎉 [IAP 與送審管線執行完畢]');
}
