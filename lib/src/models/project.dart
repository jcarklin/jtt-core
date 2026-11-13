import 'dart:convert';
import 'tablet.dart';

/// Canonical domain model for a tablet weaving project (`.jtt` JSON format).
class Project {
  static const String projectTypeTabletWeaving = 'tabletWeaving';

  static const String patternTypeThreadedIn = 'threadedIn';
  static const String patternTypeDoubleWeave = 'doubleWeave';
  static const String patternTypeBrokenTwill = 'brokenTwill';
  static const String patternTypeBrocade = 'brocade';
  static const String patternTypeLetteredBand = 'letteredBand';

  static const String slantTablet = 'tabletSlant';
  static const String slantThread = 'threadAngle';
  static const String slantArrows = 'arrows';

  static const String threadingClockwise = 'clockwise'; // DA CB
  static const String threadingAnticlockwise = 'anticlockwise'; // AD BC
  static const String threadingPoles = 'poles'; // TF TB BF BB

  String name;
  String type;
  String patternType;
  String? patternSource;
  List<Tablet> deck;
  Map<String, List<int>> packs;
  Map<String, List<String>> palettes;
  String slantRepresentation;
  String threadingDirection;
  String? extraInfo;

  Project({
    required this.name,
    this.type = projectTypeTabletWeaving,
    this.patternType = patternTypeThreadedIn,
    this.patternSource,
    List<Tablet>? deck,
    Map<String, List<int>>? packs,
    Map<String, List<String>>? palettes,
    this.slantRepresentation = slantTablet,
    this.threadingDirection = threadingAnticlockwise,
    this.extraInfo,
  })  : deck = deck ?? <Tablet>[],
        packs = packs ?? <String, List<int>>{},
        palettes = palettes ?? <String, List<String>>{};

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        name: json['name'] as String,
        type: json['type'] as String? ?? projectTypeTabletWeaving,
        patternType: json['patternType'] as String? ?? patternTypeThreadedIn,
        patternSource: json['patternSource'] as String?,
        deck: (json['deck'] as List<dynamic>?)
                ?.map((e) => Tablet.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <Tablet>[],
        packs: (json['packs'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(
                k,
                (v as List<dynamic>).map((e) => e as int).toList(),
              ),
            ) ??
            <String, List<int>>{},
        palettes: (json['palettes'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(
                k,
                (v as List<dynamic>).map((e) => e as String).toList(),
              ),
            ) ??
            <String, List<String>>{},
        slantRepresentation:
            json['slantRepresentation'] as String? ?? slantTablet,
        threadingDirection:
            json['threadingDirection'] as String? ?? threadingAnticlockwise,
        extraInfo: json['extraInfo'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'type': type,
        'patternType': patternType,
        'patternSource': patternSource,
        'deck': deck.map((t) => t.toJson()).toList(),
        'packs': packs,
        'palettes': palettes,
        'slantRepresentation': slantRepresentation,
        'threadingDirection': threadingDirection,
        'extraInfo': extraInfo,
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  @override
  String toString() => toPrettyJson();
}
