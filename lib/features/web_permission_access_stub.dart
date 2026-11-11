Future<String> requestCameraAccess() async => 'unavailable';

String testReminderSound() => 'unavailable';

Future<String> requestDeviceCoordinates() =>
    Future.error(UnsupportedError('Device location is web-only'));
