import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/features/auth/google_sign_in_errors.dart';

void main() {
  test('Android setup errors are explained', () {
    expect(
      describeGoogleSignInError(
        'PlatformException(sign_in_failed, ApiException: 10: , null, null)',
      ),
      contains('SHA-1'),
    );
    expect(describeGoogleSignInError('ApiException: 12500'), contains('12500'));
    expect(
      describeGoogleSignInError('ApiException: 7: NETWORK_ERROR'),
      contains('internet'),
    );
    expect(
      describeGoogleSignInError('ApiException: 12501'),
      contains('cancelled'),
    );
  });

  test('unknown errors pass through without the Exception prefix', () {
    expect(describeGoogleSignInError(Exception('boom')), 'boom');
  });
}
