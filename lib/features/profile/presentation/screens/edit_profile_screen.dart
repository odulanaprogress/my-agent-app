import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../../core/constants/app_colors.dart';
import '../../../../../../core/widgets/custom_button.dart';

import '../providers/profile_provider.dart';

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _EditProfileScreenContent();
  }
}

class _EditProfileScreenContent extends ConsumerStatefulWidget {
  const _EditProfileScreenContent();

  @override
  ConsumerState<_EditProfileScreenContent> createState() =>
      _EditProfileScreenStateImpl();
}

class _EditProfileScreenStateImpl
    extends ConsumerState<_EditProfileScreenContent> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();

  final _picker = ImagePicker();
  XFile? _pickedImage;
  Uint8List? _imageBytes;

  bool _isSaving = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final profileAsync = ref.read(profileProvider);
    final profile = profileAsync.valueOrNull;
    if (profile != null) {
      final fullName = (profile['fullName'] ?? '').toString();
      _fullNameController.text = fullName;
    }
  }

  Future<void> _loadImage() async {
    if (_pickedImage != null) {
      final bytes = await _pickedImage!.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        centerTitle: true,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load profile: $e')),
        data: (profile) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _buildAvatarPicker(profile),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Full name',
                        hintText: 'Enter your full name',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Full name is required'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    if (_isSaving)
                      const Center(child: CircularProgressIndicator())
                    else
                      CustomButton(
                        text: 'Save changes',
                        onPressed: () async {
                          final ok = _formKey.currentState?.validate() ?? false;
                          if (!ok) return;

                          setState(() => _isSaving = true);
                          try {
                            String? imageUrl;

                            if (_imageBytes != null) {
                              imageUrl = await ref
                                  .read(profileRepositoryProvider)
                                  .uploadProfileImage(_imageBytes!);
                            }

                            await ref
                                .read(profileRepositoryProvider)
                                .updateProfile(
                                  fullName: _fullNameController.text.trim(),
                                  profileImageUrl: imageUrl,
                                );

                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Save failed: $e')),
                            );
                          } finally {
                            if (mounted) setState(() => _isSaving = false);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatarPicker(Map<String, dynamic>? profile) {
    final hasPicked = _pickedImage != null;
    final fullName = (profile?['fullName'] ?? '').toString();
    final imageUrl = (profile?['profileImage'] ?? '').toString();

    Widget avatar;

    if (hasPicked && _imageBytes != null) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(60),
        child: Image.memory(
          _imageBytes!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    } else if (imageUrl.isNotEmpty) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(60),
        child: Image.network(
          imageUrl,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _InitialsAvatar(name: fullName),
        ),
      );
    } else {
      avatar = _InitialsAvatar(name: fullName);
    }

    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 4),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipOval(child: avatar),
          ),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            radius: 22,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                final picked = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (!context.mounted) return;
                if (picked != null) {
                  setState(() => _pickedImage = picked);
                  await _loadImage();
                }
              },
              icon: const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          if (hasPicked)
            Positioned(
              bottom: 0,
              right: 48,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 22,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _pickedImage = null;
                      _imageBytes = null;
                    });
                  },
                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String name;

  const _InitialsAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? 'U'
        : (parts.length == 1
              ? parts.first.characters.first
              : '${parts.first.characters.first}${parts[1].characters.first}');

    return Container(
      width: 120,
      height: 120,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFEAF1FF),
      ),
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 28,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }
}
