import 'package:flutter_test/flutter_test.dart';
import 'package:steam_front/steam.dart';
import 'package:steam_front/vdf.dart';

const _libraryFolders = '''
"libraryfolders"
{
    "0"
    {
        "path"        "C:\\\\Program Files (x86)\\\\Steam"
        "label"       ""
        "contentid"   "123456789"
    }
    "1"
    {
        "path"        "D:\\\\SteamLibrary"
        "label"       "Games"
    }
}
''';

const _appManifest = '''
"AppState"
{
    "appid"             "1245620"
    "name"              "ELDEN RING"
    "StateFlags"        "4"
    "installdir"        "ELDEN RING"
    "LastUpdated"       "1760000000"
    "LastPlayed"        "1761000000"
    "SizeOnDisk"        "68710000000"
    "BytesToDownload"   "68710000000"
    "BytesDownloaded"   "68710000000"
    "InstalledDepots"
    {
        "1245621"
        {
            "manifest"  "111"
            "size"      "100"
        }
    }
}
''';

void main() {
  test('parses nested libraryfolders.vdf', () {
    final root = Vdf.parse(_libraryFolders);
    final folders = root['libraryfolders'] as Map<String, Object?>;
    final first = folders['0'] as Map<String, Object?>;
    expect(first['path'], r'C:\Program Files (x86)\Steam');
    final second = folders['1'] as Map<String, Object?>;
    expect(second['path'], r'D:\SteamLibrary');
  });

  test('parses appmanifest into a SteamGame', () {
    final game = SteamGame.fromManifest(_appManifest, r'D:\SteamLibrary');
    expect(game, isNotNull);
    expect(game!.appId, 1245620);
    expect(game.name, 'ELDEN RING');
    expect(game.isInstalled, isTrue);
    expect(game.isDownloading, isFalse);
    expect(game.sizeOnDisk, 68710000000);
    expect(game.libraryPath, r'D:\SteamLibrary');
  });

  test('downloading game reports progress', () {
    const dl = '''
"AppState"
{
    "appid"  "730"
    "name"   "Counter-Strike 2"
    "StateFlags" "1042"
    "installdir" "Counter-Strike Global Offensive"
    "SizeOnDisk" "1000"
    "BytesToDownload" "1000"
    "BytesDownloaded" "250"
}
''';
    final game = SteamGame.fromManifest(dl, '/steam')!;
    expect(game.isDownloading, isTrue);
    expect(game.downloadProgress, 0.25);
  });
}
