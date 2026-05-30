# NyaCourse 项目总览

本文档给后续维护者和 AI 接手用。目标是只读这一份文件，就能理解 NyaCourse 的架构、核心数据流、主要实现位置、近期改动和注意事项。

NyaCourse 是一个 Flutter + Android Kotlin 开发的广东工业大学课表 App。Flutter 负责主要 UI、状态管理、本地缓存、主题和课表计算；Android Kotlin 负责 GDUT 教务系统原生抓取、本地通知调度、桌面悬浮球等系统能力。

当前工作目录：

```text
C:\classSchedule
```

GitHub 仓库：

```text
https://github.com/w-EMT-w/NyaCourse
```

当前版本：

```text
pubspec.yaml: 0.3.0+5
applicationId: com.example.gdut_class_schedule
GitHub release tag: v0.3.0
Release APK asset: NyaCourse-v0.3.0.apk
```

注意：用户曾经反馈改 `applicationId` 会导致旧版本本地设置、背景图等数据丢失。因此现在 `applicationId` 保持 `com.example.gdut_class_schedule`。不要随意修改包名，除非用户明确接受“相当于另一个新 App”的后果。

## 一句话架构

```text
Flutter UI/HomeScreen
  ├─ GdutJwClient -> MethodChannel(gdut_jw) -> Android MainActivity -> GDUT 教务接口
  ├─ flutter_secure_storage -> 账号、课表、成绩、考试、主题、背景、设置缓存
  ├─ ReminderService -> MethodChannel(gdut_jw) -> Android 通知/闹钟
  ├─ FloatingPetService(Dart) -> MethodChannel(gdut_pet) -> Android FloatingPetService 桌面悬浮球
  └─ ScheduleWidgetService -> home_widget -> Android AppWidgetProvider 今日课程小组件
```

## 技术栈

- Flutter：主界面、课表网格、成绩页、考试页、设置页、主题和状态管理。
- Android Kotlin：统一认证登录、教务接口请求、通知调度、悬浮窗服务。
- MethodChannel：
  - `gdut_jw`：教务抓取、成绩、考试、课前提醒。
  - `gdut_pet`：悬浮球权限、显示、隐藏、课程信息更新、点击回调。
- `flutter_secure_storage`：账号、课程、成绩、考试、主题、背景图路径、设置项。
- `file_picker` + `excel`：本地课表导入。
- `image_picker` + `image_cropper`：背景图片选择和裁剪。
- `permission_handler`：系统权限辅助。
- `flutter_colorpicker`：自定义主题色和字体颜色。
- Android `WindowManager`：桌面悬浮球和课程气泡卡片。
- Android `SpringAnimation`：悬浮球吸边、点击压缩回弹动画。

## 目录结构

