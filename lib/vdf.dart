/// Minimal parser for Valve's KeyValues (VDF) text format, as used by
/// libraryfolders.vdf and appmanifest_*.acf.
///
/// Produces nested `Map<String, Object?>` trees whose leaves are strings.
/// Duplicate keys collapse to the last value, which is fine for the files
/// this app reads (library folders and app manifests have unique keys at
/// each level that we care about).
class Vdf {
  final String _src;
  int _pos = 0;

  Vdf._(this._src);

  static Map<String, Object?> parse(String source) {
    final p = Vdf._(source);
    final result = p._parseBlock(topLevel: true);
    return result;
  }

  Map<String, Object?> _parseBlock({bool topLevel = false}) {
    final map = <String, Object?>{};
    while (true) {
      _skipWhitespaceAndComments();
      if (_pos >= _src.length) break;
      if (_src[_pos] == '}') {
        _pos++;
        if (topLevel) continue;
        break;
      }
      final key = _parseString();
      _skipWhitespaceAndComments();
      if (_pos < _src.length && _src[_pos] == '{') {
        _pos++;
        map[key] = _parseBlock();
      } else {
        final value = _parseString();
        map[key] = value;
        _skipConditional();
      }
    }
    return map;
  }

  void _skipWhitespaceAndComments() {
    while (_pos < _src.length) {
      final c = _src[_pos];
      if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
        _pos++;
      } else if (c == '/' && _pos + 1 < _src.length && _src[_pos + 1] == '/') {
        while (_pos < _src.length && _src[_pos] != '\n') {
          _pos++;
        }
      } else {
        break;
      }
    }
  }

  /// Conditional tags like [$WIN32] may follow a value; skip them.
  void _skipConditional() {
    final save = _pos;
    _skipWhitespaceAndComments();
    if (_pos < _src.length && _src[_pos] == '[') {
      while (_pos < _src.length && _src[_pos] != ']') {
        _pos++;
      }
      if (_pos < _src.length) _pos++;
    } else {
      _pos = save;
    }
  }

  String _parseString() {
    _skipWhitespaceAndComments();
    if (_pos >= _src.length) return '';
    if (_src[_pos] == '"') {
      _pos++;
      final buf = StringBuffer();
      while (_pos < _src.length) {
        final c = _src[_pos];
        if (c == '\\' && _pos + 1 < _src.length) {
          final n = _src[_pos + 1];
          if (n == 'n') {
            buf.write('\n');
          } else if (n == 't') {
            buf.write('\t');
          } else {
            buf.write(n);
          }
          _pos += 2;
        } else if (c == '"') {
          _pos++;
          break;
        } else {
          buf.write(c);
          _pos++;
        }
      }
      return buf.toString();
    }
    // Unquoted token.
    final start = _pos;
    while (_pos < _src.length &&
        !' \t\r\n{}'.contains(_src[_pos])) {
      _pos++;
    }
    return _src.substring(start, _pos);
  }
}
