import 'package:flutter/material.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User management')),
      body: const Center(
        child: Text('Wire GET /v1/admin/users with pagination + role filters.'),
      ),
    );
  }
}
