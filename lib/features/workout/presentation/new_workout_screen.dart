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

  // ==================== EJERCICIOS PRECARGADOS ====================
  Future<void> _seedExercisesIfEmpty() async {
    final existing = await db.getAllExercises();
    if (existing.isNotEmpty) return;

    final defaultExercises = [
      // Pecho
      ('Press de Banca con Barra', 'Pecho', 'Compuesto', 'Barra'),
      ('Press Inclinado con Barra', 'Pecho', 'Compuesto', 'Barra'),
      ('Press Banca Mancuernas', 'Pecho', 'Compuesto', 'Mancuernas'),
      ('Aperturas con Mancuernas', 'Pecho', 'Aislamiento', 'Mancuernas'),
      // Espalda
      ('Dominadas', 'Espalda', 'Compuesto', 'Cuerpo'),
      ('Remo con Barra', 'Espalda', 'Compuesto', 'Barra'),
      ('Remo con Mancuernas', 'Espalda', 'Compuesto', 'Mancuernas'),
      ('Jalón al Pecho', 'Espalda', 'Compuesto', 'Máquina'),
      // Piernas
      ('Sentadilla con Barra', 'Piernas', 'Compuesto', 'Barra'),
      ('Prensa de Piernas', 'Piernas', 'Compuesto', 'Máquina'),
      ('Peso Muerto Rumano', 'Piernas', 'Compuesto', 'Barra'),
      ('Zancadas', 'Piernas', 'Compuesto', 'Mancuernas'),
      // Hombros
      ('Press Militar con Barra', 'Hombros', 'Compuesto', 'Barra'),
      ('Elevaciones Laterales', 'Hombros', 'Aislamiento', 'Mancuernas'),
      // Brazos
      ('Curl de Bíceps con Barra', 'Bíceps', 'Aislamiento', 'Barra'),
      ('Curl Martillo', 'Bíceps', 'Aislamiento', 'Mancuernas'),
      ('Tríceps en Polea', 'Tríceps', 'Aislamiento', 'Cable'),
      ('Fondos en Paralelas', 'Tríceps', 'Compuesto', 'Cuerpo'),
      // Core
      ('Plancha', 'Core', 'Aislamiento', 'Cuerpo'),
      ('Crunch Abdominal', 'Core', 'Aislamiento', 'Cuerpo'),
    ];

    for (var ex in defaultExercises) {
      await db.insertExercise(
        ExercisesCompanion.insert(
          name: ex.$1,
          muscleGroup: ex.$2,
          type: ex.$3,
          equipment: ex.$4,
          isCustom: const drift.Value(false),
        ),
      );
    }
    await _loadExercises();
  }

  // ==================== CARGAR RUTINA COMPLETA ====================
  Future<void> _loadRoutine(Routine routine) async {
    try {
      final exercisesInRoutine = await db.getExercisesForRoutine(routine.id);

      if (exercisesInRoutine.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esta rutina no tiene ejercicios')),
        );
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

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Rutina "${routine.name}" cargada (${exercisesInRoutine.length} ejercicios)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar rutina: $e')),
      );
    }
  }

  // ==================== GUARDAR ENTRENAMIENTO ====================
  Future<void> _finishWorkout() async {
    if (currentSessionId == null || currentWorkoutExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega al menos un ejercicio')));
      return;
    }

    try {
      for (var workoutEx in currentWorkoutExercises) {
        for (int i = 0; i < workoutEx.sets.length; i++) {
          final set = workoutEx.sets[i];
          await db.insertSet(
            ExerciseSetsCompanion.insert(
              trainingSessionId: currentSessionId!,
              exerciseId: workoutEx.exerciseId,
              setNumber: i + 1,
              reps: set.reps,
              weight: set.weight,
            ),
          );
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

  // ==================== UI ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Entrenamiento'),
        actions: [
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
          Expanded(
            child: currentWorkoutExercises.isEmpty
                ? const Center(
                    child: Text('Presiona + para agregar ejercicios o rutinas',
                        style: TextStyle(fontSize: 18, color: Colors.grey)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: currentWorkoutExercises.length,
                    itemBuilder: (context, index) {
                      final ex = currentWorkoutExercises[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(ex.name),
                          subtitle: Text('${ex.sets.length} series'),
                          trailing: const Icon(Icons.edit),
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
            const Text('¿Qué quieres agregar?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.search, color: Colors.blue, size: 28),
              title: const Text('Buscar Ejercicio'),
              onTap: () {
                Navigator.pop(context);
                _showExerciseSelector();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.list_alt, color: Colors.orange, size: 28),
              title: const Text('Cargar Rutina Completa'),
              onTap: () {
                Navigator.pop(context);
                _showRoutinesDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_circle, color: Colors.green, size: 28),
              title: const Text('Crear Ejercicio Personalizado'),
              onTap: () {
                Navigator.pop(context);
                _showCreateCustomExercise();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showExerciseSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar ejercicio...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      filteredExercises = allExercises
                          .where((e) => e.name.toLowerCase().contains(value.toLowerCase()))
                          .toList();
                    });
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filteredExercises.length,
                  itemBuilder: (context, index) {
                    final ex = filteredExercises[index];
                    return ListTile(
                      title: Text(ex.name),
                      subtitle: Text('${ex.muscleGroup} • ${ex.equipment}'),
                      onTap: () {
                        Navigator.pop(context);
                        _addExercise(ex);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addExercise(Exercise exercise) {
    setState(() {
      currentWorkoutExercises.add(WorkoutExercise(
        name: exercise.name,
        exerciseId: exercise.id,
        sets: [],
      ));
    });
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
                await db.insertExercise(
                  ExercisesCompanion.insert(
                    name: nameCtrl.text.trim(),
                    muscleGroup: groupCtrl.text.trim().isEmpty ? 'Personalizado' : groupCtrl.text.trim(),
                    type: 'Personalizado',
                    equipment: 'Personalizado',
                    isCustom: const drift.Value(true),
                  ),
                );
                await _loadExercises();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ejercicio creado')));
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
          height: 400,
          child: ListView.builder(
            itemCount: routines.length,
            itemBuilder: (context, index) {
              final routine = routines[index];
              return ListTile(
                title: Text(routine.name),
                subtitle: Text(routine.description ?? ''),
                onTap: () => _loadRoutine(routine),
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
    if (sets.isEmpty) sets.add(ExerciseSet(reps: 8, weight: 60));
  }

  void _addSet() => setState(() => sets.add(ExerciseSet(reps: 8, weight: 60)));

  void _removeSet(int index) {
    if (sets.length > 1) setState(() => sets.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 20,
      ),
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
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Reps'),
                    controller: TextEditingController(text: set.reps.toString()),
                    onChanged: (val) => set.reps = int.tryParse(val) ?? 8,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Peso (kg)'),
                    controller: TextEditingController(text: set.weight.toString()),
                    onChanged: (val) => set.weight = double.tryParse(val) ?? 60,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeSet(idx),
                ),
              ],
            );
          }).toList(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(onPressed: _addSet, icon: const Icon(Icons.add), label: const Text('Nueva Serie')),
              ElevatedButton(
                onPressed: () {
                  widget.onSetsUpdated(sets);
                  Navigator.pop(context);
                },
                child: const Text('Guardar Series'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}