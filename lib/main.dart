import 'package:flutter/material.dart';

import 'steam.dart';

void main() {
  runApp(const SteamFrontApp());
}

class SteamFrontApp extends StatelessWidget {
  const SteamFrontApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steam Front',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2A475E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LibraryScreen(),
    );
  }
}

enum SortMode { name, size, recent }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  SteamLibrary? _library;
  List<SteamGame> _games = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  SortMode _sort = SortMode.name;
  final _pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _detect();
  }

  Future<void> _detect() async {
    final path = await SteamLibrary.detect();
    if (path == null) {
      setState(() {
        _loading = false;
        _error = 'Steam のインストール先が見つかりませんでした。下にパスを入力してください。';
      });
      return;
    }
    _pathController.text = path;
    await _load(path);
  }

  Future<void> _load(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lib = SteamLibrary(path);
      final games = await lib.loadGames();
      setState(() {
        _library = lib;
        _games = games;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '読み込みに失敗しました: $e';
      });
    }
  }

  List<SteamGame> get _visible {
    var list = _games
        .where((g) => g.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    switch (_sort) {
      case SortMode.name:
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortMode.size:
        list.sort((a, b) => b.sizeOnDisk.compareTo(a.sizeOnDisk));
        break;
      case SortMode.recent:
        list.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Steam Front'),
        actions: [
          SegmentedButton<SortMode>(
            segments: const [
              ButtonSegment(value: SortMode.name, label: Text('名前')),
              ButtonSegment(value: SortMode.size, label: Text('サイズ')),
              ButtonSegment(value: SortMode.recent, label: Text('最近更新')),
            ],
            selected: {_sort},
            onSelectionChanged: (s) => setState(() => _sort = s.first),
            showSelectedIcon: false,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '再読み込み',
            onPressed: _library == null
                ? null
                : () => _load(_library!.steamPath),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _pathController,
                    decoration: const InputDecoration(
                      labelText: 'Steam パス',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) _load(v.trim());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: '検索',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final games = _visible;
    if (games.isEmpty) {
      return const Center(child: Text('ゲームが見つかりませんでした'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.62,
      ),
      itemCount: games.length,
      itemBuilder: (context, i) => GameCard(
        game: games[i],
        onPlay:
            _library == null ? null : () => _library!.launchGame(games[i].appId),
        onInstall: _library == null
            ? null
            : () => _library!.installGame(games[i].appId),
      ),
    );
  }
}

/// Shows the capsule art, falling back to the header art, then to a
/// plain tile with the game's name.
class ArtworkImage extends StatefulWidget {
  final SteamGame game;
  const ArtworkImage({super.key, required this.game});

  @override
  State<ArtworkImage> createState() => _ArtworkImageState();
}

class _ArtworkImageState extends State<ArtworkImage> {
  int _stage = 0;

  @override
  Widget build(BuildContext context) {
    final urls = [widget.game.capsuleUrl, widget.game.headerUrl];
    if (_stage >= urls.length) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: Text(
          widget.game.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      );
    }
    return Image.network(
      urls[_stage],
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _stage++);
        });
        return const SizedBox.shrink();
      },
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
    );
  }
}

class GameCard extends StatelessWidget {
  final SteamGame game;
  final VoidCallback? onPlay;
  final VoidCallback? onInstall;
  const GameCard({
    super.key,
    required this.game,
    required this.onPlay,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    final progress = game.downloadProgress;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ArtworkImage(game: game)),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Text(
              game.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: Text(
              formatSize(game.sizeOnDisk),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          if (progress != null)
            LinearProgressIndicator(value: progress)
          else
            const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: game.isInstalled
                ? FilledButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('プレイ'),
                  )
                : OutlinedButton.icon(
                    onPressed: onInstall,
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(progress != null ? 'ダウンロード中' : 'インストール'),
                  ),
          ),
        ],
      ),
    );
  }
}
