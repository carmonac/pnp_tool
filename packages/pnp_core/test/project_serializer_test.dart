import 'package:pnp_core/pnp_core.dart';
import 'package:test/test.dart';

void main() {
  test('grid project round-trips', () {
    const project = PnpProject(
      name: 'My deck',
      mode: ProjectMode.grid,
      pageSize: SizeMm(210, 297),
      cardSize: SizeMm(63.5, 88.9),
      bleedMm: 1.5,
      spacingMm: 3,
      drawCutLines: false,
      jpegQuality: null,
      cards: [
        CardItem(id: 'a', frontRef: '/img/a_front.png', count: 2),
        CardItem(id: 'b', frontRef: '/img/b_front.png', backRef: '/img/b_back.png'),
      ],
      globalBackRef: '/img/global_back.png',
    );

    const serializer = ProjectSerializer();
    final decoded = serializer.decode(serializer.encode(project));

    expect(decoded.name, 'My deck');
    expect(decoded.mode, ProjectMode.grid);
    expect(decoded.pageSize, const SizeMm(210, 297));
    expect(decoded.cardSize, const SizeMm(63.5, 88.9));
    expect(decoded.bleedMm, 1.5);
    expect(decoded.spacingMm, 3);
    expect(decoded.drawCutLines, isFalse);
    expect(decoded.jpegQuality, isNull);
    expect(decoded.cards.length, 2);
    expect(decoded.cards[0].count, 2);
    expect(decoded.cards[1].backRef, '/img/b_back.png');
    expect(decoded.globalBackRef, '/img/global_back.png');
  });

  test('freeform project round-trips', () {
    const project = PnpProject(
      name: 'Board bits',
      mode: ProjectMode.freeform,
      pageSize: SizeMm(297, 420),
      pages: [
        FreePage(items: [
          FreeItem(
            id: 'token',
            frontRef: '/img/token.png',
            backRef: '/img/token_back.png',
            position: PointMm(12.5, 30),
            size: SizeMm(40, 40),
          ),
        ]),
        FreePage(),
      ],
    );

    const serializer = ProjectSerializer();
    final decoded = serializer.decode(serializer.encode(project));

    expect(decoded.mode, ProjectMode.freeform);
    expect(decoded.pages.length, 2);
    final item = decoded.pages[0].items.single;
    expect(item.position, const PointMm(12.5, 30));
    expect(item.size, const SizeMm(40, 40));
    expect(item.backRef, '/img/token_back.png');
    expect(decoded.pages[1].items, isEmpty);
  });

  test('custom sizes serialize with explicit dimensions', () {
    const project = PnpProject(
      name: 'odd',
      mode: ProjectMode.grid,
      pageSize: SizeMm(200, 200),
      cardSize: SizeMm(30, 45),
    );
    const serializer = ProjectSerializer();
    final json = serializer.toJson(project);
    expect((json['page'] as Map)['preset'], 'custom');
    expect((json['page'] as Map)['widthMm'], 200);
    final decoded = serializer.decode(serializer.encode(project));
    expect(decoded.pageSize, const SizeMm(200, 200));
    expect(decoded.cardSize, const SizeMm(30, 45));
  });

  test('paths relativize against baseDir and resolve back', () {
    const baseDir = '/home/user/deck';
    const serializer = ProjectSerializer(baseDir: baseDir);
    const project = PnpProject(
      name: 'deck',
      mode: ProjectMode.grid,
      pageSize: SizeMm(210, 297),
      cards: [
        CardItem(id: 'a', frontRef: '$baseDir/images/a_front.png'),
      ],
    );

    final json = serializer.toJson(project);
    expect((json['cards'] as List).first['front'], 'images/a_front.png');

    final decoded = serializer.fromJson(json);
    expect(decoded.cards.single.frontRef, '$baseDir/images/a_front.png');
  });

  test('unknown keys are ignored and defaults fill gaps', () {
    const serializer = ProjectSerializer();
    final decoded = serializer.decode(
        '{"schemaVersion":1,"mode":"grid","someFutureKey":true}');
    expect(decoded.pageSize, PagePreset.a4.size);
    expect(decoded.cardSize, CardPreset.poker.size);
    expect(decoded.drawCutLines, isTrue);
  });

  test('newer schema version is rejected', () {
    const serializer = ProjectSerializer();
    expect(() => serializer.decode('{"schemaVersion":99,"mode":"grid"}'),
        throwsFormatException);
  });
}
