import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ciphercalc/vault.dart';

void main() {
  late Directory directory;
  late Vault vault;
  setUp(() async { directory = await Directory.systemTemp.createTemp('ciphercalc-test-'); vault = Vault(directory); });
  tearDown(() async { vault.lock(); await directory.delete(recursive: true); });

  test('encrypted round trip, exact expression, restart and deletion', () async {
    await vault.create('12*16');
    await vault.add('private-note.txt', Uint8List.fromList(utf8.encode('hidden content 7319')));
    final raw = await File('${directory.path}/vault.ccv').readAsString();
    expect(raw, isNot(contains('private-note.txt')));
    expect(raw, isNot(contains('hidden content 7319')));
    expect(raw, isNot(contains('12*16')));
    vault.lock();
    expect(vault.files, isEmpty);
    expect(await vault.unlock('192'), isFalse);
    expect(await vault.unlock('16*12'), isFalse);
    expect(await vault.unlock('12*16'), isTrue);
    expect(utf8.decode(vault.files.single.bytes), 'hidden content 7319');
    final reopened = Vault(directory);
    expect(await reopened.unlock('12*16'), isTrue);
    await reopened.remove(reopened.files.single.id);
    reopened.lock();
    expect(await reopened.unlock('12*16'), isTrue);
    expect(reopened.files, isEmpty);
    reopened.lock();
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('tampering fails authentication without replacing ciphertext', () async {
    await vault.create('12345*67890');
    vault.lock();
    final file = File('${directory.path}/vault.ccv');
    final envelope = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final bytes = base64Decode(envelope['box'] as String);
    bytes[15] ^= 1;
    envelope['box'] = base64Encode(bytes);
    await file.writeAsString(jsonEncode(envelope));
    final before = await file.readAsString();
    expect(await vault.unlock('12345*67890'), isFalse);
    expect(vault.unlocked, isFalse);
    expect(await file.readAsString(), before);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('lock invalidates an in-flight unlock', () async {
    await vault.create('12345+98765');
    vault.lock();
    final pending = vault.unlock('12345+98765');
    vault.lock();
    expect(await pending, isFalse);
    expect(vault.unlocked, isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('locked writes and malformed passwords fail', () async {
    expect(() => Vault.validatePassword('1234'), throwsFormatException);
    expect(() => Vault.validatePassword('abcde'), throwsFormatException);
    await expectLater(vault.add('test', Uint8List(1)), throwsStateError);
    await vault.create('12345+67890');
    await expectLater(vault.add('too-large', Uint8List(maxVaultBytes + 1)), throwsFormatException);
    await expectLater(vault.create('12345+67890'), throwsStateError);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