```text
C:\classSchedule
├── PROJECT_OVERVIEW.md                    # 当前文档，给人和 AI 接手用
├── PRIVACY.md                             # 权限和隐私说明
├── pubspec.yaml                           # Flutter 依赖、版本号、assets
├── assets
│   ├── app_icon.jpg                       # App 内首页头像
│   └── settings_mascot.png                # 设置页顶部角色图，透明 PNG
├── lib
│   ├── main.dart                          # App 入口、主题、透明状态栏
│   ├── models
│   │   ├── course.dart                    # 课程模型
│   │   ├── data_status.dart               # 上次更新/离线缓存状态
│   │   ├── exam.dart                      # 考试模型
│   │   ├── grade.dart                     # 成绩模型
│   │   └── term.dart                      # 学期、教学周、日期计算
│   ├── screens
│   │   ├── home_screen.dart               # 主页面容器，核心状态和数据流都在这里
│   │   ├── settings_screen.dart           # 二级菜单设置页、关于页、更新记录
│   │   ├── grades_screen.dart             # 成绩页
│   │   ├── exams_screen.dart              # 考试页
│   │   ├── login_screen.dart              # 旧登录页入口，当前主流程已迁到设置页
│   │   └── schedule_screen.dart           # 旧课表页入口，当前主流程使用 HomeScreen
│   ├── services
│   │   ├── gdut_jw_client.dart            # Dart 教务客户端，Android 优先走原生通道
│   │   ├── schedule_parser.dart           # 教务课表 JSON 解析，包含 pkrq 日期解析
│   │   ├── schedule_importer.dart         # JSON/CSV/TXT/XLSX 本地导入
│   │   ├── imported_schedule_store.dart   # 本地导入课表和远程课表缓存
│   │   ├── academic_data_store.dart       # 成绩/考试缓存
│   │   ├── app_settings_store.dart        # 主题、背景、悬浮球等设置持久化
│   │   ├── background_image_cache.dart    # 背景图保存到 App 本地目录，避免重复读取相册
│   │   ├── credential_store.dart          # 账号密码安全存储
│   │   ├── course_note_store.dart         # 课程备注
│   │   ├── course_time.dart               # 节次到具体时间映射
│   │   ├── floating_pet_service.dart      # Flutter 侧悬浮球数据模型和 MethodChannel
│   │   ├── reminder_service.dart          # Flutter 侧提醒调度入口
│   │   └── cookie_store.dart              # Dart HTTP 备用链路 Cookie 管理
│   └── widgets
│       ├── week_schedule_view.dart        # 周课表网格和课程卡片
│       ├── glass_card.dart                # 毛玻璃卡片和图标按钮
│       └── data_status_header.dart        # 成绩/考试等统一标题、刷新、缓存状态、空状态
├── android
│   └── app
│       ├── build.gradle.kts               # applicationId、targetSdk、签名配置
│       └── src/main
│           ├── AndroidManifest.xml        # 权限、服务、Receiver
│           ├── kotlin/com/example/gdut_class_schedule
│           │   ├── MainActivity.kt        # 教务抓取、提醒、悬浮球 MethodChannel
│           │   └── FloatingPetService.kt  # Android 原生桌面悬浮球
│           └── res
│               ├── drawable-nodpi/floating_pet.png # 蓝色猫头悬浮球图
│               └── mipmap-*                       # App 图标
├── scripts
│   ├── gdut_schedule_probe.js             # Node 登录/接口探测
│   └── gdut_flutter_client_probe.dart     # Dart 客户端探测
├── test
│   └── widget_test.dart                   # Widget 和周次日期测试
└── integration_test
    └── login_flow_test.dart               # 登录流程集成测试
```

## 当前主要功能

### 课表

- 首页打开即显示课表，按教学周展示周一到周日课程。
- 支持上一周、下一周、左右滑动切周。
- 自动定位当前教学周。
- 解析教务系统 `pkrq`，用真实日期校准学期第 1 周，避免只靠本地推算导致周次偏移。
- 课程卡片展示课程名、地点、节次/周次等信息，文字截断按重要程度处理。
- 点击课程看详情；长按课程写备注。
- 课表页顶部有 App 头像、`NyaCourse`、时间问候和今天日期。
- 问候逻辑当前为：
  - `0:00-4:59`：晚安
  - `5:00-11:59`：早安
  - `12:00-17:59`：午安
  - `18:00-23:59`：晚安

### 登录和教务抓取

- 设置页登录 GDUT 统一认证。
- 账号密码保存在系统安全存储中。
- Android 真机默认通过 Kotlin 原生链路抓取。
- `GdutJwClient` 保留 Dart HTTP 备用逻辑，但核心优先使用 `MainActivity.kt` 的原生实现。
- 刷新失败时保留缓存，并显示更清楚的错误提示。
- 如果接口返回 HTML，通常说明登录态失效、认证流程变化或系统维护。

### 成绩

- 按学期显示课程名、学分、成绩、绩点。
- 点击课程查看课程大类、学时、修读方式等详情。
- 页面标题、刷新按钮、空状态、缓存状态使用统一组件。
- 显示上次更新时间。
- 使用缓存时显示“离线缓存”。
- 刷新失败时提示“刷新失败，已显示上次缓存”。

### 考试

- 显示课程名、考试时间、倒计时、地点、座位号。
- 座位号为空时显示“按考场信息就坐”。
- 最近考试排在最前面。
- 设置页首页会根据最近考试显示考试提示：
  - 有考试：`距离xx考试还有xx天，加油！`
  - 今天考试：`xx今天考试，加油！`
  - 没考试：`近期没有考试，睡大觉吧！` 或 `海阔天空，暂时没有考试～`
- 页面标题、刷新、空状态、缓存状态和成绩页保持一致。

### 本地导入

- 支持导入 `.json`、`.csv`、`.txt`、`.xlsx`。
- 导入后保存本地，下次打开可恢复。
- 支持教务系统原始 JSON，只要包含 `rows` 或 `kbList`。

### 课前提醒

