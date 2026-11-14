import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
  const String lifetimeId = '6832587006';
  const String baseUrl = 'https://api.appstoreconnect.apple.com';

  final Map<String, String> headers = await buildHeaders();

  // 0. Wait for Build 3 VALID & bind to Version 1.0
  stdout.writeln('📡 [0/5] 輪詢等待 Build 3 (StoreKit 2 + Xcode 27.2) 轉為 VALID...');
  String? build3Id;
  for (int i = 1; i <= 20; i++) {
    final http.Response bRes = await http.get(
      Uri.parse(
        '$baseUrl/v1/builds?filter[app]=$appId&sort=-uploadedDate&limit=5',
      ),
      headers: headers,
    );
    if (bRes.statusCode == 200) {
      final List<dynamic> list =
          ((jsonDecode(bRes.body) as Map<String, dynamic>)['data']
                  as List<dynamic>?) ??
              <dynamic>[];
      for (final dynamic b in list) {
        final Map<String, dynamic> bm = b as Map<String, dynamic>;
        final Map<String, dynamic> attrs =
            bm['attributes'] as Map<String, dynamic>;
        if (attrs['version']?.toString() == '3') {
          final String st = attrs['processingState'].toString();
          stdout.writeln('  ‣ Build 3 狀態 ($i/20): $st');
          if (st == 'VALID') {
            build3Id = bm['id'].toString();
          }
          break;
        }
      }
    }
    if (build3Id != null) break;
    await Future<void>.delayed(const Duration(seconds: 15));
  }
  if (build3Id == null) {
    stderr.writeln('🔴 Build 3 尚未處理完成，請稍候幾分鐘再單獨重跑 dart run tool/asc_clear_4_blockers_and_submit.dart');
    exit(1);
  }
  await http.patch(
    Uri.parse('$baseUrl/v1/builds/$build3Id'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{
        'type': 'builds',
        'id': build3Id,
        'attributes': const <String, dynamic>{
          'usesNonExemptEncryption': false,
        },
      },
    }),
  );
  await http.patch(
    Uri.parse('$baseUrl/v1/appStoreVersions/$versionId/relationships/build'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{'type': 'builds', 'id': build3Id},
    }),
  );
  stdout.writeln('  🟢 Build 3 ($build3Id) 已免加密並改綁至 Version 1.0！');

  // 1. contentRightsDeclaration
  stdout.writeln('\n📡 [1/5] 宣告 contentRightsDeclaration...');
  final http.Response crRes = await http.patch(
    Uri.parse('$baseUrl/v1/apps/$appId'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{
        'type': 'apps',
        'id': appId,
        'attributes': const <String, dynamic>{
          'contentRightsDeclaration': 'DOES_NOT_USE_THIRD_PARTY_CONTENT',
        },
      },
    }),
  );
  stdout.writeln('  🟢 contentRightsDeclaration 回應 [${crRes.statusCode}]');

  // 2. Free App Price Schedule ($0.00)
  stdout.writeln('\n📡 [2/5] 寫入 App 免費 \$0.00 價格排程...');
  final http.Response ppRes = await http.get(
    Uri.parse(
      '$baseUrl/v1/apps/$appId/appPricePoints?filter[territory]=USA&limit=20',
    ),
    headers: headers,
  );
  String? freePpId;
  if (ppRes.statusCode == 200) {
    final List<dynamic> list =
        ((jsonDecode(ppRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>?) ??
            <dynamic>[];
    for (final dynamic item in list) {
      final Map<String, dynamic> m = item as Map<String, dynamic>;
      final double? p = double.tryParse(
        (m['attributes'] as Map<String, dynamic>)['customerPrice']
                ?.toString() ??
            '',
      );
      if (p != null && p == 0.0) {
        freePpId = m['id'].toString();
        break;
      }
    }
  }
  if (freePpId != null) {
    const String tempId = r'${free_p1}';
    final http.Response psPost = await http.post(
      Uri.parse('$baseUrl/v1/appPriceSchedules'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'data': <String, dynamic>{
          'type': 'appPriceSchedules',
          'relationships': <String, dynamic>{
            'app': <String, dynamic>{
              'data': <String, dynamic>{'type': 'apps', 'id': appId},
            },
            'baseTerritory': <String, dynamic>{
              'data': <String, dynamic>{'type': 'territories', 'id': 'USA'},
            },
            'manualPrices': <String, dynamic>{
              'data': <Map<String, dynamic>>[
                <String, dynamic>{'type': 'appPrices', 'id': tempId},
              ],
            },
          },
        },
        'included': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'appPrices',
            'id': tempId,
            'attributes': const <String, dynamic>{'startDate': null},
            'relationships': <String, dynamic>{
              'appPricePoint': <String, dynamic>{
                'data': <String, dynamic>{
                  'type': 'appPricePoints',
                  'id': freePpId,
                },
              },
            },
          },
        ],
      }),
    );
    stdout.writeln('  🟢 App 免費排程寫入回應 [${psPost.statusCode}]');
  }

  // 3. Auto-borrow Review Contact Info
  stdout.writeln('\n📡 [3/5] 自動帶入帳號審查聯絡人並寫入...');
  String first = Platform.environment['ASC_CONTACT_FIRST'] ?? '';
  String last = Platform.environment['ASC_CONTACT_LAST'] ?? '';
  String email = Platform.environment['ASC_CONTACT_EMAIL'] ?? '';
  String phone = Platform.environment['ASC_CONTACT_PHONE'] ?? '';

  if (first.isEmpty || last.isEmpty || email.isEmpty || phone.isEmpty) {
    final http.Response appsRes = await http.get(
      Uri.parse('$baseUrl/v1/apps?limit=20'),
      headers: headers,
    );
    if (appsRes.statusCode == 200) {
      final List<dynamic> apps =
          ((jsonDecode(appsRes.body) as Map<String, dynamic>)['data']
                  as List<dynamic>?) ??
              <dynamic>[];
      for (final dynamic a in apps) {
        final String otherId = (a as Map<String, dynamic>)['id'].toString();
        if (otherId == appId) continue;
        final http.Response vRes = await http.get(
          Uri.parse(
            '$baseUrl/v1/apps/$otherId/appStoreVersions?filter[platform]=IOS&limit=3',
          ),
          headers: headers,
        );
        if (vRes.statusCode != 200) continue;
        final List<dynamic> vers =
            ((jsonDecode(vRes.body) as Map<String, dynamic>)['data']
                    as List<dynamic>?) ??
                <dynamic>[];
        for (final dynamic v in vers) {
          final String vid = (v as Map<String, dynamic>)['id'].toString();
          final http.Response rdRes = await http.get(
            Uri.parse(
              '$baseUrl/v1/appStoreVersions/$vid/appStoreReviewDetail',
            ),
            headers: headers,
          );
          if (rdRes.statusCode != 200) continue;
          final dynamic rdData =
              (jsonDecode(rdRes.body) as Map<String, dynamic>)['data'];
          if (rdData is Map<String, dynamic>) {
            final Map<String, dynamic> attrs =
                rdData['attributes'] as Map<String, dynamic>;
            final String f = attrs['contactFirstName']?.toString() ?? '';
            final String l = attrs['contactLastName']?.toString() ?? '';
            final String em = attrs['contactEmail']?.toString() ?? '';
            final String ph = attrs['contactPhone']?.toString() ?? '';
            if (f.isNotEmpty && l.isNotEmpty && em.isNotEmpty && ph.isNotEmpty) {
              first = f;
              last = l;
              email = em;
              phone = ph;
              stdout.writeln(
                '  🟢 已自動取得聯絡人資料: $first $last ($email / $phone)',
              );
              break;
            }
          }
        }
        if (email.isNotEmpty) break;
      }
    }
  }

  if (first.isEmpty || last.isEmpty || email.isEmpty || phone.isEmpty) {
    stdout.write('  請輸入聯絡人 First Name: ');
    first = stdin.readLineSync()?.trim() ?? '';
    stdout.write('  請輸入聯絡人 Last Name: ');
    last = stdin.readLineSync()?.trim() ?? '';
    stdout.write('  請輸入聯絡人 Email: ');
    email = stdin.readLineSync()?.trim() ?? '';
    stdout.write('  請輸入聯絡人電話 (含國碼如 +886 912345678): ');
    phone = stdin.readLineSync()?.trim() ?? '';
  }

  final http.Response rdPatch = await http.patch(
    Uri.parse('$baseUrl/v1/appStoreReviewDetails/$reviewDetailId'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{
        'type': 'appStoreReviewDetails',
        'id': reviewDetailId,
        'attributes': <String, dynamic>{
          'contactFirstName': first,
          'contactLastName': last,
          'contactEmail': email,
          'contactPhone': phone,
          'demoAccountRequired': false,
        },
      },
    }),
  );
  stdout.writeln('  🟢 審查聯絡人寫入回應 [${rdPatch.statusCode}]');

  // 4. Upload 2048x2732 iPad 13" screenshots
  stdout.writeln('\n📡 [4/5] 上傳 iPad 13 吋 (2048x2732) 真實 UI 截圖...');
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

    final http.Response setGet = await http.get(
      Uri.parse(
        '$baseUrl/v1/appStoreVersionLocalizations/$locId/appScreenshotSets',
      ),
      headers: headers,
    );
    String? ipadSetId;
    for (final dynamic s
        in ((jsonDecode(setGet.body) as Map<String, dynamic>)['data']
                as List<dynamic>? ??
            <dynamic>[])) {
      final Map<String, dynamic> sm = s as Map<String, dynamic>;
      if ((sm['attributes'] as Map<String, dynamic>)['screenshotDisplayType'] ==
          'APP_IPAD_PRO_3GEN_129') {
        ipadSetId = sm['id'].toString();
        break;
      }
    }
    if (ipadSetId == null) {
      final http.Response setPost = await http.post(
        Uri.parse('$baseUrl/v1/appScreenshotSets'),
        headers: headers,
        body: jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'type': 'appScreenshotSets',
            'attributes': const <String, dynamic>{
              'screenshotDisplayType': 'APP_IPAD_PRO_3GEN_129',
            },
            'relationships': <String, dynamic>{
              'appStoreVersionLocalization': <String, dynamic>{
                'data': <String, dynamic>{
                  'type': 'appStoreVersionLocalizations',
                  'id': locId,
                },
              },
            },
          },
        }),
      );
      if (setPost.statusCode == 201 || setPost.statusCode == 200) {
        ipadSetId = ((jsonDecode(setPost.body) as Map<String, dynamic>)['data']
                as Map<String, dynamic>)['id']
            .toString();
      }
    }
    if (ipadSetId == null) continue;

    final http.Response curRes = await http.get(
      Uri.parse('$baseUrl/v1/appScreenshotSets/$ipadSetId/appScreenshots'),
      headers: headers,
    );
    final List<dynamic> curShots =
        ((jsonDecode(curRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>?) ??
            <dynamic>[];
    if (curShots.isEmpty) {
      final List<String> paths = locale == 'zh-Hant'
          ? <String>[
              'tool/screenshots/ipad13_zh_1.jpg',
              'tool/screenshots/ipad13_zh_2.jpg',
            ]
          : <String>[
              'tool/screenshots/ipad13_en_1.jpg',
              'tool/screenshots/ipad13_en_2.jpg',
            ];
      for (final String path in paths) {
        final Uint8List bytes = File(path).readAsBytesSync();
        final String md5Hex =
            Process.runSync('md5', <String>['-q', path]).stdout.toString().trim();
        final http.Response res = await http.post(
          Uri.parse('$baseUrl/v1/appScreenshots'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'appScreenshots',
              'attributes': <String, dynamic>{
                'fileName': path.split('/').last,
                'fileSize': bytes.length,
              },
              'relationships': <String, dynamic>{
                'appScreenshotSet': <String, dynamic>{
                  'data': <String, dynamic>{
                    'type': 'appScreenshotSets',
                    'id': ipadSetId,
                  },
                },
              },
            },
          }),
        );
        if (res.statusCode != 201 && res.statusCode != 200) continue;
        final Map<String, dynamic> data =
            (jsonDecode(res.body) as Map<String, dynamic>)['data']
                as Map<String, dynamic>;
        final String shotId = data['id'].toString();
        final List<dynamic> ops = ((data['attributes']
                    as Map<String, dynamic>)['uploadOperations']
                as List<dynamic>?) ??
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
        await http.patch(
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
        stdout.writeln('  🟢 [$locale / iPad 13"] 上傳完成: ${path.split('/').last}');
      }
    }
  }

  await Future<void>.delayed(const Duration(seconds: 6));

  // 5. Final Review Submission
  stdout.writeln('\n📡 [5/5] 掛載 Version 1.0 (Build 3) + 3 大內購並發射送審單...');
  const String submissionId = '4242d661-405f-4005-a12a-627e32bbb31a';

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
  stdout.writeln('  ‣ 掛載 Version 1.0 回應 [${addVer.statusCode}]');
  if (addVer.statusCode != 201 && addVer.statusCode != 200) {
    stderr.writeln('  ⚠️ Version 1.0 明細: ${addVer.body}');
  }

  final http.Response addLife = await http.post(
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
              'id': lifetimeId,
            },
          },
        },
      },
    }),
  );
  stdout.writeln('  ‣ 掛載 Lifetime 回應 [${addLife.statusCode}]');

  final http.Response grpRes = await http.get(
    Uri.parse('$baseUrl/v1/apps/$appId/subscriptionGroups'),
    headers: headers,
  );
  for (final dynamic g
      in ((jsonDecode(grpRes.body) as Map<String, dynamic>)['data']
              as List<dynamic>? ??
          <dynamic>[])) {
    final String gId = (g as Map<String, dynamic>)['id'].toString();
    final http.Response subRes = await http.get(
      Uri.parse('$baseUrl/v1/subscriptionGroups/$gId/subscriptions'),
      headers: headers,
    );
    for (final dynamic s
        in ((jsonDecode(subRes.body) as Map<String, dynamic>)['data']
                as List<dynamic>? ??
            <dynamic>[])) {
      final Map<String, dynamic> sm = s as Map<String, dynamic>;
      final String subId = sm['id'].toString();
      final Map<String, dynamic> attrs =
          sm['attributes'] as Map<String, dynamic>;
      if (attrs['state'] == 'READY_TO_SUBMIT') {
        final http.Response sr = await http.post(
          Uri.parse('$baseUrl/v1/subscriptionSubmissions'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'type': 'subscriptionSubmissions',
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
        stdout.writeln('  ‣ 提交訂閱 ${attrs['productId']} 回應 [${sr.statusCode}]');
        if (sr.statusCode != 201 && sr.statusCode != 200) {
          stdout.writeln('    明細: ${sr.body}');
        }
      }
    }
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
      '\n🟢🟢🟢 [大滿貫正式送審！] DoseFlow (Build 3 + StoreKit 2 + iPhone Duo 認證截圖 + 3 大內購) 已進入 Waiting for Review！',
    );
  } else {
    stderr.writeln(
      '\n⚠️ 送審最後關卡回報 [${submitRes.statusCode}]:\n${submitRes.body}',
    );
  }
}
