import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pnp_core/pnp_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pnp_discovery_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  void touch(String name) {
    File(p.join(tempDir.path, name)).writeAsBytesSync([0]);
  }

  test('pairs fronts with their backs', () async {
    touch('dragon_front.png');
    touch('dragon_back.png');
    touch('goblin_front.jpg');
    touch('global_back.png');

    final result = await discoverCards(tempDir.path);
    expect(result.cards.map((c) => c.id), ['dragon', 'goblin']);
    expect(result.cards[0].backRef, endsWith('dragon_back.png'));
    expect(result.cards[1].backRef, isNull);
    expect(result.globalBackRef, endsWith('global_back.png'));
  });

  test('sorts naturally', () async {
    touch('card10_front.png');
    touch('card2_front.png');
    touch('global_back.png');

    final result = await discoverCards(tempDir.path);
    expect(result.cards.map((c) => c.id), ['card2', 'card10']);
  });

  test('back without front throws', () async {
    touch('ghost_back.png');
    expect(() => discoverCards(tempDir.path), throwsFormatException);
  });

  test('front without back and no global back throws when required', () async {
    touch('lonely_front.png');
    expect(() => discoverCards(tempDir.path), throwsFormatException);
    final result = await discoverCards(tempDir.path, requireBacks: false);
    expect(result.cards.single.backRef, isNull);
  });

  test('keeps only the trailing _front suffix in the key', () async {
    touch('my_front_card_front.png');
    touch('my_front_card_back.png');

    final result = await discoverCards(tempDir.path);
    expect(result.cards.single.id, 'my_front_card');
  });

  test('ignores non-image files', () async {
    touch('notes_front.txt');
    touch('real_front.png');
    touch('global_back.png');

    final result = await discoverCards(tempDir.path);
    expect(result.cards.map((c) => c.id), ['real']);
  });

  test('missing directory throws', () {
    expect(() => discoverCards(p.join(tempDir.path, 'nope')),
        throwsFormatException);
  });
}
