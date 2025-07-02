import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'models.dart';
import 'edit_complaint_dialog.dart';
import 'complaints/complaints_list.dart';
import 'complaint_provider.dart'; 
import 'complaint_service.dart'; 
import 'image_service.dart'; 
import 'map_screen/map_screen.dart'; // Import the map screen
import 'utils/responsive.dart'; // Correct import path
import 'utils/logger.dart';
import 'reports_page.dart'; // Import the ReportsPage widget

// Remove Placeholder Models Location and TravelMode

class CityDataDashboard extends StatefulWidget {
  const CityDataDashboard({super.key});

  @override
  State<CityDataDashboard> createState() => _CityDataDashboardState();
}

class _CityDataDashboardState extends State<CityDataDashboard> {
  // --- Dashboard State Variables ---
  int _currentIndex = 0; // Index for BottomNavBar (Complaints, Electorates, Reports, Map)
  
  // Lazy loading futures - only created when tabs are accessed
  Future<List<CityElectorate>>? _electoratesFuture;
  // --- NEW: Future for initial complaints load ---
  Future<void>? _complaintsFuture;
  // ----------------------------------------------

  // Filters - Keep if needed for filter dialog
  String selectedIssueType = 'Select an issue type';
  String selectedDirectorate = 'Select a directorate';

  // Access Services via Provider
  late ComplaintService _complaintService; 
  // Keep ImageService if needed by dialogs
  late ImageService _imageService; 

  // --- Restore Placeholder Data & Widgets ---
  // Remove _popularLocations, _categories, _travelModes
  // Remove _buildPopularLocations, _buildLocationCards, _buildTrafficTravel, _onCategorySelected

  @override
  void initState() {
    super.initState();
    // Initialize services only - no heavy data loading
    _complaintService = Provider.of<ComplaintProvider>(context, listen: false).complaintService; 
    _imageService = Provider.of<ImageService>(context, listen: false);
    
    // --- REFACTORED: Assign the future here, don't just call the method ---
    // Trigger initial loading of complaints via provider
    _complaintsFuture = Provider.of<ComplaintProvider>(context, listen: false).refreshComplaints();
    // --------------------------------------------------------------------
  }

