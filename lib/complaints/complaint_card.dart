import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ncdc_ccms_app/models.dart';
import 'package:readmore/readmore.dart';
import 'package:timeago/timeago.dart' as timeago;

class ComplaintCard extends StatelessWidget {
  final CityComplaint complaint;

  const ComplaintCard({
    super.key,
    required this.complaint,
  });

  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color darkText = Color(0xFF333333);
  static const Color lightText = Color(0xFF666666);
  static const Color cardBg = Colors.white;
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color lightIcon = Color(0xFF999999);

  String _getRelativeTime(DateTime? date) {
    if (date == null) return '';
    return timeago.format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCardHeader(),
          if (complaint.hasImages) _buildCardImage(complaint.imageUrls!.first),
          _buildCardBody(),
          _buildCardFooter(),
        ],
      ),
    );
  }

  Widget _buildCardHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: primaryBlue,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complaint.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: darkText,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${complaint.issueType} • ${complaint.suburb} • ${_getRelativeTime(complaint.dateSubmitted)}',
                  style: const TextStyle(fontSize: 12, color: lightText),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.more_horiz, color: lightIcon, size: 24),
        ],
      ),
    );
  }

  Widget _buildCardImage(String imageUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 200,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: primaryBlue,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: 200,
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image, color: lightIcon, size: 50),
          ),
        ),
      ),
    );
  }

  Widget _buildCardBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
      child: ReadMoreText(
        complaint.description,
        trimLines: 4,
        colorClickableText: primaryBlue,
        trimMode: TrimMode.Line,
        trimCollapsedText: 'See More',
        trimExpandedText: 'See Less',
        style: const TextStyle(fontSize: 14, color: darkText, height: 1.5),
        moreStyle: const TextStyle(
            fontSize: 13, color: primaryBlue, fontWeight: FontWeight.w500),
        lessStyle: const TextStyle(
            fontSize: 13, color: primaryBlue, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildCardFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Flexible(
              child: _buildActionButton(
                  icon: Icons.visibility_outlined, label: 'Witness (0)')),
          Flexible(
              child: _buildActionButton(
                  icon: Icons.notifications_outlined, label: 'Follow')),
          Flexible(
              child:
                  _buildActionButton(icon: Icons.share_outlined, label: 'Share')),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label}) {
    return TextButton.icon(
      onPressed: () {
        /* Action logic goes here */
      },
      icon: Icon(icon, color: lightIcon, size: 20),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: lightText,
        ),
      ),
    );
  }
}