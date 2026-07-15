import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const DevTubeApp());
}

class DevTubeApp extends StatelessWidget {
  const DevTubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevTube App',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: false,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final String backendUrl = 'https://braverindo.my.id/api/videos';
  final String youtubeApiKey = 'xxxxxxxxxx';

  final TextEditingController _searchController = TextEditingController();
  List youtubeResults = [];
  bool isLoadingSearch = false;
  List savedVideos = [];
  bool isLoadingSaved = false;

  // VARIABEL BARU: Untuk mengingat video mana saja yang sudah di-klik "Simpan"
  Set<String> processedVideoIds = {};

  final List<String> categories = [
    'Flutter',
    'Laravel',
    'React',
    'Python',
    'UI/UX'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        loadSavedVideos();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- API YOUTUBE ---
  Future<void> searchYouTube(String query) async {
    if (query.isEmpty) return;
    _searchController.text = query;
    FocusScope.of(context).unfocus();
    setState(() => isLoadingSearch = true);

    final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=10&q=$query&type=video&key=$youtubeApiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          youtubeResults = data['items'] ?? [];
          isLoadingSearch = false;
        });
      } else {
        setState(() => isLoadingSearch = false);
        final errorData = jsonDecode(response.body);
        showSnackBar('API Error: ${errorData['error']['message']}');
      }
    } catch (e) {
      setState(() => isLoadingSearch = false);
      showSnackBar('Koneksi gagal. Cek jaringan Anda.');
    }
  }

  // --- DATABASE OPERATIONS ---
  Future<void> simpanKeDatabase(Map item) async {
    final videoId = item['id']['videoId'];

    // Mencegah proses jika video sudah pernah di-klik simpan
    if (processedVideoIds.contains(videoId)) return;

    // Langsung ubah tampilan tombol agar responsif
    setState(() {
      processedVideoIds.add(videoId);
    });

    // Langsung tampilkan pesan ke pengguna
    showSnackBar('Menyimpan video ke database...');

    final videoData = {
      'youtube_video_id': videoId,
      'title': item['snippet']['title'],
      'channel_title': item['snippet']['channelTitle'],
      'thumbnail_url': item['snippet']['thumbnails']['high']['url']
    };

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(videoData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        showSnackBar('Sukses: Video berhasil tersimpan!');
      }
    } catch (e) {
      showSnackBar('Gagal menyimpan ke server, silakan coba lagi.');
      // Jika gagal, kembalikan status tombol seperti semula
      setState(() {
        processedVideoIds.remove(videoId);
      });
    }
  }

  Future<void> loadSavedVideos() async {
    setState(() => isLoadingSaved = true);
    try {
      final response = await http.get(Uri.parse(backendUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          savedVideos = data['data'] ?? [];
          isLoadingSaved = false;
        });
      }
    } catch (e) {
      setState(() => isLoadingSaved = false);
      showSnackBar('Gagal memuat data dari server');
    }
  }

  Future<void> updateStatus(int id) async {
    try {
      await http.put(
        Uri.parse('$backendUrl/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': 'Sudah Ditonton'}),
      );
      showSnackBar('Status diperbarui');
      loadSavedVideos();
    } catch (e) {
      showSnackBar('Gagal memperbarui status');
    }
  }

  Future<void> hapusVideo(int id) async {
    try {
      await http.delete(Uri.parse('$backendUrl/$id'));
      showSnackBar('Video dihapus');
      loadSavedVideos();
    } catch (e) {
      showSnackBar('Gagal menghapus video');
    }
  }

  // --- UTILITIES ---
  Future<void> tontonVideo(String videoId) async {
    final url = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      showSnackBar('Tidak bisa membuka video');
    }
  }

  void bagikanVideo(String videoId, String title) {
    Share.share(
        'Cek video tutorial menarik ini: $title\nhttps://www.youtube.com/watch?v=$videoId');
  }

  void showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating, // Membuat pesan melayang rapi
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DevTube'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Cari Video'),
            Tab(icon: Icon(Icons.bookmark), text: 'Tersimpan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: PENCARIAN
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Ketik kata kunci...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => searchYouTube(_searchController.text),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onSubmitted: (value) => searchYouTube(value),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((cat) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ActionChip(
                          label: Text(cat),
                          backgroundColor: Colors.deepPurple.shade50,
                          onPressed: () => searchYouTube(cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: isLoadingSearch
                      ? const Center(child: CircularProgressIndicator())
                      : youtubeResults.isEmpty
                          ? const Center(
                              child: Text('Tidak ada hasil pencarian'))
                          : ListView.builder(
                              itemCount: youtubeResults.length,
                              itemBuilder: (context, index) {
                                final item = youtubeResults[index];
                                final videoId = item['id']['videoId'];
                                final title = item['snippet']['title'];

                                // Cek apakah video ini sudah diklik simpan
                                final bool isSaved =
                                    processedVideoIds.contains(videoId);

                                return Card(
                                  elevation: 3,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(10)),
                                        child: Image.network(
                                          item['snippet']['thumbnails']['high']
                                                  ['url'] ??
                                              '',
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(title,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text(
                                                'Channel: ${item['snippet']['channelTitle']}',
                                                style: const TextStyle(
                                                    color: Colors.grey)),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    icon: const Icon(
                                                        Icons.play_arrow),
                                                    label: const Text('Tonton'),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                            backgroundColor:
                                                                Colors.red,
                                                            foregroundColor:
                                                                Colors.white),
                                                    onPressed: () =>
                                                        tontonVideo(videoId),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // --- TOMBOL SIMPAN YANG SUDAH DIPERBARUI ---
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    icon: Icon(isSaved
                                                        ? Icons.check
                                                        : Icons.save),
                                                    label: Text(isSaved
                                                        ? 'Tersimpan'
                                                        : 'Simpan'),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      // Berubah jadi abu-abu jika sudah disimpan
                                                      backgroundColor: isSaved
                                                          ? Colors.grey.shade400
                                                          : Colors.blue,
                                                      foregroundColor:
                                                          Colors.white,
                                                    ),
                                                    // Tombol mati (null) jika sudah disimpan agar tidak dobel
                                                    onPressed: isSaved
                                                        ? null
                                                        : () =>
                                                            simpanKeDatabase(
                                                                item),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(Icons.share,
                                                      color: Colors.blue),
                                                  onPressed: () => bagikanVideo(
                                                      videoId, title),
                                                )
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),

          // TAB 2: DATABASE TERSIMPAN
          RefreshIndicator(
            onRefresh: loadSavedVideos,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: isLoadingSaved
                  ? const Center(child: CircularProgressIndicator())
                  : savedVideos.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 200),
                            Center(
                                child: Text(
                                    'Belum ada video disimpan. Tarik ke bawah untuk refresh.')),
                          ],
                        )
                      : ListView.builder(
                          itemCount: savedVideos.length,
                          itemBuilder: (context, index) {
                            final video = savedVideos[index];
                            final bool sudahDitonton =
                                video['status'] == 'Sudah Ditonton';
                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(video['title'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text('Channel: ${video['channel_title']}',
                                        style: const TextStyle(
                                            color: Colors.grey)),
                                    Text('Status: ${video['status']}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: sudahDitonton
                                                ? Colors.green
                                                : Colors.orange)),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        video['thumbnail_url'] ?? '',
                                        width: double.infinity,
                                        height: 180,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const SizedBox(
                                          height: 180,
                                          child: Center(
                                              child: Icon(Icons.broken_image,
                                                  size: 50,
                                                  color: Colors.grey)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.play_circle),
                                      label: const Text('Tonton Video'),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          minimumSize:
                                              const Size.fromHeight(40)),
                                      onPressed: () => tontonVideo(
                                          video['youtube_video_id']),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            icon: Icon(
                                                sudahDitonton
                                                    ? Icons.check
                                                    : Icons
                                                        .check_box_outline_blank,
                                                color: sudahDitonton
                                                    ? Colors.green
                                                    : null),
                                            label: Text(sudahDitonton
                                                ? 'Selesai'
                                                : 'Tandai Selesai'),
                                            onPressed: sudahDitonton
                                                ? null
                                                : () =>
                                                    updateStatus(video['id']),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            label: const Text('Hapus',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                            onPressed: () =>
                                                hapusVideo(video['id']),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
