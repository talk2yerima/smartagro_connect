import 'package:flutter/material.dart';

class AdminCommoditiesScreen extends StatelessWidget {
  const AdminCommoditiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commodity management')),
      body: const Center(
        child: Text('CRUD reference prices + categories from admin APIs.'),
      ),
    );
  }
}
