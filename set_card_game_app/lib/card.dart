class Card {
  final CardColor color;
  final Shape shape;
  final Filling filling;
  final int count;

  Card(this.color, this.shape, this.filling, this.count);

  static Card fromShort(String card) {
    return Card(CardColor.fromShort(card[0]), Shape.fromShort(card[1]), Filling.fromShort(card[2]), int.parse(card[3]));
  }

  @override
  String toString() {
    return '${color.toShort()}${shape.toShort()}${filling.toShort()}$count';
  }

  @override
  bool operator ==(Object other) {
    return other is Card && other.color == color && other.shape == shape && other.filling == filling && other.count == count;
  }

  @override
  int get hashCode => Object.hash(color, shape, filling, count);
}

enum CardColor {
  GREEN("green"),
  PURPLE("purple"),
  RED("red");

  final String color;

  const CardColor(this.color);

  static CardColor fromShort(String color) {
    switch (color) {
      case "g":
        return GREEN;
      case "p":
        return PURPLE;
      case "r":
        return RED;
      default:
        throw ArgumentError("Invalid color $color");
    }
  }

  String toShort() {
    return color[0];
  }

  String toLong() {
    return color;
  }
}

enum Shape {
  OVAL("oval"),
  RHOMBUS("rhombus"),
  WAVE("wave");

  final String shape;

  const Shape(this.shape);

  static Shape fromShort(String shape) {
    switch (shape) {
      case "o":
        return OVAL;
      case "r":
        return RHOMBUS;
      case "w":
        return WAVE;
      default:
        throw ArgumentError("Invalid shape $shape");
    }
  }

  static Shape fromLong(String shape) {
    switch (shape) {
      case "oval":
        return OVAL;
      case "rhombus":
        return RHOMBUS;
      case "wave":
        return WAVE;
      default:
        throw ArgumentError("Invalid shape $shape");
    }
  }

  String toShort() {
    return shape[0];
  }

  String toLong() {
    return shape;
  }
}

enum Filling {
  EMPTY("empty"),
  FILLED("filled"),
  PARTIAL("partial");

  final String filling;

  const Filling(this.filling);

  static Filling fromShort(String filling) {
    switch (filling) {
      case "e":
        return EMPTY;
      case "f":
        return FILLED;
      case "p":
        return PARTIAL;
      default:
        throw ArgumentError("Invalid filling $filling");
    }
  }

  static Filling fromLong(String filling) {
    switch (filling) {
      case "empty":
        return EMPTY;
      case "filled":
        return FILLED;
      case "partial":
        return PARTIAL;
      default:
        throw ArgumentError("Invalid filling $filling");
    }
  }

  String toShort() {
    return filling[0];
  }

  String toLong() {
    return filling;
  }
}
