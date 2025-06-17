import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import 'complaint_provider.dart'; // Import the provider
import 'complaint_service.dart'; // Import ComplaintService
import 'login_page.dart';        // Import LoginPage
import 'image_service.dart'; // Import ImageService
import 'home_feed_screen.dart';
import 'widgets/custom_bottom_navbar.dart';
import 'map_screen.dart';
import 'reports_page.dart';
import 'add_complaint_dialog.dart';

// TODO: Replace with your actual Supabase URL and Anon Key
const String supabaseUrl = 'https://mdyzvdvbodwryycqlptn.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1keXp2ZHZib2R3cnl5Y3FscHRuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU3MDA0OTEsImV4cCI6MjA2MTI3NjQ5MX0.WZVogJwmtNF0mEMx36PrbLM71O1oNV0snk8FshSz9sg';

// Define Mapbox Access Token here (copied from map_screen.dart)
// TODO: Consider moving sensitive keys to environment variables or a config file for better security
const String mapboxAccessToken = 'pk.eyJ1Ijoiam9obnNraXBvbGkiLCJhIjoiY201c3BzcDYxMG9neDJscTZqeXQ4MGk4YSJ9.afrO8Lq1P6mIUbSyQ6VCsQ';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set Mapbox access token once
  mapbox.MapboxOptions.setAccessToken(mapboxAccessToken);

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final supabaseClient = Supabase.instance.client;
  final complaintService = ComplaintService(supabaseClient);
  final imageService = ImageService(supabaseClient: supabaseClient);

  runApp(
    MultiProvider(
      providers: [
        Provider<ComplaintService>.value(value: complaintService),
        Provider<ImageService>.value(value: imageService),
        ChangeNotifierProvider<ComplaintProvider>(
          create: (_) => ComplaintProvider(complaintService),
        ),
      ],
      child: MyApp(supabaseClient: supabaseClient),
    ),
  );
}

class MyApp extends StatelessWidget {
  final SupabaseClient supabaseClient;
  const MyApp({super.key, required this.supabaseClient});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NCDC CCMS',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AuthRedirect(supabaseClient: supabaseClient),
      routes: {
        '/home': (context) => const HomeFeedScreen(),
        '/login': (context) => LoginPage(supabaseClient: supabaseClient),
      },
    );
  }
}

class AuthRedirect extends StatefulWidget {
  final SupabaseClient supabaseClient;
  const AuthRedirect({super.key, required this.supabaseClient});

  @override
  AuthRedirectState createState() => AuthRedirectState();
}

class AuthRedirectState extends State<AuthRedirect> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = widget.supabaseClient.auth.onAuthStateChange.listen((data) {
      _redirect();
    });
    _redirect();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _redirect() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final session = widget.supabaseClient.auth.currentSession;
      final currentRoute = ModalRoute.of(context)?.settings.name;

      if (session != null && currentRoute != '/home') {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      } else if (session == null && currentRoute != '/login') {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeFeedScreen(),
      MapScreen(onBack: () => _navigateTo(0)),
      const ReportsPage(),
      const Center(child: Text("Profile")), // Placeholder for Profile Screen
    ];
  }

  void _navigateTo(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _showAddComplaintDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddComplaintDialog(
          complaintProvider: Provider.of<ComplaintProvider>(context, listen: false),
          imageService: Provider.of<ImageService>(context, listen: false),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddComplaintDialog,
        backgroundColor: const Color(0xFFFDB418), // Yellow color from image
        child: const Icon(Icons.add, color: Colors.black),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNavbar(
        activeIndex: _currentIndex,
        onTabChanged: _navigateTo,
      ),
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
