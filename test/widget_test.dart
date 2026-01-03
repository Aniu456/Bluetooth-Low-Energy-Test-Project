import 'package:flutter_test/flutter_test.dart';

import 'package:ble_test/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const BleTestApp());

    expect(find.text('蓝牙设备扫描'), findsOneWidget);
  });
}
