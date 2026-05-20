import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/database/app_database.dart';
import '../../../shared/providers/database_provider.dart';
import '../../workout/presentation/new_workout_screen.dart';
import '../../routines/presentation/routines_screen.dart';   // ← Nueva importación

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym Log Pro'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¡Bienvenido!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '¿Qué quieres hacer hoy?',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 40),

            // Historial
            _buildMenuButton(
              icon: Icons.history,
              title: 'Historial',
              subtitle: 'Ver entrenamientos pasados',
              onTap: () {
                // TODO: Implementar más adelante
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Historial - Próximamente')),
                );
              },
            ),
            const SizedBox(height: 16),

            // Nuevo Entrenamiento
            _buildMenuButton(
              icon: Icons.fitness_center,
              title: 'Nuevo Entrenamiento',
              subtitle: 'Registrar sesión de hoy',
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NewWorkoutScreen()),
                );
              },
            ),
            const SizedBox(height: 16),

            // Mis Rutinas
            _buildMenuButton(
              icon: Icons.list_alt,
              title: 'Mis Rutinas',
              subtitle: 'Crear y gestionar rutinas',
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RoutinesScreen()),
                );
              },
            ),
            const SizedBox(height: 16),

            // Estadísticas
            _buildMenuButton(
              icon: Icons.bar_chart,
              title: 'Estadísticas',
              subtitle: 'Progreso y récords',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Estadísticas - Próximamente')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = Colors.blue,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 40, color: color),
        title: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}