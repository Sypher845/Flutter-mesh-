import 'package:flutter/material.dart';
import '../core/enums/report_enums.dart';

class HazardTypeSelector extends StatelessWidget {
  final HazardType selectedType;
  final Function(HazardType) onChanged;

  const HazardTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hazard Type', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 10),
            DropdownButtonFormField<HazardType>(
              initialValue: selectedType,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              isExpanded: true,
              items: HazardType.values.map((type) {
                return DropdownMenuItem<HazardType>(
                  value: type,
                  child: Row(
                    children: [
                      Text(type.icon, style: TextStyle(fontSize: 20)),
                      SizedBox(width: 12),
                      Text(type.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (HazardType? newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
