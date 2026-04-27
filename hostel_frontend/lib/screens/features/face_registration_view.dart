import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api_calls.dart';
import '../../theme.dart';

class FaceRegistrationView extends StatefulWidget {
  const FaceRegistrationView({super.key});

  @override
  State<FaceRegistrationView> createState() => _FaceRegistrationViewState();
}

class _FaceRegistrationViewState extends State<FaceRegistrationView> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  
  final List<String> _directions = ['front', 'left', 'right', 'up', 'down'];
  final Map<String, String> _prompts = {
    'front': 'Look straight at the camera',
    'left': 'Turn your head to the left',
    'right': 'Turn your head to the right',
    'up': 'Tilt your head up',
    'down': 'Tilt your head down',
  };
  
  int _currentIndex = 0;
  final Map<String, XFile> _capturedPhotos = {};
  bool _isUploading = false;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      // Prefer front camera
      CameraDescription targetCamera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        targetCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      print('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile photo = await _controller!.takePicture();
      final currentDirection = _directions[_currentIndex];
      
      setState(() {
        _capturedPhotos[currentDirection] = photo;
        _currentIndex++;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to capture: $e')));
    }
  }

  Future<void> _retakePhoto(String direction) async {
    setState(() {
      _capturedPhotos.remove(direction);
      _currentIndex = _directions.indexOf(direction);
    });
  }

  Future<void> _uploadPhotos() async {
    setState(() => _isUploading = true);
    
    final success = await ApiManager.uploadFaceRegistrationPhotos(_capturedPhotos);
    
    if (!mounted) return;
    setState(() => _isUploading = false);
    
    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Success!'),
          content: const Text('Your face registration data has been submitted and is currently being processed by the system.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // close dialog
                // Reset state instead of popping the entire dashboard
                setState(() {
                  _currentIndex = 0;
                  _capturedPhotos.clear();
                });
              },
              child: const Text('Done'),
            )
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload photos. Please try again.'), backgroundColor: AppTheme.accentColor)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= _directions.length) {
      return _buildSummaryScreen();
    }

    if (!_isCameraReady || _controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentDirection = _directions[_currentIndex];
    final prompt = _prompts[currentDirection]!;

    return Scaffold(
      appBar: AppBar(title: const Text('Face Registration')),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),
          
          // Face Oval Overlay
          Center(
            child: Container(
              width: 250,
              height: 350,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor, width: 4),
                borderRadius: BorderRadius.circular(150), // Oval shape
              ),
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).fade(begin: 0.5, end: 1.0, duration: 1000.ms),

          // Instructions
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Step ${_currentIndex + 1} of ${_directions.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    prompt,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Capture Button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _capturePhoto,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryColor, width: 4),
                  ),
                  child: const Icon(Icons.camera_alt, size: 32, color: AppTheme.primaryColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Photos')),
      body: _isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  const Text('Uploading and processing...'),
                  const SizedBox(height: 8),
                  Text('This may take a moment', style: TextStyle(color: AppTheme.textSecondaryColor)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Almost done!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please review your photos. If any are blurry, you can retake them.',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  ..._directions.map((dir) {
                    final photo = _capturedPhotos[dir];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          if (photo != null)
                            kIsWeb 
                                ? Image.network(photo.path, width: 100, height: 100, fit: BoxFit.cover)
                                : Image.file(File(photo.path), width: 100, height: 100, fit: BoxFit.cover),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dir.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                            onPressed: () => _retakePhoto(dir),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _uploadPhotos,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Submit & Train Model', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}
