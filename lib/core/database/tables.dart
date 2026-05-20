import 'package:drift/drift.dart';

@DataClassName('Exercise')
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 3, max: 100)();
  TextColumn get muscleGroup => text()();
  TextColumn get type => text()(); // Compuesto, Aislamiento
  TextColumn get equipment => text()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
}

@DataClassName('Routine')
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 3, max: 80)();
  TextColumn get description => text().nullable()();
}

@DataClassName('TrainingSession')
class TrainingSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  IntColumn get routineId => integer().nullable()();
  TextColumn get notes => text().nullable()();
  RealColumn get bodyWeight => real().nullable()();
}

@DataClassName('RoutineExercise')
class RoutineExercises extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get routineId => integer()();

  IntColumn get exerciseId => integer()();

  IntColumn get orderIndex => integer()();
}

@DataClassName('ExerciseSet')
class ExerciseSets extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get trainingSessionId => integer()();

  IntColumn get exerciseId => integer()();

  IntColumn get setNumber => integer()();

  IntColumn get reps => integer()();

  RealColumn get weight => real()();

  BoolColumn get completed =>
      boolean().withDefault(const Constant(true))();
}