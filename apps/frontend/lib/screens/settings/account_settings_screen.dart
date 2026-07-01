import 'dart:io';

import 'package:flutter/material.dart';
import 'package:frontend/app/app_localizations.dart';
import 'package:frontend/app/app_settings_scope.dart';
import 'package:frontend/screens/auth/sign_in_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:image_picker/image_picker.dart';

const Color _navy = Color(0xFF173B6D);
const Color _mist = Color(0xFFF3F7FB);
const Color _pink = Color(0xFFD970C4);
const Color _coral = Color(0xFFE85B5B);
const Color _textBlue = Color(0xFF3F567A);
const Color _hintGrey = Color(0xFF8D8D8D);

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final List<String> _skinTones = const [
    'Fair',
    'Light',
    'Medium',
    'Tan',
    'Dark',
  ];

  final List<String> _bodyShapes = const [
    'Slim',
    'Athletic',
    'Regular',
    'Curvy',
    'Plus Size',
  ];

  final Map<String, String> _languageLabels = const {
    'en': 'English',
    'fr': 'French',
    'it': 'Italian',
  };

  File? _selectedImage;
  String? _selectedImageUrl;
  String? _selectedSkinTone;
  String? _selectedBodyShape;
  DateTime? _birthDate;
  String? _gender;
  String? _loadErrorMessage;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRemovingImage = false;
  bool _isLoggingOut = false;

  String _selectedLanguageCode = 'en';

  String _initialFullName = '';
  double? _initialHeight;
  double? _initialWeight;
  String? _initialSkinTone;
  String? _initialBodyShape;
  String? _initialProfileImageUrl;
  bool _didLoadAppSettings = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadAppSettings) return;
    final settings = AppSettingsScope.of(context);
    _selectedLanguageCode = settings.locale.languageCode;
    _didLoadAppSettings = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _matchAllowedValue(String? value, List<String> allowedValues) {
    if (value == null) return null;

    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final option in allowedValues) {
      if (option.toLowerCase() == normalized) {
        return option;
      }
    }

    return null;
  }

  Future<void> _loadData() async {
    try {
      final me = await ApiService.getMe();
      final profile = await ApiService.getMyProfile();

      final fullName = (me['full_name'] ?? '').toString().trim();
      final email = (me['email'] ?? '').toString().trim();

      _nameController.text = fullName;
      _emailController.text = email;
      _initialFullName = fullName;
      if (profile != null) {
        final heightValue = profile['height'];
        final weightValue = profile['weight'];

        if (heightValue != null) {
          _heightController.text = heightValue.toString();
          _initialHeight = _parseOptionalDouble(heightValue.toString());
        }

        if (weightValue != null) {
          _weightController.text = weightValue.toString();
          _initialWeight = _parseOptionalDouble(weightValue.toString());
        }

        _selectedSkinTone = _matchAllowedValue(
          profile['skin_tone']?.toString(),
          _skinTones,
        );
        _initialSkinTone = _selectedSkinTone;

        _selectedBodyShape = _matchAllowedValue(
          profile['body_shape']?.toString(),
          _bodyShapes,
        );
        _initialBodyShape = _selectedBodyShape;
        _gender = profile['gender']?.toString();

        final birthDateRaw = profile['birth_date']?.toString();
        if (birthDateRaw != null && birthDateRaw.isNotEmpty) {
          _birthDate = DateTime.tryParse(birthDateRaw);
        }

        _initialProfileImageUrl = profile['profile_image_url']?.toString();
        _selectedImageUrl = _initialProfileImageUrl;
      }
    } catch (e) {
      _loadErrorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int? calculateAge(DateTime? dateOfBirth) {
    if (dateOfBirth == null) return null;

    final today = DateTime.now();
    var age = today.year - dateOfBirth.year;
    final hasHadBirthdayThisYear =
        today.month > dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day >= dateOfBirth.day);

    if (!hasHadBirthdayThisYear) {
      age -= 1;
    }

    return age < 0 ? null : age;
  }

  Future<void> _pickImage() async {
    if (_isBusy) return;

    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (pickedFile == null || !mounted) return;

    try {
      final uploadedUrl = await ApiService.uploadProfileImage(pickedFile.path);

      setState(() {
        _selectedImage = File(pickedFile.path);
        _selectedImageUrl = uploadedUrl;
        _initialProfileImageUrl = uploadedUrl;
      });

      _showMessage(
        'Profile image uploaded successfully',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> removeProfileImage() async {
    final l10n = context.l10n;
    final shouldRemove =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.t('removeProfileImageConfirmTitle')),
            content: Text(l10n.t('removeProfileImageConfirmMessage')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.t('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.t('remove')),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldRemove || !mounted) return;

    setState(() {
      _isRemovingImage = true;
    });

    try {
      await ApiService.updateMyProfile(clearProfileImage: true);

      if (!mounted) return;

      setState(() {
        _selectedImage = null;
        _selectedImageUrl = null;
        _initialProfileImageUrl = null;
      });
      _showMessage(
        l10n.t('profileImageRemoved'),
        backgroundColor: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isRemovingImage = false;
        });
      }
    }
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

  bool get _isBusy =>
      _isLoading || _isSaving || _isRemovingImage || _isLoggingOut;

  Future<void> saveLanguage(String languageCode) async {
    final settings = AppSettingsScope.of(context);
    final l10n = context.l10n;
    final previous = _selectedLanguageCode;

    setState(() {
      _selectedLanguageCode = languageCode;
    });

    try {
      await settings.setLanguage(languageCode);
      if (!mounted) return;
      _showMessage(l10n.t('languageSaved'), backgroundColor: Colors.green);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedLanguageCode = previous;
      });
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> saveProfileChanges() async {
    final l10n = context.l10n;
    final fullName = _nameController.text.trim();
    final height = _parseOptionalDouble(_heightController.text);
    final weight = _parseOptionalDouble(_weightController.text);
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (fullName.isEmpty) {
      _showMessage('Please enter your name');
      return;
    }

    if (height == null && _heightController.text.trim().isNotEmpty) {
      _showMessage('Please enter a valid height');
      return;
    }

    if (weight == null && _weightController.text.trim().isNotEmpty) {
      _showMessage('Please enter a valid weight');
      return;
    }

    if (newPassword.isNotEmpty || confirmPassword.isNotEmpty) {
      if (currentPassword.isEmpty) {
        _showMessage('Please enter your current password');
        return;
      }

      if (newPassword.length < 6) {
        _showMessage('New password must be at least 6 characters');
        return;
      }

      if (newPassword != confirmPassword) {
        _showMessage('New password and confirmation do not match');
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (fullName != _initialFullName) {
        await ApiService.updateMe(fullName: fullName);
        _initialFullName = fullName;
      }

      final bool profileChanged =
          height != _initialHeight ||
          weight != _initialWeight ||
          _selectedSkinTone != _initialSkinTone ||
          _selectedBodyShape != _initialBodyShape ||
          (_selectedImageUrl ?? '') != (_initialProfileImageUrl ?? '');

      if (profileChanged) {
        await ApiService.updateMyProfile(
          birthDate: _birthDate,
          gender: _gender,
          height: height,
          weight: weight,
          skinTone: _selectedSkinTone,
          bodyShape: _selectedBodyShape,
          profileImageUrl: _selectedImageUrl,
        );

        _initialHeight = height;
        _initialWeight = weight;
        _initialSkinTone = _selectedSkinTone;
        _initialBodyShape = _selectedBodyShape;
        _initialProfileImageUrl = _selectedImageUrl;
      }

      if (newPassword.isNotEmpty) {
        await ApiService.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
      }

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (!mounted) return;
      _showMessage(l10n.t('settingsUpdated'), backgroundColor: Colors.green);
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

  Future<void> _logout() async {
    final l10n = context.l10n;
    final shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.t('logoutConfirmTitle')),
            content: Text(l10n.t('logoutConfirmMessage')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.t('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.t('logout')),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldLogout || !mounted) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await ApiService.logout();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: _textBlue.withValues(alpha: 0.78),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel(label),
        Container(
          height: 58,
          decoration: BoxDecoration(
            color: _mist,
            borderRadius: BorderRadius.circular(18),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            enabled: enabled && !_isBusy,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: _textBlue,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: const TextStyle(
                color: _hintGrey,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(icon, color: _pink),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final safeValue = _matchAllowedValue(value, items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel(hint),
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _mist,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(icon, color: _pink),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: safeValue,
                    hint: Text(
                      hint,
                      style: const TextStyle(
                        color: _hintGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    style: const TextStyle(
                      color: _textBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    items: items
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: _isBusy ? null : onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionForm({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return SettingsSection(
      title: title,
      subtitle: subtitle,
      icon: icon,
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasProfileImage =
        _selectedImage != null ||
        (_selectedImageUrl != null && _selectedImageUrl!.trim().isNotEmpty);
    final displayName = _nameController.text.trim().isEmpty
        ? l10n.t('yourProfile')
        : _nameController.text.trim();
    final displayEmail = _emailController.text.trim().isEmpty
        ? l10n.t('addYourEmail')
        : _emailController.text.trim();
    final age = calculateAge(_birthDate);

    return Scaffold(
      backgroundColor: _mist,
      appBar: AppBar(
        backgroundColor: _mist,
        surfaceTintColor: _mist,
        foregroundColor: _navy,
        elevation: 0,
        title: Text(
          l10n.t('accountSettings'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (_loadErrorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _coral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _coral.withValues(alpha: 0.24)),
                    ),
                    child: Text(
                      _loadErrorMessage!,
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ProfileHeader(
                  image: _selectedImage,
                  imageUrl: _selectedImageUrl,
                  name: displayName,
                  email: displayEmail,
                  ageLabel: age == null ? null : '$age years',
                  genderLabel: _gender,
                  heightLabel: _heightController.text.trim().isEmpty
                      ? null
                      : '${_heightController.text.trim()} cm',
                  weightLabel: _weightController.text.trim().isEmpty
                      ? null
                      : '${_weightController.text.trim()} kg',
                  skinToneLabel: _selectedSkinTone,
                  bodyShapeLabel: _selectedBodyShape,
                  onEdit: _pickImage,
                  editDisabled: _isBusy,
                ),
                const SizedBox(height: 18),
                _buildSectionForm(
                  title: l10n.t('account'),
                  subtitle: l10n.t('accountSubtitle'),
                  icon: Icons.person_outline_rounded,
                  children: [
                    SettingsItem(
                      icon: Icons.edit_outlined,
                      title: l10n.t('editProfile'),
                      subtitle: l10n.t('changePhotoNameDetails'),
                      onTap: _isBusy ? null : _pickImage,
                    ),
                    const SizedBox(height: 18),
                    _buildInputField(
                      controller: _nameController,
                      label: l10n.t('fullName'),
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),
                    _buildInputField(
                      controller: _emailController,
                      label: l10n.t('email'),
                      icon: Icons.email_outlined,
                      enabled: false,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: _heightController,
                            label: l10n.t('height'),
                            icon: Icons.height_rounded,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            controller: _weightController,
                            label: l10n.t('weight'),
                            icon: Icons.monitor_weight_outlined,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildSectionForm(
                  title: l10n.t('preferences'),
                  subtitle: l10n.t('preferencesSubtitle'),
                  icon: Icons.tune_rounded,
                  children: [
                    _buildDropdownField(
                      value: _selectedSkinTone,
                      hint: l10n.t('skinTone'),
                      icon: Icons.palette_outlined,
                      items: _skinTones,
                      onChanged: (value) {
                        setState(() {
                          _selectedSkinTone = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildDropdownField(
                      value: _selectedBodyShape,
                      hint: l10n.t('bodyShape'),
                      icon: Icons.accessibility_new_rounded,
                      items: _bodyShapes,
                      onChanged: (value) {
                        setState(() {
                          _selectedBodyShape = value;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    SettingsItem(
                      icon: Icons.language_rounded,
                      title: l10n.t('language'),
                      subtitle: _languageLabels[_selectedLanguageCode],
                      trailing: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLanguageCode,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          style: const TextStyle(
                            color: _textBlue,
                            fontWeight: FontWeight.w700,
                          ),
                          items: _languageLabels.entries
                              .map(
                                (entry) => DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: _isBusy
                              ? null
                              : (value) {
                                  if (value == null ||
                                      value == _selectedLanguageCode) {
                                    return;
                                  }
                                  saveLanguage(value);
                                },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildSectionForm(
                  title: l10n.t('security'),
                  subtitle: l10n.t('securitySubtitle'),
                  icon: Icons.lock_outline_rounded,
                  children: [
                    SettingsItem(
                      icon: Icons.shield_outlined,
                      title: l10n.t('changePassword'),
                      subtitle: l10n.t('changePasswordSubtitle'),
                    ),
                    const SizedBox(height: 18),
                    _buildInputField(
                      controller: _currentPasswordController,
                      label: l10n.t('currentPassword'),
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                    ),
                    const SizedBox(height: 14),
                    _buildInputField(
                      controller: _newPasswordController,
                      label: l10n.t('newPassword'),
                      icon: Icons.lock_reset_rounded,
                      obscureText: true,
                    ),
                    const SizedBox(height: 14),
                    _buildInputField(
                      controller: _confirmPasswordController,
                      label: l10n.t('confirmPassword'),
                      icon: Icons.verified_user_outlined,
                      obscureText: true,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_coral, _pink],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: _coral.withValues(alpha: 0.22),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isBusy ? null : saveProfileChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.transparent,
                        disabledForegroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              l10n.t('saveChanges'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: !hasProfileImage || _isBusy
                        ? null
                        : removeProfileImage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _pink,
                      side: BorderSide(color: _pink.withValues(alpha: 0.24)),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    icon: _isRemovingImage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _pink,
                            ),
                          )
                        : const Icon(Icons.delete_outline_rounded),
                    label: Text(
                      l10n.t('removeProfileImage'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _coral,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    icon: _isLoggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: Text(
                      l10n.t('logout'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class ProfileHeader extends StatelessWidget {
  final File? image;
  final String? imageUrl;
  final String name;
  final String email;
  final String? ageLabel;
  final String? genderLabel;
  final String? heightLabel;
  final String? weightLabel;
  final String? skinToneLabel;
  final String? bodyShapeLabel;
  final VoidCallback onEdit;
  final bool editDisabled;

  const ProfileHeader({
    super.key,
    required this.image,
    required this.imageUrl,
    required this.name,
    required this.email,
    required this.ageLabel,
    required this.genderLabel,
    required this.heightLabel,
    required this.weightLabel,
    required this.skinToneLabel,
    required this.bodyShapeLabel,
    required this.onEdit,
    required this.editDisabled,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = imageUrl == null
        ? ''
        : ApiService.resolveMediaUrl(imageUrl!);
    final hasImageUrl = resolvedImageUrl.isNotEmpty;
    final primaryPills = <_ProfilePillData>[
      if (genderLabel != null && genderLabel!.trim().isNotEmpty)
        _ProfilePillData(
          icon: Icons.male_rounded,
          label: _toTitleCase(genderLabel!),
        ),
      if (ageLabel != null && ageLabel!.trim().isNotEmpty)
        _ProfilePillData(icon: Icons.calendar_month_rounded, label: ageLabel!),
      if (heightLabel != null && heightLabel!.trim().isNotEmpty)
        _ProfilePillData(icon: Icons.height_rounded, label: heightLabel!),
      if (weightLabel != null && weightLabel!.trim().isNotEmpty)
        _ProfilePillData(
          icon: Icons.monitor_weight_outlined,
          label: weightLabel!,
        ),
    ];
    final detailPills = <_ProfilePillData>[
      if (bodyShapeLabel != null && bodyShapeLabel!.trim().isNotEmpty)
        _ProfilePillData(
          icon: Icons.accessibility_new_rounded,
          label: _toTitleCase(bodyShapeLabel!),
        ),
      if (skinToneLabel != null && skinToneLabel!.trim().isNotEmpty)
        _ProfilePillData(
          icon: null,
          label: '${_toTitleCase(skinToneLabel!)} skin tone',
          accentColor: const Color(0xFFF0B183),
        ),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF123C7C), Color(0xFF061B42)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -28,
            right: -18,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7285E2).withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.01),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF4D86E6), Color(0xFF1E4FAE)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.24),
                              blurRadius: 18,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: image != null
                              ? Image.file(image!, fit: BoxFit.cover)
                              : hasImageUrl
                              ? Image.network(
                                  resolvedImageUrl,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  child: const Icon(
                                    Icons.person_outline_rounded,
                                    color: Colors.white,
                                    size: 34,
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: 0,
                        child: Material(
                          color: _coral,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: editDisabled ? null : onEdit,
                            child: const Padding(
                              padding: EdgeInsets.all(9),
                              child: Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.mail_outline_rounded,
                              color: Colors.white.withValues(alpha: 0.72),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.74),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (primaryPills.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: primaryPills
                                .map((pill) => _ProfileDetailPill(data: pill))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (detailPills.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: detailPills
                        .map(
                          (pill) => _ProfileDetailPill(
                            data: pill,
                            isEmphasized: identical(pill, detailPills.first),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailPill extends StatelessWidget {
  final _ProfilePillData data;
  final bool isEmphasized;

  const _ProfileDetailPill({required this.data, this.isEmphasized = false});

  @override
  Widget build(BuildContext context) {
    final accentColor = data.accentColor ?? const Color(0xFF4D86FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: isEmphasized
            ? LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.08),
                ],
              )
            : null,
        color: isEmphasized ? null : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data.icon != null)
            Icon(data.icon, color: accentColor, size: 16)
          else
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.26),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          Text(
            data.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePillData {
  final IconData? icon;
  final String label;
  final Color? accentColor;

  const _ProfilePillData({
    required this.icon,
    required this.label,
    this.accentColor,
  });
}

String _toTitleCase(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return normalized;

  return normalized
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

class SettingsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const SettingsSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _mist,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _pink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _textBlue.withValues(alpha: 0.68),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _mist,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _pink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: _textBlue.withValues(alpha: 0.66),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing ?? const Icon(Icons.chevron_right_rounded, color: _textBlue),
        ],
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: child,
      ),
    );
  }
}
