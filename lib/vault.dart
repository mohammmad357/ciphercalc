import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

const maxVaultBytes = 20 * 1024 * 1024;
const kdfIterations = 210000;

List<int> randomBytes(int size) {
  final random = Random.secure();
  return List<int>.generate(size, (_) => random.nextInt(256));
}

Future<List<int>> derive(String password, List<int> salt) => Isolate.run(() async {
  final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: kdfIterations, bits: 256);
  final key = await kdf.deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  return key.extractBytes();
});

class VaultFile {
  final String id;
  final String name;
  final Uint8List bytes;
  VaultFile(this.id, this.name, this.bytes);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'data': base64Encode(bytes)};
  factory VaultFile.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id) || name.length > 255) {
      throw const FormatException('Invalid file metadata');
    }
    return VaultFile(id, name, base64Decode(json['data'] as String));
  }
}

class Vault {
  final Directory directory;
  final _cipher = AesGcm.with256bits();
  List<int>? _key;
  List<int>? _salt;
  List<VaultFile> _files = [];
  int _epoch = 0;
  bool _writing = false;
  Vault(this.directory);
  File get _disk => File('${directory.path}/vault.ccv');
  bool get unlocked => _key != null;
  List<VaultFile> get files => unlocked ? List.unmodifiable(_files) : const [];
  Future<bool> exists() => _disk.exists();

  static void validatePassword(String password) {
    if (password.length < 5 || password.length > 80 ||
        !RegExp(r'^[0-9+*/().-]+$').hasMatch(password)) {
      throw const FormatException('Use 5–80 characters: digits and + - * / ( ) .');
    }
  }

  void lock() {
    _epoch++;
    // Best effort only: managed runtimes cannot guarantee erasure of all copies.
    _key?.fillRange(0, _key!.length, 0);
    _key = null; _salt = null; _files = [];
  }

  Future<void> create(String password) async {
    final epoch = _epoch;
    validatePassword(password);
    if (await exists()) throw StateError('Vault already exists');
    final salt = randomBytes(16);
    final key = await derive(password, salt);
    if (_epoch != epoch) throw StateError('Session locked');
    _key = key; _salt = salt;
    try { await _persist([]); } catch (_) { lock(); rethrow; }
  }

  Future<bool> unlock(String password) async {
    if (_writing) throw StateError('Write in progress');
    final epoch = _epoch;
    if (password.length > 120) return false;
    if (await _disk.length() > 40 * 1024 * 1024) throw const FormatException('Vault too large');
    final envelope = jsonDecode(await _disk.readAsString()) as Map<String, dynamic>;
    if (envelope['version'] != 1 || envelope['iterations'] != kdfIterations) {
      throw const FormatException('Unsupported vault format');
    }
    final salt = base64Decode(envelope['salt'] as String);
    if (salt.length != 16) throw const FormatException('Invalid salt');
    final box = SecretBox.fromConcatenation(base64Decode(envelope['box'] as String), nonceLength: 12, macLength: 16);
    final key = await derive(password, salt);
    List<int> clear;
    try {
      clear = await _cipher.decrypt(box, secretKey: SecretKey(key), aad: utf8.encode('CipherCalc/v1'));
    } on SecretBoxAuthenticationError { return false; }
    final decoded = jsonDecode(utf8.decode(clear)) as List<dynamic>;
    final files = decoded.map((e) => VaultFile.fromJson(e as Map<String, dynamic>)).toList();
    if (files.fold<int>(0, (n, f) => n + f.bytes.length) > maxVaultBytes ||
        files.map((f) => f.id).toSet().length != files.length) {
      throw const FormatException('Invalid vault contents');
    }
    if (_epoch != epoch) { key.fillRange(0, key.length, 0); return false; }
    _key = key; _salt = salt; _files = files;
    return true;
  }

  Future<void> add(String name, Uint8List bytes) async {
    if (!unlocked) throw StateError('Locked');
    if (name.isEmpty || name.length > 255 || _files.length >= 200 ||
        _files.fold<int>(bytes.length, (n, f) => n + f.bytes.length) > maxVaultBytes) {
      throw const FormatException('Limit: 200 files, 20 MiB total, names up to 255 characters');
    }
    final id = randomBytes(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _persist([..._files, VaultFile(id, name, Uint8List.fromList(bytes))]);
  }

  Future<void> remove(String id) => _persist(_files.where((f) => f.id != id).toList());

  Future<void> _persist(List<VaultFile> files) async {
    if (!unlocked || _writing) throw StateError('Locked or busy');
    _writing = true;
    final epoch = _epoch;
    final temporary = File('${directory.path}/vault.tmp');
    try {
      final box = await _cipher.encrypt(utf8.encode(jsonEncode(files.map((f) => f.toJson()).toList())),
          secretKey: SecretKey(List<int>.from(_key!)), aad: utf8.encode('CipherCalc/v1'));
      final envelope = jsonEncode({'version': 1, 'iterations': kdfIterations,
        'salt': base64Encode(_salt!), 'box': base64Encode(box.concatenation())});
      await directory.create(recursive: true);
      await temporary.writeAsString(envelope, flush: true);
      if (_epoch != epoch) throw StateError('Session locked');
      await temporary.rename(_disk.path);
      if (_epoch == epoch) _files = files;
    } finally {
      _writing = false;
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
