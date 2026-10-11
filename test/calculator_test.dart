import 'package:flutter_test/flutter_test.dart';
import 'package:ciphercalc/calculator.dart';

void main() {
  test('precedence, parentheses, signs and decimals', () {
    expect(calculate('12*16'), 192);
    expect(calculate('1+2*3'), 7);
    expect(calculate('(1+2)*3'), 9);
    expect(calculate('-2*-3'), 6);
    expect(calculate('0.5+1.25'), 1.75);
    expect(calculate('12÷4×2'), 6);
    expect(calculate(' 1 + 2 '), 3);
    expect(calculate('192'), calculate('12*16'));
  });
  test('reject malformed expressions and nonfinite results', () {
    for (final value in ['', '1/0', '(2+3', '2..3', '1abc', '1;print(2)', '1 2', '()', '2+', '2**3']) {
      expect(() => calculate(value), throwsFormatException, reason: value);
    }
    expect(() => calculate('1' * 121), throwsFormatException);
  });
}
