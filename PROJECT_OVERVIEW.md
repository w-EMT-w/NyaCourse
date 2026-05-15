# NyaCourse 项目说明

NyaCourse 是一个用 Flutter 开发的广东工业大学课表 App。目标是打开 App 就能直接看课表，登录、导入、主题、提醒等操作都放在设置页里，尽量保持日常使用轻量、直观。

教务系统入口：

```text
https://jxfw.gdut.edu.cn
```

统一认证入口：

```text
https://authserver.gdut.edu.cn/authserver/login?service=https%3A%2F%2Fjxfw.gdut.edu.cn%2Fnew%2FssoLogin
```

## 当前功能

- 课表页：按周显示周一到周日课程，自动定位当前教学周，支持左右滑动切换周次、上一周、下一周、刷新。
- 课表日期校准：解析教务系统返回的 `pkrq` 上课日期，用真实日期校准第几周，避免学期起始周推算错误。
- 课程详情：点击课程卡片显示课程名、教师、具体上课时间、地点、课程目的；长按课程可写备注。
- 账号管理：设置页中登录 GDUT 统一认证，账号密码保存在系统安全存储中，下次打开自动同步。
- 本地课表缓存：课表同步成功后保存本地；没网或登录失败时仍可查看上次课表。
- 本地导入：支持导入 `.json`、`.csv`、`.txt`、`.xlsx` 课表文件，导入后保存到本地。
- 成绩页：按学期显示课程名、学分、成绩、绩点，点击课程查看课程大类、学时、修读方式等详情。
- 成绩缓存：成绩按学期保存到本地，刷新失败时显示上次缓存。
- 考试页：显示课程名、考试时间、倒计时、地点、座位号；座位号为空时显示“按考场信息就坐”。
- 考试缓存：考试安排按学期保存到本地，刷新失败时显示上次缓存。
- 课前提醒：按用户设置的提前分钟数发送本地通知，通知内容包含课程名、时间、地点。
- 悬浮球：Android 蓝色猫头悬浮球，支持拖动吸边和点击查看课程提醒。
- 主题设置：支持固定主题色、自定义主题色、删除自定义色、深色/浅色/跟随系统。
- 卡片风格：支持毛玻璃模糊强度、卡片透明度、底色色调、边框发光、字体颜色。
- 可读性预设：外观设置提供“清爽 / 深色壁纸 / 浅色壁纸”，一键调整背景透明度、毛玻璃和字体颜色。
- 背景图片：支持从相册选择图片、按界面比例裁剪、保存原质量文件、调节背景透明度。
- 数据状态：课表、成绩、考试显示上次更新时间；使用缓存时标记“离线缓存”，刷新失败时轻提示。
- UI：课表页包含应用头像、NyaCourse 名称、问候语；底部导航为浮动毛玻璃样式；状态栏使用 edge-to-edge 透明显示。

## 技术栈

- Flutter：页面、状态、主题、课表网格、设置项、缓存恢复。
- Android Kotlin：统一认证登录、教务接口请求、通知渠道和本地提醒调度。
- MethodChannel：Dart 与 Android 原生通信，通道名 `gdut_jw`。
- flutter_secure_storage：保存账号密码、本地课表、成绩、考试、主题配置。
- file_picker：导入课表文件。
- excel：解析 `.xlsx` 课表文件。
- image_picker：选择背景图片。
- image_cropper：按屏幕比例裁剪背景图片。
- permission_handler：请求相册、通知等权限。
- flutter_colorpicker：自定义主题色和字体颜色。
- PRIVACY.md：权限用途、隐私和 release 签名保管说明。

## 目录结构

