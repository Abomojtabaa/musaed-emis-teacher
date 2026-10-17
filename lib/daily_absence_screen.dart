import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DailyAbsenceScreen extends StatefulWidget {
  final String token;
  final String schoolId;

  const DailyAbsenceScreen({
    super.key,
    required this.token,
    required this.schoolId,
  });

  @override
  State<DailyAbsenceScreen> createState() => _DailyAbsenceScreenState();
}

class _DailyAbsenceScreenState extends State<DailyAbsenceScreen> {
  List<Map<String, dynamic>> stages = [];
  List<Map<String, dynamic>> subjects = [];
  List<Map<String, dynamic>> rooms = [];
  List<Map<String, dynamic>> students = [];

  String? stageId;
  String? subjectId;
  String? roomId;
  int? academicYearId;
  String academicYearLabel = '';
  DateTime selectedDate = DateTime.now();
  int recordId = 0;
  bool loading = true;
  bool loadingStudents = false;
  bool saving = false;
  String? error;

  Map<String, String> get _headers => {
        'Authorization': widget.token.toLowerCase().startsWith('bearer ')
            ? widget.token
            : 'Bearer ${widget.token}',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  String _id(Map<String, dynamic> x) =>
      '${x['value'] ?? x['id'] ?? x['stageId'] ?? x['subjectId'] ?? x['classroomId'] ?? x['classRoomId'] ?? x['classroomID'] ?? x['studentId'] ?? ''}';

  String _label(Map<String, dynamic> x) =>
      '${x['displayName'] ?? x['label'] ?? x['name'] ?? x['text'] ?? x['title'] ?? _id(x)}';

  bool _bool(dynamic value) =>
      value == true || value == 1 || '$value'.toLowerCase() == 'true';

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<dynamic> _getJson(String endpoint) async {
    final response = await http.get(
      Uri.parse('https://emis.moedu.gov.iq/api$endpoint'),
      headers: _headers,
    ).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${utf8.decode(response.bodyBytes)}');
    }
    final body = utf8.decode(response.bodyBytes);
    return body.trim().isEmpty ? <String, dynamic>{} : jsonDecode(body);
  }

