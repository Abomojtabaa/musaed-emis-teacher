import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'app_core.dart';
import 'emis_live_sync.dart';
import 'google_speech_service.dart';
import 'legacy_speech_service.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Allows a numeric grade, or one of the two EMIS special marks: م / غ.
/// Special marks are accepted alone; mixing them with digits is rejected.
class GradeValueInputFormatter extends TextInputFormatter {
  const GradeValueInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final value = newValue.text;
    if (value.isEmpty || RegExp(r'^\d+$').hasMatch(value) || value == 'م' || value == 'غ') {
      return newValue;
    }
    return oldValue;
  }
}

class GradeEntryScreen extends StatefulWidget {
  final String token;
  final String schoolId;
  final List<Map<String, dynamic>> teachingAssignments;
  const GradeEntryScreen({
    super.key,
    required this.token,
    required this.schoolId,
    required this.teachingAssignments,
  });

  @override
  State<GradeEntryScreen> createState() => _GradeEntryScreenState();
}

class _GradeEntryScreenState extends State<GradeEntryScreen> {
  List<Map<String, dynamic>> stages = [];
  List<Map<String, dynamic>> subjects = [];
  List<Map<String, dynamic>> rooms = [];
  List<Map<String, dynamic>> exams = [];
  List<Map<String, dynamic>> students = [];
  bool _sortStudentsAlphabetically = true;
  final Map<String, int> _studentApiOrder = {};

  String? stageId, subjectId, roomId, examId;
  final Map<int, TextEditingController> grades = {};
  // Last values known to be stored by EMIS; used to distinguish an intentional
  // deletion from a field that was simply left empty.
  final Map<int, String> _originalGrades = {};
  final Map<int, GlobalKey> _voiceFieldKeys = {};

  bool loading = true;
  bool loadingStudents = false;
  bool saving = false;
  String? error;

  bool _speechListening = false;
  String? _speechError;
  int? _activeVoiceSessionId;
  int? _activeStudentVoiceId;
  int _nextVoiceSessionId = 0;
  bool _speechStopRequested = false;
  bool _micPointerDown = false;
  bool _voiceArrowPointerDown = false;
  bool _voiceSequentialMode = AppCore.voiceSequentialAutoStart;
  int _sequentialVoiceIndex = 0;
  StreamSubscription<Map<String, dynamic>>? _googleSpeechSubscription;
  bool _legacySpeechInitialized = false;
  bool _legacySpeechAvailable = false;
  Timer? _legacyFinalizationTimer;
  Timer? _googleFinalizationTimer;
  Timer? _liveTimer;
  final GlobalKey<EmisLiveSyncState> _liveSyncKey = GlobalKey<EmisLiveSyncState>();

  GlobalKey _voiceFieldKey(int studentId) =>
      _voiceFieldKeys.putIfAbsent(studentId, GlobalKey.new);

  Map<String, String> get h => {
        'Authorization': widget.token.toLowerCase().startsWith('bearer ')
            ? widget.token
            : 'Bearer ${widget.token}',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    _voiceSequentialMode = AppCore.voiceInputEnabled && AppCore.voiceSequentialAutoStart;
    _googleSpeechSubscription = GoogleSpeechService.events.listen(_handleGoogleSpeechEvent);
    _liveTimer = Timer.periodic(const Duration(milliseconds: 700), (_) => _pushLive());
    _loadStages();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    unawaited(GoogleSpeechService.cancelListening());
    _googleSpeechSubscription?.cancel();
    _legacyFinalizationTimer?.cancel();
    _googleFinalizationTimer?.cancel();
    unawaited(LegacySpeechService.cancel());
    for (final c in grades.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _pushLive() {
    if (saving) return;
    _liveSyncKey.currentState?.pushValues(_liveValues());
  }

  Map<String, String> _liveValues() => {
        for (final entry in grades.entries) '${entry.key}': entry.value.text,
        'stageId': stageId ?? '',
        'subjectId': subjectId ?? '',
        'classRoomId': roomId ?? '',
        'examId': examId ?? '',
      };

  dynamic _unwrap(dynamic d) {
    if (d is Map && d.containsKey('data') && d['data'] != null) {
      return d['data'];
    }
    return d;
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    final raw = _unwrap(value);
    if (raw is! List) return <Map<String, dynamic>>[];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item)
    ];
  }

