import 'package:flutter/material.dart';
import 'package:ncdc_ccms_app/models.dart';

class MapBottomCarousel extends StatefulWidget {
  final List<Complaint>? complaintsData;
  final VoidCallback onClose;
  final bool isVisible;
  final Function(double lat, double lng)? onLocationChange;
  final int? initialIndex;

  const MapBottomCarousel({
    super.key,
    required this.complaintsData,
    required this.onClose,
    required this.isVisible,
    this.onLocationChange,
    this.initialIndex,
  });

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
    if (data != null &&
        index < data.length &&
        widget.onLocationChange != null) {
      final complaint = data[index];
      final lat = complaint.latitude;
      final lng = complaint.longitude;
      widget.onLocationChange!(lat, lng);
    }
  }

  String _getTimeAgo(DateTime? date) {
    if (date == null) return 'Unknown time';

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
                : Colors.white.withValues(alpha: 0.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
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

    // Handle loading state (null data)
    if (data == null) {
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

    // Handle error or empty state
    if (data.isEmpty) {
      return Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Could not load complaint details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      );
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

  Widget _buildModernComplaintCard(Complaint complaint, int index) {
    return Transform.scale(
      scale: 1.0,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(complaint),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildCardContent(complaint),
                  ),
                ),
                _buildCardFooter(complaint),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _buildCloseButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white, size: 20),
        onPressed: widget.onClose,
        splashRadius: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildCardHeader(Complaint complaint) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              complaint.issueType,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF1A237E),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _buildStatusChip(complaint.status),
        ],
      ),
    );
  }

  Widget _buildCardContent(Complaint complaint) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _buildInfoRow(
              Icons.location_on, '${complaint.suburb}, ${complaint.electorate}'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.description, complaint.description, maxLines: 3),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoColumn("Priority", complaint.priority,
                  color: _getPriorityColor(complaint.priority)),
              _buildInfoColumn("Assigned To", complaint.currentHandler),
              _buildInfoColumn("Directorate", complaint.directorate,
                  alignment: CrossAxisAlignment.end),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardFooter(Complaint complaint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildInfoRow(Icons.person, complaint.author, isFooter: true),
          _buildInfoRow(
              Icons.timer_outlined, _getTimeAgo(complaint.dateSubmitted),
              isFooter: true),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'New':
        color = Colors.blue.shade700;
        break;
      case 'In Progress':
        color = Colors.orange.shade700;
        break;
      case 'Resolved':
        color = Colors.green.shade700;
        break;
      default:
        color = Colors.grey.shade700;
    }
    return Chip(
      label: Text(
        status,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildInfoRow(IconData icon, String text,
      {int maxLines = 1, bool isFooter = false}) {
    return Row(
      children: [
        Icon(icon, size: isFooter ? 14 : 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isFooter ? 12 : 14,
              color: isFooter ? Colors.grey.shade700 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoColumn(String label, String value,
      {CrossAxisAlignment alignment = CrossAxisAlignment.start, Color? color}) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black,
          ),
        ),
      ],
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red.shade700;
      case 'Medium':
        return Colors.orange.shade700;
      case 'Low':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
} 