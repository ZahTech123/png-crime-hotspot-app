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

  Future<void> fetchAllComplaints() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _complaints = await _complaintService.fetchAllComplaints();
    } catch (e) {
      _errorMessage = 'Failed to load complaints: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addComplaint(CityComplaint complaint) async {
    try {
      await _complaintService.addComplaint(complaint);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to add complaint: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> updateComplaint(CityComplaint complaint) async {
    try {
      await _complaintService.updateComplaint(complaint);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update complaint: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> deleteComplaint(String complaintId) async {
    try {
      await _complaintService.deleteComplaint(complaintId);
      _complaints.removeWhere((c) => c.id == complaintId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete complaint: ${e.toString()}';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _complaintsSubscription?.cancel();
    super.dispose();
  }
}