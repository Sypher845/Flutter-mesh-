import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../models/report_model.dart';
import '../services/data_sync_service.dart';
import '../services/bluetooth_service.dart';
import '../utils/image_helper.dart';
import '../widgets/image_section.dart';
import '../widgets/title_section.dart';
import '../widgets/description_section.dart';
import '../widgets/hazard_type_selector.dart';
import '../widgets/location_section.dart';
import '../widgets/status_messages.dart';
import '../widgets/emulator_warning.dart';
import '../widgets/bluetooth_controls.dart';
import '../widgets/received_data_section.dart';
import '../widgets/tickets_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedImage;
  HazardType _selectedHazardType = HazardType.other;
  LocationData? _location;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
    _descriptionController.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hazard Reporter'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ImageSection(
              selectedImage: _selectedImage,
              onPickImage: _pickImage,
            ),
            SizedBox(height: 16),
            LocationSection(
              location: _location,
              onGetLocation: _getLocation,
              isLoading: _isLoadingLocation,
            ),
            SizedBox(height: 16),
            HazardTypeSelector(
              selectedType: _selectedHazardType,
              onChanged: (type) => setState(() => _selectedHazardType = type),
            ),
            SizedBox(height: 16),
            TitleSection(controller: _titleController),
            SizedBox(height: 16),
            DescriptionSection(controller: _descriptionController),
            SizedBox(height: 20),
            _buildSubmitButton(),
            SizedBox(height: 20),
            StatusMessages(),
            SizedBox(height: 20),
            EmulatorWarning(),
            SizedBox(height: 20),
            BluetoothControls(),
            SizedBox(height: 20),
            ReceivedDataSection(),
            SizedBox(height: 20),
            ReportsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Consumer2<DataSyncService, BluetoothService>(
      builder: (context, dataSync, bluetooth, child) {
        final canSubmit = _canSubmit();

        return ElevatedButton(
          onPressed: canSubmit ? _submitReport : null,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16),
            backgroundColor: canSubmit ? Theme.of(context).primaryColor : Colors.grey,
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Submit Report via Bluetooth',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        final originalFile = File(image.path);
        final compressedFile = await ImageHelper.compressImage(originalFile);
        
        if (compressedFile != null) {
          final compressedSize = await compressedFile.length();
          
          setState(() {
            _selectedImage = compressedFile;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image compressed: ${(compressedSize / 1024).toStringAsFixed(1)} KB'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          setState(() {
            _selectedImage = originalFile;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      // TODO: Implement actual location fetching with geolocator package
      // For now, using mock data
      await Future.delayed(Duration(seconds: 1));
      
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
          SnackBar(
            content: Text('Location captured successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  bool _canSubmit() {
    return _titleController.text.trim().isNotEmpty &&
           _descriptionController.text.trim().isNotEmpty;
  }

  Future<void> _submitReport() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    
    if (title.isEmpty || description.isEmpty) {
      _showMessage('❌ Please fill in all required fields', Colors.red);
      return;
    }

    final report = ReportModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      imageFile: _selectedImage,
      imagePath: _selectedImage?.path,
      location: _location,
      hazardType: _selectedHazardType,
      createdAt: DateTime.now(),
    );

    final dataSync = Provider.of<DataSyncService>(context, listen: false);
    final bluetooth = Provider.of<BluetoothService>(context, listen: false);

    try {
      await dataSync.addReport(report);
    } catch (e) {
      _showMessage('❌ Failed to save report', Colors.red);
      return;
    }

    final deviceCount = bluetooth.connectedDevices.length;
    
    if (deviceCount == 0) {
      _showMessage('📝 Report saved locally (no connected devices)', Colors.orange);
      _clearForm();
      return;
    }

    _showMessage('🔍 Verifying connections...', Colors.blue);
    
    try {
      await bluetooth.checkConnectionHealth();
      final healthyDeviceCount = bluetooth.connectedDevices.length;
      
      if (healthyDeviceCount == 0) {
        _showMessage('❌ No active connections found', Colors.red);
        return;
      }

      _showMessage('📡 Sending to $healthyDeviceCount devices...', Colors.blue);
      await bluetooth.sendReportData(report);
      _showMessage('✅ Report sent successfully!', Colors.green);
      
    } catch (e) {
      _showMessage('❌ Send failed: ${e.toString()}', Colors.red);
    }

    _clearForm();
  }

  void _showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedImage = null;
      _location = null;
      _selectedHazardType = HazardType.other;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
