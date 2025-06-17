import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:ncdc_ccms_app/map_screen.dart';
import 'package:provider/provider.dart';
import 'package:ncdc_ccms_app/complaint_provider.dart';
import 'package:ncdc_ccms_app/complaints/complaint_card.dart';
import 'package:ncdc_ccms_app/reports_page.dart';
import 'package:ncdc_ccms_app/widgets/custom_bottom_navbar.dart';
import 'package:ncdc_ccms_app/add_complaint_dialog.dart';
import 'package:ncdc_ccms_app/image_service.dart';
import 'package:ncdc_ccms_app/widgets/custom_header.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({Key? key}) : super(key: key);

  @override
  _HomeFeedScreenState createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;
  bool _isNavbarVisible = true;

  // Define constants for styling
  static const Color darkText = Color(0xFF333333);

  // --- Screens for Bottom Navigation ---
  late final List<Widget> _widgetOptions;
  
  // Titles for the AppBar
  static const List<String> _widgetTitles = <String>[
    'Crime Reports',
    'Map View',
    'Reports',
    'Profile'
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);

    // Fetch initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ComplaintProvider>(context, listen: false).fetchAllComplaints();
    });

    _widgetOptions = <Widget>[
      ComplaintFeedView(scrollController: _scrollController), // Pass controller
      MapScreen(onBack: () => _onNavItemTapped(0)),
      ReportsPage(),
      const Center(child: Text('Profile Screen (Placeholder)')),
    ];
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_isNavbarVisible) {
        setState(() => _isNavbarVisible = false);
      }
    } else {
      if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        if (!_isNavbarVisible) {
          setState(() => _isNavbarVisible = true);
        }
      }
    }
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
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
    final double appBarHeight = _selectedIndex == 0 ? 140.0 : kToolbarHeight;
    final double bottomNavBarHeight = 85.0; // Approximate height for CustomBottomNavbar

    return Scaffold(
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_isNavbarVisible ? appBarHeight : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isNavbarVisible ? appBarHeight : 0,
          child: _selectedIndex == 0
              ? CustomHeader(
                  title: _widgetTitles[_selectedIndex],
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_outlined, color: Colors.black54),
                      onPressed: () {},
                    ),
                  ],
                )
              : AppBar(
                  title: Text(_widgetTitles[_selectedIndex]),
                  backgroundColor: Colors.white,
                  elevation: 1,
                ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      floatingActionButton: AnimatedScale(
        duration: const Duration(milliseconds: 300),
        scale: _isNavbarVisible ? 1 : 0,
        child: FloatingActionButton(
          onPressed: _showAddComplaintDialog,
          backgroundColor: Colors.blueAccent,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: _isNavbarVisible ? bottomNavBarHeight : 0,
        child: CustomBottomNavbar(
          activeIndex: _selectedIndex,
          onTabChanged: _onNavItemTapped,
        ),
      ),
    );
  }
}

// Extracted the complaint feed into its own widget for clarity
class ComplaintFeedView extends StatelessWidget {
  final ScrollController scrollController; // Accept controller

  const ComplaintFeedView({
    Key? key,
    required this.scrollController, // Require controller
  }) : super(key: key);

  static const Color bgColor = Color(0xFFF0F2F5);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      child: Consumer<ComplaintProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.complaints.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            // --- Improved Error Display ---
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 50),
                    const SizedBox(height: 15),
                    const Text(
                      'Failed to load complaints.',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${provider.errorMessage}', // Show the specific error from the provider
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      onPressed: () => provider.fetchAllComplaints(),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white, backgroundColor: Theme.of(context).primaryColor, // Text color
                      ),
                    ),
                  ],
                ),
              ),
            );
            // --- End Improved Error Display ---
          }

          if (provider.complaints.isEmpty) {
            return const Center(child: Text('No complaints found.'));
          }

          return ListView.builder(
            controller: scrollController, // Use the passed controller
            padding: const EdgeInsets.only(top: 20, bottom: 20), // Adjusted padding
            itemCount: provider.complaints.length,
            itemBuilder: (context, index) {
              final complaint = provider.complaints[index];
              return ComplaintCard(complaint: complaint);
            },
          );
        },
      ),
    );
  }
}

class AddIncidentReportScreen extends StatelessWidget {
  const AddIncidentReportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Incident Report')),
      body: const Center(child: Text('Form to add a new incident report.')),
    );
  }
} 