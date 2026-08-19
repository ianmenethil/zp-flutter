/// Demo placeholder generators for the sample form.
///
/// - [_characterNames] — name pool for random customers.
/// - [randomCustomer] — fresh name/email/reference/phone when the page opens.
/// - [randomAmount] — fresh \$1–\$500 amount when the page opens.
library;

import 'dart:math';

const _mockEmailDomain = 'zenpay.com.au';
const _mockReferencePrefix = 'Frostmourne';
const _defaultPhoneNumber = '0400000000';

const _characterNames = <({String first, String last})>[
  (first: 'Arthas', last: 'Menethil'),
  (first: 'Jaina', last: 'Proudmoore'),
  (first: 'Jim', last: 'Raynor'),
  (first: 'Illidan', last: 'Stormrage'),
  (first: 'Sylvanas', last: 'Windrunner'),
  (first: 'Thrall', last: 'Durotan'),
  (first: 'Sarah', last: 'Kerrigan'),
  (first: 'Zeratul', last: 'Nerazim'),
  (first: 'Tychus', last: 'Findlay'),
  (first: 'Deckard', last: 'Cain'),
];

/// Placeholder identity; blank fields fall back to these values on submit.
({String name, String email, String reference, String phone}) randomCustomer() {
  final random = Random();
  final character = _characterNames[random.nextInt(_characterNames.length)];
  final first = character.first;
  final last = character.last;
  return (
    name: '$first $last',
    email: '${first.toLowerCase()}.${last.toLowerCase()}@$_mockEmailDomain',
    reference: '$_mockReferencePrefix-${random.nextInt(900000) + 100000}',
    phone: _defaultPhoneNumber,
  );
}

/// Placeholder amount (\$1.00–\$500.00); blank amount field falls back to this.
double randomAmount() => (Random().nextInt(49900) + 100) / 100;