- 用户可设置提前几分钟提醒。
- Flutter 将课程列表和提前分钟数传给 Android。
- Android 使用通知渠道和系统调度发送本地通知。
- Android 13 及以上需要通知权限。

### 悬浮球

- Android 桌面悬浮球，形象为蓝色猫头 PNG：`android/app/src/main/res/drawable-nodpi/floating_pet.png`。
- 设置页“悬浮球”二级页面可开关悬浮球、调卡片背景模糊度。
- 需要 `SYSTEM_ALERT_WINDOW` 权限，首次开启会跳转系统设置手动授权。
- 大小为 56dp。
- 默认吸附右边框。
- 拖动跟手，松手后吸附左/右边框。
- 吸边后隐藏一半：
  - 右边框：向右藏 50%，露左半。
  - 左边框：向左藏 50%，露右半。
- 使用 `SpringAnimation`：
  - 吸附：`stiffness 300`，`dampingRatio 0.6`
  - 点击压缩回弹：`dampingRatio 0.4`
- 待机不晃动、不上下浮动。
- 点击悬浮球：
  - 卡片未打开时打开。
  - 卡片已打开时关闭。
  - 拖动不触发开关。
- 气泡卡片：
  - 宽度 220dp。
  - 自动计算屏幕剩余空间，避免超出屏幕。
  - 最大高度为屏幕高度 35%。
  - 右吸边时卡片往左弹，左吸边时往右弹。
  - 靠近底部时向上调整。
  - 带小箭头，像猫头说话。
  - 圆角、发光白边、浅色背景，文字使用深色保证白色背景下可读。
  - 原生卡片使用独立 Window 层级，只拦截卡片区域触摸，外部触摸收起。

悬浮球课程信息由 Flutter 侧计算，Android 侧只负责显示。这样避免 Flutter 和 Kotlin 各算一套课表逻辑。

悬浮球状态文案当前逻辑：

- 今天完全没课：主状态 `今天没有课程`。
- 正在上课：主状态 `上课中~`，显示当前课程，并补充下一节课或今日课程已完成。
- 今天还有课：主状态 `下一节课`，显示最近一节课、地点、开始时间、距离上课。
- 今天课都上完：主状态 `今日课程已完成~`。
- 后续几天有课：小字补充 `明天/后天/下周X/M月D日 周X HH:mm 课程名`。
- 距离上课不足 15 分钟：显示 `快到上课时间啦`，颜色用主题色。
- 有倒计时时按分钟更新；没课/上完课时不需要每分钟刷新，只在 App 启动、课表刷新成功、用户点击悬浮球等时机更新。

相关文件：

- Flutter 侧数据模型和通道：`lib/services/floating_pet_service.dart`
- Flutter 侧课程判断：`lib/screens/home_screen.dart` 的悬浮球相关方法
- Android 通道入口：`android/app/src/main/kotlin/com/example/gdut_class_schedule/MainActivity.kt`
- Android 悬浮窗实现：`android/app/src/main/kotlin/com/example/gdut_class_schedule/FloatingPetService.kt`

### 设置页

设置页已改成“设置首页 + 二级页面”。

设置首页模块：

- 账号与同步
- 课表与提醒
- 悬浮球
- 外观主题
- 数据与缓存
- 关于

入口卡片会显示摘要，例如：

- 已登录 / 未登录
- 悬浮球 已开启 / 未开启
- 提前 10 分钟提醒
- 当前主题模式
- 本地课表条数
- 当前版本号

顶部区域：

- 使用透明 PNG：`assets/settings_mascot.png`
- 图片较大，尽量占住设置页上半部分。
- 图片下方显示时间问候、App 名称和 slogan。
- 设置页问候逻辑：
  - `0:00-4:59`：`夜深了，早点休息哦`
  - `5:00-11:59`：`早安～今天也要好好上课哦`
  - `12:00-17:59`：`下午好～课上完了吗`
  - `18:00-23:59`：按日期交替显示 `辛苦了～今天的课都上完了吗` 或 `夜深了，早点休息哦`
- Slogan 按日期交替：
  - `认真上课，从记住课表开始`
  - `上课摸鱼两不误`

返回行为：

- 二级页面不是 Dialog/BottomSheet，而是在设置页内部切换。
- 使用 `PopScope` 拦截 Android 返回键。
- 手机返回键和顶部返回箭头都会回到设置首页。
- 返回设置首页时保持首页滚动位置。

关于页：

