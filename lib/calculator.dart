/// Recursive descent arithmetic; no eval or executable expressions.
double calculate(String source) {
  if (source.isEmpty || source.length > 120) throw const FormatException('Expression length');
  final parser = _Parser(source.replaceAll('×', '*').replaceAll('÷', '/'));
  final value = parser.expression();
  parser.space();
  if (parser.index != parser.source.length || !value.isFinite) {
    throw const FormatException('Invalid calculation');
  }
  return value;
}

class _Parser {
  final String source;
  int index = 0;
  _Parser(this.source);
  void space() {
    while (index < source.length && source[index] == ' ') { index++; }
  }
  bool take(String char) {
    space();
    if (index < source.length && source[index] == char) { index++; return true; }
    return false;
  }
  double expression() {
    var value = term();
    while (true) {
      if (take('+')) { value += term(); }
      else if (take('-')) { value -= term(); }
      else { return value; }
    }
  }
  double term() {
    var value = factor();
    while (true) {
      if (take('*')) { value *= factor(); }
      else if (take('/')) {
        final divisor = factor();
        if (divisor == 0) throw const FormatException('Division by zero');
        value /= divisor;
      } else { return value; }
    }
  }
  double factor() {
    if (take('+')) return factor();
    if (take('-')) return -factor();
    if (take('(')) {
      final value = expression();
      if (!take(')')) throw const FormatException('Missing closing parenthesis');
      return value;
    }
    space();
    final start = index;
    while (index < source.length && '0123456789.'.contains(source[index])) { index++; }
    if (start == index) throw const FormatException('Expected number');
    return double.parse(source.substring(start, index));
  }
}
