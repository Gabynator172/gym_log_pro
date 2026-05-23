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

  List<Exercise> allExercises = [];
  List<Exercise> filteredExercises = [];

  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    db = ref.read(databaseProvider);
    _createNewSession();
    _loadExercises();
    _seedExercisesIfEmpty();
  }

  Future<void> _createNewSession() async {
    final sessionId = await db.insertSession(
      TrainingSessionsCompanion.insert(date: DateTime.now()),
    );
    setState(() => currentSessionId = sessionId);
  }

  Future<void> _loadExercises() async {
    final exercises = await db.getAllExercises();
    setState(() {
      allExercises = exercises;
      filteredExercises = exercises;
    });
  }

  Future<void> _seedExercisesIfEmpty() async {
    final existing = await db.getAllExercises();
    if (existing.isNotEmpty) return;

    final defaultExercises = [
      ('Press de Banca con Barra', 'Pecho', 'Compuesto', 'Barra'),
      ('Press Inclinado con Barra', 'Pecho', 'Compuesto', 'Barra'),
      ('Press Banca Mancuernas', 'Pecho', 'Compuesto', 'Mancuernas'),
      ('Aperturas con Mancuernas', 'Pecho', 'Aislamiento', 'Mancuernas'),
      ('Dominadas', 'Espalda', 'Compuesto', 'Cuerpo'),
      ('Remo con Barra', 'Espalda', 'Compuesto', 'Barra'),
      ('Sentadilla con Barra', 'Piernas', 'Compuesto', 'Barra'),
      ('Prensa de Piernas', 'Piernas', 'Compuesto', 'Máquina'),
      ('Press Militar con Barra', 'Hombros', 'Compuesto', 'Barra'),
      ('Elevaciones Laterales', 'Hombros', 'Aislamiento', 'Mancuernas'),
      ('Curl de Bíceps', 'Bíceps', 'Aislamiento', 'Mancuernas'),
      ('Tríceps en Polea', 'Tríceps', 'Aislamiento', 'Cable'),
      ('Plancha', 'Core', 'Aislamiento', 'Cuerpo'),
    ];

    for (var ex in defaultExercises) {
      await db.insertExercise(ExercisesCompanion.insert(
        name: ex.$1,
        muscleGroup: ex.$2,
        type: ex.$3,
        equipment: ex.$4,
        isCustom: const drift.Value(false),
      ));
    }
    await _loadExercises();
  }

  double get totalVolume {
    double volume = 0;
    for (var ex in currentWorkoutExercises) {
      for (var set in ex.sets) {
        volume += set.weight * set.reps;
      }
    }
    return volume;
  }

  double getVolumeForExercise(WorkoutExercise exercise) {
    return exercise.sets.fold(0.0, (sum, set) => sum + (set.weight * set.reps));
  }

  Future<void> _loadRoutine(Routine routine) async {
    try {
      final exercisesInRoutine = await db.getExercisesForRoutine(routine.id);
      if (exercisesInRoutine.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta rutina no tiene ejercicios')));
        return;
      }

      setState(() {
        currentWorkoutExercises.clear();
        for (var ex in exercisesInRoutine) {
          currentWorkoutExercises.add(WorkoutExercise(
            name: ex.name,
            exerciseId: ex.id,
            sets: [],
          ));
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Rutina "${routine.name}" cargada (${exercisesInRoutine.length} ejercicios)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar rutina: $e')));
    }
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
          ));
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Entrenamiento guardado correctamente'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _toggleEditing() => setState(() => isEditing = !isEditing);

  void _deleteExercise(int index) {
    setState(() => currentWorkoutExercises.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ejercicio eliminado')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Entrenamiento'),
        actions: [
          TextButton.icon(
            onPressed: _toggleEditing,
            icon: Icon(isEditing ? Icons.check : Icons.edit),
            label: Text(isEditing ? 'Listo' : 'Editar'),
          ),
          TextButton.icon(
            onPressed: _finishWorkout,
            icon: const Icon(Icons.check_circle),
            label: const Text('Finalizar'),
          ),
        ],
      ),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.blue[700],
            child: Text(
              'Volumen Total: ${totalVolume.toStringAsFixed(0)} kg',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: currentWorkoutExercises.isEmpty
                ? const Center(child: Text('Presiona + para agregar ejercicios o rutinas', style: TextStyle(fontSize: 18, color: Colors.grey)))
                : isEditing
                    ? ReorderableListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: currentWorkoutExercises.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = currentWorkoutExercises.removeAt(oldIndex);
                            currentWorkoutExercises.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final ex = currentWorkoutExercises[index];
                          return Card(
                            key: ValueKey(ex.exerciseId),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const Icon(Icons.drag_handle),
                              title: Text(ex.name),
                              subtitle: Text('${ex.sets.length} series'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteExercise(index),
                              ),
                            ),
                          );
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: currentWorkoutExercises.length,
                        itemBuilder: (context, index) {
                          final ex = currentWorkoutExercises[index];
                          final vol = getVolumeForExercise(ex);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(ex.name),
                              subtitle: Text('${ex.sets.length} series • ${vol.toStringAsFixed(0)} kg'),
                              trailing: const Icon(Icons.add_circle, color: Colors.green, size: 28),
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
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                const Text('¿Qué quieres agregar?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                ListTile(leading: const Icon(Icons.search, color: Colors.blue, size: 30), title: const Text('Buscar Ejercicio', style: TextStyle(fontSize: 18)), onTap: () { Navigator.pop(context); _showExerciseSelector(); }),
                const Divider(height: 30),
                ListTile(leading: const Icon(Icons.list_alt, color: Colors.orange, size: 30), title: const Text('Cargar Rutina Completa', style: TextStyle(fontSize: 18)), onTap: () { Navigator.pop(context); _showRoutinesDialog(); }),
                const Divider(height: 30),
                ListTile(leading: const Icon(Icons.add_circle, color: Colors.green, size: 30), title: const Text('Crear Ejercicio Personalizado', style: TextStyle(fontSize: 18)), onTap: () { Navigator.pop(context); _showCreateCustomExercise(); }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== BUSCADOR COPIADO EXACTAMENTE DE ROUTINE DETAIL ====================
  void _showExerciseSelector() async {
    final allExercisesLocal = await db.getAllExercises();
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = allExercisesLocal
              .where((ex) => ex.name.toLowerCase().contains(searchQuery.toLowerCase()))
              .toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.92,
            minChildSize: 0.6,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Agregar Ejercicios', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),

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

                  if (currentWorkoutExercises.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('En este entrenamiento:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: currentWorkoutExercises.map((workoutEx) {
                              return Chip(
                                label: Text(workoutEx.name),
                                backgroundColor: Colors.green.withOpacity(0.2),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () {
                                  setState(() {
                                    currentWorkoutExercises.removeWhere((e) => e.exerciseId == workoutEx.exerciseId);
                                  });
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
                        final isAdded = currentWorkoutExercises.any((e) => e.exerciseId == exercise.id);

                        return ListTile(
                          title: Text(exercise.name),
                          subtitle: Text(exercise.muscleGroup),
                          trailing: Icon(
                            isAdded ? Icons.check_circle : Icons.add_circle_outline,
                            color: isAdded ? Colors.green : Colors.blue,
                            size: 28,
                          ),
                          onTap: () {
                            setState(() {
                              if (isAdded) {
                                currentWorkoutExercises.removeWhere((e) => e.exerciseId == exercise.id);
                              } else {
                                currentWorkoutExercises.add(WorkoutExercise(
                                  name: exercise.name,
                                  exerciseId: exercise.id,
                                  sets: [],
                                ));
                              }
                            });
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
                        child: const Text('Listo', style: TextStyle(fontSize: 18)),
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

  void _showCreateCustomExercise() {
    final nameCtrl = TextEditingController();
    final groupCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Ejercicio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: groupCtrl, decoration: const InputDecoration(labelText: 'Grupo Muscular')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                await db.insertExercise(ExercisesCompanion.insert(
                  name: nameCtrl.text.trim(),
                  muscleGroup: groupCtrl.text.trim().isEmpty ? 'Personalizado' : groupCtrl.text.trim(),
                  type: 'Personalizado',
                  equipment: 'Personalizado',
                  isCustom: const drift.Value(true),
                ));
                await _loadExercises();
                Navigator.pop(context);
              }
            },
            child: const Text('Crear'),
          ),
        ],
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
          height: 480,
          child: ListView.builder(
            itemCount: routines.length,
            itemBuilder: (context, index) {
              final routine = routines[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.fitness_center, color: Colors.orange, size: 36),
                  ),
                  title: Text(routine.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                  subtitle: Text(routine.description ?? 'Sin descripción'),
                  trailing: const Icon(Icons.chevron_right, size: 28),
                  onTap: () {
                    Navigator.pop(context);
                    _loadRoutine(routine);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ],
      ),
    );
  }

  void _editExerciseSets(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SetInputSheet(
            exercise: currentWorkoutExercises[index],
            onSetsUpdated: (updatedSets) {
              setState(() => currentWorkoutExercises[index].sets = updatedSets);
            },
            scrollController: scrollController,
          ),
        ),
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
  final ScrollController? scrollController;

  const SetInputSheet({
    super.key,
    required this.exercise,
    required this.onSetsUpdated,
    this.scrollController,
  });

  @override
  State<SetInputSheet> createState() => _SetInputSheetState();
}

class _SetInputSheetState extends State<SetInputSheet> {
  late List<ExerciseSet> sets;

  @override
  void initState() {
    super.initState();
    sets = List.from(widget.exercise.sets);
    if (sets.isEmpty) sets.add(ExerciseSet(reps: 8, weight: 60));
  }

  void _addSet() => setState(() => sets.add(ExerciseSet(reps: 8, weight: 60)));

  void _removeSet(int index) {
    if (sets.length > 1) setState(() => sets.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
          Text(widget.exercise.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              itemCount: sets.length,
              itemBuilder: (context, index) {
                final set = sets[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Text('Serie ${index + 1}'),
                        const SizedBox(width: 16),
                        Expanded(child: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reps'), controller: TextEditingController(text: set.reps.toString()), onChanged: (val) => set.reps = int.tryParse(val) ?? 8)),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Peso (kg)'), controller: TextEditingController(text: set.weight.toString()), onChanged: (val) => set.weight = double.tryParse(val) ?? 60)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeSet(index)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(onPressed: _addSet, icon: const Icon(Icons.add), label: const Text('Nueva Serie')),
              ElevatedButton(onPressed: () { widget.onSetsUpdated(sets); Navigator.pop(context); }, child: const Text('Guardar Series')),
            ],
          ),
        ],
      ),
    );
  }
}