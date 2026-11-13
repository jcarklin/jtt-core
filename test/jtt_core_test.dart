import 'package:jtt_core/jtt_core.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

const _sampleXml = '''
<TWData>
  <Source>Guntram's Tabletweaving Thingy</Source>
  <Version>1.12</Version>
  <Pattern Type="BrokenTwill">
    <Name><![CDATA[Test Twill & Twist]]></Name>
    <Notes>
      <L1><![CDATA[First note line]]></L1>
    </Notes>
    <Cards Count="2">
      <Card Holes="4" Number="1">
        <Holes Count="4">
          <Colour>1</Colour>
          <Colour>2</Colour>
          <Colour>2</Colour>
          <Colour>2</Colour>
        </Holes>
        <Threading>Z</Threading>
        <CurThread>Z</CurThread>
        <CurPos>3</CurPos>
        <CurHoles Count="4">
          <Colour>1</Colour>
          <Colour>2</Colour>
          <Colour>2</Colour>
          <Colour>2</Colour>
        </CurHoles>
      </Card>
      <Card Holes="4" Number="2">
        <Holes Count="4">
          <Colour>2</Colour>
          <Colour>1</Colour>
          <Colour>2</Colour>
          <Colour>2</Colour>
        </Holes>
        <Threading>S</Threading>
        <CurThread>S</CurThread>
        <CurPos>0</CurPos>
        <CurHoles Count="4">
          <Colour>2</Colour>
          <Colour>1</Colour>
          <Colour>2</Colour>
          <Colour>2</Colour>
        </CurHoles>
      </Card>
    </Cards>
    <Packs Count="1">
      <Pack Name="Left">
        <Comment><![CDATA[Left card]]></Comment>
        <Size>1</Size>
        <Cards>1</Cards>
      </Pack>
    </Packs>
    <Picks Count="2">
      <Pick Index="0">
        <Actions Count="2">
          <Action Type="Turn" Target="Card" TargetID="1" Dir="F" Dist="2" />
          <Action Type="Turn" Target="Card" TargetID="2" Dir="B" Dist="1" />
        </Actions>
      </Pick>
      <Pick Index="1">
        <Actions Count="3">
          <Action Type="Twist" Target="Pack" TargetID="Left" Dir="I" Dist="1" />
          <Action Type="Turn" Target="Pack" TargetID="Left" Dir="F" Dist="1" />
          <Action Type="Turn" Target="Card" TargetID="2" Dir="I" Dist="1" />
        </Actions>
      </Pick>
    </Picks>
    <Palette Name="Basic" Size="2">
      <Colour Index="1">255</Colour>
      <Colour Index="2">16711680</Colour>
    </Palette>
  </Pattern>
</TWData>
''';

void main() {
  group('ColorUtils', () {
    test('converts BGR int to RGB hex and back', () {
      expect(ColorUtils.bgrIntToHex(255), 'ff0000');
      expect(ColorUtils.bgrIntToHex(65280), '00ff00');
      expect(ColorUtils.bgrIntToHex(16711680), '0000ff');

      expect(ColorUtils.hexToBgrInt('ff0000'), 255);
      expect(ColorUtils.hexToBgrInt('#0000ff'), 16711680);
    });
  });

  group('FileConversionService', () {
    test('parses CurPos, Dist, BrokenTwill, Packs, and Twist actions', () {
      final service = FileConversionService.fromGttXml(_sampleXml);

      expect(service.gttData.pattern.cards.cards[0].curPos, 3);

      final firstAction =
          service.gttData.pattern.picks.pickList[0].actions.actions[0];
      expect(firstAction.dist, 2);

      final project = service.project;
      expect(project.patternType, Project.patternTypeBrokenTwill);
      expect(project.palettes['Basic'], ['ff0000', '0000ff']);

      final card1 = project.deck[0];
      expect(card1.picks.length, 3);
      expect(card1.picks.last.twist, TwistDirection.s);
      expect(card1.picks.last.wasFlipped, isTrue);
      expect(card1.picks.last.visibleThread.index, 3);
    });

    test('round-trips Twist and Turn actions back to valid GTT XML', () {
      final fromGtt = FileConversionService.fromGttXml(_sampleXml);
      final jsonStr = fromGtt.toJttJson();

      final fromJtt = FileConversionService.fromJttJson(jsonStr);
      final exportedXml = fromJtt.toGttXml();
      final doc = XmlDocument.parse(exportedXml);

      final pick2 = doc.findAllElements('Pick').elementAt(2);
      final actionTypes = pick2
          .findAllElements('Action')
          .map((a) => a.getAttribute('Type'))
          .toList();

      expect(actionTypes, containsAll(['Twist', 'Turn']));
    });

    test('handles minimal XML without optional Packs or Notes', () {
      const minimalXml = '''
      <TWData>
        <Pattern Type="Threaded">
          <Name>Minimal</Name>
          <Cards Count="1">
            <Card Holes="4" Number="1">
              <Holes Count="4">
                <Colour>1</Colour>
                <Colour>1</Colour>
                <Colour>1</Colour>
                <Colour>1</Colour>
              </Holes>
              <Threading>S</Threading>
            </Card>
          </Cards>
        </Pattern>
      </TWData>
      ''';

      final service = FileConversionService.fromGttXml(minimalXml);
      expect(service.project.name, 'Minimal');
      expect(service.project.deck.length, 1);
      expect(service.project.packs, isEmpty);
    });
  });
}
