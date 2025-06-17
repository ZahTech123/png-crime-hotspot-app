import 'package:flutter/material.dart';
import 'package:ncdc_ccms_app/utils/size_config.dart';

class ComplaintInfoCard extends StatelessWidget {
  // Placeholder data - in a real app, you'd pass a Complaint object
  final String title;
  final String status;
  final String imageUrl; // Placeholder for an image
  final VoidCallback onShowMoreInfo;
  final VoidCallback onClose;

  const ComplaintInfoCard({
    Key? key,
    required this.title,
    required this.status,
    required this.imageUrl,
    required this.onShowMoreInfo,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(10),
        vertical: getProportionateScreenHeight(20),
      ),
      width: SizeConfig.screenWidth * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, // Make column wrap content
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Section
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16.0),
                    topRight: Radius.circular(16.0),
                  ),
                  child: (imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.isAbsolute == true)
                      ? Image.network(
                          imageUrl,
                          height: getProportionateScreenHeight(120), // Responsive height
                          fit: BoxFit.cover,
                          // Basic error handling for the image
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: getProportionateScreenHeight(120), // Responsive height
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
                              ),
                            );
                          },
                        )
                      : Container( // Placeholder for invalid/empty URL
                          height: getProportionateScreenHeight(120), // Responsive height
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
                          ),
                        ),
                ),
                // Text Content Section
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: getProportionateScreenWidth(12),
                    vertical: getProportionateScreenHeight(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: getProportionateScreenWidth(14), // Responsive font size
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: getProportionateScreenHeight(4)),
                      Text(
                        'Status: $status',
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(12), // Responsive font size
                          color: Colors.grey[600],
                        ),
                         maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Button Section
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    getProportionateScreenWidth(12),
                    0,
                    getProportionateScreenWidth(12),
                    getProportionateScreenHeight(12),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Theme.of(context).primaryColor, // Use theme color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onPressed: onShowMoreInfo,
                    child: const Text('Show More Info'),
                  ),
                ),
              ],
            ),
          ),
          // Close Button
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: InkWell(
                onTap: onClose,
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 