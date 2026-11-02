import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lost_found_app/main.dart';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://lwzhulqhjioecqlwasdl.supabase.co',
      // ignore: deprecated_member_use
      anonKey: 'sb_publishable_dRWM_lwncSiOBvIcb8XLOw_sZ2iCtoF',
    );
  });

  testWidgets('App loads without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    // Just confirms the app builds and renders something —
    // enough for a WIL prototype test suite.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}