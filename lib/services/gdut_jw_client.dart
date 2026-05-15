import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:encrypt/encrypt.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../models/course.dart';
import '../models/exam.dart';
import '../models/grade.dart';
import '../models/term.dart';
import 'cookie_store.dart';
import 'schedule_parser.dart';

class GdutJwClient {
  GdutJwClient({
    http.Client? httpClient,
    Uri? entryUri,
  })  : _httpClient = httpClient ?? _createHttpClient(),
        entryUri = entryUri ??
            Uri.parse(
              'https://authserver.gdut.edu.cn/authserver/login'
              '?service=https%3A%2F%2Fjxfw.gdut.edu.cn%2Fnew%2FssoLogin',
            );

  final http.Client _httpClient;
  final Uri entryUri;
  final CookieStore _cookies = CookieStore();

  Uri? _jwBaseUri;
  String? _nativeUsername;
  String? _nativePassword;
  String? _nativeCachedTermCode;
  List<Course>? _nativeCachedCourses;

  static const MethodChannel _nativeChannel = MethodChannel('gdut_jw');

  static http.Client _createHttpClient() {
    final inner = HttpClient()
      ..badCertificateCallback = (certificate, host, port) {
        return host == 'gdut.edu.cn' || host.endsWith('.gdut.edu.cn');
      };
    return IOClient(inner);
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    if (_shouldUseNativeAndroidClient) {
      final term = Term.now(DateTime.now());
      final courses = await _fetchScheduleNative(
        username: username,
        password: password,
        term: term,
      );
      _nativeUsername = username;
      _nativePassword = password;
      _nativeCachedTermCode = term.gdutTermCode;
      _nativeCachedCourses = courses;
      return;
    }

    _cookies.clear();

    final entryResponse = await _send(
      'GET',
      entryUri,
      followRedirects: false,
    );
    final loginUri = _resolveRedirect(entryUri, entryResponse) ?? entryUri;
    _log('entry ${entryResponse.statusCode} -> $loginUri');

    final loginPage = loginUri == entryUri && entryResponse.statusCode == 200
        ? entryResponse
        : await _send('GET', loginUri);
    _log('login page ${loginPage.statusCode} ${loginPage.request?.url}');
    if (loginPage.statusCode >= 500 ||
        loginPage.body.toLowerCase().contains('bad gateway')) {
      throw LoginException('学校统一认证服务暂时不可用（${loginPage.statusCode}），请稍后再试。');
    }
    final document = html_parser.parse(loginPage.body);
    final form = document.querySelector('form#pwdFromId') ??
        document.querySelector('form[action="/authserver/login"]');

    if (form == null) {
      throw const LoginException('没有找到统一认证登录表单，可能需要验证码或二次认证。');
    }

    final action = form.attributes['action'];
    var postUri = action == null || action.isEmpty
        ? loginPage.request?.url ?? loginUri
        : loginUri.resolve(action);
    if (postUri.query.isEmpty &&
        loginUri.query.isNotEmpty &&
        postUri.host == loginUri.host &&
        postUri.path == loginUri.path) {
      postUri = postUri.replace(queryParameters: loginUri.queryParameters);
    }

    final formValues = <String, String>{};
    for (final input in form.querySelectorAll('input')) {
      final name = input.attributes['name'];
      if (name == null || name.isEmpty) {
        continue;
      }
      formValues[name] = input.attributes['value'] ?? '';
    }

    final fields = <String, String>{
      'username': username.trim(),
      'password': _encryptPassword(
        password,
        document.querySelector('#pwdEncryptSalt')?.attributes['value'],
      ),
      'cllt': formValues['cllt'] ?? 'userNameLogin',
      'dllt': formValues['dllt'] ?? 'generalLogin',
      'lt': formValues['lt'] ?? '',
      'execution': formValues['execution'] ?? '',
      '_eventId': formValues['_eventId'] ?? 'submit',
      'rmShown': '1',
    };
    _log(
      'tokens salt=${document.querySelector('#pwdEncryptSalt')?.attributes['value']?.length ?? 0} '
      'execution=${fields['execution']?.length ?? 0} '
      'password=${fields['password']?.length ?? 0}',
    );
    _log('auth post uri $postUri');
    _log('auth fields ${fields.keys.join(', ')}');

    final authResponse = await _send(
      'POST',
      postUri,
      headers: {
        'Accept': '*/*',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Cache-Control': 'max-age=0',
        'Origin': '${postUri.scheme}://${postUri.host}',
        'Referer': loginUri.toString(),
      },
      body: fields,
      followRedirects: false,
    );
    _log(
      'auth post ${authResponse.statusCode} '
      'location=${authResponse.headers['location'] ?? ''}',
    );

    if (_resolveRedirect(postUri, authResponse) == null) {
      final message = _extractLoginError(authResponse.body);
      final previewLength =
          authResponse.body.length > 300 ? 300 : authResponse.body.length;
      _log('auth body ${authResponse.body.substring(0, previewLength)}');
      if (message != null) {
        throw LoginException(message);
      }
    }

    await _followLoginRedirects(postUri, authResponse);

    final jwBase = _jwBaseUri;
    if (jwBase == null) {
      throw const LoginException('登录后没有进入正方教务系统，请确认账号密码或学校认证策略。');
    }
  }

