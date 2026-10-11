import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'calculator.dart';
import 'vault.dart';

void main() => runApp(const CipherCalc());

class CipherCalc extends StatelessWidget {
  const CipherCalc({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CipherCalc', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff65e4d5), brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xff101725), useMaterial3: true),
    home: const CalculatorScreen(),
  );
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> with WidgetsBindingObserver {
  Vault? vault;
  bool configured = false, busy = false, pickerOpen = false, covered = false;
  String expression = '', answer = '0';
  int generation = 0, failures = 0;
  DateTime nextTry = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? pickerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }
  Future<void> initialize() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final store = Vault(Directory('${directory.path}/ciphercalc'));
      final exists = await store.exists();
      if (mounted) setState(() { vault = store; configured = exists; });
    } catch (_) { message('Storage is unavailable. Calculator still works.'); }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pickerTimer?.cancel(); vault?.lock(); super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) { setState(() => covered = false); return; }
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (!pickerOpen) lock();
      setState(() => covered = true);
    }
  }
  void lock() {
    generation++; vault?.lock();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() { expression = ''; answer = '0'; });
  }
  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
  void startPicker() {
    pickerOpen = true;
    pickerTimer = Timer(const Duration(seconds: 30), () { pickerOpen = false; lock(); });
  }
  void finishPicker() { pickerTimer?.cancel(); pickerOpen = false; }

  void input(String key) {
    if (busy) return;
    setState(() {
      if (key == 'AC') { expression = ''; answer = '0'; }
      else if (key == '⌫') { if (expression.isNotEmpty) expression = expression.substring(0, expression.length - 1); }
      else if (expression.length < 80) { expression += key; }
    });
  }
  Future<void> equals() async {
    if (busy) return;
    final original = expression;
    try {
      final value = calculate(original);
      setState(() => answer = value == value.truncateToDouble() ? value.toStringAsFixed(0) : value.toStringAsPrecision(12));
    } catch (_) { setState(() => answer = 'Invalid expression'); }
    if (!configured || vault == null || original.length < 5 || DateTime.now().isBefore(nextTry)) return;
    final token = generation;
    setState(() => busy = true);
    try {
      final success = await vault!.unlock(original);
      if (!mounted || token != generation) return;
      if (success) { failures = 0; setState(() => expression = ''); }
      else { failures++; nextTry = DateTime.now().add(Duration(seconds: failures < 5 ? 1 : 30)); }
    } catch (_) {
      if (mounted && token == generation) message('Vault could not be read. Existing data was not replaced.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> setup() async {
    if (vault == null || busy) return;
    if (configured) { help(); return; }
    final first = TextEditingController(), second = TextEditingController();
    final password = await showDialog<String>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Create your private vault'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Choose an exact expression, then enter it on the calculator and press = to unlock. Example: 12*16. Use a much longer private expression for real files. There is no password recovery.'),
        const SizedBox(height: 16),
        TextField(controller: first, obscureText: true, autocorrect: false, enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Secret expression (5–80 characters)')),
        TextField(controller: second, obscureText: true, autocorrect: false, enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Repeat expression')),
        const SizedBox(height: 12),
        const Text('Imported files are copied. Their originals remain outside the vault. Uninstalling can erase your vault.'),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          try {
            Vault.validatePassword(first.text);
            calculate(first.text);
            if (first.text != second.text) throw const FormatException('Expressions do not match');
            Navigator.pop(dialog, first.text);
          } catch (_) { message('Enter matching, valid expressions of 5–80 characters.'); }
        }, child: const Text('Create'))],
    ));
    first.dispose(); second.dispose();
    if (password == null || !mounted) return;
    final token = generation;
    setState(() => busy = true);
    try {
      await vault!.create(password);
      if (mounted && token == generation) setState(() => configured = true);
    } catch (_) { message('Vault creation failed or session was locked.'); }
    finally {
      final exists = await vault!.exists();
      if (mounted) setState(() { busy = false; configured = exists; });
    }
  }

  void help() {
    showDialog<void>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Calculator + private vault'),
      content: const SingleChildScrollView(child: Text('Use + − × ÷ and parentheses.\n\nTo unlock: enter your exact saved expression and press =. Its numerical result is not the password. Clear the display first.\n\nFiles and their names are encrypted locally. No account, ads, analytics or cloud upload. Capacity: 20 MiB / 200 files.\n\nShort expressions are easy to guess. Encryption is not an independent security audit. Original files, OS picker caches, screenshots and exported copies are outside the vault. There is no recovery if you forget the expression.\n\nThe app locks when backgrounded. File pickers have a 30-second grace period; the app view is covered while inactive.\n\nThis v0.1 preview is for test files. Export important files before uninstalling or changing installations.')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Got it'))],
    ));
  }

  Future<void> importFile() async {
    if (busy || vault?.unlocked != true) return;
    final token = generation;
    setState(() => busy = true);
    startPicker();
    try {
      final result = await FilePicker.platform.pickFiles(withReadStream: true, withData: false);
      finishPicker();
      if (result == null || !mounted || token != generation || !vault!.unlocked) return;
      final file = result.files.single;
      if (file.size > maxVaultBytes) throw const FormatException('File exceeds 20 MiB');
      final stream = file.readStream ?? (file.path == null ? null : File(file.path!).openRead());
      if (stream == null) throw const FormatException('Could not read selected file');
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        if (token != generation) throw StateError('Locked');
        if (bytes.length + chunk.length > maxVaultBytes) throw const FormatException('File too large');
        bytes.add(chunk);
      }
      await vault!.add(file.name, bytes.takeBytes());
      if (mounted && token == generation) message('Encrypted copy added. The original has not been deleted.');
    } catch (_) { message('Import failed: check the 20 MiB total limit and unlocked session.'); }
    finally { finishPicker(); if (mounted) setState(() => busy = false); }
  }

  Future<void> exportFile(VaultFile file) async {
    if (busy || vault?.unlocked != true) return;
    final token = generation;
    final confirm = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Export an unencrypted copy?'),
      content: const Text('The destination copy is outside vault protection. Other apps or cloud storage may access it.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Export'))],
    ));
    if (confirm != true || !mounted || token != generation) return;
    setState(() => busy = true); startPicker();
    try {
      final saved = await FilePicker.platform.saveFile(fileName: file.name.replaceAll(RegExp(r'[/\\]'), '_'), bytes: file.bytes);
      if (saved != null) message('Unencrypted copy exported.');
    } catch (_) { message('Export failed.'); }
    finally { finishPicker(); if (mounted) setState(() => busy = false); }
  }

  Future<void> deleteFile(VaultFile file) async {
    if (busy) return;
    final token = generation;
    final confirm = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Delete vault copy?'), content: Text(file.name),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete'))],
    ));
    if (confirm != true || !mounted || token != generation) return;
    setState(() => busy = true);
    try { await vault!.remove(file.id); } catch (_) { message('Delete failed.'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  void preview(VaultFile file) {
    if (busy || vault?.unlocked != true) return;
    final lower = file.name.toLowerCase();
    Widget content;
    if (['.jpg','.jpeg','.png','.webp','.gif'].any(lower.endsWith)) {
      content = Image.memory(file.bytes, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Text('Image preview unavailable. Export to open it.'));
    } else if (['.txt','.md','.json','.csv'].any(lower.endsWith) && file.bytes.length <= 200000) {
      content = SingleChildScrollView(child: SelectableText(utf8.decode(file.bytes, allowMalformed: true)));
    } else { content = const Text('This file is stored encrypted. Use Export to open a copy in another app.'); }
    showDialog<void>(context: context, builder: (dialog) => AlertDialog(title: Text(file.name),
      content: SizedBox(width: 400, height: 300, child: content),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Close'))]));
  }

  @override
  Widget build(BuildContext context) {
    final open = !covered && vault?.unlocked == true;
    return Scaffold(
      appBar: AppBar(title: Text(open ? 'Private vault' : 'CipherCalc'),
        actions: [if (open) IconButton(tooltip: 'Lock vault', onPressed: lock, icon: const Icon(Icons.lock_outline)),
          IconButton(tooltip: configured ? 'About & help' : 'Set up vault', onPressed: busy ? null : setup, icon: const Icon(Icons.tune))]),
      body: SafeArea(child: covered ? const Center(child: Icon(Icons.calculate_outlined, size: 64)) :
        open ? vaultView() : calculatorView()),
    );
  }

  Widget vaultView() {
    final files = vault!.files;
    final bytes = files.fold<int>(0, (n, f) => n + f.bytes.length);
    return Column(children: [
      Padding(padding: const EdgeInsets.all(20), child: Row(children: [
        const Icon(Icons.shield_outlined, color: Color(0xff65e4d5)), const SizedBox(width: 12),
        Expanded(child: Text('LOCAL · ENCRYPTED\n${files.length} files · ${(bytes/1048576).toStringAsFixed(1)} / 20 MiB')),
        FilledButton.icon(onPressed: busy ? null : importFile, icon: const Icon(Icons.add), label: const Text('Import')),
      ])),
      if (busy) const LinearProgressIndicator(),
      Expanded(child: files.isEmpty ? const Center(child: Text('Your vault is empty.\nImport a test file to begin.', textAlign: TextAlign.center)) :
        ListView.builder(itemCount: files.length, itemBuilder: (context, index) {
          final file = files[index];
          return ListTile(leading: const Icon(Icons.insert_drive_file_outlined), title: Text(file.name),
            subtitle: Text('${file.bytes.length} bytes'), onTap: () => preview(file),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'Export copy', onPressed: busy ? null : () => exportFile(file), icon: const Icon(Icons.save_alt)),
              IconButton(tooltip: 'Delete vault copy', onPressed: busy ? null : () => deleteFile(file), icon: const Icon(Icons.delete_outline)),
            ]));
        })),
      const Padding(padding: EdgeInsets.all(16), child: Text('Original files remain outside this vault.', style: TextStyle(color: Colors.white54))),
    ]);
  }

  Widget calculatorView() => LayoutBuilder(builder: (context, limits) => SingleChildScrollView(
    child: ConstrainedBox(constraints: BoxConstraints(minHeight: limits.maxHeight), child: Padding(
      padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 24),
        const Text('EVERYDAY NUMBERS', style: TextStyle(color: Color(0xff65e4d5), letterSpacing: 3, fontSize: 11)),
        const SizedBox(height: 32),
        Text(expression.isEmpty ? '0' : expression.replaceAll('*','×').replaceAll('/','÷'),
          key: const Key('expression'), textAlign: TextAlign.right, style: const TextStyle(fontSize: 27, color: Colors.white70)),
        const SizedBox(height: 12),
        Text(answer, key: const Key('answer'), textAlign: TextAlign.right, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w600)),
        const SizedBox(height: 28),
        if (busy) const LinearProgressIndicator(),
        for (final row in [['AC','(',')','/'],['7','8','9','*'],['4','5','6','-'],['1','2','3','+'],['⌫','0','.','=']])
          Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
            for (final key in row) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton(onPressed: busy ? null : () { if (key == '=') { equals(); } else { input(key); } },
                style: FilledButton.styleFrom(backgroundColor: key == '=' ? const Color(0xff65e4d5) : const Color(0xff202c3e),
                  foregroundColor: key == '=' ? const Color(0xff101725) : Colors.white,
                  minimumSize: const Size(64,64), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: Text(key == '*' ? '×' : key == '/' ? '÷' : key, style: const TextStyle(fontSize: 24))))),
          ])),
        const SizedBox(height: 12),
        const Text('OFFLINE BY DESIGN', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white38)),
      ])),
    ),
  ));
}