  Future<dynamic> _getJson(String endpoint) async {
    final response = await http.get(
      Uri.parse('https://emis.moedu.gov.iq/api$endpoint'),
      headers: h,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'HTTP ${response.statusCode}: ${utf8.decode(response.bodyBytes)}',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<List<Map<String, dynamic>>> _getList(String endpoint) async =>
      _maps(await _getJson(endpoint));

  String _id(Map<String, dynamic> x) =>
      '${x['id'] ?? x['examId'] ?? x['value'] ?? x['stageId'] ?? ''}';

  String _label(Map<String, dynamic> x) =>
      '${x['displayName'] ?? x['label'] ?? x['name'] ?? x['text'] ?? x['value'] ?? x['id'] ?? ''}';

  bool _bool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    return '$v'.toLowerCase() == 'true' || '$v' == '1';
  }

  Future<void> _loadStages() async {
    try {
      final result =
          await _getList('/selectoption/getschoolstages/${widget.schoolId}');
      if (!mounted) return;
      setState(() {
        stages = result.where((x) => widget.teachingAssignments.any((a) => '${a['stageId']}' == _id(x))).toList();
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '$e';
      });
    }
  }

  Future<void> _stageChanged(String? value) async {
    if (value == null) return;
    _clearStudents();
    setState(() {
      stageId = value;
      subjectId = null;
      roomId = null;
      examId = null;
      subjects = [];
      rooms = [];
      exams = [];
      students = [];
      error = null;
    });
    try {
      final result = await _getList(
        '/subject/getsubjectsselect?stageId=$value&schoolId=${widget.schoolId}',
      );
      if (mounted) setState(() => subjects = result.where((x) => widget.teachingAssignments.any((a) => '${a['stageId']}' == stageId && '${a['subjectId']}' == _id(x))).toList());
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _subjectChanged(String? value) async {
    if (value == null || stageId == null) return;
    _clearStudents();
    setState(() {
      subjectId = value;
      roomId = null;
      examId = null;
      rooms = [];
      exams = [];
      students = [];
      error = null;
    });
    try {
      final roomResult = await _getList(
        '/selectoption/getClassRooms?stageId=$stageId&schoolId=${widget.schoolId}&subjectId=$value',
      );
      final raw = await _getJson(
        '/examscore/getexamsformarks?schoolId=${widget.schoolId}&stageId=$stageId&subjectId=$value',
      );
      final rawExams = raw is Map ? raw['exams'] : raw;
      final examResult = _maps(rawExams);
      if (!mounted) return;
      setState(() {
        rooms = roomResult.where((x) => widget.teachingAssignments.any((a) => '${a['stageId']}' == stageId && '${a['subjectId']}' == value && '${a['classRoomId']}' == _id(x))).toList();
        exams = examResult;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _roomChanged(String? value) async {
    _clearStudents();
    setState(() {
      roomId = value;
      students = [];
      error = null;
    });
    if (examId != null) {
      await _loadStudents();
    }
  }

  Future<void> _examChanged(String? value) async {
    _clearStudents();
    setState(() {
      examId = value;
      students = [];
      error = null;
    });
    await _loadStudents();
  }

  Map<String, dynamic>? _findExamById(String id) {
    final target = id.trim();
    for (final exam in exams) {
      for (final key in const ['id', 'examId', 'exam_id', 'value']) {
        final val = exam[key];
        if (val != null && '$val'.trim() == target) {
          return exam;
        }
      }
    }
    return null;
  }

  Set<String> _examIdCandidatesForExam(Map<String, dynamic>? examObj, String fallbackId) {
    final candidates = <String>{fallbackId.trim()};
    if (examObj != null) {
      for (final key in const ['id', 'examId', 'exam_id', 'value']) {
        final value = examObj[key];
        if (value != null && '$value'.trim().isNotEmpty) {
          candidates.add('$value'.trim());
        }
      }
    }
    return candidates;
  }

  Set<String> _examIdCandidates(String selectedExamId) {
    return _examIdCandidatesForExam(_findExamById(selectedExamId), selectedExamId);
  }

  Map<dynamic, dynamic>? _findStudentGradeForExam(
    Map<String, dynamic> student,
    Set<String> selectedExamIds,
  ) {
    final rawGrades =
        student['grades'] ?? student['examScores'] ?? student['examGrades'] ?? student['scores'] ?? student['marks'];

    if (rawGrades is List) {
      for (final item in rawGrades) {
        if (item is! Map) continue;
        final gradeMap = Map<dynamic, dynamic>.from(item);
        final rawExamId = gradeMap['examId'] ??
            gradeMap['exam_id'] ?? gradeMap['examID'] ??
            gradeMap['exam'] ?? gradeMap['markId'] ?? gradeMap['id'];
        if (rawExamId != null && selectedExamIds.contains('$rawExamId'.trim())) {
          return gradeMap;
        }
      }
    } else if (rawGrades is Map) {
      for (final id in selectedExamIds) {
        if (rawGrades.containsKey(id)) {
          final val = rawGrades[id];
          if (val is Map) return Map<dynamic, dynamic>.from(val);
          return {'grade': val};
        }
      }
    }
    return null;
  }

  /// يستخرج درجة الطالب للامتحان المحدد، وإذا كان الامتحان عبارة عن معدل محسوب
  /// (AVERAGE أو MAX) غير مخزن صراحةً في استجابة الخادم، يقوم بحسابه تلقائياً
  /// من الامتحانات التي يعتمد عليها (dependsOn) تماماً كما يفعل موقع EMIS.
  num? _resolveStudentGradeNumber(
    Map<String, dynamic> student,
    String targetExamId, [
    Set<String>? visited,
  ]) {
    visited ??= <String>{};
    final normalizedId = targetExamId.trim();
    if (visited.contains(normalizedId)) return null;
    visited.add(normalizedId);

    final examMeta = _findExamById(normalizedId);
    final candidateIds = _examIdCandidatesForExam(examMeta, normalizedId);

    // 1. البحث عن قيمة مخزنة صراحةً في بيانات الطالب القادمة من الخادم
    final directMatch = _findStudentGradeForExam(student, candidateIds);
    if (directMatch != null) {
      final rawVal = directMatch['grade'] ??
          directMatch['score'] ??
          directMatch['mark'] ??
          directMatch['markScore'] ??
          directMatch['scoreValue'] ??
          directMatch['value'];
      if (rawVal != null) {
        final parsed = num.tryParse(_normalizeNumber('$rawVal'));
        if (parsed != null) return parsed;
      }
    }

    // 2. إذا لم توجد درجة مخزنة، نتحقق مما إذا كان الحقل معدلاً يُحسب عبر معادلة (AVERAGE / MAX)
    if (examMeta == null) return null;
    final typeObj = examMeta['type'];
    if (typeObj is Map) {
      final operation = '${typeObj['operation'] ?? ''}'.toUpperCase().trim();
      final dependsOn = typeObj['dependsOn'];

      if (dependsOn is List && dependsOn.isNotEmpty) {
        final depValues = <num>[];
        for (final depId in dependsOn) {
          final val = _resolveStudentGradeNumber(
            student,
            '$depId',
            Set<String>.from(visited),
          );
          if (val != null) {
            depValues.add(val);
          }
        }

        if (operation == 'AVERAGE') {
          // في نظام EMIS، يظهر المعدل عند اكتمال الدرجات المعتمدة عليها
          if (depValues.length == dependsOn.length && depValues.isNotEmpty) {
            final sum = depValues.fold<num>(0, (a, b) => a + b);
            return (sum / depValues.length).round();
          }
        } else if (operation == 'MAX') {
          if (depValues.isNotEmpty) {
            return depValues.reduce((a, b) => a > b ? a : b);
          }
        }
      }
    }

    return null;
  }

  Map<String, dynamic>? get _currentExam {
    for (final exam in exams) {
      if (_id(exam) == examId) return exam;
    }
    return null;
  }

  String _normalizeExamLabel(String value) => value
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .toLowerCase();

  bool get _isCalculatedExam {
    final exam = _currentExam;
    if (exam == null) return false;
    // EMIS marks calculated exam rows explicitly (AVERAGE / MAX with dependsOn).
    // Trust that metadata rather than relying only on localized display labels.
    final calculation = exam['type'];
    if (calculation is Map && '${calculation['operation'] ?? ''}'.trim().isNotEmpty) {
      return true;
    }
    final label = _normalizeExamLabel(_label(exam));
    const calculatedLabels = [
      'معدل النصف الأول',
      'معدل النصف الثاني',
      'معدل السعي السنوي',
      'نتيجة امتحان نهائية',
      'الدرجة النهائية',
    ];
    return calculatedLabels.any((value) => label.contains(_normalizeExamLabel(value))) ||
        label.contains('finalresult') || label.contains('finalgrade') ||
        label.contains('firstsemesteraverage') || label.contains('secondsemesteraverage') ||
        label.contains('annualcourseworkaverage');
  }

  void _clearStudents() {
    for (final c in grades.values) {
      c.dispose();
    }
    grades.clear();
    _originalGrades.clear();
  }

  String _studentName(Map<String, dynamic> student) =>
      '${student['name'] ?? student['studentName'] ?? student['fullName'] ?? student['displayName'] ?? 'طالب'}'.trim();

  String _alphabeticalKey(String value) {
    var key = value.trim().toLowerCase();
    // Normalize common Arabic letter variants so names sort more naturally.
    const replacements = {
      'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا',
      'ى': 'ي', 'ؤ': 'و', 'ئ': 'ي',
    };
    replacements.forEach((from, to) => key = key.replaceAll(from, to));
    key = key.replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '');
    return key;
  }

  String _studentIdentity(Map<String, dynamic> student) =>
      '${student['id'] ?? student['studentId'] ?? ''}';

  void _rememberStudentOrder(List<Map<String, dynamic>> roster) {
    _studentApiOrder.clear();
    for (var i = 0; i < roster.length; i++) {
      _studentApiOrder[_studentIdentity(roster[i])] = i;
    }
  }

  void _applyStudentSorting() {
    if (_sortStudentsAlphabetically) {
      students.sort((a, b) => _alphabeticalKey(_studentName(a))
          .compareTo(_alphabeticalKey(_studentName(b))));
    } else {
      students.sort((a, b) =>
          (_studentApiOrder[_studentIdentity(a)] ?? 0)
              .compareTo(_studentApiOrder[_studentIdentity(b)] ?? 0));
    }
  }

  void _setAlphabeticalSorting(bool enabled) {
    setState(() {
      _sortStudentsAlphabetically = enabled;
      _applyStudentSorting();
    });
  }

  Widget _studentSortingControl(bool isDark) => Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242424) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _sortStudentsAlphabetically,
          onChanged: _setAlphabeticalSorting,
          title: const Text('ترتيب أسماء الطلاب أبجديًا',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('يبدأ الترتيب مفعّلًا افتراضيًا'),
          secondary: const Icon(Icons.sort_by_alpha_rounded),
        ),
      );

  Future<void> _loadStudents() async {
    if (stageId == null || subjectId == null || examId == null) return;
    setState(() {
      loadingStudents = true;
      error = null;
    });
    try {
      var endpoint =
          '/examscore/getstudentswithgrades?schoolId=${widget.schoolId}&stageId=$stageId&subjectId=$subjectId';
      if (roomId != null && roomId!.isNotEmpty) {
        endpoint += '&classroomId=$roomId';
      }
      final result = await _getList(endpoint);
      _clearStudents();

      for (final student in result) {
        final id = int.tryParse('${student['id']}');
        if (id == null) continue;
        // قراءة الدرجة المخزنة أو احتساب المعدل التلقائي (في حال كان الامتحان المختار معدلاً)
        final existingValue = _resolveStudentGradeNumber(student, examId!);
        final initialText = existingValue == null ? '' : '$existingValue';
        _originalGrades[id] = initialText;
        grades[id] = TextEditingController(text: initialText);
      }

      if (mounted) {
        setState(() {
          students = result;
          _rememberStudentOrder(result);
          _applyStudentSorting();
          loadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loadingStudents = false;
          error = '$e';
        });
      }
    }
  }

  void _showVoiceMessage(String message) {
    if (!mounted) return;
    setState(() => _speechError = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  bool get _voiceAvailableBySetting => AppCore.voiceInputEnabled;

  Future<bool> _ensureMicrophoneAccess() async {
    if (!_voiceAvailableBySetting) {
      _showVoiceMessage('الميكروفون مغلق من الإعدادات.');
      return false;
    }
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final requested = await Permission.microphone.request();
    if (requested.isGranted) return true;
    _showVoiceMessage('لم يتم منح صلاحية الميكروفون.');
    return false;
  }

  bool get _usingLegacyVoice => AppCore.voiceRecognitionEngine == 'legacy';

  Future<bool> _initLegacySpeech() async {
    if (_legacySpeechInitialized) return _legacySpeechAvailable;
    _legacySpeechAvailable = await LegacySpeechService.initialize(
      onStatus: (status) {
        if (!mounted || !_usingLegacyVoice) return;
        final listening = status == 'listening';
        setState(() => _speechListening = listening);
        if (!listening && (_activeVoiceSessionId != null || _speechStopRequested)) {
          _scheduleLegacyFinalization();
        }
      },
      onError: (SpeechRecognitionError error) {
        if (!mounted || !_usingLegacyVoice) return;
        setState(() {
          _speechListening = false;
          _speechError = error.errorMsg;
        });
        _scheduleLegacyFinalization();
      },
    );
    _legacySpeechInitialized = true;
    return _legacySpeechAvailable;
  }

  void _scheduleLegacyFinalization() {
    _legacyFinalizationTimer?.cancel();
    _legacyFinalizationTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || !_usingLegacyVoice) return;
      _finishLegacyVoiceSessionAndStartPending();
    });
  }

  Future<void> _finishLegacyVoiceSessionAndStartPending() async {
    _legacyFinalizationTimer?.cancel();
    _legacyFinalizationTimer = null;
    _speechStopRequested = false;
    _activeVoiceSessionId = null;
    _activeStudentVoiceId = null;
    if (mounted) setState(() => _speechListening = false);
  }

  String _cleanNumericSpeech(String value) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const easternArabicIndic = '۰۱۲۳۴۵۶۷۸۹';
    const wordDigits = <String, String>{
      'صفر': '0', 'واحد': '1', 'واحدة': '1', 'اثنان': '2', 'اثنين': '2',
      'ثلاثة': '3', 'ثلاث': '3', 'أربعة': '4', 'اربعة': '4', 'خمسة': '5',
      'خمس': '5', 'ستة': '6', 'ست': '6', 'سبعة': '7', 'سبع': '7',
      'ثمانية': '8', 'ثماني': '8', 'تسعة': '9', 'تسع': '9', 'عشرة': '10',
    };
    final normalized = value.replaceAll('،', ' ').replaceAll(',', ' ');
    final words = normalized.split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
    final out = StringBuffer();
    for (final raw in words) {
      final word = raw.replaceAll(RegExp(r'[.\-_/]'), '');
      if (word.isEmpty) continue;
      final mapped = wordDigits[word.toLowerCase()];
      if (mapped != null) {
        out.write(mapped);
        continue;
      }
      for (final rune in word.runes) {
        final ch = String.fromCharCode(rune);
        final a = arabicIndic.indexOf(ch);
        if (a >= 0) {
          out.write(a);
          continue;
        }
        final e = easternArabicIndic.indexOf(ch);
        if (e >= 0) {
          out.write(e);
          continue;
        }
        if (RegExp(r'[0-9]').hasMatch(ch)) out.write(ch);
      }
    }
    return out.toString();
  }

  Future<void> _startLegacyVoiceSession(int studentId) async {
    if (!mounted || saving) return;
    final available = await _initLegacySpeech();
    if (!available || !mounted) return;

    final sessionId = ++_nextVoiceSessionId;
    _activeVoiceSessionId = sessionId;
    _activeStudentVoiceId = studentId;
    _scrollGradeFieldIntoView(studentId);
    _speechStopRequested = false;
    if (mounted) {
      setState(() {
        _speechError = null;
        _speechListening = true;
      });
    }

    try {
      await LegacySpeechService.listen(
        onResult: (dynamic result) {
          if (!mounted || !_usingLegacyVoice || _activeVoiceSessionId != sessionId) return;
          final raw = '${result.recognizedWords ?? ''}'.trim();
          if (raw.isEmpty) return;
          final text = _cleanNumericSpeech(raw);
          if (text.isEmpty) return;
          final controller = grades[studentId];
          if (controller == null) return;
          controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          _pushLive();
          if (result.finalResult == true) {
            _finishLegacyVoiceSessionAndStartPending();
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _speechError = '$e');
    }
  }

  void _handleGoogleSpeechEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final sessionId = int.tryParse('${event['sessionId'] ?? ''}');
    if (sessionId == null || sessionId != _activeVoiceSessionId) return;

    final type = '${event['type'] ?? ''}';
    if (type == 'listening' || type == 'ready' || type == 'begin' || type == 'partial') {
      if (!_speechListening) setState(() => _speechListening = true);
    }

    if (type == 'partial' || type == 'result') {
      final alternates = (event['alternates'] is List)
          ? (event['alternates'] as List).map((e) => '$e').toList()
          : <String>[];
      final candidates = <String>[
        '${event['text'] ?? ''}',
        ...alternates,
      ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      String text = '';
      for (final raw in candidates) {
        final cleaned = _cleanNumericSpeech(raw);
        if (cleaned.isNotEmpty) {
          text = cleaned;
          break;
        }
      }

      if (text.isNotEmpty) {
        final targetStudentId = _activeStudentVoiceId ??
            ((_sequentialVoiceIndex >= 0 && _sequentialVoiceIndex < grades.keys.length)
                ? grades.keys.elementAt(_sequentialVoiceIndex)
                : null);
        if (targetStudentId != null) {
          final controller = grades[targetStudentId];
          if (controller != null) {
            controller.value = TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            );
            _pushLive();
          }
        }
      }
    }

    if (type == 'result' || type == 'stopped') {
      if (mounted) setState(() => _speechListening = false);
    }
  }

  Future<void> _startGoogleVoiceSession(int studentId) async {
    final info = await GoogleSpeechService.getInfo();
    if (info['available'] != true) {
      _showVoiceMessage('خدمة Google للتعرف على الكلام غير متوفرة.');
      return;
    }
    final sessionId = ++_nextVoiceSessionId;
    _activeVoiceSessionId = sessionId;
    _activeStudentVoiceId = studentId;
    _scrollGradeFieldIntoView(studentId);
    _speechStopRequested = false;
    if (mounted) {
      setState(() {
        _speechError = null;
        _speechListening = true;
      });
    }
    await GoogleSpeechService.startListening(sessionId: sessionId, locale: 'ar-IQ');
  }

  Future<void> _toggleVoiceInput(int studentId) async {
    if (saving) return;
    if (!await _ensureMicrophoneAccess()) return;
    if (_usingLegacyVoice) {
      if (_activeVoiceSessionId != null && _activeStudentVoiceId == studentId) {
        await LegacySpeechService.stop();
        setState(() {
          _speechListening = false;
          _activeVoiceSessionId = null;
          _activeStudentVoiceId = null;
        });
      } else {
        if (_activeVoiceSessionId != null) await LegacySpeechService.stop();
        await _startLegacyVoiceSession(studentId);
      }
      return;
    }
    if (_activeVoiceSessionId != null && _activeStudentVoiceId == studentId) {
      await GoogleSpeechService.stopListening();
      setState(() {
        _speechListening = false;
        _activeVoiceSessionId = null;
        _activeStudentVoiceId = null;
      });
    } else {
      if (_activeVoiceSessionId != null) await GoogleSpeechService.stopListening();
      await _startGoogleVoiceSession(studentId);
    }
  }

  void _scrollGradeFieldIntoView(int studentId) {
    if (!mounted) return;
    final fieldKey = _voiceFieldKeys[studentId];
    final context = fieldKey?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.16,
      );
    }
  }

  void _stopVoiceFromPointer() {
    if (_voiceArrowPointerDown || _micPointerDown) {
      _voiceArrowPointerDown = false;
      _micPointerDown = false;
      return;
    }
    if (_activeVoiceSessionId != null) {
      _activeVoiceSessionId = null;
      _activeStudentVoiceId = null;
      setState(() => _speechListening = false);
      if (_usingLegacyVoice) {
        unawaited(LegacySpeechService.stop());
      } else {
        unawaited(GoogleSpeechService.stopListening());
      }
    }
  }

  void _markMicPointerDown() {
    _micPointerDown = true;
    Future<void>.microtask(() => _micPointerDown = false);
  }

  void _markVoiceArrowPointerDown() {
    _voiceArrowPointerDown = true;
    Future<void>.microtask(() => _voiceArrowPointerDown = false);
  }

  Future<void> _toggleSequentialModeFromButton() async {
    setState(() => _voiceSequentialMode = !_voiceSequentialMode);
    if (_voiceSequentialMode && students.isNotEmpty) {
      _sequentialVoiceIndex = 0;
      final firstId = int.tryParse('${students.first['id']}');
      if (firstId != null) {
        await _toggleVoiceInput(firstId);
      }
    } else {
      _stopSequentialVoiceMode();
    }
  }

  void _stopSequentialVoiceMode() {
    if (!_voiceSequentialMode) return;
    setState(() => _voiceSequentialMode = false);
    if (_activeVoiceSessionId != null) {
      _activeVoiceSessionId = null;
      _activeStudentVoiceId = null;
      setState(() => _speechListening = false);
      if (_usingLegacyVoice) {
        unawaited(LegacySpeechService.stop());
      } else {
        unawaited(GoogleSpeechService.stopListening());
      }
    }
  }

  Future<void> _advanceSequentialVoice() async {
    if (!_voiceSequentialMode || students.isEmpty) return;
    if (_sequentialVoiceIndex < students.length - 1) {
      setState(() => _sequentialVoiceIndex++);
      final nextId = int.tryParse('${students[_sequentialVoiceIndex]['id']}');
      if (nextId != null) {
        _scrollGradeFieldIntoView(nextId);
        await _toggleVoiceInput(nextId);
      }
    }
  }

  Future<void> _retreatSequentialVoice() async {
    if (!_voiceSequentialMode || students.isEmpty) return;
    if (_sequentialVoiceIndex > 0) {
      setState(() => _sequentialVoiceIndex--);
      final prevId = int.tryParse('${students[_sequentialVoiceIndex]['id']}');
      if (prevId != null) {
        _scrollGradeFieldIntoView(prevId);
        await _toggleVoiceInput(prevId);
      }
    }
  }

  Widget _sequentialVoiceControl() {
    final enabled = _voiceSequentialMode;
    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SwitchListTile(
        secondary: Icon(
          enabled ? Icons.keyboard_double_arrow_down_rounded : Icons.keyboard_arrow_down_rounded,
          color: enabled ? Colors.green : Colors.grey,
          size: 32,
        ),
        title: const Text('التنقل الصوتي بين حقول الدرجات', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('عند التفعيل يظهر سهمان للتنقل الصوتي السريع بين درجات الطلاب.', textDirection: TextDirection.rtl),
        value: enabled,
        activeColor: Colors.green,
        onChanged: (_) => _toggleSequentialModeFromButton(),
      ),
    );
  }

  Widget _fixedSequentialArrow() {
    if (!_voiceSequentialMode || students.isEmpty) return const SizedBox.shrink();
    final atFirst = _sequentialVoiceIndex <= 0;
    final atLast = _sequentialVoiceIndex >= students.length - 1;

    Widget arrowButton({required IconData icon, required VoidCallback? onTap, required bool disabled, required String tooltip}) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: disabled ? null : onTap,
            child: SizedBox(
              width: 58,
              height: 68,
              child: Icon(icon, size: 54, color: disabled ? Colors.grey.shade400 : Colors.green.shade700),
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: 0,
      top: MediaQuery.of(context).size.height * 0.38,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _markVoiceArrowPointerDown(),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 62,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(AppCore.voiceArrowOpacity),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
              boxShadow: const [BoxShadow(blurRadius: 9, offset: Offset(1, 2), color: Colors.black26)],
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                arrowButton(icon: Icons.keyboard_arrow_up_rounded, onTap: _retreatSequentialVoice, disabled: atFirst, tooltip: 'السابق'),
                Container(width: 36, height: 2, color: Colors.green.shade200),
                arrowButton(icon: Icons.keyboard_arrow_down_rounded, onTap: _advanceSequentialVoice, disabled: atLast, tooltip: 'التالي'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _normalizeNumber(String value) => value
      .replaceAll('٠','0').replaceAll('١','1').replaceAll('٢','2').replaceAll('٣','3').replaceAll('٤','4')
      .replaceAll('٥','5').replaceAll('٦','6').replaceAll('٧','7').replaceAll('٨','8').replaceAll('٩','9')
      .replaceAll(' ', '').replaceAll('،', '.').replaceAll(',', '.').replaceAll('٫', '.');

  Future<http.Response> _postGrade(
    int studentId,
    int examNumber,
    dynamic grade,
  ) async {
    return http.post(
      Uri.parse('https://emis.moedu.gov.iq/api/examscore/updateexamgrade'),
      headers: h,
      body: jsonEncode({
        'studentId': studentId,
        'examId': examNumber,
        'grade': grade,
      }),
    );
  }

  Future<void> _saveGrades() async {
    final exam = _currentExam;
    if (exam == null) return;
    if (_isCalculatedExam) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا المعدل يُحتسب في EMIS ولا يمكن إدخال درجته يدويًا.')),
      );
      return;
    }

    final examNumber = int.tryParse(_id(exam));
    if (examNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('معرف الامتحان غير صالح في بيانات EMIS'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => saving = true);
    int ok = 0, failed = 0, unchanged = 0;
    final failures = <String>[];
    try {
      for (final student in students) {
        final studentId = int.tryParse('${student['id']}');
        if (studentId == null) continue;
        final raw = grades[studentId]?.text.trim() ?? '';
        final original = (_originalGrades[studentId] ?? '').trim();

        // Do not resend untouched values. An empty field is a deletion only
        // when EMIS previously returned a non-empty value for this student.
        if (raw == original) {
          unchanged++;
          continue;
        }
        if (raw.isEmpty && original.isEmpty) {
          unchanged++;
          continue;
        }

        dynamic parsed;
        if (raw.isNotEmpty) {
          final special = raw.trim();
          if (special == 'م' || special == 'غ') {
            // EMIS special exam marks: م = deferred, غ = absent.
            parsed = special;
          } else {
            final numeric = int.tryParse(_normalizeNumber(raw));
            final max = int.tryParse('${exam['maxAllowedGrade'] ?? exam['max'] ?? 100}') ?? 100;
            if (numeric == null || numeric < 0 || numeric > max) {
              failed++;
              failures.add('الطالب $studentId: الدرجة "$raw" غير صالحة؛ أدخل رقمًا من 0 إلى $max أو م أو غ');
              continue;
            }
            parsed = numeric;
          }
        }

        try {
          var response = await _postGrade(studentId, examNumber, parsed);
          var body = utf8.decode(response.bodyBytes).trim();
          if (response.statusCode == 400 && body.toLowerCase().contains('exam not found')) {
            final alternatives = <int>{};
            for (final k in const ['examId', 'id', 'value']) {
              final n = int.tryParse('${exam[k] ?? ''}');
              if (n != null) alternatives.add(n);
            }
            for (final alt in alternatives) {
              if (alt == examNumber) continue;
              response = await _postGrade(studentId, alt, parsed);
              body = utf8.decode(response.bodyBytes).trim();
              if (response.statusCode >= 200 && response.statusCode < 300) break;
            }
          }
          if (response.statusCode >= 200 && response.statusCode < 300) {
            ok++;
            // Keep the edited value visible after save and mark it as the
            // latest value submitted, instead of clearing every TextField.
            _originalGrades[studentId] = raw;
          } else {
            failed++;
            failures.add('الطالب $studentId: HTTP ${response.statusCode}${body.isEmpty ? '' : ' — $body'}');
          }
        } catch (e) {
          failed++;
          failures.add('الطالب $studentId: $e');
        }
      }
      if (!mounted) return;
      setState(() => saving = false);
      final details = failures.isEmpty ? '' : '\n${failures.take(3).join('\n')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال $ok تغيير${failed == 0 ? '' : ' — فشل $failed'}${ok == 0 && unchanged > 0 ? ' — لا توجد تغييرات جديدة' : ''}$details'),
          backgroundColor: failed == 0 ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 8),
        ),
      );
      // Refresh server-side values so calculated averages supplied by EMIS are
      // read from its response after the source grades have been saved.
      if (ok > 0 && mounted) {
        await _refreshGradesFromEmis();
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _refreshGradesFromEmis() async {
    if (stageId == null || subjectId == null || examId == null) return;
    try {
      var endpoint = '/examscore/getstudentswithgrades?schoolId=${widget.schoolId}&stageId=$stageId&subjectId=$subjectId';
      if (roomId != null && roomId!.isNotEmpty) endpoint += '&classroomId=$roomId';
      final result = await _getList(endpoint);
      if (!mounted) return;
      setState(() {
        students = result;
        _rememberStudentOrder(result);
        _applyStudentSorting();
        for (final student in result) {
          final id = int.tryParse('${student['id']}');
          if (id == null || !grades.containsKey(id)) continue;
          final value = _resolveStudentGradeNumber(student, examId!);
          // If server omits an empty/deleted grade, reflect that. Otherwise
          // update with the authoritative value, including calculated exams.
          if (value != null) {
            grades[id]!.text = '$value';
            _originalGrades[id] = '$value';
          } else if ((_originalGrades[id] ?? '').isEmpty) {
            grades[id]!.text = '';
          }
        }
      });
    } catch (_) {
      // Keep the values already shown if a post-save refresh temporarily fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final exam = _currentExam;
    final max =
        int.tryParse('${exam?['maxAllowedGrade'] ?? exam?['max'] ?? 100}') ??
            100;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dropdownTextColor = isDark ? Colors.white : Colors.black87;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _stopVoiceFromPointer(),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text(
            'إدخال الدرجات',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF4A90E2)],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: loading || saving || loadingStudents || students.isEmpty || examId == null || _isCalculatedExam
                        ? null
                        : _saveGrades,
                    icon: saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_isCalculatedExam ? Icons.lock_outline_rounded : Icons.save_rounded),
                    label: Text(
                      saving ? 'جاري حفظ الدرجات...' : (_isCalculatedExam ? 'معدل مستورد من EMIS' : 'حفظ الدرجات'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
        body: Stack(
          children: [
            loading
                ? const Center(child: CircularProgressIndicator())
                : Directionality(
                    textDirection: TextDirection.rtl,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                      children: [
                        _headerCard(),
                        const SizedBox(height: 14),
                        _sequentialVoiceControl(),
                        Card(
                          elevation: 0,
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _drop('الصف الدراسي', stageId, stages, _stageChanged, isDark, dropdownTextColor),
                                const SizedBox(height: 12),
                                _drop('المادة', subjectId, subjects, _subjectChanged, isDark, dropdownTextColor),
                                const SizedBox(height: 12),
                                _drop('الشعبة', roomId, rooms, _roomChanged, isDark, dropdownTextColor),
                                const SizedBox(height: 12),
                                _drop(
                                  'فصل الدرجات / الامتحان',
                                  examId,
                                  exams,
                                  _examChanged,
                                  isDark,
                                  dropdownTextColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          _messageCard(error!, Colors.red),
                        ],
                        if (exam != null) ...[
                          const SizedBox(height: 16),
                          _examCard(exam, max, isDark),
                        ],
                        if (loadingStudents) ...[
                          const SizedBox(height: 24),
                          const Center(child: CircularProgressIndicator()),
                        ] else if (students.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text('الطلاب (${students.length})',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          _studentSortingControl(isDark),
                          ...students.map((student) => _studentCard(student, max, isDark)),
                        ],
                      ],
                    ),
                  ),
            _fixedSequentialArrow(),
            if (!loading)
              Positioned(
                left: 0,
                bottom: 0,
                child: EmisLiveSync(
                  key: _liveSyncKey,
                  url:
                      'https://emis.moedu.gov.iq/centers/schools/${widget.schoolId}/marks',
                  mode: 'edit',
                  entity: 'examscore',
                  token: widget.token,
                  aliases: {
                    'stageId': ['stageId', 'الصف الدراسي'],
                    'subjectId': ['subjectId', 'المادة'],
                    'classRoomId': ['classRoomId', 'الشعبة'],
                    'examId': ['examId', 'فصل الدرجات'],
                  },
                  onSnapshot: (values) {
                    if (saving) return;
                    for (final entry in values.entries) {
                      final studentId = int.tryParse(entry.key);
                      if (studentId != null && grades.containsKey(studentId)) {
                        final controller = grades[studentId];
                        if (controller != null && controller.text != entry.value) {
                          controller.value = TextEditingValue(
                            text: entry.value,
                            selection: TextSelection.collapsed(offset: entry.value.length),
                          );
                        }
                      }
                    }
                    if (mounted) setState(() {});
                  },
                  onStatus: (v) {},
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _headerCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF4A90E2)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: Colors.white24,
              child: Icon(
                Icons.edit_note_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إدخال الدرجات',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'قراءة مباشرة من EMIS وحفظ الدرجات',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _drop(
    String label,
    String? value,
    List<Map<String, dynamic>> data,
    ValueChanged<String?> onChanged,
    bool isDark,
    Color textColor,
  ) =>
      DropdownButtonFormField<String>(
        value: data.any((x) => _id(x) == value) ? value : null,
        isExpanded: true,
        dropdownColor: isDark ? const Color(0xFF252525) : Colors.white,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          filled: true,
          fillColor: isDark ? Colors.black12 : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE1E6EF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE1E6EF)),
          ),
        ),
        items: data
            .map(
              (x) => DropdownMenuItem<String>(
                value: _id(x),
                child: Text(
                  _label(x),
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
            )
            .where((x) => x.value != null && x.value!.isNotEmpty)
            .toList(),
        onChanged: data.isEmpty ? null : onChanged,
      );

  Widget _examCard(Map<String, dynamic> exam, int max, bool isDark) {
    final calculated = _isCalculatedExam;
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(calculated ? Icons.calculate_rounded : Icons.assignment_rounded,
                color: calculated ? Colors.teal : const Color(0xFF3949AB), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_label(exam), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(
                    calculated
                        ? 'معدل محسوب من نظام EMIS — للعرض فقط، تُستورد قيمه من النظام.'
                        : 'الدرجة القصوى: $max  •  الطلاب: ${students.length}',
                    style: TextStyle(color: calculated ? Colors.teal : Colors.grey, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _studentCard(Map<String, dynamic> student, int max, bool isDark) {
    final id = int.tryParse('${student['id']}') ?? -1;
    final name =
        '${student['name'] ?? student['fullName'] ?? student['studentName'] ?? ''}';
    
    // التحقق المخصص لجعل أيقونة الميكروفون الخاصة بهذا الطالب تتحول للون الأحمر حصراً عند تفعيله
    final isThisStudentActiveMic = _speechListening && _activeStudentVoiceId == id;

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          key: _voiceFieldKey(id),
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF1A237E).withOpacity(.08),
              child: const Icon(Icons.person, color: Color(0xFF3949AB)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'رقم الطالب: ${student['id'] ?? ''}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => _markMicPointerDown(),
                  child: IconButton(
                    tooltip: 'إدخال الدرجة بالصوت',
                    onPressed: _isCalculatedExam ? null : () => _toggleVoiceInput(id),
                    icon: Icon(
                      isThisStudentActiveMic
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                      color: isThisStudentActiveMic
                          ? Colors.red
                          : Colors.grey,
                    ),
                  ),
                ),
                SizedBox(
                  width: 86,
                  child: TextField(
                    enabled: !loadingStudents,
                    readOnly: _isCalculatedExam,
                    controller: grades[id],
                    keyboardType: TextInputType.number,
                    inputFormatters: [const GradeValueInputFormatter()],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    onChanged: (_) => _pushLive(),
                    decoration: InputDecoration(
                      hintText: '',
                      filled: true,
                      fillColor: isDark ? Colors.black26 : const Color(0xFFF7F8FB),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageCard(String text, Color color) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      );
}
