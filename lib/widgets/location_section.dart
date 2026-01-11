import 'package:flutter/material.dart';
import '../models/report_model.dart';

class LocationSection extends StatelessWidget {
  final LocationData? location;
  final VoidCallback onGetLocation;
  final bool isLoading;

  const LocationSection({
    super.key,
    required this.location,
    required this.onGetLocation,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Location', style: Theme.of(context).textTheme.titleMedium),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : onGetLocation,
                  icon: isLoading 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.my_location, size: 18),
                  label: Text(location == null ? 'Get Location' : 'Update'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            if (location != null) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green[700], size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location!.formattedCoordinates,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (location!.accuracy != null) ...[
                      SizedBox(height: 4),
                      Text(
                        'Accuracy: ±${location!.accuracy!.toStringAsFixed(1)}m',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.orange[700], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No location captured yet',
                        style: TextStyle(color: Colors.orange[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
