/// Represents a single hole and its threaded warp color on a weaving tablet.
class Thread {
  /// Zero-based hole index on the tablet (e.g., 0..3 for a 4-hole card).
  final int index;

  /// 1-based index into the project's color palette, or `null` if unthreaded.
  final int? colourIndex;

  const Thread(this.index, this.colourIndex);

  factory Thread.fromJson(Map<String, dynamic> json) => Thread(
        json['index'] as int,
        json['colourIndex'] as int?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'index': index,
        'colourIndex': colourIndex,
      };

  Thread copyWith({int? index, int? colourIndex}) => Thread(
        index ?? this.index,
        colourIndex ?? this.colourIndex,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Thread &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          colourIndex == other.colourIndex;

  @override
  int get hashCode => Object.hash(index, colourIndex);

  @override
  String toString() => 'Thread(index: $index, colourIndex: $colourIndex)';
}
