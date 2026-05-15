class CookieStore {
  final Map<String, _StoredCookie> _cookies = {};

  String headerFor(Uri uri) {
    return _matchingCookies(uri)
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
  }

  void saveFrom(Uri uri, List<String>? values) {
    if (values == null) {
      return;
    }

    for (final value in values) {
      final pair = value.split(';').first;
      final index = pair.indexOf('=');
      if (index <= 0) {
        continue;
      }

      final cookie = _StoredCookie(
        host: uri.host,
        name: pair.substring(0, index),
        value: pair.substring(index + 1),
      );
      _cookies['${cookie.host}|${cookie.name}'] = cookie;
    }
  }

  void clear() => _cookies.clear();

  List<String> debugNamesFor(Uri uri) {
    return _matchingCookies(uri)
        .map((cookie) => '${cookie.host}:${cookie.name}')
        .toList();
  }

  Iterable<_StoredCookie> _matchingCookies(Uri uri) {
    return _cookies.values.where((cookie) {
      return uri.host == cookie.host || uri.host.endsWith('.${cookie.host}');
    });
  }
}

class _StoredCookie {
  const _StoredCookie({
    required this.host,
    required this.name,
    required this.value,
  });

  final String host;
  final String name;
  final String value;
}
