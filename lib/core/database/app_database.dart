import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Exercises, Routines, TrainingSessions, RoutineExercises, ExerciseSets],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ====================== EXERCISES ======================
  Future<List<Exercise>> getAllExercises() => select(exercises).get();

  Future<int> insertExercise(ExercisesCompanion exercise) =>
      into(exercises).insert(exercise);

  Future<bool> updateExercise(Exercise exercise) =>
      update(exercises).replace(exercise);

  Future<int> deleteExercise(int id) =>
      (delete(exercises)..where((t) => t.id.equals(id))).go();

  // ====================== ROUTINES ======================
  Future<List<Routine>> getAllRoutines() => select(routines).get();

  Future<int> insertRoutine(RoutinesCompanion routine) =>
      into(routines).insert(routine);

  // ====================== TRAINING SESSIONS ======================
  Future<List<TrainingSession>> getAllSessions() => select(trainingSessions).get();

  Future<int> insertSession(TrainingSessionsCompanion session) =>
      into(trainingSessions).insert(session);

  // ====================== EXERCISE SETS ======================
  Future<List<ExerciseSet>> getSetsForSession(int sessionId) =>
      (select(exerciseSets)..where((t) => t.trainingSessionId.equals(sessionId))).get();

  Future<int> insertSet(ExerciseSetsCompanion set) =>
      into(exerciseSets).insert(set);

  // ====================== ROUTINE EXERCISES (NUEVO) ======================
  Future<List<Exercise>> getExercisesForRoutine(int routineId) async {
    final routineExs = await (select(routineExercises)
          ..where((tbl) => tbl.routineId.equals(routineId)))
        .get();

    if (routineExs.isEmpty) return [];

    final exerciseIds = routineExs.map((re) => re.exerciseId).toList();

    return (select(exercises)..where((tbl) => tbl.id.isIn(exerciseIds))).get();
  }

  Future<void> addExerciseToRoutine(int routineId, int exerciseId, int orderIndex) async {
    await into(routineExercises).insert(
      RoutineExercisesCompanion.insert(
        routineId: routineId,
        exerciseId: exerciseId,
        orderIndex: orderIndex,
      ),
    );
  }

  Future<void> removeExerciseFromRoutine(int routineId, int exerciseId) async {
    await (delete(routineExercises)
          ..where((tbl) => tbl.routineId.equals(routineId) & tbl.exerciseId.equals(exerciseId)))
        .go();
  }

  // ====================== DATABASE CONNECTION ======================
  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'gym_log_pro.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}