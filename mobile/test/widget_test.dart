import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kartabel/main.dart';

void main() {
  testWidgets('صفحه ورود نمایش داده می‌شود', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const KartabelApp());
    await tester.pumpAndSettle();
    expect(find.text('کارتابل'), findsOneWidget);
    expect(find.text('ورود'), findsOneWidget);
  });
}
