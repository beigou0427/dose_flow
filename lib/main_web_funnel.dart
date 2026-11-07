import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'core/pharmacokinetics_engine.dart';

/// 專為 Web 編譯的引流著陸頁入口 (執行: flutter run -d chrome -t lib/main_web_funnel.dart)
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WebFunnelApp());
}

class WebFunnelApp extends StatelessWidget {
  const WebFunnelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoseFlow - GLP-1 Pharmacokinetics Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0EA5E9),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      home: const LandingPage(),
    );
  }
}

/// 限制最大寬度的容器，確保在桌面瀏覽器上的排版如同手機版精緻
class MaxWidthContainer extends StatelessWidget {
  const MaxWidthContainer({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: child,
      ),
    );
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  Glp1Medication _medication = Glp1Medication.tirzepatide;
  double _doseMg = 2.5;
  int _daysAgo = 5;

  @override
  Widget build(BuildContext context) {
    final double activeResidualMg =
        PharmacokineticsEngine.singleDoseConcentrationAt(
      doseMg: _doseMg,
      medication: _medication,
      elapsedHours: _daysAgo * 24.0,
    );
    final Color doseColor = PharmacokineticsEngine.colorForDose(_doseMg);

    return Scaffold(
      body: SafeArea(
        child: MaxWidthContainer(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            children: <Widget>[
              // 1. 品牌與痛點標題區 (Information Gap Hook)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                  ),
                  child: const Text(
                    'Free GLP-1 Active Level Calculator',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0284C7),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Stop Guessing Your\nGLP-1 Levels.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select your dose to reveal how much active medication remains in your body today, calibrated by FDA pharmacokinetics.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // 2. 互動表單區 (藥物、劑量、天數)
              Card(
                color: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  side: BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '1. Medication',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      // 遵循 Flutter 3.33+ 規範，採用 initialValue 徹底消滅 value deprecated 警告
                      DropdownButtonFormField<Glp1Medication>(
                        initialValue: _medication,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: Glp1Medication.values.map((Glp1Medication med) {
                          return DropdownMenuItem<Glp1Medication>(
                            value: med,
                            child: Text(
                              med.displayNameEn,
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          );
                        }).toList(),
                        onChanged: (Glp1Medication? val) {
                          if (val != null) setState(() => _medication = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text('2. Dose Administered', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text('${_doseMg.toStringAsFixed(1)} mg', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: doseColor)),
                        ],
                      ),
                      Slider(
                        value: _doseMg.clamp(1.0, 15.0),
                        min: 1.0,
                        max: 15.0,
                        divisions: 28,
                        activeColor: doseColor,
                        onChanged: (double v) => setState(() => _doseMg = v),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text('3. Days Since Last Shot', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text('$_daysAgo days ago', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: doseColor)),
                        ],
                      ),
                      Slider(
                        value: _daysAgo.toDouble().clamp(0.0, 14.0),
                        min: 0,
                        max: 14,
                        divisions: 14,
                        activeColor: doseColor,
                        onChanged: (double v) => setState(() => _daysAgo = v.round()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. 即時運算結果卡 (The Aha Moment)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: doseColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  border: Border.all(color: doseColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.bolt_rounded, color: doseColor, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Estimated Active Level',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: doseColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '~${activeResidualMg.toStringAsFixed(2)} mg',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. 高斯模糊鎖定預覽區 (The Hard Paywall)
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 6.5, sigmaY: 6.5),
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.all(Radius.circular(16)),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: CustomPaint(
                        size: const Size(double.infinity, 200),
                        painter: PharmacokineticsChartPainter(
                          series: PharmacokineticsEngine.generateTimelineSeries(
                            logs: <InjectionRecord>[
                              InjectionRecord(
                                id: 'web_preview_shot',
                                timestamp: DateTime.now().subtract(Duration(days: _daysAgo)),
                                medication: _medication,
                                doseMg: _doseMg,
                                site: InjectionSite.rightLowerAbdomen,
                              )
                            ],
                            now: DateTime.now(),
                          ),
                          primaryColor: doseColor,
                          nowLabel: 'NOW',
                        ),
                      ),
                    ),
                  ),
                  // 鎖定卡片與下載引導
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      border: Border.all(color: doseColor.withValues(alpha: 0.3)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.lock_rounded, color: doseColor, size: 28),
                        const SizedBox(height: 8),
                        const Text(
                          'Unlock Your Full PK Curve',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Download DoseFlow to see 7-day forecasts,\nsyringe math & smart injection rotation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 5. 雙平台下載按鈕 (CTA)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {}, // 實機環境此處可放入 URL Launcher 導向 App Store
                      icon: const Icon(Icons.apple_rounded),
                      label: const Text('App Store'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {}, // 實機環境此處可放入 URL Launcher 導向 Google Play
                      icon: const Icon(Icons.shop_rounded),
                      label: const Text('Google Play'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // 6. 法規與隱私免責聲明 (FDA Compliance)
              const Text(
                'Disclaimer: DoseFlow is a personal tracker, not a medical device. Estimates use FDA Prescribing Information (Section 12.3) Bateman function models. 100% Local-First privacy.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), height: 1.5),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
