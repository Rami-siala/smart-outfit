import 'dart:io';

import 'package:flutter/material.dart';
import 'package:frontend/app/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/onboarding/preferences_screen.dart';

class DetailsUserScreen extends StatefulWidget {
  final String fullName;
  final DateTime birthDate;
  final String gender;

  const DetailsUserScreen({
    super.key,
    required this.fullName,
    required this.birthDate,
    required this.gender,
  });

  @override
  State<DetailsUserScreen> createState() => _DetailsUserScreenState();
}

class _DetailsUserScreenState extends State<DetailsUserScreen> {
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  String? _selectedImageUrl;
  String? _selectedSkinTone;
  String? _selectedBodyShape;

  bool _isSaving = false;
  bool _isLoadingStoredData = true;

  static const double _profileFrameSize = 196;
  double _profileImageScale = 1.0;

  final List<String> _skinTones = ['Fair', 'Light', 'Medium', 'Tan', 'Dark'];

  final List<String> _bodyShapes = [
    'Slim',
    'Athletic',
    'Regular',
    'Curvy',
    'Plus Size',
  ];

  @override
  void initState() {
    super.initState();
    _loadStoredProfile();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadStoredProfile() async {
    try {
      final profile = await ApiService.getMyProfile();

      if (profile != null) {
        final dynamic heightValue = profile['height'];
        final dynamic weightValue = profile['weight'];

        double? parsedHeight;
        double? parsedWeight;

        if (heightValue is num) {
          parsedHeight = heightValue.toDouble();
        } else if (heightValue is String) {
          parsedHeight = double.tryParse(heightValue);
        }

        if (weightValue is num) {
          parsedWeight = weightValue.toDouble();
        } else if (weightValue is String) {
          parsedWeight = double.tryParse(weightValue);
        }

        final String? savedSkinTone = profile['skin_tone']?.toString();
        final String? savedBodyShape = profile['body_shape']?.toString();
        final String? savedImagePath = profile['profile_image_url']?.toString();

        if (parsedHeight != null) {
          _heightController.text = parsedHeight.toString();
        }

        if (parsedWeight != null) {
          _weightController.text = parsedWeight.toString();
        }

        if (savedSkinTone != null && _skinTones.contains(savedSkinTone)) {
          _selectedSkinTone = savedSkinTone;
        }

        if (savedBodyShape != null && _bodyShapes.contains(savedBodyShape)) {
          _selectedBodyShape = savedBodyShape;
        }

        if (savedImagePath != null && savedImagePath.isNotEmpty) {
          _selectedImageUrl = savedImagePath;
        }
      }
    } catch (e) {
      debugPrint('LOAD PROFILE ERROR: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStoredData = false;
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (pickedFile == null) return;

    await _uploadSelectedImage(pickedFile);
  }

  Future<void> _takePhotoNow() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (pickedFile == null) return;

    await _uploadSelectedImage(pickedFile);
  }

  Future<void> _uploadSelectedImage(XFile pickedFile) async {
    try {
      final uploadedUrl = await ApiService.uploadProfileImage(pickedFile.path);

      if (!mounted) return;

      setState(() {
        _selectedImage = File(pickedFile.path);
        _selectedImageUrl = uploadedUrl;
      });

      _showMessage(
        'Profile image uploaded successfully',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageUrl = null;
      _profileImageScale = 1.0;
    });
  }

  void _increaseImageSize() {
    setState(() {
      if (_profileImageScale < 1.8) {
        _profileImageScale += 0.1;
      }
    });
  }

  void _decreaseImageSize() {
    setState(() {
      if (_profileImageScale > 1.0) {
        _profileImageScale -= 0.1;
      }
    });
  }

  void _showMessage(
    String message, {
    Color backgroundColor = Colors.redAccent,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  double? _parseOptionalDouble(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _saveProfile({required bool goNext}) async {
    if (_isSaving) return;

    final String heightText = _heightController.text.trim();
    final String weightText = _weightController.text.trim();

    if (goNext) {
      if (heightText.isEmpty) {
        _showMessage('Please enter your height');
        return;
      }

      if (weightText.isEmpty) {
        _showMessage('Please enter your weight');
        return;
      }

      if (_selectedSkinTone == null) {
        _showMessage('Please select your skin tone');
        return;
      }

      if (_selectedBodyShape == null) {
        _showMessage('Please select your body shape');
        return;
      }
    }

    final double? height = _parseOptionalDouble(heightText);
    final double? weight = _parseOptionalDouble(weightText);

    if (heightText.isNotEmpty && height == null) {
      _showMessage('Please enter a valid height');
      return;
    }

    if (weightText.isNotEmpty && weight == null) {
      _showMessage('Please enter a valid weight');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ApiService.updateMe(fullName: widget.fullName);

      await ApiService.updateMyProfile(
        birthDate: widget.birthDate,
        gender: widget.gender,
        height: height,
        weight: weight,
        skinTone: _selectedSkinTone,
        bodyShape: _selectedBodyShape,
        profileImageUrl: _selectedImageUrl,
      );

      if (!mounted) return;

      if (goNext) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                PreferencesScreen(selectedGender: widget.gender.toLowerCase()),
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _goBack() => _saveProfile(goNext: false);

  Future<void> _handleNext() => _saveProfile(goNext: true);

  String get _formattedBirthDate {
    return '${widget.birthDate.day}/${widget.birthDate.month}/${widget.birthDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isSaving || _isLoadingStoredData;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            const _DetailsBackground(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight <= 940;
                  final tight = constraints.maxHeight <= 900;
                  final topPadding = tight ? 8.0 : (compact ? 10.0 : 14.0);
                  final bottomPadding =
                      (tight ? 10.0 : (compact ? 14.0 : 24.0)) + bottomInset;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          18,
                          topPadding,
                          18,
                          bottomPadding,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight:
                                constraints.maxHeight -
                                topPadding -
                                bottomPadding,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DetailsTopBar(isBusy: isBusy, onBack: _goBack),
                              SizedBox(height: tight ? 8 : (compact ? 12 : 26)),
                              _DetailsHeroPanel(compact: compact, tight: tight),
                              SizedBox(height: tight ? 8 : (compact ? 10 : 18)),
                              _ProfileSummaryCard(
                                fullName: widget.fullName,
                                gender: widget.gender,
                                birthDate: _formattedBirthDate,
                                compact: compact,
                              ),
                              SizedBox(height: tight ? 8 : (compact ? 10 : 18)),
                              _DetailsCard(
                                heightController: _heightController,
                                weightController: _weightController,
                                selectedSkinTone: _selectedSkinTone,
                                selectedBodyShape: _selectedBodyShape,
                                skinTones: _skinTones,
                                bodyShapes: _bodyShapes,
                                selectedImage: _selectedImage,
                                selectedImageUrl: _selectedImageUrl,
                                profileImageScale: _profileImageScale,
                                isBusy: isBusy,
                                profileFrameSize: _profileFrameSize,
                                compact: compact,
                                tight: tight,
                                onSelectSkinTone: (value) {
                                  setState(() => _selectedSkinTone = value);
                                },
                                onSelectBodyShape: (value) {
                                  setState(() => _selectedBodyShape = value);
                                },
                                onUpload: _pickImageFromGallery,
                                onTakePhoto: _takePhotoNow,
                                onRemove: _removeImage,
                                onIncreaseImageSize: _increaseImageSize,
                                onDecreaseImageSize: _decreaseImageSize,
                              ),
                              SizedBox(height: tight ? 8 : (compact ? 10 : 18)),
                              _BottomActions(
                                isBusy: isBusy,
                                isSaving: _isSaving,
                                compact: compact,
                                onBack: _goBack,
                                onNext: _handleNext,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isLoadingStoredData)
              Container(
                color: Colors.black.withValues(alpha: 0.16),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailsTopBar extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onBack;

  const _DetailsTopBar({required this.isBusy, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: IconButton(
            onPressed: isBusy ? null : onBack,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.manage_accounts_rounded,
                size: 16,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Text(
                'Profile details',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailsHeroPanel extends StatelessWidget {
  final bool compact;
  final bool tight;

  const _DetailsHeroPanel({required this.compact, required this.tight});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        tight ? 16 : (compact ? 18 : 22),
        tight ? 14 : (compact ? 16 : 22),
        tight ? 16 : (compact ? 18 : 22),
        tight ? 14 : (compact ? 16 : 20),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailsBadge(compact: compact, tight: tight),
          SizedBox(height: tight ? 8 : (compact ? 10 : 18)),
          const Text(
            'Question 4 of 5',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: tight ? 4 : (compact ? 6 : 10)),
          Text(
            'Tell us more\nabout you',
            style: TextStyle(
              color: Colors.white,
              fontSize: tight ? 24 : (compact ? 28 : 34),
              height: 1.02,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!tight) ...[
            SizedBox(height: compact ? 6 : 10),
            Text(
              'Add a few profile details now. Your profile image is optional, so you can continue even if you skip it.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: compact ? 13 : 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          SizedBox(height: tight ? 10 : (compact ? 12 : 18)),
          const _DetailsProgressPills(),
        ],
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  final String fullName;
  final String gender;
  final String birthDate;
  final bool compact;

  const _ProfileSummaryCard({
    required this.fullName,
    required this.gender,
    required this.birthDate,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fullName,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                icon: Icons.person_outline_rounded,
                label: 'Gender: $gender',
              ),
              _SummaryChip(
                icon: Icons.cake_outlined,
                label: 'Birth date: $birthDate',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final TextEditingController heightController;
  final TextEditingController weightController;
  final String? selectedSkinTone;
  final String? selectedBodyShape;
  final List<String> skinTones;
  final List<String> bodyShapes;
  final File? selectedImage;
  final String? selectedImageUrl;
  final double profileImageScale;
  final bool isBusy;
  final double profileFrameSize;
  final bool compact;
  final bool tight;
  final ValueChanged<String?> onSelectSkinTone;
  final ValueChanged<String?> onSelectBodyShape;
  final VoidCallback onUpload;
  final VoidCallback onTakePhoto;
  final VoidCallback onRemove;
  final VoidCallback onIncreaseImageSize;
  final VoidCallback onDecreaseImageSize;

  const _DetailsCard({
    required this.heightController,
    required this.weightController,
    required this.selectedSkinTone,
    required this.selectedBodyShape,
    required this.skinTones,
    required this.bodyShapes,
    required this.selectedImage,
    required this.selectedImageUrl,
    required this.profileImageScale,
    required this.isBusy,
    required this.profileFrameSize,
    required this.compact,
    required this.tight,
    required this.onSelectSkinTone,
    required this.onSelectBodyShape,
    required this.onUpload,
    required this.onTakePhoto,
    required this.onRemove,
    required this.onIncreaseImageSize,
    required this.onDecreaseImageSize,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = selectedImageUrl == null
        ? ''
        : ApiService.resolveMediaUrl(selectedImageUrl!);
    final hasImageUrl = resolvedImageUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        tight ? 16 : (compact ? 18 : 20),
        tight ? 16 : (compact ? 18 : 22),
        tight ? 16 : (compact ? 18 : 20),
        tight ? 14 : (compact ? 16 : 20),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.mist,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 16, color: AppTheme.pink),
                SizedBox(width: 8),
                Text(
                  'Required details',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: tight ? 10 : (compact ? 10 : 16)),
          Text(
            'Build your profile',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: tight ? 20 : (compact ? 22 : 24),
              height: 1.08,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!tight) ...[
            const SizedBox(height: 6),
            Text(
              'Complete these profile details to continue. Your profile photo is still optional.',
              style: TextStyle(
                color: AppTheme.navy.withValues(alpha: 0.62),
                fontSize: compact ? 13 : 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          SizedBox(height: tight ? 12 : (compact ? 14 : 22)),
          _InputField(
            controller: heightController,
            label: 'Height (cm)',
            icon: Icons.height_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            compact: compact,
            tight: tight,
          ),
          SizedBox(height: tight ? 9 : (compact ? 10 : 14)),
          _InputField(
            controller: weightController,
            label: 'Weight (kg)',
            icon: Icons.monitor_weight_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            compact: compact,
            tight: tight,
          ),
          SizedBox(height: tight ? 9 : (compact ? 10 : 14)),
          _DropdownField(
            value: selectedSkinTone,
            hint: 'Skin tone',
            icon: Icons.palette_outlined,
            items: skinTones,
            onChanged: onSelectSkinTone,
            compact: compact,
            tight: tight,
          ),
          SizedBox(height: tight ? 9 : (compact ? 10 : 14)),
          _DropdownField(
            value: selectedBodyShape,
            hint: 'Body shape',
            icon: Icons.accessibility_new_rounded,
            items: bodyShapes,
            onChanged: onSelectBodyShape,
            compact: compact,
            tight: tight,
          ),
          SizedBox(height: tight ? 12 : (compact ? 12 : 22)),
          Container(
            padding: EdgeInsets.fromLTRB(
              tight ? 8 : 10,
              tight ? 7 : 8,
              tight ? 8 : 10,
              tight ? 7 : 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FD),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE5ECF5)),
            ),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: isBusy ? null : onTakePhoto,
                  child: Container(
                    width: tight ? 42 : 48,
                    height: tight ? 42 : 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: selectedImage == null
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFFF8FC), Color(0xFFF2F5FA)],
                            )
                          : null,
                      color: selectedImage == null ? null : Colors.white,
                      border: Border.all(
                        color: AppTheme.pink.withValues(alpha: 0.26),
                        width: 1.6,
                      ),
                    ),
                    child: ClipOval(
                      child: selectedImage == null
                          ? hasImageUrl
                                ? Image.network(
                                    resolvedImageUrl,
                                    width: tight ? 42 : 48,
                                    height: tight ? 42 : 48,
                                    fit: BoxFit.cover,
                                  )
                                : Icon(
                                    Icons.add_a_photo_outlined,
                                    size: tight ? 20 : 23,
                                    color: AppTheme.pink,
                                  )
                          : Transform.scale(
                              scale: profileImageScale,
                              child: Image.file(
                                selectedImage!,
                                width: tight ? 42 : 48,
                                height: tight ? 42 : 48,
                                fit: BoxFit.cover,
                                alignment: const Alignment(0, -0.35),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasImageUrl || selectedImage != null
                            ? 'Photo added'
                            : 'Optional photo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!tight)
                        Text(
                          'Tap icon for camera',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.navy.withValues(alpha: 0.48),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: tight ? 108 : 118,
                  height: tight ? 40 : 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.coral, AppTheme.pink],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.pink.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: isBusy ? null : onUpload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: const Text(
                        'Upload',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (selectedImage != null) ...[
            SizedBox(height: tight ? 8 : 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.mist,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.zoom_in_rounded,
                        color: AppTheme.coral,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Adjust image size',
                        style: TextStyle(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(profileImageScale * 100).round()}%',
                        style: TextStyle(
                          color: AppTheme.navy.withValues(alpha: 0.64),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onDecreaseImageSize,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.pink,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: AppTheme.pink.withValues(alpha: 0.20),
                            ),
                          ),
                          child: const Icon(Icons.remove),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onIncreaseImageSize,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.navy,
                            foregroundColor: Colors.white,
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: onRemove,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.coral,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: AppTheme.coral.withValues(alpha: 0.20),
                            ),
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Remove photo',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool isBusy;
  final bool isSaving;
  final bool compact;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _BottomActions({
    required this.isBusy,
    required this.isSaving,
    required this.compact,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: compact ? 48 : 56,
            child: OutlinedButton(
              onPressed: isBusy ? null : onBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
              ),
              child: const Text(
                'Back',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: compact ? 48 : 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Color(0xFFFFF3F7)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: ElevatedButton(
                onPressed: isBusy ? null : onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppTheme.pink,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppTheme.pink,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final bool compact;
  final bool tight;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.keyboardType,
    required this.compact,
    required this.tight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tight ? 46 : (compact ? 50 : 58),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(tight ? 16 : 20),
        border: Border.all(color: const Color(0xFFDDE6F1)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: AppTheme.navy,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(
            color: AppTheme.navy.withValues(alpha: 0.46),
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Icon(icon, color: AppTheme.pink, size: 21),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: tight ? 12 : 18),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String? value;
  final String hint;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool compact;
  final bool tight;

  const _DropdownField({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
    required this.compact,
    required this.tight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tight ? 46 : (compact ? 50 : 58),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(tight ? 16 : 20),
        border: Border.all(color: const Color(0xFFDDE6F1)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.pink, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: Text(
                  hint,
                  style: TextStyle(
                    color: AppTheme.navy.withValues(alpha: 0.46),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                isExpanded: true,
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(18),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                items: items.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsBadge extends StatelessWidget {
  final bool compact;
  final bool tight;

  const _DetailsBadge({required this.compact, required this.tight});

  @override
  Widget build(BuildContext context) {
    final size = tight ? 54.0 : (compact ? 64.0 : 88.0);
    final innerSize = tight ? 34.0 : (compact ? 40.0 : 52.0);
    final iconSize = tight ? 20.0 : (compact ? 23.0 : 28.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.98),
            const Color(0xFFFFF2F7),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppTheme.pink.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.navySoft, AppTheme.navy],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
              size: iconSize,
            ),
          ),
          Positioned(
            top: tight ? 7 : 11,
            right: tight ? 7 : 11,
            child: Container(
              width: tight ? 10 : 14,
              height: tight ? 10 : 14,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.coral, AppTheme.pink],
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsProgressPills extends StatelessWidget {
  const _DetailsProgressPills();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final isCompleted = index == 0 || index == 1 || index == 2;
        final isActive = index == 3;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == 4 ? 0 : 8),
            height: 8,
            decoration: BoxDecoration(
              color: isCompleted || isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _DetailsBackground extends StatelessWidget {
  const _DetailsBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B4E7C), Color(0xFF7A367B), Color(0xFFC03B6F)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            left: -40,
            child: _GlowOrb(
              size: 220,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            top: 160,
            right: -30,
            child: _GlowOrb(
              size: 170,
              color: const Color(0xFFFFC2D9).withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: -40,
            left: 30,
            child: _GlowOrb(
              size: 180,
              color: const Color(0xFFFFE6F1).withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