  Future<dynamic> _postJson(String endpoint, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('https://emis.moedu.gov.iq/api$endpoint'),
      headers: _headers,
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${utf8.decode(response.bodyBytes)}');
    }
    final body = utf8.decode(response.bodyBytes);
    return body.trim().isEmpty ? <String, dynamic>{} : jsonDecode(body);
  }

  // EMIS APIs لا تستخدم غلاف استجابة واحداً دائماً:
  // بعض القوائم تعود مباشرة، وغيابات الحصص تعود بالشكل
  // { data: { id: ..., data: [ ...students ] } }.
  List<Map<String, dynamic>> _maps(dynamic raw) {
    for (var depth = 0; depth < 5; depth++) {
      if (raw is List) {
        return [
          for (final item in raw)
            if (item is Map) Map<String, dynamic>.from(item),
        ];
      }
      if (raw is Map) {
        if (raw['data'] is List) {
          raw = raw['data'];
          continue;
        }
        if (raw['data'] is Map) {
          raw = raw['data'];
          continue;
        }
        if (raw['items'] is List) {
          raw = raw['items'];
          continue;
        }
        if (raw['results'] is List) {
          raw = raw['results'];
          continue;
        }
      }
      break;
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        _getJson('/selectoption/getschoolstages/${widget.schoolId}'),
        _getJson('/selectoption/getActiveAcademicYear'),
      ]);
      final loadedStages = _maps(results[0]);
      final years = _maps(results[1]);
      if (years.isNotEmpty) {
        academicYearId = int.tryParse('${years.first['value'] ?? years.first['id'] ?? ''}');
        academicYearLabel = '${years.first['displayName'] ?? years.first['label'] ?? ''}';
      }
      if (!mounted) return;
      setState(() {
        stages = loadedStages;
        loading = false;
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
    setState(() {
      stageId = value;
      subjectId = null;
      roomId = null;
      subjects = [];
      rooms = [];
      students = [];
      recordId = 0;
      error = null;
      loadingStudents = true;
    });
    try {
      final result = _maps(await _getJson(
        '/subject/getsubjectsselect?stageId=$value&schoolId=${widget.schoolId}',
      ));
      if (!mounted) return;
      setState(() {
        subjects = result;
        loadingStudents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadingStudents = false;
        error = '$e';
      });
    }
  }

  Future<void> _subjectChanged(String? value) async {
    if (value == null || stageId == null) return;
    setState(() {
      subjectId = value;
      roomId = null;
      rooms = [];
      students = [];
      recordId = 0;
      error = null;
      loadingStudents = true;
    });
    try {
      final result = _maps(await _getJson(
        '/selectoption/getClassRooms?stageId=$stageId&schoolId=${widget.schoolId}&subjectId=$value',
      ));
      if (!mounted) return;
      setState(() {
        rooms = result;
        loadingStudents = false;
        if (result.length == 1) {
          roomId = _id(result.first);
        }
      });
      // If there is only one available classroom, select it automatically.
      // Otherwise wait for the teacher to choose a classroom explicitly.
      if (result.isEmpty || result.length == 1) await _loadStudents();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadingStudents = false;
        error = '$e';
      });
    }
  }

  Future<void> _roomChanged(String? value) async {
    setState(() {
      roomId = value;
      students = [];
      recordId = 0;
      error = null;
    });
    await _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (stageId == null || subjectId == null) return;
    setState(() {
      loadingStudents = true;
      error = null;
    });
    try {
      var endpoint = '/SessionAbsence/GetSessionAbsences'
          '?schoolId=${widget.schoolId}&stageId=$stageId&subjectId=$subjectId';
      if (roomId != null && roomId!.isNotEmpty) {
        endpoint += '&classroomId=$roomId';
      }
      endpoint += '&page=1&rowsPerPage=20&sortBy=id&sortOrder=desc';
      final decoded = await _getJson(endpoint);
      dynamic wrapper = decoded;
      if (decoded is Map && decoded['data'] is Map) {
        wrapper = decoded['data'];
      }
      final parsed = _maps(decoded);
      if (wrapper is Map) {
        recordId = int.tryParse('${wrapper['id'] ?? 0}') ?? 0;
      }
      // If the absence endpoint returns no roster for a class, fall back to
      // the same student list used by the official grade-entry page.
      if (parsed.isEmpty) {
        var studentEndpoint = '/examscore/getstudentswithgrades'
            '?schoolId=${widget.schoolId}&stageId=$stageId&subjectId=$subjectId';
        if (roomId != null && roomId!.isNotEmpty) {
          studentEndpoint += '&classroomId=$roomId';
        }
        final fallback = _maps(await _getJson(studentEndpoint));
        parsed.addAll(fallback.map((s) => {
              'studentId': s['id'],
              'name': s['name'] ?? s['fullName'] ?? '',
              'isAbsent': false,
              'hasLeave': false,
            }));
      }
      if (!mounted) return;
      setState(() {
        students = parsed;
        loadingStudents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadingStudents = false;
        error = '$e';
      });
    }
  }

  void _toggleAbsent(int index, bool value) {
    setState(() => students[index]['isAbsent'] = value);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ar', 'IQ'),
    );
    if (picked == null || !mounted) return;
    setState(() => selectedDate = picked);
  }

  Future<void> _saveAbsences() async {
    if (stageId == null || subjectId == null) {
      _message('اختر الصف والمادة أولاً.');
      return;
    }
    if (rooms.isNotEmpty && (roomId == null || roomId!.isEmpty)) {
      _message('اختر الشعبة قبل تسجيل الغياب.');
      return;
    }
    if (academicYearId == null) {
      _message('تعذر تحديد السنة الدراسية الفعالة من EMIS.');
      return;
    }
    if (students.isEmpty) {
      _message('لا توجد قائمة طلاب لحفظ الغياب.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final payload = <String, dynamic>{
        if (recordId > 0) 'id': recordId,
        'schoolId': int.tryParse(widget.schoolId) ?? widget.schoolId,
        'stageId': int.tryParse(stageId!) ?? stageId,
        'subjectId': int.tryParse(subjectId!) ?? subjectId,
        if (roomId != null && roomId!.isNotEmpty)
          'classroomId': int.tryParse(roomId!) ?? roomId,
        'absenceTaken': true,
        'academicYearId': academicYearId,
        'date': _dateString(selectedDate),
        'studentSessionAbsences': [
          for (final student in students)
            if (_bool(student['isAbsent']))
              {'studentId': int.tryParse('${student['studentId'] ?? student['id']}') ?? student['studentId'] ?? student['id']}
        ],
      };
      await _postJson('/SessionAbsence/AddSessionAbsences', payload);
      await _loadStudents();
      if (!mounted) return;
      _message('تم إرسال بيانات الغياب إلى EMIS.');
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
        _message('تعذر حفظ الغياب: $e');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _selector({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final available = items.map(_id).where((x) => x.isNotEmpty).toSet();
    final safeValue = value != null && available.contains(value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          filled: true,
        ),
        items: items
            .where((x) => _id(x).isNotEmpty)
            .map((x) => DropdownMenuItem<String>(
                  value: _id(x),
                  child: Text(_label(x), overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final absentCount = students.where((s) => _bool(s['isAbsent'])).length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تسجيل الغياب اليومي', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          foregroundColor: Colors.white,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF4A90E2)],
              ),
            ),
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A237E), Color(0xFF267FB5)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('تسجيل غياب الطلبة',
                            style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          academicYearLabel.isEmpty ? 'السنة الدراسية من EMIS' : 'السنة الدراسية: $academicYearLabel',
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_month),
                          label: Text('التاريخ: ${_dateString(selectedDate)}'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _selector(label: 'الصف الدراسي', value: stageId, items: stages, onChanged: _stageChanged),
                  _selector(label: 'المادة', value: subjectId, items: subjects, onChanged: _subjectChanged),
                  if (rooms.isNotEmpty)
                    _selector(label: 'الشعبة', value: roomId, items: rooms, onChanged: _roomChanged),
                  if (error != null) ...[
                    const SizedBox(height: 6),
                    Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  ],
                  if (loadingStudents)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (stageId != null && subjectId != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text('الطلاب (${students.length})',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Chip(
                          avatar: const Icon(Icons.person_off, size: 18),
                          label: Text('الغائبون: $absentCount'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (students.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('لم يعثر EMIS على طلاب لهذه الاختيارات.'),
                      )
                    else
                      ...List.generate(students.length, (index) {
                        final student = students[index];
                        final absent = _bool(student['isAbsent']);
                        final name = '${student['name'] ?? student['studentName'] ?? student['fullName'] ?? student['displayName'] ?? 'طالب'}'.trim();
                        final studentId = '${student['studentId'] ?? student['id'] ?? ''}';
                        return Card(
                          color: dark ? const Color(0xFF1E1E1E) : Colors.white,
                          margin: const EdgeInsets.only(bottom: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: CheckboxListTile(
                            value: absent,
                            onChanged: (value) => _toggleAbsent(index, value ?? false),
                            activeColor: Colors.redAccent,
                            secondary: CircleAvatar(
                              backgroundColor: absent ? Colors.red.withOpacity(.12) : Colors.blue.withOpacity(.10),
                              child: Icon(absent ? Icons.person_off : Icons.person, color: absent ? Colors.red : Colors.blue),
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('رقم الطالب: $studentId'),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        );
                      }),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: saving ? null : _saveAbsences,
                      icon: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cloud_upload_rounded),
                      label: Text(saving ? 'جاري حفظ الغياب...' : 'حفظ الغياب في EMIS'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: const Color(0xFF1A237E),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
