import 'package:flutter/material.dart';

import '../../models/shipment_request.dart';
import '../../services/payment_service.dart';

/// FR-08 Initial Security Deposit: collects the 10% Commitment Fee. This is
/// a mock gateway screen — tapping "Pay now" simulates success immediately.
/// Swap `PaymentService.payCommitmentFee`'s body for a real JazzCash/
/// EasyPaisa API call later; this screen itself doesn't need to change.
class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key, required this.request});
  final ShipmentRequest request;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _paying = false;

  String _remainingLabel() {
    final due = widget.request.commitmentFeeDueAt?.toDate();
    if (due == null) return 'No due date set';
    final remaining = due.difference(DateTime.now());
    if (remaining.isNegative)
      return 'Overdue \u2014 this booking may be auto-cancelled soon';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    return '${hours}h ${minutes}m remaining to pay (24h from approval)';
  }

  Future<void> _payNow() async {
    setState(() => _paying = true);
    try {
      await PaymentService.payCommitmentFee(widget.request.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF16A34A),
            size: 40,
          ),
          title: const Text('Payment successful'),
          content: const Text(
            'Your commitment fee has been recorded. The operational team will be assigned next.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final amount = request.commitmentFeeAmount ?? (request.totalQuote * 0.10);
    return Scaffold(
      appBar: AppBar(title: const Text('Commitment Fee'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: const Color(0xFFECFEFF),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFF0F766E),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This is a demo payment step. Tapping "Pay now" simulates a successful payment \u2014 '
                              'a real JazzCash/EasyPaisa gateway can be dropped in later without changing this screen.',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${request.pickupCity} \u2192 ${request.destinationCity}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${request.categoryName} \u00b7 ${request.vehicleRegistrationNo}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total quote'),
                              Text(
                                'Rs ${request.totalQuote.toStringAsFixed(0)}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Commitment fee (10%)',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Rs ${amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F766E),
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _remainingLabel(),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _paying ? null : _payNow,
                    icon: const Icon(Icons.payment_outlined),
                    label: _paying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('Pay Rs ${amount.toStringAsFixed(0)} now'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
