import 'package:flutter/material.dart';

class TitleSection extends StatelessWidget {
  final TextEditingController controller;

  const TitleSection({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report Title', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Enter a brief title...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
