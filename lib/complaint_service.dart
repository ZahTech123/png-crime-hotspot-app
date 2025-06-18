import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ncdc_ccms_app/models.dart';
import 'package:ncdc_ccms_app/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Custom Exception
class ComplaintServiceException implements Exception {
  final String message;
  ComplaintServiceException(this.message);
  @override
  String toString() => 'ComplaintServiceException: $message';
}

// Top-level function for background isolate parsing
List<CityComplaint> _parseComplaints(String responseBody) {
  final parsed = json.decode(responseBody).cast<Map<String, dynamic>>();
  return parsed.map<CityComplaint>((json) => CityComplaint.fromJson(json)).toList();
}

class ComplaintService {
  final SupabaseClient _supabaseClient;

  ComplaintService(this._supabaseClient);

  // --- STREAM-BASED METHODS ---
  Stream<List<CityComplaint>> getComplaintsStream() {
    return _supabaseClient
        .from('complaints')
        .stream(primaryKey: ['id'])
        .order('_lastupdated', ascending: false)
        .map((listOfMaps) {
          try {
            return listOfMaps.map((map) => CityComplaint.fromJson(map)).toList();
          } catch (e, s) {
            appLogger.severe('Error in complaints stream processing', e, s);
            // Consider if Stream.error(ComplaintServiceException('Error processing complaints')) is better
            return <CityComplaint>[]; // Or Stream.value([])
          }
        })
        .handleError((e, s) { // Catch errors from the stream source itself
          appLogger.severe('Error fetching complaints stream source', e, s);
          // Depending on how the UI consumes this, Stream.error might be better.
          // For now, returning an empty list to prevent app crash if UI expects a list.
          return <CityComplaint>[];
        });
  }

  // --- CRUD METHODS ---
  Future<void> addComplaint(CityComplaint complaint) async {
    await _supabaseClient.from('complaints').insert(complaint.toJson());
  }

  Future<void> updateComplaint(CityComplaint complaint) async {
    await _supabaseClient
        .from('complaints')
        .update(complaint.toJson())
        .eq('id', complaint.id);
  }

  Future<void> deleteComplaint(String complaintId) async {
    await _supabaseClient
        .from('complaints')
        .delete()
        .eq('id', complaintId);
  }

  // --- ONE-TIME FETCH METHODS ---
  Future<List<CityComplaint>> fetchAllComplaints() async {
    try {
      final response = await _supabaseClient
          .from('complaints') // Corrected table name
          .select() // Select all columns from complaints table only
          .order('created_at', ascending: false);

      final jsonString = json.encode(response);
      return await compute(_parseComplaints, jsonString);
    } catch (e, s) {
      appLogger.severe('Failed to load complaints', e, s);
      throw ComplaintServiceException('Failed to load complaints. Please try again later.');
    }
  }

  Future<List<CityComplaint>> fetchComplaintsByLocation(
      double latitude, double longitude, double radius) async {
    try {
      final response = await _supabaseClient.rpc('get_complaints_in_radius', params: {
        'lat': latitude,
        'lon': longitude,
        'radius_meters': radius
      });

      final jsonString = json.encode(response);
      return await compute(_parseComplaints, jsonString);
    } catch (e, s) {
      appLogger.severe('Failed to load complaints by location', e, s);
      throw ComplaintServiceException('Failed to load complaints by location. Please try again later.');
    }
  }

  // --- ELECTORATE-SPECIFIC METHODS ---
  Future<List<String>> getElectorates() async {
    final List<Map<String, dynamic>> data =
        await _supabaseClient.from('complaints').select('electorate');
    return data
        .map((map) => map['electorate'] as String?)
        .where((name) => name != null && name.isNotEmpty)
        .whereType<String>()
        .toSet()
        .toList();
  }

  Future<List<String>> getSuburbsForElectorate(String electorateName) async {
    final List<Map<String, dynamic>> data = await _supabaseClient
        .from('complaints')
        .select('suburb')
        .eq('electorate', electorateName);

    return data
        .map((map) => map['suburb'] as String?)
        .where((name) => name != null && name.isNotEmpty)
        .whereType<String>()
        .toSet()
        .toList();
  }

  Future<int> getComplaintCountForElectorate(String electorateName) async {
    final response = await _supabaseClient
        .from('complaints')
        .select()
        .eq('electorate', electorateName);
    return response.length;
  }

  Stream<List<CityComplaint>> getComplaintsByElectorateStream(
      String electorateName) {
    return _supabaseClient
        .from('complaints')
        .stream(primaryKey: ['id'])
        .eq('electorate', electorateName)
        .order('_lastupdated', ascending: false)
        .map((listOfMaps) =>
            listOfMaps.map((map) => CityComplaint.fromJson(map)).toList());
  }
}


