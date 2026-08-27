enum Stone {
  empty,
  black,
  white;

  bool get isPlayer => this != Stone.empty;

  Stone get opponent {
    switch (this) {
      case Stone.black:
        return Stone.white;
      case Stone.white:
        return Stone.black;
      case Stone.empty:
        return Stone.empty;
    }
  }

  String get label => switch (this) {
        Stone.black => 'Black',
        Stone.white => 'White',
        Stone.empty => 'Empty',
      };
}
