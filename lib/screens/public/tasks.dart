import 'package:flutter/material.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true, 
          title: const Text(
            'Tareas',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {
                // Implementa la lógica de búsqueda
              },
              icon: const Icon(Icons.search),
            ),
          ],
          // TabBar con colores personalizados
          bottom: const TabBar(
            labelColor: Color(0xFF08143C), // Color del texto de la pestaña activa
            unselectedLabelColor: Colors.grey, // Color del texto de la pestaña inactiva
            indicatorColor: Color(0xFF1CA424), // Color de la barra debajo de la pestaña activa
            indicatorWeight: 1, // Ajusta el grosor de la barra indicadora
            indicatorPadding: EdgeInsets.symmetric(horizontal: 1), // Ajusta el espacio entre la barra indicadora y el texto
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'Reservadas'),
              Tab(text: 'Activas'),
              Tab(text: 'Completadas'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            Center(child: Text('Reservadas')),
            Center(child: Text('Activas')),
            Center(child: Text('Completadas')),
          ],
        ),
      ),
    );
  }
}