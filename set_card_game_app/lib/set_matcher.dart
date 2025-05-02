import 'package:set_card_game_app/card.dart';

/// A class for computing valid sets in a list of cards.
class SetMatcher {
  /// Computes the valid sets of three cards using a brute force approach by simply looking at all
  /// (unique) possible combinations of sets.
  ///
  /// Returns a set of valid sets of three.
  static Set<Set<(Card, T)>> computeBruteForce<T>(List<(Card, T)> allCards) {
    final sets = <Set<(Card, T)>>{};
    for (int i = 0; i < allCards.length; i++) {
      final cardI = allCards[i];
      for (int j = i + 1; j < allCards.length; j++) {
        final cardJ = allCards[j];
        for (int k = j + 1; k < allCards.length; k++) {
          final cardK = allCards[k];
          final set = {cardI, cardJ, cardK};
          if (_cardsFormValidSet(set)) {
            sets.add(set);
          }
        }
      }
    }
    return sets;
  }

  /// Determines whether the three cards form a valid sets.
  /// All four properties must "match" (see the _propertyMatches method) to form a valid set.
  static bool _cardsFormValidSet(Set<(Card, dynamic)> cards) {
    return _propertyMatches(cards, (c) => c.color) &&
        _propertyMatches(cards, (c) => c.shape) &&
        _propertyMatches(cards, (c) => c.filling) &&
        _propertyMatches(cards, (c) => c.count);
  }

  /// Determines whether the three cards could part of a valid set solely based on the specified property.
  /// A set is valid when either all three cards have the same value for the property or all three card have different
  /// values for the property.
  static bool _propertyMatches(Set<(Card, dynamic)> cards, Object Function(Card) propertyFunction) {
    final properties = cards.map((c) => propertyFunction(c.$1)).toSet();
    return properties.length == 1 || properties.length == 3;
  }
}
