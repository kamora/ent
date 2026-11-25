// Finds and runs impellerc, Impeller's offline shader compiler, which the Flutter SDK ships with its engine artifacts.

import 'dart:convert';
import 'dart:io';

// impellerc's folder in the engine artifacts on each host: every Mac uses darwin-x64, arm64 ones included.
const _hosts = ['darwin-x64', 'linux-x64', 'linux-arm64', 'windows-x64', 'windows-arm64'];

/// The impellerc of the Flutter SDK this process runs from: the `IMPELLERC` environment variable, which Flutter's
/// tools set for build hooks (a locally built engine's included), or else the SDK's engine artifacts, found from the
/// Dart executable (`<flutter>/bin/cache/dart-sdk/bin/dart`, or `flutter_tester` in the artifacts).
File findImpellerc() {
  final variable = Platform.environment['IMPELLERC'];

  if (variable != null && variable.isNotEmpty) {
    if (!File(variable).existsSync()) {
      throw StateError('ent_impeller: IMPELLERC is $variable, which is not a file.');
    }

    return File(variable);
  }

  final segments = Uri.file(Platform.resolvedExecutable).pathSegments;
  final index = segments.lastIndexWhere((segment) => segment == 'dart-sdk' || segment == 'artifacts');

  if (index < 0) {
    throw StateError('ent_impeller: no Flutter SDK around ${Platform.resolvedExecutable}; set IMPELLERC.');
  }

  final artifacts = Uri.file(Platform.resolvedExecutable)
      .replace(pathSegments: [...segments.sublist(0, index), 'artifacts', 'engine', '']);
  final tried = <String>[];

  for (final host in _hosts) {
    final file = File.fromUri(artifacts.resolve('$host/impellerc${Platform.isWindows ? '.exe' : ''}'));

    if (file.existsSync()) {
      return file;
    }

    tried.add(file.path);
  }

  throw StateError('ent_impeller: impellerc is not in the Flutter SDK; tried ${tried.join(', ')}.');
}

/// Runs [impellerc] to compile the shaders of [manifest] (name to `{type, file}`, files by absolute path) into the
/// shader bundle [output], with every backend, OpenGL ES as GLSL ES 3.00. Returns the files it read.
List<File> compileBundle(File impellerc, Map<String, Object?> manifest, File output, {required List<Uri> includes}) {
  final depfile = File('${output.path}.d');

  if (depfile.existsSync()) {
    depfile.deleteSync();
  }

  final result = Process.runSync(impellerc.path, [
    '--sl=${output.path}',
    '--shader-bundle=${jsonEncode(manifest)}',
    '--depfile=${depfile.path}',
    '--gles-language-version=300',
    for (final include in includes) '--include=${include.toFilePath()}',

    // Impeller's own shader headers, beside the compiler.
    '--include=${impellerc.parent.uri.resolve('shader_lib').toFilePath()}',
  ]);

  if (result.exitCode != 0) {
    throw StateError('ent_impeller: impellerc failed:\n${result.stderr}\n${result.stdout}');
  }

  final read = readDepfile(depfile.readAsStringSync());
  depfile.deleteSync();
  return read;
}

/// The files a Ninja-style depfile (`<target>: <file> <file> ...`) lists. impellerc does not escape spaces, so where
/// a word is no file, the words after it are joined to it, one by one, until they name one.
List<File> readDepfile(String text, {bool Function(String path)? exists}) {
  exists ??= (path) => File(path).existsSync();
  final separator = RegExp(r':(\s|$)').firstMatch(text);

  if (separator == null) {
    return const [];
  }

  final words = text.substring(separator.end).trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  final files = <File>[];

  for (var i = 0; i < words.length; i++) {
    var path = words[i];

    if (!exists(path)) {
      var joined = path;

      for (var j = i + 1; j < words.length; j++) {
        joined = '$joined ${words[j]}';

        if (exists(joined)) {
          path = joined;
          i = j;
          break;
        }
      }
    }

    files.add(File(path));
  }

  return files;
}
