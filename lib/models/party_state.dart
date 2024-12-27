class PartyState {
  final String id;
  final List players;
  final bool isJoin;
  final bool isOver;
  final List tracks;

  PartyState({
    required this.id,
    required this.players,
    required this.isJoin,
    required this.isOver,
    required this.tracks,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'players': players,
        'isJoin': isJoin,
        'isOver': isOver,
        'tracks': tracks,
      };
}
