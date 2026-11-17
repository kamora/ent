// Host side of integration_test/bench_test.dart: waits for the result, writes it to build/bench.json, and for each
// reported window reads the app's CPU samples from the VM service and writes the functions with the largest
// exclusive and inclusive share to build/bench_profile.json.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';
import 'package:vm_service/vm_service.dart' hide Response;

Future<void> main() async {
  final driver = await FlutterDriver.connect() as VMServiceFlutterDriver;
  final response = Response.fromJson(await driver.requestData(null, timeout: const Duration(minutes: 15)));
  final data = response.data!;
  final profiles = <Map<String, Object>>[];

  for (final window in (data['windows']! as List).cast<Map<String, dynamic>>()) {
    final start = window['start'] as int;
    final samples = await driver.serviceClient.getCpuSamples(
      driver.appIsolate.id!,
      start,
      (window['end'] as int) - start,
    );
    final functions = samples.functions!;
    final self = <String, int>{};
    final total = <String, int>{};

    String name(int i) {
      final function = functions[i].function;

      if (function is FuncRef) {
        return '${function.owner is ClassRef ? '${(function.owner as ClassRef).name}.' : ''}${function.name} '
            '(${function.location?.script?.uri?.split('/').last})';
      }

      return (function as dynamic).name as String? ?? '?';
    }

    for (final sample in samples.samples!) {
      final stack = sample.stack!;

      if (stack.isEmpty) {
        continue;
      }

      self.update(name(stack.first), (v) => v + 1, ifAbsent: () => 1);

      for (final i in stack.map(name).toSet()) {
        total.update(i, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    List<String> top(Map<String, int> counts) {
      final sorted = counts.entries.toList()..sort((a, b) => b.value - a.value);
      return [
        for (final e in sorted.take(40)) '${(100 * e.value / samples.samples!.length).toStringAsFixed(1)}% ${e.key}',
      ];
    }

    profiles.add({
      'case': window['case'],
      'n': window['n'],
      'samples': samples.samples!.length,
      'period': samples.samplePeriod!,
      'self': top(self),
      'total': top(total),
    });
  }

  File('build/bench.json').writeAsStringSync(const JsonEncoder.withIndent('\t').convert(data));
  File('build/bench_profile.json').writeAsStringSync(const JsonEncoder.withIndent('\t').convert(profiles));
  await driver.close();
  exit(response.allTestsPassed ? 0 : 1);
}
