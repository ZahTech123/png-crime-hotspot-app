// complaint_service.dart
// import 'package:cloud_firestore/cloud_firestore.dart'; // Remove Firestore import
import 'models.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show compute;
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'utils/logger.dart';

class ComplaintService {
  // Add SupabaseClient field
  final SupabaseClient _supabaseClient;
  
  // Enhanced cache for expensive queries with background refresh
  final Map<String, dynamic> _cache = {};
  Timer? _cacheCleanupTimer;
  Timer? _backgroundRefreshTimer;
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const Duration _backgroundRefreshInterval = Duration(minutes: 3);

  // Constructor accepts and stores the client
  ComplaintService({required SupabaseClient supabaseClient})
      : _supabaseClient = supabaseClient {
    // Set up periodic cache cleanup
    _cacheCleanupTimer = Timer.periodic(const Duration(minutes: 10), (_) => _cleanupCache());
    
    // Set up background cache refresh for critical data
    _backgroundRefreshTimer = Timer.periodic(_backgroundRefreshInterval, (_) => _refreshCriticalCache());
  }

  /// Cleanup expired cache entries
  void _cleanupCache() {
    final now = DateTime.now();
    _cache.removeWhere((key, value) {
      if (value is Map && value.containsKey('timestamp')) {
        final timestamp = value['timestamp'] as DateTime;
        return now.difference(timestamp) > _cacheExpiry;
      }
      return true;
    });
  }

  /// Background refresh of critical cache data
  void _refreshCriticalCache() async {
    try {
      // Refresh electorates data in background
      if (_cache.containsKey('electorates')) {
        _getElectoratesFromDatabase(); // This will update cache
      }
      
      // Refresh electorate stats if they exist
      final electorateKeys = _cache.keys.where((key) => key.startsWith('electorate_stats_')).toList();
      if (electorateKeys.isNotEmpty) {
        _getAllElectorateStatsFromDatabase(); // Bulk refresh
      }
    } catch (e) {
              AppLogger.e('[ComplaintService] Background cache refresh failed', e);
    }
  }

  /// Get cached data or null if expired/not found
  T? _getCachedData<T>(String key) {
    final cached = _cache[key];
    if (cached is Map && cached.containsKey('timestamp') && cached.containsKey('data')) {
      final timestamp = cached['timestamp'] as DateTime;
      if (DateTime.now().difference(timestamp) < _cacheExpiry) {
        return cached['data'] as T;
      }
      _cache.remove(key);
    }
    return null;
  }

  /// Cache data with timestamp
  void _setCachedData<T>(String key, T data) {
    _cache[key] = {
      'timestamp': DateTime.now(),
      'data': data,
    };
  }

