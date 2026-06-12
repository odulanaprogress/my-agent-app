import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/verification_provider.dart';
import '../../domain/verification_type.dart';
import '../../domain/verification_status.dart';
import '../../../../../core/services/cloudinary_service.dart';
import '../../../../auth/presentation/providers/current_user_provider.dart';
import '../../../../../core/services/user_behavior_service.dart';

class UploadVerificationScreen extends ConsumerStatefulWidget {
  const UploadVerificationScreen({super.key});

  @override
  ConsumerState<UploadVerificationScreen> createState() =>
      _UploadVerificationScreenState();
}

class _UploadVerificationScreenState
    extends ConsumerState<UploadVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _documentNumberController = TextEditingController();

  VerificationType _selectedType = VerificationType.nin;

  File? _idFrontFile;
  File? _idBackFile;
  File? _selfieFile;
  File? _propertyOwnershipFile;
  File? _utilityBillFile;

  // Remote URLs for resubmission
  String? _remoteFrontUrl;
  String? _remoteBackUrl;
  String? _remoteSelfieUrl;
  String? _remoteOwnershipUrl;
  String? _remoteUtilityUrl;

  bool _isUploading = false;
  String _uploadProgressMessage = '';

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _fullNameController.text = user.fullName;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(verificationStateProvider);
      if (state.documentData != null) {
        _populateFields(state.documentData!);
      }
      ref.read(verificationControllerProvider).refresh();
    });
  }

  void _populateFields(Map<String, dynamic> doc) {
    setState(() {
      final user = ref.read(currentUserProvider);
      if (_fullNameController.text.isEmpty || (user != null && _fullNameController.text == user.fullName)) {
        final docName = doc['fullName'] as String?;
        if (docName != null && docName.isNotEmpty) {
          _fullNameController.text = docName;
        }
      }
      if (_documentNumberController.text.isEmpty) {
        final docNum = doc['documentNumber'] as String?;
        if (docNum != null && docNum.isNotEmpty) {
          _documentNumberController.text = docNum;
        }
      }
      final typeStr = doc['verificationType'] as String?;
      if (typeStr != null) {
        final matchedType = VerificationType.values.firstWhere(
          (e) => e.asFirestoreValue == typeStr,
          orElse: () => VerificationType.nin,
        );
        _selectedType = matchedType;
      }
      _remoteFrontUrl = doc['documentFront'] as String?;
      _remoteBackUrl = doc['documentBack'] as String?;
      _remoteSelfieUrl = doc['selfieImage'] as String?;
      _remoteOwnershipUrl = doc['propertyOwnershipDoc'] as String?;
      _remoteUtilityUrl = doc['utilityBill'] as String?;
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _documentNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF0F172A)),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF0F172A)),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() {
          final file = File(picked.path);
          switch (type) {
            case 'front':
              _idFrontFile = file;
              _remoteFrontUrl = null;
              break;
            case 'back':
              _idBackFile = file;
              _remoteBackUrl = null;
              break;
            case 'selfie':
              _selfieFile = file;
              _remoteSelfieUrl = null;
              break;
            case 'ownership':
              _propertyOwnershipFile = file;
              _remoteOwnershipUrl = null;
              break;
            case 'utility':
              _utilityBillFile = file;
              _remoteUtilityUrl = null;
              break;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final isLandlord = user.role == 'landlord';

    // Validation using either selected local files or existing remote URLs
    final hasFront = _idFrontFile != null || (_remoteFrontUrl != null && _remoteFrontUrl!.isNotEmpty);
    if (!hasFront) {
      _showError('Please select ID Document Front photo');
      return;
    }
    // Passports typically don't have a back page that needs uploading, but other cards do
    if (_selectedType != VerificationType.internationalPassport) {
      final hasBack = _idBackFile != null || (_remoteBackUrl != null && _remoteBackUrl!.isNotEmpty);
      if (!hasBack) {
        _showError('Please select ID Document Back photo');
        return;
      }
    }
    final hasSelfie = _selfieFile != null || (_remoteSelfieUrl != null && _remoteSelfieUrl!.isNotEmpty);
    if (!hasSelfie) {
      _showError('Please take a selfie photo');
      return;
    }
    if (isLandlord) {
      final hasOwnership = _propertyOwnershipFile != null || (_remoteOwnershipUrl != null && _remoteOwnershipUrl!.isNotEmpty);
      if (!hasOwnership) {
        _showError('Landlords must provide Property Ownership Document');
        return;
      }
      final hasUtility = _utilityBillFile != null || (_remoteUtilityUrl != null && _remoteUtilityUrl!.isNotEmpty);
      if (!hasUtility) {
        _showError('Landlords must provide Utility Bill (Proof of Address)');
        return;
      }
    }

    setState(() {
      _isUploading = true;
      _uploadProgressMessage = 'Initializing upload...';
    });

    try {
      final cloudinary = CloudinaryService();

      String frontUrl = _remoteFrontUrl ?? '';
      if (_idFrontFile != null) {
        setState(() => _uploadProgressMessage = 'Uploading ID Front...');
        final res = await cloudinary.uploadImage(_idFrontFile!);
        if (res == null) throw Exception('Failed to upload ID Front image');
        frontUrl = res;
      }

      String backUrl = _remoteBackUrl ?? '';
      if (_idBackFile != null) {
        setState(() => _uploadProgressMessage = 'Uploading ID Back...');
        final res = await cloudinary.uploadImage(_idBackFile!);
        if (res == null) throw Exception('Failed to upload ID Back image');
        backUrl = res;
      }

      String selfieUrl = _remoteSelfieUrl ?? '';
      if (_selfieFile != null) {
        setState(() => _uploadProgressMessage = 'Uploading Selfie...');
        final res = await cloudinary.uploadImage(_selfieFile!);
        if (res == null) throw Exception('Failed to upload Selfie');
        selfieUrl = res;
      }

      String ownershipUrl = _remoteOwnershipUrl ?? '';
      String utilityUrl = _remoteUtilityUrl ?? '';

      if (isLandlord) {
        if (_propertyOwnershipFile != null) {
          setState(() => _uploadProgressMessage = 'Uploading Ownership Document...');
          final resOwner = await cloudinary.uploadImage(_propertyOwnershipFile!);
          if (resOwner == null) throw Exception('Failed to upload Ownership Document');
          ownershipUrl = resOwner;
        }

        if (_utilityBillFile != null) {
          setState(() => _uploadProgressMessage = 'Uploading Utility Bill...');
          final resUtil = await cloudinary.uploadImage(_utilityBillFile!);
          if (resUtil == null) throw Exception('Failed to upload Utility Bill');
          utilityUrl = resUtil;
        }
      }

      setState(() => _uploadProgressMessage = 'Saving verification details...');

      await ref.read(verificationControllerProvider).submitVerification(
            verificationType: _selectedType,
            fullName: _fullNameController.text.trim(),
            documentNumber: _documentNumberController.text.trim(),
            documentFront: frontUrl,
            documentBack: backUrl,
            selfieImage: selfieUrl,
            propertyOwnershipDoc: ownershipUrl,
            utilityBill: utilityUrl,
            role: user.role,
          );

      // Log verification submission behavior
      await UserBehaviorService.logVerificationSubmit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification submitted successfully! Pending review.'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgressMessage = '';
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VerificationState>(verificationStateProvider, (previous, next) {
      if (next.documentData != null && (previous == null || previous.documentData == null)) {
        _populateFields(next.documentData!);
      }
    });

    final user = ref.watch(currentUserProvider);
    final isLandlord = user?.role == 'landlord';
    final state = ref.watch(verificationStateProvider);
    final isPending = state.status == VerificationStatus.pending;

    if (isPending) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Identity Verification', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFFFEF3C7),
                  child: Icon(Icons.pending_actions_rounded, size: 50, color: Colors.orange),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verification Under Review',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your identity documents have been submitted and are currently being reviewed by our admin team. Inputs are locked to prevent duplicate submissions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Back to Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Identity Verification',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display Rejection Feedback at the top if verification was rejected
                    if (state.status == VerificationStatus.rejected && state.rejectionReason != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Verification Rejected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF991B1B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              state.rejectionReason!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF7F1D1D),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Please correct the highlighted fields/documents and resubmit.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF991B1B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Header Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isLandlord
                              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                              : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            child: Icon(
                              isLandlord ? Icons.gavel_rounded : Icons.person_search_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isLandlord ? 'Landlord Verification Flow' : 'Tenant Verification Flow',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isLandlord
                                      ? 'Requires ID document, selfie, utility bill & property documents.'
                                      : 'Requires government-issued ID document & a selfie verification.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Applicant Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter your legal full name',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Please enter your full name' : null,
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Document Type & Number',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<VerificationType>(
                      initialValue: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Select ID Type',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      items: VerificationType.values.where((e) => e != VerificationType.bvn).map((type) {
                        return DropdownMenuItem<VerificationType>(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _documentNumberController,
                      decoration: InputDecoration(
                        labelText: 'ID / Document Number',
                        hintText: 'Enter number matching your selected ID',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Please enter the ID document number' : null,
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Document Uploads',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildImageUploadCard(
                      title: 'ID Front Side Photo',
                      subtitle: 'Ensure all details are clearly readable',
                      file: _idFrontFile,
                      imageUrl: _remoteFrontUrl,
                      onTap: () => _pickImage('front'),
                      onClear: () {
                        setState(() {
                          _idFrontFile = null;
                          _remoteFrontUrl = null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    if (_selectedType != VerificationType.internationalPassport) ...[
                      _buildImageUploadCard(
                        title: 'ID Back Side Photo',
                        subtitle: 'Upload the rear side of your ID card',
                        file: _idBackFile,
                        imageUrl: _remoteBackUrl,
                        onTap: () => _pickImage('back'),
                        onClear: () {
                          setState(() {
                            _idBackFile = null;
                            _remoteBackUrl = null;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    _buildImageUploadCard(
                      title: 'Selfie Photo',
                      subtitle: 'Hold a clear neutral pose in good lighting',
                      file: _selfieFile,
                      imageUrl: _remoteSelfieUrl,
                      onTap: () => _pickImage('selfie'),
                      onClear: () {
                        setState(() {
                          _selfieFile = null;
                          _remoteSelfieUrl = null;
                        });
                      },
                      isSelfie: true,
                    ),
                    const SizedBox(height: 24),

                    if (isLandlord) ...[
                      const Text(
                        'Landlord Documents',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildImageUploadCard(
                        title: 'Property Ownership Document',
                        subtitle: 'Upload C of O, Deed of Assignment, or Governor\'s Consent',
                        file: _propertyOwnershipFile,
                        imageUrl: _remoteOwnershipUrl,
                        onTap: () => _pickImage('ownership'),
                        onClear: () {
                          setState(() {
                            _propertyOwnershipFile = null;
                            _remoteOwnershipUrl = null;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildImageUploadCard(
                        title: 'Utility Bill / Proof of Address',
                        subtitle: 'Power or water bill from past 3 months',
                        file: _utilityBillFile,
                        imageUrl: _remoteUtilityUrl,
                        onTap: () => _pickImage('utility'),
                        onClear: () {
                          setState(() {
                            _utilityBillFile = null;
                            _remoteUtilityUrl = null;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _isUploading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Submit Verification',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              alignment: Alignment.center,
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFF0F172A),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _uploadProgressMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Do not close the app or go back.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageUploadCard({
    required String title,
    required String subtitle,
    required File? file,
    required String? imageUrl,
    required VoidCallback onTap,
    required VoidCallback onClear,
    bool isSelfie = false,
  }) {
    final hasImage = file != null || (imageUrl != null && imageUrl.isNotEmpty);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasImage ? Colors.green.shade200 : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      image: file != null
                          ? DecorationImage(
                              image: FileImage(file),
                              fit: BoxFit.cover,
                            )
                          : (imageUrl != null && imageUrl.isNotEmpty)
                              ? DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: !hasImage
                        ? Icon(
                            isSelfie ? Icons.face_rounded : Icons.photo_library_outlined,
                            color: const Color(0xFF64748B),
                            size: 28,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasImage)
                    IconButton(
                      icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                      onPressed: onClear,
                    )
                  else
                    const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Color(0xFF64748B),
                      size: 22,
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
