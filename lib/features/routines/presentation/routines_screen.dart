import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/database/app_database.dart';
import '../../../shared/providers/database_provider.dart';
import 'routine_detail_screen.dart';

class RoutinesScreen extends ConsumerStatefulWidget {
  const RoutinesScreen({super.key});

  @override
  ConsumerState<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends ConsumerState<RoutinesScreen> {
  late AppDatabase db;
  List<Routine> routines = [];

  @override
  void initState() {
    super.initState();
    db = ref.read(databaseProvider);
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    final list = await db.getAllRoutines();
    setState(() => routines = list);
  }

  Future<void> _createRoutine() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Rutina'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre de la rutina')),
            const SizedBox(height: 12),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Descripción (opcional)'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await db.insertRoutine(RoutinesCompanion.insert(
                  name: name,
                  description: descController.text.trim().isEmpty ? const drift.Value(null) : drift.Value(descController.text.trim()),
                ));
                Navigator.pop(context);
                _loadRoutines();
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Rutinas')),
      body: routines.isEmpty
          ? const Center(
              child: Text('No tienes rutinas aún\nCrea una con el botón +', textAlign: TextAlign.center),
            )
          : ListView.builder(
              itemCount: routines.length,
              itemBuilder: (context, index) {
                final routine = routines[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ListTile(
                    title: Text(routine.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(routine.description ?? 'Sin descripción'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoutineDetailScreen(routine: routine),
                        ),
                      ).then((_) => _loadRoutines());
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createRoutine,
        child: const Icon(Icons.add),
      ),
    );
  }
}