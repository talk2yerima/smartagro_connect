import 'package:flutter/material.dart';

class AdminModerationScreen extends StatelessWidget {
  const AdminModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product moderation')),
      body: const Center(
        child: Text('Queue flagged listings, approve/reject with audit trail.'),
      ),
    );
  }
}
