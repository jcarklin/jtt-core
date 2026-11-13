import 'dart:convert';
import 'package:xml/xml.dart';

import '../models/gtt_project.dart';
import '../models/project.dart';
import '../models/tablet.dart';
import '../models/thread.dart';
import '../utils/color_utils.dart';

/// Platform-agnostic service for bidirectional conversion between legacy
/// Guntram's Tabletweaving Thingy (`.gtt` XML) and canonical `.jtt` JSON.
class FileConversionService {
  final TwData gttData;
  final Project project;

  const FileConversionService._({
    required this.gttData,
    required this.project,
  });

  /// Parses a `.gtt` XML string and converts it into a [Project].
  factory FileConversionService.fromGttXml(String xmlInput) {
    final document = XmlDocument.parse(xmlInput);
    final root = document.getElement('TWData');
    if (root == null) {
      throw const FormatException('Invalid .gtt XML: missing <TWData> root');
    }
    final twData = TwData.fromXml(root);
    final project = _convertTwDataToProject(twData);
    return FileConversionService._(gttData: twData, project: project);
  }

  /// Parses a `.jtt` JSON string and converts it into a [TwData] XML model.
  factory FileConversionService.fromJttJson(String jsonInput) {
    final decoded = jsonDecode(jsonInput) as Map<String, dynamic>;
    final project = Project.fromJson(decoded);
    final twData = _convertProjectToTwData(project);
    return FileConversionService._(gttData: twData, project: project);
  }

  /// Serializes the internal [project] to formatted `.jtt` JSON.
  String toJttJson() => project.toPrettyJson();

  /// Serializes the [gttData] model to formatted `.gtt` XML.
  String toGttXml() => gttData.toXml();

  static Project _convertTwDataToProject(TwData twData) {
    final gttPattern = twData.pattern;

    final mappedPatternType = switch (gttPattern.type) {
      GttProject.patternTypeThreaded => Project.patternTypeThreadedIn,
      GttProject.patternTypeDoubleFace => Project.patternTypeDoubleWeave,
      GttProject.patternTypeBrokenTwill => Project.patternTypeBrokenTwill,
      GttProject.patternTypeBrocade => Project.patternTypeBrocade,
      GttProject.patternTypeLetteredBand => Project.patternTypeLetteredBand,
      _ => throw FormatException(
          'Unsupported GTT pattern type: "${gttPattern.type}"',
        ),
    };

    final deck = gttPattern.cards.cards
        .asMap()
        .entries
        .map((e) => _convertGttCardToTablet(e.key, e.value))
        .toList();

    final packsMap = <String, List<int>>{
      for (final pack in gttPattern.packs.packs) pack.name: pack.cardIndices,
    };

    final hexColors = gttPattern.palette.colours
        .map((c) => ColorUtils.bgrIntToHex(c.value))
        .toList();

    final palettes = <String, List<String>>{
      if (hexColors.isNotEmpty) gttPattern.palette.name: hexColors,
    };

    // Replay pick actions onto each tablet
    for (final gttPick in gttPattern.picks.pickList) {
      final actions = gttPick.actions.actions;

      // 1. Collect all 1-based card IDs that receive a Twist (flip) on this pick
      final twistedCardIds = <int>{};
      for (final action in actions) {
        if (action.type == GttActionType.twist) {
          if (action.target == GttTarget.card && action.targetId is int) {
            twistedCardIds.add(action.targetId as int);
          } else if (action.target == GttTarget.pack &&
              action.targetId is String) {
            final packCards = packsMap[action.targetId as String];
            if (packCards != null) {
              twistedCardIds.addAll(packCards);
            }
          }
        }
      }

      // 2. Track which cards explicitly received a Turn action
      final turnedCardIds = <int>{};
      for (final action in actions) {
        if (action.type != GttActionType.turn) continue;

        if (action.target == GttTarget.card && action.targetId is int) {
          final cardId = action.targetId as int;
          if (cardId >= 1 && cardId <= deck.length) {
            turnedCardIds.add(cardId);
            _applyTurnAction(
              action,
              deck[cardId - 1],
              isTwist: twistedCardIds.contains(cardId),
            );
          }
        } else if (action.target == GttTarget.pack &&
            action.targetId is String) {
          final packCards = packsMap[action.targetId as String] ?? const [];
          for (final cardId in packCards) {
            if (cardId >= 1 && cardId <= deck.length) {
              turnedCardIds.add(cardId);
              _applyTurnAction(
                action,
                deck[cardId - 1],
                isTwist: twistedCardIds.contains(cardId),
              );
            }
          }
        }
      }

      // 3. Any card that was twisted (flipped) without a separate Turn action
      //    still advances one pick with an idle turn.
      for (final cardId in twistedCardIds) {
        if (!turnedCardIds.contains(cardId) &&
            cardId >= 1 &&
            cardId <= deck.length) {
          deck[cardId - 1].turn(TurnDirection.idle, isTwist: true);
        }
      }
    }

    return Project(
      name: gttPattern.name,
      type: Project.projectTypeTabletWeaving,
      patternType: mappedPatternType,
      patternSource: twData.source,
      slantRepresentation: Project.slantThread,
      deck: deck,
      packs: packsMap,
      palettes: palettes,
      extraInfo: gttPattern.notes,
    );
  }

