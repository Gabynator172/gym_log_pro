import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/database/app_database.dart';
import '../../../shared/providers/database_provider.dart';
import '../../routines/presentation/routines_screen.dart';

class NewWorkoutScreen extends ConsumerStatefulWidget {
  const NewWorkoutScreen({super.key});

  @override
  ConsumerState<NewWorkoutScreen> createState() => _NewWorkoutScreenState();
}

class _NewWorkoutScreenState extends ConsumerState<NewWorkoutScreen> {
  late AppDatabase db;
  int? currentSessionId;
  final List<WorkoutExercise> currentWorkoutExercises = [];
  final Set<int> addedExerciseIds = {};

  @override
  void initState() {
    super.initState();
    db = ref.read(databaseProvider);
    _createNewSession();
  }

  Future<void> _createNewSession() async {
    final sessionId = await db.insertSession(TrainingSessionsCompanion.insert(date: DateTime.now()));
    setState(() => currentSessionId = sessionId);
  }

  // ==================== CARGAR RUTINA ====================
  Future<void> _loadRoutine(Routine routine) async {
    final exercises = await db.getExercisesForRoutine(routine.id);
    setState(() {
      currentWorkoutExercises.clear();
      addedExerciseIds.clear();
      for (var ex in exercises) {
        currentWorkoutExercises.add(WorkoutExercise(name: ex.name, exerciseId: ex.id, sets: []));
        addedExerciseIds.add(ex.id);
      }
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Rutina "${routine.name}" cargada')));
  }

  // ==================== BUSCADOR AVANZADO ====================
  void _showExerciseSelector() async {
    final allExercises = await db.getAllExercises();
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = allExercises
                .where((ex) => ex.name.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.92,
              minChildSize: 0.6,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Seleccionar Ejercicios', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),

                    // Barra de búsqueda
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Buscar ejercicio...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setModalState(() => searchQuery = value);
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Ejercicios seleccionados (anclados arriba)
                    if (addedExerciseIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Seleccionados:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: currentWorkoutExercises.map((ex) {
                                return Chip(
                                  label: Text(ex.name),
                                  backgroundColor: Colors.green.withOpacity(0.2),
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                  onDeleted: () {
                                    _removeExercise(currentWorkoutExercises.indexOf(ex));
                                    setModalState(() {});
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final exercise = filtered[index];
                          final isAdded = addedExerciseIds.contains(exercise.id);

                          return ListTile(
                            title: Text(exercise.name),
                            subtitle: Text(exercise.muscleGroup),
                            trailing: Icon(
                              isAdded ? Icons.check_circle : Icons.add_circle_outline,
                              color: isAdded ? Colors.green : Colors.blue,
                              size: 28,
                            ),
                            onTap: () {
                              if (isAdded) {
                                // Quitar si ya está seleccionado
                                final indexToRemove = currentWorkoutExercises.indexWhere((e) => e.exerciseId == exercise.id);
                                if (indexToRemove != -1) {
                                  _removeExercise(indexToRemove);
                                  setModalState(() {});
                                }
                              } else {
                                // Agregar
                                _addExercise(exercise);
                                setModalState(() {});
                              }
                            },
                          );
                        },
                      ),
                    ),

                    // Botón Listo
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Listo', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _addExercise(Exercise exercise) {
    setState(() {
      currentWorkoutExercises.add(WorkoutExercise(
        name: exercise.name,
        exerciseId: exercise.id,
        sets: [],
      ));
      addedExerciseIds.add(exercise.id);
    });
  }

  void _removeExercise(int index) {
    if (index < 0 || index >= currentWorkoutExercises.length) return;
    final name = currentWorkoutExercises[index].name;
    setState(() {
      addedExerciseIds.remove(currentWorkoutExercises[index].exerciseId);
      currentWorkoutExercises.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Eliminado: $name')));
  }

  Future<void> _finishWorkout() async {
    if (currentSessionId == null || currentWorkoutExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega al menos un ejercicio')));
      return;
    }

    try {
      for (var workoutEx in currentWorkoutExercises) {
        for (int i = 0; i < workoutEx.sets.length; i++) {
          final set = workoutEx.sets[i];
          await db.insertSet(ExerciseSetsCompanion.insert(
            trainingSessionId: currentSessionId!,
            exerciseId: workoutEx.exerciseId,
            setNumber: i + 1,
            reps: set.reps,
            weight: set.weight,
            completed: const drift.Value(true),
          ));
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Entrenamiento guardado correctamente!'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Entrenamiento')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[850],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sesión #$currentSessionId', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${DateTime.now().toString().substring(0, 10)}'),
              ],
            ),
          ),
          Expanded(
            child: currentWorkoutExercises.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fitness_center, size: 90, color: Colors.grey),
                        SizedBox(height: 20),
                        Text('Sin ejercicios aún', style: TextStyle(fontSize: 22)),
                        Text('Presiona + para agregar'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: currentWorkoutExercises.length,
                    itemBuilder: (context, index) {
                      final ex = currentWorkoutExercises[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${ex.sets.length} series'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeExercise(index),
                          ),
                          onTap: () => _editExerciseSets(index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10))),
            const Text('¿Qué quieres agregar?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            ListTile(
              leading: const Icon(Icons.search, size: 28, color: Colors.blue),
              title: const Text('Buscar Ejercicio Individual'),
              subtitle: const Text('Agregar uno por uno'),
              onTap: () {
                Navigator.pop(context);
                _showExerciseSelector();
              },
            ),
            const Divider(height: 8),

            ListTile(
              leading: const Icon(Icons.list_alt, size: 28, color: Colors.orange),
              title: const Text('Cargar Rutina Completa'),
              subtitle: const Text('Agregar todos los ejercicios de una rutina'),
              onTap: () {
                Navigator.pop(context);
                _showRoutinesDialog();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showRoutinesDialog() async {
    final routines = await db.getAllRoutines();
    if (routines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes rutinas creadas')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Rutina'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: routines.length,
            itemBuilder: (context, index) {
              final routine = routines[index];
              return ListTile(
                title: Text(routine.name),
                onTap: () => _loadRoutine(routine),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))],
      ),
    );
  }

  void _editExerciseSets(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SetInputSheet(
        exercise: currentWorkoutExercises[index],
        onSetsUpdated: (updatedSets) {
          setState(() => currentWorkoutExercises[index].sets = updatedSets);
        },
      ),
    );
  }
}

// ====================== MODELOS ======================
class WorkoutExercise {
  final String name;
  final int exerciseId;
  List<ExerciseSet> sets;
  WorkoutExercise({required this.name, required this.exerciseId, required this.sets});
}

class ExerciseSet {
  int reps;
  double weight;
  ExerciseSet({required this.reps, required this.weight});
}

// ====================== SetInputSheet ======================
class SetInputSheet extends StatefulWidget {
  final WorkoutExercise exercise;
  final Function(List<ExerciseSet>) onSetsUpdated;

  const SetInputSheet({super.key, required this.exercise, required this.onSetsUpdated});

  @override
  State<SetInputSheet> createState() => _SetInputSheetState();
}

class _SetInputSheetState extends State<SetInputSheet> {
  late List<ExerciseSet> sets;

  @override
  void initState() {
    super.initState();
    sets = List.from(widget.exercise.sets);
    if (sets.isEmpty) sets.add(ExerciseSet(reps: 8, weight: 60.0));
  }

  void _addSet() => setState(() => sets.add(ExerciseSet(reps: 8, weight: 60.0)));
  void _removeSet(int index) {
    if (sets.length > 1) setState(() => sets.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.exercise.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...sets.asMap().entries.map((entry) {
            int idx = entry.key;
            ExerciseSet set = entry.value;
            return Row(
              children: [
                Text('Serie ${idx + 1}'),
                const SizedBox(width: 16),
                Expanded(child: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reps'), controller: TextEditingController(text: set.reps.toString()), onChanged: (val) => set.reps = int.tryParse(val) ?? 8)),
                const SizedBox(width: 12),
                Expanded(child: TextField(keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Peso (kg)'), controller: TextEditingController(text: set.weight.toString()), onChanged: (val) => set.weight = double.tryParse(val) ?? 60.0)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeSet(idx)),
              ],
            );
          }).toList(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(onPressed: _addSet, icon: const Icon(Icons.add), label: const Text('Nueva Serie')),
              ElevatedButton(onPressed: () { widget.onSetsUpdated(sets); Navigator.pop(context); }, child: const Text('Guardar Series')),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}