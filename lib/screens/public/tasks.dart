import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';

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
        body: Padding(
          padding: const EdgeInsets.only(top: 16.0), // Añade espacio arriba
          child: TabBarView(
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

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TaskDetailsScreen(
                                              task: task,
                                              supplier: supplier,
                                              supplierInfo: supplierInfo,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 0.0), // Añade espacio debajo
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          // Modifica la decoración para solo bordes arriba y abajo
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(color: Color(0xFF08143c), width: 0.5),
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
              _clientId == null
                  ? const Center(child: CircularProgressIndicator(color: Colors.green,))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('tasks')
                          .where('clientID', isEqualTo: _clientId)
                          .where('state', isEqualTo: 'En proceso')
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
                          return const Center(child: Text('No tienes tareas activas'));
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

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TaskDetailsScreen(
                                              task: task,
                                              supplier: supplier,
                                              supplierInfo: supplierInfo,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 0.0), // Añade espacio debajo
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          // Modifica la decoración para solo bordes arriba y abajo
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(color: Color(0xFF08143c), width: 0.5),
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

              // Pestaña "Completadas"
              _clientId == null
                  ? const Center(child: CircularProgressIndicator(color: Colors.green,))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('tasks')
                          .where('clientID', isEqualTo: _clientId)
                          .where('state', isEqualTo: 'Finalizada')
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
                          return const Center(child: Text('No tienes tareas completadas'));
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

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TaskDetailsScreen(
                                              task: task,
                                              supplier: supplier,
                                              supplierInfo: supplierInfo,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 0.0), // Añade espacio debajo
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          // Modifica la decoración para solo bordes arriba y abajo
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(color: Color(0xFF08143c), width: 0.5),
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

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  bool _showProfileImage = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        // No se necesita leading
        title: const Text(
          'Información detallada',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Stack(
        children: [
          // Contenido principal
          Padding(
            padding: const EdgeInsets.all(23.0),
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
                            color: const Color(0xFF08143C),
                            width: 3.0,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundImage: widget.supplier?.data()?['profileImageUrl'] != null
                              ? NetworkImage(
                                  widget.supplier?.data()?['profileImageUrl'])
                              : const AssetImage(
                                  'assets/images/ProfilePhoto_predetermined.png'),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Nombre del agente
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.supplier?.data()?['name']}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Calificación del agente
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 5.0,
                        horizontal: 10.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: const Color(0xFF08143C),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 18.0,
                            color: Color(0xFF1ca424),
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            '${widget.supplierInfo?.data()?['assessment'] ?? 'Sin calificación'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // ID del agente
                Text(
                  'ID: ${widget.supplier?.id}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 10),
                // Servicio seleccionado
                Text(
                  'Servicio: ${widget.task.data()['service']}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                // Detalles del servicio
                Text(
                  'Detalles: ${widget.task.data()['serviceDetails']}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                // Tarifa por hora del agente
                Text(
                  'Tarifa por hora: \$${widget.task.data()['hourlyRate'].toStringAsFixed(2)}/hr',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                // Estado de la tarea
                Text(
                  'Estado: ${widget.task.data()['state']}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                // Evaluación del agente
                Text(
                  'Evaluación: ${widget.supplierInfo?.data()?['assessment'] ?? 'Sin calificación'}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                // Fecha y hora de la reservación
                Text(
                  'Reservado: ${widget.task.data()['reservation'] != null ? DateTime.fromMillisecondsSinceEpoch(widget.task.data()['reservation'].millisecondsSinceEpoch).toLocal().toString() : 'No disponible'}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                // Punto de referencia
                Text(
                  'Punto de referencia: ${widget.task.data()['referencePoint'] ?? 'No disponible'}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),

                // Fecha y hora de inicio (solo para tareas activas y completadas)
                if (widget.task.data()['state'] == 'En proceso' ||
                    widget.task.data()['state'] == 'Finalizada')
                  Text(
                    'Inicio: ${widget.task.data()['start'] != null ? DateTime.fromMillisecondsSinceEpoch(widget.task.data()['start'].millisecondsSinceEpoch).toLocal().toString() : 'No disponible'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                const SizedBox(height: 10),

                // Fecha y hora de finalización (solo para tareas completadas)
                if (widget.task.data()['state'] == 'Finalizada')
                  Text(
                    'Finalización: ${widget.task.data()['end'] != null ? DateTime.fromMillisecondsSinceEpoch(widget.task.data()['end'].millisecondsSinceEpoch).toLocal().toString() : 'No disponible'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                const SizedBox(height: 10),

                // Comentario del cliente (solo para tareas completadas)
                if (widget.task.data()['state'] == 'Finalizada')
                  Text(
                    'Comentario: ${widget.task.data()['clientComment'] ?? 'No disponible'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                const SizedBox(height: 10),

                // Evaluación del cliente (solo para tareas completadas)
                if (widget.task.data()['state'] == 'Finalizada')
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 18.0,
                        color: Color(0xFF1ca424),
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        '${widget.task.data()['clientEvaluation'] ?? 'No disponible'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),

                  // Obtiene la ubicación del cliente desde el campo 'clientLocation' en la tarea
                  if (widget.task.data()['clientLocation'] != null)
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          // Obtén las coordenadas de GeoPoint
                          final GeoPoint clientLocation =
                              widget.task.data()['clientLocation'];

                          // Crea un LatLng para el mapa
                          final LatLng clientLatLng =
                              LatLng(clientLocation.latitude, clientLocation.longitude);

                          // Navega a la pantalla LocationMapScreen y envía las coordenadas
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LocationMapScreen(
                                clientLatLng: clientLatLng,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 15),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: const Text(
                          'Ver Ubicación',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
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
                      backgroundImage: widget.supplier?.data()?['profileImageUrl'] != null
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
    );
  }
}

// Pantalla para mostrar el mapa con la ubicación del cliente
class LocationMapScreen extends StatefulWidget {
  final LatLng clientLatLng;

  const LocationMapScreen({super.key, required this.clientLatLng});

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación del Cliente'),
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          center: widget.clientLatLng,
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
                point: widget.clientLatLng,
                builder: (ctx) => const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}