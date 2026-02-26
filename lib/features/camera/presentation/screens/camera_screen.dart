import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tide/features/camera/presentation/screens/post_preview_screen.dart';

enum CameraMode { photo, video }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  CameraMode _currentMode = CameraMode.photo;
  
  final List<File> _capturedMedia = [];
  final int _maxItems = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _initializeCamera(_selectedCameraIndex);
      }
    } catch (e) {
      debugPrint("DEBUG ERROR: Erro ao carregar câmaras: $e");
    }
  }

  Future<void> _initializeCamera(int cameraIndex) async {
    if (_controller != null) await _controller!.dispose();

    _controller = CameraController(
      _cameras![cameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint("DEBUG ERROR: Erro ao inicializar câmara: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _handleCapture() async {
    if (_currentMode == CameraMode.photo) {
      await _takePicture();
    } else {
      if (_isRecording) {
        await _stopVideo();
      } else {
        await _startVideo();
      }
    }
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _controller!.value.isTakingPicture || _capturedMedia.length >= _maxItems) return;
    try {
      final image = await _controller!.takePicture();
      setState(() => _capturedMedia.add(File(image.path)));
    } catch (e) {
      debugPrint("DEBUG ERROR: _takePicture: $e");
    }
  }

  Future<void> _startVideo() async {
    if (!_isCameraInitialized || _isRecording) return;
    try {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint("DEBUG ERROR: _startVideo: $e");
    }
  }

  Future<void> _stopVideo() async {
    if (!_isCameraInitialized || !_isRecording) return;
    try {
      final video = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _capturedMedia.clear(); // Garante que só vai o vídeo atual
        _capturedMedia.add(File(video.path));
      });
      _finishCapture();
    } catch (e) {
      debugPrint("DEBUG ERROR: _stopVideo: $e");
    }
  }

  void _finishCapture() {
    if (_capturedMedia.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostPreviewScreen(mediaFiles: List.from(_capturedMedia)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black, 
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8)))
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          _buildUI(),
        ],
      ),
    );
  }

  Widget _buildUI() {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(),
          const Spacer(),
          // CARROSSEL SÓ APARECE NO MODO FOTO
          if (_currentMode == CameraMode.photo && _capturedMedia.isNotEmpty) 
            _buildThumbnailList(),
          _buildModeSelector(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.4),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // Botão SEGUINTE só aparece no modo FOTO (no vídeo é automático)
          if (_currentMode == CameraMode.photo && _capturedMedia.isNotEmpty)
            GestureDetector(
              onTap: _finishCapture,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  "SEGUINTE (${_capturedMedia.length})", 
                  style: GoogleFonts.inter(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 12,
                    letterSpacing: 1
                  )
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    if (_isRecording) return const SizedBox(height: 40);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20)
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _modeButton("FOTO", CameraMode.photo),
            const SizedBox(width: 24),
            _modeButton("VÍDEO", CameraMode.video),
          ],
        ),
      ),
    );
  }

  Widget _modeButton(String label, CameraMode mode) {
    bool isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () {
        if (_isRecording) return;
        setState(() {
          _currentMode = mode;
          _capturedMedia.clear(); 
        });
      },
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: isSelected ? Colors.white : Colors.white38,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const SizedBox(width: 48), 
          GestureDetector(
            onTap: _handleCapture,
            child: Container(
              height: 85, width: 85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isRecording ? Colors.white : Colors.white.withOpacity(0.5), 
                  width: 4
                ),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _isRecording ? 32 : 70,
                  width: _isRecording ? 32 : 70,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.redAccent : Colors.white,
                    borderRadius: BorderRadius.circular(_isRecording ? 6 : 40),
                  ),
                ),
              ),
            ),
          ),
          CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.4),
            radius: 24,
            child: IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 24),
              onPressed: () {
                _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
                _initializeCamera(_selectedCameraIndex);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailList() {
    return Container(
      height: 65,
      margin: const EdgeInsets.only(bottom: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _capturedMedia.length,
        itemBuilder: (context, index) => Container(
          width: 50, margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 2),
            image: DecorationImage(
              image: FileImage(_capturedMedia[index]), 
              fit: BoxFit.cover
            ),
          ),
        ),
      ),
    );
  }
}