  /// Dispose resources
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _backgroundRefreshTimer?.cancel();
    _cache.clear();
  }

  /// Clear cache (useful after data modifications)
  void clearCache() {
    _cache.clear();
    AppLogger.d('[ComplaintService] Cache cleared');
  }

  /// Process stream data in background isolate to prevent UI blocking
  Future<List<Complaint>> _processComplaintDataInBackground(List<Map<String, dynamic>> rawData) async {
    if (rawData.length < 50) {
      // For small datasets, process directly to avoid isolate overhead
      return rawData.map((mapData) {
        final String id = mapData['id'].toString();
        return Complaint.fromJson(id, mapData);
      }).toList();
    }
    
    // For large datasets, use background processing
    return await compute(_processComplaintDataInIsolate, rawData);
  }

  /// Optimized stream with background processing and robust error handling
  Stream<List<Map<String, dynamic>>> getComplaintsStream() {
    AppLogger.i('[ComplaintService] Subscribing to optimized complaints stream with error handling...');
    
    return _supabaseClient
        .from('complaints')
        .stream(primaryKey: ['id'])
        .order('_lastupdated', ascending: false)
        .handleError((error) {
          // Enhanced error handling for real-time subscription issues
          AppLogger.e('[ComplaintService] Stream Error Details', error);
          
          // Check for specific RealtimeSubscribeException patterns
          if (error.toString().contains('RealtimeSubscribeException') || 
              error.toString().contains('channel error') ||
              error.toString().contains('code: 1006')) {
            AppLogger.w('[ComplaintService] Real-time subscription error detected - Code 1006 often indicates network/RLS issues');
            AppLogger.w('[ComplaintService] Consider checking Row Level Security policies and network connectivity');
          }
          
          // Re-throw for the provider to handle with retry logic
          throw error;
        })
        .map((listOfMaps) {
          AppLogger.d('[ComplaintService] Received raw complaints data: ${listOfMaps.length} items');
          // Return raw data for background processing by ComplaintProvider
          return listOfMaps;
        });
  }

  /// Optimized bulk electorate data fetching
  Future<Map<String, dynamic>> getAllElectorateStats() async {
    const cacheKey = 'all_electorate_stats';
    
    // Check cache first
    final cached = _getCachedData<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      AppLogger.d('[ComplaintService] Returning cached electorate stats');
      return cached;
    }
    
    // Fetch from database in background
    return await _getAllElectorateStatsFromDatabase();
  }

  /// Background database fetch for electorate stats
  Future<Map<String, dynamic>> _getAllElectorateStatsFromDatabase() async {
    AppLogger.i('[ComplaintService] Fetching all electorate stats in bulk...');
    
    try {
      // Single optimized query to get all electorate data
      final List<Map<String, dynamic>> data = await _supabaseClient
          .from('complaints')
          .select('electorate, suburb')
          .not('electorate', 'is', null)
          .not('suburb', 'is', null);

      // Process data efficiently using compute for large datasets
      final stats = await compute(_processElectorateStatsInIsolate, data);
      
      const cacheKey = 'all_electorate_stats';
      _setCachedData(cacheKey, stats);
      
      AppLogger.d('[ComplaintService] Bulk electorate stats cached: ${stats['electorates']?.length ?? 0} electorates');
      
      return stats;
    } catch (e) {
      AppLogger.e('[ComplaintService] Error fetching bulk electorate stats: $e');
      rethrow;
    }
  }

  /// Optimized electorates fetch with database-level distinct
  Future<List<String>> getElectorates() async {
    const cacheKey = 'electorates';
    
    // Check cache first
    final cached = _getCachedData<List<String>>(cacheKey);
    if (cached != null) {
      AppLogger.d('[ComplaintService] Returning cached electorates: ${cached.length} items');
      return cached;
    }
    
    return await _getElectoratesFromDatabase();
  }

  /// Background database fetch for electorates
  Future<List<String>> _getElectoratesFromDatabase() async {
    AppLogger.i('[ComplaintService] Fetching distinct electorates with optimized query...');
    
    try {
      // Use optimized distinct query
      final List<Map<String, dynamic>> data = await _supabaseClient
          .from('complaints')
          .select('electorate')
          .not('electorate', 'is', null)
          .order('electorate');
      
      // Process in background for large datasets
      final electorateNames = await compute(_extractDistinctElectoratesInIsolate, data);
      
      const cacheKey = 'electorates';
      _setCachedData(cacheKey, electorateNames);
      
      AppLogger.d('[ComplaintService] Cached ${electorateNames.length} distinct electorates');
      
      return electorateNames;
    } catch (e) {
      AppLogger.e('[ComplaintService] Error fetching electorates', e);
      rethrow;
    }
  }

  /// Paginated complaints fetch for better memory management
  Future<List<Complaint>> getPaginatedComplaints(int page, int limit, {String? electorateFilter, String? statusFilter}) async {
    final cacheKey = 'complaints_${page}_${limit}_${electorateFilter ?? 'all'}_${statusFilter ?? 'all'}';
    
    final cached = _getCachedData<List<Complaint>>(cacheKey);
    if (cached != null) {
      return cached;
    }
    
    try {
      AppLogger.d('[ComplaintService] Fetching paginated complaints: page=$page, limit=$limit');
      
      // Build the query with filters right after select() and before order()
      var query = _supabaseClient
          .from('complaints')
          .select();

      // Apply filters right after select()
      if (electorateFilter != null) {
        query = query.eq('electorate', electorateFilter);
      }
      
      if (statusFilter != null) {
        query = query.eq('status', statusFilter);
      }

      // Apply ordering and range last
      final response = await query
          .order('_lastupdated', ascending: false)
          .range(page * limit, (page + 1) * limit - 1);
      
      // Process in background for large datasets
      final complaints = await _processComplaintDataInBackground(response);
      
      _setCachedData(cacheKey, complaints);
      
      return complaints;
    } catch (e) {
      AppLogger.e('[ComplaintService] Error fetching paginated complaints', e);
      rethrow;
    }
  }

  /// Optimized bulk operations for CRUD
  Future<void> addComplaint(Complaint complaint) async {
    try {
      final dataToInsert = complaint.toJson();
      await _supabaseClient.from('complaints').insert(dataToInsert);
      
      // Clear relevant caches
      _clearRelevantCaches();
      
    } catch (e) {
      AppLogger.e('Error adding complaint', e);
      rethrow; 
    }
  }

  Future<void> updateComplaint(Complaint complaint) async {
    try {
      final dataToUpdate = complaint.toJson();
      await _supabaseClient
          .from('complaints')
          .update(dataToUpdate)
          .eq('id', complaint.id);
          
      // Clear relevant caches
      _clearRelevantCaches();
      
    } catch (e) {
       AppLogger.e('Error updating complaint', e);
       rethrow;
    }
  }

  Future<void> deleteComplaint(String complaintId) async {
    try {
      await _supabaseClient
          .from('complaints')
          .delete()
          .eq('id', complaintId);
          
      // Clear relevant caches
      _clearRelevantCaches();
      
    } catch (e) {
      AppLogger.e('Error deleting complaint', e);
      rethrow;
    }
  }

  /// Bulk update operations for efficiency
  Future<void> bulkUpdateComplaints(List<Complaint> complaints) async {
    try {
      AppLogger.i('[ComplaintService] Performing bulk update of ${complaints.length} complaints');
      
      // Convert to JSON and batch update
      final updates = complaints.map((c) => c.toJson()).toList();
      
      // Use upsert for bulk operations
      await _supabaseClient
          .from('complaints')
          .upsert(updates);
          
      _clearRelevantCaches();
      
    } catch (e) {
      AppLogger.e('Error in bulk update: $e');
      rethrow;
    }
  }

  /// Clear caches that might be affected by data changes
  void _clearRelevantCaches() {
    _cache.removeWhere((key, value) => 
        key.startsWith('electorates') || 
        key.startsWith('complaints_') ||
        key.startsWith('count_') ||
        key.startsWith('suburbs_') ||
        key.startsWith('all_electorate_stats'));
  }

  /// Legacy methods with optimization
  Future<List<String>> getSuburbsForElectorate(String electorateName) async {
    // First try to get from bulk stats
    final allStats = await getAllElectorateStats();
    final electorateStats = allStats['electorate_details'] as Map<String, dynamic>?;
    
    if (electorateStats?.containsKey(electorateName) == true) {
      final suburbs = electorateStats![electorateName]['suburbs'] as List<String>?;
      if (suburbs != null) {
        AppLogger.d('[ComplaintService] Returning suburbs from bulk stats for $electorateName: ${suburbs.length} items');
        return suburbs;
      }
    }
    
    // Fallback to individual query with caching
    final cacheKey = 'suburbs_$electorateName';
    final cached = _getCachedData<List<String>>(cacheKey);
    if (cached != null) {
      return cached;
    }
    
    try {
      final data = await _supabaseClient
          .from('complaints')
          .select('suburb')
          .eq('electorate', electorateName)
          .not('suburb', 'is', null);

      final suburbNames = await compute(_extractDistinctSuburbsInIsolate, data);
      _setCachedData(cacheKey, suburbNames);
      
      return suburbNames;
    } catch (e) {
      AppLogger.e('[ComplaintService] Error fetching suburbs for $electorateName: $e');
      rethrow;
    }
  }

  Future<int> getComplaintCountForElectorate(String electorateName) async {
    // First try to get from bulk stats
    final allStats = await getAllElectorateStats();
    final electorateStats = allStats['electorate_details'] as Map<String, dynamic>?;
    
    if (electorateStats?.containsKey(electorateName) == true) {
      final count = electorateStats![electorateName]['count'] as int?;
      if (count != null) {
        AppLogger.d('[ComplaintService] Returning count from bulk stats for $electorateName: $count');
        return count;
      }
    }
    
    // Fallback to individual query
    final cacheKey = 'count_$electorateName';
    final cached = _getCachedData<int>(cacheKey);
    if (cached != null) {
      return cached;
    }
    
    try {
      final response = await _supabaseClient
          .from('complaints')
          .count()
          .eq('electorate', electorateName);

      _setCachedData(cacheKey, response);
      return response; 
    } catch (e) {
      AppLogger.e('[ComplaintService] Error counting complaints for $electorateName: $e');
      return 0;
    }
  }

  Stream<List<Complaint>> getComplaintsByElectorateStream(String electorateName) {
    return _supabaseClient
        .from('complaints')
        .stream(primaryKey: ['id'])
        .eq('electorate', electorateName)
        .order('_lastupdated', ascending: false)
        .map((listOfMaps) {
          return listOfMaps.map((mapData) {
            final String id = mapData['id'].toString();
            return Complaint.fromJson(id, mapData);
          }).toList();
        });
  }

  /// Optimized map data with spatial indexing considerations
  Future<List<Complaint>> getComplaintsForMap({int? limit}) async {
    const cacheKey = 'map_complaints';
    
    final cached = _getCachedData<List<Complaint>>(cacheKey);
    if (cached != null) {
      return cached;
    }

    try {
      var query = _supabaseClient
          .from('complaints')
          .select('id, latitude, longitude, suburb, issueType, status, electorate, description, currentHandler, directorate, dateSubmitted, priority')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .order('_lastupdated', ascending: false);
          
      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      final complaints = await _processComplaintDataInBackground(response);
      
      _setCachedData(cacheKey, complaints);
      
      return complaints;
    } catch (e) {
      AppLogger.e('[ComplaintService] Error fetching map data: $e');
      rethrow;
    }
  }

  /// Optimized nearby complaints fetch
  Future<List<Complaint>> getComplaintDetailsAndNearby(String complaintId) async {
    try {
      // Use single query with join-like functionality
      final mainResponse = await _supabaseClient
          .from('complaints')
          .select()
          .eq('id', complaintId)
          .single();
      
      final mainComplaint = Complaint.fromJson(mainResponse['id'].toString(), mainResponse);

      // Optimized nearby query with limit
      final nearbyResponse = await _supabaseClient
          .from('complaints')
          .select()
          .eq('suburb', mainComplaint.suburb)
          .neq('id', complaintId)
          .order('_lastupdated', ascending: false)
          .limit(4);

      final nearbyComplaints = await _processComplaintDataInBackground(nearbyResponse);

      return [mainComplaint, ...nearbyComplaints];
    } catch (e) {
      AppLogger.e('[ComplaintService] Error fetching complaint details: $e');
      rethrow;
    }
  }
}

