import 'package:xml/xml.dart';

enum GttDir { f, b, i }

enum GttTarget { card, pack }

enum GttActionType { turn, twist }

enum GttThreading { z, s }

/// Root XML wrapper (`<TWData>`) for Guntram's Tabletweaving Thingy `.gtt` files.
class TwData {
  final String source;
  final String version;
  final GttProject pattern;

  const TwData({
    required this.source,
    required this.version,
    required this.pattern,
  });

  factory TwData.fromXml(XmlElement twDataElement) {
    final patternEl = twDataElement.getElement('Pattern');
    if (patternEl == null) {
      throw const FormatException('Invalid .gtt XML: missing <Pattern> element');
    }
    return TwData(
      source: twDataElement.getElement('Source')?.innerText ??
          "Guntram's Tabletweaving Thingy",
      version: twDataElement.getElement('Version')?.innerText ?? '1.15',
      pattern: GttProject.fromXml(patternEl),
    );
  }

  String toXml() {
    final builder = XmlBuilder();
    builder.element('TWData', nest: () {
      builder.element('Source', nest: () => builder.text(source));
      builder.element('Version', nest: () => builder.text(version));
      pattern.toXml(builder);
    });
    return builder.buildDocument().toXmlString(pretty: true);
  }
}

class GttProject {
  static const String patternTypeThreaded = 'Threaded';
  static const String patternTypeDoubleFace = 'DoubleFace';
  static const String patternTypeBrokenTwill = 'BrokenTwill';
  static const String patternTypeBrocade = 'Brocade';
  static const String patternTypeLetteredBand = 'LetteredBand';

  final String name;
  final String type;
  final String? notes;
  final GttCards cards;
  final GttPacks packs;
  final GttPicks picks;
  final GttPalette palette;

  const GttProject({
    required this.name,
    required this.type,
    this.notes,
    required this.cards,
    this.packs = const GttPacks([]),
    this.picks = const GttPicks([]),
    this.palette = const GttPalette(name: '', size: 0, colours: []),
  });

  factory GttProject.fromXml(XmlElement patternElement) {
    final notesEl = patternElement.getElement('Notes');
    final parsedNotes = notesEl == null
        ? ''
        : notesEl.descendants
            .whereType<XmlText>()
            .map((e) => e.value.trim())
            .where((line) => line.isNotEmpty)
            .join('\n');

    final cardsEl = patternElement.getElement('Cards');
    if (cardsEl == null) {
      throw const FormatException('Invalid .gtt XML: missing <Cards> element');
    }

    final packsEl = patternElement.getElement('Packs');
    final picksEl = patternElement.getElement('Picks');
    final paletteEl = patternElement.getElement('Palette');

    return GttProject(
      name: patternElement.getElement('Name')?.innerText ?? 'Untitled',
      type: patternElement.getAttribute('Type') ?? patternTypeThreaded,
      notes: parsedNotes,
      cards: GttCards.fromXml(cardsEl),
      packs: packsEl != null ? GttPacks.fromXml(packsEl) : const GttPacks([]),
      picks: picksEl != null ? GttPicks.fromXml(picksEl) : const GttPicks([]),
      palette: paletteEl != null
          ? GttPalette.fromXml(paletteEl)
          : const GttPalette(name: '', size: 0, colours: []),
    );
  }

  void toXml(XmlBuilder builder) {
    builder.element('Pattern', nest: () {
      builder.attribute('Type', type);
      builder.element('Name', nest: () => builder.cdata(name));

      final exportNotes = [
        if (notes != null && notes!.trim().isNotEmpty) notes!.trim(),
        'Exported from jtt_core',
      ].join('\n');

      builder.element('Notes', nest: () {
        final lines = exportNotes
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();
        for (var i = 0; i < lines.length; i++) {
          builder.element('L${i + 1}', nest: () => builder.cdata(lines[i]));
        }
      });

      cards.toXml(builder);
      packs.toXml(builder);
      picks.toXml(builder);
      palette.toXml(builder);
    });
  }
}

class GttCards {
  final List<GttCard> cards;
  int get count => cards.length;

  const GttCards(this.cards);

  factory GttCards.fromXml(XmlElement cardsXml) {
    final parsedCards = cardsXml
        .findElements('Card')
        .map((element) => GttCard.fromXml(element))
        .toList();
    return GttCards(parsedCards);
  }

  void toXml(XmlBuilder builder) {
    builder.element('Cards', nest: () {
      builder.attribute('Count', count);
      for (final card in cards) {
        card.toXml(builder);
      }
    });
  }
}