- 显示 GitHub 仓库链接。
- 有检查更新功能，优先读取 GitHub raw `update.json`，Gitee 作为备用。
- 检查到新版后可在 App 内下载 APK，再调 Android 系统安装器安装。
- Android 8 及以上如果未允许“安装未知应用”，会先引导用户去系统设置授权。
- 有更新记录，当前最新为 `0.3.0+5`。

### 外观和主题

- 支持浅色、深色、跟随系统。
- 支持固定主题色和自定义主题色。
- 自定义主题色最多 8 个，可删除。
- 支持背景图片，选择后保存到 App 本地目录，避免每次从相册重新加载导致慢和权限问题。
- 支持背景透明度。
- 支持卡片风格：透明度、底色色调、边框发光、字体颜色等。
- 推荐预设已经不再作为当前功能，不要在 UI 或文档里继续写“清爽/深色壁纸/浅色壁纸”预设。

## 核心数据流

### App 启动

1. `main.dart` 创建 `GdutJwClient`，启动 `HomeScreen`。
2. `HomeScreen.initState()` 初始化当前学期、当前周、定时器和悬浮球点击回调。
3. 读取设置：主题、背景、卡片风格、悬浮球开关等。
4. 读取课程备注、课表缓存、成绩缓存、考试缓存。
5. 从 `CredentialStore` 读取账号密码。
6. 如果已有账号密码，自动登录并同步课表；失败则保留缓存。
7. 如果悬浮球已开启，计算当前课程状态并调用原生悬浮球显示/更新。

### 课表同步

1. `HomeScreen` 调用 `GdutJwClient.login()` / fetch。
2. Android 平台优先使用 `MethodChannel('gdut_jw')`。
3. `MainActivity.kt` 调用 `GdutNativeClient.loginAndFetchSchedule()`。
4. 原生端登录统一认证并请求教务课表接口。
5. 返回 JSON 给 Dart。
6. `ScheduleParser` 解析课程字段和 `pkrq`。
7. `HomeScreen._calibrateTerm()` 使用 `pkrq + zc + 星期` 校准学期第 1 周日期。
8. 成功后写入 `ImportedScheduleStore.saveCached()`。
9. UI 刷新课表，并更新悬浮球和课前提醒。

### 成绩同步

1. 成绩页选择学期后点击刷新。
2. `GdutJwClient.fetchGrades(term)` 请求原生通道。
3. 原生端请求 `xskccjxx!getDataList.action`。
4. 成功后保存到 `AcademicDataStore.saveGrades(termCode, grades)`。
5. 失败时读取 `AcademicDataStore.readGrades(termCode)`，并标记离线缓存。

### 考试同步

1. 考试页点击刷新。
2. `GdutJwClient.fetchExams(term)` 请求原生通道。
3. 原生端请求 `xsksap!getDataList.action`。
4. 成功后保存到 `AcademicDataStore.saveExams(termCode, exams)`。
5. 失败时读取缓存，并标记离线缓存。
6. UI 按最近考试优先排序。

### 背景图片

1. 用户在设置页选择图片。
2. `image_picker` 取图，`image_cropper` 按屏幕比例裁剪。
3. `background_image_cache.dart` 把图片保存到 App 本地目录。
4. `AppSettingsStore` 只保存本地路径和透明度等设置。
5. 下次启动直接从本地文件加载，减少相册权限和读取开销。

### 悬浮球信息更新

1. Flutter 侧根据当前日期、教学周、课程节次、`course_time.dart` 计算课程状态。
2. 生成 `FloatingPetCourse`。
3. 调用 `FloatingPetService.show()` 或 `updateCourse()`。
4. `MainActivity.kt` 把字段写入 Intent。
5. `FloatingPetService.kt` 只渲染悬浮球和气泡卡片。
6. 有“距离上课”倒计时时，Flutter 定时按分钟更新；其他状态低频更新。

## 教务系统接口

教务系统入口：

```text
https://jxfw.gdut.edu.cn
```

统一认证入口：

```text
https://authserver.gdut.edu.cn/authserver/login?service=https%3A%2F%2Fjxfw.gdut.edu.cn%2Fnew%2FssoLogin
```

当前使用接口：

```text
课表：xsgrkbcx!getDataList.action
成绩：xskccjxx!getDataList.action
考试：xsksap!getDataList.action
```

学期参数来自 `Term.gdutTermCode`，例如 `202502`。

如果学校认证策略改变，优先检查：

