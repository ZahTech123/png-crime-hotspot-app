import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart'; // Import Provider

import 'login_page.dart';
import 'city_data_dashboard.dart';
import 'complaint_provider.dart'; // Import ComplaintProvider
import 'complaint_service.dart'; // Import ComplaintService
import 'image_service.dart'; // Import ImageService
import 'providers/performance_provider.dart'; // Import PerformanceProvider
import 'utils/logger.dart'; // Import AppLogger
import 'map_screen/map_icon_service.dart'; // Import MapIconService

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

  // Initialize MapIconService early for optimized map performance
  try {
    await MapIconService.instance.initialize();
    AppLogger.i('[Main] MapIconService initialized successfully');
  } catch (e) {
    AppLogger.w('[Main] MapIconService initialization failed, will use fallback: $e');
  }

  runApp(NCDCApp(supabaseClient: supabaseClient));
}

class NCDCApp extends StatelessWidget {
  final SupabaseClient supabaseClient;

  const NCDCApp({super.key, required this.supabaseClient});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Add PerformanceProvider first for monitoring
        ChangeNotifierProvider(
          create: (context) => PerformanceProvider(),
        ),
        // Initialize ComplaintService with the Supabase client
        Provider<ComplaintService>(
          create: (context) => ComplaintService(supabaseClient: supabaseClient),
        ),
        // Initialize ImageService with the Supabase client
        Provider<ImageService>(
          create: (context) => ImageService(supabaseClient: supabaseClient),
        ),
        // Create ComplaintProvider which depends on ComplaintService
        ChangeNotifierProxyProvider<ComplaintService, ComplaintProvider>(
          create: (context) => ComplaintProvider(
            Provider.of<ComplaintService>(context, listen: false),
          ),
          update: (context, complaintService, previousProvider) {
            // If the service changes, update the provider
            return previousProvider ?? ComplaintProvider(complaintService);
          },
        ),
      ],
      child: Builder( // Use Builder to get context for Theme
        builder: (context) {
          // Access PerformanceProvider if needed for theme decisions, though not directly used here
          // final performanceProvider = Provider.of<PerformanceProvider>(context, listen: false);

          // Define light and dark themes
          final ThemeData lightTheme = ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            // Add other light theme specific properties here
          );

          final ThemeData darkTheme = ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blue, // Or a different swatch for dark mode
            scaffoldBackgroundColor: Colors.grey[850], // Darker background
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.grey[900], // Darker AppBar
              elevation: 1, // Subtle elevation
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
              iconTheme: IconThemeData(color: Colors.white),
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            cardColor: Colors.grey[800],
            textTheme: TextTheme( // Ensure text is legible on dark backgrounds
              bodyLarge: TextStyle(color: Colors.white70),
              bodyMedium: TextStyle(color: Colors.white70),
              titleLarge: TextStyle(color: Colors.white),
              // Define other text styles as needed
            ),
            iconTheme: IconThemeData(color: Colors.white70), // Default icon color
            // Add other dark theme specific properties here
          );

          // For this step, we'll manually toggle. Later, a ThemeProvider could manage this.
          // For now, we assume MapNotifier is the source of truth for dark mode on MapScreen.
          // If a global theme provider is introduced, this logic would change.

          return MaterialApp(
            title: 'NCDC CCMS',
            theme: lightTheme, // Default theme
            darkTheme: darkTheme, // Dark theme
            // ThemeMode will be controlled by a global theme provider eventually.
            // For now, MapScreen will handle its own theming based on MapNotifier.
            // If we want MaterialApp to control the theme globally, we'd need a ThemeProvider here.
            home: AuthRedirect(supabaseClient: supabaseClient),
            debugShowCheckedModeBanner: false, // Remove debug banner for cleaner look
            builder: (context, child) {
              return MemoryPressureIntegration(child: child!);
            },
          );
        }
      ),
    );
  }
}

/// PHASE 1: Widget to integrate PerformanceProvider with ImageService for memory pressure handling
class MemoryPressureIntegration extends StatefulWidget {
  final Widget child;
  
  const MemoryPressureIntegration({super.key, required this.child});

  @override
  State<MemoryPressureIntegration> createState() => _MemoryPressureIntegrationState();
}

class _MemoryPressureIntegrationState extends State<MemoryPressureIntegration> {
  bool _integrationInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize integration once providers are available
    if (!_integrationInitialized) {
      _initializeMemoryPressureIntegration();
      _integrationInitialized = true;
    }
  }

  /// PHASE 1: Wire up memory pressure callbacks between providers
  void _initializeMemoryPressureIntegration() {
    try {
      // Add safety check to ensure providers are available
      if (!mounted) return;
      
      final performanceProvider = Provider.of<PerformanceProvider>(context, listen: false);
      final imageService = Provider.of<ImageService>(context, listen: false);
      
      // Providers should be available at this point, but add defensive check
      // (Note: In Flutter Provider pattern, these should never be null here)
      
      // Register ImageService cache clearing as a memory pressure callback
      performanceProvider.registerMemoryPressureCallback(() {
        try {
          if (!mounted) return; // Safety check
          
          imageService.clearCacheUnderPressure();
          
          // Log the cache info after clearing for monitoring
          final cacheInfo = imageService.getCacheInfo();
          AppLogger.i('[MemoryPressureIntegration] Cache cleared under pressure. Remaining items: ${cacheInfo['cacheItems']}, size: ${cacheInfo['cacheSizeKB']}KB');
          
        } catch (e) {
          AppLogger.e('[MemoryPressureIntegration] Error clearing image cache under pressure', e);
        }
      });
      
      AppLogger.i('[MemoryPressureIntegration] Memory pressure integration initialized successfully');
      
    } catch (e) {
      AppLogger.e('[MemoryPressureIntegration] Error initializing memory pressure integration', e);
      // Don't crash the app if integration fails
    }
  }

  @override
  void dispose() {
    // Dispose of MapIconService when app shuts down
    try {
      MapIconService.instance.dispose();
      AppLogger.i('[MemoryPressureIntegration] MapIconService disposed');
    } catch (e) {
      AppLogger.w('[MemoryPressureIntegration] Error disposing MapIconService: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
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
