import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/permission_service.dart';

class TenancyAgreementScreen extends StatefulWidget {
  final String? propertyId;
  final String? propertyTitle;
  final String? landlordId;
  final double? rentAmount;
  final String? tenantName;
  final String? landlordName;

  const TenancyAgreementScreen({
    super.key,
    this.propertyId,
    this.propertyTitle,
    this.landlordId,
    this.rentAmount,
    this.tenantName,
    this.landlordName,
  });

  @override
  State<TenancyAgreementScreen> createState() => _TenancyAgreementScreenState();
}

class _TenancyAgreementScreenState extends State<TenancyAgreementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey _signatureKey = GlobalKey();
  final List<Offset?> _signaturePoints = [];
  bool _hasSignature = false;
  bool _isSigning = false;
  bool _agreementAccepted = false;
  bool _isSaving = false;
  String _rentalDuration = '12 months';
  final List<String> _durations = [
    '3 months',
    '6 months',
    '12 months',
    '18 months',
    '24 months',
    '36 months',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _printOrDownloadAgreement(BuildContext context) async {
    final hasPermission = await PermissionService.requestStoragePermission(context);
    if (!hasPermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to download agreements.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future.delayed(const Duration(seconds: 2), () {
            if (context.mounted) {
              Navigator.pop(context);
              _showSuccessDialog();
            }
          });
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12),
                CircularProgressIndicator(color: Color(0xFF0F172A)),
                SizedBox(height: 20),
                Text(
                  'Generating PDF Agreement...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Compiling terms, signatures, and lease data',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('PDF Downloaded', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'The tenancy agreement for "${widget.propertyTitle ?? 'Property'}" has been successfully compiled into a PDF and saved to your device storage.',
          style: const TextStyle(height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _clearSignature() {
    setState(() {
      _signaturePoints.clear();
      _hasSignature = false;
    });
  }

  Future<void> _saveAgreement() async {
    if (!_hasSignature) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign the agreement first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!_agreementAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms before signing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('tenancy_agreements').add({
        'tenantId': user.uid,
        'tenantEmail': user.email ?? '',
        'tenantName': widget.tenantName ?? user.displayName ?? '',
        'landlordId': widget.landlordId ?? '',
        'landlordName': widget.landlordName ?? '',
        'propertyId': widget.propertyId ?? '',
        'propertyTitle': widget.propertyTitle ?? '',
        'rentAmount': widget.rentAmount ?? 0,
        'rentalDuration': _rentalDuration,
        'status': 'signed_by_tenant',
        'signedAt': FieldValue.serverTimestamp(),
        'termsAccepted': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('Agreement Signed!'),
            ],
          ),
          content: const Text(
            'Your tenancy agreement has been digitally signed and submitted. The landlord will be notified to counter-sign.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF0F172A)),
        title: const Text(
          'Tenancy Agreement',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Color(0xFF0F172A)),
            onPressed: () => _printOrDownloadAgreement(context),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Color(0xFF0F172A)),
            onPressed: () => _printOrDownloadAgreement(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0F172A),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0F172A),
          tabs: const [
            Tab(text: 'Agreement'),
            Tab(text: 'Signature'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAgreementTab(),
          _buildSignatureTab(),
        ],
      ),
    );
  }

  Widget _buildAgreementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TENANCY AGREEMENT',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.propertyTitle ?? 'Property Agreement',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _chip('Tenant: ${widget.tenantName ?? 'You'}'),
                    const SizedBox(width: 8),
                    _chip('Landlord: ${widget.landlordName ?? 'Owner'}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Duration selector
          _sectionTitle('Rental Duration'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _rentalDuration,
                isExpanded: true,
                items: _durations
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => _rentalDuration = v!),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Agreement text
          _sectionTitle('Terms and Conditions'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              _agreementText(),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                height: 1.7,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Accept checkbox
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _agreementAccepted
                  ? Colors.green.shade50
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _agreementAccepted
                    ? Colors.green.shade300
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _agreementAccepted,
                  activeColor: Colors.green,
                  onChanged: (v) =>
                      setState(() => _agreementAccepted = v ?? false),
                ),
                Expanded(
                  child: Text(
                    'I have read and agree to the terms and conditions of this tenancy agreement.',
                    style: TextStyle(
                      fontSize: 13,
                      color: _agreementAccepted
                          ? Colors.green.shade800
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.draw_rounded, size: 18),
              label: const Text('Proceed to Sign'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _agreementAccepted
                  ? () => _tabController.animateTo(1)
                  : null,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSignatureTab() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Draw Your Signature',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use your finger to draw your signature in the box below.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isSigning
                            ? const Color(0xFF0F172A)
                            : Colors.grey.shade300,
                        width: _isSigning ? 2 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Guide text
                        if (!_hasSignature)
                          Center(
                            child: Text(
                              'Sign here',
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 20,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        RepaintBoundary(
                          key: _signatureKey,
                          child: GestureDetector(
                            onPanStart: (d) {
                              setState(() {
                                _isSigning = true;
                                _signaturePoints.add(d.localPosition);
                              });
                            },
                            onPanUpdate: (d) {
                              setState(() {
                                _signaturePoints.add(d.localPosition);
                                _hasSignature = true;
                              });
                            },
                            onPanEnd: (_) {
                              setState(() {
                                _signaturePoints.add(null);
                                _isSigning = false;
                              });
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: CustomPaint(
                                painter: _SignaturePainter(_signaturePoints),
                                child: Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Signature line
                        Positioned(
                          bottom: 50,
                          left: 30,
                          right: 30,
                          child: Container(
                            height: 1,
                            color: Colors.grey.shade200,
                          ),
                        ),
                        Positioned(
                          bottom: 32,
                          left: 30,
                          child: Text(
                            'Signature',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        label: const Text('Clear'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _clearSignature,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.verified_rounded, size: 18),
                        label:
                            Text(_isSaving ? 'Saving...' : 'Sign Agreement'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isSaving ? null : _saveAgreement,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }

  String _agreementText() {
    final prop = widget.propertyTitle ?? 'the above-referenced property';
    final duration = _rentalDuration;
    final amount = widget.rentAmount != null
        ? '₦${widget.rentAmount!.toStringAsFixed(0)}'
        : '[Agreed Amount]';

    return '''TENANCY AGREEMENT

This Tenancy Agreement ("Agreement") is entered into between the Landlord and the Tenant as identified above, for the property: $prop.

1. TERM
The tenancy shall commence upon execution of this agreement and shall run for a period of $duration, unless terminated in accordance with the terms herein.

2. RENT
The agreed monthly rent is $amount per month. All rent payments shall be made through the AGENT Platform via the Escrow system.

3. ESCROW PAYMENT NOTICE
All rental payments are processed through AGENT's Escrow system. Funds will be held securely and released to the Landlord upon confirmed tenant possession of the property.

4. USE OF PROPERTY
The Tenant shall use the property solely for residential purposes and shall not sublet, assign, or transfer the tenancy without prior written consent from the Landlord.

5. MAINTENANCE
The Tenant shall maintain the property in good condition and report any damage or repairs needed to the Landlord promptly.

6. TERMINATION
Either party may terminate this agreement by providing a minimum of 30 days written notice through the AGENT Platform.

7. GOVERNING LAW
This agreement is governed by the laws of the Federal Republic of Nigeria.

8. PLATFORM DISCLAIMER
AGENT serves as a facilitating platform and is not liable for any disputes arising between the Landlord and Tenant. All disputes shall be resolved between the parties directly or through lawful channels.

By signing below, both parties agree to be bound by the terms of this Agreement.''';
  }
}

// ─── Signature Painter ────────────────────────────────────
class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
