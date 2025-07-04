import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
// ignore: unnecessary_import
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:mobileservicesapp/screens/public/homepage.dart';
import 'package:mobileservicesapp/screens/public/social.dart';
import 'package:one_context/one_context.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:mobileservicesapp/integrations/coins.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  // Obtiene el UID del usuario actual
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userId;
  String? _clientId;

  @override
  void initState() {
    super.initState();
    _fetchClientId();
  }

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

  // Función para obtener la evaluación promedio del proveedor
  Future<double> _getAverageSupplierEvaluation(String supplierId) async {
    QuerySnapshot<Map<String, dynamic>> tasksSnapshot =
        await FirebaseFirestore.instance.collection('tasks').get();

    double totalEvaluation = 0;
    int evaluationCount = 0;

    for (var taskDoc in tasksSnapshot.docs) {
      if (taskDoc.data()['supplierID'] == supplierId &&
          taskDoc.data()['clientEvaluation'] != null) {
        totalEvaluation +=
            double.tryParse(taskDoc.data()['clientEvaluation'].toString()) ??
                0.0;
        evaluationCount++;
      }
    }

    if (evaluationCount == 0) {
      return 0.0;
    } else {
      return totalEvaluation / evaluationCount;
    }
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
                      child: CupertinoActivityIndicator(
                      radius: 16,
                      color: Colors.green,
                    ))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('tasks')
                          .where('clientID', isEqualTo: _clientId)
                          .where('state', whereIn: [
                        'Pendiente',
                        'Agendado',
                      ]).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                              child: Text('Error al obtener tareas'));
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CupertinoActivityIndicator(
                            radius: 16,
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
                                          child: CupertinoActivityIndicator(
                                        radius: 16,
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
                                          .collection('users')
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
                                                    CupertinoActivityIndicator(
                                              radius: 16,
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

                                        // Obtén la evaluación promedio del proveedor
                                        return FutureBuilder<double>(
                                          future: _getAverageSupplierEvaluation(
                                              supplierId),
                                          builder: (context,
                                              averageEvaluationSnapshot) {
                                            if (averageEvaluationSnapshot
                                                    .connectionState ==
                                                ConnectionState.waiting) {
                                              return const ListTile(
                                                title: Center(
                                                    child:
                                                        CupertinoActivityIndicator(
                                                  radius: 16,
                                                  color: Colors.green,
                                                )),
                                              );
                                            }

                                            double averageEvaluation =
                                                averageEvaluationSnapshot
                                                        .data ??
                                                    0.0;

                                            return GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        TaskDetailsScreen(
                                                      task: task,
                                                      supplier: supplier,
                                                      supplierInfo:
                                                          supplierInfo,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom:
                                                        0.0), // Añade espacio debajo
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  // Modifica la decoración para solo bordes arriba y abajo
                                                  decoration:
                                                      const BoxDecoration(
                                                    border: Border(
                                                      bottom: BorderSide(
                                                          color:
                                                              Color(0xFF08143c),
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
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16),
                                                            ),
                                                            Text(
                                                              task.data()[
                                                                  'service'],
                                                              style: const TextStyle(
                                                                  fontSize:
                                                                      14.0,
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
                                                                  // Muestra la evaluación promedio
                                                                  averageEvaluation
                                                                      .toStringAsFixed(
                                                                          1),
                                                                  style: const TextStyle(
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
                                                            const EdgeInsets
                                                                .only(
                                                                left: 16.0),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Text(
                                                              '${task.data()['state']}',
                                                              style: TextStyle(
                                                                fontSize: 14.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: task.data()[
                                                                            'state'] ==
                                                                        'Pendiente'
                                                                    ? const Color(
                                                                        0xFFE65100) // Red for Pendiente
                                                                    : Colors
                                                                        .amber, // LightGreen for Agendado
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 1),
                                                            Text(
                                                              task.data()['state'] ==
                                                                      'Pendiente'
                                                                  ? // Display reservation date if state is 'Pendiente'
                                                                  task.data()['reservation'] !=
                                                                          null
                                                                      ? DateFormat(
                                                                              'dd/MM/yyyy')
                                                                          .format((task.data()['reservation'] as Timestamp)
                                                                              .toDate())
                                                                      : 'Sin fecha'
                                                                  : // Display scheduled date if state is 'Agendado'
                                                                  task.data()['scheduled'] !=
                                                                          null
                                                                      ? DateFormat(
                                                                              'dd/MM/yyyy')
                                                                          .format(
                                                                              (task.data()['scheduled'] as Timestamp).toDate())
                                                                      : 'Sin fecha',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 10.0,
                                                                color: Color(
                                                                    0xFF08143C),
                                                              ),
                                                            ),
                                                            // Show time below the date
                                                            if (task.data()[
                                                                    'scheduled'] !=
                                                                null)
                                                              Text(
                                                                DateFormat(
                                                                        'hh:mm a') // Show time with AM/PM
                                                                    .format((task.data()['scheduled']
                                                                            as Timestamp)
                                                                        .toDate()),
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize:
                                                                      10.0,
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
                                          },
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
                      child: CupertinoActivityIndicator(
                      radius: 16,
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
                              child: CupertinoActivityIndicator(
                            radius: 16,
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
                                          child: CupertinoActivityIndicator(
                                        radius: 16,
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
                                          .collection('users')
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
                                                    CupertinoActivityIndicator(
                                              radius: 16,
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

                                        // Obtén la evaluación promedio del proveedor
                                        return FutureBuilder<double>(
                                          future: _getAverageSupplierEvaluation(
                                              supplierId),
                                          builder: (context,
                                              averageEvaluationSnapshot) {
                                            if (averageEvaluationSnapshot
                                                    .connectionState ==
                                                ConnectionState.waiting) {
                                              return const ListTile(
                                                title: Center(
                                                    child:
                                                        CupertinoActivityIndicator(
                                                  radius: 16,
                                                  color: Colors.green,
                                                )),
                                              );
                                            }

                                            double averageEvaluation =
                                                averageEvaluationSnapshot
                                                        .data ??
                                                    0.0;

                                            return GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        TaskDetailsScreen(
                                                      task: task,
                                                      supplier: supplier,
                                                      supplierInfo:
                                                          supplierInfo,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom:
                                                        0.0), // Añade espacio debajo
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  // Modifica la decoración para solo bordes arriba y abajo
                                                  decoration:
                                                      const BoxDecoration(
                                                    border: Border(
                                                      bottom: BorderSide(
                                                          color:
                                                              Color(0xFF08143c),
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
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16),
                                                            ),
                                                            Text(
                                                              task.data()[
                                                                  'service'],
                                                              style: const TextStyle(
                                                                  fontSize:
                                                                      14.0,
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
                                                                  // Muestra la evaluación promedio
                                                                  averageEvaluation
                                                                      .toStringAsFixed(
                                                                          1),
                                                                  style: const TextStyle(
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
                                                            const EdgeInsets
                                                                .only(
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
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .amber,
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
                                                                      .format((task.data()['start']
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
                                          },
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
                      child: CupertinoActivityIndicator(
                      radius: 16,
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
                              child: CupertinoActivityIndicator(
                            radius: 16,
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
                                          child: CupertinoActivityIndicator(
                                        radius: 16,
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
                                          .collection('users')
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
                                                    CupertinoActivityIndicator(
                                              radius: 16,
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

                                        // Obtén la evaluación promedio del proveedor
                                        return FutureBuilder<double>(
                                          future: _getAverageSupplierEvaluation(
                                              supplierId),
                                          builder: (context,
                                              averageEvaluationSnapshot) {
                                            if (averageEvaluationSnapshot
                                                    .connectionState ==
                                                ConnectionState.waiting) {
                                              return const ListTile(
                                                title: Center(
                                                    child:
                                                        CupertinoActivityIndicator(
                                                  radius: 16,
                                                  color: Colors.green,
                                                )),
                                              );
                                            }

                                            double averageEvaluation =
                                                averageEvaluationSnapshot
                                                        .data ??
                                                    0.0;

                                            return GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        TaskDetailsScreen(
                                                      task: task,
                                                      supplier: supplier,
                                                      supplierInfo:
                                                          supplierInfo,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom:
                                                        0.0), // Añade espacio debajo
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  // Modifica la decoración para solo bordes arriba y abajo
                                                  decoration:
                                                      const BoxDecoration(
                                                    border: Border(
                                                      bottom: BorderSide(
                                                          color:
                                                              Color(0xFF08143c),
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
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16),
                                                            ),
                                                            Text(
                                                              task.data()[
                                                                  'service'],
                                                              style: const TextStyle(
                                                                  fontSize:
                                                                      14.0,
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
                                                                  // Muestra la evaluación promedio
                                                                  averageEvaluation
                                                                      .toStringAsFixed(
                                                                          1),
                                                                  style: const TextStyle(
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
                                                            const EdgeInsets
                                                                .only(
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
                                                                    FontWeight
                                                                        .bold,
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
                                                                      .format((task.data()['end']
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
                                          },
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
  final bool _pagoMovilSelected = false;
  bool _efectivoSelected = false;
  final bool _paypalSelected = false;
  final bool _zinliSelected = false;
  final bool _binanceSelected = false;
  final bool _zelleSelected = false;

  // ignore: unused_field
  late Future _initFuture;
  double _walletBalance = 0.0;
  String clientIDString = "";

  String? _supplierID;
  Map<String, dynamic>? _mobilePaymentData;
  Map<String, dynamic>? _binancePayData;
  Map<String, dynamic>? _zinliData;
  Map<String, dynamic>? _zelleData;
  Map<String, dynamic>? _paypalData;

  double _bcvExchangeRate = 0.0;
  bool _isLoadingExchangeRate = true;
  bool _showPagoMovilDetails = false;
  bool _showBinanceDetails = false;
  bool _showZinliDetails = false;
  bool _showZelleDetails = false;
  bool _showPaypalDetails = false;

  bool _hasZinli = false;
  bool _hasBinance = false;
  bool _hasZelle = false;
  bool _hasPayPal = false;

  File? _comprobante;

  double _averageEvaluation = 0.0;
  int _evaluationCount = 0;

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
        return StatefulBuilder(
          builder: (context, setState) {
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
                      activeColor: Colors.green,
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
                      activeColor: Colors.green,
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
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() {
                          _selectedReason = value;
                        });
                      },
                    ),
                    RadioListTile(
                      title: const Text('Tiempo exagerado de espera'),
                      value: 'Tiempo exagerado de espera',
                      groupValue: _selectedReason,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() {
                          _selectedReason = value;
                        });
                      },
                    ),
                    RadioListTile(
                      title: const Text(
                          'No he recibido ninguna respuesta del agente'),
                      value: 'No he recibido ninguna respuesta del agente',
                      groupValue: _selectedReason,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() {
                          _selectedReason = value;
                        });
                      },
                    ),
                    RadioListTile(
                      title:
                          const Text('El agente solicitó cancelar la reserva'),
                      value: 'El agente solicitó cancelar la reserva',
                      groupValue: _selectedReason,
                      activeColor: Colors.green,
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
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() {
                          _selectedReason = value;
                        });
                      },
                    ),
                    if (_selectedReason == 'Otro motivo')
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: TextField(
                          controller: _otherReasonController,
                          decoration: InputDecoration(
                            labelText: 'Describe el motivo',
                            hintText: 'Ej. Cambio de planes, emergencia...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Colors.green),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actionsPadding: EdgeInsets.zero,
              actions: [
                Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(15),
                                bottomRight: Radius.zero,
                                topLeft: Radius.zero,
                                topRight: Radius.zero,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF08143C)),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 48,
                        color: Colors.grey,
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            if (_selectedReason != null) {
                              if (_selectedReason == 'Otro motivo' &&
                                  _otherReasonController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Por favor, describe el motivo de la cancelación.',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 5),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              } else {
                                _cancelReservation();
                                Navigator.of(context).pop();
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Por favor, seleccione el motivo de la cancelación.',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 5),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.zero,
                                bottomRight: Radius.circular(15),
                                topLeft: Radius.zero,
                                topRight: Radius.zero,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Confirmar',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF08143C)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
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
  await _getSupplierID();
  await _getMobilePaymentData();
  await _checkPaymentMethods();
  
  setState(() => _isLoadingExchangeRate = true);
  try {
    _bcvExchangeRate = await ExchangeRates.getBCVExchangeRate();
    if (kDebugMode) {
      print('Tasa actualizada: $_bcvExchangeRate');
    }
  } finally {
    if (mounted) {
      setState(() => _isLoadingExchangeRate = false);
    }
  }
}

  Future<void> _getSupplierID() async {
    _supplierID = widget.task.data()['supplierID'];
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
          .collection('users')
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

  Future<void> _checkPaymentMethods() async {
  if (_supplierID != null) {
    final walletDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_supplierID)
        .get();

    if (walletDoc.exists) {
      final paymentMethodsCollection = walletDoc.reference.collection('paymentMethods');

      _hasZinli = (await paymentMethodsCollection.doc('zinli').get()).exists;
      _hasBinance = (await paymentMethodsCollection.doc('binancePay').get()).exists;
      _hasZelle = (await paymentMethodsCollection.doc('zelle').get()).exists;
      _hasPayPal = (await paymentMethodsCollection.doc('paypal').get()).exists;
    }
  }
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
    _getAverageSupplierEvaluation();
    _getUserInfo();
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

  Future<void> _getAverageSupplierEvaluation() async {
    if (widget.supplier != null) {
      QuerySnapshot<Map<String, dynamic>> tasksSnapshot =
          await FirebaseFirestore.instance.collection('tasks').get();

      double totalEvaluation = 0;
      int evaluationCount = 0;

      for (var taskDoc in tasksSnapshot.docs) {
        if (taskDoc.data()['supplierID'] == widget.supplier!.id &&
            taskDoc.data()['clientEvaluation'] != null) {
          totalEvaluation +=
              double.tryParse(taskDoc.data()['clientEvaluation'].toString()) ??
                  0.0;
          evaluationCount++;
        }
      }

      setState(() {
        if (evaluationCount == 0) {
          _averageEvaluation = 0.0;
          _evaluationCount = 0;
        } else {
          _averageEvaluation = totalEvaluation / evaluationCount;
          _evaluationCount = evaluationCount;
        }
      });
    }
  }

  void _handleWalletPayment() async {
    final taskData = widget.task.data();
    final quotation = taskData['quotation'] as Map<String, dynamic>;
    final totalAmountUSD = quotation['totalAmountUSD'] as double;

    if (_walletBalance >= totalAmountUSD) {
      // Suficiente saldo
      await _processWalletPayment(taskData, totalAmountUSD);
    } else {
      // Saldo insuficiente
      OneContext().showSnackBar(
        builder: (_) => SnackBar(
          content: const Text(
            'Saldo insuficiente. Por favor, selecciono otro método de pago.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _processWalletPayment(
      Map<String, dynamic> taskData, double totalAmountUSD) async {
    try {
      // Crear transacción
      final transactionData = {
        'senderName': taskData['clientName'],
        'senderId': taskData['clientID'],
        'recipientName': taskData['supplierName'],
        'recipientId': taskData['supplierID'],
        'paymentType': 'Pago de servicio',
        'date': FieldValue.serverTimestamp(),
        'amount': totalAmountUSD,
        'paymentMethod': {
          'Monedero': {'amount': totalAmountUSD}
        },
        'taskId': widget.task.id,
        'service': taskData['service'],
      };

      final transactionRef = await FirebaseFirestore.instance
          .collection('transactions')
          .add(transactionData);

      // Actualizar task
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .update({
        'transactionID': transactionRef.id,
        'state': 'Finalizada',
      });

      // Actualizar wallets
      await FirebaseFirestore.instance
          .collection('users')
          .doc(clientIDString)
          .update({'walletBalance': FieldValue.increment(-totalAmountUSD)});

      await FirebaseFirestore.instance
          .collection('users')
          .doc(taskData['supplierID'])
          .update({'walletBalance': FieldValue.increment(totalAmountUSD)});

      // Mostrar snackbar
      OneContext().showSnackBar(
        builder: (_) => SnackBar(
          content: const Text(
            '¡Transacción aprobada!',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // Navegar a la pantalla de recibo
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ServiceTransactionReceiptScreen(
              paymentType: 'Pago de servicio',
              date: DateTime.now(),
              transactionId: transactionRef.id,
              concept: taskData['service'],
              recipientId: taskData['supplierID'],
              recipientName: taskData['supplierName'],
              amount: totalAmountUSD,
              supplierProfileImageUrl:
                  widget.supplier?.data()?['profileImageUrl'] ?? '',
              supplierName: taskData['supplierName'],
              supplierId: taskData['supplierID'],
              taskId: widget.task.id,
              paymentMethod: transactionData['paymentMethod'],
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
    } catch (e) {
      OneContext().showSnackBar(
        builder: (_) => SnackBar(
          content: const Text(
            'Trasancción fallida',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showSufficientBalanceWarning() {
  OneContext().showSnackBar(
    builder: (_) => SnackBar(
      content: const Text(
        'El saldo del monedero es suficiente para cubrir la totalidad del pago',
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}

  void _togglePagoMovilDetails() {
  final taskData = widget.task.data();
  final totalAmountUSD = taskData['quotation']['totalAmountUSD'] as double;
  
  if (_walletBalance >= totalAmountUSD) {
    _showSufficientBalanceWarning();
    return;
  }

  setState(() {
    _showPagoMovilDetails = !_showPagoMovilDetails;
  });
  if (_showPagoMovilDetails) {
    _animationController?.forward();
    _showBinanceDetails = false;
    _showZinliDetails = false;
    _efectivoSelected = false;
    _showZelleDetails = false;
    _showPaypalDetails = false;
    _updatePaymentMethod('Pago Móvil');
  } else {
    _animationController?.reverse();
  }
}

  Future<void> _getMobilePaymentData() async {
    if (_supplierID != null) {
      try {
        final walletDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_supplierID)
            .get();

        if (walletDoc.exists) {
          final mobilePaymentDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_supplierID)
              .collection('paymentMethods')
              .doc('mobilePayment')
              .get();

          if (mobilePaymentDoc.exists) {
            setState(() {
              _mobilePaymentData = mobilePaymentDoc.data();
            });
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error al obtener datos de pago móvil: $e');
        }
      }
    }
  }

  Future<void> _getBinancePayData() async {
    if (_supplierID != null) {
      try {
        final walletDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_supplierID)
            .get();

        if (walletDoc.exists) {
          final binancePayDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_supplierID)
              .collection('paymentMethods')
              .doc('binancePay')
              .get();

          if (binancePayDoc.exists) {
            setState(() {
              _binancePayData = binancePayDoc.data();
            });
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error al obtener datos de Binance Pay: $e');
        }
      }
    }
  }

  void _toggleBinanceDetails() {
  final taskData = widget.task.data();
  final totalAmountUSD = taskData['quotation']['totalAmountUSD'] as double;
  
  if (_walletBalance >= totalAmountUSD) {
    _showSufficientBalanceWarning();
    return;
  }

  setState(() {
    _showBinanceDetails = !_showBinanceDetails;
  });
  if (_showBinanceDetails) {
    _animationController?.forward();
    _getBinancePayData();
    _showPagoMovilDetails = false;
    _efectivoSelected = false;
    _showZinliDetails = false;
    _showZelleDetails = false;
    _showPaypalDetails = false;
    _updatePaymentMethod('Binance');
  } else {
    _animationController?.reverse();
  }
}

  Future<void> _getZinliData() async {
    if (_supplierID != null) {
      try {
        final walletDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_supplierID)
            .get();

        if (walletDoc.exists) {
          final zinliDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_supplierID)
              .collection('paymentMethods')
              .doc('zinli')
              .get();

          if (zinliDoc.exists) {
            setState(() {
              _zinliData = zinliDoc.data();
            });
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error al obtener datos de Zinli: $e');
        }
      }
    }
  }

 void _toggleZinliDetails() {
  final taskData = widget.task.data();
  final totalAmountUSD = taskData['quotation']['totalAmountUSD'] as double;
  
  if (_walletBalance >= totalAmountUSD) {
    _showSufficientBalanceWarning();
    return;
  }

  setState(() {
    _showZinliDetails = !_showZinliDetails;
  });
  if (_showZinliDetails) {
    _animationController?.forward();
    _getZinliData();
    _showPagoMovilDetails = false;
    _efectivoSelected = false;
    _showBinanceDetails = false;
    _showZelleDetails = false;
    _showPaypalDetails = false;
    _updatePaymentMethod('Zinli');
  } else {
    _animationController?.reverse();
  }
}

  Future<void> _getZelleData() async {
    if (_supplierID != null) {
      try {
        final walletDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_supplierID)
            .get();

        if (walletDoc.exists) {
          final zelleDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_supplierID)
              .collection('paymentMethods')
              .doc('zelle')
              .get();

          if (zelleDoc.exists) {
            setState(() {
              _zelleData = zelleDoc.data();
            });
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error al obtener datos de Zelle: $e');
        }
      }
    }
  }

  void _toggleZelleDetails() {
  final taskData = widget.task.data();
  final totalAmountUSD = taskData['quotation']['totalAmountUSD'] as double;
  
  if (_walletBalance >= totalAmountUSD) {
    _showSufficientBalanceWarning();
    return;
  }

  setState(() {
    _showZelleDetails = !_showZelleDetails;
  });
  if (_showZelleDetails) {
    _animationController?.forward();
    _getZelleData();
    _showPagoMovilDetails = false;
    _efectivoSelected = false;
    _showBinanceDetails = false;
    _showZinliDetails = false;
    _showPaypalDetails = false;
    _updatePaymentMethod('Zelle');
  } else {
    _animationController?.reverse();
  }
}

Future<void> _getPaypalData() async {
  if (_supplierID != null) {
    try {
      final walletDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_supplierID)
          .get();

      if (walletDoc.exists) {
        final paypalDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_supplierID)
            .collection('paymentMethods')
            .doc('paypal')
            .get();

        if (paypalDoc.exists) {
          setState(() {
            _paypalData = paypalDoc.data();
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener datos de PayPal: $e');
      }
    }
  }
}

void _togglePaypalDetails() {
  final taskData = widget.task.data();
  final totalAmountUSD = taskData['quotation']['totalAmountUSD'] as double;
  
  if (_walletBalance >= totalAmountUSD) {
    _showSufficientBalanceWarning();
    return;
  }

  setState(() {
    _showPaypalDetails = !_showPaypalDetails;
  });
  if (_showPaypalDetails) {
    _animationController?.forward();
    _getPaypalData();
    _showPagoMovilDetails = false;
    _efectivoSelected = false;
    _showBinanceDetails = false;
    _showZinliDetails = false;
    _showZelleDetails = false;
    _updatePaymentMethod('PayPal');
  } else {
    _animationController?.reverse();
  }
}

  Future<void> _updatePaymentMethod(String method) async {
    try {
      final taskDoc = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .get();

      List<dynamic> currentMethods =
          List.from(taskDoc.data()?['paymentMethods'] ?? []);

      if (currentMethods.length > 1) {
        currentMethods[1] = method;
      } else if (currentMethods.length == 1) {
        currentMethods.add(method);
      } else {
        currentMethods = ['', method];
      }

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .update({'paymentMethods': currentMethods});
    } catch (e) {
      if (kDebugMode) {
        print('Error al actualizar el método de pago: $e');
      }
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
          .child('vouchers')
          .child('${widget.task.id}.jpg');
      await ref.putFile(_comprobante!);
      final url = await ref.getDownloadURL();

      // Update the task document, including 'paymentReceived' field
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .update({
        'voucherURL': url,
        'paymentReceived': false // Set paymentReceived to false
      });

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '¡Comprobante subido exitosamente!',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Error al subir el comprobante.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _deleteComprobante() async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('vouchers')
          .child('${widget.task.id}.jpg');
      await ref.delete();

      // Update the task document, removing 'paymentReceived' field
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .update({
        'voucherURL': FieldValue.delete(),
        'paymentReceived': FieldValue.delete()
      });

      setState(() {
        _comprobante = null;
      });

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '¡Comprobante eliminado exitosamente!',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Error al eliminar el comprobante.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showPaymentReceipt() async {
    final taskData = widget.task.data();
    final transactionID = taskData['transactionID'];

    if (transactionID == null) {
      OneContext().showSnackBar(
        builder: (_) => SnackBar(
          content: const Text(
            'Transacción no encontrada',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    try {
      final transactionDoc = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(transactionID)
          .get();

      if (!transactionDoc.exists) {
        OneContext().showSnackBar(
          builder: (_) => SnackBar(
            content: const Text(
              'Transacción no encontrada',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      final transactionData = transactionDoc.data()!;

      OneContext().push(
        MaterialPageRoute(
          builder: (context) => ServiceTransactionReceiptScreen(
            paymentType: transactionData['paymentType'] ?? 'Pago de servicio',
            date: (transactionData['date'] as Timestamp).toDate(),
            transactionId: transactionID,
            concept: transactionData['service'] ?? '',
            recipientId: transactionData['recipientId'] ?? '',
            recipientName: transactionData['recipientName'] ?? '',
            amount: (transactionData['amount'] as num).toDouble(),
            supplierProfileImageUrl:
                widget.supplier?.data()?['profileImageUrl'] ?? '',
            supplierName: transactionData['recipientName'] ?? '',
            supplierId: transactionData['recipientId'] ?? '',
            taskId: widget.task.id,
            paymentMethod: transactionData['paymentMethod'],
            onBackPressed: () {
              OneContext().pop();
            },
          ),
        ),
      );
    } catch (e) {
      OneContext().showSnackBar(
        builder: (_) => SnackBar(
          content: const Text(
            'Error al obtener el comprobante.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
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
        leading: IconButton(
          icon: const Icon(
            Icons
                .arrow_back_ios_new_rounded, // Puedes cambiar este icono por otro
            color: Colors.black,
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
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
                                  Row(
                                    children: [
                                      Text(
                                        '${taskData?['supplierName']}',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(
                                          width:
                                              5), // Espacio entre el nombre y el icono
                                      if (widget.supplier
                                              ?.data()?['verified'] ==
                                          true) // Verifica si verified es true
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.blue,
                                          size: 22,
                                        ),
                                    ],
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
                                              _evaluationCount > 0
                                                  ? _averageEvaluation
                                                      .toStringAsFixed(1)
                                                  : 'Sin calificación',
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
                                alignment: Alignment.topRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProfileViewScreen(
                                            supplierId: widget.supplier!.id),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 1),
                                    minimumSize: const Size(120.0, 41.0),
                                    textStyle: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    side: const BorderSide(
                                        color: Colors.white, width: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  label: const Text('Ver perfil',
                                      style: TextStyle(fontSize: 15)),
                                ),
                              ),
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
                                    taskData?['state'] == 'Finalizada' ||
                                    taskData?['scheduled'] != null)
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
                                          const Divider(
                                            height: 32,
                                            color: Colors.black,
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
  padding: const EdgeInsets.only(bottom: 12.0),
  child: Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1ca424),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'VES',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          'Total en bolívares',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600]
          ),
        ),
      ),
      if (_isLoadingExchangeRate)
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        )
      else
        Text(
          taskData?['quotation'] == null ? '0,00' :
            ((taskData!['quotation']['totalAmountUSD'] as double) * _bcvExchangeRate)
              .toStringAsFixed(2),
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black
          ),
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
                                          const SizedBox(height: 8),
                                          ElevatedButton.icon(
                                            icon: const Icon(
                                                Icons.account_balance_wallet,
                                                color: Colors.black),
                                            label: const Text(
                                              'Monedero',
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 13),
                                            ),
                                            onPressed: _handleWalletPayment,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              minimumSize: const Size(
                                                  double.infinity,
                                                  50), // para que ocupe todo el ancho
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                side: const BorderSide(
                                                    color: Color(0xFF08143C)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Si posee dinero en su monedero pero no es suficiente, será descontado su saldo disponible y se permitirá cancelar el restante con cualquiera de los siguientes métodos:',
                                            style: TextStyle(
                                              fontSize: 12,
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
                                                    _showPagoMovilDetails =
                                                        false;
                                                    _showBinanceDetails = false;
                                                    _showZinliDetails = false;
                                                    _showZelleDetails = false;
                                                    _updatePaymentMethod(
                                                        'Efectivo');
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
                                          const SizedBox(height: 15),
                                          _buildPaymentButtons(),
                                          const SizedBox(height: 15),
                                          // Campo de texto para billete y Advertencia con Visibility
                                          Visibility(
                                            visible: _efectivoSelected,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(7.0),
                                                  child: TextField(
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration: InputDecoration(
                                                      labelText: 'Billete',
                                                      labelStyle:
                                                          const TextStyle(
                                                              color:
                                                                  Colors.black),
                                                      hintText:
                                                          'Denominación del billete',
                                                      hintStyle:
                                                          const TextStyle(
                                                              color:
                                                                  Colors.grey),
                                                      filled: true,
                                                      fillColor:
                                                          Colors.transparent,
                                                      border:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16.0),
                                                        borderSide:
                                                            const BorderSide(
                                                                color: Colors
                                                                    .blue),
                                                      ),
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 16.0,
                                                        vertical: 16.0,
                                                      ),
                                                      suffixIcon: IconButton(
                                                        icon: Image.asset(
                                                            'assets/images/IconSend.png',
                                                            height: 35,
                                                            width:
                                                                35), // Reemplaza con tu imagen
                                                        onPressed: () {
                                                          // Función para enviar el valor a Firestore (implementar)
                                                          if (kDebugMode) {
                                                            print(
                                                                'Enviar a Firestore');
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const Padding(
                                                  padding: EdgeInsets.all(6.0),
                                                  child: Text(
                                                    'Advertencia: Si el agente no posee disponibilidad de cambio, el monto restante será añadido a su monedero instantáneamente.',
                                                    style: TextStyle(
                                                      color: Color.fromARGB(
                                                          255, 250, 96, 85),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
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
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      'Bs. ${(((taskData?['quotation']['totalAmountUSD'] as double) - _walletBalance) * _bcvExchangeRate).abs().toStringAsFixed(2)}',
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.green,
      ),
    ),
    Text(
      '\$${((taskData?['quotation']['totalAmountUSD'] as double) - _walletBalance).abs().toStringAsFixed(2)}',
      style: TextStyle(
        fontSize: 18,
        color: Colors.grey[600],
      ),
    ),
  ],
),
                                                  const SizedBox(height: 0),
                                                  Text(
                                                    'Tasa BCV: ${_bcvExchangeRate.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Text(
                                                    'Datos del pago Móvil:',
                                                    style: TextStyle(
                                                      fontSize: 15,
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
                                                      side: const BorderSide(
                                                          color: Color(
                                                              0xFF1ca424)),
                                                    ),
                                                    color: Colors.white,
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
                                                                  color: Color(
                                                                      0xFF08143c)),
                                                              const SizedBox(
                                                                  width: 10),
                                                              Text(
                                                                'Banco: ${_mobilePaymentData?['bank'] ?? 'N/A'}',
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
                                                                  color: Color(
                                                                      0xFF08143c)),
                                                              const SizedBox(
                                                                  width: 10),
                                                              Text(
                                                                'Cédula: ${_mobilePaymentData?['identification'] ?? 'N/A'}',
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
                                                                  color: Color(
                                                                      0xFF08143c)),
                                                              const SizedBox(
                                                                  width: 10),
                                                              Text(
                                                                'Teléfono: ${_mobilePaymentData?['phone'] ?? 'N/A'}',
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
                                                  _buildComprobanteUploader(
                                                      'Pago Móvil'),
                                                ],
                                              ),
                                            ),
                                          ),
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 500),
                                            height:
                                                _showBinanceDetails ? null : 0,
                                            child: AnimatedOpacity(
                                              duration: const Duration(
                                                  milliseconds: 500),
                                              opacity: _showBinanceDetails
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
                                                  Text(
                                                    '${((taskData?['quotation']['totalAmountUSD'] as double) - _walletBalance).toStringAsFixed(2)} USDT',
                                                    style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Text(
                                                    'Datos de Binance Pay:',
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
                                                      side: const BorderSide(
                                                          color: Color(
                                                              0xFF1ca424)),
                                                    ),
                                                    color: Colors.white,
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
                                                                      .qr_code_rounded,
                                                                  color: Color(
                                                                      0xFF08143c)),
                                                              const SizedBox(
                                                                  width: 10),
                                                              Text(
                                                                'Binance ID: ${_binancePayData?['binanceID'] ?? 'N/A'}',
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
                                                                      .email_rounded,
                                                                  color: Color(
                                                                      0xFF08143c)),
                                                              const SizedBox(
                                                                  width: 10),
                                                              Text(
                                                                'Email: ${_binancePayData?['email'] ?? 'N/A'}',
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
                                                                      .local_phone_rounded,
                                                                  color: Color(
                                                                      0xFF08143c)),
                                                              const SizedBox(
                                                                  width: 10),
                                                              Text(
                                                                'Teléfono: ${_binancePayData?['phone'] ?? 'N/A'}',
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
                                                  _buildComprobanteUploader(
                                                      'Binance'),
                                                ],
                                              ),
                                            ),
                                          ),
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 500),
                                            height:
                                                _showZinliDetails ? null : 0,
                                            child: AnimatedOpacity(
                                              duration: const Duration(
                                                  milliseconds: 500),
                                              opacity:
                                                  _showZinliDetails ? 1.0 : 0.0,
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
                                                    children: [
                                                      const Icon(
                                                        Icons.attach_money,
                                                        color: Colors.green,
                                                        size:
                                                            26, // Ajusta el tamaño del ícono según tus necesidades
                                                      ),
                                                      Text(
                                                        ((taskData?['quotation']
                                                                        [
                                                                        'totalAmountUSD']
                                                                    as double) -
                                                                _walletBalance)
                                                            .toStringAsFixed(2),
                                                        style: const TextStyle(
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.green,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Text(
                                                    'Datos de Zinli:',
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
                                                      side: const BorderSide(
                                                          color: Color(
                                                              0xFF1ca424)),
                                                    ),
                                                    color: Colors.white,
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
                                                                      .email_rounded,
                                                                  color: Color(
                                                                      0xFF08143c)),
                                                              const SizedBox(
                                                                  width: 10),
                                                              Text(
                                                                'Email: ${_zinliData?['email'] ?? 'N/A'}',
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
                                                                      .local_phone_rounded,
                                                                  color: Color(
                                                                      0xFF08143c)),
                                                              const SizedBox(
                                                                  width: 10),
                                                              Text(
                                                                'Teléfono: ${_zinliData?['phone'] ?? 'N/A'}',
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
                                                  _buildComprobanteUploader(
                                                      'Zinli'),
                                                ],
                                              ),
                                            ),
                                          ),
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 500),
                                            height:
                                                _showZelleDetails ? null : 0,
                                            child: AnimatedOpacity(
                                              duration: const Duration(
                                                  milliseconds: 500),
                                              opacity:
                                                  _showZelleDetails ? 1.0 : 0.0,
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
                                                    children: [
                                                      const Icon(
                                                        Icons.attach_money,
                                                        color: Colors.green,
                                                        size:
                                                            26, // Ajusta el tamaño del ícono según tus necesidades
                                                      ),
                                                      Text(
                                                        ((taskData?['quotation']
                                                                        [
                                                                        'totalAmountUSD']
                                                                    as double) -
                                                                _walletBalance)
                                                            .toStringAsFixed(2),
                                                        style: const TextStyle(
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.green,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Text(
                                                    'Datos de Zelle:',
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
                                                      side: const BorderSide(
                                                          color: Color(
                                                              0xFF1ca424)),
                                                    ),
                                                    color: Colors.white,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              16.0),
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                              Icons.email,
                                                              color: Color(
                                                                  0xFF08143c)),
                                                          const SizedBox(
                                                              width: 10),
                                                          Text(
                                                            'Email: ${_zelleData?['email'] ?? 'N/A'}',
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        16),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  _buildComprobanteUploader(
                                                      'Zelle'),
                                                ],
                                              ),
                                            ),
                                          ),
                                          AnimatedContainer(
  duration: const Duration(milliseconds: 500),
  height: _showPaypalDetails ? null : 0,
  child: AnimatedOpacity(
    duration: const Duration(milliseconds: 500),
    opacity: _showPaypalDetails ? 1.0 : 0.0,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Monto a pagar:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${((taskData?['quotation']['totalAmountUSD'] as double) - _walletBalance).toStringAsFixed(2)} USD',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Datos de PayPal:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF1ca424)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.email, color: Color(0xFF08143c)),
                    const SizedBox(width: 10),
                    Text(
                      'Email: ${_paypalData?['email'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _buildComprobanteUploader('PayPal'),
      ],
    ),
  ),
),
                                        ],
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 10),

                                // Agendado
                                if (taskData?['scheduled'] != null)
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
                                          color:
                                              Color.fromRGBO(209, 196, 233, 1),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Agendado: ${formatDateTime(widget.task.data()['scheduled'] as Timestamp?)}',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ],
                                  ),

                                // Reservado
                                if (taskData?['scheduled'] == null)
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
                                          color:
                                              Color.fromRGBO(209, 196, 233, 1),
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
                                    taskData?['state'] == 'Finalizada' ||
                                    taskData?['scheduled'] != null)
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
                                        color: Colors.white,
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
                                                    '${taskData?['supplierComment'] ?? 'No disponible'}',
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
                                                '${taskData?['supplierEvaluation'] ?? 'No disponible'}',
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
                                      taskData?['state'] == 'Finalizada' ||
                                      taskData?['scheduled'] != null)
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
                                          // Agrega borderRadius a la forma del Card
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15)),
                                          shadowColor: const Color(0xFF08143C),
                                          child: Container(
                                            // Agrega borderRadius al contenedor del mapa
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(15.0),
                                              border: Border.all(
                                                color: const Color(0xFF08143C),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              // Agrega ClipRRect para redondear los bordes del mapa
                                              borderRadius:
                                                  BorderRadius.circular(15.0),
                                              child: SizedBox(
                                                height:
                                                    200, // Ajusta la altura del mapa
                                                child: ClientLocationMap(
                                                  clientLatLng: LatLng(
                                                    widget.task
                                                        .data()[
                                                            'clientLocation']
                                                        .latitude,
                                                    widget.task
                                                        .data()[
                                                            'clientLocation']
                                                        .longitude,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                const SizedBox(height: 20),

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
                                        Icons.qr_code_rounded,
                                        size: 18.0,
                                        color: Colors.yellow,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Task ID: ${widget.task.id}', // Aquí obtienes el ID del documento
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                        // Botón "Cancelar reservación" (solo si el estado es "Pendiente")
                        if (taskData?['state'] == 'Pendiente' ||
                            taskData?['scheduled'] != null)
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

                        // Botón "Comprobante de pago"
                        if (taskData?['state'] == 'Finalizada')
                          Padding(
                            padding: const EdgeInsets.only(top: 20.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF08143C),
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
                                        color: Colors.green, width: 2.0),
                                  ),
                                ),
                                onPressed: _showPaymentReceipt,
                                child: const Text(
                                  'Comprobante de pago',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
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
                      child: CupertinoActivityIndicator(
                    radius: 16,
                    color: Colors.green,
                  ));
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

  Widget _buildComprobanteUploader(String paymentMethod) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              if (_comprobante == null)
                ElevatedButton(
                  onPressed: _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF08143c),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Subir comprobante de pago'),
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_comprobante!),
                ),
                ElevatedButton(
                  onPressed: _deleteComprobante,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF08143c),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Eliminar comprobante'),
                ),
              ],
              const SizedBox(height: 10),
              if (_comprobante == null)
                Text(
                  'Adjunte su comprobante para procesar el pago',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pending_actions, color: Colors.blue[800]),
                    const SizedBox(width: 12),
                    Text(
                      'Esperando confirmación del agente',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentButtons() {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        if (_hasPayPal)
          _buildPaymentButton(
            onPressed: _togglePaypalDetails,
            selected: _paypalSelected,
            child: Image.asset(
              'assets/images/Paypal_Logo.png',
              height: 30,
              width: 70,
            ),
          ),
        if (_hasZelle)
          _buildPaymentButton(
            onPressed: _toggleZelleDetails,
            selected: _zelleSelected,
            child: Image.asset(
              'assets/images/Zelle_Logo.png',
              height: 25,
              width: 50,
            ),
          ),
        if (_hasBinance)
          _buildPaymentButton(
            onPressed: _toggleBinanceDetails,
            selected: _binanceSelected,
            child: Image.asset(
              'assets/images/Binance_LogoNew.png',
              height: 40,
              width: 50,
            ),
          ),
        if (_hasZinli)
          _buildPaymentButton(
            onPressed: _toggleZinliDetails,
            selected: _zinliSelected,
            child: Image.asset(
              'assets/images/Zinli_Logo.png',
              height: 25,
              width: 50,
            ),
          ),
      ],
    ),
  );
}

  Widget _buildPaymentButton({
    required VoidCallback onPressed,
    required bool selected,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero, // Removes internal padding
          backgroundColor: selected ? Colors.green[100] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color:
                  selected ? const Color(0xFF1ca424) : const Color(0xFF08143C),
            ),
          ),
          minimumSize: const Size(90, 50),
        ),
        child: SizedBox(
          width:
              110, // Sets the width of the child container to match the button's minimum size
          child: child,
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
    case 'Agendado':
      return const Icon(
        Icons.circle,
        size: 18.0,
        color: Colors.amber,
      );
    case 'En proceso':
      return const Icon(
        Icons.circle,
        size: 18.0,
        color: Colors.lightGreen,
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
        initialCenter: clientLatLng,
        initialZoom: 15,
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
              child: const Icon(
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

class ServiceTransactionReceiptScreen extends StatefulWidget {
  final String paymentType;
  final DateTime date;
  final String transactionId;
  final String concept;
  final String recipientId;
  final String recipientName;
  final double amount;
  final VoidCallback? onBackPressed;
  final String supplierProfileImageUrl;
  final String supplierName;
  final String supplierId;
  final String taskId;
  final Map<String, dynamic> paymentMethod; // Agrega paymentMethod

  const ServiceTransactionReceiptScreen({
    super.key,
    required this.paymentType,
    required this.date,
    required this.transactionId,
    required this.concept,
    required this.recipientId,
    required this.recipientName,
    required this.amount,
    this.onBackPressed,
    required this.supplierProfileImageUrl,
    required this.supplierName,
    required this.supplierId,
    required this.taskId,
    required this.paymentMethod, // Agrega paymentMethod al constructor
  });

  @override
  // ignore: library_private_types_in_public_api
  _ServiceTransactionReceiptScreenState createState() =>
      _ServiceTransactionReceiptScreenState();
}

class _ServiceTransactionReceiptScreenState
    extends State<ServiceTransactionReceiptScreen> {
  final ScreenshotController screenshotController = ScreenshotController();
  int _rating = 0; // Ahora es un entero
  final TextEditingController _commentController = TextEditingController();
  bool _hasClientEvaluation = false;

  @override
  void initState() {
    super.initState();
    _checkClientEvaluation();
  }

  Future<void> _checkClientEvaluation() async {
    final taskDoc = await FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.taskId)
        .get();
    setState(() {
      _hasClientEvaluation = taskDoc.data()?['clientEvaluation'] != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Comprobante de pago'),
          leading: _hasClientEvaluation
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: _handleBackPress,
                )
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.share, color: Colors.black),
              onPressed: () => _shareScreenshot(),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Screenshot(
                controller: screenshotController,
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Center(
                              child: Icon(
                                Icons.check_circle_outline_rounded,
                                color: Colors.green,
                                size: 80,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment
                                    .center, // Centra los textos verticalmente
                                children: [
                                  const Text(
                                    '¡Transacción aprobada!',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(
                                      height: 10), // Espacio entre los textos
                                  Text(
                                    'Monto total: \$${widget.amount.toStringAsFixed(2)}', // Muestra el monto con 2 decimales
                                    textAlign:
                                        TextAlign.center, // Centra el texto
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildInfoCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_hasClientEvaluation) ...[
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundImage:
                                NetworkImage(widget.supplierProfileImageUrl),
                          ),
                          const SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.supplierName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                "ID: ${widget.supplierId}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Center(
                        child: RatingBar.builder(
                          initialRating:
                              _rating.toDouble(), // Convierte a double
                          minRating: 1,
                          maxRating: 5, // Ajusta el máximo a 5
                          direction: Axis.horizontal,
                          allowHalfRating:
                              false, // Desactiva la selección de medios
                          itemCount: 5,
                          itemPadding:
                              const EdgeInsets.symmetric(horizontal: 4.0),
                          itemBuilder: (context, _) => const Icon(
                            Icons.star_rounded,
                            color: Color.fromRGBO(0, 230, 118, 1),
                            size: 30,
                          ),
                          onRatingUpdate: (rating) {
                            setState(() {
                              _rating =
                                  rating.toInt(); // Guarda el valor entero
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          labelText: 'Comentario',
                          labelStyle: const TextStyle(color: Colors.black),
                          hintText:
                              'Ingresa un comentario o una sugerencia (opcional)',
                          hintStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            borderSide: const BorderSide(color: Colors.blue),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 16.0,
                          ),
                        ),
                        style: const TextStyle(fontSize: 15),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 15),
                      Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                                0xFF08143C), // Color de fondo #08143c
                            padding: const EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 30,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _submitEvaluationAndExit,
                          child: const Text(
                            "Enviar y salir",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white, // Color de las letras blanco
                              fontWeight: FontWeight.bold, // Letras en negrita
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  widget.paymentType,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo),
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                  'Fecha', DateFormat('dd/MM/yyyy HH:mm').format(widget.date)),
              _buildInfoRow('Referencia', widget.transactionId,
                  isCopiable: true),
              _buildInfoRow('Servicio', widget.concept),
              _buildInfoRow('Receptor',
                  '${widget.recipientName} (${widget.recipientId})'),
              // Sección para mostrar los métodos de pago
              if (widget.paymentMethod.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Métodos de pago',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF08143C),
                        ),
                      ),
                      for (var entry in widget.paymentMethod.entries)
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 16.0, bottom: 1.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key,
                                  style:
                                      const TextStyle(color: Colors.black87)),
                              Text(
                                  '\$${(entry.value['amount'] as num).toStringAsFixed(2)}',
                                  style:
                                      const TextStyle(color: Colors.black87)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              _buildInfoRow('Task ID: ', widget.taskId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isCopiable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF08143C),
              )),
          Row(
            children: [
              Text(value),
              if (isCopiable)
                IconButton(
                  icon: const Icon(Icons.copy, size: 15),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    OneContext().showSnackBar(
                      builder: (_) => SnackBar(
                        content: const Text(
                          '¡Referencia copia al portapeles con éxito!',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleBackPress() {
    if (widget.onBackPressed != null) {
      widget.onBackPressed!();
    } else {
      Navigator.of(context).pushReplacement(_createRoute());
    }
  }

  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const HomePage(selectedIndex: 2),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(-1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  Future<void> _shareScreenshot() async {
    final Uint8List? image = await screenshotController.capture();
    if (image != null) {
      final directory = await getTemporaryDirectory();
      final imagePath =
          await File('${directory.path}/comprobante_transaccion.png').create();
      await imagePath.writeAsBytes(image);

      final xFile = XFile(imagePath.path);
      await Share.shareXFiles([xFile], text: 'Comprobante de transacción');
    }
  }

  void _submitEvaluationAndExit() async {
    if (_rating == 0) {
      OneContext().showSnackBar(
        builder: (_) => SnackBar(
          content: const Text(
            'Por favor, evalúe al agente antes de salir.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.taskId)
        .update({
      'clientEvaluation': _rating, // Guarda el rating como entero
      'clientComment': _commentController.text,
    });

    OneContext().showSnackBar(
      builder: (_) => SnackBar(
        content: const Text(
          'Muchas gracias por hacer uso de nuestros servicios.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );

    _handleBackPress();
  }
}