  // --- Optimized Async Data Loading Method (uses bulk operations) ---
  Future<List<CityElectorate>> _loadElectorateData() async {
    // Add small delay to let UI render first
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      // Use optimized bulk electorate stats fetching (single database query)
      final allStats = await _complaintService.getAllElectorateStats();
      
      final electorateNames = allStats['electorates'] as List<String>? ?? [];
      final electorateDetails = allStats['electorate_details'] as Map<String, dynamic>? ?? {};
      
      if (electorateNames.isEmpty) {
        return <CityElectorate>[];
      }

      // Process results synchronously from bulk data
      final List<CityElectorate> loadedElectorates = [];
      
      for (final name in electorateNames) {
        final details = electorateDetails[name] as Map<String, dynamic>?;
        if (details != null) {
          final suburbs = (details['suburbs'] as List<dynamic>?)?.cast<String>() ?? [];
          final count = details['count'] as int? ?? 0;
          
          loadedElectorates.add(CityElectorate(
            id: name.toLowerCase().replaceAll(' ', '_'),
            name: name,
            totalComplaints: count,
            suburbs: suburbs,
          ));
        }
      }

      AppLogger.d('[Dashboard] Loaded ${loadedElectorates.length} electorates using bulk operations');
      return loadedElectorates;
      
    } catch (e) {
      AppLogger.e('[Dashboard] Error loading electorate data', e);
      // Fallback to empty list on error
      return <CityElectorate>[];
    }
  }

  // --- Bottom Nav Tapped Logic (Updated for Lazy Loading) ---
  void _onBottomNavTapped(int index) {
    // Check if the map icon (index 3) was tapped
    if (index == 3) { 
      // Navigate to MapScreen without changing the bottom nav index
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MapScreen()),
      );
    } else {
      // Only update state if it's not the map tab
      setState(() {
        _currentIndex = index;
        
        // Initialize data loading futures only when tabs are accessed (lazy loading)
        if (index == 1 && _electoratesFuture == null) {
          _electoratesFuture = _loadElectorateData();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    // Access ComplaintProvider needed for _buildComplaintsScreen
    final complaintProvider = context.watch<ComplaintProvider>();

    return Scaffold(
      // No AppBar, header is in the body
      body: SafeArea(
        child: Column( // Use Column instead of ListView for fixed header/search + scrollable content
          children: [
            const SizedBox(height: 16), // Add some top padding
            _buildHeader(textTheme, complaintProvider),
            const SizedBox(height: 24),
            _buildSearchBar(theme),
            const SizedBox(height: 24),
            // Use Expanded to make the content area fill remaining space
            Expanded(
              child: _buildCurrentScreen(complaintProvider), 
            ),
          ],
        ),
      ),
      bottomNavigationBar: ClipRRect( // Wrap BottomNavBar with ClipRRect
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)), // Round top corners
        child: BottomNavigationBar(
          // Use the _currentIndex for the actual tabs
          currentIndex: _currentIndex,
          onTap: _onBottomNavTapped, 
          type: BottomNavigationBarType.fixed, 
          // Theme is applied globally, customization here if needed
          items: const [
            // --- Restore Original Tabs + Add Map Tab ---
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt), // Optional: different icon when active
              label: 'Complaints',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
               activeIcon: Icon(Icons.groups),
              label: 'Electorates', 
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: 'Reports', 
            ),
             // --- Add the new Map Tab Item ---
             BottomNavigationBarItem(
               // Tapping this item navigates, doesn't change _currentIndex
               icon: Icon(Icons.map_outlined), 
               activeIcon: Icon(Icons.map),
               label: 'Map',
             ),
          ],
        ), // End BottomNavigationBar
      ), // End ClipRRect
    );
  }

  // --- Restore Builder Methods for UI Sections ---

  Widget _buildHeader(TextTheme textTheme, ComplaintProvider complaintProvider) {
    // Reuse the header builder from previous attempt
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            // Adjust title to fit context - maybe just 'Complaints' or 'Dashboard'
            'NCDC CCMS', 
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          // Add Refresh Icon here? Or Profile Icon?
          Row(
            children: [
               // Refresh button for current view
               IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Data',
                  onPressed: () {
                    if (_currentIndex == 0) {
                       complaintProvider.refreshComplaints();
                    } else if (_currentIndex == 1) {
                      // Force refresh electorates data
                      setState(() {
                        _electoratesFuture = _loadElectorateData();
                      });
                    }
                    // Add refresh logic for reports if needed
                  },
               ),
               // Filter button
                IconButton(
                 icon: const Icon(Icons.filter_list),
                 tooltip: 'Filter',
                 onPressed: _showFiltersDialog, 
               ),
               const SizedBox(width: 8), // Spacing
               // Profile Icon (Placeholder)
               const CircleAvatar(
                radius: 20, // Slightly smaller
                backgroundColor: Colors.grey, 
                 child: Icon(Icons.person, color: Colors.white, size: 20),
               ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    // Reuse the search bar builder from previous attempt
     return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextField(
         // TODO: Connect this to actual filtering logic
        decoration: InputDecoration(
          hintText: 'Search ${_currentIndex == 0 ? 'Complaints' : _currentIndex == 1 ? 'Electorates' : '...'}', // Dynamic hint text
          prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
          // Remove the filter icon here if it's in the header now
          // suffixIcon: Icon(Icons.tune, color: Colors.grey[700]), 
        ),
        onChanged: (value) {
          // TODO: Implement search/filter logic based on _currentIndex
          // Log search query for debugging (removed print statement)
          // Example: complaintProvider.filterComplaints(value);
        },
      ),
    );
  }

  // --- Restore Screen Building Logic ---
  Widget _buildCurrentScreen(ComplaintProvider complaintProvider) {
    // Use the original switch logic based on _currentIndex
    switch (_currentIndex) {
      case 0: return _buildComplaintsScreen(complaintProvider);
      case 1: return _buildElectoratesScreen();
      case 2: return _buildReportsScreen();
      // Default should not be reached if _currentIndex is managed correctly
      default: return _buildComplaintsScreen(complaintProvider); 
    }
  }

  Widget _buildComplaintsScreen(ComplaintProvider complaintProvider) {
    // --- REFACTORED: Use FutureBuilder for the initial load ---
    return FutureBuilder(
      future: _complaintsFuture,
      builder: (context, snapshot) {
        // While waiting for the initial load, show a loading indicator.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // If an error occurred during the initial fetch, show an error message.
        if (snapshot.hasError) {
          return Center(child: Text('Error loading complaints: ${snapshot.error}'));
        }

        // After the initial load, rely on the provider for subsequent state changes.
        // This handles refreshes and other real-time updates.
        if (complaintProvider.isLoading && complaintProvider.complaints.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (complaintProvider.errorMessage != null) {
          return Center(child: Text('Error: ${complaintProvider.errorMessage}'));
        }
        if (complaintProvider.complaints.isEmpty) {
          return const Center(child: Text('No complaints found.'));
        }

        // --- Original Code (for displaying the list) --- 
        return ComplaintsList(
          complaints: complaintProvider.complaints, 
          onEdit: (complaint) => _showEditComplaintDialog(context, complaint), 
          onDelete: (id) async { 
             try {
               await complaintProvider.deleteComplaint(id);
               if (!context.mounted) return;
               ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                  const SnackBar(content: Text('Complaint deleted'), duration: Duration(seconds: 2))
               );
             } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                  SnackBar(content: Text('Error deleting complaint: $e'), backgroundColor: Colors.red)
               );
             }
          },
          imageService: _imageService, // Pass the ImageService instance here
        );
      },
    );
  }

  Widget _buildElectoratesScreen() {
    // Use FutureBuilder for async loading with lazy initialization
    if (_electoratesFuture == null) {
      // First time accessing - show loading prompt
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Tap to load electorates data'),
          ],
        ),
      );
    }

    return FutureBuilder<List<CityElectorate>>(
      future: _electoratesFuture,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading electorates...'),
              ],
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _electoratesFuture = _loadElectorateData();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Success state
        final electorates = snapshot.data ?? [];
        if (electorates.isEmpty) {
          return const Center(child: Text('No electorates found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          itemCount: electorates.length,
          itemBuilder: (context, index) {
            final electorate = electorates[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(electorate.name),
                subtitle: Text('Complaints: ${electorate.totalComplaints} | Suburbs: ${electorate.suburbs.join(', ')}'),
                trailing: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                      IconButton(
                         icon: const Icon(Icons.list_alt),
                         tooltip: 'View Complaints',
                         onPressed: () => _showElectorateComplaints(context, electorate.name),
                      ),
                   ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReportsScreen() {
    // Return the actual ReportsPage widget
    return const ReportsPage(); 
  }

  // --- Restore Dialog and Detail Screen Navigation Methods ---



  void _showElectorateComplaints(BuildContext context, String electorateName) {
     // Keep original implementation using StreamBuilder
     Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar( // Give this screen an AppBar
            title: Text('$electorateName Complaints'),
          ),
          body: StreamBuilder<List<Complaint>>(
            stream: _complaintService.getComplaintsByElectorateStream(electorateName),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No complaints found for this electorate.'));
              }
              final complaints = snapshot.data!;
              // Use the same ComplaintsList widget for consistency? Or simpler list view
              return ListView.builder(
                itemCount: complaints.length,
                itemBuilder: (context, index) {
                  final complaint = complaints[index];
                  return ListTile(
                    title: Text(complaint.ticketId.isEmpty ? 'No Ticket ID' : complaint.ticketId),
                    subtitle: Text('${complaint.suburb} - ${complaint.issueType}'),
                    trailing: Text(complaint.status),
                    // Add onTap for detail view if needed
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }



  void _showEditComplaintDialog(BuildContext context, Complaint complaint) {
    // Use showModalBottomSheet for a mobile-native feel
     showModalBottomSheet(
       context: context,
       isScrollControlled: true, // Allows the sheet to take more height
       shape: const RoundedRectangleBorder( // Rounded top corners
         borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
       ),
       builder: (BuildContext bottomSheetContext) {
          // Get the core content widget
          final editDialogContent = EditComplaintDialog(
             complaint: complaint,
             complaintProvider: Provider.of<ComplaintProvider>(context, listen: false),
             imageService: _imageService, // Pass the instance obtained in initState
          );

          // Get responsive padding values
          final double horizontalPadding = Responsive.value<double>(bottomSheetContext, mobile: 16.0, tablet: 24.0);
          // Note: Top padding is handled within EditComplaintDialog title section now

          // Wrap the content with Padding (for keyboard) and SingleChildScrollView
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom, 
              left: horizontalPadding,
              right: horizontalPadding,
              // No top padding here, handled inside EditComplaintDialog
            ),
            child: SingleChildScrollView(
              // Constrain the height of the content within the scroll view
              child: SizedBox(
                  height: MediaQuery.of(bottomSheetContext).size.height * 0.9, // Max 90% of screen height
                  child: editDialogContent, // Place the content inside the SizedBox
               ),
            ),
          );
       },
     );
  }

  void _showFiltersDialog() {
    // Keep original or implement filter logic
    // This might interact with ComplaintProvider or local state
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Filter functionality not implemented yet')),
    );
  }
}
