import 'package:flutter_test/flutter_test.dart';
import 'package:pnp_studio/main.dart';
import 'package:pnp_studio/strings.dart';

void main() {
  testWidgets('home screen shows project actions', (tester) async {
    await tester.pumpWidget(const PnpStudioApp());

    expect(find.text(Strings.newGridProject), findsOneWidget);
    expect(find.text(Strings.newFreeformProject), findsOneWidget);
    expect(find.text(Strings.openProject), findsOneWidget);
  });
}
