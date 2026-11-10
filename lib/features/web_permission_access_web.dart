import 'dart:js_interop';

@JS('nwlRequestCameraPermission')
external JSPromise<JSString> _requestCameraPermission();

@JS('nwlTestReminderSound')
external String _testReminderSound();

/// The browser prompt must originate from a user tap, not from login itself.
Future<String> requestCameraAccess() async =>
    (await _requestCameraPermission().toDart).toDart;

String testReminderSound() => _testReminderSound();
