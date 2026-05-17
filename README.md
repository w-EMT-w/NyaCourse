# NyaCourse

一个 Flutter Android 课表 App，面向广东工业大学教务系统 `https://jxfw.gdut.edu.cn`。

更完整的项目结构、数据流程、导入格式和正式版打包说明见 [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)。

## 功能

- 使用 GDUT 统一认证登录教务系统。
- 打开后默认进入每周课表，支持滑动切换周次、刷新课表、长按课程备注。
- 使用教务系统 `pkrq` 日期校准教学周，避免周次日期偏移。
- 支持课表、成绩、考试安排本地缓存，没网时可查看上次数据。
- 支持成绩详情、考试倒计时、座位号兜底显示。
- 支持本地课表导入：JSON / CSV / TXT / XLSX。
- 支持课前提醒、本地通知。
- 支持背景图片、主题色、自定义主题色、毛玻璃卡片、字体颜色设置。

## 注意

GDUT 当前入口会跳转到统一认证，再进入正方系统。若学校后续启用验证码、滑块、短信二次认证或更换统一认证参数，需要优先检查 `android/app/src/main/kotlin/com/example/gdut_class_schedule/MainActivity.kt` 和 `lib/services/gdut_jw_client.dart`。