/// Static functions for isolate processing
List<Complaint> _processComplaintDataInIsolate(List<Map<String, dynamic>> rawData) {
  return rawData.map((mapData) {
    final String id = mapData['id'].toString();
    return Complaint.fromJson(id, mapData);
  }).toList();
}

Map<String, dynamic> _processElectorateStatsInIsolate(List<Map<String, dynamic>> rawData) {
  final Map<String, Set<String>> electorateSuburbs = {};
  final Map<String, int> electorateCounts = {};
  
  for (final item in rawData) {
    final electorate = item['electorate'] as String?;
    final suburb = item['suburb'] as String?;
    
    if (electorate != null && suburb != null) {
      electorateSuburbs.putIfAbsent(electorate, () => <String>{}).add(suburb);
      electorateCounts[electorate] = (electorateCounts[electorate] ?? 0) + 1;
    }
  }
  
  final Map<String, dynamic> electorateDetails = {};
  for (final electorate in electorateSuburbs.keys) {
    electorateDetails[electorate] = {
      'suburbs': electorateSuburbs[electorate]!.toList()..sort(),
      'count': electorateCounts[electorate] ?? 0,
    };
  }
  
  return {
    'electorates': electorateSuburbs.keys.toList()..sort(),
    'electorate_details': electorateDetails,
    'total_electorates': electorateSuburbs.length,
  };
}

List<String> _extractDistinctElectoratesInIsolate(List<Map<String, dynamic>> rawData) {
  final Set<String> electorates = {};
  for (final item in rawData) {
    final electorate = item['electorate'] as String?;
    if (electorate != null && electorate.isNotEmpty) {
      electorates.add(electorate);
    }
  }
  return electorates.toList()..sort();
}

List<String> _extractDistinctSuburbsInIsolate(List<Map<String, dynamic>> rawData) {
  final Set<String> suburbs = {};
  for (final item in rawData) {
    final suburb = item['suburb'] as String?;
    if (suburb != null && suburb.isNotEmpty) {
      suburbs.add(suburb);
    }
  }
  return suburbs.toList()..sort();
}


