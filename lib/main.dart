import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';
import 'package:flutter_tts/flutter_tts.dart';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marker Detection for Blind',
      home: CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  bool isDetecting = false;
  FlutterTts flutterTts = FlutterTts();
  String? lastDetectedLabel; // Variabel untuk menyimpan label terakhir
  bool allowRepeat = true; // Variabel untuk mengontrol apakah pengucapan diizinkan

  @override
  void initState() {
    super.initState();
    controller = CameraController(cameras![0], ResolutionPreset.medium);
    controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      loadModel();
      controller?.startImageStream((CameraImage img) {
        if (!isDetecting) {
          isDetecting = true;
          detectObject(img);
        }
      });
    });
  }

  loadModel() async {
    await Tflite.loadModel(
      model: "assets/xcep4_model.tflite",
      labels: "assets/labels.txt",
    );
  }

  detectObject(CameraImage img) async {
    var recognitions = await Tflite.runModelOnFrame(
      bytesList: img.planes.map((plane) {
        return plane.bytes;
      }).toList(),
      imageHeight: img.height,
      imageWidth: img.width,
      imageMean: 127.5,
      imageStd: 127.5,
      numResults: 1,
      threshold: 0.5,
    );

    // Pengecekan null dan jika recognitions tidak kosong
    if (recognitions != null && recognitions.isNotEmpty) {
      String label = recognitions[0]["label"];
      double confidence = recognitions[0]["confidence"];
      
      // Hanya sebutkan jika confidence cukup tinggi dan pengucapan diizinkan
      if (confidence > 0.6 && allowRepeat) {
        speak(label);
        lastDetectedLabel = label;
        allowRepeat = false; // Nonaktifkan pengucapan ulang hingga kamera beralih
        
        // Jeda deteksi untuk mencegah pengulangan suara yang terlalu cepat
        Future.delayed(Duration(seconds: 3), () {
          allowRepeat = true; // Izinkan pengucapan lagi setelah 3 detik
        });
      }
    }

    isDetecting = false;
  }

  speak(String text) async {
    await flutterTts.speak("Terdapat $text di depan Anda");
  }

  @override
  void dispose() {
    controller?.dispose();
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller!.value.isInitialized) {
      return Container();
    }
    return Scaffold(
      appBar: AppBar(title: Text('Deteksi Marker')),
      body: CameraPreview(controller!),
    );
  }
}
