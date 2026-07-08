import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:article_sum_mobile/main.dart';

void main() {
  testWidgets('bottom nav switches tabs', (WidgetTester tester) async {
    // Explicitly cleared config, to exercise the "not configured" state —
    // the app ships with a real default project, so an empty override is
    // needed to hit this path in tests.
    SharedPreferences.setMockInitialValues({
      'supabase_url': '',
      'supabase_anon_key': '',
    });
    await tester.pumpWidget(const ArticleSummaryApp());
    await tester.pump();

    expect(find.text('Pending Approval'), findsOneWidget);
    expect(find.textContaining('Supabase is not configured'), findsOneWidget);

    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Archive'), findsWidgets);
    expect(find.textContaining('Supabase is not configured'), findsOneWidget);
  });
}
