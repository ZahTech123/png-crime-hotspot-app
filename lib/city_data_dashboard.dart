import 'package:flutter/material.dart';
import 'package:ncdc_ccms_app/complaints/complaint_details_sheet.dart';
import 'package:ncdc_ccms_app/image_service.dart';
import 'package:ncdc_ccms_app/map_screen.dart';
import 'package:ncdc_ccms_app/models.dart';
import 'package:ncdc_ccms_app/reports_page.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'complaint_provider.dart';

class CityDataDashboard extends StatefulWidget {
  const CityDataDashboard({super.key});

  @override
  State<CityDataDashboard> createState() => _CityDataDashboardState();
}

class _CityDataDashboardState extends State<CityDataDashboard> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    final complaintProvider =
        Provider.of<ComplaintProvider>(context, listen: false);

    _screens = [
      _buildComplaintsScreen(complaintProvider),
      const ReportsPage(),
    ];
  }

  void _onBottomNavTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => MapScreen(onBack: () => Navigator.pop(context))),
      );
    } else {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Complaints',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintsScreen(ComplaintProvider provider) {
    return Consumer<ComplaintProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.complaints.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.errorMessage != null) {
          return Center(child: Text(provider.errorMessage!));
        }
        if (provider.complaints.isEmpty) {
          return const Center(child: Text('No complaints found.'));
        }
        return ListView.builder(
          itemCount: provider.complaints.length,
          itemBuilder: (context, index) {
            final complaint = provider.complaints[index];
            return Card(
              margin:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: ListTile(
                title: Text(complaint.issueType,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    'Status: ${complaint.status}\n${complaint.description ?? ''}'),
                isThreeLine: true,
                onTap: () {
                  if (mounted) {
                    _showComplaintDetails(context, complaint);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showComplaintDetails(BuildContext context, CityComplaint complaint) {
    final complaintProvider =
        Provider.of<ComplaintProvider>(context, listen: false);
    final imageService = ImageService(supabaseClient: Supabase.instance.client);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bContext) => ComplaintDetailsSheet(
        complaint: complaint,
        onEdit: (updatedComplaint) {
          complaintProvider.updateComplaint(updatedComplaint);
        },
        onDelete: (complaintId) {
          complaintProvider.deleteComplaint(complaintId);
          Navigator.of(bContext).pop(); // Close sheet after delete
        },
        onClose: () {
          Navigator.of(bContext).pop();
        },
        imageService: imageService,
      ),
    );
  }
}