  Future<List<Course>> fetchSchedule(Term term) async {
    if (_shouldUseNativeAndroidClient) {
      if (_nativeCachedTermCode == term.gdutTermCode &&
          _nativeCachedCourses != null) {
        return _nativeCachedCourses!;
      }

      final username = _nativeUsername;
      final password = _nativePassword;
      if (username == null || password == null) {
        throw StateError('尚未登录教务系统。');
      }

      final courses = await _fetchScheduleNative(
        username: username,
        password: password,
        term: term,
      );
      _nativeCachedTermCode = term.gdutTermCode;
      _nativeCachedCourses = courses;
      return courses;
    }

    final jwBase = _jwBaseUri;
    if (jwBase == null) {
      throw StateError('尚未登录教务系统。');
    }

    final data = await _fetchSchedule(term);
    return ScheduleParser.parse(data);
  }

  Future<List<Grade>> fetchGrades(Term term) async {
    if (_shouldUseNativeAndroidClient) {
      final username = _nativeUsername;
      final password = _nativePassword;
      if (username == null || password == null) {
        throw StateError('尚未登录教务系统。');
      }
      final body =
          await _invokeNativeJson('fetchGrades', username, password, term);
      final data = jsonDecode(body);
      final rows = data is Map<String, dynamic> ? data['rows'] : null;
      if (rows is! List) {
        return const [];
      }
      return rows
          .whereType<Map>()
          .map((item) {
            final row = Map<String, dynamic>.from(item);
            return Grade(
              courseName: _text(row['kcmc']),
              credit: double.tryParse(_text(row['xf'])) ?? 0,
              score: _text(row['zcj'] ?? row['cj']),
              gradePoint: double.tryParse(
                      _text(row['cjjd'] ?? row['jd'] ?? row['jdj'])) ??
                  0,
              academicTerm: _text(row['xnxqmc'] ?? row['xnxqdm']),
              hours: _text(row['xs']),
              courseCategory: _text(row['kcdlmc'] ?? row['kcdl']),
              courseType: _text(row['kcflmc'] ?? row['kcfl']),
              studyMode: _text(row['xdfsmc'] ?? row['xdfs'] ?? row['xsfsmc']),
              examNature: _text(row['ksxzmc'] ?? row['ksxz']),
              gradeMode: _text(row['cjfsmc'] ?? row['cjfs']),
              remark: _text(row['bz'] ?? row['ts']),
            );
          })
          .where((grade) => grade.courseName.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Future<List<Exam>> fetchExams(Term term) async {
    if (_shouldUseNativeAndroidClient) {
      final username = _nativeUsername;
      final password = _nativePassword;
      if (username == null || password == null) {
        throw StateError('尚未登录教务系统。');
      }
      final body =
          await _invokeNativeJson('fetchExams', username, password, term);
      final data = jsonDecode(body);
      final rows = data is Map<String, dynamic> ? data['rows'] : null;
      if (rows is! List) {
        return const [];
      }
      return rows
          .whereType<Map>()
          .map((item) {
            final row = Map<String, dynamic>.from(item);
            final date =
                DateTime.tryParse(_text(row['ksrq'])) ?? DateTime.now();
            final time = _text(row['kssj']).split('--').first;
            final parts = time.split(':');
            final examTime = parts.length == 2
                ? DateTime(
                    date.year,
                    date.month,
                    date.day,
                    int.tryParse(parts[0]) ?? 0,
                    int.tryParse(parts[1]) ?? 0,
                  )
                : date;
            return Exam(
              courseName: _text(row['kcmc']),
              time: examTime,
              location: _text(row['kscdmc']),
              seatNumber: _text(row['zwh']),
            );
          })
          .where((exam) => exam.courseName.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Future<String> _invokeNativeJson(
    String method,
    String username,
    String password,
    Term term,
  ) async {
    try {
      return await _nativeChannel.invokeMethod<String>(
            method,
            {
              'username': username.trim(),
              'password': password,
              'termCode': term.gdutTermCode,
            },
          ) ??
          '{}';
    } on PlatformException catch (error) {
      throw ScheduleException(error.message ?? '接口请求失败');
    }
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';

  Future<Map<String, dynamic>> _fetchSchedule(Term term) async {
    final jwBase = _jwBaseUri;
    if (jwBase == null) {
      throw StateError('尚未登录教务系统。');
    }

    final scheduleUri = jwBase.resolve('/xsgrkbcx!getDataList.action');
    final response = await _send(
      'POST',
      scheduleUri,
      headers: {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Referer': jwBase
            .resolve('/xsgrkbcx!xskbList2.action?xnxqdm=${term.gdutTermCode}')
            .toString(),
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: {
        'xnxqdm': term.gdutTermCode,
        'zc': '',
        'page': '1',
        'rows': '500',
        'sort': 'kxh',
        'order': 'asc',
      },
    );

    if (response.statusCode != 200) {
      throw ScheduleException('课表接口返回 ${response.statusCode}。');
    }

    final rawBody = response.body.trimLeft();
    if (!rawBody.startsWith('{')) {
      throw const ScheduleException('教务系统返回了网页页面，登录态可能已失效，请重新登录后再刷新课表。');
    }

    final data = jsonDecode(rawBody);
    if (data is! Map<String, dynamic>) {
      throw const ScheduleException('课表接口返回格式异常。');
    }
    return data;
  }

  bool get _shouldUseNativeAndroidClient =>
      Platform.isAndroid && !const bool.fromEnvironment('GDUT_FORCE_DART');

  Future<List<Course>> _fetchScheduleNative({
    required String username,
    required String password,
    required Term term,
  }) async {
    try {
      final body = await _nativeChannel.invokeMethod<String>(
        'fetchSchedule',
        {
          'username': username.trim(),
          'password': password,
          'termCode': term.gdutTermCode,
        },
      );
      final data = jsonDecode(body ?? '{}');
      if (data is! Map<String, dynamic>) {
        throw const ScheduleException('课表接口返回格式异常。');
      }
      return ScheduleParser.parse(data);
    } on PlatformException catch (error) {
      throw LoginException(error.message ?? '认证失败');
    }
  }

  Future<void> _followLoginRedirects(
    Uri startUri,
    http.Response firstResponse,
  ) async {
    var response = firstResponse;
    var currentUri = startUri;

    for (var i = 0; i < 12; i++) {
      final next = _resolveRedirect(currentUri, response);
      if (next == null) {
        _captureJwBase(currentUri);
        return;
      }

      currentUri = next;
      _log('redirect ${response.statusCode} -> $currentUri');
      _captureJwBase(currentUri);
      response = await _send('GET', currentUri, followRedirects: false);
      _log('redirect response ${response.statusCode} ${response.request?.url}');
      _captureJwBase(response.request?.url ?? currentUri);
    }

    throw const LoginException('统一认证跳转次数过多，登录流程可能已变化。');
  }

  void _log(String message) {
    developer.log(message, name: 'GdutJwClient');
    if (const bool.fromEnvironment('GDUT_DEBUG')) {
      // ignore: avoid_print
      print('GdutJwClient: $message');
    }
  }

  void _captureJwBase(Uri uri) {
    if (uri.host == 'jxfw.gdut.edu.cn' &&
        (uri.path.contains('/new/ssoLogin') ||
            uri.path.contains('/login!welcome.action') ||
            uri.path.contains('/xsgrkbcx'))) {
      _jwBaseUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
      );
    }
  }

  Uri? _resolveRedirect(Uri base, http.Response response) {
    if (response.statusCode < 300 || response.statusCode >= 400) {
      return null;
    }

    final location = response.headers['location'];
    if (location == null || location.isEmpty) {
      return null;
    }
    return base.resolve(location);
  }

  String? _extractLoginError(String html) {
    final document = html_parser.parse(html);
    final errorText = document.querySelector('#showErrorTip')?.text.trim();
    if (errorText != null && errorText.isNotEmpty) {
      return errorText;
    }
    if (html.contains('Internal Server Error')) {
      return '统一认证服务返回 500，登录参数可能已变化。';
    }
    return null;
  }

  String _encryptPassword(String password, String? salt) {
    final normalizedSalt = salt?.trim() ?? '';
    if (normalizedSalt.length != 16) {
      return password;
    }

    final key = crypto.Key.fromUtf8(normalizedSalt);
    final iv = crypto.IV.fromUtf8(_randomString(16));
    final encrypter = crypto.Encrypter(
      crypto.AES(key, mode: crypto.AESMode.cbc, padding: 'PKCS7'),
    );

    return encrypter.encrypt('${_randomString(64)}$password', iv: iv).base64;
  }

  String _randomString(int length) {
    const chars = 'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Map<String, String>? body,
    bool followRedirects = true,
  }) async {
    final request = http.Request(method, uri)
      ..followRedirects = followRedirects
      ..headers.addAll({
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 GDUTSchedule/0.1',
        ...?headers,
      });

    final cookieHeader = _cookies.headerFor(uri);
    if (cookieHeader.isNotEmpty) {
      request.headers['Cookie'] = cookieHeader;
      _log(
          'send cookies ${uri.host} ${_cookies.debugNamesFor(uri).join(', ')}');
    }

    if (body != null) {
      request.headers['Content-Type'] =
          'application/x-www-form-urlencoded; charset=UTF-8';
      request.body = body.entries
          .map(
            (entry) => '${Uri.encodeQueryComponent(entry.key)}='
                '${Uri.encodeQueryComponent(entry.value)}',
          )
          .join('&');
    }

    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    _cookies.saveFrom(uri, response.headersSplitValues['set-cookie']);
    final setCookie = response.headersSplitValues['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      _log('set-cookie ${uri.host} ${setCookie.length}');
    }
    _captureJwBase(response.request?.url ?? uri);
    return response;
  }
}

class LoginException implements Exception {
  const LoginException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ScheduleException implements Exception {
  const ScheduleException(this.message);

  final String message;

  @override
  String toString() => message;
}
