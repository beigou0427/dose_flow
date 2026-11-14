import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String keyId = '853IQM8TC6VX';
  const String lifetimeId = '6832587006';
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

  stdout.writeln('🔍 搜尋 $lifetimeId 的 \$119.99 價格點...');
  String? nextUrl =
      '$baseUrl/v2/inAppPurchases/$lifetimeId/pricePoints?filter[territory]=USA&limit=200';
  String? usaPpId;
  double bestDiff = double.infinity;

  while (nextUrl != null) {
    final http.Response res =
        await http.get(Uri.parse(nextUrl), headers: headers);
    if (res.statusCode != 200) break;
    final Map<String, dynamic> dec =
        jsonDecode(res.body) as Map<String, dynamic>;
    for (final dynamic item
        in (dec['data'] as List<dynamic>? ?? <dynamic>[])) {
      final Map<String, dynamic> m = item as Map<String, dynamic>;
      final double? p = double.tryParse(
        (m['attributes'] as Map<String, dynamic>)['customerPrice']
                ?.toString() ??
            '',
      );
      if (p == null) continue;
      final double diff = (p - 119.99).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        usaPpId = m['id'].toString();
      }
      if (diff < 0.01) {
        nextUrl = null;
        break;
      }
    }
    if (nextUrl != null) {
      nextUrl =
          (dec['links'] as Map<String, dynamic>?)?['next']?.toString();
    }
  }

  if (usaPpId == null) {
    stderr.writeln('🔴 找不到 \$119.99 價格點');
    exit(1);
  }
  stdout.writeln('🟢 鎖定 \$119.99 價格點 ID: $usaPpId');

  const String tempId = r'${iap_price_1}';
  final http.Response psPost = await http.post(
    Uri.parse('$baseUrl/v1/inAppPurchasePriceSchedules'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'data': <String, dynamic>{
        'type': 'inAppPurchasePriceSchedules',
        'relationships': <String, dynamic>{
          'baseTerritory': <String, dynamic>{
            'data': <String, dynamic>{'type': 'territories', 'id': 'USA'},
          },
          'inAppPurchase': <String, dynamic>{
            'data': <String, dynamic>{
              'type': 'inAppPurchases',
              'id': lifetimeId,
            },
          },
          'manualPrices': <String, dynamic>{
            'data': <Map<String, dynamic>>[
              <String, dynamic>{'type': 'inAppPurchasePrices', 'id': tempId},
            ],
          },
        },
      },
      'included': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'inAppPurchasePrices',
          'id': tempId,
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
                'id': lifetimeId,
              },
            },
          },
        },
      ],
    }),
  );
  stdout.writeln('  ‣ 寫入價格排程回應 [${psPost.statusCode}]');
  if (psPost.statusCode != 201 && psPost.statusCode != 200) {
    stderr.writeln('  🔴 錯誤細節: ${psPost.body}');
  }

  final http.Response recheck = await http.get(
    Uri.parse('$baseUrl/v2/inAppPurchases/$lifetimeId'),
    headers: headers,
  );
  if (recheck.statusCode == 200) {
    final String state =
        (((jsonDecode(recheck.body) as Map<String, dynamic>)['data']
                as Map<String, dynamic>)['attributes']
            as Map<String, dynamic>)['state']
            .toString();
    stdout.writeln('🟢 com.doseflow.app.lifetime 最新狀態 -> $state');
  }
}