- `android/app/src/main/kotlin/com/example/gdut_class_schedule/MainActivity.kt`
- `lib/services/gdut_jw_client.dart`
- `scripts/gdut_schedule_probe.js`

登录问题常见判断：

- 账号密码错误：提示用户检查账号密码。
- 登录态失效：重新登录。
- 接口返回 HTML：多半是认证没过、登录态失效或学校页面改版。
- 学校系统维护：接口可能超时、返回维护页面或异常 HTML。

## 本地存储

主要存储都用 `flutter_secure_storage`：

- `CredentialStore`：账号密码。
- `ImportedScheduleStore`：导入课表、远程课表缓存。
- `AcademicDataStore`：成绩、考试缓存。
- `AppSettingsStore`：主题、背景图路径、背景透明度、卡片风格、悬浮球开关和模糊度。
- `CourseNoteStore`：课程备注。

不要把真实账号密码写进代码、脚本、日志、文档或 GitHub。

## 导入格式

CSV 推荐表头：

```csv
课程名,教师,地点,星期,开始节,结束节,周次,课程目的
人工智能,张老师,教2-102,周一,1,2,1-16,完成课程学习
```

英文表头也支持：

```csv
name,teacher,location,dayOfWeek,startSection,endSection,weeks,objective
```

JSON 可以是课程数组：

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

也可以是教务系统原始 JSON，只要包含 `rows` 或 `kbList`。

XLSX 推荐列名与 CSV 一致。导入器会尽量识别中文和英文表头。

## 构建和验证

Flutter SDK：

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

Debug APK：

```powershell
C:\tools\flutter\bin\flutter.bat build apk --debug
```

输出：

```text
C:\classSchedule\build\app\outputs\flutter-apk\app-debug.apk
```

Release APK：

```powershell
C:\tools\flutter\bin\flutter.bat build apk --release
```

输出：

```text
C:\classSchedule\build\app\outputs\flutter-apk\app-release.apk
```

签名验证：

```powershell
C:\tools\android-sdk\build-tools\35.0.0\apksigner.bat verify --print-certs C:\classSchedule\build\app\outputs\flutter-apk\app-release.apk
```

当前 release 签名配置：

- 签名文件：`C:\classSchedule\release-key.jks`
- 签名配置：`C:\classSchedule\android\key.properties`

不要提交 `.jks`、`key.properties` 或任何密码。

如果要构建 AAB：

```powershell
C:\tools\flutter\bin\flutter.bat build appbundle --release
```

输出：

```text
C:\classSchedule\build\app\outputs\bundle\release\app-release.aab
```

## GitHub Release 流程

当前用户要求过“不改版本号，只替换 GitHub 上的 APK”。已做过的方式是：

1. 本机构建 release APK。
2. 找到对应 GitHub release，例如 `v0.2.2`。
3. 删除对应同名资产，例如 `NyaCourse-v0.2.2.apk`。
4. 上传新的同名 APK。
5. 不改 tag，不改版本号，不新建 release。

当前下载地址：

```text
https://github.com/w-EMT-w/NyaCourse/releases/download/v0.3.0/NyaCourse-v0.3.0.apk
```

如果以后要真正发新版本：

1. 修改 `pubspec.yaml` 版本，例如 `0.2.3+5`。
2. 更新设置页关于/更新记录中的版本。
3. 跑 `flutter analyze` 和 `flutter test`。
4. 构建 release APK 并验证签名。
5. 在 GitHub 创建新 tag/release。
6. 上传 APK。

## App 内更新

当前 App 内更新不直接依赖 GitHub API。关于页“检查更新”优先读取仓库根目录的 GitHub raw JSON，并带 30 秒超时和 Gitee 备用 URL 重试：

```text
https://raw.githubusercontent.com/w-EMT-w/NyaCourse/main/update.json
https://gitee.com/w-EMT-w/NyaCourse/raw/main/update.json
https://gitee.com/w-EMT-w/NyaCourse/raw/main/update.json?inline=false
```

推荐 `update.json` 格式：

```json
{
  "version": "0.3.0",
  "build": 5,
  "title": "NyaCourse 0.3.0",
  "notes": "新增今日课程桌面小组件，并优化小组件离线刷新。",
  "apkUrl": "https://github.com/w-EMT-w/NyaCourse/releases/download/v0.3.0/NyaCourse-v0.3.0.apk",
  "fallbackUrl": "https://github.com/w-EMT-w/NyaCourse/releases/latest",
  "force": false
}
```

