import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/functions_service.dart';

enum AppStatus { initial, uploading, generating, success, error }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FunctionsService _functionsService = FunctionsService();
  final ImagePicker _picker = ImagePicker();

  AppStatus _status = AppStatus.initial;
  String? _errorMessage;
  File? _selectedImage;
  List<String> _generatedImageUrls = [];
  bool _isSaving = false;
  late AnimationController _controller;
  final List<String> _scenePool = const [
    'café setting',
    'city travel street',
    'sunny beach',
    'mountain hiking trail',
    'coastal sunset cliffs',
    'snowy cabin',
    'desert road trip',
    'rooftop skyline night',
    'tropical waterfall',
    'forest trail',
    'museum or landmark',
    'sailing boat',
    'lakeside pier dawn',
    'modern art gallery',
    'country farmhouse',
  ];
  final List<String> _chosenScenes = [];
  bool _customSceneEnabled = false;
  final TextEditingController _customSceneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initAuth();
  }

  @override
  void dispose() {
    _controller.dispose();
    _customSceneController.dispose();
    super.dispose();
  }

  Future<void> _initAuth() async {
    final user = _authService.currentUser;
    if (user == null) {
      await _authService.signInAnonymously();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    print('picking image');
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      print('picker dialog closed');
      if (pickedFile != null) {
        print('Image picked');
        setState(() {
          _selectedImage = File(pickedFile.path);
          _generatedImageUrls = [];
          _chosenScenes.clear();
          _customSceneEnabled = false;
          _customSceneController.clear();
          _status = AppStatus.initial;
        });
      }
    } catch (e) {
      _setError("Failed to pick image: $e");
    }
  }

  Future<void> _generate() async {
    if (_selectedImage == null) return;

    final user = _authService.currentUser;
    if (user == null) {
      _setError("User not authenticated");
      return;
    }

    setState(() {
      _status = AppStatus.generating;
      _errorMessage = null;
    });

    try {
      // Build final scenes list (include custom if provided)
      final List<String> scenes = List<String>.from(_chosenScenes);
      final String custom = _customSceneController.text.trim();
      if (_customSceneEnabled && custom.isNotEmpty) {
        if (scenes.length < 4) {
          scenes.add(custom);
        } else {
          scenes[3] = custom; // ensure max 4 by replacing last
        }
      }
      if (scenes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please select scenes first")),
          );
        }
        _openScenePicker();
        return;
      }

      // Generate Images
      final urls = await _functionsService.generateImages(
        _selectedImage!,
        user.uid,
        scenes,
      );

      setState(() {
        _generatedImageUrls = urls;
        _status = AppStatus.success;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated ${urls.length} images'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  bool _hasSelectedScenes() {
    final custom = _customSceneController.text.trim();
    return _chosenScenes.isNotEmpty ||
        (_customSceneEnabled && custom.isNotEmpty);
  }

  void _setError(String message) {
    setState(() {
      _status = AppStatus.error;
      _errorMessage = message;
    });
  }

  void _reset() {
    setState(() {
      _selectedImage = null;
      _generatedImageUrls = [];
      _status = AppStatus.initial;
      _errorMessage = null;
    });
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Select Photo",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOption(
                  icon: Icons.camera_alt_outlined,
                  label: "Camera",
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildOption(
                  icon: Icons.photo_library_outlined,
                  label: "Gallery",
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Photo Remix',
          style: GoogleFonts.dmSans(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          if (_status == AppStatus.success || _selectedImage != null)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restart_alt,
                  color: Colors.black,
                  size: 20,
                ),
              ),
              onPressed: _reset,
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          // Background Gradients
          Positioned(
            top: -100,
            right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.1),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purple.withOpacity(0.1),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: _buildContent(),
                  ),
                ),
                if (_status == AppStatus.initial ||
                    _selectedImage != null &&
                        _status != AppStatus.success &&
                        _status != AppStatus.generating &&
                        _status != AppStatus.uploading)
                  _buildBottomBar(),
              ],
            ),
          ),

          if (_status == AppStatus.error)
            Positioned(
              top: 100,
              left: 24,
              right: 24,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                color: Colors.redAccent,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage ?? "Unknown error",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () =>
                            setState(() => _status = AppStatus.initial),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_status == AppStatus.success) {
      return _buildResultsView();
    } else if (_status == AppStatus.generating ||
        _status == AppStatus.uploading) {
      return _buildLoadingView();
    } else if (_selectedImage != null) {
      print('preview View');
      return _buildPreviewView();
    } else {
      return _buildEmptyState();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Hero(
            tag: 'placeholder',
            child: Container(
              height: 240,
              width: 240,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_outlined,
                size: 80,
                color: Colors.grey[300],
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            "Remix Reality",
            style: GoogleFonts.dmSans(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Turn your portraits into stunning\nAI-generated scenes.",
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'image_preview',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.file(
                  _selectedImage!,
                  height: MediaQuery.of(context).size.height * 0.45,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Ready to Remix",
            style: GoogleFonts.dmSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Choose up to 4 scenes",
            style: GoogleFonts.dmSans(fontSize: 16),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openScenePicker,
            icon: const Icon(Icons.arrow_drop_down),
            label: const Text("Select Scenes"),
          ),
          const SizedBox(height: 8),
          if (_chosenScenes.isNotEmpty ||
              (_customSceneEnabled &&
                  _customSceneController.text.trim().isNotEmpty))
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._chosenScenes.map((s) => Chip(label: Text(s))),
                if (_customSceneEnabled &&
                    _customSceneController.text.trim().isNotEmpty)
                  Chip(label: Text(_customSceneController.text.trim())),
              ],
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _openScenePicker() {
    final Set<String> temp = Set<String>.from(_chosenScenes);
    bool tempOther = _customSceneEnabled;
    final TextEditingController tempController = TextEditingController(
      text: _customSceneController.text,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                final customText = tempController.text.trim();
                final int customCount = (tempOther && customText.isNotEmpty)
                    ? 1
                    : 0;
                final int allowedMax = 4 - customCount;
                final int selectedCount = temp.length + customCount;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Select Scenes",
                            style: GoogleFonts.dmSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "$selectedCount/4",
                            style: GoogleFonts.dmSans(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _scenePool.length,
                          itemBuilder: (context, index) {
                            final s = _scenePool[index];
                            final selected = temp.contains(s);
                            final canSelectMore = temp.length < allowedMax;
                            return CheckboxListTile(
                              title: Text(s, style: GoogleFonts.dmSans()),
                              value: selected,
                              onChanged: (!selected && !canSelectMore)
                                  ? null
                                  : (val) {
                                      setModalState(() {
                                        if (val == true) {
                                          if (temp.length < allowedMax) {
                                            temp.add(s);
                                          }
                                        } else {
                                          temp.remove(s);
                                        }
                                      });
                                    },
                            );
                          },
                        ),
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: Text(
                          "Other (type your own)",
                          style: GoogleFonts.dmSans(),
                        ),
                        value: tempOther,
                        onChanged: (val) {
                          setModalState(() {
                            tempOther = val;
                            final text = tempController.text.trim();
                            final count = (tempOther && text.isNotEmpty)
                                ? 1
                                : 0;
                            final maxAllowed = 4 - count;
                            while (temp.length > maxAllowed) {
                              temp.remove(temp.last);
                            }
                          });
                        },
                      ),
                      if (tempOther)
                        TextField(
                          controller: tempController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText:
                                "Describe your scene (e.g., twilight rooftop café)",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            setModalState(() {
                              if (tempOther) {
                                final text = tempController.text.trim();
                                final count = text.isNotEmpty ? 1 : 0;
                                final maxAllowed = 4 - count;
                                while (temp.length > maxAllowed) {
                                  temp.remove(temp.last);
                                }
                              }
                            });
                          },
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final customText = tempController.text.trim();
                            final int customCount =
                                (tempOther && customText.isNotEmpty) ? 1 : 0;
                            while (temp.length + customCount > 4) {
                              temp.remove(temp.last);
                            }
                            setState(() {
                              _chosenScenes
                                ..clear()
                                ..addAll(temp);
                              _customSceneEnabled = tempOther;
                              _customSceneController.text = customText;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text("Done"),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              children: [
                const Center(
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    _status == AppStatus.uploading
                        ? Icons.cloud_upload
                        : Icons.auto_awesome,
                    color: Colors.black,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _status == AppStatus.uploading
                ? "Uploading your photo..."
                : "Designing new worlds...",
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "This usually takes 5-10 seconds",
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Before",
                  style: GoogleFonts.dmSans(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectedImage != null)
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    ),
                  ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "After (Remixed)",
                      style: GoogleFonts.dmSans(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      onPressed: _isSaving ? null : _saveImages,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black,
                                ),
                              ),
                            )
                          : const Icon(Icons.save_alt),
                      tooltip: _isSaving ? "Saving..." : "Save all to Gallery",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childCount: _generatedImageUrls.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: Colors.black,
                        appBar: AppBar(
                          backgroundColor: Colors.black,
                          iconTheme: const IconThemeData(color: Colors.white),
                        ),
                        body: Center(
                          child: Image.network(
                            _generatedImageUrls[index],
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              final expected =
                                  loadingProgress.expectedTotalBytes;
                              final loaded =
                                  loadingProgress.cumulativeBytesLoaded;
                              final value = expected != null && expected > 0
                                  ? loaded / expected
                                  : null;
                              return SizedBox(
                                height: 300,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: value,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      _generatedImageUrls[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        final expected = loadingProgress.expectedTotalBytes;
                        final loaded = loadingProgress.cumulativeBytesLoaded;
                        final value = expected != null && expected > 0
                            ? loaded / expected
                            : null;
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: Container(color: Colors.grey[200]),
                            ),
                            Center(
                              child: CircularProgressIndicator(value: value),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Future<void> _saveImages() async {
    try {
      setState(() => _isSaving = true);
      // Save generated images
      for (String url in _generatedImageUrls) {
        await GallerySaver.saveImage(url, albumName: "Ergodic Remix");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Images saved to gallery!")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to save images: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton(
          onPressed: _selectedImage == null
              ? _showImagePickerOptions
              : (!_hasSelectedScenes() ? _openScenePicker : _generate),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
          ),
          child: Text(
            _selectedImage == null
                ? "Pick a Photo"
                : (!_hasSelectedScenes() ? "Select Scenes" : "Generate Magic"),
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
