import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _capturedImage;

  Future<void> captureImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _capturedImage = File(pickedFile.path);
      });

      Navigator.pop(context, pickedFile.path); // Return image path
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Scan Parcel Label")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _capturedImage == null
                ? Text("No image captured yet")
                : Image.file(_capturedImage!), // Display captured image
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: captureImage,
              child: Text("📸 Capture Image"),
            ),
          ],
        ),
      ),
    );
  }
}
