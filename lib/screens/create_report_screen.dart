import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../models/report_model.dart';
import '../providers/report_provider.dart';
import '../services/bluetooth/bluetooth_service.dart';
import '../core/enums/report_enums.dart';

class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({super.key});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _selectedImage;
  int? _imageSize; // Size in bytes
  LocationData? _location;
  HazardType _selectedHazardType = HazardType.other;
  bool _isSubmitting = false;
  bool _isLoadingLocation = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Widget _buildImageSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.image, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Image',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_selectedImage != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                        _imageSize = null;
                      });
                    },
                    tooltip: 'Remove image',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_selectedImage != null) ...[
              // Image Preview
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedImage!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              
              // Image Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compressed Size: ${(_imageSize! / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _imageSize! < 300 * 1024 
                                ? '✓ Size is good for transmission'
                                : '⚠ Image may be too large',
                            style: TextStyle(
                              fontSize: 12,
                              color: _imageSize! < 300 * 1024 
                                  ? Colors.green.shade700 
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Pick Image Button
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Pick Image from Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.blue.shade300),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Optional: Add a photo to your report',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_location != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _location = null;
                      });
                    },
                    tooltip: 'Remove location',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_location != null) ...[
              // Location Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Location Captured',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildLocationRow(
                      Icons.my_location,
                      'Latitude',
                      _location!.latitude.toStringAsFixed(6),
                    ),
                    const SizedBox(height: 8),
                    _buildLocationRow(
                      Icons.my_location,
                      'Longitude',
                      _location!.longitude.toStringAsFixed(6),
                    ),
                    if (_location!.accuracy != null) ...[
                      const SizedBox(height: 8),
                      _buildLocationRow(
                        Icons.gps_fixed,
                        'Accuracy',
                        '±${_location!.accuracy!.toStringAsFixed(1)}m',
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.map, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _location!.formattedCoordinates,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Get Location Button
              OutlinedButton.icon(
                onPressed: _isLoadingLocation ? null : _getLocation,
                icon: _isLoadingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_location),
                label: Text(_isLoadingLocation ? 'Getting Location...' : 'Capture Current Location'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Optional: Add GPS coordinates to your report',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final imageFile = File(image.path);
        
        // Compress image
        final bytes = await imageFile.readAsBytes();
        final decodedImage = img.decodeImage(bytes);
        
        if (decodedImage != null) {
          final compressed = img.encodeJpg(decodedImage, quality: 70);
          final tempFile = File('${imageFile.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tempFile.writeAsBytes(compressed);
          
          setState(() {
            _selectedImage = tempFile;
            _imageSize = compressed.length;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✓ Image compressed: ${(compressed.length / 1024).toStringAsFixed(1)} KB'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Mock location for now
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _location = LocationData(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 10.0,
          timestamp: DateTime.now(),
        );
        _isLoadingLocation = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location captured'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isSubmitting = true);

      // Create report
      final report = ReportModel(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageFile: _selectedImage,
        imagePath: _selectedImage?.path,
        location: _location,
        hazardType: _selectedHazardType,
        createdAt: DateTime.now(),
        hopCount: 0,
      );

      // Add to provider first (save locally)
      final provider = Provider.of<ReportProvider>(context, listen: false);
      provider.addReport(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Report saved locally, sending to nearby devices...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Send via Bluetooth using Nearby Connections
      // Get the bluetooth service instance from home screen
      // We'll use a global instance approach
      try {
        final bluetoothService = BluetoothService();
        await bluetoothService.sendReportData(report);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Report sent successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (sendError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠ Report saved locally but send failed: $sendError'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Error creating report: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Report'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<HazardType>(
                initialValue: _selectedHazardType,
                decoration: const InputDecoration(
                  labelText: 'Hazard Type',
                  border: OutlineInputBorder(),
                ),
                items: HazardType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.name),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedHazardType = value);
                  }
                },
              ),
              const SizedBox(height: 24),
              
              // Image Section
              _buildImageSection(),
              
              const SizedBox(height: 24),
              
              // Location Section
              _buildLocationSection(),
              
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}