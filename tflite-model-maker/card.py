class Color:
    GREEN = None
    PURPLE = None
    RED = None

    def __init__(self, color: str):
        self.color = color

    def from_short(color: str):
        if color == 'g':
            return Color.GREEN
        elif color == 'p':
            return Color.PURPLE
        elif color == 'r':
            return Color.RED
        else:
            raise ValueError(f'Invalid color [{color}]')

    def to_short(self):
        return self.color[0]

    def to_long(self):
        return self.color

    def __str__(self):
        return self.to_short()

    def __hash__(self):
        return hash(self.color)

    def __eq__(self, __value):
        if not isinstance(__value, Color):
            return NotImplemented
        return self.color == __value.color


# Now define the instances
Color.GREEN = Color('green')
Color.PURPLE = Color('purple')
Color.RED = Color('red')


class Shape:
    OVAL = None
    RHOMBUS = None
    WAVE = None

    def __init__(self, shape: str):
        self.shape = shape

    def from_short(shape: str):
        if shape == 'o':
            return Shape.OVAL
        elif shape == 'r':
            return Shape.RHOMBUS
        elif shape == 'w':
            return Shape.WAVE
        else:
            raise ValueError(f'Invalid shape [{shape}]')

    def from_long(shape: str):
        if shape == 'oval':
            return Shape.OVAL
        elif shape == 'rhombus':
            return Shape.RHOMBUS
        elif shape == 'wave':
            return Shape.WAVE
        else:
            raise ValueError(f'Invalid shape [{shape}]')

    def to_short(self):
        return self.shape[0]

    def to_long(self):
        return self.shape

    def __str__(self):
        return self.to_short()

    def __hash__(self):
        return hash(self.shape)

    def __eq__(self, __value):
        if not isinstance(__value, Shape):
            return NotImplemented
        return self.shape == __value.shape


Shape.OVAL = Shape('oval')
Shape.RHOMBUS = Shape('rhombus')
Shape.WAVE = Shape('wave')


class Filling:
    EMPTY = None
    FILLED = None
    PARTIAL = None

    def __init__(self, filling: str):
        self.filling = filling

    def from_short(filling: str):
        if filling == 'e':
            return Filling.EMPTY
        elif filling == 'f':
            return Filling.FILLED
        elif filling == 'p':
            return Filling.PARTIAL
        else:
            raise ValueError(f'Invalid filling [{filling}]')

    def from_long(filling: str):
        if filling == 'empty':
            return Filling.EMPTY
        elif filling == 'filled':
            return Filling.FILLED
        elif filling == 'partial':
            return Filling.PARTIAL
        else:
            raise ValueError(f'Invalid filling [{filling}]')

    def to_short(self):
        return self.filling[0]

    def to_long(self):
        return self.filling

    def __str__(self):
        return self.to_short()

    def __hash__(self):
        return hash(self.filling)

    def __eq__(self, __value):
        if not isinstance(__value, Filling):
            return NotImplemented
        return self.filling == __value.filling


Filling.EMPTY = Filling('empty')
Filling.FILLED = Filling('filled')
Filling.PARTIAL = Filling('partial')


class Card:
    def __init__(self, color: Color, shape: Shape, filling: Filling, count: int):
        self.color = color
        self.shape = shape
        self.filling = filling
        self.count = count

    def from_filename(filename: str):
        return Card.from_short(filename.rsplit('.', 1)[0].split('-')[-1])

    def from_short(card: str):
        return Card(Color.from_short(card[0]), Shape.from_short(card[1]), Filling.from_short(card[2]), int(card[3]))

    def __str__(self):
        return f'{self.color}{self.shape}{self.filling}{self.count}'

    def __hash__(self):
        return hash((self.color, self.shape, self.filling, self.count))

    def __eq__(self, __value):
        if not isinstance(__value, Card):
            return NotImplemented
        return self.color == __value.color and self.shape == __value.shape and self.filling == __value.filling and self.count == __value.count
