import 'package:flutter_test/flutter_test.dart';
import 'package:shipping_hub/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ShippingHubApp());
    expect(find.text('Shipping Hub'), findsAny);
  });
}
