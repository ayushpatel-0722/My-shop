# Firestore rules tests

Runs `../firestore.rules` in the local Firestore emulator and checks what a
packer, a dispatcher, an employee without permissions, an admin and an
outsider may do to an order.

```sh
cd firestore_rules_test
npm install
npm test          # needs Java 11+ and Node 18+
```

Run it before every `firebase deploy --only firestore:rules` (`make rules-deploy`).
