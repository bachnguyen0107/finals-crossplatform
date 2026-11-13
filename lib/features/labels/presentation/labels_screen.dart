import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/labels_providers.dart';
import '../domain/label.dart';

class LabelsScreen extends ConsumerStatefulWidget {
  const LabelsScreen({super.key});

  @override
  ConsumerState<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends ConsumerState<LabelsScreen> {
  bool _isLoading = false;

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showAddOrEditDialog({Label? label}) async {
    final isEditing = label != null;
    final controller = TextEditingController(text: label?.name ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Rename Label' : 'Add Label'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Label Name'),
              validator: validateLabelName,
              onFieldSubmitted: (_) => _submit(formKey, controller, label),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : () => _submit(formKey, controller, label),
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submit(
    GlobalKey<FormState> formKey,
    TextEditingController controller,
    Label? label,
  ) async {
    if (!formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final name = controller.text.trim();
      final notifier = ref.read(labelsControllerProvider.notifier);
      if (label == null) {
        await notifier.create(name: name);
      } else {
        await notifier.rename(id: label.id, name: name);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmAndDelete(Label label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Label'),
          content: Text(
            'Are you sure you want to delete "${label.name}"?\n\nDeleting a label will never delete your notes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await ref.read(labelsControllerProvider.notifier).delete(label.id);
      } catch (e) {
        _showSnackBar(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelsAsync = ref.watch(labelsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Labels'),
      ),
      body: labelsAsync.when(
        data: (labels) {
          if (labels.isEmpty) {
            return const Center(child: Text('No labels yet'));
          }
          return ListView.builder(
            itemCount: labels.length,
            itemBuilder: (context, index) {
              final label = labels[index];
              return ListTile(
                title: Text(label.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showAddOrEditDialog(label: label),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _confirmAndDelete(label),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(labelsControllerProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}