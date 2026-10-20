import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'intro_screen.dart';
import 'emis_webview_screen.dart';
import 'app_core.dart';
import 'google_speech_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _checkingGoogleSpeech = true;
  bool _googleSpeechAvailable = false;
  String _googleSpeechMessage = 'جاري فحص خدمة Google...';

  // متحكمات الحقول النصية للقيم الافتراضية
  late final TextEditingController _countryCtrl;
  late final TextEditingController _govCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _townCtrl;
  late final TextEditingController _address2Ctrl;
  late final TextEditingController _closestLocationCtrl;

  // قائمة المحافظات مطابقة تماماً لما يظهر في EMIS (بما فيها حلبجة وبنفس الترتيب)
  static const List<String> _iraqGovernorates = [
    'نينوى',
    'صلاح الدين',
    'كركوك',
    'ديالى',
    'بغداد',
    'الأنبار',
    'بابل',
    'كربلاء',
    'النجف',
    'القادسية',
    'المثنى',
    'واسط',
    'ذي قار',
    'ميسان',
    'البصرة',
    'أربيل',
    'دهوك',
    'السليمانية',
    'حلبجة',
  ];

  // قائمة المستوى المعيشي للطالب مطابقة للصورة تماماً
  static const List<Map<String, String>> _economicLevelOptions = [
    {'value': 'الطبقة تحت خط الفقر', 'label': 'الطبقة تحت خط الفقر'},
    {'value': 'الطبقة الفقيرة', 'label': 'الطبقة الفقيرة'},
    {'value': 'الطبقة الوسطى', 'label': 'الطبقة الوسطى'},
    {'value': 'الطبقة العليا', 'label': 'الطبقة العليا'},
  ];

  // قائمة نوع التوظيف مطابقة للصورة تماماً
  static const List<Map<String, String>> _employmentTypeOptions = [
    {'value': 'ملاك', 'label': 'ملاك دائم'},
    {'value': 'عقد', 'label': 'عقد'},
    {'value': 'محاضر', 'label': 'محاضر'},
    {'value': 'أجر يومي', 'label': 'أجر يومي'},
  ];

  // قائمة الحالة الوظيفية للمعلم مطابقة للصور تماماً
  static const List<Map<String, String>> _teacherStatusOptions = [
    {'value': 'مستمر', 'label': 'مستمر'},
    {'value': 'متقاعد', 'label': 'متقاعد'},
    {'value': 'مفصول', 'label': 'مفصول'},
    {'value': 'متوفى', 'label': 'متوفى'},
    {'value': 'استقالة', 'label': 'استقالة'},
    {'value': 'منقول الى وزارة أخرى', 'label': 'منقول الى وزارة أخرى'},
    {'value': 'العزل', 'label': 'العزل'},
    {
      'value': 'مكلف او منسبي من خارج الوزاراة',
      'label': 'مكلف او منسبي من خارج الوزاراة'
    },
    {
      'value': 'مكلف او منسب من وزارة التربية الى جهات أخرى',
      'label': 'مكلف او منسب من وزارة التربية الى جهات أخرى'
    },
    {'value': 'في إجازة دراسية', 'label': 'في إجازة دراسية'},
    {'value': 'في إجازة أمومة', 'label': 'في إجازة أمومة'},
    {'value': 'أخرى', 'label': 'أخرى'},
    {'value': 'مجاز', 'label': 'مجاز'},
    {'value': 'منسب', 'label': 'منسب'},
    {'value': 'سحب يد', 'label': 'سحب يد'},
    {'value': 'مستقيل', 'label': 'مستقيل'},
  ];

  // قائمة التحصيل الدراسي للمعلم مطابقة للصور تماماً
  static const List<Map<String, String>> _educationLevelOptions = [
    {'value': 'إعدادية', 'label': 'إعدادية'},
    {'value': 'إعدادية مهنية', 'label': 'إعدادية مهنية'},
    {'value': 'إعدادية دورة تأهيلية', 'label': 'إعدادية دورة تأهيلية'},
    {'value': 'دبلوم عالي', 'label': 'دبلوم عالي'},
    {'value': 'دبلوم معهد تطوير', 'label': 'دبلوم معهد تطوير'},
    {'value': 'دبلوم', 'label': 'دبلوم'},
    {'value': 'بكالوريوس', 'label': 'بكالوريوس'},
    {'value': 'ماجستير', 'label': 'ماجستير'},
    {'value': 'دكتوراه', 'label': 'دكتوراه'},
    {'value': 'دار المعلمين', 'label': 'دار المعلمين'},
    {'value': 'خريج ابتدائية', 'label': 'خريج ابتدائية'},
    {'value': 'خريج متوسطة', 'label': 'خريج متوسطة'},
    {'value': 'أخرى', 'label': 'أخرى'},
    {'value': 'يقرأ ويكتب', 'label': 'يقرأ ويكتب'},
    {'value': 'أمي', 'label': 'أمي'},
    {'value': 'مجهول', 'label': 'مجهول'},
    {'value': 'ابتدائية', 'label': 'ابتدائية'},
    {'value': 'متوسطة', 'label': 'متوسطة'},
  ];

  @override
  void initState() {
    super.initState();
    _countryCtrl = TextEditingController(text: AppCore.defaultCountry);
    _govCtrl = TextEditingController(text: AppCore.defaultGovernorate);
    _districtCtrl = TextEditingController(text: AppCore.defaultDistrict);
    _townCtrl = TextEditingController(text: AppCore.defaultTown);
    _address2Ctrl = TextEditingController(text: AppCore.defaultAddress2);
    _closestLocationCtrl =
        TextEditingController(text: AppCore.defaultClosestLocation);
    _checkGoogleSpeech();
  }

  @override
  void dispose() {
    _countryCtrl.dispose();
    _govCtrl.dispose();
    _districtCtrl.dispose();
    _townCtrl.dispose();
    _address2Ctrl.dispose();
    _closestLocationCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkGoogleSpeech() async {
    if (mounted) {
      setState(() {
        _checkingGoogleSpeech = true;
        _googleSpeechMessage = 'جاري فحص خدمة Google...';
      });
    }
    try {
      final info = await GoogleSpeechService.getInfo()
          .timeout(const Duration(seconds: 3));
      final available = info['available'] == true;
      final googleAvailable = info['googleAvailable'] == true;
      final provider = '${info['provider'] ?? ''}'.trim();
      final defaultPackage = '${info['defaultPackage'] ?? ''}'.trim();
      if (!mounted) return;
      setState(() {
        _googleSpeechAvailable = available;
        _checkingGoogleSpeech = false;
        if (!available) {
          _googleSpeechMessage =
              'لا توجد خدمة تعرف صوتي افتراضية متاحة في Android. افتح إعدادات إدخال الصوت وتأكد من تفعيل خدمة التعرف.';
        } else if (googleAvailable) {
          _googleSpeechMessage =
              'Google متاحة مباشرة. مزود التعرف الحالي: ${provider.isEmpty ? 'Google' : provider}.';
        } else {
          _googleSpeechMessage =
              'تطبيق Google مثبت، لكن Android لا يعرضه كخدمة مستقلة. سيتم استخدام خدمة التعرف الافتراضية${defaultPackage.isEmpty ? '' : ' ($defaultPackage)'}، وقد تكون Google.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingGoogleSpeech = false;
        _googleSpeechAvailable = false;
        _googleSpeechMessage = 'تعذر فحص خدمات التعرف الصوتي في Android.';
      });
    }
  }

  void _setVoiceEngine(String? engine) {
    if (engine == null) return;
    AppCore.setVoiceRecognitionEngine(engine);
    if (mounted) setState(() {});
  }

  void _setVoiceSetting({
    bool? autoRestart,
    int? possibleSilenceMs,
    int? completeSilenceMs,
    int? minimumSpeechMs,
    int? restartDelayMs,
    int? finalizationTimeoutMs,
    double? arrowOpacity,
  }) {
    AppCore.saveVoiceSettings(
      autoRestart: autoRestart,
      possibleSilenceMs: possibleSilenceMs,
      completeSilenceMs: completeSilenceMs,
      minimumSpeechMs: minimumSpeechMs,
      restartDelayMs: restartDelayMs,
      finalizationTimeoutMs: finalizationTimeoutMs,
      arrowOpacity: arrowOpacity,
    );
    if (mounted) setState(() {});
  }

  void _resetVoiceSettings() {
    AppCore.resetVoiceSettings();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('تمت إعادة جميع إعدادات الميكروفون إلى القيم الافتراضية.')),
    );
  }

  void _resetDefaultFields() {
    AppCore.resetDefaultFieldValues();
    _countryCtrl.text = AppCore.defaultCountry;
    _govCtrl.text = AppCore.defaultGovernorate;
    _districtCtrl.text = AppCore.defaultDistrict;
    _townCtrl.text = AppCore.defaultTown;
    _address2Ctrl.text = AppCore.defaultAddress2;
    _closestLocationCtrl.text = AppCore.defaultClosestLocation;
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تمت استعادة القيم الافتراضية الأصلية للمدرسة والحقول.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _setVoiceEnabled(bool enabled) async {
    if (enabled) {
      try {
        final permission = await Permission.microphone
            .request()
            .timeout(const Duration(seconds: 5));
        if (!permission.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'يجب منح التطبيق صلاحية الميكروفون من إعدادات Android أولاً.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('Permission request error: $e');
      }
    }

    AppCore.setVoiceInputEnabled(enabled);
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text(
          'سيتم حذف جلسة EMIS المحفوظة وملفات تعريف الارتباط وبيانات الدخول المحلية، ثم فتح صفحة تسجيل الدخول من جديد. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final cookieManager = WebViewCookieManager();
    try {
      await cookieManager.clearCookies().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('تعذر حذف Cookies قبل تسجيل الخروج: $e');
    }

    try {
      final pageLoaded = Completer<void>();
      final cleanupController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (!pageLoaded.isCompleted) pageLoaded.complete();
            },
          ),
        );
      await cleanupController.loadRequest(
        Uri.parse('https://emis.moedu.gov.iq/auth/login?logout_cleanup=1'),
      );
      await pageLoaded.future.timeout(const Duration(seconds: 3));
      await cleanupController.runJavaScript(r'''(async function() {
        try { localStorage.clear(); } catch (_) {}
        try { sessionStorage.clear(); } catch (_) {}
        try {
          if (window.indexedDB && indexedDB.databases) {
            const dbs = await indexedDB.databases();
            await Promise.all(dbs.map(db => db.name ? new Promise(resolve => {
              const req = indexedDB.deleteDatabase(db.name);
              req.onsuccess = req.onerror = req.onblocked = () => resolve();
            }) : Promise.resolve()));
          }
        } catch (_) {}
        try {
          if (navigator.serviceWorker && navigator.serviceWorker.getRegistrations) {
            const registrations = await navigator.serviceWorker.getRegistrations();
            await Promise.all(registrations.map(reg => reg.unregister()));
          }
        } catch (_) {}
        try {
          if (window.caches && caches.keys) {
            const keys = await caches.keys();
            await Promise.all(keys.map(key => caches.delete(key)));
          }
        } catch (_) {}
        try {
          document.querySelectorAll('input').forEach(input => {
            if (/password|username|user|email|login/i.test(
              [input.name, input.id, input.autocomplete, input.type].join(' '))) {
              input.value = '';
            }
          });
        } catch (_) {}
      })();''').timeout(const Duration(seconds: 2));
      await cookieManager.clearCookies().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('تعذر مسح بعض بيانات متصفح EMIS: $e');
      try {
        await cookieManager.clearCookies().timeout(const Duration(seconds: 1));
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const EmisWebviewScreen(startAtLogin: true),
      ),
      (route) => false,
    );
  }

  Widget _voiceSlider(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) formatter,
    required ValueChanged<double> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(
              formatter(value),
              style: TextStyle(
                color:
                    isDark ? Colors.lightGreenAccent : Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: formatter(value),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _defaultDropdown({
    required String label,
    required String currentValue,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    final hasValue = items.any((e) => e['value'] == currentValue);
    final effectiveItems = [
      if (!hasValue && currentValue.isNotEmpty)
        {'value': currentValue, 'label': currentValue},
      ...items,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: currentValue.isEmpty ? null : currentValue,
        isExpanded: true,
        dropdownColor: isDark ? const Color(0xFF252525) : Colors.white,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark ? Colors.black26 : const Color(0xFFF7F8FA),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: effectiveItems
            .map((item) => DropdownMenuItem<String>(
                  value: item['value'],
                  child: Text(
                    item['label']!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _defaultTextField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required bool isDark,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark ? Colors.black26 : const Color(0xFFF7F8FA),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _subHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppCore.themeNotifier,
      builder: (context, currentMode, child) {
        final isDark = currentMode == ThemeMode.dark;
        final bgColor =
            isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
        final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text(
              'الإعدادات',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF4A90E2)],
                ),
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                color: cardColor,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded,
                      color: Colors.red, size: 30),
                  title: Text(
                    'تسجيل الخروج من EMIS',
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  subtitle: Text(
                    'إنهاء الجلسة والعودة إلى شاشة تسجيل الدخول',
                    style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[700]),
                  ),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: _logout,
                ),
              ),
              const SizedBox(height: 15),
              Card(
                color: cardColor,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: Colors.amber,
                    size: 30,
                  ),
                  title: Text(
                    'الوضع الداكن (Dark Mode)',
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  trailing: Switch(
                    value: isDark,
                    activeColor: Colors.amber,
                    onChanged: (val) {
                      AppCore.saveThemePreference(val);
                      setState(() {});
                    },
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Card(
                color: cardColor,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        AppCore.isAudioMuted
                            ? Icons.volume_off
                            : Icons.music_note,
                        color: Colors.blue,
                        size: 30,
                      ),
                      title: Text(
                        'الموسيقى الهادئة',
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      trailing: Switch(
                        value: !AppCore.isAudioMuted,
                        activeColor: Colors.blue,
                        onChanged: (val) {
                          AppCore.toggleAudio();
                          setState(() {});
                        },
                      ),
                    ),
                    if (!AppCore.isAudioMuted)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.volume_down, color: Colors.grey),
                            Expanded(
                              child: Slider(
                                value: AppCore.currentVolume,
                                min: 0.0,
                                max: 1.0,
                                divisions: 10,
                                label:
                                    '${(AppCore.currentVolume * 100).round()}%',
                                onChanged: (val) {
                                  setState(() => AppCore.currentVolume = val);
                                  AppCore.setVolume(val);
                                },
                              ),
                            ),
                            const Icon(Icons.volume_up, color: Colors.grey),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // ==================== إطار القيم الافتراضية للمدرسة والحقول ====================
              Card(
                color: cardColor,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.school_rounded,
                              color: Colors.indigo, size: 30),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'القيم الافتراضية للمدرسة والحقول',
                                  style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                Text(
                                  'تُعبأ تلقائياً عند إضافة طالب أو معلم جديد بحسب نوع وموقع مدرستك',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _resetDefaultFields,
                            icon: const Icon(Icons.restore_rounded),
                            label: const Text('الافتراضي'),
                          ),
                        ],
                      ),
                      const Divider(),

                      _subHeader(
                        'البيانات الجغرافية والموقع (الدولة والمحافظة والمدينة)',
                        Icons.location_on_rounded,
                        isDark ? Colors.lightBlueAccent : Colors.indigo,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _defaultTextField(
                              label: 'الدولة / الجنسية / بلد الإصدار',
                              controller: _countryCtrl,
                              isDark: isDark,
                              onChanged: (v) =>
                                  AppCore.saveDefaultFieldValues(country: v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _defaultDropdown(
                              label: 'المحافظة الافتراضية',
                              currentValue: AppCore.defaultGovernorate,
                              isDark: isDark,
                              items: _iraqGovernorates
                                  .map((g) => {'value': g, 'label': g})
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                _govCtrl.text = v;
                                AppCore.saveDefaultFieldValues(governorate: v);
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _defaultTextField(
                              label: 'القضاء / الناحية الافتراضية',
                              controller: _districtCtrl,
                              hint: 'مثال: الديوانية',
                              isDark: isDark,
                              onChanged: (v) =>
                                  AppCore.saveDefaultFieldValues(district: v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _defaultTextField(
                              label: 'المدينة / القرية (نص العنوان)',
                              controller: _townCtrl,
                              hint: 'مثال: الديوانية',
                              isDark: isDark,
                              onChanged: (v) =>
                                  AppCore.saveDefaultFieldValues(town: v),
                            ),
                          ),
                        ],
                      ),

                      _subHeader(
                        'بيانات المدرسة والوثائق الشخصية (طالب ومعلم)',
                        Icons.badge_rounded,
                        isDark ? Colors.amberAccent : Colors.deepOrange,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _defaultDropdown(
                              label: 'الجنس الافتراضي (نوع المدرسة)',
                              currentValue: AppCore.defaultGender,
                              isDark: isDark,
                              items: const [
                                {'value': '1', 'label': 'ذكر (مدارس البنين)'},
                                {'value': '2', 'label': 'أنثى (مدارس البنات)'},
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                AppCore.saveDefaultFieldValues(gender: v);
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _defaultDropdown(
                              label: 'نوع الهوية الافتراضي',
                              currentValue: AppCore.defaultIdType,
                              isDark: isDark,
                              items: const [
                                {
                                  'value': '12',
                                  'label': 'البطاقة الوطنية الموحدة'
                                },
                                {
                                  'value': '3',
                                  'label': 'هوية الأحوال المدنية'
                                },
                                {'value': '22', 'label': 'شهادة الولادة'},
                                {'value': '16', 'label': 'أخرى'},
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                AppCore.saveDefaultFieldValues(idType: v);
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _defaultDropdown(
                              label: 'اللغة الأم',
                              currentValue: AppCore.defaultMotherTongue,
                              isDark: isDark,
                              items: const [
                                {'value': 'العربية', 'label': 'العربية'},
                                {'value': 'الكردية', 'label': 'الكردية'},
                                {'value': 'التركمانية', 'label': 'التركمانية'},
                                {'value': 'السريانية', 'label': 'السريانية'},
                                {'value': 'أخرى', 'label': 'أخرى'},
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                AppCore.saveDefaultFieldValues(motherTongue: v);
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _defaultDropdown(
                              label: 'لغة الدراسة',
                              currentValue: AppCore.defaultStudyLanguage,
                              isDark: isDark,
                              items: const [
                                {'value': 'العربية', 'label': 'العربية'},
                                {'value': 'الإنكليزية', 'label': 'الإنكليزية'},
                                {'value': 'الكردية', 'label': 'الكردية'},
                                {'value': 'التركمانية', 'label': 'التركمانية'},
                                {'value': 'السريانية', 'label': 'السريانية'},
                                {'value': 'أخرى', 'label': 'أخرى'},
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                AppCore.saveDefaultFieldValues(
                                    studyLanguage: v);
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _defaultDropdown(
                              label: 'الديانة الافتراضية',
                              currentValue: AppCore.defaultReligion,
                              isDark: isDark,
                              items: const [
                                {'value': 'الإسلام', 'label': 'الإسلام'},
                                {'value': 'المسيحية', 'label': 'المسيحية'},
                                {'value': 'الأزيدية', 'label': 'الأزيدية'},
                                {
                                  'value': 'الصابئة المندائية',
                                  'label': 'الصابئة المندائية'
                                },
                                {'value': 'أخرى', 'label': 'أخرى'},
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                AppCore.saveDefaultFieldValues(religion: v);
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _defaultDropdown(
                              label: 'فصيلة الدم الافتراضية',
                              currentValue: AppCore.defaultBloodGroup,
                              isDark: isDark,
                              items: const [
                                {'value': 'O+', 'label': 'O+'},
                                {'value': 'O-', 'label': 'O-'},
                                {'value': 'A+', 'label': 'A+'},
                                {'value': 'A-', 'label': 'A-'},
                                {'value': 'B+', 'label': 'B+'},
                                {'value': 'B-', 'label': 'B-'},
                                {'value': 'AB+', 'label': 'AB+'},
                                {'value': 'AB-', 'label': 'AB-'},
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                AppCore.saveDefaultFieldValues(bloodGroup: v);
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),

                      _subHeader(
                        'القيم الافتراضية الخاصة بالطالب',
                        Icons.person_rounded,
                        isDark ? Colors.lightGreenAccent : Colors.teal,
                      ),
                      _defaultDropdown(
                        label: 'المستوى المعيشي للطالب',
                        currentValue: AppCore.defaultEconomicLevel,
                        isDark: isDark,
                        items: _economicLevelOptions,
                        onChanged: (v) {
                          if (v == null) return;
                          AppCore.saveDefaultFieldValues(economicLevel: v);
                          setState(() {});
                        },
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _defaultTextField(
                              label: 'عنوان 2 الافتراضي',
                              controller: _address2Ctrl,
                              isDark: isDark,
                              onChanged: (v) =>
                                  AppCore.saveDefaultFieldValues(address2: v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _defaultTextField(
                              label: 'أقرب نقطة دالة افتراضية',
                              controller: _closestLocationCtrl,
                              isDark: isDark,
                              onChanged: (v) => AppCore.saveDefaultFieldValues(
                                  closestLocation: v),
                            ),
                          ),
                        ],
                      ),

                      _subHeader(
                        'القيم الافتراضية الخاصة بالمعلم / المدرس',
                        Icons.work_rounded,
                        isDark ? Colors.purpleAccent : Colors.deepPurple,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _defaultDropdown(
                              label: 'نوع التوظيف',
                              currentValue: AppCore.defaultEmploymentType,
                              isDark: isDark,
                              items: _employmentTypeOptions,
                              onChanged: (v) {
                                if (v == null) return;
                                AppCore.saveDefaultFieldValues(
                                    employmentType: v);
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _defaultDropdown(
                              label: 'نوع الموظف',
                              currentValue: AppCore.defaultEmployeeCategory,
                              isDark: isDark,
                              items: const [
                                {'value': 'تدريسي', 'label': 'تدريسي'},
                                {'value': 'إداري', 'label': 'إداري'},
                                {'value': 'خدمي', 'label': 'خدمي'},
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                AppCore.saveDefaultFieldValues(
                                    employeeCategory: v);
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _defaultDropdown(
                              label: 'التصنيف الوظيفي',
                              currentValue: AppCore.defaultClassification,
                              isDark: isDark,
                              items: const [
                                {'value': 'معلم', 'label': 'معلم'},
                                {'value': 'معلم جامعي', 'label': 'معلم جامعي'},
                                {'value': 'مدرس', 'label': 'مدرس'},
                                {'value': 'مرشد تربوي', 'label': 'مرشد تربوي'},
                                {'value': 'معلم مهني', 'label': 'معلم مهني'},
                                {'value': 'مدرب مهني', 'label': 'مدرب مهني'},
                                {'value': 'موظف بعقد', 'label': 'موظف بعقد'},
                                {'value': 'محاضر بعقد', 'label': 'محاضر بعقد'},
                                {'value': 'إداري', 'label': 'إداري'},
                                {'value': 'موظف خدمة', 'label': 'موظف خدمة'},
                                {'value': 'حارس', 'label': 'حارس'},
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                AppCore.saveDefaultFieldValues(
                                    classification: v);
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _defaultDropdown(
                              label: 'المنصب الحالي',
                              currentValue: AppCore.defaultCurrentPosition,
                              isDark: isDark,
                              items: const [
                                {'value': 'مدير', 'label': 'مدير'},
                                {'value': 'معاون', 'label': 'معاون'},
                                {'value': 'معلم', 'label': 'معلم'},
                                {'value': 'مدرس', 'label': 'مدرس'},
                                {'value': 'مرشد تربوي', 'label': 'مرشد تربوي'},
                                {'value': 'كاتب', 'label': 'كاتب'},
                                {'value': 'أمين مكتبة', 'label': 'أمين مكتبة'},
                                {'value': 'محاسب', 'label': 'محاسب'},
                                {'value': 'موظف خدمة', 'label': 'موظف خدمة'},
                                {'value': 'حارس ليلي', 'label': 'حارس ليلي'},
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                AppCore.saveDefaultFieldValues(
                                    currentPosition: v);
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      _defaultDropdown(
                        label: 'التحصيل الدراسي',
                        currentValue: AppCore.defaultEducationLevel,
                        isDark: isDark,
                        items: _educationLevelOptions,
                        onChanged: (v) {
                          if (v == null) return;
                          AppCore.saveDefaultFieldValues(educationLevel: v);
                          setState(() {});
                        },
                      ),
                      _defaultDropdown(
                        label: 'الحالة الوظيفية',
                        currentValue: AppCore.defaultTeacherStatus,
                        isDark: isDark,
                        items: _teacherStatusOptions,
                        onChanged: (v) {
                          if (v == null) return;
                          AppCore.saveDefaultFieldValues(teacherStatus: v);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),
              Card(
                color: cardColor,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      secondary: Icon(
                        AppCore.voiceSequentialAutoStart
                            ? Icons.keyboard_double_arrow_down_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppCore.voiceSequentialAutoStart
                            ? Colors.green
                            : Colors.grey,
                        size: 30,
                      ),
                      title: Text(
                        'التفعيل الافتراضي للتنقل الصوتي بين الحقول',
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      subtitle: Text(
                        'عند التفعيل يبدأ التنقل الصوتي تلقائياً عند فتح صفحة إضافة طالب جديد. يمكنك إيقافه من داخل الصفحة.',
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[700],
                            height: 1.35),
                      ),
                      value: AppCore.voiceSequentialAutoStart,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        AppCore.setVoiceSequentialAutoStart(value);
                        setState(() {});
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      secondary: Icon(
                        AppCore.voiceInputEnabled ? Icons.mic : Icons.mic_off,
                        color: AppCore.voiceInputEnabled
                            ? Colors.green
                            : Colors.red,
                        size: 30,
                      ),
                      title: Text(
                        'الميكروفون والتعرف الصوتي',
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      subtitle: Text(
                        'اختيار محرك التعرف الصوتي المستخدم في حقول إضافة الطالب',
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[700],
                            height: 1.35),
                      ),
                      value: AppCore.voiceInputEnabled,
                      activeColor: Colors.green,
                      onChanged: _setVoiceEnabled,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: DropdownButtonFormField<String>(
                        value: AppCore.voiceRecognitionEngine,
                        decoration: InputDecoration(
                          labelText: 'محرك التعرف الصوتي',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor:
                              isDark ? Colors.black26 : const Color(0xFFF7F8FA),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'google',
                            child: Text('Google / خدمة Android الافتراضية'),
                          ),
                          DropdownMenuItem(
                            value: 'legacy',
                            child: Text('التعرف السابق (speech_to_text)'),
                          ),
                        ],
                        onChanged: _setVoiceEngine,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.green.withOpacity(.10)
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.green.shade800
                                : Colors.green.shade200,
                          ),
                        ),
                        child: const Text(
                          'خدمة Google هنا ليست Google Cloud المدفوعة: التطبيق يستخدم SpeechRecognizer الموجود في Android مع مزود التعرف الموجود على الجهاز. لا يحتاج هذا المسار إلى مفتاح API أو اشتراك Google Cloud، لكن قد يستخدم اتصال الإنترنت وبيانات الهاتف عند اعتماد الخدمة على التعرف الشبكي.',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              height: 1.45,
                              fontSize: 12),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _checkingGoogleSpeech
                                ? Icons.sync
                                : (_googleSpeechAvailable
                                    ? Icons.cloud_done
                                    : Icons.warning_amber_rounded),
                            color: _checkingGoogleSpeech
                                ? Colors.blue
                                : (_googleSpeechAvailable
                                    ? Colors.green
                                    : Colors.orange),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _googleSpeechMessage,
                              style: TextStyle(
                                color:
                                    isDark ? Colors.white70 : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'إعادة الفحص',
                            onPressed: _checkingGoogleSpeech
                                ? null
                                : _checkGoogleSpeech,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Card(
                color: cardColor,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded,
                              color: Colors.green, size: 30),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'ضبط الميكروفون والتعرف الصوتي',
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _resetVoiceSettings,
                            icon: const Icon(Icons.restore_rounded),
                            label: const Text('الافتراضي'),
                          ),
                        ],
                      ),
                      const Divider(),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('إعادة الاستماع تلقائياً'),
                        subtitle: const Text(
                            'إذا أنهت خدمة Google جلسة بسبب الصمت أو النتيجة، يعيد التطبيق الاستماع تلقائياً ما دام المستخدم لم يضغط لإيقاف الميكروفون.'),
                        value: AppCore.voiceAutoRestart,
                        onChanged: (v) => _setVoiceSetting(autoRestart: v),
                      ),
                      const SizedBox(height: 8),
                      _voiceSlider(
                        context,
                        label: 'الصمت المحتمل قبل إنهاء الجملة',
                        value: AppCore.voicePossibleSilenceMs.toDouble(),
                        min: 1000,
                        max: 50000,
                        divisions: 98,
                        formatter: (v) => '${(v / 1000).toStringAsFixed(1)} ث',
                        onChanged: (v) =>
                            _setVoiceSetting(possibleSilenceMs: v.round()),
                      ),
                      _voiceSlider(
                        context,
                        label: 'الصمت المؤكد قبل إنهاء الجلسة',
                        value: AppCore.voiceCompleteSilenceMs.toDouble(),
                        min: 1000,
                        max: 50000,
                        divisions: 98,
                        formatter: (v) => '${(v / 1000).toStringAsFixed(1)} ث',
                        onChanged: (v) =>
                            _setVoiceSetting(completeSilenceMs: v.round()),
                      ),
                      _voiceSlider(
                        context,
                        label: 'الحد الأدنى لبدء التقاط الكلام',
                        value: AppCore.voiceMinimumSpeechMs.toDouble(),
                        min: 100,
                        max: 6000,
                        divisions: 59,
                        formatter: (v) => '${v.round()} مللي ثانية',
                        onChanged: (v) =>
                            _setVoiceSetting(minimumSpeechMs: v.round()),
                      ),
                      _voiceSlider(
                        context,
                        label: 'الفاصل بين جلسات التعرف',
                        value: AppCore.voiceRestartDelayMs.toDouble(),
                        min: 0,
                        max: 9000,
                        divisions: 90,
                        formatter: (v) => '${v.round()} مللي ثانية',
                        onChanged: (v) =>
                            _setVoiceSetting(restartDelayMs: v.round()),
                      ),
                      _voiceSlider(
                        context,
                        label: 'مهلة إنهاء الجلسة عند الضغط على الإيقاف',
                        value: AppCore.voiceFinalizationTimeoutMs.toDouble(),
                        min: 500,
                        max: 6000,
                        divisions: 55,
                        formatter: (v) => '${v.round()} مللي ثانية',
                        onChanged: (v) =>
                            _setVoiceSetting(finalizationTimeoutMs: v.round()),
                      ),
                      _voiceSlider(
                        context,
                        label: 'شفافية الأسهم الثابتة',
                        value: ((1.0 - AppCore.voiceArrowOpacity) * 100)
                            .clamp(10.0, 80.0),
                        min: 10,
                        max: 80,
                        divisions: 14,
                        formatter: (v) => '${v.round()}%',
                        onChanged: (v) =>
                            _setVoiceSetting(arrowOpacity: 1.0 - v / 100.0),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'زيادة الشفافية تجعل الأسهم أقل تغطية للحقول الموجودة خلفها. الإعدادات الزمنية تؤثر على مسار Google/Android ولا تُجبر خدمة Google إذا كانت تفرض حدوداً داخلية خاصة بها.',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[700],
                            height: 1.45,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Card(
                color: cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'الخيار الأول يستخدم Android SpeechRecognizer مع خدمة Google عندما تكون متاحة مباشرة، وإذا لم تكن ظاهرة كخدمة مستقلة يستخدم مزود التعرف الافتراضي في Android. إذا بقي التعرف غير مناسب، اختر «التعرف السابق (speech_to_text)» للعودة إلى الطريقة التي كانت تعمل سابقاً. عند إيقاف الميكروفون لن تعمل أزراره في صفحة إضافة الطالب حتى تعيد تفعيله من هنا.',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontWeight: FontWeight.w600, height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Center(
                child: Text(
                  'نسخة غير رسمية',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 5),
              const Center(
                child: Text(
                  'تصميم/ علي الفتلاوي / ثانوية الديوانية للمتميزين',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}
