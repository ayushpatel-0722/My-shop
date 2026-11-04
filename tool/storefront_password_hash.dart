// Prints a salted hash to store in the `password` field of the Firestore
// document `home_screen_confing_password/password` (optional: plain text works
// too, a hash just keeps the password itself out of the database). The password is read from stdin and is never
// written anywhere, so it stays out of the repository and shell history:
//
//   dart run tool/storefront_password_hash.dart
import 'dart:io';

import 'package:myshop/core/services/company_password.dart';

void main() {
  stdout.write('New storefront password: ');
  stdin.echoMode = false;
  final password = stdin.readLineSync() ?? '';
  stdin.echoMode = true;
  stdout.writeln();
  if (password.trim().length < 8) {
    stderr.writeln('Use at least 8 characters.');
    exit(1);
  }
  // A high iteration count: any signed-in user can read this hash.
  stdout.writeln(CompanyPassword.hash(password, iterations: 150000));
}
