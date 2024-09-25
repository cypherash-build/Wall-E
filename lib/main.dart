import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(debug: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wally',
      theme: ThemeData(
        fontFamily: 'MontserratAlternates',
        brightness: Brightness.dark,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const WallpaperScreen(),
    );
  }
}

class WallpaperScreen extends StatefulWidget {
  const WallpaperScreen({super.key});

  @override
  _WallpaperScreenState createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen> {
  List<dynamic> wallpapers = [];
  List<dynamic> likedWallpapers = [];
  bool isLoading = false;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initSharedPreferences().then((_) {
      // Now _prefs is initialized, you can safely use it in setState or other parts of your widget
      setState(() {});
    });

    _loadWallpapers();
    //_requestStoragePermission();
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadLikedWallpapers(); // Load liked wallpapers from SharedPreferences
  }

  Future<void> _loadLikedWallpapers() async {
    final likedUrls = _prefs.getStringList('liked_wallpapers') ?? [];
    setState(() {
      likedWallpapers = wallpapers
          .where((wallpaper) => likedUrls.contains(wallpaper['url']))
          .toList();
    });
  }

  Future<void> _loadWallpapers() async {
    final String response = await rootBundle.loadString('assets/dhd_links.txt');
    final lines = response.split('\n');
    setState(() {
      wallpapers = lines.where((line) => line.isNotEmpty).map((line) {
        final fileName = line.split('/').last;
        final title = fileName
            .split('.')
            .first
            .replaceAll('~', ' '); // Replace ~ with space
        return {'url': line, 'title': title};
      }).toList();
    });
  }

  void _downloadImage(String imageUrl) async {
    try {
      final directory =
          await getApplicationDocumentsDirectory(); // Get internal storage directory
      final savedDir = directory.path;

      // Initiate download
      await FlutterDownloader.enqueue(
        url: imageUrl,
        savedDir: savedDir,
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: true,
      );
    } on PlatformException catch (error) {
      // Handle download errors
      print(error);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to download image')),
      );
    }
  }

  void _toggleLike(int index) async {
    if (_prefs == null) {
      // Handle the case where SharedPreferences is not yet initialized
      // You could show a loading indicator or a message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please wait while the app is loading...')),
      );
      return;
    }

    try {
      setState(() {
        if (likedWallpapers.contains(wallpapers[index])) {
          likedWallpapers.remove(wallpapers[index]);
        } else {
          likedWallpapers.add(wallpapers[index]);
        }
      });

      // Extract URLs from likedWallpapers and create a List<String>
      final likedUrls = likedWallpapers
          .map((wallpaper) => wallpaper['url'] as String)
          .toList();

      // Save the List<String> to SharedPreferences
      await _prefs.setStringList('liked_wallpapers', likedUrls);
    } catch (e) {
      // Handle potential errors during SharedPreferences operations
      print('Error saving liked wallpapers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('An error occurred while saving your preferences')),
      );
    }
  }

  void _showPreviewDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
              ),
              padding: const EdgeInsets.all(16),
              child: FadeInImage.memoryNetwork(
                placeholder: kTransparentImage,
                image: imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Wall-E ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      LikedWallpapersScreen(wallpapers: likedWallpapers),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
        ),
        itemCount: wallpapers.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _showPreviewDialog(context, wallpapers[index]['url']),
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FadeInImage.memoryNetwork(
                    placeholder: kTransparentImage,
                    image: wallpapers[index]['url'],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  if (isLoading)
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) async {
                        if (value == 'preview') {
                          _showPreviewDialog(context, wallpapers[index]['url']);
                        } else if (value == 'download') {
                          var status =
                              await Permission.manageExternalStorage.request();
                          if (status.isGranted) {
                            if (Platform.isAndroid &&
                                await Permission.photos.isDenied) {
                              await Permission.photos.request();
                            }
                            _downloadImage(wallpapers[index]['url']);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Storage permission denied')),
                            );
                          }
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'preview',
                          child: Row(
                            children: [Icon(Icons.preview), Text('Preview')],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'download',
                          child: Row(
                            children: [Icon(Icons.download), Text("Dowload")],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: IconButton(
                      icon: Icon(
                        likedWallpapers.contains(wallpapers[index])
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: likedWallpapers.contains(wallpapers[index])
                            ? Colors.red
                            : Colors.white,
                      ),
                      onPressed: () => _toggleLike(index),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black.withOpacity(
                          0.5), // Semi-transparent background for title
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            wallpapers[index]['title'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              overflow:
                                  TextOverflow.ellipsis, // Eclipse long titles
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              likedWallpapers.contains(wallpapers[index])
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: likedWallpapers.contains(wallpapers[index])
                                  ? Colors.red
                                  : Colors.white,
                            ),
                            onPressed: () => _toggleLike(index),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class LikedWallpapersScreen extends StatelessWidget {
  final List<dynamic> wallpapers;

  const LikedWallpapersScreen({super.key, required this.wallpapers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liked Wallpapers'),
      ),
      body: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
        ),
        itemCount: wallpapers.length,
        itemBuilder: (context, index) {
          return Card(
            elevation: 4,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            child: FadeInImage.memoryNetwork(
              placeholder: kTransparentImage,
              image: wallpapers[index]['url'],
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          );
        },
      ),
    );
  }
}
