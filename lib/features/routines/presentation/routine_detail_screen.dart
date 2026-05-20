import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/database/app_database.dart';
import '../../../shared/providers/database_provider.dart';

class RoutineDetailScreen extends ConsumerStatefulWidget {
  final Routine routine;

  const RoutineDetailScreen({super.key, required this.routine});

  @override
  ConsumerState<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends ConsumerState<RoutineDetailScreen> {
  late AppDatabase db;
  List<Exercise> exercisesInRoutine = [];
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    db = ref.read(databaseProvider);
    _loadRoutineExercises();
  }

  Future<void> _loadRoutineExercises() async {
    final exercises = await db.getExercisesForRoutine(widget.routine.id);
    setState(() => exercisesInRoutine = exercises);
  }

  Future<void> _addExerciseToRoutine(Exercise exercise) async {
    final order = exercisesInRoutine.length;
    await db.addExerciseToRoutine(widget.routine.id, exercise.id, order);
    await _loadRoutineExercises();
  }

  Future<void> _removeExerciseFromRoutine(int exerciseId) async {
    await db.removeExerciseFromRoutine(widget.routine.id, exerciseId);
    await _loadRoutineExercises();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;

    final movedExercise = exercisesInRoutine.removeAt(oldIndex);
    exercisesInRoutine.insert(newIndex, movedExercise);

    // Actualizar orden en BD
    for (int i = 0; i < exercisesInRoutine.length; i++) {
      await db.addExerciseToRoutine(
        widget.routine.id,
        exercisesInRoutine[i].id,
        i,
      );
    }
    setState(() {});
  }

  void _showAddExercisesToRoutine() async { 
    // (Mantengo el buscador anterior, puedes copiarlo si lo necesitas)
    final allExercises = await db.getAllExercises();
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = allExercises
              .where((ex) => ex.name.toLowerCase().contains(searchQuery.toLowerCase()))
              .toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.92,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Agregar a "${widget.routine.name}"', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar ejercicio...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setModalState(() => searchQuery = value),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final exercise = filtered[index];
                        final isInRoutine = exercisesInRoutine.any((e) => e.id == exercise.id);

                        return ListTile(
                          title: Text(exercise.name),
                          subtitle: Text(exercise.muscleGroup),
                          trailing: Icon(
                            isInRoutine ? Icons.check_circle : Icons.add_circle_outline,
                            color: isInRoutine ? Colors.green : Colors.blue,
                          ),
                          onTap: () async {
                            if (isInRoutine) {
                              await _removeExerciseFromRoutine(exercise.id);
                            } else {
                              await _addExerciseToRoutine(exercise);
                            }
                            setModalState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Listo'),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine.name),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => isEditing = !isEditing),
            icon: Icon(isEditing ? Icons.check : Icons.edit),
            label: Text(isEditing ? 'Listo' : 'Editar'),
          ),
        ],
      ),
      body: exercisesInRoutine.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fitness_center, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Esta rutina no tiene ejercicios aún'),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: exercisesInRoutine.length,
              onReorder: _onReorder,
              buildDefaultDragHandles: false,
              itemBuilder: (context, index) {
                final exercise = exercisesInRoutine[index];
                return Card(
                  key: ValueKey(exercise.id),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: isEditing
                        ? ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle, size: 28), // ← 3 líneas horizontales
                          )
                        : null,
                    title: Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(exercise.muscleGroup),
                    trailing: isEditing
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeExerciseFromRoutine(exercise.id),
                          )
                        : null,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExercisesToRoutine,
        icon: const Icon(Icons.add),
        label: const Text('Agregar Ejercicios'),
      ),
    );
  }
}