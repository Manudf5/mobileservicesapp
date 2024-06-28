import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
// ignore: unnecessary_import
import 'package:geolocator_android/geolocator_android.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
// ignore: unnecessary_import
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
// ignore: unused_import
import 'package:geocoding/geocoding.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State {
  String greeting = '';
  String userName = '';
  String userLastName = '';

  @override
  void initState() {
    super.initState();
    _fetchGreetingAndUserName();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
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
        print('Greeting: $greeting, userName: $userName'); // Imprime los valores para comprobar
      });
    }
  }

  // Función para obtener el ID combinado de Firestore
  Future _getCombinedIdFromFirestore(String uid) async {
    QuerySnapshot<Map<String, dynamic>> querySnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .where('uid', isEqualTo: uid)
            .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Center(
          child: Text(
            '',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mostrar el saludo y el nombre solo si están cargados
            if (greeting.isNotEmpty && userName.isNotEmpty)
              AnimatedTextKit(
                animatedTexts: [
                  // Combina el saludo y el nombre en un solo TyperAnimatedText
                  TyperAnimatedText(
                    '¡$greeting, $userName!',
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    speed: const Duration(milliseconds: 50),
                    textAlign: TextAlign.start,
                  ),
                ],
                isRepeatingAnimation: false,
              )
            else
              const CircularProgressIndicator(color: Colors.green),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
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
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey[200],
                      ),
                      child: const Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 16.0),
                            child: Icon(
                              Icons.search,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(width: 16.0),
                          Expanded(
                            child: Text(
                              "¿Que servicio necesitas hoy?",
                              style: TextStyle(
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificacionesScreen(),
                      ),
                    );
                  },
                  child: Container(
                    height: 45,
                    width: 45,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey[200],
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Image.asset(
                      'assets/images/IconNotification.png',
                      height: 22,
                      width: 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildButton(
                    'assets/images/IconHome_Screen.png',
                    'Hogar',
                    context,
                  ),
                  _buildButton(
                    'assets/images/IconWelfare_Screen.png',
                    'Personal',
                    context,
                  ),
                  _buildButton(
                    'assets/images/IconProfessional_Screen.png',
                    'Profesional',
                    context,
                  ),
                  _buildButton(
                    'assets/images/IconEntertainment_Screen.png',
                    'Entretenimiento',
                    context,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildButton(
      String imagePath, String text, BuildContext context) {
    return InkWell(
      onTap: () {
        if (text == 'Hogar') {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const HogarScreen(),
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
            ),
          );
        } else if (text == 'Personal') {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const PersonalScreen(),
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
            ),
          );
        } else if (text == 'Profesional') {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const ProfesionalScreen(),
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
            ),
          );
        } else if (text == 'Entretenimiento') {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const EntretenimientoScreen(),
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey[200],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              imagePath,
              height: 100,
              width: 100,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State createState() => _SearchScreenState();
}

class _SearchScreenState extends State {
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
      _filteredServices = _services;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error al obtener servicios: $e');
      // Manejar el error, mostrar un mensaje al usuario, etc.
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredServices = _services.where((service) =>
          service['serviceName'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('¿Que servicio necesitas hoy?'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                borderRadius: BorderRadius.circular(10),
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
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredServices.isEmpty
                      ? const Center(
                          child: Text('No se encontraron servicios'),
                                                  )
                      : GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 9 / 7,
children: _filteredServices.map((service) {
                            return _buildServiceButton(
                                service['imageUrl'], service['serviceName'], service['id']);
                          }).toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceButton(String imagePath, String text, String serviceId) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocationDetailsScreen(serviceName: text, id: serviceId,),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF08143C),
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start ,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Center(
                child: Image.network(
                  imagePath,
                  height: 90,
                  width: 178,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
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
  State createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Notificaciones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Título de la sección
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Notificaciones recientes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Lista de notificaciones
            Expanded(
              child: ListView.builder(
                itemCount: 5, // Reemplaza con el número real de notificaciones
                itemBuilder: (context, index) {
                  return const ListTile(
                    leading: Icon(Icons.notifications),
                    title: Text('Título de la notificación'),
                    subtitle: Text('Descripción de la notificación'),
                    trailing: Icon(Icons.more_vert),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error al obtener servicios: $e');
      // Manejar el error, mostrar un mensaje al usuario, etc.
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.green,))
            : _services.isEmpty
                ? const Center(
                    child: Text('No hay servicios disponibles, inténtelo de nuevo más tarde'),
                  )
                : GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 9 / 7,
                    children: _services.map((service) {
                      return _buildServiceButton(
                          service['imageUrl'], service['serviceName'], service['id']);
                    }).toList(),
                  ),
      ),
    );
  }

  Widget _buildServiceButton(String imagePath, String text, String serviceId) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocationDetailsScreen(serviceName: text, id: serviceId,),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF08143C),
            width: 2.0,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Center(
                child: Image.network(
                  imagePath,
                  height: 90,
                  width: 178,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
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
      setState(() {});
    } catch (e) {
      // ignore: avoid_print
      print('Error al obtener servicios: $e');
      // Manejar el error, mostrar un mensaje al usuario, etc.
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _services.isEmpty
            ? const Center(
                child: Text('No hay servicios disponibles, inténtelo de nuevo más tarde'),
              )
            : GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 9 / 7,
                children: _services.map((service) {
                  return _buildServiceButton(
                      service['imageUrl'], service['serviceName'], service['id']);
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildServiceButton(String imagePath, String text, String serviceId) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocationDetailsScreen(serviceName: text, id: serviceId,),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF08143C),
            width: 2.0,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Center(
                child: Image.network(
                  imagePath,
                  height: 90,
                  width: 178,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
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
      setState(() {});
    } catch (e) {
      // ignore: avoid_print
      print('Error al obtener servicios: $e');
      // Manejar el error, mostrar un mensaje al usuario, etc.
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _services.isEmpty
            ? const Center(
                child: Text('No hay servicios disponibles, inténtelo de nuevo más tarde'),
              )
            : GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 9 / 7,
                children: _services.map((service) {
                  return _buildServiceButton(
                      service['imageUrl'], service['serviceName'], service['id']);
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildServiceButton(String imagePath, String text, String serviceId) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocationDetailsScreen(serviceName: text, id: serviceId,),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF08143C),
            width: 2.0,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Center(
                child: Image.network(
                  imagePath,
                  height: 90,
                  width: 178,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
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
      setState(() {});
    } catch (e) {
      // ignore: avoid_print
      print('Error al obtener servicios: $e');
      // Manejar el error, mostrar un mensaje al usuario, etc.
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _services.isEmpty
            ? const Center(
                child: Text('No hay servicios disponibles, inténtelo de nuevo más tarde'),
              )
            : GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 9 / 7,
                children: _services.map((service) {
                  return _buildServiceButton(
                      service['imageUrl'], service['serviceName'], service['id']);
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildServiceButton(String imagePath, String text, String serviceId) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocationDetailsScreen(serviceName: text, id: serviceId,),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF08143C),
            width: 2.0,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Center(
                child: Image.network(
                  imagePath,
                  height: 90,
                  width: 178,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
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
  LatLng? _selectedLatLng; // Coordenadas de la ubicación seleccionada por el usuario
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
      _locationPermissionGranted =
          permission == LocationPermission.always ||
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
        _markerLatLng = _selectedLatLng; // Inicializar _markerLatLng con la ubicación actual
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
      selectedServiceName = '${selectedServiceName.substring(0, 25)}...';
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(selectedServiceName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              "¿En donde requieres del servicio?",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Ingrese su ubicación en la barra de búsqueda o para mayor precisión, seleccione su dirección interactuando dentro del mapa:",
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 15),
            Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
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
                        hintText: "Buscar ubicación",
                        border: InputBorder.none,
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
                ],
              ),
            ),
            if (_isLoadingSuggestions)
              const Center(
                child: CircularProgressIndicator(color: Colors.green,),
              )
            else if (_suggestions.isNotEmpty)
              SizedBox(
                height: 150,
                child: ListView.builder(
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ListTile(
                      title: Text(suggestion['place_name']),
                      subtitle: Text(suggestion['properties']['text'] ?? ''),
                      onTap: () {
                        _searchController.text = suggestion['place_name'];
                        // Convertimos el place_id a una cadena de texto
                        _selectedLatLng = LatLng(
                            suggestion['geometry']['coordinates'][1],
                            suggestion['geometry']['coordinates'][0]);
                        _markerLatLng = _selectedLatLng; // Actualizar _markerLatLng al seleccionar una sugerencia
                        mapController.move(_selectedLatLng!, 15);
                        setState(() {
                          _suggestions = [];
                        });
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: PopupScope(
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    center: _selectedLatLng ??
                        const LatLng(10.4806, -66.9036), // Caracas
                    zoom: _selectedLatLng != null ? 15 : 5, // Zoom inicial
                    interactiveFlags: InteractiveFlag.all,
                    onTap: (tapPosition, latLng) {
                      setState(() {
                        _selectedLatLng = latLng;
                        _markerLatLng = latLng; // Actualizar _markerLatLng al tocar el mapa
                        print('Latitud: ${_markerLatLng?.latitude}'); // Imprimir las coordenadas
                        print('Longitud: ${_markerLatLng?.longitude}'); // Imprimir las coordenadas
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
                          if (_markerLatLng != null) // Usar _markerLatLng aquí
                            Marker(
                              width: 80,
                              height: 80,
                              point: _markerLatLng!,
                              builder: (ctx) => const Icon(Icons.location_pin,
                                  color: Colors.green, size: 40),
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
            const SizedBox(height: 16),
            TextField(
              controller: _referenceController,
              decoration: InputDecoration(
                labelText: 'Punto de referencia e información adicional',
                labelStyle: const TextStyle(color: Colors.black),
                hintText: 'Ej. Frente a la tienda, cerca del parque...',
                hintStyle: const TextStyle(color: Colors.grey),
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
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _markerLatLng != null
                    ? _saveLocationDetails
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text(
                  'Continuar',
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
    );
  }
}

// Nueva pantalla SelectSuppliersScreen
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
  List<DocumentSnapshot<Map<String, dynamic>>> _suppliers = [];
  List<DocumentSnapshot<Map<String, dynamic>>> _filteredSuppliers = [];
  bool _isLoading = true;
  bool _showFilterDialog = false; 

  // Variables para controlar la selección de filtros
  String _selectedFilter = 'Recomendados'; 
  bool _preciosBajosSelected = false;
  bool _preciosAltosSelected = false;
  bool _mayorCantidadTareasSelected = false;
  bool _masCercanosSelected = false;

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
      QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore
          .instance
          .collection('suppliers')
          .get();
      _suppliers = querySnapshot.docs;

      _filteredSuppliers = _suppliers.where((supplier) {
        if (supplier.data()?['services'] != null &&
            supplier.data()?['permissions'] == 1) {
          bool offersService = supplier.data()?['services'].any((service) {
            return service['service'] == widget.id;
          });

          double distance = calculateDistance(
            widget.latitude,
            widget.longitude,
            supplier.data()?['location'].latitude,
            supplier.data()?['location'].longitude,
          );

          bool withinRange = distance <= 10;

          return offersService && withinRange;
        }
        return false;
      }).toList();

      for (var supplier in _filteredSuppliers) {
        DocumentReference<Map<String, dynamic>> userDocRef =
            FirebaseFirestore.instance.collection('users').doc(supplier.id);

        userDocRef.snapshots().listen((userDoc) {
          if (userDoc.exists) {
            supplier.reference.update({
              'profileImageUrl': userDoc.data()?['profileImageUrl'],
              'assessment': userDoc.data()?['assessment']
            }).then((_) {
            });
          }
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error al obtener proveedores: $e');
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
      double hourlyRateA = double.tryParse(a.data()?['services']
              .firstWhere((service) => service['service'] == widget.id)['hourlyRate'].toString() ?? '0') ?? 0.0;
      double hourlyRateB = double.tryParse(b.data()?['services']
              .firstWhere((service) => service['service'] == widget.id)['hourlyRate'].toString() ?? '0') ?? 0.0;

      return hourlyRateA.compareTo(hourlyRateB);
    });
  }

  void _sortSuppliersByPriceDescending() {
    _filteredSuppliers.sort((a, b) {
      double hourlyRateA = double.tryParse(a.data()?['services']
              .firstWhere((service) => service['service'] == widget.id)['hourlyRate'].toString() ?? '0') ?? 0.0;
      double hourlyRateB = double.tryParse(b.data()?['services']
              .firstWhere((service) => service['service'] == widget.id)['hourlyRate'].toString() ?? '0') ?? 0.0;

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
    setState(() {
      _selectedFilter = filter; 
      _showFilterDialog = false; 
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
        _filteredSuppliers = _suppliers.where((supplier) {
          if (supplier.data()?['services'] != null &&
              supplier.data()?['permissions'] == 1) {
            bool offersService = supplier.data()?['services'].any((service) {
              return service['service'] == widget.id;
            });

            double distance = calculateDistance(
              widget.latitude,
              widget.longitude,
              supplier.data()?['location'].latitude,
              supplier.data()?['location'].longitude,
            );

            bool withinRange = distance <= 10;

            return offersService && withinRange;
          }
          return false;
        }).toList();
        break;
    }
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: const Text(
          'Selecciona a tu agente',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _showFilterDialog = true; 
              });
            },
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
                  _selectedFilter == 'Recomendados'
                      ? 'Recomendados'
                      : 'Resultados por $_selectedFilter', 
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16.0),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
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
                                  padding: const EdgeInsets.only(
                                      bottom: 10.0), 
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

  Widget _buildSupplierButton(
      DocumentSnapshot<Map<String, dynamic>> supplier) {
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
              reference: widget.reference, // Pasa la referencia del proveedor
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
                    'ID: ${supplier.id}',
                    style: const TextStyle(fontSize: 8.0),
                  ),
                  Text(
                    '${supplier.data()?['name']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    widget.serviceName,
                    style: const TextStyle(
                        fontSize: 14.0, fontStyle: FontStyle.italic), 
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
                        color: Color(0xFF1ca424),
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        '${supplier.data()?['assessment'] ?? 'Sin calificación'}',
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
                hourlyRate == 0.0 ? 'Gratis' : '\$${hourlyRate.toStringAsFixed(2)}/hr',
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
              onPressed: () => onMayorCantidadTareasSelected(
                  !mayorCantidadTareasSelected),
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
            color: isSelected
                ? const Color(0xFF08143C)
                : const Color(0xFF08143C), 
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
  final String reference; // Referencia del proveedor

  const SelectedSuppliersScreen({
    super.key,
    required this.selectedSupplier,
    required this.serviceName,
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.reference, // Referencia del proveedor
  });

  @override
  State<SelectedSuppliersScreen> createState() =>
      _SelectedSuppliersScreenState();
}

class _SelectedSuppliersScreenState extends State<SelectedSuppliersScreen>
    with SingleTickerProviderStateMixin {
  bool _showProfileImage = false;
  bool _showReservationModal = false;
  final _reservationTextController = TextEditingController();
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this, // 'this' se refiere al widget State
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Comienza fuera de la pantalla
      end: Offset.zero, // Termina visible
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut, // Curva de animación suave
      ),
    );
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
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: const Text(
          'Agente seleccionado',
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
                          backgroundImage: widget.selectedSupplier.data()?['profileImageUrl'] !=
                                  null
                              ? NetworkImage(
                                  widget.selectedSupplier.data()?['profileImageUrl'])
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
                      '${widget.selectedSupplier.data()?['name']}',
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
                            '${widget.selectedSupplier.data()?['assessment'] ?? 'Sin calificación'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // ID del agente
                Text(
                  'ID: ${widget.selectedSupplier.id}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 10),
                // Servicio seleccionado
                Text(
                  'Servicio: ${widget.serviceName}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                // Tarifa por hora del agente
                Text(
                  'Tarifa por hora: ${_getHourlyRate(widget.selectedSupplier, widget.id)}', // Llama a _getHourlyRate con el id
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
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
                      backgroundImage: widget.selectedSupplier.data()?['profileImageUrl'] !=
                              null
                          ? NetworkImage(
                              widget.selectedSupplier.data()?['profileImageUrl'])
                          : const AssetImage(
                              'assets/images/ProfilePhoto_predetermined.png'),
                    ),
                  ),
                ),
              ),
            ),

          // Ventana de reserva
          if (_showReservationModal)
            SlideTransition(
              position: _slideAnimation,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showReservationModal = false;
                    _animationController.reverse(); // Invierte la animación
                  });
                },
                child: Stack(
                  children: [
                    // Fondo opaco oscuro
                    Container(
                      color: Colors.black.withOpacity(0.5),
                    ),
                    // Ventana de reserva
                    Positioned(
                      bottom: 0, // Posiciona la ventana en la parte inferior
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: const BoxDecoration(
                          color: Colors.white, // Color de fondo del diálogo
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(25.0),
                            topRight: Radius.circular(25.0),
                          ), // Redondear las esquinas superiores
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Detalles de la Reserva',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF08143C), // Color del texto
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Campo de texto para el motivo de la reserva
                            TextField(
                              controller: _reservationTextController,
                              maxLines: 6,
                              style: const TextStyle(color: Color(0xFF08143C)), // Color del texto
                              decoration:  InputDecoration(
                                hintText:
                                'Ingrese el motivo de la reserva y especificaciones de su solicitud (máx. 500 caracteres)',
                                hintStyle: const TextStyle(color: Colors.black), // Color del texto de la sugerencia
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20),),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Botón para confirmar la reserva
                            ElevatedButton(
                              onPressed: () {
                                // Aquí puedes implementar la lógica para procesar la reserva
                                print(
                                    'Confirmar reserva con detalles: ${_reservationTextController.text}');
                                setState(() {
                                  _showReservationModal = false;
                                  _animationController.reverse();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1ca424),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 15,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Confirmar reserva',
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // FloatingActionButton
      floatingActionButton: _showReservationModal
          ? null // Ocultar el botón
          : SizedBox(
        width: double.infinity, // Ocupar todo el ancho de la pantalla
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: ElevatedButton(
            onPressed: () async { // Uso de async
              setState(() {
                _showReservationModal = true;
              });
              // Esperar a que _animationController esté inicializado
              await Future.delayed(Duration.zero);
              _animationController.forward(); 
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1ca424),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 15,
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Reservar servicio',
            ),
          ),
        ),
      ),
      // Quitar el espacio alrededor del botón
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
      return 'Gratis';
    } else {
      return '\$${hourlyRate.toStringAsFixed(2)}';
    }
  }
}