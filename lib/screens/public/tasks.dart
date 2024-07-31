import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
// ignore: unnecessary_import
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_paypal/flutter_paypal.dart';
import 'package:mobileservicesapp/screens/public/wallet.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State createState() => _TasksScreenState();
}

class _TasksScreenState extends State {
  // Obtiene el UID del usuario actual
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userId;
  String? _clientId;

  // Obtiene el ID del cliente desde Firestore
  Future _fetchClientId() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        _userId = user.uid;

        // Busca en la colección 'users' el documento que tiene un campo 'uid' que coincida con _userId
        final QuerySnapshot<Map<String, dynamic>> querySnapshot =
            await FirebaseFirestore.instance
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
              fontSize: 28,
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
            labelColor:
                Color(0xFF08143C), // Color del texto de la pestaña activa
            unselectedLabelColor:
                Colors.grey, // Color del texto de la pestaña inactiva
            indicatorColor: Color(
                0xFF1CA424), // Color de la barra debajo de la pestaña activa
            indicatorWeight: 1, // Ajusta el grosor de la barra indicadora
            indicatorPadding: EdgeInsets.symmetric(
                horizontal:
                    1), // Ajusta el espacio entre la barra indicadora y el texto
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'Reservadas'),
              Tab(text: 'Activas'),
              Tab(text: 'Completadas'),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.only(top: 16.0), // Añade espacio arriba
          child: TabBarView(
            children: [
              // Pestaña "Reservadas"
              _clientId == null
                  ? const Center(
                      child: CircularProgressIndicator(
                      color: Colors.green,
                    ))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('tasks')
                          .where('clientID', isEqualTo: _clientId)
                          .where('state', isEqualTo: 'Pendiente')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                              child: Text('Error al obtener tareas'));
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                            color: Colors.green,
                          ));
                        }

                        final tasks = snapshot.data!.docs;
                        if (tasks.isEmpty) {
                          return const Center(
                              child: Text('No tienes reservas'));
                        }

                        return ListView.builder(
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            final supplierId = task.data()['supplierID'];

                            // Obtén la información del agente del usuario
                            return FutureBuilder<
                                    DocumentSnapshot<Map<String, dynamic>>>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(supplierId)
                                    .get(),
                                builder: (context, supplierSnapshot) {
                                  if (supplierSnapshot.hasError) {
                                    return const ListTile(
                                      title: Text(
                                          'Error al obtener información del agente'),
                                    );
                                  }
                                  if (supplierSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const ListTile(
                                      title: Center(
                                          child: CircularProgressIndicator(
                                        color: Colors.green,
                                      )),
                                    );
                                  }

                                  final supplier = supplierSnapshot.data;
                                  if (supplier == null) {
                                    return const ListTile(
                                      title: Text('Agente no encontrado'),
                                    );
                                  }

                                  // Obtén la información del proveedor
                                  return FutureBuilder<
                                          DocumentSnapshot<
                                              Map<String, dynamic>>>(
                                      future: FirebaseFirestore.instance
                                          .collection('suppliers')
                                          .doc(supplierId)
                                          .get(),
                                      builder: (context, supplierInfoSnapshot) {
                                        if (supplierInfoSnapshot.hasError) {
                                          return const ListTile(
                                            title: Text(
                                                'Error al obtener información del proveedor'),
                                          );
                                        }
                                        if (supplierInfoSnapshot
                                                .connectionState ==
                                            ConnectionState.waiting) {
                                          return const ListTile(
                                            title: Center(
                                                child:
                                                    CircularProgressIndicator(
                                              color: Colors.green,
                                            )),
                                          );
                                        }

                                        final supplierInfo =
                                            supplierInfoSnapshot.data;
                                        if (supplierInfo == null) {
                                          return const ListTile(
                                            title:
                                                Text('Proveedor no encontrado'),
                                          );
                                        }

                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    TaskDetailsScreen(
                                                  task: task,
                                                  supplier: supplier,
                                                  supplierInfo: supplierInfo,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                bottom:
                                                    0.0), // Añade espacio debajo
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              // Modifica la decoración para solo bordes arriba y abajo
                                              decoration: const BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                      color: Color(0xFF08143c),
                                                      width: 0.5),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 30,
                                                    backgroundImage: supplier
                                                                    .data()?[
                                                                'profileImageUrl'] !=
                                                            null
                                                        ? NetworkImage(supplier
                                                                .data()?[
                                                            'profileImageUrl'])
                                                        : const AssetImage(
                                                            'assets/images/ProfilePhoto_predetermined.png'),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'ID: $supplierId',
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      8.0),
                                                        ),
                                                        Text(
                                                          '${task.data()['supplierName']}',
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16),
                                                        ),
                                                        Text(
                                                          task.data()[
                                                              'service'],
                                                          style: const TextStyle(
                                                              fontSize: 14.0,
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic),
                                                        ),
                                                        Row(
                                                          children: [
                                                            const Icon(
                                                              Icons.star,
                                                              size: 16.0,
                                                              color: Color(
                                                                  0xFF1ca424),
                                                            ),
                                                            const SizedBox(
                                                                width: 4.0),
                                                            Text(
                                                              '${supplierInfo.data()?['assessment'] ?? 'Sin calificación'}',
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          12.0),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 16.0),
                                                    child: Column(
                                                      // Use a Column to stack the text widgets
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start, // Align text to the start
                                                      children: [
                                                        Text(
                                                          '${task.data()['state']}',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14.0,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Color(
                                                                0xFFE65100),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height:
                                                                1), // Add some space between the text widgets
                                                        Text(
                                                          // Formatea la fecha desde Timestamp a DD/MM/YYYY
                                                          task.data()['reservation'] !=
                                                                  null
                                                              ? DateFormat(
                                                                      'dd/MM/yyyy')
                                                                  .format((task.data()[
                                                                              'reservation']
                                                                          as Timestamp)
                                                                      .toDate())
                                                              : 'Sin fecha',
                                                          style:
                                                              const TextStyle(
                                                            fontSize:
                                                                10.0, // Smaller font size for the date
                                                            color: Color(
                                                                0xFF08143C),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      });
                                });
                          },
                        );
                      },
                    ),

              // Pestaña "Activas"
              _clientId == null
                  ? const Center(
                      child: CircularProgressIndicator(
                      color: Colors.green,
                    ))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('tasks')
                          .where('clientID', isEqualTo: _clientId)
                          .where('state', whereIn: [
                        'En proceso',
                        'Cotizando',
                        'Por pagar',
                        'Pagando'
                      ]).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                              child: Text('Error al obtener tareas'));
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                            color: Colors.green,
                          ));
                        }

                        final tasks = snapshot.data!.docs;
                        if (tasks.isEmpty) {
                          return const Center(
                              child: Text('No tienes tareas activas'));
                        }

                        return ListView.builder(
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            final supplierId = task.data()['supplierID'];

                            // Obtén la información del agente del usuario
                            return FutureBuilder<
                                    DocumentSnapshot<Map<String, dynamic>>>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(supplierId)
                                    .get(),
                                builder: (context, supplierSnapshot) {
                                  if (supplierSnapshot.hasError) {
                                    return const ListTile(
                                      title: Text(
                                          'Error al obtener información del agente'),
                                    );
                                  }
                                  if (supplierSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const ListTile(
                                      title: Center(
                                          child: CircularProgressIndicator(
                                        color: Colors.green,
                                      )),
                                    );
                                  }

                                  final supplier = supplierSnapshot.data;
                                  if (supplier == null) {
                                    return const ListTile(
                                      title: Text('Agente no encontrado'),
                                    );
                                  }

                                  // Obtén la información del proveedor
                                  return FutureBuilder<
                                          DocumentSnapshot<
                                              Map<String, dynamic>>>(
                                      future: FirebaseFirestore.instance
                                          .collection('suppliers')
                                          .doc(supplierId)
                                          .get(),
                                      builder: (context, supplierInfoSnapshot) {
                                        if (supplierInfoSnapshot.hasError) {
                                          return const ListTile(
                                            title: Text(
                                                'Error al obtener información del proveedor'),
                                          );
                                        }
                                        if (supplierInfoSnapshot
                                                .connectionState ==
                                            ConnectionState.waiting) {
                                          return const ListTile(
                                            title: Center(
                                                child:
                                                    CircularProgressIndicator(
                                              color: Colors.green,
                                            )),
                                          );
                                        }

                                        final supplierInfo =
                                            supplierInfoSnapshot.data;
                                        if (supplierInfo == null) {
                                          return const ListTile(
                                            title:
                                                Text('Proveedor no encontrado'),
                                          );
                                        }

                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    TaskDetailsScreen(
                                                  task: task,
                                                  supplier: supplier,
                                                  supplierInfo: supplierInfo,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                bottom:
                                                    0.0), // Añade espacio debajo
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              // Modifica la decoración para solo bordes arriba y abajo
                                              decoration: const BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                      color: Color(0xFF08143c),
                                                      width: 0.5),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 30,
                                                    backgroundImage: supplier
                                                                    .data()?[
                                                                'profileImageUrl'] !=
                                                            null
                                                        ? NetworkImage(supplier
                                                                .data()?[
                                                            'profileImageUrl'])
                                                        : const AssetImage(
                                                            'assets/images/ProfilePhoto_predetermined.png'),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'ID: $supplierId',
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      8.0),
                                                        ),
                                                        Text(
                                                          '${task.data()['supplierName']}',
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16),
                                                        ),
                                                        Text(
                                                          task.data()[
                                                              'service'],
                                                          style: const TextStyle(
                                                              fontSize: 14.0,
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic),
                                                        ),
                                                        Row(
                                                          children: [
                                                            const Icon(
                                                              Icons.star,
                                                              size: 16.0,
                                                              color: Color(
                                                                  0xFF1ca424),
                                                            ),
                                                            const SizedBox(
                                                                width: 4.0),
                                                            Text(
                                                              '${supplierInfo.data()?['assessment'] ?? 'Sin calificación'}',
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          12.0),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 16.0),
                                                    child: Column(
                                                      // Use a Column to stack the text widgets
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start, // Align text to the start
                                                      children: [
                                                        Text(
                                                          '${task.data()['state']}',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14.0,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.amber,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height:
                                                                1), // Add some space between the text widgets
                                                        Text(
                                                          // Formatea la fecha desde Timestamp a DD/MM/YYYY
                                                          task.data()['start'] !=
                                                                  null
                                                              ? DateFormat(
                                                                      'dd/MM/yyyy')
                                                                  .format((task.data()[
                                                                              'start']
                                                                          as Timestamp)
                                                                      .toDate())
                                                              : 'Sin fecha',
                                                          style:
                                                              const TextStyle(
                                                            fontSize:
                                                                10.0, // Smaller font size for the date
                                                            color: Color(
                                                                0xFF08143C),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      });
                                });
                          },
                        );
                      },
                    ),

              // Pestaña "Completadas"
              _clientId == null
                  ? const Center(
                      child: CircularProgressIndicator(
                      color: Colors.green,
                    ))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('tasks')
                          .where('clientID', isEqualTo: _clientId)
                          .where('state', isEqualTo: 'Finalizada')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                              child: Text('Error al obtener tareas'));
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                            color: Colors.green,
                          ));
                        }

                        final tasks = snapshot.data!.docs;
                        if (tasks.isEmpty) {
                          return const Center(
                              child: Text('No tienes tareas completadas'));
                        }

                        return ListView.builder(
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            final supplierId = task.data()['supplierID'];

                            // Obtén la información del agente del usuario
                            return FutureBuilder<
                                    DocumentSnapshot<Map<String, dynamic>>>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(supplierId)
                                    .get(),
                                builder: (context, supplierSnapshot) {
                                  if (supplierSnapshot.hasError) {
                                    return const ListTile(
                                      title: Text(
                                          'Error al obtener información del agente'),
                                    );
                                  }
                                  if (supplierSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const ListTile(
                                      title: Center(
                                          child: CircularProgressIndicator(
                                        color: Colors.green,
                                      )),
                                    );
                                  }

                                  final supplier = supplierSnapshot.data;
                                  if (supplier == null) {
                                    return const ListTile(
                                      title: Text('Agente no encontrado'),
                                    );
                                  }

                                  // Obtén la información del proveedor
                                  return FutureBuilder<
                                          DocumentSnapshot<
                                              Map<String, dynamic>>>(
                                      future: FirebaseFirestore.instance
                                          .collection('suppliers')
                                          .doc(supplierId)
                                          .get(),
                                      builder: (context, supplierInfoSnapshot) {
                                        if (supplierInfoSnapshot.hasError) {
                                          return const ListTile(
                                            title: Text(
                                                'Error al obtener información del proveedor'),
                                          );
                                        }
                                        if (supplierInfoSnapshot
                                                .connectionState ==
                                            ConnectionState.waiting) {
                                          return const ListTile(
                                            title: Center(
                                                child:
                                                    CircularProgressIndicator(
                                              color: Colors.green,
                                            )),
                                          );
                                        }

                                        final supplierInfo =
                                            supplierInfoSnapshot.data;
                                        if (supplierInfo == null) {
                                          return const ListTile(
                                            title:
                                                Text('Proveedor no encontrado'),
                                          );
                                        }

                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    TaskDetailsScreen(
                                                  task: task,
                                                  supplier: supplier,
                                                  supplierInfo: supplierInfo,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                bottom:
                                                    0.0), // Añade espacio debajo
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              // Modifica la decoración para solo bordes arriba y abajo
                                              decoration: const BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                      color: Color(0xFF08143c),
                                                      width: 0.5),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 30,
                                                    backgroundImage: supplier
                                                                    .data()?[
                                                                'profileImageUrl'] !=
                                                            null
                                                        ? NetworkImage(supplier
                                                                .data()?[
                                                            'profileImageUrl'])
                                                        : const AssetImage(
                                                            'assets/images/ProfilePhoto_predetermined.png'),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'ID: $supplierId',
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      8.0),
                                                        ),
                                                        Text(
                                                          '${task.data()['supplierName']}',
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16),
                                                        ),
                                                        Text(
                                                          task.data()[
                                                              'service'],
                                                          style: const TextStyle(
                                                              fontSize: 14.0,
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic),
                                                        ),
                                                        Row(
                                                          children: [
                                                            const Icon(
                                                              Icons.star,
                                                              size: 16.0,
                                                              color: Color(
                                                                  0xFF1ca424),
                                                            ),
                                                            const SizedBox(
                                                                width: 4.0),
                                                            Text(
                                                              '${supplierInfo.data()?['assessment'] ?? 'Sin calificación'}',
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          12.0),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 16.0),
                                                    child: Column(
                                                      // Use a Column to stack the text widgets
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start, // Align text to the start
                                                      children: [
                                                        Text(
                                                          '${task.data()['state']}',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14.0,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Color(
                                                                0xFF00C853),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height:
                                                                1), // Add some space between the text widgets
                                                        Text(
                                                          // Formatea la fecha desde Timestamp a DD/MM/YYYY
                                                          task.data()['end'] !=
                                                                  null
                                                              ? DateFormat(
                                                                      'dd/MM/yyyy')
                                                                  .format((task.data()[
                                                                              'end']
                                                                          as Timestamp)
                                                                      .toDate())
                                                              : 'Sin fecha',
                                                          style:
                                                              const TextStyle(
                                                            fontSize:
                                                                10.0, // Smaller font size for the date
                                                            color: Color(
                                                                0xFF08143C),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      });
                                });
                          },
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class TaskDetailsScreen extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> task;
  final DocumentSnapshot<Map<String, dynamic>>? supplier;
  final DocumentSnapshot<Map<String, dynamic>>? supplierInfo;

  const TaskDetailsScreen({
    super.key,
    required this.task,
    required this.supplier,
    required this.supplierInfo,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen>
    with SingleTickerProviderStateMixin {
  bool _showProfileImage = false;
  String? _selectedReason;
  final TextEditingController _otherReasonController = TextEditingController();
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _taskStream;
  final _messageController = TextEditingController();
  AnimationController? _animationController;
  Timer? _timer;
  DateTime? _startTime;
  bool _showCards = false;
  final Set _selectedCards = {};
  final bool _pagoMovilSelected = false;
  bool _efectivoSelected = false;
  bool _paypalSelected = false;
  bool _zinliSelected = false;
  bool _binanceSelected = false;

  // ignore: unused_field
  late Future _initFuture;
  late Future _cardsFuture;
  bool _hasCards = false;
  double _walletBalance = 0.0;
  String clientIDString = "";

  double _bcvExchangeRate = 1.0;
  bool _showPagoMovilDetails = false;
  File? _comprobante;

  String formatDateTime(Timestamp? dateTime) {
    if (dateTime == null) {
      return 'No disponible';
    }
    final convertedDateTime = dateTime.toDate();
    final formattedDate =
        "${convertedDateTime.day.toString().padLeft(2, '0')}/${convertedDateTime.month.toString().padLeft(2, '0')}/${convertedDateTime.year}";
    final formattedTime =
        '${convertedDateTime.hour % 12 == 0 ? 12 : convertedDateTime.hour % 12}:${convertedDateTime.minute.toString().padLeft(2, '0')} ${convertedDateTime.hour >= 12 ? 'PM' : 'AM'}';
    return "$formattedDate a las $formattedTime";
  }

  Future _showCancelConfirmationDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar cancelación'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('¿Por qué deseas cancelar la reservación?'),
                const SizedBox(height: 16),
                RadioListTile(
                  title: const Text('No deseo el servicio'),
                  value: 'No deseo el servicio',
                  groupValue: _selectedReason,
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                ),
                RadioListTile(
                  title: const Text('Demora en responder los mensajes'),
                  value: 'Demora en responder los mensajes',
                  groupValue: _selectedReason,
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                ),
                RadioListTile(
                  title: const Text('Muy costoso'),
                  value: 'Muy costoso',
                  groupValue: _selectedReason,
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                ),
                RadioListTile(
                  title: const Text('Fecha asignada muy lejana'),
                  value: 'Fecha asignada muy lejana',
                  groupValue: _selectedReason,
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                ),
                RadioListTile(
                  title:
                      const Text('No he recibido ninguna respuesta del agente'),
                  value: 'No he recibido ninguna respuesta del agente',
                  groupValue: _selectedReason,
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                ),
                RadioListTile(
                  title: const Text('El agente solicitó cancelar la reserva'),
                  value: 'El agente solicitó cancelar la reserva',
                  groupValue: _selectedReason,
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                ),
                RadioListTile(
                  title: const Text('Otro motivo'),
                  value: 'Otro motivo',
                  groupValue: _selectedReason,
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                ),
                if (_selectedReason == 'Otro motivo')
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: TextFormField(
                      controller: _otherReasonController,
                      decoration: const InputDecoration(
                        hintText: 'Describe el motivo de la cancelación',
                        border: OutlineInputBorder(),
                        hintMaxLines: 2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (_selectedReason != null) {
                  if (_selectedReason == 'Otro motivo' &&
                      _otherReasonController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Por favor, describe el motivo de la cancelación.',
                        ),
                      ),
                    );
                  } else {
                    _cancelReservation();
                    Navigator.of(context).pop();
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Por favor, selecciona un motivo para la cancelación.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  void _cancelReservation() async {
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .update({
        'state': 'Cancelada',
        'cancellationReason': _selectedReason,
        'cancellationDescription': _selectedReason == 'Otro motivo'
            ? _otherReasonController.text
            : null,
      });

      // ignore: use_build_context_synchronously
      Navigator.of(context).pop();
    } catch (e) {
      if (kDebugMode) {
        print('Error al cancelar la reservación: $e');
      }
    }
  }

  Future _initializeData() async {
    await _getUserInfo();
    await _getWalletBalance();
    _cardsFuture = _getCardsData();
    _hasCards = await _checkIfUserHasCards();
    _bcvExchangeRate = await getBCVExchangeRate();
  }

  Future _getUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        setState(() {
          clientIDString = doc['id'];
        });
      }
    }
  }

  Future _getWalletBalance() async {
    if (clientIDString.isNotEmpty) {
      final walletDoc = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(clientIDString)
          .get();

      if (walletDoc.exists) {
        final walletData = walletDoc.data() as Map<String, dynamic>;
        setState(() {
          _walletBalance = walletData['walletBalance'] ?? 0.0;
        });
      }
    }
  }

  Future _getCardsData() {
    return FirebaseFirestore.instance
        .collection('wallets')
        .doc(clientIDString)
        .collection('cards')
        .get();
  }

  Future _checkIfUserHasCards() async {
    final cardsSnapshot = await _cardsFuture;
    return cardsSnapshot.docs.isNotEmpty;
  }

  void _initializeStartTime() {
    final taskData = widget.task.data();
    if (taskData['state'] == 'En proceso') {
      _startTime = (taskData['start'] as Timestamp).toDate();
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  String _formatElapsedTime() {
    if (_startTime == null) return '00:00';
    final difference = DateTime.now().difference(_startTime!);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeData();
    _startTimer();
    _initializeStartTime();
    _selectedReason = null;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _taskStream = FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.task.id)
        .snapshots();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController?.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _handlePayPalPayment() async {
    final taskData = widget.task.data();
    final quotation = taskData['quotation'] as Map<String, dynamic>;
    final totalAmountUSD = quotation['totalAmountUSD'] as double;

    final amountToPayWithPayPal = totalAmountUSD - _walletBalance;

    if (amountToPayWithPayPal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'El saldo del monedero es suficiente para cubrir el costo total.')),
      );
      return;
    }

    bool paymentSuccess = false;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) => UsePaypal(
          sandboxMode: false,
          clientId:
              "AdfwCuiRLwAVHmAtVZed11lO8eXlFw4uUyBxrlwIR3OXUwZDm6l_PgPa9Wji20E7hXYFW4JfyaDdcabi",
          secretKey:
              "EA-2R8sv5qXqOEHxFxS7znBg30OrOhVL-nolsCR-ZVSH6P25wLARZ_kSw_uCAs2rSK4TkkcN_u6h70xv",
          returnURL: "https://samplesite.com/return",
          cancelURL: "https://samplesite.com/cancel",
          transactions: [
            {
              "amount": {
                "total": amountToPayWithPayPal.toStringAsFixed(2),
                "currency": "USD",
                "details": {
                  "subtotal": amountToPayWithPayPal.toStringAsFixed(2),
                  "shipping": '0',
                  "shipping_discount": 0
                }
              },
              "description": "Pago por servicio",
              "item_list": {
                "items": [
                  {
                    "name": "Servicio",
                    "quantity": 1,
                    "price": amountToPayWithPayPal.toStringAsFixed(2),
                    "currency": "USD"
                  }
                ],
              }
            }
          ],
          note: "Contactanos para cualquier duda sobre tu pedido.",
          onSuccess: (Map params) async {
            if (kDebugMode) {
              print("onSuccess: $params");
            }

            await FirebaseFirestore.instance
                .collection('wallets')
                .doc(taskData['supplierID'])
                .update(
                    {'walletBalance': FieldValue.increment(totalAmountUSD)});

            if (_walletBalance > 0) {
              await FirebaseFirestore.instance
                  .collection('wallets')
                  .doc(clientIDString)
                  .update(
                      {'walletBalance': FieldValue.increment(-_walletBalance)});
            }

            final transactionData = {
              'senderName': taskData['clientName'],
              'senderId': taskData['clientID'],
              'recipientName': taskData['supplierName'],
              'recipientId': taskData['supplierID'],
              'paymentType': 'Pago de servicio',
              'date': FieldValue.serverTimestamp(),
              'amount': totalAmountUSD,
              'paymentMethod': _walletBalance > 0
                  ? {
                      'Monedero': {'amount': _walletBalance},
                      'Paypal': {
                        'amount': amountToPayWithPayPal,
                        'transactionId': params['paymentId']
                      }
                    }
                  : {
                      'Paypal': {
                        'amount': amountToPayWithPayPal,
                        'transactionId': params['paymentId']
                      }
                    },
              'taskId': widget.task.id,
              'service': taskData['service'],
            };

            final transactionRef = await FirebaseFirestore.instance
                .collection('transactions')
                .add(transactionData);

            await FirebaseFirestore.instance
                .collection('tasks')
                .doc(widget.task.id)
                .update({'transactionID': transactionRef.id});

            paymentSuccess = true;
            // ignore: use_build_context_synchronously
            Navigator.of(context).pop();

            await FirebaseFirestore.instance
                .collection('tasks')
                .doc(widget.task.id)
                .update({'state': 'Finalizada'});
                
          },
          onError: (error) {
            if (kDebugMode) {
              print("onError: $error");
            }
            paymentSuccess = false;
            Navigator.of(context).pop();
          },
          onCancel: (params) {
            if (kDebugMode) {
              print('cancelled: $params');
            }
            paymentSuccess = false;
            Navigator.of(context).pop();
          },
        ),
      ),
    );

    if (paymentSuccess) {
      final taskDoc = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .get();
      final updatedTaskData = taskDoc.data() as Map<String, dynamic>;
      // ignore: use_build_context_synchronously

      // ignore: use_build_context_synchronously
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TransactionReceiptScreen(
            paymentType: 'Pago de servicio',
            date: DateTime.now(),
            transactionId: updatedTaskData['transactionID'],
            concept: taskData['service'],
            recipientId: taskData['supplierID'],
            recipientName: taskData['supplierName'],
            amount: totalAmountUSD,
            onBackPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => TaskDetailsScreen(
                    task: widget.task,
                    supplier: widget.supplier,
                    supplierInfo: widget.supplierInfo,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  Future<double> getBCVExchangeRate() async {
    try {
      final response = await http.get(Uri.parse('https://www.bcv.org.ve/'));
      if (response.statusCode == 200) {
        final document = parse(response.body);
        final dollarRate = document.querySelector('#dolar .centrado')?.text;
        if (dollarRate != null) {
          return double.parse(dollarRate.replaceAll(',', '.'));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener el tipo de cambio: $e');
      }
    }
    return 1.0;
  }

  void _togglePagoMovilDetails() {
    setState(() {
      _showPagoMovilDetails = !_showPagoMovilDetails;
    });
    if (_showPagoMovilDetails) {
      _animationController?.forward();
    } else {
      _animationController?.reverse();
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _comprobante = File(pickedFile.path);
      });
      _uploadComprobante();
    }
  }

  Future<void> _uploadComprobante() async {
    if (_comprobante == null) return;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('comprobantes')
          .child('${widget.task.id}.jpg');
      await ref.putFile(_comprobante!);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .update({'comprobanteURL': url});

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comprobante subido exitosamente')),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al subir el comprobante')),
      );
    }
  }

  void _deleteComprobante() async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('comprobantes')
          .child('${widget.task.id}.jpg');
      await ref.delete();

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .update({'comprobanteURL': FieldValue.delete()});

      setState(() {
        _comprobante = null;
      });

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comprobante eliminado exitosamente')),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al eliminar el comprobante')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[50],
        title: const Text(
          'Información',
          style: TextStyle(color: Colors.black, fontSize: 20),
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: const Color(0xFF08143C),
                width: 1.0,
              ),
              color: Colors.white.withOpacity(0.5),
            ),
            child: Row(
              children: [
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _taskStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final taskData = snapshot.data!.data();
                      return Text(
                        '${taskData?['state']}',
                        style: const TextStyle(fontSize: 16),
                      );
                    } else {
                      return const Text(
                        'Cargando...',
                        style: TextStyle(fontSize: 16),
                      );
                    }
                  },
                ),
                const SizedBox(width: 3),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _taskStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final taskData = snapshot.data!.data();
                      return getColoredIcon(taskData?['state']);
                    } else {
                      return const Icon(Icons.circle);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
        elevation: 0, // Elimina la sombra de la barra de título
      ),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _taskStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final taskData = snapshot.data!.data();
                  // Actualizar el tiempo de inicio si cambia el estado de la tarea
                  if (taskData?['state'] == 'En proceso' &&
                      _startTime == null) {
                    _startTime = (taskData?['start'] as Timestamp).toDate();
                    _startTimer();
                  } else if (taskData?['state'] != 'En proceso') {
                    _startTime = null;
                    _timer?.cancel();
                  }

                  // Contenido principal
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 23.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CircleAvatar con la foto de perfil y marco
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showProfileImage = true;
                              });
                            },
                            child: Hero(
                              tag: 'profileImage',
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.green,
                                    width: 3.0,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundImage: widget.supplier
                                              ?.data()?['profileImageUrl'] !=
                                          null
                                      ? NetworkImage(widget.supplier
                                          ?.data()?['profileImageUrl'])
                                      : const AssetImage(
                                          'assets/images/ProfilePhoto_predetermined.png'),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${taskData?['supplierName']}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'ID: ${widget.supplier?.id}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2.0,
                                          horizontal: 5.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[900],
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          border: Border.all(
                                            color: const Color(0xFF08143C),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              size: 14.0,
                                              color: Colors.yellow,
                                            ),
                                            const SizedBox(width: 4.0),
                                            Text(
                                              '${widget.supplierInfo?.data()?['assessment'] ?? 'Sin calificación'}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (taskData?['state'] == 'En proceso')
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF08143C),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Tiempo transcurrido',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        const Icon(Icons.access_time,
                                            size: 16,
                                            color: Color.fromARGB(
                                                255, 30, 145, 38)),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatElapsedTime(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            if (widget.task.data()['state'] == 'Finalizada')
                              Align(
                                alignment: Alignment.bottomRight,
                                child: SizedBox(
                                  height: 35, // Define la altura del botón
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF08143C),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical:
                                            4, // Reduce el padding vertical
                                      ),
                                      textStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize:
                                            12, // Reduce el tamaño de la fuente
                                        fontWeight: FontWeight.bold,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10.0),
                                      ),
                                    ),
                                    onPressed: () {
                                      // Implementar acción del botón "Seguir"
                                    },
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "+",
                                          style: TextStyle(
                                              fontSize: 20.0,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF00C853)),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Seguir',
                                          style: TextStyle(
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF00C853)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Sección de detalles de la tarea
                        Card(
                          color: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          shadowColor: const Color(0xFF08143C),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 10.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Servicio seleccionado
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4.0),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(5.0),
                                        color: Colors.blueGrey[600],
                                      ),
                                      child: const Icon(Icons.shopping_cart,
                                          size: 18.0,
                                          color:
                                              Color.fromRGBO(255, 204, 128, 1)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Servicio: ${widget.task.data()['service']}',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Detalles del servicio
                                if (taskData?['state'] == 'Pendiente' ||
                                    taskData?['state'] == 'En proceso' ||
                                    taskData?['state'] == 'Cotizando' ||
                                    taskData?['state'] == 'Finalizada')
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4.0),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(5.0),
                                          color: Colors.blueGrey[600],
                                        ),
                                        child: const Icon(
                                          Icons.description,
                                          size: 18.0,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '${taskData?['serviceDetails']}',
                                          style: const TextStyle(fontSize: 16),
                                          softWrap: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 10),
                                // Tarifa por hora del agente
                                Card(
                                  color: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15)),
                                  shadowColor: Colors.green,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10.0),
                                      color: Colors.green[100],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Tarifa por hora',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.all(4.0),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(5.0),
                                                color: Colors.blueGrey[600],
                                              ),
                                              child: const Icon(
                                                Icons.attach_money,
                                                size: 18.0,
                                                color: Colors.greenAccent,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                '${widget.task.data()['hourlyRate'].toStringAsFixed(2)}/hr',
                                                style: const TextStyle(
                                                    fontSize: 16),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.all(4.0),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(5.0),
                                                color: Colors.blueGrey[600],
                                              ),
                                              child: const Icon(
                                                Icons.payment,
                                                size: 18.0,
                                                color: Colors.tealAccent,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'Métodos de pago: ${widget.task.data()['paymentMethods']?.join(', ') ?? 'No disponible'}',
                                                style: const TextStyle(
                                                    fontSize: 16),
                                              ),
                                            ),
                                            if (widget.task
                                                    .data()['paymentMethods']
                                                    ?.contains('Tarjetas') ==
                                                true)
                                              // Número de tarjeta
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            4.0),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              5.0),
                                                      color:
                                                          Colors.blueGrey[600],
                                                    ),
                                                    child: const Icon(
                                                      Icons.credit_card,
                                                      size: 18.0,
                                                      color: Colors.tealAccent,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      'Tarjeta: ${widget.task.data()['selectedCards']?.join(', ') ?? 'No disponible'}',
                                                      style: const TextStyle(
                                                          fontSize: 16),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        const Text(
                                          'Nota: El monto final a pagar puede variar durante la ejecución del servicio.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),

                                if (taskData?['state'] == 'Por pagar' ||
                                    taskData?['state'] == 'Pagando')
                                  // Cotización
                                  Card(
                                    color: Colors.blue[50],
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(15)),
                                    shadowColor: const Color(0xFF08143C),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Cotización',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 16),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12.0),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF08143C),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Icon(Icons.access_time,
                                                      size: 20,
                                                      color: Colors.blue[100]),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'Tiempo transcurrido',
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        color:
                                                            Colors.grey[600]),
                                                  ),
                                                ),
                                                Text(
                                                  '${taskData?['quotation']['hoursWorked']}h ${taskData?['quotation']['minutesWorked']}m',
                                                  style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (taskData?['quotation']
                                                  ['damageAmount'] !=
                                              null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 12.0),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFF08143C),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Icon(Icons.warning,
                                                        size: 20,
                                                        color:
                                                            Colors.blue[100]),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      'Daños materiales',
                                                      style: TextStyle(
                                                          fontSize: 16,
                                                          color:
                                                              Colors.grey[600]),
                                                    ),
                                                  ),
                                                  Text(
                                                    '- \$${taskData?['quotation']['damageAmount'].toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.black),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (taskData?['quotation']
                                                  ['materialsAmount'] !=
                                              null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 12.0),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFF08143C),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Icon(
                                                        Icons.shopping_cart,
                                                        size: 20,
                                                        color:
                                                            Colors.blue[100]),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      'Otros gastos',
                                                      style: TextStyle(
                                                          fontSize: 16,
                                                          color:
                                                              Colors.grey[600]),
                                                    ),
                                                  ),
                                                  Text(
                                                    '\$${taskData?['quotation']['materialsAmount'].toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.black),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (taskData?['quotation']
                                                  ['additionalObservation'] !=
                                              null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 12.0),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFF08143C),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Icon(Icons.note,
                                                        size: 20,
                                                        color:
                                                            Colors.blue[100]),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      'Observación',
                                                      style: TextStyle(
                                                          fontSize: 16,
                                                          color:
                                                              Colors.grey[600]),
                                                    ),
                                                  ),
                                                  Text(
                                                    '${taskData?['quotation']['additionalObservation']}',
                                                    style: const TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.black),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const Divider(height: 32),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12.0),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF1ca424),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: const Text(
                                                    'USD',
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'Total en dólares',
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        color:
                                                            Colors.grey[600]),
                                                  ),
                                                ),
                                                Text(
                                                  '\$${taskData?['quotation']['totalAmountUSD'].toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color.fromRGBO(
                                                          13, 71, 161, 1)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12.0),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF1ca424),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: const Text(
                                                    'Bs',
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'Total en bolívares',
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        color:
                                                            Colors.grey[600]),
                                                  ),
                                                ),
                                                Text(
                                                  '${taskData?['quotation']['totalAmountBs'].toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (taskData?['state'] == 'Cotizando')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                        Colors.blue[300]!,
                                        Colors.blue[800]!
                                      ]),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.pending_actions,
                                            color: Colors.white),
                                        SizedBox(width: 12),
                                        Text(
                                          'Esperando la cotización del agente',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 10),

                                if (taskData?['state'] == 'Pagando')
                                  Card(
                                    color: Colors.white,
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: const BorderSide(
                                        color: Color(0xFF08143C),
                                      ),
                                    ),
                                    shadowColor: const Color(0xFF08143C),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Métodos de pago disponibles',
                                            style: TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Text(
                                            'Los pagos se realizan al finalizar el servicio',
                                            style: TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 15),
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0F4FF),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                  'Saldo disponible',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF08143C),
                                                  ),
                                                ),
                                                Text(
                                                  '\$${_walletBalance.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1ca424),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 15),
                                          if (_hasCards)
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _showCards = !_showCards;
                                                  });
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: _showCards
                                                      ? Colors.green[100]
                                                      : Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      vertical: 12,
                                                      horizontal: 15),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    side: BorderSide(
                                                      color: _showCards
                                                          ? const Color(
                                                              0xFF1ca424)
                                                          : const Color(
                                                              0xFF08143C),
                                                    ),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    const Text('Tarjetas'),
                                                    Row(
                                                      children: [
                                                        Image.asset(
                                                          'assets/images/VISA_Logo.png',
                                                          height: 20,
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Image.asset(
                                                          'assets/images/MasterCard_Logo.png',
                                                          height: 20,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          if (_showCards)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  top: 10),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: FutureBuilder(
                                                future: _cardsFuture,
                                                builder:
                                                    (context, cardsSnapshot) {
                                                  if (cardsSnapshot
                                                          .connectionState ==
                                                      ConnectionState.waiting) {
                                                    return const CircularProgressIndicator(
                                                        color: Colors.green);
                                                  }
                                                  if (cardsSnapshot.hasError) {
                                                    return Text(
                                                        'Error: ${cardsSnapshot.error}');
                                                  }
                                                  if (!cardsSnapshot.hasData ||
                                                      cardsSnapshot
                                                          .data!.docs.isEmpty) {
                                                    return const Text(
                                                        'No hay tarjetas disponibles');
                                                  }

                                                  return Column(
                                                    children: cardsSnapshot
                                                        .data!.docs
                                                        .map((card) {
                                                      final cardData =
                                                          card.data() as Map<
                                                              String, dynamic>;
                                                      final cardNumber = cardData[
                                                              'cardNumber'] ??
                                                          '';
                                                      final cardType = cardData[
                                                              'cardType'] ??
                                                          '';
                                                      final imagePath = cardType ==
                                                              'Visa'
                                                          ? 'assets/images/VISA_Logo.png'
                                                          : 'assets/images/MasterCard_Logo.png';

                                                      return CheckboxListTile(
                                                        title: Row(
                                                          children: [
                                                            Text(
                                                              cardNumber,
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          13),
                                                            ),
                                                            const SizedBox(
                                                                width: 10),
                                                            Image.asset(
                                                              imagePath,
                                                              height: 20,
                                                            ),
                                                          ],
                                                        ),
                                                        value: _selectedCards
                                                            .contains(card.id),
                                                        onChanged:
                                                            (bool? value) {
                                                          setState(() {
                                                            if (value == true) {
                                                              _selectedCards
                                                                  .add(card.id);
                                                            } else {
                                                              _selectedCards
                                                                  .remove(
                                                                      card.id);
                                                            }
                                                          });
                                                        },
                                                      );
                                                    }).toList(),
                                                  );
                                                },
                                              ),
                                            ),
                                          const SizedBox(height: 15),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  icon: const Icon(
                                                      Icons.phone_android,
                                                      color: Colors.black),
                                                  label: const Text(
                                                    'Pago Móvil',
                                                    style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 13),
                                                  ),
                                                  onPressed:
                                                      _togglePagoMovilDetails,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        _pagoMovilSelected
                                                            ? Colors.green[100]
                                                            : Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      side: BorderSide(
                                                        color:
                                                            _pagoMovilSelected
                                                                ? const Color(
                                                                    0xFF1ca424)
                                                                : const Color(
                                                                    0xFF08143C),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  icon: const Icon(
                                                      Icons
                                                          .attach_money_rounded,
                                                      color: Colors.green),
                                                  label: const Text(
                                                    'Efectivo',
                                                    style: TextStyle(
                                                        color: Colors.green),
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _efectivoSelected =
                                                          !_efectivoSelected;
                                                    });
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        _efectivoSelected
                                                            ? Colors.green[100]
                                                            : Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      side: BorderSide(
                                                        color: _efectivoSelected
                                                            ? const Color(
                                                                0xFF1ca424)
                                                            : const Color(
                                                                0xFF08143C),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (_efectivoSelected)
                                            const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Text(
                                                'Advertencia: Si el agente no tiene cambio, el monto restante será añadido a su monedero instantáneamente.',
                                                style: TextStyle(
                                                  color: Color.fromARGB(
                                                      255, 250, 96, 85),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 15),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _paypalSelected =
                                                          !_paypalSelected;
                                                    });
                                                    if (_paypalSelected) {
                                                      _handlePayPalPayment();
                                                    }
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        _paypalSelected
                                                            ? Colors.green[100]
                                                            : Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      side: BorderSide(
                                                        color: _paypalSelected
                                                            ? const Color(
                                                                0xFF1ca424)
                                                            : const Color(
                                                                0xFF08143C),
                                                      ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12.0),
                                                  ),
                                                  child: FittedBox(
                                                    child: Image.asset(
                                                      'assets/images/Paypal_Logo.png',
                                                      height: 50,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _zinliSelected =
                                                          !_zinliSelected;
                                                    });
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        _zinliSelected
                                                            ? Colors.green[100]
                                                            : Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      side: BorderSide(
                                                        color: _zinliSelected
                                                            ? const Color(
                                                                0xFF1ca424)
                                                            : const Color(
                                                                0xFF08143C),
                                                      ),
                                                    ),
                                                  ),
                                                  child: FittedBox(
                                                    child: Image.asset(
                                                      'assets/images/Zinli_Logo.png',
                                                      height: 40,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _binanceSelected =
                                                          !_binanceSelected;
                                                    });
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        _binanceSelected
                                                            ? Colors.green[100]
                                                            : Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      side: BorderSide(
                                                        color: _binanceSelected
                                                            ? const Color(
                                                                0xFF1ca424)
                                                            : const Color(
                                                                0xFF08143C),
                                                      ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                            11.0),
                                                  ),
                                                  child: FittedBox(
                                                    child: Image.asset(
                                                      'assets/images/Binance_Logo.png',
                                                      height: 50,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 500),
                                            height: _showPagoMovilDetails
                                                ? null
                                                : 0,
                                            child: AnimatedOpacity(
                                              duration: const Duration(
                                                  milliseconds: 500),
                                              opacity: _showPagoMovilDetails
                                                  ? 1.0
                                                  : 0.0,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const SizedBox(height: 20),
                                                  Text(
                                                    'Monto a pagar:',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blue[800],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Bs. ${(((taskData?['quotation']['totalAmountUSD'] as double) - _walletBalance) * _bcvExchangeRate).toStringAsFixed(2)}',
                                                        style: const TextStyle(
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.green,
                                                        ),
                                                      ),
                                                      Text(
                                                        '\$${((taskData?['quotation']['totalAmountUSD'] as double) - _walletBalance).toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Text(
                                                    'Datos para Pago Móvil:',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blue[800],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Card(
                                                    elevation: 2,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              16.0),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              const Icon(
                                                                  Icons
                                                                      .account_balance,
                                                                  color: Colors
                                                                      .blue),
                                                              const SizedBox(
                                                                  width: 10),
                                                              Text(
                                                                'Banco: ${widget.supplierInfo?['mobilePayment'][0]['bank'] ?? 'N/A'}',
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            16),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              height: 10),
                                                          Row(
                                                            children: [
                                                              const Icon(
                                                                  Icons
                                                                      .perm_identity,
                                                                  color: Colors
                                                                      .blue),
                                                              const SizedBox(
                                                                  width: 10),
                                                              Text(
                                                                'Cédula: ${widget.supplierInfo?['mobilePayment'][0]['identification'] ?? 'N/A'}',
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            16),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              height: 10),
                                                          Row(
                                                            children: [
                                                              const Icon(
                                                                  Icons.phone,
                                                                  color: Colors
                                                                      .blue),
                                                              const SizedBox(
                                                                  width: 10),
                                                              Text(
                                                                'Teléfono: ${widget.supplierInfo?['mobilePayment'][0]['phone'] ?? 'N/A'}',
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            16),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  ElevatedButton(
                                                    onPressed: _pickImage,
                                                    child: const Text(
                                                        'Subir comprobante de pago'),
                                                  ),
                                                  if (_comprobante != null)
                                                    Column(
                                                      children: [
                                                        const SizedBox(
                                                            height: 10),
                                                        Image.file(
                                                            _comprobante!),
                                                        ElevatedButton(
                                                          onPressed:
                                                              _deleteComprobante,
                                                          child: const Text(
                                                              'Eliminar comprobante'),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 10),

                                // Reservado
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4.0),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(5.0),
                                        color: Colors.blueGrey[600],
                                      ),
                                      child: const Icon(
                                        Icons.calendar_today,
                                        size: 18.0,
                                        color: Color.fromRGBO(209, 196, 233, 1),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Reservado: ${formatDateTime(widget.task.data()['reservation'] as Timestamp?)}',
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Inicio
                                if (taskData?['state'] == 'En proceso' ||
                                    taskData?['state'] == 'Cotizando' ||
                                    taskData?['state'] == 'Por pagar' ||
                                    taskData?['state'] == 'Pagando' ||
                                    taskData?['state'] == 'Finalizada')
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4.0),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(5.0),
                                          color: Colors.blueGrey[600],
                                        ),
                                        child: const Icon(
                                          Icons.play_circle_outline_rounded,
                                          size: 18.0,
                                          color:
                                              Color.fromRGBO(128, 216, 255, 1),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Inicio: ${formatDateTime(widget.task.data()['start'] as Timestamp?)}',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 10),
                                // Finalización
                                if (taskData?['state'] == 'Cotizando' ||
                                    taskData?['state'] == 'Por pagar' ||
                                    taskData?['state'] == 'Pagando' ||
                                    taskData?['state'] == 'Finalizada')
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4.0),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(5.0),
                                          color: Colors.blueGrey[600],
                                        ),
                                        child: const Icon(
                                          Icons.stop_circle,
                                          size: 18.0,
                                          color:
                                              Color.fromRGBO(248, 187, 208, 1),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Finalización: ${formatDateTime(widget.task.data()['end'] as Timestamp?)}',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 10),

                                // Punto de referencia
                                if (taskData?['state'] == 'Pendiente' ||
                                    taskData?['state'] == 'En proceso' ||
                                    taskData?['state'] == 'Finalizada')
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4.0),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(5.0),
                                          color: Colors.blueGrey[600],
                                        ),
                                        child: const Icon(
                                          Icons.location_pin,
                                          size: 18.0,
                                          color:
                                              Color.fromRGBO(255, 138, 128, 1),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Punto de referencia: ${widget.task.data()['referencePoint'] ?? 'No disponible'}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 10),
                                // Comentario del cliente (solo para tareas completadas)
                                if (taskData?['state'] == 'Finalizada')
                                  Card(
                                    color: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(15)),
                                    shadowColor: const Color(0xFF08143C),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius:
                                            BorderRadius.circular(10.0),
                                        border: Border.all(
                                          color: const Color(0xFF08143C),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Text(
                                                'Calificación obtenida',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10.0),
                                              border: Border.all(
                                                color: const Color(0xFF08143C),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.comment,
                                                  size: 18.0,
                                                  color: Color(0xFF08143C),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    '${taskData?['clientComment'] ?? 'No disponible'}',
                                                    style: const TextStyle(
                                                        fontSize: 16),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                size: 18.0,
                                                color: Color(0xFF1ca424),
                                              ),
                                              const SizedBox(width: 4.0),
                                              Text(
                                                '${taskData?['clientEvaluation'] ?? 'No disponible'}',
                                                style: const TextStyle(
                                                    fontSize: 16),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 20),
                                // Ubicación del servicio
                                if (taskData?['clientLocation'] != null)
                                  if (taskData?['state'] == 'Pendiente' ||
                                      taskData?['state'] == 'En proceso' ||
                                      taskData?['state'] == 'Finalizada')
                                    Column(
                                      children: [
                                        const Text(
                                          'Ubicación del servicio:',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 10),
                                        Card(
                                          color: Colors.white,
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15)),
                                          shadowColor: const Color(0xFF08143C),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10.0),
                                              border: Border.all(
                                                color: const Color(0xFF08143C),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: SizedBox(
                                              height:
                                                  200, // Ajusta la altura del mapa
                                              child: ClientLocationMap(
                                                clientLatLng: LatLng(
                                                  widget.task
                                                      .data()['clientLocation']
                                                      .latitude,
                                                  widget.task
                                                      .data()['clientLocation']
                                                      .longitude,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              ],
                            ),
                          ),
                        ),
                        // Botón "Cancelar reservación" (solo si el estado es "Pendiente")
                        if (taskData?['state'] == 'Pendiente')
                          Padding(
                            padding: const EdgeInsets.only(top: 20.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  textStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    side: const BorderSide(
                                        color: Colors.red, width: 1.0),
                                  ),
                                ),
                                onPressed: _showCancelConfirmationDialog,
                                child: const Text(
                                  'Cancelar reservación',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        if (taskData?['state'] == 'Por pagar')
                          Padding(
                            padding: const EdgeInsets.only(top: 20.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.green,
                                      Color.fromRGBO(27, 94, 32, 1)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    textStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                  ),
                                  onPressed: () {
                                    // Cambiamos el estado a "Pagando"
                                    FirebaseFirestore.instance
                                        .collection('tasks')
                                        .doc(widget.task.id)
                                        .update({
                                      'state': 'Pagando',
                                    });
                                  },
                                  child: const Text(
                                    'Pagar servicio',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.green,
                    ),
                  );
                }
              },
            ),
            // Ampliación de la imagen de perfil
            if (_showProfileImage)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showProfileImage = false;
                  });
                },
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Hero(
                      tag: 'profileImage',
                      child: CircleAvatar(
                        radius: 175,
                        backgroundImage: widget.supplier
                                    ?.data()?['profileImageUrl'] !=
                                null
                            ? NetworkImage(
                                widget.supplier?.data()?['profileImageUrl'])
                            : const AssetImage(
                                'assets/images/ProfilePhoto_predetermined.png'),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Icon getColoredIcon(String state) {
  switch (state) {
    case 'Pendiente':
      return const Icon(
        Icons.circle,
        size: 18.0,
        color: Color.fromRGBO(230, 81, 0, 1),
      );
    case 'En proceso':
      return const Icon(
        Icons.circle,
        size: 18.0,
        color: Colors.amber,
      );
    case 'Finalizada':
      return const Icon(
        Icons.circle,
        size: 18.0,
        color: Color.fromRGBO(0, 200, 83, 1),
      );
    case 'Cancelada':
      return const Icon(
        Icons.circle,
        size: 18.0,
        color: Colors.grey,
      );
    default:
      return const Icon(Icons.circle);
  }
}

// Widget para mostrar el mapa con la ubicación del cliente
class ClientLocationMap extends StatelessWidget {
  final LatLng clientLatLng;

  const ClientLocationMap({super.key, required this.clientLatLng});

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        center: clientLatLng,
        zoom: 15,
        interactiveFlags: InteractiveFlag.all,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
        ),
        MarkerLayer(
          markers: [
            Marker(
              width: 80,
              height: 80,
              point: clientLatLng,
              builder: (ctx) => const Icon(
                Icons.location_pin,
                color: Colors.red,
                size: 40,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
