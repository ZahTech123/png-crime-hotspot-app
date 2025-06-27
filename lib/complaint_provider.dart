import 'package:flutter/foundation.dart';
import 'package:ncdc_ccms_app/models.dart';
import 'package:ncdc_ccms_app/complaint_service.dart';
import 'dart:async';

class ComplaintProvider with ChangeNotifier {
  final ComplaintService _complaintService;
  StreamSubscription? _complaintsSubscription;

  ComplaintService get complaintService => _complaintService;

  List<CityComplaint> _complaints = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CityComplaint> get complaints => _complaints;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ComplaintProvider(this._complaintService) {
    _listenToComplaints();
  }

  void _listenToComplaints() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _complaintsSubscription?.cancel();
    _complaintsSubscription = _complaintService.getComplaintsStream().listen((complaintsData) {
      _complaints = complaintsData;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }, onError: (error) {
      if (kDebugMode) {
        print('Error listening to complaints stream: $error');
      }
      _isLoading = false;
      _errorMessage = 'Failed to load complaints. Please try again.';
      notifyListeners();
    });
  }

  Future<void> refreshComplaints() async {
    _listenToComplaints();
  }

  Future<void> addComplaint(CityComplaint complaint) async {
    try {
      await _complaintService.addComplaint(complaint);
    } catch (e) {
      if (kDebugMode) {
        print('Error adding complaint via provider: $e');
      }
      _errorMessage = 'Failed to add complaint.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateComplaint(CityComplaint complaint) async {
    try {
      await _complaintService.updateComplaint(complaint);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating complaint via provider: $e');
      }
      _errorMessage = 'Failed to update complaint.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteComplaint(String id) async {
    try {
      await _complaintService.deleteComplaint(id);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting complaint via provider: $e');
      }
      _errorMessage = 'Failed to delete complaint.';
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _complaintsSubscription?.cancel();
    super.dispose();
  }
}