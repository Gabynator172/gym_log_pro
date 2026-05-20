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
  List<Exercise> allExercises = [];
  List<Exercise> filteredExercises = [];

  @override
  void initState() {
    super.initState();
    db = ref.read(databaseProvider);
    _loadData();
  }

  Future<void> _loadData() async {
    final all = await db.getAllExercises();
    // final inRoutine = await db.getExercisesForRoutine(widget.routine.id); // Activaremos después
    setState(() {
      allExercises = all;
      filteredExercises = all;
    });
  }

  void _filterExercises(String query) {
    setState(() {
      filteredExercises = allExercises
          .where((e) => e.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _addExerciseToRoutine(Exercise exercise) async {
    try {
      final currentOrder = exercisesInRoutine.length;
      await db.addExerciseToRoutine(widget.routine.id, exercise.id, currentOrder);
      
      setState(() {
        exercisesInRoutine.add(exercise);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${exercise.name} agregado')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.routine.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar ejercicio...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterExercises,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredExercises.length,
              itemBuilder: (context, index) {
                final exercise = filteredExercises[index];
                return ListTile(
                  title: Text(exercise.name),
                  subtitle: Text(exercise.muscleGroup),
                  trailing: const Icon(Icons.add_circle_outline, color: Colors.green),
                  onTap: () => _addExerciseToRoutine(exercise),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}