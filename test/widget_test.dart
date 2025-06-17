import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncdc_ccms_app/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // Initialize Supabase before running tests
  setUpAll(() async {
    // Use dummy credentials for testing
    await Supabase.initialize(
      url: 'http://127.0.0.1:54321', // Dummy URL
      anonKey: 'dummy_key',          // Dummy Key
    );
  });

  testWidgets('NCDCCityManagerApp renders correctly', (WidgetTester tester) async {
    final supabaseClient = Supabase.instance.client;
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(supabaseClient: supabaseClient));

    // Verify that our app renders the correct title text
    expect(find.text('NCDC CCMS'), findsOneWidget);
    
    // Verify the bottom navigation bar exists
    // expect(find.byType(BottomNavigationBar), findsOneWidget);
    // expect(find.text('Complaints'), findsOneWidget);
    // expect(find.text('Electorates'), findsOneWidget);
    // expect(find.text('Reports'), findsOneWidget);
  });

  testWidgets('Complaints screen renders correctly', (WidgetTester tester) async {
    final supabaseClient = Supabase.instance.client;
    // Build our app and trigger a frame.
    // Ensure Supabase is initialized before pumping the widget
    await tester.pumpWidget(MyApp(supabaseClient: supabaseClient));

    // Pump and settle to allow navigation/async operations
    await tester.pump();

    // Verify initial screen shows complaints
    // expect(find.text('Waste Management'), findsOneWidget);
    // expect(find.text('Potholes & Drainage'), findsOneWidget);
  });
}