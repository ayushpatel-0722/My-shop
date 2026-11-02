/// Turns a failed Google sign-in into something a person (and a developer
/// reading a screenshot) can act on, instead of a raw platform exception.
///
/// The Android plugin reports every setup problem as `sign_in_failed` with an
/// `ApiException` code: 10 means this build's SHA-1 / package name is not
/// registered in Firebase, 12500 a missing support email or OAuth client,
/// 7 no network, 12501 the user closed the picker.
String describeGoogleSignInError(Object error) {
  final text = error.toString();
  if (text.contains('ApiException: 10') || text.contains('DEVELOPER_ERROR')) {
    return 'Google sign-in is not set up for this app build '
        '(SHA-1 fingerprint missing in Firebase). Code 10.';
  }
  if (text.contains('ApiException: 12500') || text.contains('12500')) {
    return 'Google sign-in is not fully configured in Firebase '
        '(OAuth client or support email). Code 12500.';
  }
  if (text.contains('ApiException: 7') ||
      text.contains('network_error') ||
      text.contains('network-request-failed')) {
    return 'No internet connection. Check your network and try again.';
  }
  if (text.contains('ApiException: 12501') || text.contains('canceled')) {
    return 'Google sign-in was cancelled.';
  }
  if (text.contains('account-exists-with-different-credential')) {
    return 'An account already exists with this email using another '
        'sign-in method.';
  }
  return text.replaceFirst('Exception: ', '');
}
