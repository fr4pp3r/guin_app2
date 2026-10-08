import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/document_provider.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/utils/helpers.dart';

class PendingPaymentsScreen extends StatefulWidget {
  const PendingPaymentsScreen({super.key});

  @override
  State<PendingPaymentsScreen> createState() => _PendingPaymentsScreenState();
}

class _PendingPaymentsScreenState extends State<PendingPaymentsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<DocumentProvider>().loadPendingPayments();
    });
  }

  Future<void> _verifyPayment(DocumentRequest request) async {
    final authProvider = context.read<AuthProvider>();
    final documentProvider = context.read<DocumentProvider>();

    final confirm = await Helpers.showConfirmDialog(
      context,
      title: 'Confirm Payment',
      message:
          'Confirm this payment of ₱${request.paymentAmount.toStringAsFixed(2)}?\n\n'
          'The request will be forwarded to the Captain for final approval.',
    );

    if (!confirm) return;

    Helpers.showLoadingDialog(context, 'Confirming payment...');
    try {
      await documentProvider.treasurerConfirmPayment(
        requestId: request.id,
        treasurerId: authProvider.userProfile!.id,
      );

      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showSuccessSnackBar(
        context,
        'Payment confirmed — forwarded to Captain for approval',
      );
    } catch (e) {
      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showErrorSnackBar(
        context,
        'Error: ${Helpers.parseSupabaseError(e.toString())}',
      );
    }
  }

  Future<void> _rejectPayment(DocumentRequest request) async {
    final authProvider = context.read<AuthProvider>();
    final documentProvider = context.read<DocumentProvider>();

    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter reason...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                Helpers.showErrorSnackBar(ctx, 'Please provide a reason');
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      reasonController.dispose();
      return;
    }

    Helpers.showLoadingDialog(context, 'Rejecting payment...');
    try {
      await documentProvider.treasurerRejectPayment(
        requestId: request.id,
        treasurerId: authProvider.userProfile!.id,
        reason: reasonController.text.trim(),
      );
      reasonController.dispose();

      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showSuccessSnackBar(
        context,
        'Payment rejected — citizen notified',
      );
    } catch (e) {
      reasonController.dispose();
      if (!mounted) return;
      Helpers.dismissDialog(context);
      Helpers.showErrorSnackBar(
        context,
        'Error: ${Helpers.parseSupabaseError(e.toString())}',
      );
    }
  }

  Future<void> _encodeCashPayment(DocumentRequest request) async {
    final authProvider = context.read<AuthProvider>();
    final documentProvider = context.read<DocumentProvider>();
    final referenceController = TextEditingController();
    String selectedMethod = 'cash_onsite';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Encode Cash Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Amount: ₱${request.paymentAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedMethod,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: const [
                  DropdownMenuItem(
                    value: 'cash_onsite',
                    child: Text('Cash On-Site'),
                  ),
                  DropdownMenuItem(
                    value: 'manual_cashier',
                    child: Text('Manual Cashier'),
                  ),
                ],
                onChanged: (v) => setDialogState(() => selectedMethod = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: referenceController,
                decoration: const InputDecoration(
                  labelText: 'Reference / OR Number (optional)',
                  hintText: 'e.g. OR-2025-001',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) {
      referenceController.dispose();
      return;
    }

    try {
      await documentProvider.encodeCashPayment(
        requestId: request.id,
        treasurerId: authProvider.userProfile!.id,
        method: selectedMethod,
        referenceNumber: referenceController.text.trim().isNotEmpty
            ? referenceController.text.trim()
            : null,
      );
      referenceController.dispose();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash payment encoded & verified'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      referenceController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _viewReceipt(String receiptUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Payment Receipt'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: receiptUrl,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) =>
                      const Center(child: Icon(Icons.error)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF6A1B9A),
                  Color(0xFF7B1FA2),
                  Color(0xFFAB47BC),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.payment_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Treasurer — Payment Verification',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Verify invoices and confirm/reject payments',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Body
          Expanded(
            child: Consumer<DocumentProvider>(
              builder: (context, documentProvider, _) {
                if (documentProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final requests = documentProvider.pendingPayments;
                if (requests.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => documentProvider.loadPendingPayments(),
                    child: ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.payment_outlined,
                                  size: 64,
                                  color: Colors.grey.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No pending payments',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => documentProvider.loadPendingPayments(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card header
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF7B1FA2,
                                ).withValues(alpha: 0.05),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF7B1FA2,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.description_outlined,
                                      color: Color(0xFF7B1FA2),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          request.documentTypeDisplay,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          request.userName ?? 'Unknown user',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      request.statusDisplay,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Details
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _infoRow(
                                    Icons.info_outline,
                                    'Purpose',
                                    request.purpose,
                                  ),
                                  const SizedBox(height: 6),
                                  _infoRow(
                                    Icons.monetization_on_outlined,
                                    'Amount',
                                    '₱${request.paymentAmount.toStringAsFixed(2)}',
                                    valueColor: Colors.green.shade700,
                                  ),
                                  const SizedBox(height: 6),
                                  _infoRow(
                                    Icons.calendar_today_outlined,
                                    'Requested',
                                    _formatDate(request.requestedAt),
                                  ),
                                ],
                              ),
                            ),
                            // Receipt preview
                            if (request.paymentReceiptUrl != null) ...[
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: GestureDetector(
                                  onTap: () =>
                                      _viewReceipt(request.paymentReceiptUrl!),
                                  child: Container(
                                    height: 140,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: CachedNetworkImage(
                                            imageUrl:
                                                request.paymentReceiptUrl!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            placeholder: (_, __) => const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                const Center(
                                                  child: Icon(
                                                    Icons.broken_image_outlined,
                                                  ),
                                                ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.zoom_in,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'View',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            // Actions
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                16,
                              ),
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _encodeCashPayment(request),
                                      icon: const Icon(
                                        Icons.point_of_sale_outlined,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Encode Cash / Manual Payment',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF1976D2,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFF1976D2),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (request.paymentReceiptUrl != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                _rejectPayment(request),
                                            icon: const Icon(
                                              Icons.cancel_outlined,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Reject',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(
                                                color: Colors.red,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _verifyPayment(request),
                                            icon: const Icon(
                                              Icons.check_circle_outlined,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Verify GCash',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
