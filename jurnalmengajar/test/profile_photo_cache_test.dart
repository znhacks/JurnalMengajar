import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jurnalmengajar/core/services/profile_photo_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePhotoCache().resetForTesting();
  });

  test('avatar is stored locally and can be reused without network', () async {
    const userId = 'user-avatar';
    const photoUrl = 'https://example.com/profile.jpg?t=1';
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      expect(request.url.toString(), photoUrl);
      return http.Response.bytes(
        bytes,
        200,
        headers: {'content-type': 'image/jpeg'},
      );
    });

    final fetched = await http.runWithClient(
      () => ProfilePhotoCache().fetch(userId, photoUrl),
      () => client,
    );
    expect(fetched, orderedEquals(bytes));
    expect(ProfilePhotoCache().cached(userId, photoUrl), orderedEquals(bytes));
    expect(requestCount, 1);

    // Simulate an app restart: memory is empty, storage still has the photo.
    await pumpEventQueue();
    ProfilePhotoCache().resetForTesting();
    expect(ProfilePhotoCache().cached(userId, photoUrl), isNull);

    await ProfilePhotoCache().loadFromStorage(userId, photoUrl);
    expect(ProfilePhotoCache().cached(userId, photoUrl), orderedEquals(bytes));
    expect(requestCount, 1);
  });

  test('non-image responses are not cached', () async {
    const userId = 'user-avatar';
    const photoUrl = 'https://example.com/error';
    final client = MockClient(
      (request) async => http.Response(
        '<html>not an image</html>',
        200,
        headers: {'content-type': 'text/html'},
      ),
    );

    final fetched = await http.runWithClient(
      () => ProfilePhotoCache().fetch(userId, photoUrl),
      () => client,
    );

    expect(fetched, isNull);
    expect(ProfilePhotoCache().cached(userId, photoUrl), isNull);
  });
}
