import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  // Obtiene el UID del usuario actual
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userId;
  String? _clientId;

  // Obtiene el ID del cliente desde Firestore
  Future<void> _fetchClientId() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        _userId = user.uid;

        // Busca en la colección 'users' el documento que tiene un campo 'uid' que coincida con _userId
        final QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore
            .instance
            .collection('users')
            .where('uid', isEqualTo: _userId) // Busca por el campo 'uid'
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // Si se encuentra el documento, obtiene el ID del cliente
          _clientId = querySnapshot.docs.first.data()['id'];
          setState(() {});
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener el ID del cliente: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchClientId();
  }

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
        body: TabBarView(
          children: [
            // Pestaña "Reservadas"
            _clientId == null
                ? const Center(child: CircularProgressIndicator(color: Colors.green,))
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('tasks')
                        .where('clientID', isEqualTo: _clientId)
                        .where('state', isEqualTo: 'Pendiente')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(child: Text('Error al obtener tareas'));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final tasks = snapshot.data!.docs;
                      if (tasks.isEmpty) {
                        return const Center(child: Text('No tienes reservas'));
                      }

                      return ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final supplierId = task.data()['supplierID'];

                          // Obtén la información del agente del usuario
                          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(supplierId)
                                .get(),
                            builder: (context, supplierSnapshot) {
                              if (supplierSnapshot.hasError) {
                                return const ListTile(
                                  title: Text('Error al obtener información del agente'),
                                );
                              }
                              if (supplierSnapshot.connectionState == ConnectionState.waiting) {
                                return const ListTile(
                                  title: Center(child: CircularProgressIndicator()),
                                );
                              }

                              final supplier = supplierSnapshot.data;
                              if (supplier == null) {
                                return const ListTile(
                                  title: Text('Agente no encontrado'),
                                );
                              }

                              // Obtén la información del proveedor
                              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                future: FirebaseFirestore.instance
                                    .collection('suppliers')
                                    .doc(supplierId)
                                    .get(),
                                builder: (context, supplierInfoSnapshot) {
                                  if (supplierInfoSnapshot.hasError) {
                                    return const ListTile(
                                      title: Text('Error al obtener información del proveedor'),
                                    );
                                  }
                                  if (supplierInfoSnapshot.connectionState == ConnectionState.waiting) {
                                    return const ListTile(
                                      title: Center(child: CircularProgressIndicator()),
                                    );
                                  }

                                  final supplierInfo = supplierInfoSnapshot.data;
                                  if (supplierInfo == null) {
                                    return const ListTile(
                                      title: Text('Proveedor no encontrado'),
                                    );
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0), // Añade espacio debajo
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFF08143C),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 30,
                                            backgroundImage: supplier.data()?['profileImageUrl'] != null
                                                ? NetworkImage(supplier.data()?['profileImageUrl'])
                                                : const AssetImage(
                                                    'assets/images/ProfilePhoto_predetermined.png'),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'ID: $supplierId',
                                                  style: const TextStyle(fontSize: 8.0),
                                                ),
                                                Text(
                                                  '${supplier.data()?['name']}',
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                                Text(
                                                  task.data()['service'],
                                                  style: const TextStyle(
                                                      fontSize: 14.0, fontStyle: FontStyle.italic),
                                                ),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.star,
                                                      size: 16.0,
                                                      color: Color(0xFF1ca424),
                                                    ),
                                                    const SizedBox(width: 4.0),
                                                    Text(
                                                      '${supplierInfo.data()?['assessment'] ?? 'Sin calificación'}',
                                                      style: const TextStyle(fontSize: 12.0),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 16.0),
                                            child: Text(
                                              task.data()['hourlyRate'] == 0.0
                                                  ? 'Gratis'
                                                  : '\$${task.data()['hourlyRate'].toStringAsFixed(2)}/hr',
                                              style: const TextStyle(
                                                  fontSize: 16.0,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF08143C)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              );
                            }
                          );
                        },
                      );
                    },
                  ),

            // Pestaña "Activas"
            const Center(child: Text('Activas')),

            // Pestaña "Completadas"
            const Center(child: Text('Completadas')),
          ],
        ),
      ),
    );
  }
}