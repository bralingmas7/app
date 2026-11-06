import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const SentGalleryApp());

class SentGalleryApp extends StatelessWidget {
  const SentGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp Sent Gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF168C61),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF101815),
      ),
      home: const GalleryHome(),
    );
  }
}

class GalleryHome extends StatefulWidget {
  const GalleryHome({super.key});

  @override
  State<GalleryHome> createState() => _GalleryHomeState();
}

class _GalleryHomeState extends State<GalleryHome> {
  static const _channel = MethodChannel('whatsapp_sent_gallery/saf');
  final Map<String, List<SentImage>> _images = {
    'regular': [],
    'business': [],
  };
  final Map<String, bool> _hasFolder = {
    'regular': false,
    'business': false,
  };
  bool _loading = false;
  String _active = 'regular';
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  String get _activeLabel =>
      _active == 'regular' ? 'WhatsApp' : 'WhatsApp Business';

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      for (final key in ['regular', 'business']) {
        final result = await _channel.invokeMethod<List<dynamic>>(
          'listImages',
          {'account': key},
        );
        _images[key] = (result ?? [])
            .map((item) => SentImage.fromMap(Map<dynamic, dynamic>.from(item)))
            .toList();
        _hasFolder[key] = true;
      }
    } on PlatformException catch (e) {
      if (e.code == 'NO_FOLDER') {
        // A missing folder is expected on first launch.
      } else {
        _error = e.message ?? e.code;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseFolder(String account) async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      await _channel.invokeMethod<String>(
        'chooseFolder',
        {'account': account},
      );
      final result = await _channel.invokeMethod<List<dynamic>>(
        'listImages',
        {'account': account},
      );
      _images[account] = (result ?? [])
          .map((item) => SentImage.fromMap(Map<dynamic, dynamic>.from(item)))
          .toList();
      _hasFolder[account] = true;
      _active = account;
    } on PlatformException catch (e) {
      if (e.code != 'CANCELLED') _error = e.message ?? e.code;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshActive() async {
    setState(() => _loading = true);
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'listImages',
        {'account': _active},
      );
      _images[_active] = (result ?? [])
          .map((item) => SentImage.fromMap(Map<dynamic, dynamic>.from(item)))
          .toList();
      _error = null;
    } on PlatformException catch (e) {
      _error = e.message ?? e.code;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _images[_active] ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sent Gallery'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refreshActive,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'regular',
                  label: Text('WhatsApp'),
                  icon: Icon(Icons.chat),
                ),
                ButtonSegment(
                  value: 'business',
                  label: Text('Business'),
                  icon: Icon(Icons.business),
                ),
              ],
              selected: {_active},
              onSelectionChanged: (value) {
                setState(() => _active = value.first);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Folder $_activeLabel',
                              style: Theme.of(context).textTheme.titleSmall),
                          Text(
                            '${items.length} foto ditemukan',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed:
                          _loading ? null : () => _chooseFolder(_active),
                      child: const Text('Pilih Sent'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: items.isEmpty
                ? _EmptyState(
                    hasFolder: _hasFolder[_active] ?? false,
                    onChoose: () => _chooseFolder(_active),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(3),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PhotoPage(
                              image: item,
                              title: item.name,
                            ),
                          ),
                        ),
                        child: Hero(
                          tag: item.uri,
                          child: SentThumbnail(image: item),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Text(
              'Pilih folder Sent untuk WhatsApp dan WhatsApp Business secara terpisah.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFolder, required this.onChoose});
  final bool hasFolder;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_library_outlined, size: 64),
              const SizedBox(height: 14),
              Text(
                hasFolder ? 'Belum ada foto terkirim' : 'Folder Sent belum dipilih',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tekan “Pilih Sent”, lalu pilih folder WhatsApp Images/Sent '
                'di pemilih folder Android.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onChoose,
                icon: const Icon(Icons.folder_open),
                label: const Text('Pilih folder Sent'),
              ),
            ],
          ),
        ),
      );
}

class SentImage {
  const SentImage({
    required this.uri,
    required this.name,
    required this.modified,
  });

  final String uri;
  final String name;
  final int modified;

  factory SentImage.fromMap(Map<dynamic, dynamic> map) => SentImage(
        uri: map['uri'] as String,
        name: map['name'] as String? ?? 'image',
        modified: map['modified'] as int? ?? 0,
      );
}

class SentThumbnail extends StatelessWidget {
  const SentThumbnail({super.key, required this.image});
  final SentImage image;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: SafImageCache.load(image.uri),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          }
          return Container(
            color: const Color(0xFF26332D),
            child: const Center(child: Icon(Icons.image_outlined)),
          );
        },
      );
}

class SafImageCache {
  static const _channel = MethodChannel('whatsapp_sent_gallery/saf');
  static final Map<String, Future<Uint8List?>> _cache = {};

  static Future<Uint8List?> load(String uri) {
    return _cache.putIfAbsent(uri, () async {
      try {
        return await _channel.invokeMethod<Uint8List>(
          'readImage',
          {'uri': uri},
        );
      } on PlatformException {
        return null;
      }
    });
  }
}

class PhotoPage extends StatelessWidget {
  const PhotoPage({super.key, required this.image, required this.title});
  final SentImage image;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: Center(
          child: FutureBuilder<Uint8List?>(
            future: SafImageCache.load(image.uri),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const CircularProgressIndicator();
              }
              if (snapshot.data == null) {
                return const Text('Foto tidak dapat dibuka. Coba pilih ulang folder.');
              }
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Hero(
                  tag: image.uri,
                  child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                ),
              );
            },
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              image.modified > 0
                  ? 'Diubah: ${DateTime.fromMillisecondsSinceEpoch(image.modified).toLocal()}'
                  : image.name,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