```text
C:\classSchedule
├── assets
│   └── app_icon.jpg                       # App 内顶部头像资源
├── lib
│   ├── main.dart                          # App 入口、主题、edge-to-edge 状态栏
│   ├── models
│   │   ├── course.dart                    # 课程模型
│   │   ├── grade.dart                     # 成绩模型
│   │   ├── exam.dart                      # 考试模型
│   │   └── term.dart                      # 学期、周次、日期计算
│   ├── screens
│   │   ├── home_screen.dart               # 主容器、底部导航、登录、刷新、缓存调度
│   │   ├── settings_screen.dart           # 设置页：账号、导入、提醒、主题、背景、卡片风格
│   │   ├── grades_screen.dart             # 成绩页
│   │   ├── exams_screen.dart              # 考试页
│   │   ├── login_screen.dart              # 旧登录页入口，当前主流程已迁移到设置页
│   │   └── schedule_screen.dart           # 旧课表页入口，当前主流程使用 HomeScreen
│   ├── services
│   │   ├── gdut_jw_client.dart            # Dart 侧教务客户端和原生通道封装
│   │   ├── schedule_parser.dart           # 教务课表 JSON 解析，含 pkrq 日期解析
│   │   ├── schedule_importer.dart         # JSON / CSV / TXT / XLSX 本地导入
│   │   ├── imported_schedule_store.dart   # 远程课表缓存和导入课表缓存
│   │   ├── academic_data_store.dart       # 成绩、考试本地缓存
│   │   ├── app_settings_store.dart        # 背景、主题色、卡片风格等设置持久化
│   │   ├── credential_store.dart          # 账号密码安全存储
│   │   ├── course_note_store.dart         # 课程备注存储
│   │   ├── reminder_service.dart          # Dart 侧提醒调度入口
│   │   ├── course_time.dart               # 节次到具体时间映射
│   │   └── cookie_store.dart              # Dart HTTP 登录备用链路 Cookie 管理
│   └── widgets
│       ├── week_schedule_view.dart        # 周课表网格、课程卡片
│       └── glass_card.dart                # 毛玻璃卡片、毛玻璃图标按钮
├── android
│   └── app
│       ├── src\main\kotlin\com\example\gdut_class_schedule\MainActivity.kt
│       │                                   # 原生登录、抓取、通知调度
│       ├── src\main\AndroidManifest.xml   # 权限、App 名称、图标、通知 Receiver
│       └── build.gradle.kts               # Android 构建和 release 签名配置
├── scripts
│   ├── gdut_schedule_probe.js             # Node 登录/接口探测脚本
│   └── gdut_flutter_client_probe.dart     # Dart 客户端探测脚本
├── test
│   └── widget_test.dart                   # 基础 Widget 和周次日期测试
└── integration_test
    └── login_flow_test.dart               # 登录流程集成测试
```

## 数据流程

### 启动流程

1. `main.dart` 启动 App，设置透明状态栏和 Material 主题。
2. `HomeScreen` 初始化当前学期、当前周。
3. 读取本地设置：背景、主题、自定义颜色、卡片风格、字体颜色。
4. 读取课程备注、成绩缓存、考试缓存。
5. 从 `CredentialStore` 读取账号密码。
6. 如果已有账号密码，自动登录并同步课表；失败则保留本地缓存。

### 自动同步课表

1. `GdutJwClient.login()` 登录 GDUT 统一认证。
2. Android 设备默认走 Kotlin 原生实现。
3. 登录成功后请求 `xsgrkbcx!getDataList.action`。
4. 课表请求使用 `zc=""` 获取全学期数据，稳定性高。
5. `ScheduleParser` 解析课程字段，并读取 `pkrq`。
6. `HomeScreen._calibrateTerm()` 根据 `pkrq + zc + 星期` 反推教务系统真实第 1 周日期。
7. 同步成功后写入 `ImportedScheduleStore.saveCached()`。
8. 课表页按当前周过滤显示课程。

### 成绩同步和缓存

1. 成绩页选择学期，点击刷新。
2. `GdutJwClient.fetchGrades(term)` 请求 `xskccjxx!getDataList.action`。
3. 成功后写入 `AcademicDataStore.saveGrades(termCode, grades)`。
4. 刷新失败时读取 `AcademicDataStore.readGrades(termCode)`。

### 考试同步和缓存

1. 考试页点击刷新。
2. `GdutJwClient.fetchExams(term)` 请求 `xsksap!getDataList.action`。
3. 成功后写入 `AcademicDataStore.saveExams(termCode, exams)`。
4. 刷新失败时读取 `AcademicDataStore.readExams(termCode)`。

### 本地导入课表

1. 设置页点击“课表导入”。
2. `file_picker` 打开系统文件选择器。
3. `ScheduleImporter` 解析 JSON / CSV / TXT / XLSX。
4. 转成 `Course` 列表并保存到 `ImportedScheduleStore.save()`。
5. 当前课表立即更新；下次打开可恢复本地导入课表。

## 教务系统接口

当前使用接口：

```text
课表：xsgrkbcx!getDataList.action
成绩：xskccjxx!getDataList.action
考试：xsksap!getDataList.action
```

学期参数来自 `Term.gdutTermCode`，例如 `202502`。

如果学校改登录策略、验证码、二次认证、接口字段，优先检查：

- `android/app/src/main/kotlin/com/example/gdut_class_schedule/MainActivity.kt`
- `lib/services/gdut_jw_client.dart`
- `scripts/gdut_schedule_probe.js`

## 本地存储

当前主要存储都使用 `flutter_secure_storage`：

- `CredentialStore`：账号密码。
- `ImportedScheduleStore`：导入课表、远程课表缓存。
- `AcademicDataStore`：成绩缓存、考试缓存。
- `AppSettingsStore`：背景图路径、背景透明度、滑动切周、主题色、自定义主题色、卡片风格。
- `CourseNoteStore`：课程备注。

