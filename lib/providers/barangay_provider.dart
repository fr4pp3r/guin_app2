import 'package:flutter/foundation.dart';
import 'package:guin_app/models/barangay_config.dart';
import 'package:guin_app/models/document_fee.dart';
import 'package:guin_app/services/barangay_service.dart';

class BarangayProvider with ChangeNotifier {
  final BarangayService _barangayService = BarangayService();

  BarangayConfig? _config;
  List<DocumentFee> _fees = [];
  bool _isLoading = false;
  String? _error;

  BarangayConfig? get config => _config;
  List<DocumentFee> get fees => _fees;
  bool get isLoading => _isLoading;
  String? get error => _error;

  DocumentFee? getFeeByType(String documentType) {
    try {
      return _fees.firstWhere((fee) => fee.documentType == documentType);
    } catch (e) {
      return null;
    }
  }

  Future<void> loadConfig() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _config = await _barangayService.getBarangayConfig();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadFees() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _fees = await _barangayService.getDocumentFees();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateConfig({
    required String id,
    required String gcashName,
    required String gcashNumber,
    required String barangayName,
    required String barangayAddress,
    String? barangayCaptain,
    String? contactNumber,
    String? email,
    String? logoUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _config = await _barangayService.updateBarangayConfig(
        id: id,
        gcashName: gcashName,
        gcashNumber: gcashNumber,
        barangayName: barangayName,
        barangayAddress: barangayAddress,
        barangayCaptain: barangayCaptain,
        contactNumber: contactNumber,
        email: email,
        logoUrl: logoUrl,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateFee({
    required String id,
    required double feeAmount,
    String? description,
    required bool isFree,
  }) async {
    try {
      final updatedFee = await _barangayService.updateDocumentFee(
        id: id,
        feeAmount: feeAmount,
        description: description,
        isFree: isFree,
      );

      final index = _fees.indexWhere((f) => f.id == id);
      if (index != -1) {
        _fees[index] = updatedFee;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
