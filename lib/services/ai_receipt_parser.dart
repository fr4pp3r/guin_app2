import 'package:flutter/foundation.dart';
import 'package:guin_app/services/ai_service.dart';
import 'package:guin_app/utils/image_compressor.dart';
import 'package:guin_app/utils/helpers.dart';
import 'dart:io';

class GcashReceiptParse {
  const GcashReceiptParse({
    this.referenceNumber,
    this.amount,
    this.paidAt,
    required this.confidence,
    required this.parsedAt,
  });

  final String? referenceNumber;
  final double? amount;
  final DateTime? paidAt;
  final double confidence;
  final DateTime parsedAt;

  Map<String, dynamic> toJson() => {
        'referenceNumber': referenceNumber,
        'amount': amount,
        'paidAt': paidAt?.toIso8601String(),
        'confidence': confidence,
        'parsedAt': parsedAt.toIso8601String(),
      };

  static GcashReceiptParse? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final paidAtStr = json['paidAt'] as String?;
    final parsedAtStr = json['parsedAt'] as String?;
    return GcashReceiptParse(
      referenceNumber: json['referenceNumber'] as String?,
      amount: json['amount'] is num ? (json['amount'] as num).toDouble() : null,
      paidAt: paidAtStr != null ? DateTime.tryParse(paidAtStr) : null,
      confidence: json['confidence'] is num ? (json['confidence'] as num).toDouble() : 0,
      parsedAt: parsedAtStr != null ? DateTime.tryParse(parsedAtStr)! : Helpers.now(),
    );
  }
}

class AiReceiptParser {
  AiReceiptParser({AiService? service}) : _service = service ?? AiService();

  final AiService _service;

  Future<GcashReceiptParse?> parseFile(File file, {double? expectedAmount}) async {
    final base64 = await ImageCompressor.toBase64PngForReceipt(file);
    if (base64 == null) return null;
    return parseBase64(base64, expectedAmount: expectedAmount);
  }

  Future<GcashReceiptParse?> parseBase64(String base64, {double? expectedAmount}) async {
    final payload = <String, dynamic>{'receipt_b64': base64};
    if (expectedAmount != null) payload['expectedAmount'] = expectedAmount;
    final res = await _service.invoke('receipt-parser', payload);
    if (res == null) return null;
    try {
      final ref = res['referenceNumber'] as String? ?? res['reference_number'] as String?;
      final amount = res['amount'] is num ? (res['amount'] as num).toDouble() : null;
      final date = res['date'] as String?;
      final confidence = res['confidence'] is num ? (res['confidence'] as num).toDouble() : 0.0;
      final ambiguous = res['ambiguous'] == true;
      if (ambiguous) return null;
      final parsedAt = Helpers.now();
      return GcashReceiptParse(
        referenceNumber: _normalizeRef(ref),
        amount: amount,
        paidAt: date != null ? DateTime.tryParse(date) : null,
        confidence: confidence.clamp(0, 1),
        parsedAt: parsedAt,
      );
    } catch (e) {
      debugPrint('AiReceiptParser: parse error $e');
      return null;
    }
  }

  String? _normalizeRef(String? ref) {
    if (ref == null || ref.trim().isEmpty) return null;
    final cleaned = ref.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (cleaned.isEmpty) return null;
    return cleaned;
  }
}