注意：账号密码只应保存在系统安全存储，不要写进代码、脚本或文档。

## 导入文件格式

### CSV

推荐表头：

```csv
课程名,教师,地点,星期,开始节,结束节,周次,课程目的
人工智能,张老师,教2-102,周一,1,2,1-16,完成课程学习
```

也支持英文表头：

```csv
name,teacher,location,dayOfWeek,startSection,endSection,weeks,objective
```

### JSON

可以导入课程数组：

```json
[
  {
    "name": "人工智能",
    "teacher": "张老师",
    "location": "教2-102",
    "dayOfWeek": 1,
    "startSection": 1,
    "endSection": 2,
    "weeks": [1, 2, 3, 4, 5],
    "objective": "完成课程学习"
  }
]
```

也可以导入教务系统返回的原始 JSON，只要包含 `rows` 或 `kbList`。

### XLSX

推荐列名与 CSV 一致。导入器会尽量识别中文表头和英文表头，但如果表头缺失或节次/周次写法过于随意，可能需要手动整理。

## 本机开发

当前电脑 Flutter SDK 路径：

```powershell
C:\tools\flutter\bin\flutter.bat
```

常用命令：

```powershell
C:\tools\flutter\bin\flutter.bat pub get
C:\tools\flutter\bin\flutter.bat analyze
C:\tools\flutter\bin\flutter.bat test
C:\tools\flutter\bin\flutter.bat run
```

构建 Debug APK：

```powershell
C:\tools\flutter\bin\flutter.bat build apk --debug
```

Debug APK 输出位置：

```text
C:\classSchedule\build\app\outputs\flutter-apk\app-debug.apk
```

安装到当前连接的 Android 设备或模拟器：

```powershell
C:\tools\android-sdk\platform-tools\adb.exe install -r C:\classSchedule\build\app\outputs\flutter-apk\app-debug.apk
```

## 正式版安装包

当前项目已经配置 release 签名读取逻辑：

- 签名文件：`C:\classSchedule\release-key.jks`
- 签名配置：`C:\classSchedule\android\key.properties`

不要把 `.jks`、`key.properties` 或密码提交到公开仓库。

构建 Release APK：

```powershell
C:\tools\flutter\bin\flutter.bat build apk --release
```

Release APK 输出位置：

```text
C:\classSchedule\build\app\outputs\flutter-apk\app-release.apk
```

验证签名：

```powershell
C:\tools\android-sdk\build-tools\35.0.0\apksigner.bat verify --print-certs C:\classSchedule\build\app\outputs\flutter-apk\app-release.apk
```

如果要上架应用商店，通常还需要 AAB：

```powershell
C:\tools\flutter\bin\flutter.bat build appbundle --release
```

输出位置：

```text
C:\classSchedule\build\app\outputs\bundle\release\app-release.aab
```

正式发布前建议：

- 当前 `applicationId` 已改为 `app.nyacourse.mobile`。
- 当前 `pubspec.yaml` 版本为 `0.2.0+2`。
- 检查 App 图标和启动图。
- 隐私说明、权限说明见 `PRIVACY.md`。

## 近期设计约定

- 课表页保持信息优先，课程卡片尽量紧凑，地点信息要尽量完整显示。
- 设置页、成绩页、考试页使用毛玻璃卡片风格。
- 背景图默认只作为氛围，不应影响课程文字可读性。
- 自定义主题色通过固定色块旁的 `+` 添加，上限 8 个，可删除。
- 底部导航为浮动毛玻璃样式，列表页需要保留足够底部滚动空间。

## 注意事项

- 不要把真实账号密码写进代码、脚本或文档。
- 学校统一认证策略可能变化，登录失败时先用 `scripts/gdut_schedule_probe.js` 探测网页流程。
- 如果接口返回 HTML 页面而不是 JSON，通常代表登录态失效或学校策略变化。
- Android 13 及以上通知需要用户授权。
- 悬浮球需要 Android 悬浮窗权限 `SYSTEM_ALERT_WINDOW`，首次开启会跳转系统设置手动授权。
- 背景图片读取受 Android 相册权限策略影响，当前 targetSdk 临时设为 32 以改善相册读取兼容。
- Debug 包体积会明显大于 Release 包；正式版构建后体积会小很多。

## 后续功能建议

- 增加“上次更新”时间，区分缓存数据和刚刷新数据。
- 成绩页增加 GPA 汇总、学期统计。
- 考试页增加考试提醒和按时间排序确认。
- 课表页增加隐藏周末、课程冲突提示、课程颜色自定义。
- 增加导出当前课表为 JSON / CSV / XLSX。
- 清理旧的 `login_screen.dart`、`schedule_screen.dart`，减少历史入口干扰。
