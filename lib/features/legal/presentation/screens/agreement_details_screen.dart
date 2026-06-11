import 'package:flutter/material.dart';

class AgreementDetailsScreen extends StatelessWidget {
  const AgreementDetailsScreen({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agreement details')),
      body: Center(child: Text('Document ID: $documentId')),
    );
  }
}
