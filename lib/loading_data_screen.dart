import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dashboard_screen.dart';
import 'app_core.dart';
import 'emis_webview_screen.dart';

class LoadingDataScreen extends StatefulWidget {
  final String token;
  final String? refreshToken;
  final String schoolId;

  const LoadingDataScreen({
    super.key,
    required this.token,
    this.refreshToken,
    required this.schoolId,
  });

  @override
  State<LoadingDataScreen> createState() => _LoadingDataScreenState();
}

class _SessionExpired implements Exception {}

class _LoadingDataScreenState extends State<LoadingDataScreen>
    with SingleTickerProviderStateMixin {
  String _statusText = 'جاري الاتصال بخوادم EMIS...';
  double _progressValue = .08;
  late String _activeToken;
  late final AnimationController _pulse;

  // قفل لمنع إرسال عدة طلبات تحديث رمز الدخول في نفس اللحظة
  Future<bool>? _refreshingTokenFuture;
  bool _hasTriedRefreshOn403 = false;

  List<Map<String, dynamic>> _stages = [];
  final Map<String, List<Map<String, dynamic>>> _subjectsByStage = {};
  final Map<String, List<Map<String, dynamic>>> _examsBySubject = {};

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _activeToken = widget.token;
    AppCore.playRelaxMusic();
    _startFetchingData();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Map<String, String> get _headers => {
        'Authorization': _activeToken.toLowerCase().startsWith('bearer ')
            ? _activeToken
            : 'Bearer $_activeToken',
        'Accept': 'application/json, text/plain, */*',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      };

  /// تحديث رمز الدخول بأمان مع منع تداخل الطلبات المتزامنة
  Future<bool> _refreshAccessToken() async {
    if (_refreshingTokenFuture != null) {
      return await _refreshingTokenFuture!;
    }
    _refreshingTokenFuture = _doRefreshToken();
    try {
      return await _refreshingTokenFuture!;
    } finally {
      _refreshingTokenFuture = null;
    }
  }

  Future<bool> _doRefreshToken() async {
    final refresh = widget.refreshToken?.trim();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final current = _activeToken.replaceFirst(
        RegExp(r'^Bearer\s+', caseSensitive: false),
        '',
      );
      final response = await http
          .post(
            Uri.parse('https://emis.moedu.gov.iq/api/account/refresh'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'accessToken': current,
              'refreshToken': refresh,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return false;
      final decoded = _decode(response);
      if (decoded is Map) {
        final next = (decoded['accessToken'] ??
                decoded['token'] ??
                (decoded['data'] is Map ? decoded['data']['accessToken'] : null))
            ?.toString();
        if (next != null && next.trim().isEmpty == false) {
          _activeToken = next.trim();
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// دالة جلب أساسية مع معالجة ذكية للأخطاء ورموز الحالة
  Future<http.Response> _get(Uri uri, {int retries = 2}) async {
    http.Response? last;
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final response = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 15));
        last = response;

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        // 401 يعني انتهاء صلاحية الجلسة فعلياً
        if (response.statusCode == 401) {
          if (await _refreshAccessToken()) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            continue;
          }
          throw _SessionExpired();
        }

        // 403 غالباً ما يكون بسبب نقص صلاحيات المستخدم في EMIS لدالة معينة (مثل الامتحانات)
        // أو بسبب ضغط الطلبات، لذلك نجرب تحديث التوكن مرة واحدة فقط طوال فترة التحميل
        if (response.statusCode == 403) {
          if (!_hasTriedRefreshOn403) {
            _hasTriedRefreshOn403 = true;
            if (await _refreshAccessToken()) {
              await Future<void>.delayed(const Duration(milliseconds: 400));
              continue;
            }
          }
          // إذا استمر 403، نخرج فوراً ولا نعيد المحاولة لتجنب حظر الحساب أو تأخير التحميل
          break;
        }

        // في حال وجود ضغط على الخادم (429 أو 500+) ننتظر قليلاً ثم نعيد المحاولة
        if (attempt < retries - 1) {
          await Future<void>.delayed(Duration(milliseconds: 800 * (attempt + 1)));
        }
      } on _SessionExpired {
        rethrow;
      } catch (_) {
        if (attempt == retries - 1) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }
    throw Exception('EMIS HTTP ${last?.statusCode ?? 0}');
  }

  /// دالة جلب آمنة لا توقف التطبيق أبداً (تُرجع null عند الفشل ما عدا انتهاء الجلسة 401)
  Future<dynamic> _safeGetDecoded(Uri uri, {String debugLabel = ''}) async {
    try {
      final response = await _get(uri);
      return _decode(response);
    } on _SessionExpired {
      rethrow; // انتهاء الجلسة الكلي فقط يعيد التوجيه لصفحة الدخول
    } catch (e) {
      debugPrint('⚠️ تم تخطي خطأ في [$debugLabel] ($uri): $e');
      return null;
    }
  }

  /// فك تشفير مرن وآمن ضد النصوص الفارغة أو غير الصالحة
  dynamic _decode(http.Response response) {
    try {
      final text = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      if (text.isEmpty) return <String, dynamic>{};
      return jsonDecode(text);
    } catch (e) {
      debugPrint('⚠️ تعذر قراءة JSON: $e');
      return <String, dynamic>{};
    }
  }

  /// استخراج ذكي للقوائم مهما كان شكل استجابة EMIS
  List<dynamic> _smartExtractList(dynamic decoded) {
    if (decoded == null) return <dynamic>[];
    if (decoded is List) return decoded;
    if (decoded is Map) {
      // البحث في المفاتيح الشائعة التي يستخدمها نظام EMIS
      const candidateKeys = [
        'data',
        'items',
        'result',
        'results',
        'records',
        'value',
        'exams',
        'students',
        'employees',
        'stages',
        'subjects',
        'list',
      ];
      for (final key in candidateKeys) {
        final val = decoded[key];
        if (val is List) return val;
        // أحياناً تكون البيانات متداخلة مثل data -> items
        if (val is Map) {
          for (final subKey in candidateKeys) {
            if (val[subKey] is List) return val[subKey] as List;
          }
        }
      }
      // إذا لم يجد مفتاحاً معروفاً، يبحث عن أول قيمة من نوع List داخل الـ Map
      for (final val in decoded.values) {
        if (val is List) return val;
      }
    }
    return <dynamic>[];
  }

  /// استخراج ذكي لقائمة من الخرائط (List<Map<String, dynamic>>)
  List<Map<String, dynamic>> _smartMaps(dynamic value) {
    final list = _smartExtractList(value);
    return [
      for (final item in list)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  /// استخراج ذكي لبيانات كائن مفرد (Map) مثل بيانات المستخدم أو المدرسة
  Map<String, dynamic> _smartExtractMap(dynamic decoded) {
    if (decoded == null) return <String, dynamic>{};
    if (decoded is Map) {
      if (decoded['data'] is Map) {
        return Map<String, dynamic>.from(decoded['data'] as Map);
      }
      if (decoded['result'] is Map) {
        return Map<String, dynamic>.from(decoded['result'] as Map);
      }
      return Map<String, dynamic>.from(decoded);
    }
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      return Map<String, dynamic>.from(decoded.first as Map);
    }
    return <String, dynamic>{};
  }

  /// استخراج المعرف (ID) بمرونة عالية مهما اختلف اسمه في استجابة EMIS
  String _catalogId(Map<String, dynamic> item) {
    final id = item['value'] ??
        item['id'] ??
        item['stageId'] ??
        item['subjectId'] ??
        item['key'] ??
        item['code'] ??
        '';
    return id.toString().trim();
  }

  /// تشغيل متزامن هادئ وآمن لا يتوقف عند فشل أحد العناصر
  Future<void> _runConcurrent<T>(
    List<T> items,
    Future<void> Function(T item) task, {
    int maxConcurrent = 2,
  }) async {
    if (items.isEmpty) return;
    var nextIndex = 0;
    final safeConcurrency = maxConcurrent > 2 ? 2 : maxConcurrent;
    final workerCount =
        items.length < safeConcurrency ? items.length : safeConcurrency;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= items.length) return;
        try {
          await task(items[index]);
        } on _SessionExpired {
          rethrow;
        } catch (e) {
          debugPrint('⚠️ تم تخطي عنصر أثناء المزامنة: $e');
        }
        // تهدئة بسيطة جداً لمنع جدار الحماية في EMIS من حظر الطلبات المتتالية (403)
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));
  }

  Future<void> _loadAcademicCatalog() async {
    if (!mounted) return;
    setState(() {
      _statusText = 'جاري استيراد الصفوف الدراسية...';
      _progressValue = .46;
    });

    final stagesDecoded = await _safeGetDecoded(
      Uri.parse(
        'https://emis.moedu.gov.iq/api/selectoption/getschoolstages/${widget.schoolId}',
      ),
      debugLabel: 'الصفوف الدراسية',
    );
    _stages = _smartMaps(stagesDecoded);

    // إذا لم ترجع الصفوف (أو لم تكن للمستخدم صلاحية)، نكمل التحميل دون إيقاف التطبيق
    if (_stages.isEmpty) {
      debugPrint('ℹ️ لم تُرجع EMIS صفوفاً دراسية، سيتم المتابعة للبيانات الأخرى.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _statusText = 'جاري استيراد المواد الدراسية...';
      _progressValue = .50;
    });

    final stageIds = _stages
        .map(_catalogId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    await _runConcurrent(stageIds, (stageId) async {
      final decoded = await _safeGetDecoded(
        Uri.parse(
          'https://emis.moedu.gov.iq/api/subject/getsubjectsselect?stageId=$stageId&schoolId=${widget.schoolId}',
        ),
        debugLabel: 'مواد الصف $stageId',
      );
      _subjectsByStage[stageId] = _smartMaps(decoded);
    });

    final subjectKeys = <String>[];
    for (final entry in _subjectsByStage.entries) {
      for (final subject in entry.value) {
        final subjectId = _catalogId(subject);
        if (subjectId.isNotEmpty) {
          subjectKeys.add('${entry.key}:$subjectId');
        }
      }
    }

    if (subjectKeys.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _statusText = 'جاري استيراد الفصول الدراسية من EMIS...';
      _progressValue = .56;
    });

    int completedExams = 0;
    await _runConcurrent(subjectKeys, (key) async {
      final parts = key.split(':');
      if (parts.length != 2) return;
      final stageId = parts[0];
      final subjectId = parts[1];

      final decoded = await _safeGetDecoded(
        Uri.parse(
          'https://emis.moedu.gov.iq/api/examscore/getexamsformarks?schoolId=${widget.schoolId}&stageId=$stageId&subjectId=$subjectId',
        ),
        debugLabel: 'امتحانات $key',
      );

      final rawExams =
          (decoded is Map && decoded['exams'] != null) ? decoded['exams'] : decoded;
      _examsBySubject[key] = _smartMaps(rawExams);

      completedExams++;
      if (mounted && subjectKeys.isNotEmpty) {
        setState(() {
          // تحريك شريط التقدم بسلاسة بين 56% و 62% أثناء جلب الفصول
          _progressValue = .56 + (.06 * (completedExams / subjectKeys.length));
        });
      }
    });

    if (!mounted) return;
    setState(() {
      _statusText = 'اكتمل استيراد الفصول الدراسية والمواد...';
      _progressValue = .62;
    });
  }

  Future<void> _startFetchingData() async {
    try {
      _hasTriedRefreshOn403 = false;

      // 1. جلب بيانات المستخدم
      if (!mounted) return;
      setState(() {
        _statusText = 'جاري جلب بيانات المستخدم...';
        _progressValue = .20;
      });
      String realUserName = 'مستخدم النظام';
      final userDecoded = await _safeGetDecoded(
        Uri.parse('https://emis.moedu.gov.iq/api/account/getloggedinuser'),
        debugLabel: 'بيانات المستخدم',
      );
      final userData = _smartExtractMap(userDecoded);
      final extractedUserName = (userData['employeeName'] ??
              userData['fullName'] ??
              userData['userName'] ??
              userData['name'] ??
              '')
          .toString()
          .trim();
      if (extractedUserName.isNotEmpty) {
        realUserName = extractedUserName;
      }

      // 2. جلب بيانات المدرسة
      if (!mounted) return;
      setState(() {
        _statusText = 'جاري جلب بيانات المدرسة...';
        _progressValue = .38;
      });
      String schoolName = 'المدرسة';
      final schoolDecoded = await _safeGetDecoded(
        Uri.parse(
          'https://emis.moedu.gov.iq/api/school/getschoolinformation/${widget.schoolId}',
        ),
        debugLabel: 'بيانات المدرسة',
      );
      final schoolData = _smartExtractMap(schoolDecoded);
      final extractedSchoolName = (schoolData['schoolName'] ??
              schoolData['name'] ??
              schoolData['entityName'] ??
              schoolData['title'] ??
              '')
          .toString()
          .trim();
      if (extractedSchoolName.isNotEmpty) {
        schoolName = extractedSchoolName;
      }

      // 3. جلب الصفوف والمواد والفصول الدراسية (بشكل مرن يتخطى أي أخطاء صلاحيات 403)
      await _loadAcademicCatalog();

      // 4. جلب سجلات الطلاب
      if (!mounted) return;
      setState(() {
        _statusText = 'جاري تحميل سجلات الطلاب...';
        _progressValue = .72;
      });
      final studentsDecoded = await _safeGetDecoded(
        Uri.parse(
          'https://emis.moedu.gov.iq/api/student/getstudents?page=1&rowsPerPage=3000&sortBy=id&sortOrder=desc&entityId=${widget.schoolId}',
        ),
        debugLabel: 'سجلات الطلاب',
      );
      final studentsData = _smartExtractList(studentsDecoded);

      // 5. جلب سجلات المعلمين
      if (!mounted) return;
      setState(() {
        _statusText = 'جاري تحميل سجلات المعلمين...';
        _progressValue = .88;
      });
      final teachersDecoded = await _safeGetDecoded(
        Uri.parse(
          'https://emis.moedu.gov.iq/api/employee/getemployeesbyentities?page=1&rowsPerPage=1000&sortBy=id&sortOrder=desc&entityId=${widget.schoolId}&isTeacher=true',
        ),
        debugLabel: 'سجلات المعلمين',
      );
      final teachersData = _smartExtractList(teachersDecoded);

      // 6. اكتمال التحميل والانتقال للرئيسية
      if (!mounted) return;
      setState(() {
        _statusText = 'اكتملت المزامنة — تجهيز التطبيق...';
        _progressValue = 1.0;
      });
      await Future<void>.delayed(const Duration(milliseconds: 450));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            token: _headers['Authorization']!,
            schoolId: widget.schoolId,
            schoolName: schoolName,
            userName: realUserName,
            allStudents: studentsData,
            allTeachers: teachersData,
            stages: _stages,
            subjectsByStage: _subjectsByStage,
            examsBySubject: _examsBySubject,
          ),
        ),
      );
    } on _SessionExpired {
      if (!mounted) return;
      setState(() {
        _statusText = 'انتهت جلسة EMIS. إعادة فتح جلسة الدخول...';
        _progressValue = .12;
      });
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EmisWebviewScreen()),
      );
    } catch (e) {
      debugPrint('EMIS fatal loading error: $e');
      if (!mounted) return;
      setState(() {
        _statusText = 'تعذر تحميل بيانات المدرسة. أعد المحاولة.';
      });
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تعذر تحميل البيانات'),
          content: Text('$e', textDirection: TextDirection.rtl),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _startFetchingData();
              },
              child: const Text('إعادة المحاولة'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const EmisWebviewScreen()),
                );
              },
              child: const Text('تسجيل الدخول من جديد'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF172A88), Color(0xFF2F78D0), Color(0xFFF4F7FC)],
            stops: [0, .55, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Transform.scale(
                      scale: 1 + (_pulse.value * .035),
                      child: SizedBox(
                        width: 250,
                        height: 310,
                        child: Image.asset(
                          'assets/avatar.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'مساعد EMIS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'مساعد الإدارة المدرسية',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 34),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.14),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.sync_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _statusText,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _progressValue,
                            minHeight: 9,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${(_progressValue * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