实现位置：

- Flutter 检查、比较版本、下载 APK：`lib/screens/settings_screen.dart`
- Android 安装权限、打开未知应用授权页、调系统安装器：`android/app/src/main/kotlin/com/example/gdut_class_schedule/MainActivity.kt`
- FileProvider 路径：`android/app/src/main/res/xml/file_paths.xml`
- 权限：`android.permission.REQUEST_INSTALL_PACKAGES`
- 通道名：`gdut_update`

更新流程：

1. 用户点击关于页“检查更新”。
2. App 请求 GitHub raw `update.json`，失败时尝试 Gitee 备用地址。
3. 比较 `version` 和 `build`，只有远端更新才提示。
4. 用户点击“下载并安装”。
5. Android 检查是否允许安装未知应用。
6. 未授权则跳系统设置；已授权则下载 APK 到临时目录。
7. 下载完成后通过 FileProvider 生成 content URI，调系统安装器。
8. 下载失败时提示稍后重试或浏览器打开 `fallbackUrl`。

## 最新改动记录

截至当前文档更新，最近一轮改动包括：

- 新增 Android 今日课程桌面小组件，支持浅色、深色和纸张风格。
- 小组件通过 `home_widget` 接收完整课表缓存，Android 原生侧可离线按当天日期计算课程。
- 小组件在午夜、上课、下课、手机时间变化和时区变化时安排事件刷新，系统 30 分钟周期刷新作为兜底。
- 小组件预览、日历图标、文字层级、教室显示和最多 3 行课程窗口已优化。
- 设置页顶部角色图 `assets/settings_mascot.png` 已重新抠成透明 PNG，并清理白边。
- 设置页顶部图片尺寸放大，尽量占住设置页上半部分。
- 设置页使用“设置首页 + 二级页面”结构，返回键返回上一级，不直接退出 App。
- 设置页新增时间问候、App 名称、slogan、考试提示。
- 课表页顶部显示今天日期。
- 课表页问候修正：不再出现“夜安”，凌晨显示晚安。
- 设置页凌晨不再说早安，改为“夜深了，早点休息哦”。
- 悬浮球点击逻辑修复：点击打开卡片，再次点击关闭卡片，拖动不触发开关。
- 悬浮球卡片保持 220dp 宽，避免超出屏幕，带箭头和更清晰边框。
- 悬浮球信息文案更正式：例如 `今日课程已完成~`、`上课中~`。
- 悬浮球待机不再晃动。
- 背景图片保存到 App 本地目录，减少反复从相册加载导致的卡顿和权限问题。
- 关于页检查更新改为 GitHub raw `update.json` 主更新源，Gitee 作为备用，支持 App 内下载并调用系统安装器。
- GitHub `v0.2.2` release 的 APK 已替换为最新构建，不改版本号。

## 设计和维护约定

- 登录和教务抓取逻辑是高风险区，改之前先读 `MainActivity.kt`、`gdut_jw_client.dart` 和 probe 脚本。
- 不要轻易改 `applicationId`，会影响旧版本升级时本地数据延续。
- 课表页信息密度优先，不做大面积营销式布局。
- 背景图只作为氛围，不能影响文字可读性。
- 成绩页、考试页、设置页统一使用毛玻璃风格，但滑动时要注意性能。
- 设置项继续增加时，应放入对应二级页面，不要把设置首页堆成长列表。
- 悬浮球课程判断放 Flutter 侧，Android 侧只显示。
- 原生悬浮窗只拦截悬浮球和卡片区域触摸，不能影响桌面/其他 App 滑动。
- 生成或替换图片资源后，要确认是真透明 PNG，不要把灰白棋盘格烘进图里。
- 新增 release 前要确认用户是否要改版本号；用户可能只想替换已有 release asset。

## 已知注意事项

- Android `targetSdk` 当前为 32，是为了背景图片/相册读取兼容性；`build.gradle.kts` 禁用了 `ExpiredTargetSdkVersion` lint。
- `login_screen.dart` 和 `schedule_screen.dart` 是旧入口，主流程已经在 `HomeScreen`。
- 悬浮球需要系统悬浮窗权限；没权限时只能引导用户去系统设置手动开启。
- Android 13+ 通知权限需要用户授权。
- 教务系统页面和认证流程可能变化，登录失败不能只看 Flutter 层。
- GitHub 凭据、release 签名文件和密码都不能写入仓库。
