import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String keyId = '853IQM8TC6VX';
  const String versionId = '277e9a5f-25ce-4e00-96e4-156eda75812c';
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

  final List<File> duoFiles = Directory('tool/screenshots/manual_duo')
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.jpg'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));

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

    final http.Response setRes = await http.get(
      Uri.parse(
        '$baseUrl/v1/appStoreVersionLocalizations/$locId/appScreenshotSets?include=appScreenshots',
      ),
      headers: headers,
    );
    final Map<String, dynamic> setDec =
        jsonDecode(setRes.body) as Map<String, dynamic>;
    final List<dynamic> sets = (setDec['data'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> included =
        (setDec['included'] as List<dynamic>?) ?? <dynamic>[];

    String? duoSetId;
    for (final dynamic s in sets) {
      final Map<String, dynamic> sm = s as Map<String, dynamic>;
      final Map<String, dynamic> attrs =
          sm['attributes'] as Map<String, dynamic>;
      if (attrs['screenshotDisplayType'] == 'APP_IPHONE_DUO') {
        duoSetId = sm['id'].toString();
        final List<dynamic> relShots = (((sm['relationships']
                        as Map<String, dynamic>?)?['appScreenshots']
                    as Map<String, dynamic>?)?['data'] as List<dynamic>?) ??
            <dynamic>[];
        for (final dynamic rs in relShots) {
          final String oldId = (rs as Map<String, dynamic>)['id'].toString();
          await http.delete(
            Uri.parse('$baseUrl/v1/appScreenshots/$oldId'),
            headers: headers,
          );
        }
        stdout.writeln('\n🧹 [$locale / APP_IPHONE_DUO] 已清除 ${relShots.length} 張舊圖');
      }
    }

    if (duoSetId == null) continue;
    for (final File file in duoFiles) {
      final String path = file.path;
      final Uint8List bytes = file.readAsBytesSync();
      final String md5Hex =
          Process.runSync('md5', <String>['-q', path]).stdout.toString().trim();
      final http.Response res = await http.post(
        Uri.parse('$baseUrl/v1/appScreenshots'),
        headers: headers,
        body: jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'type': 'appScreenshots',
            'attributes': <String, dynamic>{
              'fileName': '${locale}_${path.split('/').last}',
              'fileSize': bytes.length,
            },
            'relationships': <String, dynamic>{
              'appScreenshotSet': <String, dynamic>{
                'data': <String, dynamic>{
                  'type': 'appScreenshotSets',
                  'id': duoSetId,
                },
              },
            },
          },
        }),
      );
      if (res.statusCode != 201 && res.statusCode != 200) {
        stderr.writeln('  🔴 預約失敗 $path [${res.statusCode}]: ${res.body}');
        continue;
      }
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
      stdout.writeln('  🟢 [$locale / APP_IPHONE_DUO] 已上傳手動真機圖: ${path.split('/').last}');
    }
    if (included.isEmpty) continue;
  }

  await Future<void>.delayed(const Duration(seconds: 5));
  stdout.writeln('\n🔍 驗貨 Apple 伺服器 APP_IPHONE_DUO 掃描結果:');
  for (final dynamic l in locs) {
    final Map<String, dynamic> lm = l as Map<String, dynamic>;
    final String locId = lm['id'].toString();
    final String locale =
        (lm['attributes'] as Map<String, dynamic>)['locale'].toString();
    if (locale != 'zh-Hant' && locale != 'en-US') continue;
    final http.Response setRes = await http.get(
      Uri.parse(
        '$baseUrl/v1/appStoreVersionLocalizations/$locId/appScreenshotSets?include=appScreenshots',
      ),
      headers: headers,
    );
    final List<dynamic> shots =
        ((jsonDecode(setRes.body) as Map<String, dynamic>)['included']
                as List<dynamic>?) ??
            <dynamic>[];
    for (final dynamic sh in shots) {
      final Map<String, dynamic> attrs =
          (sh as Map<String, dynamic>)['attributes'] as Map<String, dynamic>;
      if (!attrs['fileName'].toString().contains('duo')) continue;
      final Map<String, dynamic> ads =
          attrs['assetDeliveryState'] as Map<String, dynamic>? ??
              <String, dynamic>{};
      stdout.writeln(
        '  • [$locale] ${attrs['fileName']} -> ${ads['state']}${(ads['errors'] as List<dynamic>? ?? <dynamic>[]).isNotEmpty ? " | 錯誤: ${ads['errors']}" : ""}',
      );
    }
  }
}
