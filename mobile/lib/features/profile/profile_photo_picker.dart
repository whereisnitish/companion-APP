import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_exception.dart';
import '../../providers/core_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/press_effect.dart';

final Provider<ImagePicker> imagePickerProvider = Provider<ImagePicker>((Ref ref) => ImagePicker());

/// Reads a file's type from its first bytes, since a picked file's name and
/// reported type are not reliable. Null means it is not a type the server accepts.
String? imageContentType(Uint8List bytes) {
  bool startsWith(List<int> prefix, [int offset = 0]) {
    if (bytes.length < offset + prefix.length) return false;
    for (int i = 0; i < prefix.length; i += 1) {
      if (bytes[offset + i] != prefix[i]) return false;
    }
    return true;
  }

  if (startsWith(const <int>[0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (startsWith(const <int>[0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (startsWith('RIFF'.codeUnits) && startsWith('WEBP'.codeUnits, 8)) return 'image/webp';
  return null;
}

/// A person's picture with the way to change it: tap for gallery or camera.
///
/// [onUploaded] receives the new URL. The caller saves it with the rest of the
/// profile, so backing out of a screen leaves the current picture in place.
class ProfilePhotoPicker extends ConsumerStatefulWidget {
  const ProfilePhotoPicker({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.onUploaded,
    this.size = 96,
    this.showButton = false,
  });

  final String name;
  final String? imageUrl;
  final ValueChanged<String> onUploaded;
  final double size;
  final bool showButton;

  @override
  ConsumerState<ProfilePhotoPicker> createState() => _ProfilePhotoPickerState();
}

class _ProfilePhotoPickerState extends ConsumerState<ProfilePhotoPicker> {
  /// A profile picture never needs more than this, and keeps uploads small.
  static const double _maxDimension = 1080;
  static const int _quality = 85;

  bool _isUploading = false;

  Future<void> _change() async {
    if (_isUploading) return;

    final ImageSource? source = await AppSheet.show<ImageSource>(
      context,
      builder: (BuildContext sheetContext) => AppSheet(
        title: 'Add a photo',
        subtitle: 'Use a clear photo of yourself.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppButton(
              label: 'Choose from gallery',
              icon: Icons.photo_library_outlined,
              onPressed: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Take a photo',
              icon: Icons.camera_alt_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final XFile? file = await ref.read(imagePickerProvider).pickImage(
            source: source,
            maxWidth: _maxDimension,
            maxHeight: _maxDimension,
            imageQuality: _quality,
          );
      if (file == null || !mounted) return;

      setState(() => _isUploading = true);

      final Uint8List bytes = await file.readAsBytes();
      final String? contentType = imageContentType(bytes);
      if (contentType == null) {
        if (mounted) AppSnackbar.error(context, 'Please use a JPEG, PNG or WebP photo.');
        return;
      }

      final String url = await ref
          .read(profileServiceProvider)
          .uploadPhoto(bytes, contentType: contentType);
      if (mounted) widget.onUploaded(url);
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    } on PlatformException catch (error) {
      if (!mounted) return;
      final bool denied = error.code.endsWith('access_denied');
      AppSnackbar.error(
        context,
        denied
            ? 'Please allow access in your phone’s settings, then try again.'
            : source == ImageSource.camera
                ? 'We could not open the camera.'
                : 'We could not open your gallery.',
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool hasPhoto = widget.imageUrl?.isNotEmpty ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PressEffect(
          onTap: _change,
          scale: 0.94,
          child: Stack(
            children: <Widget>[
              AppAvatar(
                name: widget.name.isEmpty ? 'You' : widget.name,
                imageUrl: widget.imageUrl,
                size: widget.size,
                ring: colors.primary,
              ),
              if (_isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.canvas.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.canvas, width: 2),
                  ),
                  child: Icon(Icons.camera_alt_outlined, size: 14, color: colors.onPrimary),
                ),
              ),
            ],
          ),
        ),
        if (widget.showButton) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: hasPhoto ? 'Change photo' : 'Add a photo',
            icon: Icons.add_a_photo_outlined,
            variant: AppButtonVariant.secondary,
            expand: false,
            onPressed: _isUploading ? null : _change,
          ),
        ],
      ],
    );
  }
}
