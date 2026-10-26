import 'dart:io';

import 'vdf.dart';

/// One installed (or downloading) Steam app, from an appmanifest_*.acf file.
class SteamGame {
  final int appId;
  final String name;
  final String installDir;
  final String libraryPath;
  final int stateFlags;
  final int sizeOnDisk;
  final int bytesDownloaded;
  final int bytesToDownload;
  final int lastUpdated; // unix seconds
  final int lastPlayed; // unix seconds, 0 if never

  const SteamGame({
    required this.appId,
    required this.name,
    required this.installDir,
    required this.libraryPath,
    required this.stateFlags,
    required this.sizeOnDisk,
    required this.bytesDownloaded,
    required this.bytesToDownload,
    required this.lastUpdated,
    required this.lastPlayed,
  });

  /// StateFlags bit 2 (value 4) = fully installed.
  bool get isInstalled => (stateFlags & 4) != 0;

  /// Download in progress / partially downloaded.
  bool get isDownloading =>
      bytesToDownload > 0 && bytesDownloaded < bytesToDownload;

  double? get downloadProgress =>
      bytesToDownload > 0 ? bytesDownloaded / bytesToDownload : null;

  String get capsuleUrl =>
      'https://cdn.akamai.steamstatic.com/steam/apps/$appId/library_600x900.jpg';
  String get headerUrl =>
      'https://cdn.akamai.steamstatic.com/steam/apps/$appId/header.jpg';

  static SteamGame? fromManifest(String text, String libraryPath) {
    final root = Vdf.parse(text);
    final app = root['AppState'];
    if (app is! Map<String, Object?>) return null;
    int asInt(Object? v) => int.tryParse(v?.toString() ?? '') ?? 0;
    final appId = asInt(app['appid']);
    if (appId == 0) return null;
    return SteamGame(
      appId: appId,
      name: (app['name'] ?? 'App $appId').toString(),
      installDir: (app['installdir'] ?? '').toString(),
      libraryPath: libraryPath,
      stateFlags: asInt(app['StateFlags']),
      sizeOnDisk: asInt(app['SizeOnDisk']),
      bytesDownloaded: asInt(app['BytesDownloaded']),
      bytesToDownload: asInt(app['BytesToDownload']),
      lastUpdated: asInt(app['LastUpdated']),
      lastPlayed: asInt(app['LastPlayed']),
    );
  }
}

/// Loads the Steam library from a Steam installation directory.
class SteamLibrary {
  final String steamPath;
  SteamLibrary(this.steamPath);

  String get steamExe =>
      Platform.isWindows ? '$steamPath\\steam.exe' : 'steam';

  /// Candidate Steam install locations (Windows defaults).
  static List<String> candidatePaths() {
    if (Platform.isWindows) {
      final pf86 = Platform.environment['ProgramFiles(x86)'] ??
          r'C:\Program Files (x86)';
      final pf = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
      return ['$pf86\\Steam', '$pf\\Steam'];
    }
    final home = Platform.environment['HOME'] ?? '';
    return [
      '$home/.steam/steam',
      '$home/.local/share/Steam',
      '$home/snap/steam/common/.steam/steam',
    ];
  }

  static Future<String?> detect() async {
    for (final p in candidatePaths()) {
      if (await File('$p${Platform.pathSeparator}steamapps'
              '${Platform.pathSeparator}libraryfolders.vdf')
          .exists()) {
        return p;
      }
    }
    return null;
  }

  Future<List<String>> libraryPaths() async {
    final sep = Platform.pathSeparator;
    var vdfFile = File('$steamPath${sep}steamapps${sep}libraryfolders.vdf');
    if (!await vdfFile.exists()) {
      vdfFile = File('$steamPath${sep}config${sep}libraryfolders.vdf');
    }
    final paths = <String>[steamPath];
    if (await vdfFile.exists()) {
      final root = Vdf.parse(await vdfFile.readAsString());
      final folders = root['libraryfolders'];
      if (folders is Map<String, Object?>) {
        for (final entry in folders.values) {
          if (entry is Map<String, Object?>) {
            final p = entry['path']?.toString();
            if (p != null && p.isNotEmpty && !paths.contains(p)) {
              paths.add(p);
            }
          }
        }
      }
    }
    return paths;
  }

  Future<List<SteamGame>> loadGames() async {
    final sep = Platform.pathSeparator;
    final games = <SteamGame>[];
    for (final lib in await libraryPaths()) {
      final dir = Directory('$lib${sep}steamapps');
      if (!await dir.exists()) continue;
      await for (final entity in dir.list()) {
        if (entity is File &&
            entity.path.contains('appmanifest_') &&
            entity.path.endsWith('.acf')) {
          try {
            final game = SteamGame.fromManifest(
                await entity.readAsString(), lib);
            if (game != null) games.add(game);
          } catch (_) {
            // Skip unreadable / malformed manifests.
          }
        }
      }
    }
    games.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return games;
  }

  /// Launches a game through the Steam client core (no web UI involved):
  /// Windows uses steam.exe -applaunch, elsewhere the steam:// URL handler.
  Future<void> launchGame(int appId) async {
    if (Platform.isWindows) {
      await Process.start(steamExe, ['-applaunch', '$appId'],
          mode: ProcessStartMode.detached);
    } else {
      await Process.start('xdg-open', ['steam://rungameid/$appId'],
          mode: ProcessStartMode.detached);
    }
  }

  /// Asks the client core to install a game.
  Future<void> installGame(int appId) async {
    if (Platform.isWindows) {
      await Process.start(steamExe, ['-silent', 'steam://install/$appId'],
          mode: ProcessStartMode.detached);
    } else {
      await Process.start('xdg-open', ['steam://install/$appId'],
          mode: ProcessStartMode.detached);
    }
  }
}

String formatSize(int bytes) {
  if (bytes <= 0) return '-';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}
