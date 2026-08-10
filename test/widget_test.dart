import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:photobox_pro/main.dart';

void main() {
  test('scroll behavior accepts kiosk pointer devices', () {
    const behavior = PhotoboxScrollBehavior();

    expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
    expect(behavior.dragDevices, contains(PointerDeviceKind.stylus));
    expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
  });
}