class GttCard {
  final GttHoles holes;
  final GttThreading threading;
  final GttThreading curThread;
  final int curPos;
  final GttHoles curHoles;
  final int holeCount;
  final int number;

  const GttCard({
    required this.holes,
    required this.threading,
    required this.curThread,
    this.curPos = 0,
    required this.curHoles,
    required this.holeCount,
    required this.number,
  });

  factory GttCard.fromXml(XmlElement cardElement) {
    final holesEl = cardElement.getElement('Holes');
    if (holesEl == null) {
      throw const FormatException('Invalid .gtt XML: <Card> missing <Holes>');
    }
    final holes = GttHoles.fromXml(holesEl);
    final curHolesEl = cardElement.getElement('CurHoles');
    final threading = cardElement.getElement('Threading')?.innerText == 'Z'
        ? GttThreading.z
        : GttThreading.s;
    final curThreadText = cardElement.getElement('CurThread')?.innerText;
    final curThread = curThreadText == null
        ? threading
        : (curThreadText == 'Z' ? GttThreading.z : GttThreading.s);

    // Fixed bug: read <CurPos> instead of <CurThread>
    final curPos =
        int.tryParse(cardElement.getElement('CurPos')?.innerText ?? '0') ?? 0;

    return GttCard(
      holes: holes,
      threading: threading,
      curThread: curThread,
      curPos: curPos,
      curHoles: curHolesEl != null ? GttHoles.fromXml(curHolesEl) : holes,
      holeCount:
          int.tryParse(cardElement.getAttribute('Holes') ?? '') ?? holes.count,
      number: int.tryParse(cardElement.getAttribute('Number') ?? '1') ?? 1,
    );
  }

  void toXml(XmlBuilder builder) {
    builder.element('Card', nest: () {
      builder.attribute('Holes', holeCount);
      builder.attribute('Number', number);
      holes.toXml(builder, 'Holes');
      builder.element(
        'Threading',
        nest: () => builder.text(threading == GttThreading.s ? 'S' : 'Z'),
      );
      builder.element(
        'CurThread',
        nest: () => builder.text(curThread == GttThreading.s ? 'S' : 'Z'),
      );
      builder.element('CurPos', nest: () => builder.text(curPos));
      curHoles.toXml(builder, 'CurHoles');
    });
  }
}

class GttHoles {
  final List<int?> colours;
  int get count => colours.length;

  const GttHoles({required this.colours});

  factory GttHoles.fromXml(XmlElement holesElement) {
    final parsed = holesElement
        .findElements('Colour')
        .map((e) => int.tryParse(e.innerText.trim()))
        .toList();
    return GttHoles(colours: parsed);
  }

  void toXml(XmlBuilder builder, String elementName) {
    builder.element(elementName, nest: () {
      builder.attribute('Count', count);
      for (final colour in colours) {
        builder.element('Colour', nest: () => builder.text(colour ?? 0));
      }
    });
  }
}

class GttPacks {
  final List<GttPack> packs;
  int get count => packs.length;

  const GttPacks(this.packs);

  factory GttPacks.fromXml(XmlElement packsElement) {
    final parsed = packsElement
        .findElements('Pack')
        .map((e) => GttPack.fromXml(e))
        .toList();
    return GttPacks(parsed);
  }

  void toXml(XmlBuilder builder) {
    builder.element('Packs', nest: () {
      builder.attribute('Count', count);
      for (final pack in packs) {
        pack.toXml(builder);
      }
    });
  }
}

class GttPack {
  final String name;
  final String comment;
  final int size;
  final List<int> cardIndices;

  const GttPack({
    required this.name,
    this.comment = '',
    required this.size,
    required this.cardIndices,
  });

  factory GttPack.fromXml(XmlElement packElement) {
    final rawCards = packElement.getElement('Cards')?.innerText ?? '';
    final indices = rawCards
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();

    return GttPack(
      name: packElement.getAttribute('Name') ?? 'Unknown',
      comment: packElement.getElement('Comment')?.innerText ?? '',
      size: int.tryParse(packElement.getElement('Size')?.innerText ?? '') ??
          indices.length,
      cardIndices: indices,
    );
  }

  void toXml(XmlBuilder builder) {
    builder.element('Pack', nest: () {
      builder.attribute('Name', name);
      builder.element('Comment', nest: () => builder.cdata(comment));
      builder.element('Size', nest: () => builder.text(size));
      builder.element('Cards', nest: () => builder.text(cardIndices.join(',')));
    });
  }
}

class GttPalette {
  final String name;
  final int size;
  final List<GttColour> colours;

  const GttPalette({
    required this.name,
    required this.size,
    required this.colours,
  });

