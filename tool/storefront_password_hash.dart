// Prints the salted hash to store as `passwordHash` in the Firestore document
// `storefront_config/lock`. The password is read from stdin and is never
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
  stdout.writeln(CompanyPassword.hash(password));
}
