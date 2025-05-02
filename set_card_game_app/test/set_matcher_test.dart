import 'package:flutter_test/flutter_test.dart';
import 'package:set_card_game_app/card.dart';
import 'package:set_card_game_app/set_matcher.dart';

void main() {
  test('simple match of 3 cards', () {
    final cards = [_createCard('gof1'), _createCard('gof2'), _createCard('gof3')];
    cards.shuffle();
    final sets = SetMatcher.computeBruteForce(cards);
    final expected = {
      {_createCard('gof1'), _createCard('gof2'), _createCard('gof3')},
    };
    expect(sets, equals(expected), reason: 'Computed sets do not match, input was $cards');
  });

  test('simple non-match of 3 cards', () {
    final cards = [_createCard('gof1'), _createCard('gof2'), _createCard('gof1')];
    cards.shuffle();
    final sets = SetMatcher.computeBruteForce(cards);
    final expected = <Card>{};
    expect(sets, equals(expected), reason: 'Computed sets do not match, input was $cards');
  });

  test('one match in 9 cards', () {
    final cards = [
      _createCard('gof1'),
      _createCard('gof2'),
      _createCard('gof3'),
      _createCard('rrf1'),
      _createCard('rre1'),
      _createCard('rre2'),
      _createCard('prf1'),
      _createCard('pre1'),
      _createCard('pre2')
    ];
    cards.shuffle();
    final sets = SetMatcher.computeBruteForce(cards);
    final expected = {
      {_createCard('gof1'), _createCard('gof2'), _createCard('gof3')},
    };
    expect(sets, equals(expected), reason: 'Computed sets do not match, input was $cards');
  });

  test('no match in 9 cards', () {
    final cards = [
      _createCard('gof1'),
      _createCard('grf2'),
      _createCard('gof3'),
      _createCard('rrf1'),
      _createCard('rre1'),
      _createCard('rre2'),
      _createCard('prf1'),
      _createCard('pre1'),
      _createCard('pre2')
    ];
    cards.shuffle();
    final sets = SetMatcher.computeBruteForce(cards);
    final expected = <Card>{};
    expect(sets, equals(expected), reason: 'Computed sets do not match, input was $cards');
  });

  test('multiple matches in 9 cards', () {
    final cards = [
      _createCard('gof1'),
      _createCard('gof2'),
      _createCard('gof3'),
      _createCard('rre1'),
      _createCard('rre2'),
      _createCard('rre3'),
      _createCard('prf1'),
      _createCard('pre1'),
      _createCard('pre2')
    ];
    cards.shuffle();
    final sets = SetMatcher.computeBruteForce(cards);
    final expected = {
      {_createCard('gof1'), _createCard('gof2'), _createCard('gof3')},
      {_createCard('rre1'), _createCard('rre2'), _createCard('rre3')}
    };
    expect(sets, equals(expected), reason: 'Computed sets do not match, input was $cards');
  });
}

(Card, Object) _createCard(String card) {
  return (Card.fromShort(card), 0);
}
