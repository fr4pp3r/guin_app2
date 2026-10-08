class PaymentRecord {
  final String id;
  final String requestId;
  final String userId;
  final String paymentMethod;
  final double amount;
  final String? referenceNumber;
  final String? receiptUrl;
  final String status;
  final String? encodedBy;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? rejectionReason;
  final String? remarks;
  final DateTime createdAt;

  PaymentRecord({
    required this.id,
    required this.requestId,
    required this.userId,
    required this.paymentMethod,
    required this.amount,
    this.referenceNumber,
    this.receiptUrl,
    required this.status,
    this.encodedBy,
    this.verifiedBy,
    this.verifiedAt,
    this.rejectionReason,
    this.remarks,
    required this.createdAt,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      userId: json['user_id'] as String,
      paymentMethod: json['payment_method'] as String,
      amount: (json['amount'] as num).toDouble(),
      referenceNumber: json['reference_number'] as String?,
      receiptUrl: json['receipt_url'] as String?,
      status: json['status'] as String,
      encodedBy: json['encoded_by'] as String?,
      verifiedBy: json['verified_by'] as String?,
      verifiedAt: json['verified_at'] != null ? DateTime.parse(json['verified_at'] as String) : null,
      rejectionReason: json['rejection_reason'] as String?,
      remarks: json['remarks'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
