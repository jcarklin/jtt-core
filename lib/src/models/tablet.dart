import 'thread.dart';

/// Turning direction for a tablet during a single weft pick.
enum TurnDirection {
  forwards('F'),
  backwards('B'),
  idle('I');

  final String code;
  const TurnDirection(this.code);

  static TurnDirection fromCode(String code) => switch (code) {
        'F' => TurnDirection.forwards,
        'B' => TurnDirection.backwards,
        _ => TurnDirection.idle,
      };
}

/// Physical threading orientation (slant) of a tablet.
enum TwistDirection {
  s('S'),
  z('Z');

  final String code;
  const TwistDirection(this.code);

  TwistDirection get flipped =>
      this == TwistDirection.s ? TwistDirection.z : TwistDirection.s;

  static TwistDirection fromCode(String code) =>
      code == 'Z' ? TwistDirection.z : TwistDirection.s;
}

/// Represents the resulting state of a single tablet after one weft pick.
class Pick {
  /// Active threading slant (`S` or `Z`) during this pick.
  final TwistDirection twist;

  /// Direction the tablet was turned (`F`, `B`, or `I`).
  final TurnDirection turned;

  /// The thread currently positioned on the top shed of the band.
  final Thread visibleThread;

  /// Whether the tablet was flipped (`S` <-> `Z`) prior to turning on this pick.
  final bool wasFlipped;

  const Pick({
    required this.twist,
    required this.turned,
    required this.visibleThread,
    this.wasFlipped = false,
  });

  String get pickKey => '${twist.code}${turned.code}${visibleThread.index}';

  factory Pick.fromJson(Map<String, dynamic> json) => Pick(
        twist: TwistDirection.fromCode(json['twist'] as String),
        turned: TurnDirection.fromCode(json['turned'] as String),
        visibleThread:
            Thread.fromJson(json['visibleThread'] as Map<String, dynamic>),
        wasFlipped: json['wasFlipped'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'twist': twist.code,
        'turned': turned.code,
        'visibleThread': visibleThread.toJson(),
        'wasFlipped': wasFlipped,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pick &&
          runtimeType == other.runtimeType &&
          twist == other.twist &&
          turned == other.turned &&
          visibleThread == other.visibleThread &&
          wasFlipped == other.wasFlipped;

  @override
  int get hashCode => Object.hash(twist, turned, visibleThread, wasFlipped);
}

/// Represents a single tablet (card) in a weaving deck and its pick sequence.
class Tablet {
  final List<Thread> threadPositions;
  final TwistDirection startingTwist;
  final int deckIndex;
  final List<Pick> picks;
  final Map<String, Pick> _pickCache = {};

  Tablet({
    required this.threadPositions,
    required this.startingTwist,
    required this.deckIndex,
    List<Pick>? picks,
  }) : picks = picks ?? <Pick>[];

  /// Returns the most recent pick, or a virtual initial state before pick 0.
  Pick get lastPick => picks.isEmpty
      ? Pick(
          twist: startingTwist,
          turned: TurnDirection.idle,
          visibleThread: threadPositions.first,
        )
      : picks.last;

  /// Advances the tablet by one pick in [turningDirection], optionally flipping
  /// its `S`/`Z` orientation first if [isTwist] is `true`.
  Pick turn(TurnDirection turningDirection, {bool isTwist = false}) {
    final previous = lastPick;
    final newTwist = isTwist ? previous.twist.flipped : previous.twist;
    final lastVisible = previous.visibleThread.index;
    final holeCount = threadPositions.length;

    final int newVisible = switch (turningDirection) {
      TurnDirection.forwards => (lastVisible + 1) % holeCount,
      TurnDirection.backwards => (lastVisible - 1 + holeCount) % holeCount,
      TurnDirection.idle => lastVisible,
    };

    return _addPick(
      newTwist: newTwist,
      turningDirection: turningDirection,
      newVisible: newVisible,
      wasFlipped: isTwist,
    );
  }

  Pick _addPick({
    required TwistDirection newTwist,
    required TurnDirection turningDirection,
    required int newVisible,
    required bool wasFlipped,
  }) {
    final key =
        '${newTwist.code}${turningDirection.code}$newVisible${wasFlipped ? '_T' : ''}';
    final pick = _pickCache.putIfAbsent(
      key,
      () => Pick(
        twist: newTwist,
        turned: turningDirection,
        visibleThread: threadPositions[newVisible],
        wasFlipped: wasFlipped,
      ),
    );
    picks.add(pick);
    return pick;
  }

  factory Tablet.fromJson(Map<String, dynamic> json) => Tablet(
        threadPositions: (json['threadPositions'] as List<dynamic>)
            .map((e) => Thread.fromJson(e as Map<String, dynamic>))
            .toList(),
        startingTwist:
            TwistDirection.fromCode(json['startingTwist'] as String),
        deckIndex: json['deckIndex'] as int,
        picks: (json['picks'] as List<dynamic>?)
                ?.map((e) => Pick.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <Pick>[],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'threadPositions': threadPositions.map((t) => t.toJson()).toList(),
        'startingTwist': startingTwist.code,
        'deckIndex': deckIndex,
        'picks': picks.map((p) => p.toJson()).toList(),
      };
}
