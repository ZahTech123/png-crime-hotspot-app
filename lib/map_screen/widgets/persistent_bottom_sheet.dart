import 'package:flutter/material.dart';

class MapBottomCarousel extends StatefulWidget {
  final List<Map<String, dynamic>>? complaintsData;
  final VoidCallback onClose;
  final bool isVisible;
  final Function(double lat, double lng)? onLocationChange;
  final int? initialIndex;

  const MapBottomCarousel({
    Key? key,
    required this.complaintsData,
    required this.onClose,
    required this.isVisible,
    this.onLocationChange,
    this.initialIndex,
  }) : super(key: key);

  @override
  State<MapBottomCarousel> createState() => _MapBottomCarouselState();
}

class _MapBottomCarouselState extends State<MapBottomCarousel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
    _pageController = PageController(
      initialPage: _currentIndex, 
      viewportFraction: 0.9,
    );
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(MapBottomCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _animationController.forward();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _animationController.reverse();
    }
    
    if (widget.complaintsData != oldWidget.complaintsData) {
      if (widget.complaintsData != null && widget.complaintsData!.isNotEmpty) {
        if (_pageController.hasClients && _pageController.positions.isNotEmpty) {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        _currentIndex = 0;
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    final data = widget.complaintsData;
    if (data != null && index < data.length && widget.onLocationChange != null) {
      final complaint = data[index];
      final lat = complaint['latitude'];
      final lng = complaint['longitude'];
      if (lat != null && lng != null) {
        widget.onLocationChange!(lat.toDouble(), lng.toDouble());
      }
    }
  }

  String _getTimeAgo(String? dateString) {
    if (dateString == null) return 'Unknown time';
    
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'Hr' : 'Hrs'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'min' : 'mins'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible && !_animationController.isAnimating) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                height: 400, // Increased to resolve 50px overflow error
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  children: [
                    Expanded(
                      child: _buildCarouselContent(),
                    ),
                    const SizedBox(height: 12),
                    _buildPageIndicators(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageIndicators() {
    final data = widget.complaintsData;
    if (data == null || data.length <= 1) return const SizedBox.shrink();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        data.length,
        (index) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == _currentIndex 
                ? Colors.white 
                : Colors.white.withOpacity(0.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselContent() {
    final data = widget.complaintsData;
    
    if (data == null || data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // Handle loading state
    if (data.length == 1) {
      final singleItem = data.first;
      if (singleItem.containsKey('loading')) {
        return const Center(
          child: Card(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading complaint details...'),
                ],
              ),
            ),
          ),
        );
      }

      if (singleItem.containsKey('error')) {
        return Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    singleItem['error'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: data.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: _buildModernComplaintCard(data[index], index),
        );
      },
    );
  }

  Widget _buildModernComplaintCard(Map<String, dynamic> complaint, int index) {
    final issueType = complaint['issue_type'] ?? 'General Issue';
    final suburb = complaint['suburb'] ?? 'Unknown Location';
    final electorate = complaint['electorate'] ?? 'Unknown Electorate';
    final createdAt = complaint['created_at'] ?? complaint['date'];
    final timeAgo = _getTimeAgo(createdAt);
    
    return Card(
      elevation: 12,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.0),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with image/illustration area
            Container(
              height: 150, // Extended height for better visual proportions
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20.0),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getIssueTypeColor(issueType),
                    _getIssueTypeColor(issueType).withOpacity(0.7),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Background pattern/illustration effect
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20.0),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20.0),
                        ),
                        child: _buildHeaderIllustration(issueType),
                      ),
                    ),
                  ),
                  // "New" badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'New',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Close button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: widget.onClose,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content section
            Container(
              height: 200, // Final adjustment to eliminate 16px overflow
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Issue type title
                  Text(
                    issueType,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Location info with icon
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suburb,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              electorate,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Timestamp
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Description (if space allows)
                  if (complaint['description'] != null)
                    Text(
                      complaint['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const Spacer(), // Push button to bottom
                  // "See More" button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Handle "See More" action
                        _showComplaintDetails(complaint);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'See More',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIllustration(String issueType) {
    // Create a visual pattern based on issue type
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getIssueTypeColor(issueType).withOpacity(0.3),
            _getIssueTypeColor(issueType).withOpacity(0.6),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Geometric pattern for visual appeal
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 30,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 10,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          // Icon representation
          Center(
            child: Icon(
              _getIssueTypeIcon(issueType),
              size: 48,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIssueTypeIcon(String issueType) {
    switch (issueType.toLowerCase()) {
      case 'car theft':
      case 'theft':
        return Icons.car_crash;
      case 'vandalism':
        return Icons.broken_image;
      case 'noise complaint':
        return Icons.volume_up;
      case 'public safety':
        return Icons.security;
      case 'infrastructure':
        return Icons.construction;
      case 'environmental':
        return Icons.eco;
      default:
        return Icons.report_problem;
    }
  }

  Color _getIssueTypeColor(String issueType) {
    switch (issueType.toLowerCase()) {
      case 'car theft':
      case 'theft':
        return Colors.red[700]!;
      case 'vandalism':
        return Colors.orange[700]!;
      case 'noise complaint':
        return Colors.purple[700]!;
      case 'public safety':
        return Colors.indigo[700]!;
      case 'infrastructure':
        return Colors.brown[700]!;
      case 'environmental':
        return Colors.green[700]!;
      default:
        return Colors.blue[700]!;
    }
  }

  void _showComplaintDetails(Map<String, dynamic> complaint) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  complaint['issue_type'] ?? 'Complaint Details',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Details
                _buildDetailRow('Location', complaint['suburb'] ?? 'N/A'),
                _buildDetailRow('Electorate', complaint['electorate'] ?? 'N/A'),
                _buildDetailRow('Status', complaint['status'] ?? 'N/A'),
                _buildDetailRow('ID', complaint['id']?.toString() ?? 'N/A'),
                if (complaint['description'] != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    complaint['description'],
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'resolved':
        return Colors.green;
      case 'in progress':
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
} 