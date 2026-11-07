import 'package:companion/core/network/api_client.dart';
import 'package:companion/core/network/api_exception.dart';
import 'package:companion/core/storage/token_storage.dart';
import 'package:companion/features/profile/profile_photo_picker.dart';
import 'package:companion/providers/core_providers.dart';
import 'package:companion/services/profile_service.dart';
import 'package:companion/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

final Uint8List _jpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

class _FakePicker extends ImagePicker {
  _FakePicker({this.file, this.error});

  final XFile? file;
  final PlatformException? error;
  ImageSource? requested;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    requested = source;
    if (error != null) throw error!;
    return file;
  }
}

class _FakeProfiles extends ProfileService {
  _FakeProfiles({this.failure}) : super(ApiClient(tokenStorage: TokenStorage()));

  final ApiException? failure;
  Uint8List? uploaded;
  String? uploadedType;

  @override
  Future<String> uploadPhoto(Uint8List bytes, {required String contentType}) async {
    if (failure != null) throw failure!;
    uploaded = bytes;
    uploadedType = contentType;
    return 'https://api.test/media/photos/p1';
  }
}

void main() {
  group('imageContentType', () {
    Uint8List bytes(List<int> values) => Uint8List.fromList(values);

    test('recognises each accepted format from its bytes', () {
      expect(imageContentType(_jpeg), 'image/jpeg');
      expect(imageContentType(bytes(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])), 'image/png');
      expect(
        imageContentType(bytes(<int>[...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits])),
        'image/webp',
      );
    });

    test('refuses anything else, including an empty file', () {
      expect(imageContentType(bytes(<int>[])), isNull);
      expect(imageContentType(bytes('<script>'.codeUnits)), isNull);
      expect(imageContentType(bytes('RIFFxxxxWAVE'.codeUnits)), isNull);
    });
  });

  group('ProfilePhotoPicker', () {
    Future<List<String>> pump(
      WidgetTester tester, {
      required _FakePicker picker,
      required _FakeProfiles profiles,
    }) async {
      final List<String> urls = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            imagePickerProvider.overrideWithValue(picker),
            profileServiceProvider.overrideWithValue(profiles),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Center(
                child: ProfilePhotoPicker(
                  name: 'Sara',
                  imageUrl: null,
                  showButton: true,
                  onUploaded: urls.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      return urls;
    }

    Future<void> choose(WidgetTester tester, String option) async {
      await tester.tap(find.text('Add a photo').first);
      // Long enough for the sheet to finish sliding in, so the option can be tapped.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text(option));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('uploads a photo chosen from the gallery', (WidgetTester tester) async {
      final _FakePicker picker = _FakePicker(file: XFile.fromData(_jpeg));
      final _FakeProfiles profiles = _FakeProfiles();
      final List<String> urls = await pump(tester, picker: picker, profiles: profiles);

      await choose(tester, 'Choose from gallery');

      expect(picker.requested, ImageSource.gallery);
      expect(profiles.uploaded, _jpeg);
      expect(profiles.uploadedType, 'image/jpeg');
      expect(urls, <String>['https://api.test/media/photos/p1']);
    });

    testWidgets('uploads a photo taken with the camera', (WidgetTester tester) async {
      final _FakePicker picker = _FakePicker(file: XFile.fromData(_jpeg));
      final List<String> urls = await pump(tester, picker: picker, profiles: _FakeProfiles());

      await choose(tester, 'Take a photo');

      expect(picker.requested, ImageSource.camera);
      expect(urls, hasLength(1));
    });

    testWidgets('backing out of the gallery changes nothing', (WidgetTester tester) async {
      final _FakeProfiles profiles = _FakeProfiles();
      final List<String> urls = await pump(tester, picker: _FakePicker(), profiles: profiles);

      await choose(tester, 'Choose from gallery');

      expect(profiles.uploaded, isNull);
      expect(urls, isEmpty);
    });

    testWidgets('explains a refused permission', (WidgetTester tester) async {
      final List<String> urls = await pump(
        tester,
        picker: _FakePicker(error: PlatformException(code: 'camera_access_denied')),
        profiles: _FakeProfiles(),
      );

      await choose(tester, 'Take a photo');

      expect(find.textContaining('allow access'), findsOneWidget);
      expect(urls, isEmpty);
    });

    testWidgets('does not send a file that is not an image', (WidgetTester tester) async {
      final _FakeProfiles profiles = _FakeProfiles();
      final List<String> urls = await pump(
        tester,
        picker: _FakePicker(file: XFile.fromData(Uint8List.fromList('not an image'.codeUnits))),
        profiles: profiles,
      );

      await choose(tester, 'Choose from gallery');

      expect(find.textContaining('JPEG, PNG or WebP'), findsOneWidget);
      expect(profiles.uploaded, isNull);
      expect(urls, isEmpty);
    });

    testWidgets('shows the server’s reason when an upload fails', (WidgetTester tester) async {
      final List<String> urls = await pump(
        tester,
        picker: _FakePicker(file: XFile.fromData(_jpeg)),
        profiles: _FakeProfiles(
          failure: const ApiException(message: 'That file is too large.', code: 'TOO_LARGE'),
        ),
      );

      await choose(tester, 'Choose from gallery');

      expect(find.text('That file is too large.'), findsOneWidget);
      expect(urls, isEmpty);
    });
  });
}
