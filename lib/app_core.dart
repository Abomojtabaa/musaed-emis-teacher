import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppCore {
  static ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
  static final AudioPlayer audioPlayer = AudioPlayer();
  static bool isAudioMuted = true;
  static double currentVolume = 0.5;
  static bool voiceInputEnabled = true;
  static bool voiceSequentialAutoStart = false;
  static String voiceRecognitionEngine = 'google';

  // إعدادات التعرف الصوتي في Android/Google
  static bool voiceAutoRestart = false;
  static int voicePossibleSilenceMs = 23000;
  static int voiceCompleteSilenceMs = 23000;
  static int voiceMinimumSpeechMs = 2500;
  static int voiceRestartDelayMs = 4100;
  static int voiceFinalizationTimeoutMs = 2400;
  static double voiceArrowOpacity = 0.25;

  // ==================== القيم الافتراضية للمدرسة والحقول ====================
  static String defaultGender = '1'; // '1' = ذكر ، '2' = أنثى
  static String defaultCountry = 'العراق';
  static String defaultGovernorate = 'القادسية';
  static String defaultDistrict = 'الديوانية';
  static String defaultTown = 'الديوانية';
  static String defaultIdType = '12'; // 12 = البطاقة الوطنية الموحدة
  static String defaultMotherTongue = 'العربية';
  static String defaultStudyLanguage = 'العربية';
  static String defaultReligion = 'الإسلام';
  static String defaultBloodGroup = 'O+';
  static String defaultEconomicLevel = 'الطبقة الوسطى';
  static String defaultAddress2 = '0';
  static String defaultClosestLocation = '0';

  // القيم الافتراضية الخاصة بالمعلم/الكادر
  static String defaultTeacherStatus = 'مستمر';
  static String defaultEmployeeCategory = 'تدريسي';
  static String defaultEmploymentType = 'ملاك';
  static String defaultClassification = 'معلم';
  static String defaultCurrentPosition = 'مدرس';
  static String defaultEducationLevel = 'بكالوريوس';

  static Future<SharedPreferences?> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance()
          .timeout(const Duration(milliseconds: 1500));
    } catch (e) {
      debugPrint('SharedPreferences timeout or error: $e');
      return null;
    }
  }

  static Future<void> initPreferences() async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      bool isDark = prefs.getBool('isDark') ?? false;
      themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

      isAudioMuted = prefs.getBool('isAudioMuted') ?? true;
      currentVolume = prefs.getDouble('currentVolume') ?? 0.5;
      voiceInputEnabled = prefs.getBool('voiceInputEnabled') ?? true;
      voiceSequentialAutoStart =
          prefs.getBool('voiceSequentialAutoStart') ?? false;
      voiceRecognitionEngine =
          prefs.getString('voiceRecognitionEngine') ?? 'google';
      voiceAutoRestart = prefs.getBool('voiceAutoRestart') ?? false;
      voicePossibleSilenceMs = prefs.getInt('voicePossibleSilenceMs') ?? 23000;
      voiceCompleteSilenceMs = prefs.getInt('voiceCompleteSilenceMs') ?? 23000;
      voiceMinimumSpeechMs = prefs.getInt('voiceMinimumSpeechMs') ?? 2500;
      voiceRestartDelayMs = prefs.getInt('voiceRestartDelayMs') ?? 4100;
      voiceFinalizationTimeoutMs =
          prefs.getInt('voiceFinalizationTimeoutMs') ?? 2400;
      voiceArrowOpacity =
          (prefs.getDouble('voiceArrowOpacity') ?? 0.25).clamp(0.20, 0.90);

      // قراءة القيم الافتراضية للمدرسة والحقول
      defaultGender = prefs.getString('defaultGender') ?? '1';
      defaultCountry = prefs.getString('defaultCountry') ?? 'العراق';
      defaultGovernorate = prefs.getString('defaultGovernorate') ?? 'القادسية';
      defaultDistrict = prefs.getString('defaultDistrict') ?? 'الديوانية';
      defaultTown = prefs.getString('defaultTown') ?? 'الديوانية';
      defaultIdType = prefs.getString('defaultIdType') ?? '12';
      defaultMotherTongue = prefs.getString('defaultMotherTongue') ?? 'العربية';
      defaultStudyLanguage =
          prefs.getString('defaultStudyLanguage') ?? 'العربية';
      defaultReligion = prefs.getString('defaultReligion') ?? 'الإسلام';
      defaultBloodGroup = prefs.getString('defaultBloodGroup') ?? 'O+';
      defaultEconomicLevel =
          prefs.getString('defaultEconomicLevel') ?? 'الطبقة الوسطى';
      defaultAddress2 = prefs.getString('defaultAddress2') ?? '0';
      defaultClosestLocation = prefs.getString('defaultClosestLocation') ?? '0';

      defaultTeacherStatus =
          prefs.getString('defaultTeacherStatus') ?? 'مستمر';
      defaultEmployeeCategory =
          prefs.getString('defaultEmployeeCategory') ?? 'تدريسي';
      defaultEmploymentType =
          prefs.getString('defaultEmploymentType') ?? 'ملاك';
      defaultClassification =
          prefs.getString('defaultClassification') ?? 'معلم';
      defaultCurrentPosition =
          prefs.getString('defaultCurrentPosition') ?? 'مدرس';
      defaultEducationLevel =
          prefs.getString('defaultEducationLevel') ?? 'بكالوريوس';
    }

    try {
      await audioPlayer
          .setVolume(currentVolume)
          .timeout(const Duration(seconds: 1));
      if (!isAudioMuted) {
        unawaited(playRelaxMusic());
      } else {
        await audioPlayer.stop().timeout(const Duration(seconds: 1));
      }
    } catch (e) {
      debugPrint('Audio init error: $e');
    }
  }

  static Future<void> saveDefaultFieldValues({
    String? gender,
    String? country,
    String? governorate,
    String? district,
    String? town,
    String? idType,
    String? motherTongue,
    String? studyLanguage,
    String? religion,
    String? bloodGroup,
    String? economicLevel,
    String? address2,
    String? closestLocation,
    String? teacherStatus,
    String? employeeCategory,
    String? employmentType,
    String? classification,
    String? currentPosition,
    String? educationLevel,
  }) async {
    if (gender != null) defaultGender = gender;
    if (country != null) defaultCountry = country.trim();
    if (governorate != null) defaultGovernorate = governorate.trim();
    if (district != null) defaultDistrict = district.trim();
    if (town != null) defaultTown = town.trim();
    if (idType != null) defaultIdType = idType;
    if (motherTongue != null) defaultMotherTongue = motherTongue;
    if (studyLanguage != null) defaultStudyLanguage = studyLanguage;
    if (religion != null) defaultReligion = religion;
    if (bloodGroup != null) defaultBloodGroup = bloodGroup;
    if (economicLevel != null) defaultEconomicLevel = economicLevel;
    if (address2 != null) defaultAddress2 = address2.trim();
    if (closestLocation != null) defaultClosestLocation = closestLocation.trim();
    if (teacherStatus != null) defaultTeacherStatus = teacherStatus;
    if (employeeCategory != null) defaultEmployeeCategory = employeeCategory;
    if (employmentType != null) defaultEmploymentType = employmentType;
    if (classification != null) defaultClassification = classification;
    if (currentPosition != null) defaultCurrentPosition = currentPosition;
    if (educationLevel != null) defaultEducationLevel = educationLevel;

    final prefs = await _getPrefs();
    if (prefs == null) return;

    if (gender != null) await prefs.setString('defaultGender', defaultGender);
    if (country != null) await prefs.setString('defaultCountry', defaultCountry);
    if (governorate != null) {
      await prefs.setString('defaultGovernorate', defaultGovernorate);
    }
    if (district != null) {
      await prefs.setString('defaultDistrict', defaultDistrict);
    }
    if (town != null) await prefs.setString('defaultTown', defaultTown);
    if (idType != null) await prefs.setString('defaultIdType', defaultIdType);
    if (motherTongue != null) {
      await prefs.setString('defaultMotherTongue', defaultMotherTongue);
    }
    if (studyLanguage != null) {
      await prefs.setString('defaultStudyLanguage', defaultStudyLanguage);
    }
    if (religion != null) {
      await prefs.setString('defaultReligion', defaultReligion);
    }
    if (bloodGroup != null) {
      await prefs.setString('defaultBloodGroup', defaultBloodGroup);
    }
    if (economicLevel != null) {
      await prefs.setString('defaultEconomicLevel', defaultEconomicLevel);
    }
    if (address2 != null) {
      await prefs.setString('defaultAddress2', defaultAddress2);
    }
    if (closestLocation != null) {
      await prefs.setString('defaultClosestLocation', defaultClosestLocation);
    }
    if (teacherStatus != null) {
      await prefs.setString('defaultTeacherStatus', defaultTeacherStatus);
    }
    if (employeeCategory != null) {
      await prefs.setString('defaultEmployeeCategory', defaultEmployeeCategory);
    }
    if (employmentType != null) {
      await prefs.setString('defaultEmploymentType', defaultEmploymentType);
    }
    if (classification != null) {
      await prefs.setString('defaultClassification', defaultClassification);
    }
    if (currentPosition != null) {
      await prefs.setString('defaultCurrentPosition', defaultCurrentPosition);
    }
    if (educationLevel != null) {
      await prefs.setString('defaultEducationLevel', defaultEducationLevel);
    }
  }

  static Future<void> resetDefaultFieldValues() async {
    defaultGender = '1';
    defaultCountry = 'العراق';
    defaultGovernorate = 'القادسية';
    defaultDistrict = 'الديوانية';
    defaultTown = 'الديوانية';
    defaultIdType = '12';
    defaultMotherTongue = 'العربية';
    defaultStudyLanguage = 'العربية';
    defaultReligion = 'الإسلام';
    defaultBloodGroup = 'O+';
    defaultEconomicLevel = 'الطبقة الوسطى';
    defaultAddress2 = '0';
    defaultClosestLocation = '0';
    defaultTeacherStatus = 'مستمر';
    defaultEmployeeCategory = 'تدريسي';
    defaultEmploymentType = 'ملاك';
    defaultClassification = 'معلم';
    defaultCurrentPosition = 'مدرس';
    defaultEducationLevel = 'بكالوريوس';

    final prefs = await _getPrefs();
    if (prefs == null) return;
    for (final key in [
      'defaultGender',
      'defaultCountry',
      'defaultGovernorate',
      'defaultDistrict',
      'defaultTown',
      'defaultIdType',
      'defaultMotherTongue',
      'defaultStudyLanguage',
      'defaultReligion',
      'defaultBloodGroup',
      'defaultEconomicLevel',
      'defaultAddress2',
      'defaultClosestLocation',
      'defaultTeacherStatus',
      'defaultEmployeeCategory',
      'defaultEmploymentType',
      'defaultClassification',
      'defaultCurrentPosition',
      'defaultEducationLevel',
    ]) {
      await prefs.remove(key);
    }
  }

  static Future<void> saveThemePreference(bool isDark) async {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await _getPrefs();
    await prefs?.setBool('isDark', isDark);
  }

  static Future<void> playRelaxMusic() async {
    if (isAudioMuted) return;
    try {
      await audioPlayer
          .setReleaseMode(ReleaseMode.loop)
          .timeout(const Duration(seconds: 1));
      if (audioPlayer.state != PlayerState.playing) {
        await audioPlayer
            .play(AssetSource('relax.mp3'))
            .timeout(const Duration(seconds: 2));
        await audioPlayer
            .setVolume(currentVolume)
            .timeout(const Duration(seconds: 1));
      }
    } catch (e) {
      debugPrint('خطأ في تشغيل الموسيقى الهادئة: $e');
    }
  }

  static Future<void> toggleAudio() async {
    isAudioMuted = !isAudioMuted;
    try {
      if (isAudioMuted) {
        await audioPlayer.stop().timeout(const Duration(seconds: 1));
      } else {
        unawaited(playRelaxMusic());
      }
    } catch (e) {
      debugPrint('خطأ أثناء تبديل الصوت: $e');
    }
    final prefs = await _getPrefs();
    await prefs?.setBool('isAudioMuted', isAudioMuted);
  }

  static Future<void> setVolume(double vol) async {
    currentVolume = vol;
    try {
      await audioPlayer
          .setVolume(vol)
          .timeout(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('خطأ في ضبط مستوى الصوت: $e');
    }
    final prefs = await _getPrefs();
    await prefs?.setDouble('currentVolume', vol);
  }

  static Future<void> setVoiceInputEnabled(bool enabled) async {
    voiceInputEnabled = enabled;
    final prefs = await _getPrefs();
    await prefs?.setBool('voiceInputEnabled', enabled);
  }

  static Future<void> setVoiceSequentialAutoStart(bool enabled) async {
    voiceSequentialAutoStart = enabled;
    final prefs = await _getPrefs();
    await prefs?.setBool('voiceSequentialAutoStart', enabled);
  }

  static Future<void> setVoiceRecognitionEngine(String engine) async {
    final value = engine == 'legacy' ? 'legacy' : 'google';
    voiceRecognitionEngine = value;
    final prefs = await _getPrefs();
    await prefs?.setString('voiceRecognitionEngine', value);
  }

  static Future<void> saveVoiceSettings({
    bool? autoRestart,
    int? possibleSilenceMs,
    int? completeSilenceMs,
    int? minimumSpeechMs,
    int? restartDelayMs,
    int? finalizationTimeoutMs,
    double? arrowOpacity,
  }) async {
    if (autoRestart != null) voiceAutoRestart = autoRestart;
    if (possibleSilenceMs != null) voicePossibleSilenceMs = possibleSilenceMs;
    if (completeSilenceMs != null) voiceCompleteSilenceMs = completeSilenceMs;
    if (minimumSpeechMs != null) voiceMinimumSpeechMs = minimumSpeechMs;
    if (restartDelayMs != null) voiceRestartDelayMs = restartDelayMs;
    if (finalizationTimeoutMs != null) {
      voiceFinalizationTimeoutMs = finalizationTimeoutMs;
    }
    if (arrowOpacity != null) {
      voiceArrowOpacity = arrowOpacity.clamp(0.20, 0.90);
    }

    final prefs = await _getPrefs();
    if (prefs == null) return;

    if (autoRestart != null) {
      await prefs.setBool('voiceAutoRestart', autoRestart);
    }
    if (possibleSilenceMs != null) {
      await prefs.setInt('voicePossibleSilenceMs', possibleSilenceMs);
    }
    if (completeSilenceMs != null) {
      await prefs.setInt('voiceCompleteSilenceMs', completeSilenceMs);
    }
    if (minimumSpeechMs != null) {
      await prefs.setInt('voiceMinimumSpeechMs', minimumSpeechMs);
    }
    if (restartDelayMs != null) {
      await prefs.setInt('voiceRestartDelayMs', restartDelayMs);
    }
    if (finalizationTimeoutMs != null) {
      await prefs.setInt('voiceFinalizationTimeoutMs', finalizationTimeoutMs);
    }
    if (arrowOpacity != null) {
      await prefs.setDouble('voiceArrowOpacity', voiceArrowOpacity);
    }
  }

  static Future<void> resetVoiceSettings() async {
    voiceAutoRestart = false;
    voicePossibleSilenceMs = 23000;
    voiceCompleteSilenceMs = 23000;
    voiceMinimumSpeechMs = 2500;
    voiceRestartDelayMs = 4100;
    voiceFinalizationTimeoutMs = 2400;
    voiceArrowOpacity = 0.25;

    final prefs = await _getPrefs();
    if (prefs == null) return;
    for (final key in [
      'voiceAutoRestart',
      'voicePossibleSilenceMs',
      'voiceCompleteSilenceMs',
      'voiceMinimumSpeechMs',
      'voiceRestartDelayMs',
      'voiceFinalizationTimeoutMs',
      'voiceArrowOpacity',
    ]) {
      await prefs.remove(key);
    }
  }

  static void toggleTheme() {
    bool isDark = themeNotifier.value == ThemeMode.dark;
    saveThemePreference(!isDark);
  }
}