  factory GttPalette.fromXml(XmlElement paletteElement) {
    final parsed = paletteElement
        .findElements('Colour')
        .map((e) => GttColour.fromXml(e))
        .toList();
    return GttPalette(
      name: paletteElement.getAttribute('Name') ?? '',
      size: int.tryParse(paletteElement.getAttribute('Size') ?? '') ??
          parsed.length,
      colours: parsed,
    );
  }

  void toXml(XmlBuilder builder) {
    builder.element('Palette', nest: () {
      builder.attribute('Name', name);
      builder.attribute('Size', size);
      for (final colour in colours) {
        builder.element('Colour', nest: () {
          builder.attribute('Index', colour.index);
          builder.text(colour.value);
        });
      }
    });
  }
}

class GttColour {
  final int index;
  final int value;

  const GttColour({required this.index, required this.value});

  factory GttColour.fromXml(XmlElement colourElement) {
    return GttColour(
      index: int.tryParse(colourElement.getAttribute('Index') ?? '1') ?? 1,
      value: int.tryParse(colourElement.innerText.trim()) ?? 0,
    );
  }
}

class GttPicks {
  final List<GttPick> pickList;
  int get count => pickList.length;

  const GttPicks(this.pickList);

  factory GttPicks.fromXml(XmlElement picksElement) {
    final parsed = picksElement
        .findElements('Pick')
        .map((element) => GttPick.fromXml(element))
        .toList();
    return GttPicks(parsed);
  }

  void toXml(XmlBuilder builder) {
    builder.element('Picks', nest: () {
      builder.attribute('Count', count);
      for (final pick in pickList) {
        pick.toXml(builder);
      }
    });
  }
}

class GttPick {
  final int index;
  final GttActions actions;

  const GttPick({required this.index, required this.actions});

  factory GttPick.fromXml(XmlElement pickElement) {
    final actionsEl = pickElement.getElement('Actions');
    return GttPick(
      index: int.tryParse(pickElement.getAttribute('Index') ?? '0') ?? 0,
      actions: actionsEl != null
          ? GttActions.fromXml(actionsEl)
          : const GttActions([]),
    );
  }

  void toXml(XmlBuilder builder) {
    builder.element('Pick', nest: () {
      builder.attribute('Index', index);
      actions.toXml(builder);
    });
  }
}

class GttActions {
  final List<GttAction> actions;
  int get count => actions.length;

  const GttActions(this.actions);

  factory GttActions.fromXml(XmlElement actionsElement) {
    final parsed = actionsElement
        .findElements('Action')
        .map((e) => GttAction.fromXml(e))
        .toList();
    return GttActions(parsed);
  }

  void toXml(XmlBuilder builder) {
    builder.element('Actions', nest: () {
      builder.attribute('Count', count);
      for (final action in actions) {
        action.toXml(builder);
      }
    });
  }
}

class GttAction {
  final GttActionType type;
  final GttTarget target;
  final Object targetId; // int (1-based card ID) or String (pack name)
  final GttDir dir;
  final int dist;

  const GttAction({
    required this.type,
    required this.target,
    required this.targetId,
    required this.dir,
    this.dist = 1,
  });

  factory GttAction.fromXml(XmlElement actionElement) {
    final type = actionElement.getAttribute('Type') == 'Twist'
        ? GttActionType.twist
        : GttActionType.turn;
    final target = actionElement.getAttribute('Target') == 'Pack'
        ? GttTarget.pack
        : GttTarget.card;
    final rawTid = actionElement.getAttribute('TargetID') ?? '1';
    final Object targetId =
        target == GttTarget.card ? (int.tryParse(rawTid) ?? 1) : rawTid;

    final dir = switch (actionElement.getAttribute('Dir')) {
      'F' => GttDir.f,
      'B' => GttDir.b,
      _ => GttDir.i,
    };

    // Fixed bug: read 'Dist' attribute instead of 'Dir'
    final dist =
        int.tryParse(actionElement.getAttribute('Dist') ?? '1') ?? 1;

    return GttAction(
      type: type,
      target: target,
      targetId: targetId,
      dir: dir,
      dist: dist,
    );
  }

  void toXml(XmlBuilder builder) {
    builder.element('Action', nest: () {
      builder.attribute(
        'Type',
        type == GttActionType.turn ? 'Turn' : 'Twist',
      );
      builder.attribute(
        'Target',
        target == GttTarget.pack ? 'Pack' : 'Card',
      );
      builder.attribute('TargetID', targetId);
      builder.attribute(
        'Dir',
        switch (dir) {
          GttDir.f => 'F',
          GttDir.b => 'B',
          GttDir.i => 'I',
        },
      );
      builder.attribute('Dist', dist);
    });
  }
}
