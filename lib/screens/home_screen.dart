import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/course.dart';
import '../models/data_status.dart';
import '../models/exam.dart';
import '../models/grade.dart';
import '../models/term.dart';
import '../services/academic_data_store.dart';
import '../services/app_settings_store.dart';
import '../services/background_image_cache.dart';
import '../services/course_time.dart';
import '../services/course_note_store.dart';
import '../services/credential_store.dart';
import '../services/floating_pet_service.dart';
import '../services/gdut_jw_client.dart';
import '../services/imported_schedule_store.dart';
import '../services/reminder_service.dart';
import '../services/schedule_importer.dart';
import '../widgets/glass_card.dart';
import '../widgets/data_status_header.dart';
import '../widgets/week_schedule_view.dart';
import 'exams_screen.dart';
import 'grades_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.client,
    required this.themeSeed,
    required this.onThemeSeedChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final GdutJwClient client;
  final Color themeSeed;
  final ValueChanged<Color> onThemeSeedChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _reminderService = const ReminderService();
  final _credentialStore = const CredentialStore();
  final _importedScheduleStore = const ImportedScheduleStore();
  final _courseNoteStore = const CourseNoteStore();
  final _appSettingsStore = const AppSettingsStore();
  final _backgroundImageCache = const BackgroundImageCache();
  final _academicDataStore = const AcademicDataStore();
  final _floatingPetService = const FloatingPetService();
  final _imagePicker = ImagePicker();
  Timer? _floatingPetUpdateTimer;
  late Term _term;
  late Term _gradeTerm;
  int _pageIndex = 0;
  late int _selectedWeek;
  int _reminderMinutes = 10;
  bool _loggedIn = false;
  bool _loadingSchedule = false;
  bool _loadingGrades = false;
  bool _loadingExams = false;
  String? _error;
  String? _savedUsername;
  String? _backgroundImagePath;
  String? _backgroundDisplayImagePath;
  double _backgroundOpacity = 0.40;
  bool _cropBackgroundToScreen = true;
  bool _swipeWeekEnabled = true;
  bool _floatingPetEnabled = false;
  double _floatingPetCardBlur = 20;
  CardStyleSettings _cardStyle = CardStyleSettings.defaults;
  List<Color> _customThemeColors = const [];
  List<Course> _courses = const [];
  List<Grade> _grades = const [];
  List<Exam> _exams = const [];
  DataStatus _scheduleStatus = const DataStatus();
  DataStatus _gradesStatus = const DataStatus();
  DataStatus _examsStatus = const DataStatus();
  Map<String, String> _courseNotes = const {};

  @override
  void dispose() {
    _floatingPetUpdateTimer?.cancel();
    FloatingPetService.setClickHandler(null);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    FloatingPetService.setClickHandler(() async {
      await _syncFloatingPet();
    });
    _term = Term.now(DateTime.now());
    _gradeTerm = Term.recent(DateTime.now())[1];
    _selectedWeek = _term.currentWeek(DateTime.now());
    _restoreAppSettings();
    _restoreCourseNotes();
    _restoreCachedGrades();
    _restoreCachedExams();
    _restoreLogin();
  }

  Future<void> _login() async {
    final credentials = await showModalBottomSheet<SavedCredentials>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LoginSheet(initialUsername: _savedUsername),
    );
    if (credentials == null) {
      return;
    }

    await _loginWithCredentials(credentials, save: true);
  }

  Future<void> _restoreLogin() async {
    await _restoreCachedSchedule(includeImported: true);
    final credentials = await _credentialStore.read();
    if (credentials == null) {
      return;
    }
    setState(() {
      _savedUsername = credentials.username;
    });
    await _loginWithCredentials(credentials, save: false);
  }

  Future<bool> _restoreCachedSchedule({required bool includeImported}) async {
    try {
      var courses = await _importedScheduleStore.readCached();
      if (courses.isEmpty && includeImported) {
        courses = await _importedScheduleStore.read();
      }
      if (!mounted || courses.isEmpty) {
        return false;
      }
      final calibratedTerm = _calibrateTerm(courses);
      final updatedAt = await _scheduleCacheUpdatedAt(includeImported);
      setState(() {
        _term = calibratedTerm;
        _selectedWeek = calibratedTerm.currentWeek(DateTime.now());
        _courses = courses;
        _scheduleStatus = DataStatus(
          lastUpdated: updatedAt,
          offlineCache: true,
        );
      });
      await _syncFloatingPet();
      return true;
    } catch (_) {
      // Corrupt local imports should not block normal app startup.
      return false;
    }
  }

  Future<void> _restoreAppSettings() async {
    final settings = await _appSettingsStore.read();
    if (!mounted) {
      return;
    }
    final backgroundPath = settings.backgroundImagePath;
    final displayPath = settings.backgroundDisplayImagePath;
    setState(() {
      _backgroundImagePath =
          backgroundPath != null && File(backgroundPath).existsSync()
              ? backgroundPath
              : null;
      _backgroundDisplayImagePath =
          displayPath != null && File(displayPath).existsSync()
              ? displayPath
              : null;
      _backgroundOpacity = settings.backgroundOpacity ?? _backgroundOpacity;
      _cropBackgroundToScreen =
          settings.cropBackgroundToScreen ?? _cropBackgroundToScreen;
      _swipeWeekEnabled = settings.swipeWeekEnabled ?? _swipeWeekEnabled;
      _floatingPetEnabled =
          settings.floatingPetEnabled ?? _floatingPetEnabled;
      _floatingPetCardBlur =
          settings.floatingPetCardBlur ?? _floatingPetCardBlur;
      _cardStyle = settings.cardStyle ?? _cardStyle;
      _customThemeColors =
          (settings.customThemeColorValues ?? const []).map(Color.new).toList();
    });
    if (settings.themeSeedValue != null) {
      widget.onThemeSeedChanged(Color(settings.themeSeedValue!));
    }
    if (_floatingPetEnabled && _courses.isNotEmpty) {
      await _syncFloatingPet();
    }
    await _ensureBackgroundDisplayImage();
  }

  Future<void> _saveAppSettings() async {
    await _appSettingsStore.save(
      backgroundImagePath: _backgroundImagePath,
      backgroundDisplayImagePath: _backgroundDisplayImagePath,
      backgroundOpacity: _backgroundOpacity,
      cropBackgroundToScreen: _cropBackgroundToScreen,
      swipeWeekEnabled: _swipeWeekEnabled,
      floatingPetEnabled: _floatingPetEnabled,
      floatingPetCardBlur: _floatingPetCardBlur,
      cardStyle: _cardStyle,
      customThemeColorValues:
          _customThemeColors.map((color) => color.toARGB32()).toList(),
      themeSeedValue: widget.themeSeed.toARGB32(),
    );
  }

  Future<void> _restoreCourseNotes() async {
    final notes = await _courseNoteStore.read();
    if (!mounted) {
      return;
    }
    setState(() {
      _courseNotes = notes;
    });
  }

  String? get _backgroundFilePathForDisplay {
    final displayPath = _backgroundDisplayImagePath;
    if (displayPath != null && File(displayPath).existsSync()) {
      return displayPath;
    }
    final originalPath = _backgroundImagePath;
    if (originalPath != null && File(originalPath).existsSync()) {
      return originalPath;
    }
    return null;
  }

  Future<void> _ensureBackgroundDisplayImage() async {
    final sourcePath = _backgroundImagePath;
    if (!mounted ||
        sourcePath == null ||
        _backgroundDisplayImagePath != null ||
        !File(sourcePath).existsSync()) {
      return;
    }
    final displayPath = await _backgroundImageCache.createDisplayCopy(
      sourcePath: sourcePath,
      logicalScreenSize: MediaQuery.sizeOf(context),
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _backgroundDisplayImagePath = displayPath;
    });
    await _saveAppSettings();
  }

  Future<void> _restoreCachedGrades() async {
    final grades = await _academicDataStore.readGrades(_gradeTerm.gdutTermCode);
    if (!mounted || grades.isEmpty) {
      return;
    }
    final updatedAt =
        await _academicDataStore.readGradesUpdatedAt(_gradeTerm.gdutTermCode);
    setState(() {
      _grades = grades;
      _gradesStatus = DataStatus(lastUpdated: updatedAt, offlineCache: true);
    });
  }

  Future<void> _restoreCachedExams() async {
    final exams = await _academicDataStore.readExams(_term.gdutTermCode);
    if (!mounted || exams.isEmpty) {
      return;
    }
    final updatedAt =
        await _academicDataStore.readExamsUpdatedAt(_term.gdutTermCode);
    setState(() {
      _exams = exams;
      _examsStatus = DataStatus(lastUpdated: updatedAt, offlineCache: true);
    });
  }

  Future<void> _loginWithCredentials(
    SavedCredentials credentials, {
    required bool save,
  }) async {
    setState(() {
      _loadingSchedule = true;
      _error = null;
    });

    try {
      await widget.client.login(
        username: credentials.username,
        password: credentials.password,
      );
      final courses = await widget.client.fetchSchedule(_term);
      if (save) {
        await _credentialStore.save(
          username: credentials.username,
          password: credentials.password,
        );
      }
      final calibratedTerm = _calibrateTerm(courses);
      setState(() {
        _loggedIn = true;
        _savedUsername = credentials.username;
        _term = calibratedTerm;
        _courses = courses;
        _selectedWeek = calibratedTerm.currentWeek(DateTime.now());
        _scheduleStatus = DataStatus(lastUpdated: DateTime.now());
      });
      await _importedScheduleStore.saveCached(courses);
      await _rescheduleReminders();
      await _syncFloatingPet();
    } catch (error) {
      final hasCache = await _restoreCachedSchedule(includeImported: false);
      setState(() {
        _error = _friendlyLoginError(error);
      });
      _showSnackBar(hasCache ? '同步失败，已显示上次缓存' : '同步失败，暂无可用缓存');
    } finally {
      if (mounted) {
        setState(() {
          _loadingSchedule = false;
        });
      }
    }
  }

  Future<void> _clearSavedAccount() async {
    await _credentialStore.clear();
    setState(() {
      _loggedIn = false;
      _savedUsername = null;
      _courses = const [];
      _grades = const [];
      _exams = const [];
      _scheduleStatus = const DataStatus();
      _gradesStatus = const DataStatus();
      _examsStatus = const DataStatus();
      _error = null;
    });
  }

  Future<void> _refreshSchedule() async {
    if (!_loggedIn) {
      setState(() => _pageIndex = 3);
      return;
    }

    setState(() {
      _loadingSchedule = true;
      _error = null;
    });
    try {
      final courses = await widget.client.fetchSchedule(_term);
      final calibratedTerm = _calibrateTerm(courses);
      setState(() {
        _term = calibratedTerm;
        _courses = courses;
        _scheduleStatus = DataStatus(lastUpdated: DateTime.now());
      });
      await _importedScheduleStore.saveCached(courses);
      await _rescheduleReminders();
      await _syncFloatingPet();
    } catch (error) {
      final hasCache = await _restoreCachedSchedule(includeImported: false);
      setState(() {
        _error = _friendlyLoginError(error);
      });
      _showSnackBar(hasCache ? '课表刷新失败，已显示上次缓存' : '课表刷新失败，暂无可用缓存');
    } finally {
      if (mounted) {
        setState(() {
          _loadingSchedule = false;
        });
      }
    }
  }

  Future<void> _refreshGrades() async {
    if (!_loggedIn) {
      await _login();
      return;
    }
    setState(() => _loadingGrades = true);
    try {
      final grades = await widget.client.fetchGrades(_gradeTerm);
      await _academicDataStore.saveGrades(_gradeTerm.gdutTermCode, grades);
      if (mounted) {
        setState(() {
          _grades = grades;
          _gradesStatus = DataStatus(lastUpdated: DateTime.now());
        });
      }
    } catch (error) {
      final cached =
          await _academicDataStore.readGrades(_gradeTerm.gdutTermCode);
      var hasCache = false;
      if (mounted && cached.isNotEmpty) {
        final updatedAt =
            await _academicDataStore.readGradesUpdatedAt(_gradeTerm.gdutTermCode);
        setState(() {
          _grades = cached;
          _gradesStatus = DataStatus(lastUpdated: updatedAt, offlineCache: true);
        });
        hasCache = true;
      }
      _showSnackBar(hasCache ? '成绩刷新失败，已显示上次缓存' : '成绩刷新失败，暂无可用缓存');
    } finally {
      if (mounted) {
        setState(() => _loadingGrades = false);
      }
    }
  }

  Future<void> _refreshExams() async {
    if (!_loggedIn) {
      await _login();
      return;
    }
    setState(() => _loadingExams = true);
    try {
      final exams = await widget.client.fetchExams(_term);
      await _academicDataStore.saveExams(_term.gdutTermCode, exams);
      if (mounted) {
        setState(() {
          _exams = exams;
          _examsStatus = DataStatus(lastUpdated: DateTime.now());
        });
      }
    } catch (error) {
      final cached = await _academicDataStore.readExams(_term.gdutTermCode);
      var hasCache = false;
      if (mounted && cached.isNotEmpty) {
        final updatedAt =
            await _academicDataStore.readExamsUpdatedAt(_term.gdutTermCode);
        setState(() {
          _exams = cached;
          _examsStatus = DataStatus(lastUpdated: updatedAt, offlineCache: true);
        });
        hasCache = true;
      }
      _showSnackBar(hasCache ? '考试刷新失败，已显示上次缓存' : '考试刷新失败，暂无可用缓存');
    } finally {
      if (mounted) {
        setState(() => _loadingExams = false);
      }
    }
  }

  Future<void> _rescheduleReminders() async {
    if (_reminderMinutes <= 0 || _courses.isEmpty) {
      return;
    }
    await _reminderService.schedule(
      courses: _courses,
      term: _term,
      reminderMinutes: _reminderMinutes,
    );
  }

  Term _calibrateTerm(List<Course> courses) {
    final starts = <DateTime, int>{};
    for (final course in courses) {
      final date = course.date;
      if (date == null || course.weeks.isEmpty) {
        continue;
      }
      final week = course.weeks.reduce((a, b) => a < b ? a : b);
      final weekStart = date
          .subtract(Duration(days: course.dayOfWeek - 1))
          .subtract(Duration(days: (week - 1) * 7));
      final normalized =
          DateTime(weekStart.year, weekStart.month, weekStart.day);
      starts[normalized] = (starts[normalized] ?? 0) + 1;
    }
    if (starts.isEmpty) {
      return _term;
    }

    final inferred = starts.entries.reduce(
      (best, next) => next.value > best.value ? next : best,
    );
    return _term.withStartDate(inferred.key);
  }

  Future<void> _importSchedule() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'csv', 'txt', 'xlsx'],
      );
      if (result == null) {
        return;
      }

      final file = result.files.single;
      final path = file.path;
      if (path == null) {
        throw const FormatException('无法读取所选文件');
      }

      final imported = ScheduleImporter.parseBytes(
        await File(path).readAsBytes(),
        sourceName: file.name,
      );
      await _importedScheduleStore.save(imported.courses);

      setState(() {
        _courses = imported.courses;
        _selectedWeek = _term.currentWeek(DateTime.now());
        _error = null;
        _scheduleStatus = DataStatus(lastUpdated: DateTime.now());
      });
      await _rescheduleReminders();
      await _syncFloatingPet();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('已导入 ${imported.courses.length} 条课程：${imported.sourceName}'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$error')),
      );
    }
  }

  Future<void> _pickBackgroundImage() async {
    final scheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.sizeOf(context);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final photos = await Permission.photos.request();
    if (photos.isDenied || photos.isPermanentlyDenied) {
      await Permission.storage.request();
    }

    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return;
    }

    final cropped = await ImageCropper().cropImage(
      sourcePath: image.path,
      compressQuality: 100,
      aspectRatio: CropAspectRatio(
        ratioX: screenSize.width,
        ratioY: screenSize.height,
      ),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '裁剪背景',
          toolbarColor: scheme.primary,
          toolbarWidgetColor: scheme.onPrimary,
          lockAspectRatio: true,
        ),
      ],
    );
    final pickedPath = cropped?.path ?? image.path;
    final directory = await getApplicationDocumentsDirectory();
    final oldPath = _backgroundImagePath;
    final oldDisplayPath = _backgroundDisplayImagePath;
    final savedPath =
        '${directory.path}/nyacourse_background_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(pickedPath).copy(savedPath);
    final displayPath = await _backgroundImageCache.createDisplayCopy(
      sourcePath: savedPath,
      logicalScreenSize: screenSize,
      devicePixelRatio: devicePixelRatio,
    );
    PaintingBinding.instance.imageCache.evict(FileImage(File(pickedPath)));
    if (oldPath != null) {
      PaintingBinding.instance.imageCache.evict(FileImage(File(oldPath)));
      await _backgroundImageCache.deleteIfOwned(oldPath);
    }
    if (oldDisplayPath != null) {
      PaintingBinding.instance.imageCache
          .evict(FileImage(File(oldDisplayPath)));
      await _backgroundImageCache.deleteIfOwned(oldDisplayPath);
    }
    PaintingBinding.instance.imageCache.clear();
    setState(() {
      _backgroundImagePath = savedPath;
      _backgroundDisplayImagePath = displayPath;
    });
    PaintingBinding.instance.imageCache.evict(FileImage(File(savedPath)));
    PaintingBinding.instance.imageCache.evict(FileImage(File(displayPath)));
    await _saveAppSettings();
  }

  void _changeWeek(int delta) {
    setState(() {
      _selectedWeek = (_selectedWeek + delta).clamp(1, 25).toInt();
    });
  }

  void _showCourseDetail(Course course) {
    final time = timeRangeForSections(
      course.startSection,
      course.endSection,
    );
    final date = _term.dateForWeekday(
      week: _selectedWeek,
      weekday: course.dayOfWeek,
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(course.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _DetailLine(icon: Icons.person_outline, text: course.teacher),
            _DetailLine(
              icon: Icons.schedule,
              text:
                  '周${_weekdayName(course.dayOfWeek)} ${date.month}/${date.day} '
                  '${time.label} 第${course.startSection}-${course.endSection}节',
            ),
            _DetailLine(icon: Icons.place_outlined, text: course.location),
            if (course.teachingContent.isNotEmpty)
              _DetailLine(
                icon: Icons.article_outlined,
                text: '授课内容：${course.teachingContent}',
              ),
            _DetailLine(icon: Icons.flag_outlined, text: course.objective),
            _DetailLine(
              icon: Icons.sticky_note_2_outlined,
              text: _courseNotes[course.noteKey] ?? '',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCourseNote(Course course) async {
    final controller =
        TextEditingController(text: _courseNotes[course.noteKey]);
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('课程备注', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: course.name,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (note == null) {
      return;
    }

    final notes = Map<String, String>.from(_courseNotes);
    if (note.isEmpty) {
      notes.remove(course.noteKey);
    } else {
      notes[course.noteKey] = note;
    }
    await _courseNoteStore.save(notes);
    if (!mounted) {
      return;
    }
    setState(() {
      _courseNotes = notes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _ScheduleTab(
        term: _term,
        selectedWeek: _selectedWeek,
        loading: _loadingSchedule,
        courses: _courses,
        status: _scheduleStatus,
        courseNotes: _courseNotes,
        swipeWeekEnabled: _swipeWeekEnabled,
        onRefresh: _refreshSchedule,
        onChangeWeek: _changeWeek,
        onCourseTap: _showCourseDetail,
        onCourseLongPress: _editCourseNote,
        cardStyle: _cardStyle,
        themeSeed: widget.themeSeed,
      ),
      GradesScreen(
        grades: _grades,
        terms: Term.recent(DateTime.now()),
        selectedTerm: _gradeTerm,
        loading: _loadingGrades,
        status: _gradesStatus,
        cardStyle: _cardStyle,
        themeSeed: widget.themeSeed,
        onTermChanged: (term) {
          setState(() {
            _gradeTerm = term;
            _grades = const [];
            _gradesStatus = const DataStatus();
          });
          _restoreCachedGrades();
          _refreshGrades();
        },
        onRefresh: _refreshGrades,
      ),
      ExamsScreen(
        exams: _exams,
        loading: _loadingExams,
        status: _examsStatus,
        onRefresh: _refreshExams,
        cardStyle: _cardStyle,
        themeSeed: widget.themeSeed,
      ),
      SettingsScreen(
        loggedIn: _loggedIn,
        savedUsername: _savedUsername,
        loadingAccount: _loadingSchedule,
        accountError: _error,
        onLogin: _login,
        onClearAccount: _clearSavedAccount,
        importedCourseCount: _courses.length,
        onImportSchedule: _importSchedule,
        reminderMinutes: _reminderMinutes,
        onReminderChanged: (value) async {
          setState(() => _reminderMinutes = value);
          await _rescheduleReminders();
        },
        themeSeed: widget.themeSeed,
        onThemeSeedChanged: (color) async {
          widget.onThemeSeedChanged(color);
          await _saveAppSettingsWithThemeSeed(color);
        },
        customThemeColors: _customThemeColors,
        onAddCustomThemeColor: (color) async {
          if (_customThemeColors
              .any((item) => item.toARGB32() == color.toARGB32())) {
            widget.onThemeSeedChanged(color);
            await _saveAppSettingsWithThemeSeed(color);
            return;
          }
          setState(() {
            _customThemeColors = [
              ..._customThemeColors,
              color,
            ].take(8).toList();
          });
          widget.onThemeSeedChanged(color);
          await _saveAppSettingsWithThemeSeed(color);
        },
        onDeleteCustomThemeColor: (color) async {
          setState(() {
            _customThemeColors = _customThemeColors
                .where((item) => item.toARGB32() != color.toARGB32())
                .toList();
          });
          await _saveAppSettings();
        },
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
        backgroundImagePath: _backgroundImagePath,
        backgroundOpacity: _backgroundOpacity,
        cropBackgroundToScreen: _cropBackgroundToScreen,
        swipeWeekEnabled: _swipeWeekEnabled,
        floatingPetEnabled: _floatingPetEnabled,
        onFloatingPetEnabledChanged: _setFloatingPetEnabled,
        floatingPetCardBlur: _floatingPetCardBlur,
        onFloatingPetCardBlurChanged: (value) async {
          setState(() => _floatingPetCardBlur = value);
          await _saveAppSettings();
          await _syncFloatingPet();
        },
        cardStyle: _cardStyle,
        onPickBackgroundImage: _pickBackgroundImage,
        onClearBackgroundImage: () async {
          final oldPath = _backgroundImagePath;
          final oldDisplayPath = _backgroundDisplayImagePath;
          setState(() {
            _backgroundImagePath = null;
            _backgroundDisplayImagePath = null;
          });
          if (oldPath != null) {
            PaintingBinding.instance.imageCache.evict(FileImage(File(oldPath)));
            await _backgroundImageCache.deleteIfOwned(oldPath);
          }
          if (oldDisplayPath != null) {
            PaintingBinding.instance.imageCache
                .evict(FileImage(File(oldDisplayPath)));
            await _backgroundImageCache.deleteIfOwned(oldDisplayPath);
          }
          PaintingBinding.instance.imageCache.clear();
          await _saveAppSettings();
        },
        onCropBackgroundChanged: (value) async {
          setState(() {
            _cropBackgroundToScreen = value;
          });
          await _saveAppSettings();
        },
        onBackgroundOpacityChanged: (value) async {
          setState(() {
            _backgroundOpacity = value;
          });
          await _saveAppSettings();
        },
        onSwipeWeekEnabledChanged: (value) async {
          setState(() {
            _swipeWeekEnabled = value;
          });
          await _saveAppSettings();
        },
        onCardStyleChanged: (value) async {
          setState(() {
            _cardStyle = value;
          });
          await _saveAppSettings();
        },
        onResetAppearance: () async {
          setState(() {
            _backgroundOpacity = 0.40;
            _cropBackgroundToScreen = true;
            _cardStyle = CardStyleSettings.defaults;
            _customThemeColors = const [];
          });
          widget.onThemeSeedChanged(const Color(0xff006b5b));
          await _saveAppSettingsWithThemeSeed(const Color(0xff006b5b));
        },
      ),
    ];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_backgroundFilePathForDisplay != null)
            Opacity(
              opacity: _backgroundOpacity,
              child: Image.file(
                File(_backgroundFilePathForDisplay!),
                key: ValueKey(_backgroundFilePathForDisplay),
                fit: _cropBackgroundToScreen ? BoxFit.cover : BoxFit.contain,
                filterQuality: FilterQuality.low,
              ),
            ),
          SafeArea(child: pages[_pageIndex]),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: _FloatingNavigationBar(
        selectedIndex: _pageIndex,
        onSelected: (index) => setState(() => _pageIndex = index),
        cardStyle: _cardStyle,
        themeSeed: widget.themeSeed,
      ),
    );
  }

  Future<void> _saveAppSettingsWithThemeSeed(Color themeSeed) async {
    await _appSettingsStore.save(
      backgroundImagePath: _backgroundImagePath,
      backgroundDisplayImagePath: _backgroundDisplayImagePath,
      backgroundOpacity: _backgroundOpacity,
      cropBackgroundToScreen: _cropBackgroundToScreen,
      swipeWeekEnabled: _swipeWeekEnabled,
      floatingPetEnabled: _floatingPetEnabled,
      floatingPetCardBlur: _floatingPetCardBlur,
      cardStyle: _cardStyle,
      customThemeColorValues:
          _customThemeColors.map((color) => color.toARGB32()).toList(),
      themeSeedValue: themeSeed.toARGB32(),
    );
  }

  Future<DateTime?> _scheduleCacheUpdatedAt(bool includeImported) async {
    final remote = await _importedScheduleStore.readCachedUpdatedAt();
    if (remote != null || !includeImported) {
      return remote;
    }
    return _importedScheduleStore.readUpdatedAt();
  }

  Future<void> _setFloatingPetEnabled(bool enabled) async {
    if (!enabled) {
      _floatingPetUpdateTimer?.cancel();
      setState(() => _floatingPetEnabled = false);
      await _saveAppSettings();
      await _floatingPetService.hide();
      return;
    }

    final granted = await _floatingPetService.canDrawOverlays();
    if (!granted) {
      _showSnackBar('请在系统设置中开启 NyaCourse 悬浮窗权限');
      await _floatingPetService.openOverlaySettings();
      return;
    }

    setState(() => _floatingPetEnabled = true);
    await _saveAppSettings();
    await _syncFloatingPet();
  }

  Future<void> _syncFloatingPet() async {
    if (!_floatingPetEnabled) {
      _floatingPetUpdateTimer?.cancel();
      return;
    }
    try {
      final course = _todayNextCourseForPet();
      await _floatingPetService.show(course);
      _scheduleFloatingPetUpdate(course);
    } catch (error) {
      _showSnackBar('桌面宠物启动失败：$error');
    }
  }

  void _scheduleFloatingPetUpdate(FloatingPetCourse course) {
    _floatingPetUpdateTimer?.cancel();
    if (!_floatingPetEnabled) {
      return;
    }
    final now = DateTime.now();
    Duration delay;
    if (course.minutesLeft >= 0 && course.dayLabel == '今天') {
      final nextMinute = DateTime(now.year, now.month, now.day, now.hour,
          now.minute + 1);
      delay = nextMinute.difference(now);
    } else {
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      delay = tomorrow.difference(now);
    }
    _floatingPetUpdateTimer = Timer(delay, () {
      if (mounted && _floatingPetEnabled) {
        _syncFloatingPet();
      }
    });
  }

  FloatingPetCourse _todayNextCourseForPet() {
    final now = DateTime.now();
    if (_courses.isEmpty) {
      return FloatingPetCourse(
        statusText: '课表未同步',
        courseName: '',
        location: '',
        startTime: '',
        minutesLeft: -1,
        dayLabel: '',
        secondaryText: '',
        urgent: false,
        themeColorValue: widget.themeSeed.toARGB32(),
        cardBlur: _floatingPetCardBlur,
      );
    }
    final todayCourses = _coursesForDate(now);
    for (final item in todayCourses) {
      final startsAt = item.$2;
      if (startsAt.isBefore(now)) {
        continue;
      }
      return FloatingPetCourse(
        statusText: '最近一节课',
        courseName: item.$1.name,
        location: item.$1.location,
        startTime: _clockLabel(startsAt),
        minutesLeft: startsAt.difference(now).inMinutes,
        dayLabel: '今天',
        secondaryText: '',
        urgent: startsAt.difference(now).inMinutes < 15,
        themeColorValue: widget.themeSeed.toARGB32(),
        cardBlur: _floatingPetCardBlur,
      );
    }

    final statusText = todayCourses.isEmpty ? '今天没有课' : '上完课了';
    for (var offset = 1; offset <= 21; offset++) {
      final date = DateTime(now.year, now.month, now.day + offset);
      final courses = _coursesForDate(date);
      if (courses.isEmpty) {
        continue;
      }
      final first = courses.first;
      final dayLabel = offset == 1 ? '明天' : _weekdayLabel(date.weekday);
      return FloatingPetCourse(
        statusText: statusText,
        courseName: '',
        location: '',
        startTime: '',
        minutesLeft: -1,
        dayLabel: '',
        secondaryText: '$dayLabel ${_clockLabel(first.$2)} ${first.$1.name}',
        urgent: false,
        themeColorValue: widget.themeSeed.toARGB32(),
        cardBlur: _floatingPetCardBlur,
      );
    }

    return FloatingPetCourse(
      statusText: statusText,
      courseName: '',
      location: '',
      startTime: '',
      minutesLeft: -1,
      dayLabel: '',
      secondaryText: '',
      urgent: false,
      themeColorValue: widget.themeSeed.toARGB32(),
      cardBlur: _floatingPetCardBlur,
    );
  }

  List<(Course, DateTime)> _coursesForDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final week = _term.currentWeek(normalized);
    final courses = <(Course, DateTime)>[];
    for (final course in _courses) {
      if (course.dayOfWeek != normalized.weekday ||
          !course.isActiveInWeek(week)) {
        continue;
      }
      final start = sectionTimes[course.startSection]?.start;
      if (start == null) {
        continue;
      }
      final parts = start.split(':');
      if (parts.length != 2) {
        continue;
      }
      courses.add((
        course,
        DateTime(
          normalized.year,
          normalized.month,
          normalized.day,
          int.tryParse(parts[0]) ?? 0,
          int.tryParse(parts[1]) ?? 0,
        ),
      ));
    }
    courses.sort((a, b) => a.$2.compareTo(b.$2));
    return courses;
  }

  String _clockLabel(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _weekdayLabel(int day) {
    return '周${const ['一', '二', '三', '四', '五', '六', '日'][day - 1]}';
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _friendlyLoginError(Object error) {
    final text = error.toString();
    if (text.contains('账号') ||
        text.contains('密码') ||
        text.contains('用户名') ||
        text.contains('credential')) {
      return '账号或密码可能不正确，请重新登录';
    }
    if (text.contains('返回了网页') ||
        text.contains('HTML') ||
        text.contains('<html') ||
        text.contains('登录态')) {
      return '登录态已失效，请重新登录后刷新';
    }
    if (text.contains('维护') ||
        text.contains('500') ||
        text.contains('503') ||
        text.contains('timeout') ||
        text.contains('timed out')) {
      return '学校系统可能维护或网络不稳定，稍后再试';
    }
    if (text.contains('表单') ||
        text.contains('验证码') ||
        text.contains('二次认证') ||
        text.contains('策略')) {
      return '学校认证流程可能已变化，需要重新检查登录策略';
    }
    return text.replaceFirst('Exception: ', '');
  }

  String _weekdayName(int day) =>
      const ['一', '二', '三', '四', '五', '六', '日'][day - 1];
}

class _FloatingNavigationBar extends StatelessWidget {
  const _FloatingNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.cardStyle,
    required this.themeSeed,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final CardStyleSettings cardStyle;
  final Color themeSeed;

  static const _items = [
    (Icons.calendar_month_outlined, Icons.calendar_month, '课表'),
    (Icons.school_outlined, Icons.school, '成绩'),
    (Icons.event_note_outlined, Icons.event_note, '考试'),
    (Icons.tune, Icons.tune, '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: GlassCard(
        style: cardStyle,
        themeSeed: themeSeed,
        borderRadius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            for (var index = 0; index < _items.length; index++)
              Expanded(
                child: _NavItem(
                  icon: selectedIndex == index
                      ? _items[index].$2
                      : _items[index].$1,
                  label: _items[index].$3,
                  selected: selectedIndex == index,
                  color: themeSeed,
                  onTap: () => onSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? color
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              width: 46,
              height: 30,
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: foreground, size: 22),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({
    required this.term,
    required this.selectedWeek,
    required this.loading,
    required this.courses,
    required this.status,
    required this.courseNotes,
    required this.swipeWeekEnabled,
    required this.onRefresh,
    required this.onChangeWeek,
    required this.onCourseTap,
    required this.onCourseLongPress,
    required this.cardStyle,
    required this.themeSeed,
  });

  final Term term;
  final int selectedWeek;
  final bool loading;
  final List<Course> courses;
  final DataStatus status;
  final Map<String, String> courseNotes;
  final bool swipeWeekEnabled;
  final VoidCallback onRefresh;
  final ValueChanged<int> onChangeWeek;
  final ValueChanged<Course> onCourseTap;
  final ValueChanged<Course> onCourseLongPress;
  final CardStyleSettings cardStyle;
  final Color themeSeed;

  @override
  Widget build(BuildContext context) {
    final activeCourses =
        courses.where((course) => course.isActiveInWeek(selectedWeek)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.asset(
                      'assets/app_icon.jpg',
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NyaCourse',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: themeSeed,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _greeting(),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.72),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${term.displayName}  第 $selectedWeek 周',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color:
                                        glassForegroundColor(context, cardStyle),
                                  ),
                        ),
                        const SizedBox(height: 2),
                        DataStatusText(status: status),
                      ],
                    ),
                  ),
                  GlassIconButton(
                    style: cardStyle,
                    themeSeed: themeSeed,
                    tooltip: '上一周',
                    onPressed:
                        selectedWeek == 1 ? null : () => onChangeWeek(-1),
                    icon: Icons.chevron_left,
                  ),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    style: cardStyle,
                    themeSeed: themeSeed,
                    tooltip: '下一周',
                    onPressed:
                        selectedWeek == 25 ? null : () => onChangeWeek(1),
                    icon: Icons.chevron_right,
                  ),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    style: cardStyle,
                    themeSeed: themeSeed,
                    tooltip: '刷新课表',
                    onPressed: loading ? null : onRefresh,
                    icon: Icons.refresh,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: swipeWeekEnabled
                  ? (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity < -120 && selectedWeek < 25) {
                        onChangeWeek(1);
                      } else if (velocity > 120 && selectedWeek > 1) {
                        onChangeWeek(-1);
                      }
                    }
                  : null,
              child: WeekScheduleView(
                courses: activeCourses,
                totalSections: 12,
                term: term,
                selectedWeek: selectedWeek,
                courseNotes: courseNotes,
                onCourseTap: onCourseTap,
                onCourseLongPress: onCourseLongPress,
              ),
            ),
          ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) {
      return '夜安';
    }
    if (hour < 12) {
      return '早安';
    }
    if (hour < 18) {
      return '午安';
    }
    return '晚安';
  }
}

class _LoginSheet extends StatefulWidget {
  const _LoginSheet({this.initialUsername});

  final String? initialUsername;

  @override
  State<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<_LoginSheet> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.initialUsername ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(SavedCredentials(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('统一认证登录', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '学号',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入学号' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (value) =>
                  value == null || value.isEmpty ? '请输入密码' : null,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.login),
              label: const Text('登录并保存'),
            ),
            const SizedBox(height: 10),
            Text(
              '账号密码会保存到系统安全存储，用于下次打开自动同步。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.58),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
