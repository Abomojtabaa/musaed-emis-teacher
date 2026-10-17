import 'package:flutter/material.dart';
import 'app_core.dart';
import 'settings_screen.dart';
import 'grade_entry_screen.dart';
import 'daily_absence_screen.dart';

class DashboardScreen extends StatelessWidget {
  final String token;
  final String schoolId;
  final String schoolName;
  final String userName;
  final List<dynamic> allStudents;
  final List<dynamic> allTeachers;
  final List<Map<String, dynamic>> stages;
  final Map<String, List<Map<String, dynamic>>> subjectsByStage;
  final Map<String, List<Map<String, dynamic>>> examsBySubject;
  final List<Map<String, dynamic>> teachingAssignments;

  const DashboardScreen({
    super.key,
    required this.token,
    required this.schoolId,
    required this.schoolName,
    required this.userName,
    required this.allStudents,
    required this.allTeachers,
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
        final background = dark ? const Color(0xFF121212) : const Color(0xFFF3F6FB);
        final card = dark ? const Color(0xFF1E1E1E) : Colors.white;
        final text = dark ? Colors.white : const Color(0xFF17213A);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: background,
            body: SafeArea(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF101B58), Color(0xFF246CB5), Color(0xFF168DAD)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.16),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white54),
                          ),
                          child: const Icon(Icons.person_rounded, color: Colors.white, size: 34),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('مرحباً أستاذ،',
                                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              Text(
                                userName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.school_rounded, color: Color(0xFFFFD166), size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      schoolName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'الإعدادات',
                          icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 29),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الخدمات المتاحة',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: text),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                      children: [
                        _serviceCard(
                          context,
                          card: card,
                          text: text,
                          title: 'إدخال الدرجات',
                          subtitle: 'اختيار الصف والمادة والشعبة والفصل وإدخال الدرجات مباشرة مع دعم الميكروفون والتنقل الصوتي.',
                          icon: Icons.edit_note_rounded,
                          color: const Color(0xFFEF8C24),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GradeEntryScreen(
                                token: token,
                                schoolId: schoolId,
                                teachingAssignments: teachingAssignments,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _serviceCard(
                          context,
                          card: card,
                          text: text,
                          title: 'تسجيل الغياب اليومي',
                          subtitle: 'تحديد الصف والمادة والشعبة والتاريخ، ثم اختيار الطلبة الغائبين وحفظهم في EMIS.',
                          icon: Icons.fact_check_rounded,
                          color: const Color(0xFFD94B55),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DailyAbsenceScreen(token: token, schoolId: schoolId, teachingAssignments: teachingAssignments),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.verified_user_outlined, color: dark ? Colors.lightBlueAccent : Colors.blueGrey),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'متصل بنظام EMIS',
                                  style: TextStyle(color: text, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const Icon(Icons.check_circle, color: Colors.green),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _serviceCard(
    BuildContext context, {
    required Color card,
    required Color text,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: card,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 33),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 7),
                    Text(subtitle, style: TextStyle(color: text.withOpacity(.72), height: 1.4, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.arrow_back_ios_new_rounded, color: text.withOpacity(.55), size: 17),
            ],
          ),
        ),
      ),
    );
  }
}
