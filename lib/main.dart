import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart'; // Import Provider

import 'login_page.dart';
import 'city_data_dashboard.dart';
import 'complaint_provider.dart'; // Import ComplaintProvider
import 'complaint_service.dart'; // Import ComplaintService
import 'image_service.dart'; // Import ImageService

// TODO: Replace with your actual Supabase URL and Anon Key
const String supabaseUrl = 'https://mdyzvdvbodwryycqlptn.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1keXp2ZHZib2R3cnl5Y3FscHRuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU3MDA0OTEsImV4cCI6MjA2MTI3NjQ5MX0.WZVogJwmtNF0mEMx36PrbLM71O1oNV0snk8FshSz9sg';

// Define Mapbox Access Token here (copied from map_screen.dart)
// TODO: Consider moving sensitive keys to environment variables or a config file for better security
const String mapboxAccessToken = 'pk.eyJ1Ijoiam9obnNraXBvbGkiLCJhIjoiY201c3BzcDYxMG9neDJscTZqeXQ4MGk4YSJ9.afrO8Lq1P6mIUbSyQ6VCsQ';

// REMOVE Global Supabase client variable
// late SupabaseClient supabase;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Set Mapbox Access Token for MapLibre ---
  // The token is now set in AndroidManifest.xml for native integration.
  // MapLibreMap.setAccessToken(mapboxAccessToken); // ERROR: Method doesn't exist on MapLibreMap. Token must be provided via AndroidManifest.xml or gradle.properties for mapbox:// styles.

  // --- Initialize Supabase ---
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Get the Supabase client instance *after* initialization
  final supabaseClient = Supabase.instance.client;

  // Create service instances, passing the client
  final complaintService = ComplaintService(supabaseClient: supabaseClient);
  final imageService = ImageService(supabaseClient: supabaseClient);

  runApp(
    MultiProvider( // Use MultiProvider
      providers: [
        ChangeNotifierProvider(
          create: (context) => ComplaintProvider(complaintService),
        ),
        Provider<ImageService>(
          create: (_) => imageService,
        ),
        // Optionally provide SupabaseClient itself if needed directly by widgets
        // Provider<SupabaseClient>(create: (_) => supabaseClient),
      ],
      // Pass the client to MyApp/AuthRedirect
      child: MyApp(supabaseClient: supabaseClient),
    ),
  );
}

class MyApp extends StatelessWidget {
  final SupabaseClient supabaseClient;
  const MyApp({super.key, required this.supabaseClient}); // Add client to constructor

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NCDC CCMS',
      theme: ThemeData(
        primarySwatch: Colors.green, // Or your preferred theme color
        visualDensity: VisualDensity.adaptivePlatformDensity,
         inputDecorationTheme: const InputDecorationTheme( // Consistent input decoration
          border: OutlineInputBorder(),
          filled: true,
         // fillColor: Colors.grey[200], // Optional: background color for inputs
        ),
         elevatedButtonTheme: ElevatedButtonThemeData( // Consistent button style
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48), // Wider buttons
            // backgroundColor: Colors.green, // Button color
            // foregroundColor: Colors.white, // Text color
             shape: RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ),
      home: AuthRedirect(supabaseClient: supabaseClient),
    );
  }
}

class AuthRedirect extends StatefulWidget {
  final SupabaseClient supabaseClient; // Add client field
  const AuthRedirect({super.key, required this.supabaseClient}); // Require client in constructor

  @override
  State<AuthRedirect> createState() => _AuthRedirectState();
}

class _AuthRedirectState extends State<AuthRedirect> {
  Stream<AuthState>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    // Use the client passed via widget property
    _authStateSubscription = widget.supabaseClient.auth.onAuthStateChange;
    _redirect(); // Check initial state
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _redirect() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final session = widget.supabaseClient.auth.currentSession;
    if (session != null) {
      // TODO: Pass SupabaseClient to CityDataDashboard if needed
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const CityDataDashboard()), 
      );
    } else {
      // Pass the client to LoginPage
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginPage(supabaseClient: widget.supabaseClient)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      // Use the client passed via widget property
      stream: _authStateSubscription,
      builder: (context, snapshot) {
        // Use the client passed via widget property
        if (snapshot.connectionState == ConnectionState.waiting &&
            widget.supabaseClient.auth.currentSession == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
        }

        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

// You might need to adjust the placeholder MyHomePage or remove it
// if CityDataDashboard is your primary logged-in view.
class MyHomePage extends StatelessWidget {
 const MyHomePage({super.key, required this.title});

 final String title;

 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(
       title: Text(title),
     ),
     body: Center(
       child: Text('Placeholder Home Page - Should be replaced by CityDataDashboard'),
     ),
   );
 }
}
