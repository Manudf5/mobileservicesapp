import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

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
                          return const Center(child: CircularProgressIndicator(color: Colors.green,));
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
                                    title: Center(child: CircularProgressIndicator(color: Colors.green,)),
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
                                        title: Center(child: CircularProgressIndicator(color: Colors.green,)),
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
                                                      '${task.data()['supplierName']}',
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
                                                child: Column( // Use a Column to stack the text widgets
                                                  crossAxisAlignment: CrossAxisAlignment.start, // Align text to the start
                                                  children: [
                                                    Text(
                                                      '${task.data()['state']}',
                                                      style: const TextStyle(
                                                        fontSize: 14.0,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF00C853),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 1), // Add some space between the text widgets
                                                    Text(
                                                      // Formatea la fecha desde Timestamp a DD/MM/YYYY
                                                      task.data()['reservation'] != null
                                                          ? DateFormat('dd/MM/yyyy').format(
                                                              (task.data()['reservation'] as Timestamp).toDate())
                                                          : 'Sin fecha',
                                                      style: const TextStyle(
                                                        fontSize: 10.0, // Smaller font size for the date
                                                        color: Color(0xFF08143C),
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
                          return const Center(child: CircularProgressIndicator(color: Colors.green,));
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
                                    title: Center(child: CircularProgressIndicator(color: Colors.green,)),
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
                                        title: Center(child: CircularProgressIndicator(color: Colors.green,)),
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
                                                      '${task.data()['supplierName']}',
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
                                                child: Column( // Use a Column to stack the text widgets
                                                  crossAxisAlignment: CrossAxisAlignment.start, // Align text to the start
                                                  children: [
                                                    Text(
                                                      '${task.data()['state']}',
                                                      style: const TextStyle(
                                                        fontSize: 14.0,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF00C853),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 1), // Add some space between the text widgets
                                                    Text(
                                                      // Formatea la fecha desde Timestamp a DD/MM/YYYY
                                                      task.data()['start'] != null
                                                          ? DateFormat('dd/MM/yyyy').format(
                                                              (task.data()['start'] as Timestamp).toDate())
                                                          : 'Sin fecha',
                                                      style: const TextStyle(
                                                        fontSize: 10.0, // Smaller font size for the date
                                                        color: Color(0xFF08143C),
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
                          return const Center(child: CircularProgressIndicator(color: Colors.green,));
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
                                    title: Center(child: CircularProgressIndicator(color: Colors.green,)),
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
                                        title: Center(child: CircularProgressIndicator(color: Colors.green,)),
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
                                                      '${task.data()['supplierName']}',
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
                                                child: Column( // Use a Column to stack the text widgets
                                                  crossAxisAlignment: CrossAxisAlignment.start, // Align text to the start
                                                  children: [
                                                    Text(
                                                      '${task.data()['state']}',
                                                      style: const TextStyle(
                                                        fontSize: 14.0,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF00C853),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 1), // Add some space between the text widgets
                                                    Text(
                                                      // Formatea la fecha desde Timestamp a DD/MM/YYYY
                                                      task.data()['end'] != null
                                                          ? DateFormat('dd/MM/yyyy').format(
                                                              (task.data()['end'] as Timestamp).toDate())
                                                          : 'Sin fecha',
                                                      style: const TextStyle(
                                                        fontSize: 10.0, // Smaller font size for the date
                                                        color: Color(0xFF08143C),
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

  // Formatea la fecha y hora en el formato deseado (12h)
  String formatDateTime(Timestamp? dateTime) {
    if (dateTime == null) {
      return 'No disponible';
    }
    // Convierte el Timestamp a DateTime
    final convertedDateTime = dateTime.toDate();

    final formattedDate =
        "${convertedDateTime.day.toString().padLeft(2, '0')}/${convertedDateTime.month.toString().padLeft(2, '0')}/${convertedDateTime.year}";

    // Formatea la hora en formato 12h
    final formattedTime =
        '${convertedDateTime.hour % 12 == 0 ? 12 : convertedDateTime.hour % 12}:${convertedDateTime.minute.toString().padLeft(2, '0')} ${convertedDateTime.hour >= 12 ? 'PM' : 'AM'}';

    return "$formattedDate a las $formattedTime";
  }

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
      body: SingleChildScrollView( // Agrega SingleChildScrollView para el scroll
        child: Stack(
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
                        '${widget.task.data()['supplierName']}',
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

                  // Estado de la tarea
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18.0,
                        color: Color(0xFF08143C),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Estado: ${widget.task.data()['state']}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 3),
                      // Usa la función getColoredIcon para el icono del estado
                      getColoredIcon(widget.task.data()['state']),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Servicio seleccionado
                  Row(
                    children: [
                      const Icon(
                        Icons.shopping_cart,
                        size: 18.0,
                        color: Color(0xFF08143C),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Servicio: ${widget.task.data()['service']}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Detalles del servicio
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(
                        color: const Color(0xFF08143C),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detalles',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.description,
                              size: 18.0,
                              color: Color(0xFF08143C),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${widget.task.data()['serviceDetails']}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Tarifa por hora del agente
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(
                        color: const Color(0xFF1ca424),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                            const Icon(
                              Icons.attach_money,
                              size: 18.0,
                              color: Color(0xFF08143C),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '\$${widget.task.data()['hourlyRate'].toStringAsFixed(2)}/hr',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Reservado
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 18.0,
                        color: Color(0xFF08143C),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Reservado: ${formatDateTime(widget.task.data()['reservation'] as Timestamp?)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Inicio
                  if (widget.task.data()['state'] == 'En proceso' ||
                      widget.task.data()['state'] == 'Finalizada')
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 18.0,
                          color: Color(0xFF08143C),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Inicio: ${formatDateTime(widget.task.data()['start'] as Timestamp?)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  // Finalización
                  if (widget.task.data()['state'] == 'Finalizada')
                    Row(
                      children: [
                        const Icon(
                          Icons.stop_circle,
                          size: 18.0,
                          color: Color(0xFF08143C),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Finalización: ${formatDateTime(widget.task.data()['end'] as Timestamp?)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  // Punto de referencia
                  Row(
                    children: [
                      const Icon(
                        Icons.location_pin,
                        size: 18.0,
                        color: Color(0xFF08143C),
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
                  if (widget.task.data()['state'] == 'Finalizada')
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: const Color(0xFF08143C),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.comment,
                                size: 18.0,
                                color: Color(0xFF08143C),
                              ),
                              SizedBox(width: 10),
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
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: const Color(0xFF1ca424),
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
                                  '${widget.task.data()['clientComment'] ?? 'No disponible'}',
                                  style: const TextStyle(fontSize: 16),
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
                                  '${widget.task.data()['clientEvaluation'] ?? 'No disponible'}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),

                                    // Ubicación del servicio
                  if (widget.task.data()['clientLocation'] != null)
                    Column(
                      children: [
                        const Text(
                          'Ubicación del servicio:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            border: Border.all(
                              color: const Color(0xFF08143C),
                              width: 1.0,
                            ),
                          ),
                          child: SizedBox(
                            height: 200, // Ajusta la altura del mapa
                            child: ClientLocationMap(
                              clientLatLng: LatLng(
                                  widget.task.data()['clientLocation'].latitude,
                                  widget.task.data()['clientLocation'].longitude),
                            ),
                          ),
                        ),
                      ],
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
      ),
    );
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

// Función para obtener el ícono correspondiente al estado de la tarea
IconData getIconForState(String state) {
  switch (state) {
    case 'Pendiente':
      return Icons.pending_actions;
    case 'En proceso':
      return Icons.play_arrow;
    case 'Finalizada':
      return Icons.check_circle;
    default:
      return Icons.info_outline;
  }
}

// Función para crear un Icon widget con el color correspondiente
Widget getColoredIcon(String state) {
  switch (state) {
    case 'Pendiente':
      return Icon(getIconForState(state), color: Colors.amber); // Color mostaza
    case 'En proceso':
      return Icon(getIconForState(state), color: Colors.lightGreen); // Verde claro
    case 'Finalizada':
      return Icon(getIconForState(state), color: Colors.green); // Verde oscuro
    default:
      return Icon(getIconForState(state));
  }
}