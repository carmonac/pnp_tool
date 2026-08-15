import 'package:pnp_core/pnp_core.dart';
import 'package:test/test.dart';

void main() {
  test('numeric runs compare as numbers', () {
    expect(compareNatural('card2', 'card10'), lessThan(0));
    expect(compareNatural('card10', 'card2'), greaterThan(0));
    expect(compareNatural('card2', 'card2'), 0);
  });

  test('sorts a mixed list naturally', () {
    final names = ['card10', 'card2', 'card1', 'ace', 'card20', 'card3'];
    names.sort(compareNatural);
    expect(names, ['ace', 'card1', 'card2', 'card3', 'card10', 'card20']);
  });

  test('handles leading zeros and plain strings', () {
    expect(compareNatural('card02', 'card3'), lessThan(0));
    expect(compareNatural('alpha', 'beta'), lessThan(0));
    expect(compareNatural('a1b2', 'a1b10'), lessThan(0));
  });
}