  static void _applyTurnAction(
    GttAction action,
    Tablet tablet, {
    required bool isTwist,
  }) {
    final direction = switch (action.dir) {
      GttDir.f => TurnDirection.forwards,
      GttDir.b => TurnDirection.backwards,
      GttDir.i => TurnDirection.idle,
    };

    final steps = action.dist < 1 ? 1 : action.dist;
    for (var step = 0; step < steps; step++) {
      // Flip only happens once before the turn steps
      tablet.turn(direction, isTwist: step == 0 && isTwist);
    }
  }

  static Tablet _convertGttCardToTablet(int index, GttCard gttCard) {
    final threads = gttCard.holes.colours
        .asMap()
        .entries
        .map((e) => Thread(e.key, e.value))
        .toList(growable: false);

    return Tablet(
      threadPositions: threads,
      startingTwist: gttCard.threading == GttThreading.s
          ? TwistDirection.s
          : TwistDirection.z,
      deckIndex: index,
    );
  }

  static TwData _convertProjectToTwData(Project project) {
    final cards = project.deck.map(_convertTabletToGttCard).toList();

    final gttPatternType = switch (project.patternType) {
      Project.patternTypeThreadedIn => GttProject.patternTypeThreaded,
      Project.patternTypeDoubleWeave => GttProject.patternTypeDoubleFace,
      Project.patternTypeBrokenTwill => GttProject.patternTypeBrokenTwill,
      Project.patternTypeBrocade => GttProject.patternTypeBrocade,
      Project.patternTypeLetteredBand => GttProject.patternTypeLetteredBand,
      _ => GttProject.patternTypeThreaded,
    };

    return TwData(
      source: project.patternSource ?? 'jtt_core',
      version: '1.15',
      pattern: GttProject(
        name: project.name,
        notes: project.extraInfo,
        cards: GttCards(cards),
        type: gttPatternType,
        palette: _convertPalettesToGtt(project.palettes),
        picks: _convertDeckToGttPicks(project.deck),
        packs: _convertPacksToGtt(project.packs),
      ),
    );
  }

  static GttCard _convertTabletToGttCard(Tablet tablet) {
    final holes = GttHoles(
      colours: tablet.threadPositions.map((t) => t.colourIndex).toList(),
    );
    final threading = tablet.startingTwist == TwistDirection.s
        ? GttThreading.s
        : GttThreading.z;

    return GttCard(
      holes: holes,
      threading: threading,
      curThread: threading,
      curPos: 0,
      curHoles: holes,
      holeCount: holes.count,
      number: tablet.deckIndex + 1,
    );
  }

  static GttPalette _convertPalettesToGtt(
    Map<String, List<String>> palettes,
  ) {
    if (palettes.isEmpty) {
      return const GttPalette(name: '', size: 0, colours: []);
    }
    final entry = palettes.entries.first;
    final colours = entry.value
        .asMap()
        .entries
        .map(
          (e) => GttColour(
            index: e.key + 1,
            value: ColorUtils.hexToBgrInt(e.value),
          ),
        )
        .toList();

    return GttPalette(
      name: entry.key,
      size: colours.length,
      colours: colours,
    );
  }

  static GttPicks _convertDeckToGttPicks(List<Tablet> deck) {
    if (deck.isEmpty || deck.first.picks.isEmpty) {
      return const GttPicks([]);
    }

    final pickCount = deck.first.picks.length;
    final picks = <GttPick>[];

    for (var pickIdx = 0; pickIdx < pickCount; pickIdx++) {
      final actions = <GttAction>[];

      for (var tabletIdx = 0; tabletIdx < deck.length; tabletIdx++) {
        final tablet = deck[tabletIdx];
        if (pickIdx >= tablet.picks.length) continue;

        final prevTwist = pickIdx == 0
            ? tablet.startingTwist
            : tablet.picks[pickIdx - 1].twist;
        final pick = tablet.picks[pickIdx];
        final cardId = tabletIdx + 1;

        // Emit a separate Twist action if slant flipped on this pick,
        // followed by the Turn action (preserving GTT XML semantics).
        if (pick.wasFlipped || pick.twist != prevTwist) {
          actions.add(
            GttAction(
              type: GttActionType.twist,
              target: GttTarget.card,
              targetId: cardId,
              dir: GttDir.i,
              dist: 1,
            ),
          );
        }

        final dir = switch (pick.turned) {
          TurnDirection.forwards => GttDir.f,
          TurnDirection.backwards => GttDir.b,
          TurnDirection.idle => GttDir.i,
        };

        actions.add(
          GttAction(
            type: GttActionType.turn,
            target: GttTarget.card,
            targetId: cardId,
            dir: dir,
            dist: 1,
          ),
        );
      }

      picks.add(GttPick(index: pickIdx, actions: GttActions(actions)));
    }

    return GttPicks(picks);
  }

  static GttPacks _convertPacksToGtt(Map<String, List<int>> packs) {
    final list = packs.entries
        .map(
          (entry) => GttPack(
            name: entry.key,
            size: entry.value.length,
            cardIndices: entry.value,
          ),
        )
        .toList();
    return GttPacks(list);
  }
}
