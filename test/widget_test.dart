import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:ciphercalc/main.dart';

class TestPaths extends PathProviderPlatform {
  final String path;
  TestPaths(this.path);
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  testWidgets('calculator works without creating a vault', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = (await tester.runAsync(() => Directory.systemTemp.createTemp('ciphercalc-widget-')))!;
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = TestPaths(directory.path);
    addTearDown(() async {
      PathProviderPlatform.instance = previous;
      await directory.delete(recursive: true);
    });
    final capture = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: capture, child: const CipherCalc()));
    await tester.pumpAndSettle();
    for (final key in ['1', '+', '2', '×', '3', '=']) {
      await tester.tap(find.widgetWithText(FilledButton, key));
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const Key('answer'))).data, '7');
    await tester.tap(find.widgetWithText(FilledButton, 'AC'));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('answer'))).data, '0');
    await tester.runAsync(() async {
      final boundary = capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = Directory('../dist');
      await output.create(recursive: true);
      await File('${output.path}/ciphercalc-calculator-${Platform.operatingSystem}.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}
