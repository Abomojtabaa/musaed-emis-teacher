import 'package:flutter/material.dart';
import 'grade_entry_screen.dart';
import 'app_core.dart';

class GradesScreen extends StatelessWidget {
  final String token;
  final String schoolId;
  final List<Map<String, dynamic>> stages;
  final Map<String, List<Map<String, dynamic>>> subjectsByStage;
  final Map<String, List<Map<String, dynamic>>> examsBySubject;
  final List<Map<String, dynamic>> teachingAssignments;

  const GradesScreen({
    super.key,
    required this.token,
    required this.schoolId,
    required this.stages,
    required this.subjectsByStage,
    required this.examsBySubject,
    required this.teachingAssignments,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppCore.themeNotifier,
      builder: (context, mode, _) {
        final dark = mode == ThemeMode.dark;
        return Scaffold(
          backgroundColor: dark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text('الدرجات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 23)),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A90E2)]),
              ),
            ),
          ),
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF4A90E2)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.bar_chart_rounded, color: Colors.white, size: 31),
                      ),
                      SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('إدخال درجات الطلبة',
                                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            SizedBox(height: 5),
                            Text('تسجيل الدرجات مباشرة في نظام EMIS باستخدام لوحة المفاتيح أو الميكروفون.',
                                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  elevation: 0,
                  color: dark ? const Color(0xFF1E1E1E) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GradeEntryScreen(token: token, schoolId: schoolId, teachingAssignments: teachingAssignments),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(21),
                    child: Padding(
                      padding: const EdgeInsets.all(19),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(.12),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: const Icon(Icons.edit_note_rounded, color: Colors.orange, size: 33),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'فتح صفحة إدخال الدرجات',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: dark ? Colors.white : Colors.black87),
                            ),
                          ),
                          Icon(Icons.arrow_back_ios_new_rounded, color: dark ? Colors.white54 : Colors.black45, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
