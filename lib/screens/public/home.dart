import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
// ignore: unnecessary_import
import 'package:geolocator_android/geolocator_android.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
// ignore: unnecessary_import
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
// ignore: unused_import
import 'package:geocoding/geocoding.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:mobileservicesapp/screens/public/homepage.dart';
import 'package:mobileservicesapp/screens/public/profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String greeting = '';
  String userName = '';
  int _unreadNotificationsCount = 0;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _fetchGreetingAndUserName();
    _fetchUnreadNotificationsCount();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future _fetchGreetingAndUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Obtén el ID combinado del usuario de Firestore
      String combinedId = await _getCombinedIdFromFirestore(user.uid);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(combinedId)
          .get();

      setState(() {
        userName = userDoc.data()?['name'] ?? '';
        final hour = DateTime.now().hour;
        if (hour >= 5 && hour < 12) {
          greeting = 'Buenos días';
        } else if (hour >= 12 && hour < 20) {
          greeting = 'Buenas tardes';
        } else {
          greeting = 'Buenas noches';
        }
        // ignore: avoid_print
        print(
            'Greeting: $greeting, userName: $userName'); // Imprime los valores para comprobar
      });
    }
  }

  // Función para obtener el ID combinado de Firestore
  Future _getCombinedIdFromFirestore(String uid) async {
    QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore
        .instance
        .collection('users')
        .where('uid', isEqualTo: uid)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }

    return '';
  }

  Future<void> _fetchUnreadNotificationsCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String combinedId = await _getCombinedIdFromFirestore(user.uid);

      _notificationSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(combinedId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _unreadNotificationsCount = snapshot.docs.length;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/images/MSA_LogoTemporal.png',
                    height: 60,
                    width: 60,
                  ),
                  GestureDetector(
                    onTap: () {
                      // Navegar a la pantalla de notificaciones
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificacionesScreen(),
                        ),
                      );
                    },
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[200],
                          ),
                          child: Icon(
                            Icons.notifications_none,
                            color: Colors.green[700],
                            size: 28,
                          ),
                        ),
                        if (_unreadNotificationsCount > 0)
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                            ),
                            child: Text(
                              '$_unreadNotificationsCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (greeting.isNotEmpty && userName.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting,',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¿Qué servicio podemos ofrecerte hoy?',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                )
              else
                const CupertinoActivityIndicator(
                  radius: 16,
                  color: Colors.green,
                ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SearchScreen(),
                    ),
                  );
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: Colors.grey[200],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Buscar servicios",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.07,
                  children: [
                    _buildButton(
                        'assets/images/IconHome_Screen.jpg', 'Hogar', context),
                    _buildButton('assets/images/IconWelfare_Screen.jpg',
                        'Personal', context),
                    _buildButton('assets/images/IconProfessional_Screen.jpg',
                        'Profesional', context),
                    _buildButton('assets/images/IconEntertainment_Screen.jpg',
                        'Entretenimiento', context),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildButton(String imagePath, String text, BuildContext context) {
  return GestureDetector(
    onTap: () {
      // Navega a la pantalla correspondiente sin animación
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            switch (text) {
              case 'Hogar':
                return const HogarScreen();
              case 'Personal':
                return const PersonalScreen();
              case 'Profesional':
                return const ProfesionalScreen();
              case 'Entretenimiento':
                return const EntretenimientoScreen();
              default:
                return const HomeScreen();
            }
          },
        ),
      );
    },
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              imagePath,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    ),
  );
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _filteredServices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _fetchServices() async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance.collection('services').get();
      _services = querySnapshot.docs.map((doc) => doc.data()).toList();
      _services.sort((a, b) => a['serviceName'].compareTo(b['serviceName']));
      _filteredServices = _services;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener servicios: $e');
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredServices = _services
          .where((service) => service['serviceName']
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('¿Que servicio necesitas hoy?',
            style: TextStyle(fontSize: 19)),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Colors.grey[200],
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 16.0),
                    child: Icon(
                      Icons.search,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: "Buscar servicio",
                        border: InputBorder.none,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25.0),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CupertinoActivityIndicator(
                      radius: 16,
                      color: Colors.green,
                    ))
                  : _filteredServices.isEmpty
                      ? const Center(
                          child: Text('No se encontraron servicios'),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 16 / 13,
                          ),
                          itemCount: _filteredServices.length,
                          itemBuilder: (context, index) {
                            return _buildServiceButton(
                                _filteredServices[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceButton(Map<String, dynamic> service) {
    return InkWell(
      onTap: () async {
        bool hasPermission =
            await LocationUtils.checkLocationPermission(context);
        if (hasPermission) {
          Navigator.push(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(
              builder: (context) => LocationDetailsScreen(
                serviceName: service['serviceName'],
                id: service['id'],
              ),
            ),
          );
        } else {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Seleccione su ubicación manualmente.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 15),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          await Future.delayed(const Duration(seconds: 0));

          Navigator.push(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(
              builder: (context) => LocationDetailsScreen(
                serviceName: service['serviceName'],
                id: service['id'],
              ),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.blueGrey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: CachedNetworkImage(
                  imageUrl: service['imageUrl'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                service['serviceName'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String combinedId = ''; // El ID combinado del usuario

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    // Obtener el ID combinado del usuario
    combinedId = await _getCombinedId();

    // Cargar las notificaciones desde Firestore
    QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(combinedId)
        .collection('notifications')
        .orderBy('notificationDate', descending: true)
        .get();

    setState(() {
      _notifications = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'title': doc['title'],
          'description': doc['description'],
          'notificationDate': doc['notificationDate'].toDate(),
          'read': doc['read'],
          'NotificationImageUrl': doc.data().containsKey('NotificationImageUrl')
              ? doc['NotificationImageUrl']
              : null,
        };
      }).toList();
      _isLoading = false;
    });
  }

  Future<String> _getCombinedId() async {
    // Aquí obtienes el ID combinado del usuario actual desde Firestore
    final user = FirebaseAuth.instance.currentUser;
    QuerySnapshot<Map<String, dynamic>> querySnapshot = await _firestore
        .collection('users')
        .where('uid', isEqualTo: user!.uid)
        .get();
    return querySnapshot.docs.first.id;
  }

  Future<void> _markAsRead(String notificationId) async {
    // Actualizar el campo "read" a true en Firestore
    await _firestore
        .collection('users')
        .doc(combinedId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Notificaciones de la app',
          style: TextStyle(color: Colors.grey[800], fontSize: 20),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CupertinoActivityIndicator(
                radius: 16,
                color: Colors.green,
              ),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Text(
                    'No tienes notificaciones aún.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: Colors.grey[300]),
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: notification['read']
                              ? Colors.grey[300]
                              : Colors.green[100],
                          child: Icon(
                            notification['read']
                                ? Icons.mark_email_read
                                : Icons.mark_email_unread,
                            color: notification['read']
                                ? Colors.grey
                                : Colors.green,
                          ),
                        ),
                        title: Text(
                          notification['title'],
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800]),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              notification['description'],
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                _formatDateTime(notification['notificationDate']
                                    as DateTime),
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          if (notification['NotificationImageUrl'] != null)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  notification['NotificationImageUrl'],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                        ],
                        onExpansionChanged: (expanded) {
                          if (expanded && !notification['read']) {
                            setState(() {
                              _notifications[index]['read'] = true;
                            });
                            _markAsRead(notification['id']);
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final DateFormat formatter =
        DateFormat('EEEE, dd \'de\' MMMM \'de\' yyyy', 'es_ES');
    final DateFormat timeFormatter = DateFormat('hh:mm a', 'es_ES');

    // Convertir el día de la semana a mayúscula
    String dayOfWeek = formatter.format(dateTime).split(',')[0];
    String capitalizedDayOfWeek =
        dayOfWeek[0].toUpperCase() + dayOfWeek.substring(1);

    return '$capitalizedDayOfWeek, ${formatter.format(dateTime).substring(dayOfWeek.length + 2)} a las ${timeFormatter.format(dateTime)}';
  }
}

class HogarScreen extends StatefulWidget {
  const HogarScreen({super.key});

  @override
  State<HogarScreen> createState() => _HogarScreenState();
}

class _HogarScreenState extends State<HogarScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _fetchServices() async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collection('services')
              .where('id', isGreaterThanOrEqualTo: 'HOG')
              .where('id', isLessThan: 'HOH')
              .get();
      _services = querySnapshot.docs.map((doc) => doc.data()).toList();
      _services.sort((a, b) => a['serviceName'].compareTo(b['serviceName']));
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener servicios: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Servicios para el hogar'),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(
                child: CupertinoActivityIndicator(
                  radius: 16,
                  color: Colors.green,
                ),
              )
            : _services.isEmpty
                ? const Center(
                    child: Text(
                        'No hay servicios disponibles, inténtelo de nuevo más tarde'),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 16 / 13,
                    ),
                    itemCount: _services.length,
                    itemBuilder: (context, index) {
                      return _buildServiceButton(_services[index]);
                    },
                  ),
      ),
    );
  }

  Widget _buildServiceButton(Map<String, dynamic> service) {
    return InkWell(
      onTap: () async {
        bool hasPermission =
            await LocationUtils.checkLocationPermission(context);
        if (hasPermission) {
          Navigator.push(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(
              builder: (context) => LocationDetailsScreen(
                serviceName: service['serviceName'],
                id: service['id'],
              ),
            ),
          );
        } else {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Seleccione su ubicación manualmente.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 15),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          await Future.delayed(const Duration(seconds: 0));

          Navigator.push(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(
              builder: (context) => LocationDetailsScreen(
                serviceName: service['serviceName'],
                id: service['id'],
              ),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.blueGrey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: CachedNetworkImage(
                  imageUrl: service['imageUrl'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                service['serviceName'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PersonalScreen extends StatefulWidget {
  const PersonalScreen({super.key});

  @override
  State<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true; // Variable para controlar el estado de carga

  @override
  void initState() {
    super.initState();
    _fetchServices();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _fetchServices() async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collection('services')
              .where('id', isGreaterThanOrEqualTo: 'PER')
              .where('id', isLessThan: 'PES')
              .get();
      _services = querySnapshot.docs.map((doc) => doc.data()).toList();
      _services.sort((a, b) => a['serviceName'].compareTo(b['serviceName']));
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener servicios: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Servicios Personales'),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(
                child: CupertinoActivityIndicator(
                  radius: 16,
                  color: Colors.green,
                ),
              )
            : _services.isEmpty
                ? const Center(
                    child: Text(
                        'No hay servicios disponibles, inténtelo de nuevo más tarde'),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 16 / 13,
                    ),
                    itemCount: _services.length,
                    itemBuilder: (context, index) {
                      return _buildServiceButton(_services[index]);
                    },
                  ),
      ),
    );
  }

  Widget _buildServiceButton(Map<String, dynamic> service) {
    return InkWell(
      onTap: () async {
        bool hasPermission =
            await LocationUtils.checkLocationPermission(context);
        if (hasPermission) {
          Navigator.push(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(
              builder: (context) => LocationDetailsScreen(
                serviceName: service['serviceName'],
                id: service['id'],
              ),
            ),
          );
        } else {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Seleccione su ubicación manualmente.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 15),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          await Future.delayed(const Duration(seconds: 0));

          Navigator.push(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(
              builder: (context) => LocationDetailsScreen(
                serviceName: service['serviceName'],
                id: service['id'],
              ),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.blueGrey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: CachedNetworkImage(
                  imageUrl: service['imageUrl'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                service['serviceName'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfesionalScreen extends StatefulWidget {
  const ProfesionalScreen({super.key});

  @override
  State<ProfesionalScreen> createState() => _ProfesionalScreenState();
}

class _ProfesionalScreenState extends State<ProfesionalScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true; // Variable para controlar el estado de carga

  @override
  void initState() {
    super.initState();
    _fetchServices();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _fetchServices() async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collection('services')
              .where('id', isGreaterThanOrEqualTo: 'PRO')
              .where('id', isLessThan: 'PRP')
              .get();
      _services = querySnapshot.docs.map((doc) => doc.data()).toList();
      _services.sort((a, b) => a['serviceName'].compareTo(b['serviceName']));
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener servicios: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Servicios Profesionales'),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(
                child: CupertinoActivityIndicator(
                  radius: 16,
                  color: Colors.green,
                ),
              )
            : _services.isEmpty
                ? const Center(
                    child: Text(
                        'No hay servicios disponibles, inténtelo de nuevo más tarde'),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 16 / 13,
                    ),
                    itemCount: _services.length,
                    itemBuilder: (context, index) {
                      return _buildServiceButton(_services[index]);
                    },
                  ),
      ),
    );
  }

  Widget _buildServiceButton(Map<String, dynamic> service) {
    return InkWell(
      onTap: () async {
        bool hasPermission =
            await LocationUtils.checkLocationPermission(context);
        if (hasPermission) {
          Navigator.push(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(
              builder: (context) => LocationDetailsScreen(
                serviceName: service['serviceName'],
                id: service['id'],
              ),
            ),
          );
        } else {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Seleccione su ubicación manualmente.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 15),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          await Future.delayed(const Duration(seconds: 0));

          Navigator.push(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(
              builder: (context) => LocationDetailsScreen(
                serviceName: service['serviceName'],
                id: service['id'],
              ),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.blueGrey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: CachedNetworkImage(
                  imageUrl: service['imageUrl'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                service['serviceName'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EntretenimientoScreen extends StatefulWidget {
  const EntretenimientoScreen({super.key});

  @override
  State<EntretenimientoScreen> createState() => _EntretenimientoScreenState();
}

class _EntretenimientoScreenState extends State<EntretenimientoScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true; // Variable para controlar el estado de carga

  @override
  void initState() {
    super.initState();
    _fetchServices();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _fetchServices() async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collection('services')
              .where('id', isGreaterThanOrEqualTo: 'ENT')
              .where('id', isLessThan: 'ENU')
              .get();
      _services = querySnapshot.docs.map((doc) => doc.data()).toList();
      _services.sort((a, b) => a['serviceName'].compareTo(b['serviceName']));
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener servicios: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Servicios de entretenimiento'),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(
                child: CupertinoActivityIndicator(
                  radius: 16,
                  color: Colors.green,
                ),
              )
            : _services.isEmpty
                ? const Center(
                    child: Text(
                        'No hay servicios disponibles, inténtelo de nuevo más tarde'),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 16 / 13,
                    ),
                    itemCount: _services.length,
                    itemBuilder: (context, index) {
                      return _buildServiceButton(_services[index]);
                    },
                  ),
      ),
    );
  }

  Widget _buildServiceButton(Map<String, dynamic> service) {
    return InkWell(
      onTap: () async {
        bool hasPermission =
            await LocationUtils.checkLocationPermission(context);
        if (hasPermission) {
          Navigator.push(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(
              builder: (context) => LocationDetailsScreen(
                serviceName: service['serviceName'],
                id: service['id'],
              ),
            ),
          );
        } else {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Seleccione su ubicación manualmente.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 15),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          await Future.delayed(const Duration(seconds: 0));

          Navigator.push(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(
              builder: (context) => LocationDetailsScreen(
                serviceName: service['serviceName'],
                id: service['id'],
              ),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.blueGrey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: CachedNetworkImage(
                  imageUrl: service['imageUrl'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                service['serviceName'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationUtils {
  static Future<bool> checkLocationPermission(BuildContext context) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return await showDialog(
            // ignore: use_build_context_synchronously
            context: context,
            builder: (BuildContext context) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on,
                          size: 50, color: Colors.green),
                      const SizedBox(height: 20),
                      const Text(
                        'Solicitud de acceso',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Para ofrecerle una experiencia óptima y resultados más precisos en la búsqueda de agentes disponibles, necesitamos acceder a su ubicación. Su comodidad es importante para nosotros.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop(true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text('Permitir ubicación',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ) ??
          false;
    }
    return true;
  }
}

class LocationDetailsScreen extends StatefulWidget {
  final String serviceName;
  final String id; // Agregar el ID del servicio

  const LocationDetailsScreen(
      {super.key, required this.serviceName, required this.id});

  @override
  State createState() => _LocationDetailsScreenState();
}

class _LocationDetailsScreenState extends State<LocationDetailsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  List _suggestions = [];
  bool _isLoadingSuggestions = false;
  // ignore: unused_field
  Position? _currentPosition;
  bool _locationPermissionGranted = false;
  LatLng?
      _selectedLatLng; // Coordenadas de la ubicación seleccionada por el usuario
  LatLng? _markerLatLng; // Coordenadas del marcador en el mapa
  MapController mapController = MapController();

  final String _mapboxAccessToken =
      'pk.eyJ1IjoibWFudWRmNSIsImEiOiJjbHhqMjZmd3oxbWlyMmxvaGZ2dDAyZ3I0In0.f3Pxh3KWGKMEKuZuq2Wltg';

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
    ));
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    setState(() {
      _locationPermissionGranted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    });
    if (_locationPermissionGranted) {
      _getCurrentLocation();
    }
  }

  Future _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
        _selectedLatLng = LatLng(position.latitude, position.longitude);
        _markerLatLng =
            _selectedLatLng; // Inicializar _markerLatLng con la ubicación actual
        mapController.move(_selectedLatLng!, 15); // Zoom inicial
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error al obtener la ubicación: $e');
    }
  }

  Future _getSuggestions(String query) async {
    setState(() {
      _isLoadingSuggestions = true;
    });

    final response = await http.get(Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=$_mapboxAccessToken&country=ve',
    ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _suggestions = data['features'];
    } else {
      // ignore: avoid_print
      print('Error al obtener sugerencias: ${response.statusCode}');
    }

    setState(() {
      _isLoadingSuggestions = false;
    });
  }

  Future _saveLocationDetails() async {
    // Mostrar la latitud y longitud en consola
    // ignore: avoid_print
    print('Latitud: ${_markerLatLng?.latitude}'); // Usar _markerLatLng aquí
    // ignore: avoid_print
    print('Longitud: ${_markerLatLng?.longitude}'); // Usar _markerLatLng aquí

    // Navegar a la pantalla SelectSuppliersScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectSuppliersScreen(
          serviceName: widget.serviceName,
          id: widget.id, // Pasar el ID del servicio
          latitude: _markerLatLng!.latitude, // Pasar la latitud
          longitude: _markerLatLng!.longitude, // Pasar la longitud
          reference: _referenceController.text, // Pasar el punto de referencia
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String selectedServiceName = widget.serviceName;
    if (selectedServiceName.length > 25) {
      selectedServiceName = '${selectedServiceName.substring(0, 30)}...';
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          selectedServiceName,
          style: TextStyle(color: Colors.grey[800], fontSize: 20),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "¿Dónde requiere el servicio?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Ingrese su ubicación o seleccione en el mapa:",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Buscar ubicación",
                          prefixIcon:
                              Icon(Icons.search, color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onChanged: (text) {
                          if (text.isNotEmpty) {
                            _getSuggestions(text);
                          } else {
                            setState(() {
                              _suggestions = [];
                            });
                          }
                        },
                      ),
                    ),
                    if (_isLoadingSuggestions)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Center(
                            child: CupertinoActivityIndicator(
                          radius: 16,
                          color: Colors.green,
                        )),
                      )
                    else if (_suggestions.isNotEmpty)
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.3,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              title: Text(
                                suggestion['place_name'],
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                suggestion['properties']['text'] ?? '',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () {
                                _searchController.text =
                                    suggestion['place_name'];
                                _selectedLatLng = LatLng(
                                  suggestion['geometry']['coordinates'][1],
                                  suggestion['geometry']['coordinates'][0],
                                );
                                _markerLatLng = _selectedLatLng;
                                mapController.move(_selectedLatLng!, 15);
                                setState(() {
                                  _suggestions = [];
                                });
                                FocusScope.of(context).unfocus();
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: PopupScope(
                          child: FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              center: _selectedLatLng ??
                                  const LatLng(10.4806, -66.9036),
                              zoom: _selectedLatLng != null ? 15 : 5,
                              interactiveFlags: InteractiveFlag.all,
                              onTap: (tapPosition, latLng) {
                                setState(() {
                                  _selectedLatLng = latLng;
                                  _markerLatLng = latLng;
                                  if (kDebugMode) {
                                    print(
                                        'Latitud: ${_markerLatLng?.latitude}');
                                  }
                                  if (kDebugMode) {
                                    print(
                                        'Longitud: ${_markerLatLng?.longitude}');
                                  }
                                });
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                subdomains: const ['a', 'b', 'c'],
                              ),
                              MarkerClusterLayerWidget(
                                options: MarkerClusterLayerOptions(
                                  maxClusterRadius: 20,
                                  disableClusteringAtZoom: 16,
                                  size: const Size(40, 40),
                                  builder: (context, markers) {
                                    return Container(
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.green,
                                      ),
                                      child: Text(
                                        '${markers.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                  polygonOptions: const PolygonOptions(
                                    borderColor: Colors.black,
                                    color: Colors.black12,
                                    borderStrokeWidth: 3,
                                  ),
                                  markers: [
                                    if (_markerLatLng != null)
                                      Marker(
                                        width: 80,
                                        height: 80,
                                        point: _markerLatLng!,
                                        builder: (ctx) => const Icon(
                                            Icons.location_pin,
                                            color: Colors.green,
                                            size: 40),
                                      ),
                                  ],
                                  popupOptions: PopupOptions(
                                    popupSnap: PopupSnap.markerTop,
                                    popupBuilder: (_, marker) => Container(
                                      width: 200,
                                      height: 100,
                                      color: Colors.white,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(_searchController.text),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _referenceController,
                      decoration: InputDecoration(
                        labelText: 'Punto de referencia',
                        hintText: 'Ej. Frente a la tienda, cerca del parque...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed:
                            _markerLatLng != null ? _saveLocationDetails : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 15),
                        ),
                        child: const Text(
                          'Continuar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class SelectSuppliersScreen extends StatefulWidget {
  final String serviceName;
  final String id;
  final double latitude;
  final double longitude;
  final String reference;

  const SelectSuppliersScreen({
    super.key,
    required this.serviceName,
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.reference,
  });

  @override
  State<SelectSuppliersScreen> createState() => _SelectSuppliersScreenState();
}

class _SelectSuppliersScreenState extends State<SelectSuppliersScreen> {
  // ignore: unused_field
  final List<DocumentSnapshot<Map<String, dynamic>>> _suppliers = [];
  List<DocumentSnapshot<Map<String, dynamic>>> _filteredSuppliers = [];
  bool _isLoading = true;
  bool _showFilterDialog = false;

  String _selectedFilter = 'Recomendados';
  bool _preciosBajosSelected = false;
  bool _preciosAltosSelected = false;
  bool _mayorCantidadTareasSelected = false;
  bool _masCercanosSelected = false;
  bool _mounted = true;

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  Future _fetchSuppliers() async {
    try {
      QuerySnapshot<Map<String, dynamic>> suppliersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      _filteredSuppliers = [];

      for (var supplierDoc in suppliersSnapshot.docs) {
        DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
            .instance
            .collection('users')
            .doc(supplierDoc.id)
            .get();

        if (supplierDoc.data()['services'] != null &&
            supplierDoc.data()['solvent'] == true &&
            userDoc.data()?['role'] == 1 &&
            userDoc.data()?['status'] == 0 &&
            userDoc.data()?['profileImageUrl'] != null &&
            userDoc.data()!['profileImageUrl'].toString().isNotEmpty) {
          bool offersService = supplierDoc.data()['services'].any((service) {
            return service['service'] == widget.id;
          });

          double distance = calculateDistance(
            widget.latitude,
            widget.longitude,
            supplierDoc.data()['location'].latitude,
            supplierDoc.data()['location'].longitude,
          );

          bool withinRange = distance <= 25;

          if (offersService && withinRange) {
            _filteredSuppliers.add(supplierDoc);

            supplierDoc.reference.update({
              'profileImageUrl': userDoc.data()?['profileImageUrl'],
              // 'assessment': userDoc.data()?['assessment'] // Ya no se necesita
            });
          }
        }
      }

      // Mezclar la lista de proveedores aleatoriamente
      _filteredSuppliers.shuffle(Random());

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener proveedores: $e');
      }
    }
  }

  Future<int?> getFollowersCount(String supplierId) async {
    try {
      var followersCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(supplierId)
          .collection('followers');

      var snapshot = await followersCollection.get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.length;
      } else {
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener seguidores: $e');
      }
      return null;
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    double dLat = (lat2 - lat1) * (pi / 180);
    double dLon = (lon2 - lon1) * (pi / 180);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;
    return distance;
  }

  void _sortSuppliersByPriceAscending() {
    _filteredSuppliers.sort((a, b) {
      double hourlyRateA = double.tryParse(a
                  .data()?['services']
                  .firstWhere((service) => service['service'] == widget.id)[
                      'hourlyRate']
                  .toString() ??
              '0') ??
          0.0;
      double hourlyRateB = double.tryParse(b
                  .data()?['services']
                  .firstWhere((service) => service['service'] == widget.id)[
                      'hourlyRate']
                  .toString() ??
              '0') ??
          0.0;

      return hourlyRateA.compareTo(hourlyRateB);
    });
  }

  void _sortSuppliersByPriceDescending() {
    _filteredSuppliers.sort((a, b) {
      double hourlyRateA = double.tryParse(a
                  .data()?['services']
                  .firstWhere((service) => service['service'] == widget.id)[
                      'hourlyRate']
                  .toString() ??
              '0') ??
          0.0;
      double hourlyRateB = double.tryParse(b
                  .data()?['services']
                  .firstWhere((service) => service['service'] == widget.id)[
                      'hourlyRate']
                  .toString() ??
              '0') ??
          0.0;

      return hourlyRateB.compareTo(hourlyRateA);
    });
  }

  void _sortSuppliersByDistanceAscending() {
    _filteredSuppliers.sort((a, b) {
      double distanceA = calculateDistance(
        widget.latitude,
        widget.longitude,
        a.data()?['location'].latitude,
        a.data()?['location'].longitude,
      );
      double distanceB = calculateDistance(
        widget.latitude,
        widget.longitude,
        b.data()?['location'].latitude,
        b.data()?['location'].longitude,
      );

      return distanceA.compareTo(distanceB);
    });
  }

  void _applyFilter(String filter) {
    if (!_mounted) return;

    setState(() {
      _selectedFilter = filter;
    });

    switch (filter) {
      case 'Precios bajos':
        _sortSuppliersByPriceAscending();
        break;
      case 'Precios altos':
        _sortSuppliersByPriceDescending();
        break;
      case 'Más cercanos':
        _sortSuppliersByDistanceAscending();
        break;
      case 'Recomendados':
        _fetchRecommendedSuppliers();
        break;
      case 'Mayor cantidad de tareas completadas':
        // Implementa esta función si es necesario
        break;
    }
  }

  Future<void> _fetchRecommendedSuppliers() async {
    try {
      QuerySnapshot<Map<String, dynamic>> suppliersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      List<DocumentSnapshot<Map<String, dynamic>>> recommendedSuppliers = [];

      for (var supplierDoc in suppliersSnapshot.docs) {
        DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
            .instance
            .collection('users')
            .doc(supplierDoc.id)
            .get();

        if (supplierDoc.data()['services'] != null &&
            supplierDoc.data()['solvent'] == true &&
            userDoc.data()?['role'] == 1 &&
            userDoc.data()?['status'] == 0 &&
            userDoc.data()?['profileImageUrl'] != null &&
            userDoc.data()!['profileImageUrl'].toString().isNotEmpty) {
          bool offersService = supplierDoc.data()['services'].any((service) {
            return service['service'] == widget.id;
          });

          double distance = calculateDistance(
            widget.latitude,
            widget.longitude,
            supplierDoc.data()['location'].latitude,
            supplierDoc.data()['location'].longitude,
          );

          bool withinRange = distance <= 25;

          if (offersService && withinRange) {
            recommendedSuppliers.add(supplierDoc);

            supplierDoc.reference.update({
              'profileImageUrl': userDoc.data()?['profileImageUrl'],
              // 'assessment': userDoc.data()?['assessment'] // Ya no se necesita
            });
          }
        }
      }

      // Mezclar la lista de proveedores recomendados aleatoriamente
      recommendedSuppliers.shuffle(Random());

      setState(() {
        _filteredSuppliers = recommendedSuppliers;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener proveedores recomendados: $e');
      }
    }
  }

  void _showFilterOptions() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_list,
                        size: 50, color: Colors.green),
                    const SizedBox(height: 20),
                    const Text(
                      'Filtros de búsqueda',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Selecciona un filtro para organizar los resultados de tu búsqueda.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildFilterOption(
                        'Recomendados', setDialogState, dialogContext),
                    _buildFilterOption(
                        'Precios bajos', setDialogState, dialogContext),
                    _buildFilterOption(
                        'Precios altos', setDialogState, dialogContext),
                    _buildFilterOption(
                        'Más cercanos', setDialogState, dialogContext),
                    _buildFilterOption('Mayor cantidad de tareas completadas',
                        setDialogState, dialogContext),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOption(String filterName, StateSetter setDialogState,
      BuildContext dialogContext) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton(
        onPressed: () {
          setDialogState(() {
            _selectedFilter = filterName;
          });
          Navigator.of(dialogContext).pop();
          if (_mounted) {
            _applyFilter(filterName);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedFilter == filterName
              ? Colors.green
              : Colors.blueGrey[50],
          foregroundColor:
              _selectedFilter == filterName ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          side: const BorderSide(
            color: Color(0xFF08143C),
          ),
        ),
        child: Text(filterName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
          ),
        ),
        title: const Text(
          'Selecciona a tu agente',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            onPressed: _showFilterOptions,
            icon: const Icon(Icons.filter_list, color: Colors.black),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 25.0),
                Text(
                  'Ordenado por $_selectedFilter',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16.0),
                Expanded(
                  child: _isLoading
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Center(
                              child: CupertinoActivityIndicator(
                                radius: 16,
                                color: Colors.green,
                              ),
                            ),
                            SizedBox(height: 8.0),
                            Text(
                              'Buscando agentes',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        )
                      : _filteredSuppliers.isEmpty
                          ? const Center(
                              child: Text('No se encontraron agentes'),
                            )
                          : ListView.builder(
                              itemCount: _filteredSuppliers.length,
                              shrinkWrap: true,
                              padding: const EdgeInsets.only(top: 10.0),
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: _buildSupplierButton(
                                      _filteredSuppliers[index]),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          if (_showFilterDialog)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showFilterDialog = false;
                  });
                },
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showFilterDialog ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_showFilterDialog)
            Center(
              child: FilterDialog(
                onFilterApplied: _applyFilter,
                preciosBajosSelected: _preciosBajosSelected,
                preciosAltosSelected: _preciosAltosSelected,
                mayorCantidadTareasSelected: _mayorCantidadTareasSelected,
                masCercanosSelected: _masCercanosSelected,
                onPreciosBajosSelected: (value) {
                  setState(() {
                    _preciosBajosSelected = value;
                    _preciosAltosSelected = false;
                    _mayorCantidadTareasSelected = false;
                    _masCercanosSelected = false;

                    if (value) {
                      _applyFilter('Precios bajos');
                    } else {
                      _applyFilter('Recomendados');
                    }
                  });
                },
                onPreciosAltosSelected: (value) {
                  setState(() {
                    _preciosAltosSelected = value;
                    _preciosBajosSelected = false;
                    _mayorCantidadTareasSelected = false;
                    _masCercanosSelected = false;

                    if (value) {
                      _applyFilter('Precios altos');
                    } else {
                      _applyFilter('Recomendados');
                    }
                  });
                },
                onMayorCantidadTareasSelected: (value) {
                  setState(() {
                    _mayorCantidadTareasSelected = value;
                    _preciosAltosSelected = false;
                    _preciosBajosSelected = false;
                    _masCercanosSelected = false;

                    if (value) {
                      _applyFilter('Mayor cantidad de tareas completadas');
                    } else {
                      _applyFilter('Recomendados');
                    }
                  });
                },
                onMasCercanosSelected: (value) {
                  setState(() {
                    _masCercanosSelected = value;
                    _preciosAltosSelected = false;
                    _preciosBajosSelected = false;
                    _mayorCantidadTareasSelected = false;

                    if (value) {
                      _applyFilter('Más cercanos');
                    } else {
                      _applyFilter('Recomendados');
                    }
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSupplierButton(DocumentSnapshot<Map<String, dynamic>> supplier) {
    double hourlyRate = 0.0;
    if (supplier.data()?['services'] != null) {
      for (var service in supplier.data()?['services']) {
        if (service['service'] == widget.id) {
          hourlyRate = service['hourlyRate'] != null
              ? double.tryParse(service['hourlyRate'].toString()) ?? 0.0
              : 0.0;
          break;
        }
      }
    }

    double distance = calculateDistance(
      widget.latitude,
      widget.longitude,
      supplier.data()?['location'].latitude,
      supplier.data()?['location'].longitude,
    );

    String formattedDistance;
    if (distance < 1) {
      formattedDistance = '${(distance * 1000).toStringAsFixed(0)} m';
    } else {
      formattedDistance = '${distance.toStringAsFixed(1)} km';
    }

    Future<List<int>> getTaskCounts() async {
      QuerySnapshot<Map<String, dynamic>> tasksSnapshot =
          await FirebaseFirestore.instance.collection('tasks').get();

      int completedTasks = 0;
      int pendingTasks = 0;

      for (var taskDoc in tasksSnapshot.docs) {
        if (taskDoc.data()['supplierID'] == supplier.id) {
          if (taskDoc.data()['state'] == 'Finalizada') {
            completedTasks++;
          } else if (taskDoc.data()['state'] != 'Finalizada' &&
              taskDoc.data()['state'] != 'Cancelada') {
            pendingTasks++;
          }
        }
      }

      return [completedTasks, pendingTasks];
    }

    Future<List<dynamic>> getAverageClientEvaluation() async {
      QuerySnapshot<Map<String, dynamic>> tasksSnapshot =
          await FirebaseFirestore.instance.collection('tasks').get();

      double totalEvaluation = 0;
      int evaluationCount = 0;

      for (var taskDoc in tasksSnapshot.docs) {
        if (taskDoc.data()['supplierID'] == supplier.id &&
            taskDoc.data()['clientEvaluation'] != null) {
          totalEvaluation +=
              double.tryParse(taskDoc.data()['clientEvaluation'].toString()) ??
                  0.0;
          evaluationCount++;
        }
      }

      if (evaluationCount == 0) {
        return ['No disponible', 0];
      } else {
        double averageEvaluation = totalEvaluation / evaluationCount;
        return [averageEvaluation.toStringAsFixed(1), evaluationCount];
      }
    }

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        getTaskCounts(),
        getAverageClientEvaluation(),
        FirebaseFirestore.instance.collection('users').doc(supplier.id).get(),
        getFollowersCount(supplier.id),
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          List<int> taskCounts = snapshot.data![0] as List<int>;
          int completedTasks = taskCounts[0];
          int pendingTasks = taskCounts[1];

          List<dynamic> evaluationData = snapshot.data![1] as List<dynamic>;
          String averageEvaluation = evaluationData[0] as String;
          int evaluationCount = evaluationData[1] as int;

          DocumentSnapshot<Map<String, dynamic>> userDoc =
              snapshot.data![2] as DocumentSnapshot<Map<String, dynamic>>;
          String? bio = userDoc.data()?['bio'];

          int? followersCount = snapshot.data![3] as int?;

          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SelectedSuppliersScreen(
                    selectedSupplier: supplier,
                    serviceName: widget.serviceName,
                    id: widget.id,
                    latitude: widget.latitude,
                    longitude: widget.longitude,
                    reference: widget.reference,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF08143C),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundImage: supplier
                                        .data()?['profileImageUrl'] !=
                                    null
                                ? NetworkImage(
                                    supplier.data()?['profileImageUrl'])
                                : const AssetImage(
                                        'assets/images/ProfilePhoto_predetermined.png')
                                    as ImageProvider,
                          ),
                          if (followersCount != null)
                            Positioned(
                              bottom: -1,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 09,
                                      color: Color.fromARGB(255, 15, 37, 112),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '$followersCount',
                                      style: const TextStyle(
                                        color: Color.fromARGB(255, 15, 37, 112),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (completedTasks < 5)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green[800],
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const Text(
                                        'NUEVO',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                Text(
                                  'ID: ${supplier.id}',
                                  style: const TextStyle(fontSize: 9.0),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              '${supplier.data()?['name']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              widget.serviceName,
                              style: const TextStyle(
                                  fontSize: 12.0, fontStyle: FontStyle.italic),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.social_distance_outlined,
                                  size: 16.0,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 4.0),
                                Text(
                                  formattedDistance,
                                  style: const TextStyle(fontSize: 12.0),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 16.0,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 4.0),
                                Text(
                                  averageEvaluation,
                                  style: const TextStyle(fontSize: 12.0),
                                ),
                                const SizedBox(width: 8.0),
                                Text(
                                  '($evaluationCount ${evaluationCount == 1 ? 'opinión' : 'opiniones'})',
                                  style: const TextStyle(fontSize: 12.0),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 16.0,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    '$completedTasks ${completedTasks == 1 ? 'tarea completada' : 'tareas completadas'}',
                                    style: const TextStyle(fontSize: 12.0),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  if (pendingTasks > 0)
                                    const Icon(
                                      Icons.hourglass_empty,
                                      size: 16.0,
                                      color: Colors.orange,
                                    ),
                                  const SizedBox(width: 4.0),
                                  if (pendingTasks > 0)
                                    Text(
                                      '$pendingTasks ${pendingTasks == 1 ? 'cliente' : 'clientes'} en espera',
                                      style: const TextStyle(fontSize: 12.0),
                                    )
                                  else
                                    const Text(
                                      'DISPONIBLE',
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Text(
                          hourlyRate == 0.0
                              ? 'Cotizado'
                              : '\$${hourlyRate.toStringAsFixed(2)}/hr',
                          style: const TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF08143C)),
                        ),
                      ),
                    ],
                  ),
                  if (bio != null && bio.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return const Center(
              child: CupertinoActivityIndicator(
            radius: 16,
            color: Colors.green,
          ));
        }
      },
    );
  }
}

class FilterDialog extends StatelessWidget {
  final Function(String filter) onFilterApplied;
  final bool preciosBajosSelected;
  final bool preciosAltosSelected;
  final bool mayorCantidadTareasSelected;
  final bool masCercanosSelected;
  final ValueChanged onPreciosBajosSelected;
  final ValueChanged onPreciosAltosSelected;
  final ValueChanged onMayorCantidadTareasSelected;
  final ValueChanged onMasCercanosSelected;

  const FilterDialog({
    super.key,
    required this.onFilterApplied,
    required this.preciosBajosSelected,
    required this.preciosAltosSelected,
    required this.mayorCantidadTareasSelected,
    required this.masCercanosSelected,
    required this.onPreciosBajosSelected,
    required this.onPreciosAltosSelected,
    required this.onMayorCantidadTareasSelected,
    required this.onMasCercanosSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Filtros de búsqueda',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16.0),
            _buildFilterItem(
              label: 'Recomendados',
              isSelected: false,
              onPressed: () {
                onFilterApplied('Recomendados');
              },
            ),
            _buildFilterItem(
              label: 'Precios bajos',
              isSelected: preciosBajosSelected,
              onPressed: () => onPreciosBajosSelected(!preciosBajosSelected),
            ),
            _buildFilterItem(
              label: 'Precios altos',
              isSelected: preciosAltosSelected,
              onPressed: () => onPreciosAltosSelected(!preciosAltosSelected),
            ),
            _buildFilterItem(
              label: 'Mayor cantidad de tareas completadas',
              isSelected: mayorCantidadTareasSelected,
              onPressed: () =>
                  onMayorCantidadTareasSelected(!mayorCantidadTareasSelected),
            ),
            _buildFilterItem(
              label: 'Más cercanos',
              isSelected: masCercanosSelected,
              onPressed: () => onMasCercanosSelected(!masCercanosSelected),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterItem({
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(
            color: Color(0xFF08143C),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: isSelected
              ? const Color(0xFF08143C).withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color:
                isSelected ? const Color(0xFF08143C) : const Color(0xFF08143C),
          ),
        ),
      ),
    );
  }
}

class SelectedSuppliersScreen extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> selectedSupplier;
  final String serviceName;
  final String id;
  final double latitude;
  final double longitude;
  final String reference;

  const SelectedSuppliersScreen({
    super.key,
    required this.selectedSupplier,
    required this.serviceName,
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.reference,
  });

  @override
  State<SelectedSuppliersScreen> createState() =>
      _SelectedSuppliersScreenState();
}

class _SelectedSuppliersScreenState extends State<SelectedSuppliersScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  // ignore: unused_field
  late Animation<Offset> _slideAnimation;
  final TextEditingController _reservationTextController =
      TextEditingController();

  String clientIDString = "";
  String clientName = "";

  bool _hasMobilePayment = false;
  bool _hasZinli = false;
  bool _hasPaypal = false;
  bool _hasBinance = false;
  bool _hasZelle = false;

  bool _isSupplierVerified = false;
  String supplierName = '';
  String supplierLastName = '';

  late Future<void> _initFuture;

  // Variable para almacenar la URL de la imagen de portada
  String? _coverImageUrl;

  final Map<String, Color> _labelColors = {};

  // Método para obtener un color aleatorio para un servicio
  Color _getLabelColor(String service) {
    if (_labelColors.containsKey(service)) {
      return _labelColors[service]!;
    } else {
      Color randomColor = Color(Random().nextInt(0xFFFFFFFF))
          .withOpacity(0.7); // Ajusta la opacidad según sea necesario
      _labelColors[service] = randomColor;
      return randomColor;
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _initFuture = _initializeData();
  }

  Future<void> _initializeData() async {
    await _getUserInfo();
    await _checkPaymentMethods();
    await _getUserCoverImage(); // Nueva función para obtener la imagen de portada
  }

  Future<void> _getUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .get();

      // Obtenemos el documento del usuario
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.selectedSupplier.id)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        setState(() {
          clientName = '${doc['name']} ${doc['lastName']}';
          clientIDString = doc['id'];
          _isSupplierVerified = userDoc.data()?['verified'] ?? false;
          supplierName = userDoc.data()?['name'];
          supplierLastName = userDoc.data()?['lastName'];
        });
      }
    }
  }

  Future<void> _checkPaymentMethods() async {
    final walletDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.selectedSupplier.id)
        .get();

    if (walletDoc.exists) {
      final paymentMethodsCollection =
          walletDoc.reference.collection('paymentMethods');

      final mobilePaymentDoc = await paymentMethodsCollection.doc('mobilePayment').get();
      final paypalDoc = await paymentMethodsCollection.doc('paypal').get();
      final zinliDoc = await paymentMethodsCollection.doc('zinli').get();
      final binanceDoc = await paymentMethodsCollection.doc('binancePay').get();
      final zelleDoc = await paymentMethodsCollection.doc('zelle').get();

      setState(() {
        _hasMobilePayment = mobilePaymentDoc.exists;
        _hasPaypal = paypalDoc.exists;
        _hasZinli = zinliDoc.exists;
        _hasBinance = binanceDoc.exists;
        _hasZelle = zelleDoc.exists;
      });
    }
  }

  // Nueva función para obtener la imagen de portada del usuario
  Future<void> _getUserCoverImage() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.selectedSupplier.id)
        .get();
    if (userDoc.exists) {
      setState(() {
        _coverImageUrl = userDoc.data()?['coverImageUrl'];
      });
    }
  }

  Future<Map<String, dynamic>> _getSupplierRatings(String supplierID) async {
    QuerySnapshot<Map<String, dynamic>> tasksSnapshot =
        await FirebaseFirestore.instance.collection('tasks').get();

    int totalRatings = 0;
    double totalScore = 0;
    Map<int, int> ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    for (var taskDoc in tasksSnapshot.docs) {
      if (taskDoc.data()['supplierID'] == supplierID &&
          taskDoc.data()['clientEvaluation'] != null) {
        int rating = taskDoc.data()['clientEvaluation'] as int;
        totalRatings++;
        totalScore += rating;
        ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
      }
    }

    double averageRating = totalRatings > 0 ? totalScore / totalRatings : 0;

    return {
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'ratingCounts': ratingCounts,
    };
  }

  void _showReportBottomSheet() {
    String selectedReason = '';
    String otherReason = '';
    bool isOtherSelected = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Reportar usuario',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8.0,
                      children: [
                        'Comportamiento inapropiado',
                        'Contenido indebido',
                        'Información falsa',
                        'Incitación negativa',
                        'Ventas ilícitas',
                        'Spam',
                        'Otro',
                      ].map((String reason) {
                        return ChoiceChip(
                          label: Text(
                            reason,
                            style: TextStyle(
                              color: selectedReason == reason
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          selectedColor: selectedReason == reason
                              ? const Color(0xFF08143C)
                              : null,
                          selected: selectedReason == reason,
                          onSelected: (bool selected) {
                            setState(() {
                              selectedReason = selected ? reason : '';
                              isOtherSelected = reason == 'Otro';
                            });
                          },
                          // Add this to change checkmark color
                          selectedShadowColor: Colors.transparent,
                          disabledColor: Colors.transparent,
                          checkmarkColor: Colors.green,
                        );
                      }).toList(),
                    ),
                    if (isOtherSelected) ...[
                      const SizedBox(height: 20),
                      TextFormField(
                        onChanged: (value) {
                          otherReason = value;
                        },
                        decoration: InputDecoration(
                          labelText: 'Especifique el motivo',
                          labelStyle: const TextStyle(color: Colors.black),
                          hintText: 'Ingresa el motivo',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.blueGrey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide:
                                const BorderSide(color: Color(0xFF08143c)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 16.0,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, ingresa el motivo';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1ca424),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () =>
                            _submitReport(selectedReason, otherReason),
                        child: const Text('Enviar reporte'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _submitReport(String selectedReason, String otherReason) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Usuario no autenticado')),
      );
      return;
    }

    final reporterDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: currentUser.uid)
        .get();

    if (reporterDoc.docs.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Error: No se pudo obtener la información del usuario')),
      );
      return;
    }

    final reporterData = reporterDoc.docs.first.data();
    final reportData = {
      'timestamp': FieldValue.serverTimestamp(),
      'reportedUserName': '$supplierName $supplierLastName',
      'reportedUserId': widget.selectedSupplier.id,
      'reason': selectedReason == 'Otro' ? otherReason : selectedReason,
      'category': 'Usuario',
      'reporterName': '${reporterData['name']} ${reporterData['lastName']}',
      'reporterId': reporterDoc.docs.first.id,
    };

    // Generar el ID del documento
    final DateTime now = DateTime.now();
    final String documentId =
        '${widget.selectedSupplier.id}_${now.year}${now.month}${now.day}${now.hour}${now.minute}${now.second}';

    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(documentId)
          .set(reportData);
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte enviado')),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al enviar el reporte')),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _reservationTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Agente seleccionado',
          style: TextStyle(color: Colors.black, fontSize: 17),
        ),
        // Cambiar la flecha de retroceso
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () {
            // Acción a realizar al presionar la flecha de retroceso
            Navigator.pop(context); // Regresar a la pantalla anterior
          },
        ),
        actions: <Widget>[
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (String result) {
              if (result == 'Reportar usuario') {
                _showReportBottomSheet();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'Reportar usuario',
                child: Text('Reportar usuario'),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CupertinoActivityIndicator(
              radius: 20,
              color: Colors.green,
            ));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          return SingleChildScrollView(
            child: Stack(
              children: [
                // Separado para que el padding no afecte la foto de perfil
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      GestureDetector(
                        onTap: () {
                          if (_coverImageUrl != null &&
                              _coverImageUrl!.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImagePreviewScreen(
                                  imageUrl:
                                      _coverImageUrl!, // Pasar la URL obtenida
                                  isCoverImage: true,
                                ),
                              ),
                            );
                          }
                        },
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(13.0),
                            bottomRight: Radius.circular(13.0),
                          ),
                          child:
                              _coverImageUrl == null || _coverImageUrl!.isEmpty
                                  ? Container(
                                      height: 165,
                                      color: const Color(0xFF08143c),
                                    )
                                  : Container(
                                      height: 165, // Ajustar la altura a 165
                                      decoration: BoxDecoration(
                                        image: DecorationImage(
                                          image: NetworkImage(
                                              _coverImageUrl!), // Usar la URL obtenida
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                        ).animate().fadeIn().slideY(),
                      ),
                      Positioned(
                        top: 105,
                        left: 20,
                        child: GestureDetector(
                          onTap: () {
                            final profileImageUrl = widget.selectedSupplier
                                .data()?['profileImageUrl'];
                            if (profileImageUrl != null &&
                                profileImageUrl.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ImagePreviewScreen(
                                    imageUrl: profileImageUrl,
                                    isCoverImage: false,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Hero(
                            tag: 'profileImage',
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4.0,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundImage: widget.selectedSupplier
                                            .data()?['profileImageUrl'] !=
                                        null
                                    ? NetworkImage(widget.selectedSupplier
                                        .data()?['profileImageUrl'])
                                    : const AssetImage(
                                            'assets/images/ProfilePhoto_predetermined.png')
                                        as ImageProvider,
                              ),
                            ),
                          ).animate().fade().scale(),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(top: 141, left: 23.0, right: 23.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Botón Reservar servicio alineado a la derecha
                      Padding(
                        padding: const EdgeInsets.only(top: 0.0),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: TextButton.icon(
                            onPressed: () {
                              _showReservationBottomSheet();
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              // Reduce el ancho y el alto del botón
                              minimumSize: const Size(165.0, 41.0),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              // Agrega esta línea para el borde blanco
                              side: const BorderSide(
                                  color: Colors.white, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            icon: const Icon(Icons.shopping_cart,
                                size: 20), // Icono de carrito de compras
                            label: const Text('¡Reservar ahora!',
                                style: TextStyle(fontSize: 15)),
                          ).animate().fade().scale(),
                        ),
                      ),
                      // Espacio para el botón
                      const SizedBox(height: 30.0),
                      // Nombre del proveedor
                      Row(
                        children: [
                          Text(
                            '$supplierName $supplierLastName', // Concatenate the names
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 5),
                          if (_isSupplierVerified)
                            const Icon(
                              Icons.check_circle,
                              color: Colors.blue,
                              size: 22,
                            ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  FutureBuilder<List<int>>(
                                    future: _getTaskCounts(
                                        widget.selectedSupplier.id),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData &&
                                          snapshot.data![0] < 5) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green[800],
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          child: const Text(
                                            'NUEVO',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ID: ${widget.selectedSupplier.id}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      _buildFollowerCount(),
                      const SizedBox(height: 10),
                      // Agregar la biografía aquí
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.selectedSupplier.id)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CupertinoActivityIndicator(
                              radius: 16,
                              color: Colors.green,
                            );
                          }
                          if (snapshot.hasData && snapshot.data!.exists) {
                            String? bio = snapshot.data!.get('bio') as String?;
                            if (bio != null && bio.isNotEmpty) {
                              return Container(
                                margin:
                                    const EdgeInsets.only(top: 10, bottom: 20),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.0,
                                  ),
                                ),
                                width: double.infinity,
                                child: Text(
                                  bio,
                                  style: const TextStyle(
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }
                          }
                          return const SizedBox
                              .shrink(); // No mostrar el container si no hay biografía
                        },
                      ),
                      // Diseño mejorado para Servicio y Tarifa por hora
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 15),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Servicio:',
                                  style: TextStyle(
                                      color: Colors.black, fontSize: 16),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  widget.serviceName.length > 25
                                      ? '${widget.serviceName.substring(0, 25)}...'
                                      : widget.serviceName,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Modalidad de pago:',
                                  style: TextStyle(
                                      color: Colors.black, fontSize: 16),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _getHourlyRate(
                                      widget.selectedSupplier, widget.id),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Mostrar conteo de tareas completadas y clientes en fila
                      FutureBuilder<List<int>>(
                        future: _getTaskCounts(widget.selectedSupplier.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CupertinoActivityIndicator(
                              radius: 16,
                              color: Colors.green,
                            );
                          }
                          if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          }
                          if (snapshot.hasData) {
                            List<int> taskCounts = snapshot.data!;
                            int completedTasks = taskCounts[0];
                            int pendingTasks = taskCounts[1];
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Mostrar conteo de tareas completadas
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF08143C),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          size: 20.0,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 4.0),
                                        Text(
                                          '$completedTasks ${completedTasks == 1 ? 'tarea completada' : 'tareas completadas'}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.0),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8.0),
                                // Mostrar conteo de clientes en fila o "DISPONIBLE"
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF08143C),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.hourglass_empty,
                                          size: 20.0,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(width: 4.0),
                                        if (pendingTasks > 0)
                                          Text(
                                            '$pendingTasks ${pendingTasks == 1 ? 'cliente' : 'clientes'} en espera',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12.0),
                                          )
                                        else
                                          const Text(
                                            'DISPONIBLE',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12.0,
                                                fontWeight: FontWeight.bold),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return const CupertinoActivityIndicator(
                            radius: 16,
                            color: Colors.green,
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Métodos de pago aceptados:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildPaymentMethod(
                              Icons.account_balance_wallet, 'Monedero'),
                          _buildPaymentMethod(Icons.attach_money, 'Efectivo'),
                          if(_hasMobilePayment)
                            _buildPaymentMethod(
                                Icons.mobile_friendly, 'Pago Móvil'),
                          if(_hasPaypal)
                            _buildPaymentMethodImage(
                                'assets/images/Paypal_Logo.png'),
                          if (_hasBinance)
                            _buildPaymentMethodImage(
                                'assets/images/Binance_Logo.png'),
                          if (_hasZinli)
                            _buildPaymentMethodImage(
                                'assets/images/Zinli_Logo.png'),
                          if (_hasZelle)
                            _buildPaymentMethodImage(
                                'assets/images/Zelle_Logo.png'),
                        ],
                      ),
                      const SizedBox(height: 30),
                      _buildPublicationsCarousel(),
                      const SizedBox(height: 30),
                      _buildRatingsAndReviews(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Nuevo método para mostrar la lista de publicaciones en un BottomSheet
  void _showPublicationsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          // Ajustar la altura del contenedor
          height: MediaQuery.of(context).size.height *
              0.60, // 60% de la altura de la pantalla
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Titulo del BottomSheet
              const Text(
                'Publicaciones relacionadas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // GridView para mostrar las publicaciones
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.selectedSupplier.id)
                      .collection('publications')
                      .where('serviceName', isEqualTo: widget.serviceName)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CupertinoActivityIndicator(
                          radius: 20,
                          color: Colors.green,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('No hay publicaciones disponibles'),
                      );
                    }

                    List<QueryDocumentSnapshot> publications =
                        snapshot.data!.docs;

                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 5,
                        mainAxisSpacing: 5,
                      ),
                      itemCount: publications.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImagePreviewScreen(
                                  imageUrl: publications[index][
                                      'PostImageUrl'], // Pasa la URL de la imagen
                                  isCoverImage: false,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            // Agrega esquinas redondeadas al contenedor de la imagen
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: NetworkImage(
                                    publications[index]['PostImageUrl']),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPublicationsCarousel() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.selectedSupplier.id)
          .collection('publications')
          .where('serviceName', isEqualTo: widget.serviceName)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CupertinoActivityIndicator(
            radius: 16,
            color: Colors.green,
          );
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox(height: 0);
        }

        List<QueryDocumentSnapshot> publications = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Publicaciones relacionadas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Botón para mostrar el BottomSheet con la lista de publicaciones
                IconButton(
                  onPressed: () {
                    _showPublicationsBottomSheet();
                  },
                  icon: const Icon(Icons.grid_view),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (publications.length == 1)
              _buildSinglePublication(publications.first)
            else
              _buildMultiplePublications(publications),
          ],
        );
      },
    );
  }

  Widget _buildSinglePublication(QueryDocumentSnapshot publication) {
    return GestureDetector(
      onTap: () {
        // Navega a ImagePreviewScreen cuando se toca la imagen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImagePreviewScreen(
              imageUrl: publication['PostImageUrl'], // Pasa la URL de la imagen
              isCoverImage: false,
            ),
          ),
        );
      },
      child: Container(
        height: 200,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 5.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.network(
            publication['PostImageUrl'],
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildMultiplePublications(List<QueryDocumentSnapshot> publications) {
    return CarouselSlider(
      options: CarouselOptions(
        height: 200,
        aspectRatio: 16 / 9,
        viewportFraction: 0.8,
        initialPage: 0,
        enableInfiniteScroll: publications.length > 1,
        reverse: false,
        autoPlay: publications.length > 1,
        autoPlayInterval: const Duration(seconds: 3),
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
        autoPlayCurve: Curves.fastOutSlowIn,
        enlargeCenterPage: true,
        scrollDirection: Axis.horizontal,
      ),
      items: publications.map((publication) {
        return Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                // Navega a ImagePreviewScreen cuando se toca la imagen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImagePreviewScreen(
                      imageUrl: publication[
                          'PostImageUrl'], // Pasa la URL de la imagen
                      isCoverImage: false,
                    ),
                  ),
                );
              },
              child: Container(
                width: MediaQuery.of(context).size.width,
                margin: const EdgeInsets.symmetric(horizontal: 5.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    publication['PostImageUrl'],
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildRatingsAndReviews() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getSupplierRatings(widget.selectedSupplier.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CupertinoActivityIndicator(
            radius: 16,
            color: Colors.green,
          );
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        Map<String, dynamic> ratingsData = snapshot.data!;
        double averageRating = ratingsData['averageRating'];
        int totalRatings = ratingsData['totalRatings'];
        Map<int, int> ratingCounts = ratingsData['ratingCounts'];

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título de Calificaciones y Opiniones
              const Text(
                'Calificaciones y Opiniones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF08143C),
                ),
              ),
              const SizedBox(height: 15),
              // Puntuación y Número de Calificaciones
              Row(
                children: [
                  // Puntuación en grande
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF08143C),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Número de calificaciones
                  Text(
                    '($totalRatings)',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Barra de progreso para cada estrella
              for (int i = 5; i >= 1; i--)
                _buildStarRating(i, ratingCounts[i] ?? 0, totalRatings),
              const SizedBox(height: 20),
              // Mostrar las 10 opiniones más recientes
              FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('tasks')
                    .orderBy('end', descending: true)
                    .limit(10)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CupertinoActivityIndicator(
                      radius: 16,
                      color: Colors.green,
                    );
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks =
                      snapshot.data!.docs;

                  return Column(
                    children: tasks
                        .where((task) =>
                            task.data()['supplierID'] ==
                                widget.selectedSupplier.id &&
                            task.data()['clientEvaluation'] != null &&
                            task.data()['clientComment'] != null)
                        .map((task) => _buildClientReview(task))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              // Botón para mostrar todas las opiniones
              if (totalRatings > 0)
                Center(
                  child: TextButton(
                    onPressed: () {
                      _showFullReviewsBottomSheet();
                    },
                    child: const Text(
                      'Ver todas las opiniones',
                      style: TextStyle(
                        color: Color(0xFF08143C),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStarRating(int stars, int count, int total) {
    double percentage = total > 0 ? (count / total) * 100 : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Número de estrellas
          Text('$stars'),
          const SizedBox(width: 5),
          // Estrella llena
          const Icon(Icons.star, size: 16, color: Colors.green),
          const SizedBox(width: 5),
          // Barra de progreso
          Expanded(
            child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                minHeight: 8,
                borderRadius: BorderRadius.circular(30)),
          ),
          const SizedBox(width: 5),
          // Porcentaje de votos
          Text('${percentage.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildClientReview(QueryDocumentSnapshot<Map<String, dynamic>> task) {
    final clientID = task.data()['clientID'];
    final clientEvaluation = task.data()['clientEvaluation'];
    final clientComment = task.data()['clientComment'];
    final taskEndDate = task.data()['end'] as Timestamp?;

    final serviceName =
        task.data()['service'] ?? 'General'; // Obtener el nombre del servicio

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection('users').doc(clientID).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CupertinoActivityIndicator(
            radius: 16,
            color: Colors.green,
          );
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final clientData = snapshot.data!.data();
        final clientName = '${clientData?['name']} ${clientData?['lastName']}';
        final profileImageUrl = clientData?['profileImageUrl'];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: profileImageUrl != null &&
                            profileImageUrl.isNotEmpty
                        ? NetworkImage(profileImageUrl)
                        : const AssetImage(
                                'assets/images/ProfilePhoto_predetermined.png')
                            as ImageProvider,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          for (int i = 0; i < clientEvaluation; i++)
                            const Icon(Icons.star,
                                size: 16, color: Colors.green),
                          for (int i = 0; i < (5 - clientEvaluation); i++)
                            const Icon(Icons.star,
                                size: 16, color: Colors.grey),
                          const SizedBox(width: 5),
                          if (taskEndDate != null)
                            Text(
                              DateFormat('dd/MM/yyyy')
                                  .format(taskEndDate.toDate()),
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(
                          height:
                              3), // Agregar espacio entre el comentario y la etiqueta
                      Container(
                        constraints: const BoxConstraints(maxWidth: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getLabelColor(serviceName),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          serviceName,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                clientComment,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 15),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethod(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodImage(String imagePath) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(imagePath, height: 18.2),
        ],
      ),
    );
  }

  // Widget para mostrar la cantidad de seguidores de manera elegante
  Widget _buildFollowerCount() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.selectedSupplier.id)
          .collection('followers')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CupertinoActivityIndicator();
        }
        if (snapshot.hasError) {
          return const Text('Error');
        }
        final followerCount = snapshot.data?.docs.length ?? 0;

        return Container(
          padding: const EdgeInsets.symmetric(
            vertical: 8.0,
            horizontal: 12.0,
          ),
          width: 170,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.people,
                size: 18.0,
                color: Colors.black,
              ),
              const SizedBox(width: 4.0),
              // Modificaciones para el tamaño del texto
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$followerCount ',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(
                      text: 'seguidores',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Función para mostrar todas las opiniones en un BottomSheet
  void _showFullReviewsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height *
              0.80, // 80% de la altura de la pantalla
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(30.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Título del BottomSheet
              const Text(
                'Todas las opiniones',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF08143C),
                ),
              ),
              const SizedBox(height: 20),
              // Mostrar todas las opiniones
              FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('tasks')
                    .orderBy('end', descending: true)
                    .where('supplierID', isEqualTo: widget.selectedSupplier.id)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CupertinoActivityIndicator(
                        radius: 20,
                        color: Colors.green,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks =
                      snapshot.data!.docs;

                  return Expanded(
                    child: ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        if (task.data()['clientEvaluation'] != null &&
                            task.data()['clientComment'] != null) {
                          return _buildClientReview(task);
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReservationBottomSheet() {
    _animationController.forward();
    List<String> selectedDays = [];
    DateTime selectedTime = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return SlideTransition(
                position: _slideAnimation,
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(30.0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'Detalles de la reserva',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF08143C),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _reservationTextController,
                            maxLines: 4,
                            style: const TextStyle(color: Color(0xFF08143C)),
                            decoration: InputDecoration(
                              hintText: '¿Por qué requiere del servicio?',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(20),
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'Días preferidos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF08143C),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children:
                                ['L', 'M', 'X', 'J', 'V', 'S', 'D'].map((day) {
                              bool isSelected = selectedDays.contains(day);
                              return GestureDetector(
                                onTap: () => setState(() {
                                  isSelected
                                      ? selectedDays.remove(day)
                                      : selectedDays.add(day);
                                }),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF08143C)
                                        : Colors.transparent,
                                    border: Border.all(
                                        color: const Color(0xFF08143C)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      day,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF08143C),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'Hora preferida',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF08143C),
                            ),
                          ),
                          const SizedBox(height: 15),
                          InkWell(
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime:
                                    TimeOfDay.fromDateTime(selectedTime),
                                builder: (BuildContext context, Widget? child) {
                                  return Theme(
                                    data: ThemeData.light().copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Color.fromRGBO(200, 230, 201,
                                            1), // Color principal
                                        onPrimary: Color(
                                            0xFF08143C), // Color del texto sobre el color principal
                                        surface: Colors
                                            .white, // Color de fondo para el dial
                                        onSurface: Color(
                                            0xFF08143C), // Color del texto y números
                                      ),
                                      textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                          foregroundColor: const Color(
                                              0xFF08143C), // Color para los botones de texto
                                        ),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedTime = DateTime(
                                    DateTime.now().year,
                                    DateTime.now().month,
                                    DateTime.now().day,
                                    picked.hour,
                                    picked.minute,
                                  );
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('hh:mm a').format(selectedTime),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF08143C),
                                    ),
                                  ),
                                  const Icon(Icons.access_time,
                                      color: Color(0xFF08143C)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _confirmReservation(
                                  selectedDays, selectedTime),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1ca424),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text('Confirmar reserva'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    ).then((_) {
      _animationController.reverse();
    });
  }

  void _confirmReservation(
      List<String> selectedDays, DateTime selectedTime) async {
    // Primero, obtenemos el ID del usuario actual
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Si no hay usuario actual, mostramos un error
      _showErrorSnackBar(
          'Error de autenticación. Por favor, inicie sesión nuevamente.');
      return;
    }

    // Buscamos el documento del usuario actual en la colección 'users'
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: currentUser.uid)
        .get();

    if (userDoc.docs.isEmpty) {
      _showErrorSnackBar('Error al obtener información del usuario.');
      return;
    }

    final currentUserID = userDoc.docs.first.id;

    // Verificamos si el ID del proveedor es el mismo que el del usuario actual
    if (currentUserID == widget.selectedSupplier.id) {
      _showErrorSnackBar(
          'No es posible reservar sus propios servicios. Por favor, seleccione otro proveedor.');
      return;
    }

    // Continuamos con la verificación de la longitud del texto de reserva
    if (_reservationTextController.text.length < 10) {
      _showErrorSnackBar(
          'Por favor, escriba al menos 10 caracteres describiendo por qué requiere del servicio.');
      return;
    }

    // El resto del código de _confirmReservation() sigue igual...

    final hourlyRate = _getHourlyRate(widget.selectedSupplier, widget.id)
        .replaceAll('\$', '')
        .trim();

    List<String> selectedPaymentMethods = ['Monedero'];

    final taskData = {
      'clientID': clientIDString,
      'clientLocation': GeoPoint(widget.latitude, widget.longitude),
      'clientName': clientName,
      'hourlyRate': double.tryParse(hourlyRate) ?? 0.0,
      'referencePoint': widget.reference.isEmpty ? null : widget.reference,
      'reservation': Timestamp.now(),
      'service': widget.serviceName,
      'serviceDetails': _reservationTextController.text,
      'serviceID': widget.id,
      'state': 'Pendiente',
      'supplierID': widget.selectedSupplier.id,
      'supplierName': widget.selectedSupplier.data()?['name'],
      'paymentMethods': selectedPaymentMethods,
      'preferredDays': selectedDays,
      'preferredTime': Timestamp.fromDate(selectedTime),
    };

    try {
      await FirebaseFirestore.instance.collection('tasks').add(taskData);
      Navigator.pushAndRemoveUntil(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(
          builder: (context) => const HomePage(selectedIndex: 2),
        ),
        (route) => false,
      );
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '¡Servicio reservado con éxito!',
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
    } catch (error) {
      if (kDebugMode) {
        print('Error al guardar la tarea: $error');
      }
      _showErrorSnackBar('Reserva fallida. Por favor, intente nuevamente.');
    }
  }

// Función auxiliar para mostrar SnackBars de error
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 13),
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

  String _getHourlyRate(
      DocumentSnapshot<Map<String, dynamic>> supplier, String id) {
    double hourlyRate = 0.0;
    if (supplier.data()?['services'] != null) {
      for (var service in supplier.data()?['services']) {
        if (service['service'] == id) {
          hourlyRate = service['hourlyRate'] != null
              ? service['hourlyRate'].toDouble()
              : 0.0;
          break;
        }
      }
    }
    if (hourlyRate == 0.0) {
      return 'Por servicio';
    } else {
      return '\$${hourlyRate.toStringAsFixed(2)}/hr';
    }
  }

  // Función para obtener el conteo de tareas completadas y clientes en fila
  Future<List<int>> _getTaskCounts(String supplierID) async {
    QuerySnapshot<Map<String, dynamic>> tasksSnapshot =
        await FirebaseFirestore.instance.collection('tasks').get();

    int completedTasks = 0;
    int pendingTasks = 0;

    for (var taskDoc in tasksSnapshot.docs) {
      if (taskDoc.data()['supplierID'] == supplierID) {
        if (taskDoc.data()['state'] == 'Finalizada') {
          completedTasks++;
        } else if (taskDoc.data()['state'] != 'Finalizada' &&
            taskDoc.data()['state'] != 'Cancelada') {
          pendingTasks++;
        }
      }
    }

    return [completedTasks, pendingTasks];
  }

  // Función para obtener el promedio de evaluaciones del cliente
}
