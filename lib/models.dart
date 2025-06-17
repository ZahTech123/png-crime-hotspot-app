// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CityComplaint {
  final String id;
  final String ticketId;
  final String issueType;
  final String suburb;
  final String description;
  final String status;
  final String priority;
  final String directorate;
  final DateTime dateSubmitted;
  final String electorate;
  final String currentHandler;
  final String? previousHandler;
  final List<String>? previousHandlers;
  final bool resolved;
  final double latitude;
  final double longitude;
  final String name;
  final String team;
  final DateTime submissionTime;
  final DateTime? closedTime;
  final DateTime lastUpdated;
  final bool emailEscalation;
  final int escalationCount;
  final DateTime handlerStartDateAndTime;
  final DateTime? lastEscalated;
  final bool isNew;
  final bool isRead;
  final List<String>? imageUrls;  // New field for image attachments
  final List<Map<String, dynamic>>? attachmentsData; // Added for detailed attachment info

  CityComplaint({
    required this.id,
    required this.ticketId,
    required this.issueType,
    required this.suburb,
    required this.description,
    required this.status,
    required this.priority,
    required this.directorate,
    required this.dateSubmitted,
    required this.electorate,
    required this.currentHandler,
    this.previousHandler,
    this.previousHandlers,
    required this.resolved,
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.team,
    required this.submissionTime,
    this.closedTime,
    required this.lastUpdated,
    required this.emailEscalation,
    required this.escalationCount,
    required this.handlerStartDateAndTime,
    this.lastEscalated,
    required this.isNew,
    required this.isRead,
    this.imageUrls,  // Added to constructor
    this.attachmentsData, // Added to constructor
  });

  factory CityComplaint.fromJson(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? 'N/A'; // Safely extract ID
    
    return CityComplaint(
      id: id,
      ticketId: data['ticketId'] ?? '',
      issueType: data['issueType'] ?? '',
      suburb: data['suburb'] ?? '',
      description: data['description'] ?? '',
      status: _normalizeStatus(data['status'] ?? 'New'),
      priority: _normalizePriority(data['priority'] ?? 'Medium'),
      directorate: data['directorate'] ?? '',
      dateSubmitted: _parseDateTime(data['dateSubmitted']),
      electorate: data['electorate'] ?? '',
      currentHandler: data['currentHandler'] ?? '',
      previousHandler: data['previousHandler'] ?? '',
      previousHandlers: data['previousHandlers'] == null ? null : List<String>.from(data['previousHandlers']),
      resolved: data['resolved'] is bool ? data['resolved'] : false,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      name: data['name'] ?? '',
      team: data['team'] ?? '',
      submissionTime: _parseDateTime(data['submissionTime']),
      closedTime: data['closedTime'] == null ? null : _parseDateTime(data['closedTime']),
      lastUpdated: _parseDateTime(data['_lastupdated']),
      emailEscalation: data['emailEscalation'] is bool ? data['emailEscalation'] : false,
      escalationCount: (data['escalationCount'] as num?)?.toInt() ?? 0,
      handlerStartDateAndTime: _parseDateTime(data['handlerStartDateAndTime']),
      lastEscalated: data['lastEscalated'] == null ? null : _parseDateTime(data['lastEscalated']),
      isNew: data['isNew'] is bool ? data['isNew'] : false,
      isRead: data['isRead'] is bool ? data['isRead'] : false,
      imageUrls: data['imageUrls'] == null || data['imageUrls'] is! List
          ? null 
          : List<String>.from((data['imageUrls'] as List<dynamic>).map((item) => item.toString())),
      attachmentsData: data['attachments_data'] == null
          ? null
          : List<Map<String, dynamic>>.from(
              (data['attachments_data'] as List<dynamic>).map(
                  (item) => Map<String, dynamic>.from(item as Map))),
    );
  }

  // --- Normalization Helpers ---
  static String _normalizeStatus(String input) {
    String lower = input.toLowerCase().trim(); // Trim whitespace too
    if (lower == 'new') return 'New';
    if (lower == 'in progress') return 'In Progress';
    if (lower == 'resolved') return 'Resolved';
    if (lower == 'closed') return 'Closed';
    return 'New'; // Default fallback
  }

  static String _normalizePriority(String input) {
    String lower = input.toLowerCase().trim(); // Trim whitespace too
    if (lower == 'critical') return 'Critical'; // Handle "Critical"
    if (lower == 'high') return 'High';
    if (lower == 'medium') return 'Medium';
    if (lower == 'low') return 'Low';
    return 'Medium'; // Default fallback
  }
  // --- End Normalization Helpers ---

  static DateTime _parseDateTime(dynamic value) {
    try {
      if (value == null) {
         return DateTime.now();
      }
      if (value is DateTime) {
        return value;
      }
      if (value is String) {
        return DateTime.parse(value).toLocal();
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'ticketId': ticketId,
      'issueType': issueType,
      'suburb': suburb,
      'description': description,
      'status': status,
      'priority': priority,
      'directorate': directorate,
      'dateSubmitted': dateSubmitted.toIso8601String(),
      'electorate': electorate,
      'currentHandler': currentHandler,
      'previousHandler': previousHandler,
      'previousHandlers': previousHandlers,
      'resolved': resolved,
      'latitude': latitude,
      'longitude': longitude,
      'name': name,
      'team': team,
      'submissionTime': submissionTime.toIso8601String(),
      'closedTime': closedTime?.toIso8601String(),
      'emailEscalation': emailEscalation,
      'escalationCount': escalationCount,
      'handlerStartDateAndTime': handlerStartDateAndTime.toIso8601String(),
      'lastEscalated': lastEscalated?.toIso8601String(),
      'isNew': isNew,
      'isRead': isRead,
      'imageUrls': imageUrls ?? [],
      'attachments_data': attachmentsData ?? [], // Add to toJson, use snake_case for DB
    };
  }

  // Enhanced copyWith method
  CityComplaint copyWith({
    String? ticketId,
    String? issueType,
    String? status,
    String? priority,
    String? currentHandler,
    String? previousHandler,
    List<String>? previousHandlers,
    bool? resolved,
    String? description,
    DateTime? lastUpdated,
    bool? emailEscalation,
    int? escalationCount,
    bool? isNew,
    bool? isRead,
    List<String>? imageUrls,  // Added parameter
    List<Map<String, dynamic>>? attachmentsData, // Added parameter
  }) {
    return CityComplaint(
      id: id,
      ticketId: ticketId ?? this.ticketId,
      issueType: issueType ?? this.issueType,
      suburb: suburb,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      directorate: directorate,
      dateSubmitted: dateSubmitted,
      electorate: electorate,
      currentHandler: currentHandler ?? this.currentHandler,
      previousHandler: previousHandler ?? this.previousHandler,
      previousHandlers: previousHandlers ?? this.previousHandlers,
      resolved: resolved ?? this.resolved,
      latitude: latitude,
      longitude: longitude,
      name: name,
      team: team,
      submissionTime: submissionTime,
      closedTime: closedTime,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      emailEscalation: emailEscalation ?? this.emailEscalation,
      escalationCount: escalationCount ?? this.escalationCount,
      handlerStartDateAndTime: handlerStartDateAndTime,
      lastEscalated: lastEscalated,
      isNew: isNew ?? this.isNew,
      isRead: isRead ?? this.isRead,
      imageUrls: imageUrls ?? this.imageUrls,  // Added to copyWith
      attachmentsData: attachmentsData ?? this.attachmentsData, // Added to copyWith
    );
  }

  // Status and priority helpers
  Color get statusColor {
    switch (status) {
      case 'New': return Colors.blue;
      case 'In Progress': return Colors.orange;
      case 'Resolved': return Colors.green;
      case 'Closed': return Colors.grey;
      default: return Colors.purple;
    }
  }

  IconData get priorityIcon {
    switch (priority) {
      case 'High': return Icons.error;
      case 'Medium': return Icons.warning;
      case 'Low': return Icons.info;
      default: return Icons.circle;
    }
  }

  Color get priorityColor {
    switch (priority) {
      case 'High': return Colors.red;
      case 'Medium': return Colors.orange;
      case 'Low': return Colors.green;
      default: return Colors.grey;
    }
  }

  // Format dates for display
  String get formattedDateSubmitted => 
      '${dateSubmitted.day}/${dateSubmitted.month}/${dateSubmitted.year}';
  
  String get formattedLastUpdated =>
      '${lastUpdated.day}/${lastUpdated.month}/${lastUpdated.year} ${lastUpdated.hour}:${lastUpdated.minute}';

  // Helper to check if complaint has images
  bool get hasImages => imageUrls?.isNotEmpty ?? false;
}

class CityElectorate {
  final String id;
  final String name;
  int totalComplaints;
  final List<String> suburbs;

  CityElectorate({
    required this.id,
    required this.name,
    required this.totalComplaints,
    required this.suburbs,
  });

  factory CityElectorate.fromJson(String id, Map<String, dynamic> data) {
    return CityElectorate(
      id: id,
      name: data['name'] ?? '',
      totalComplaints: (data['total_complaints'] as num?)?.toInt() ?? 0,
      suburbs: List<String>.from(data['suburbs'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'total_complaints': totalComplaints,
      'suburbs': suburbs,
    };
  }
}

enum ComplaintPriority {
  low,
  medium,
  high,
  critical,
}

enum ComplaintStatus {
  pending,
  // ... existing code ...
}