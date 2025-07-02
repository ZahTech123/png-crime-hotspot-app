import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:ncdc_ccms_app/models.dart';
import 'package:ncdc_ccms_app/complaint_service.dart';
import 'package:ncdc_ccms_app/utils/logger.dart';

class ComplaintProvider with ChangeNotifier {
  final ComplaintService _complaintService;
  StreamSubscription? _complaintsSubscription;
  Timer? _refreshDebounceTimer;
  Timer? _retryTimer;
  bool _isDisposed = false;
  
  // Retry mechanism state
  int _retryAttempts = 0;
  static const int _maxRetryAttempts = 5;
  static const Duration _baseRetryDelay = Duration(seconds: 2);

  ComplaintService get complaintService => _complaintService;

  List<Complaint> _complaints = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Complaint> get complaints => _complaints;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ComplaintProvider(this._complaintService) {
    _initializeStream();
  }

  /// Initialize the stream subscription with retry logic
  void _initializeStream() {
    if (_isDisposed) return;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _complaintsSubscription?.cancel();
    _complaintsSubscription = _complaintService.getComplaintsStream().listen(
      _handleComplaintsData,
      onError: _handleStreamError,
    );
  }

  /// Handle complaints data with background processing
  void _handleComplaintsData(List<Map<String, dynamic>> rawData) async {
    if (_isDisposed) return;

    try {
      // Reset retry attempts on successful data
      _retryAttempts = 0;
      _retryTimer?.cancel();
      
      // Process data in background to avoid blocking UI
      final processedComplaints = await _processComplaintsInBackground(rawData);
      
      if (_isDisposed) return;
      
      _complaints = processedComplaints;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      
    } catch (e) {
      if (!_isDisposed) {
        _handleStreamError(e);
      }
    }
  }

  /// Process complaints data in background isolate
  Future<List<Complaint>> _processComplaintsInBackground(List<Map<String, dynamic>> rawData) async {
    if (rawData.isEmpty) return <Complaint>[];
    
    // For small datasets, process on main thread to avoid isolate overhead
    if (rawData.length <= 50) {
      return rawData.map((data) {
        final String id = data['id'].toString();
        return Complaint.fromJson(id, data);
      }).toList();
    }
    
    // For larger datasets, use compute for background processing
    return await compute(_parseComplaintsInIsolate, rawData);
  }

  /// Handle stream errors with retry mechanism and exponential backoff
  void _handleStreamError(dynamic error) {
    if (_isDisposed) return;
    
    AppLogger.e('Error listening to complaints stream', error);
    
    // Check for specific real-time subscription errors
    final isRealtimeError = error.toString().contains('RealtimeSubscribeException') ||
                           error.toString().contains('channel error') ||
                           error.toString().contains('code: 1006');
    
    if (isRealtimeError && _retryAttempts < _maxRetryAttempts) {
      _retryAttempts++;
      
      // Calculate exponential backoff delay
      final retryDelay = Duration(
        seconds: (_baseRetryDelay.inSeconds * (1 << (_retryAttempts - 1))).clamp(1, 60)
      );
      
      AppLogger.w('[ComplaintProvider] Real-time connection failed. Retry attempt $_retryAttempts/$_maxRetryAttempts in ${retryDelay.inSeconds}s');
      
      _errorMessage = 'Connection lost. Retrying in ${retryDelay.inSeconds}s... (Attempt $_retryAttempts/$_maxRetryAttempts)';
      notifyListeners();
      
      // Schedule retry with exponential backoff
      _retryTimer = Timer(retryDelay, () {
        if (!_isDisposed) {
                  AppLogger.i('[ComplaintProvider] Attempting to reconnect...');
          _initializeStream();
        }
      });
    } else {
      // Max retries reached or non-recoverable error
      _isLoading = false;
      if (_retryAttempts >= _maxRetryAttempts) {
        _errorMessage = 'Connection failed after $_maxRetryAttempts attempts. Please check your internet connection and try refreshing.';
        AppLogger.e('[ComplaintProvider] Max retry attempts reached. Manual refresh required.');
      } else {
        _errorMessage = 'Failed to load complaints. Please try again.';
      }
      notifyListeners();
    }
  }

  /// Debounced refresh to prevent multiple rapid subscriptions
  Future<void> refreshComplaints() async {
    if (_isDisposed) return;
    
    // Cancel any existing refresh timer
    _refreshDebounceTimer?.cancel();
    
    // Set up debounced refresh
    _refreshDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!_isDisposed) {
        _initializeStream();
      }
    });
  }

  /// Force immediate refresh (for cases where debouncing isn't wanted)
  Future<void> forceRefreshComplaints() async {
    if (_isDisposed) return;
    
    _refreshDebounceTimer?.cancel();
    _initializeStream();
  }

  Future<void> addComplaint(Complaint complaint) async {
    if (_isDisposed) return;
    
    try {
      await _complaintService.addComplaint(complaint);
      // Don't refresh immediately - the stream will update automatically
    } catch (e) {
      AppLogger.e('Error adding complaint via provider', e);
      if (!_isDisposed) {
        _errorMessage = 'Failed to add complaint.';
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> updateComplaint(Complaint complaint) async {
    if (_isDisposed) return;
    
    try {
      await _complaintService.updateComplaint(complaint);
      // Don't refresh immediately - the stream will update automatically
    } catch (e) {
      AppLogger.e('Error updating complaint via provider', e);
      if (!_isDisposed) {
        _errorMessage = 'Failed to update complaint.';
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> deleteComplaint(String id) async {
    if (_isDisposed) return;
    
    try {
      await _complaintService.deleteComplaint(id);
      // Don't refresh immediately - the stream will update automatically
    } catch (e) {
      AppLogger.e('Error deleting complaint via provider', e);
      if (!_isDisposed) {
        _errorMessage = 'Failed to delete complaint.';
        notifyListeners();
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _refreshDebounceTimer?.cancel();
    _retryTimer?.cancel();
    _complaintsSubscription?.cancel();
    super.dispose();
  }
}

/// Static function to parse complaints in isolate
List<Complaint> _parseComplaintsInIsolate(List<Map<String, dynamic>> rawData) {
  try {
    return rawData.map((data) {
      final String id = data['id'].toString();
      return Complaint.fromJson(id, data);
    }).toList();
  } catch (e) {
    AppLogger.e('Error parsing complaints in isolate', e);
    return <Complaint>[];
  }
}