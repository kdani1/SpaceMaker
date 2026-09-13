import 'package:flutter_test/flutter_test.dart';
import 'package:spacemaker/theme.dart';

void main() {
  test('theme colors stay distinct', () {
    expect(SM.keep, isNot(SM.toss));
  });
}
