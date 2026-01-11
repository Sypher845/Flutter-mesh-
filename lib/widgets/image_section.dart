import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ImageSection extends StatelessWidget {
  final File? selectedImage;
  final Function(ImageSource) onPickImage;

  const ImageSection({
    super.key,
    required this.selectedImage,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upload Image', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 10),
            if (selectedImage != null) ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(selectedImage!, fit: BoxFit.cover),
                ),
              ),
              SizedBox(height: 8),
              FutureBuilder<int>(
                future: selectedImage!.length(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final sizeKB = snapshot.data! / 1024;
                    final color = sizeKB > 200 ? Colors.red : (sizeKB > 100 ? Colors.orange : Colors.green);
                    final icon = sizeKB > 200 ? Icons.warning : Icons.check_circle;
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14, color: color),
                          SizedBox(width: 4),
                          Text(
                            'Size: ${sizeKB.toStringAsFixed(1)} KB${sizeKB > 200 ? ' (Too large!)' : sizeKB > 100 ? ' (May fail)' : ' (Good)'}',
                            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
              SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onPickImage(ImageSource.camera),
                    icon: Icon(Icons.camera_alt),
                    label: Text('Camera'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onPickImage(ImageSource.gallery),
                    icon: Icon(Icons.photo_library),
                    label: Text('Gallery'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
