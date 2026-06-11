import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/legal_provider.dart';

class AgreementsScreen extends ConsumerWidget {
  const AgreementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Agreements')),
      body: uid == null
          ? const Center(child: Text('Please log in'))
          : StreamBuilder(
              stream: ref
                  .watch(legalRepositoryProvider)
                  .watchUserLegalDocuments(userId: uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No agreements yet'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    final type = data['documentType']?.toString() ?? 'document';
                    return ListTile(
                      title: Text(type),
                      subtitle: Text('Created: ${data['createdAt']}'),
                      onTap: () {
                        // TODO: navigate to agreement details/receipt
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
