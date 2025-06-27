// complaint_service.dart
// import 'package:cloud_firestore/cloud_firestore.dart'; // Remove Firestore import
import 'models.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase

class ComplaintService {
  // Add SupabaseClient field
  final SupabaseClient _supabaseClient;

  // Constructor accepts and stores the client
  ComplaintService({required SupabaseClient supabaseClient})
      : _supabaseClient = supabaseClient;

  Stream<List<CityComplaint>> getComplaintsStream() {
    print('[ComplaintService] Subscribing to complaints stream...'); // Log subscription
    return _supabaseClient
        .from('complaints')
        .stream(primaryKey: ['id']) // Specify primary key column(s)
        .order('_lastupdated', ascending: false) // Use snake_case for column name
        .map((listOfMaps) {
          print('[ComplaintService] Received raw complaints data: ${listOfMaps.length} items'); // Log raw data
          // Map the list of maps using the factory constructor
          try {
            final complaints = listOfMaps.map((mapData) {
              // Supabase includes 'id' in the map, use it directly
              // Assuming 'id' is returned as a string or can be cast to string.
              // Adjust if your ID type is different (e.g., int)
              final String id = mapData['id'].toString(); 
              return CityComplaint.fromJson(id, mapData);
            }).toList();
            print('[ComplaintService] Parsed complaints: ${complaints.length} items'); // Log parsed count
            return complaints;
          } catch (e) {
            print('[ComplaintService] Error parsing complaints stream: $e');
            return <CityComplaint>[]; // Return empty list on error
          }
        });
  }

  // Remove the Firestore-specific _mapDocument method
  /*
  CityComplaint _mapDocument(DocumentSnapshot doc) { ... }
  */

  Future<void> addComplaint(CityComplaint complaint) async {
    try {
      // Use the toJson method from the model
      final dataToInsert = complaint.toJson();
      
      // Insert into Supabase table
      await _supabaseClient.from('complaints').insert(dataToInsert);
      
    } catch (e) {
      print('Error adding complaint: $e');
      // Rethrow or handle error appropriately
      rethrow; 
    }
  }

  // Add methods for updating and deleting if needed, using Supabase client:
  // Example Update:
  Future<void> updateComplaint(CityComplaint complaint) async {
    try {
      final dataToUpdate = complaint.toJson();
      // Assuming 'id' is the primary key
      await _supabaseClient
          .from('complaints')
          .update(dataToUpdate)
          .eq('id', complaint.id); // Use .eq for matching the ID
    } catch (e) {
       print('Error updating complaint: $e');
       rethrow;
    }
  }

  // Example Delete:
  Future<void> deleteComplaint(String complaintId) async {
    try {
      await _supabaseClient
          .from('complaints')
          .delete()
          .eq('id', complaintId);
    } catch (e) {
       print('Error deleting complaint: $e');
       rethrow;
    }
  }

  // --- Electorate Methods ---

  // Fetch all distinct electorate names from the complaints table
  Future<List<String>> getElectorates() async {
    print('[ComplaintService] Fetching distinct electorates...');
    try {
      // Use Supabase RPC or a view for distinct, or fetch all and process client-side
      // Simpler approach: Fetch all 'electorate' column values and make them distinct client-side
      final List<Map<String, dynamic>> data = await _supabaseClient
          .from('complaints') 
          .select('electorate'); // Select only the electorate column
      
      print('[ComplaintService] Raw electorate data fetched: ${data.length} rows');
      
      // Extract names and make them distinct
      final electorateNames = data
          .map((mapData) => mapData['electorate'] as String?) // Cast to String?
          .where((name) => name != null && name.isNotEmpty) // Filter out null or empty names
          .whereType<String>() // Add this to ensure non-nullable String type
          .toSet() // Convert to Set to get unique names
          .toList(); // Convert back to List
          
      print('[ComplaintService] Distinct electorate names: $electorateNames');
      return electorateNames;
    } catch (e) {
      print('[ComplaintService] Error fetching distinct electorates: $e');
      rethrow;
    }
  }

  // Fetch distinct suburbs for a given electorate
  Future<List<String>> getSuburbsForElectorate(String electorateName) async {
    print('[ComplaintService] Fetching suburbs for electorate: $electorateName');
    try {
      final List<Map<String, dynamic>> data = await _supabaseClient
          .from('complaints')
          .select('suburb') // Select only the suburb column
          .eq('electorate', electorateName); // Filter by electorate name

      print('[ComplaintService] Raw suburb data fetched for $electorateName: ${data.length} rows');
      
      // Extract names and make them distinct
      final suburbNames = data
          .map((mapData) => mapData['suburb'] as String?) // Cast to String?
          .where((name) => name != null && name.isNotEmpty) // Filter out null or empty names
          .whereType<String>() // Add this to ensure non-nullable String type
          .toSet() // Convert to Set to get unique names
          .toList(); // Convert back to List
          
      print('[ComplaintService] Distinct suburbs for $electorateName: $suburbNames');
      return suburbNames;
    } catch (e) {
      print('[ComplaintService] Error fetching suburbs for electorate $electorateName: $e');
      rethrow;
    }
  }

  // Get count of complaints for a specific electorate
  Future<int> getComplaintCountForElectorate(String electorateName) async {
    print('[ComplaintService] Fetching complaint count for electorate: $electorateName');
    try {
      // Use Supabase count method (simplified syntax)
      final response = await _supabaseClient
          .from('complaints')
          .count() // Try without explicit CountOption
          .eq('electorate', electorateName);

      print('[ComplaintService] Complaint count for $electorateName: $response');
      return response; 
    } catch (e) {
      print('[ComplaintService] Error counting complaints for electorate $electorateName: $e');
      return 0; // Return 0 on error
    }
  }

  // Get a stream of complaints filtered by electorate
  Stream<List<CityComplaint>> getComplaintsByElectorateStream(String electorateName) {
    return _supabaseClient
        .from('complaints')
        .stream(primaryKey: ['id'])
        .eq('electorate', electorateName) // Filter by electorate
        .order('_lastupdated', ascending: false)
        .map((listOfMaps) {
          return listOfMaps.map((mapData) {
            final String id = mapData['id'].toString();
            return CityComplaint.fromJson(id, mapData);
          }).toList();
        });
  }

}


