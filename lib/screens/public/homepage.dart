import 'package:flutter/material.dart';
import 'profile.dart';
import 'tasks.dart';
import 'home.dart';
import 'social.dart'; // Importa el nuevo archivo social.dart

// Define las pantallas para cada botón

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white
      ),
      child: const Center(
        child: Text('Pantalla de Monedero'),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final int selectedIndex;
   const HomePage({super.key, required this.selectedIndex});

  @override
  // ignore: library_private_types_in_public_api
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

    @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex; // Inicializa el estado con el valor del parámetro
  }

  final List<Widget> _screens = [
    const HomeScreen(), // Ahora utiliza HomeScreen de home.dart
    const SocialScreen(),
    const TasksScreen(), // Ahora utiliza TasksScreen de tasks.dart
    const WalletScreen(),
    const ProfileScreen(), // Ahora utiliza ProfileScreen de profile.dart
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _screens[_selectedIndex], // Centra verticalmente el contenido de las pantallas
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              _selectedIndex == 0
                  ? 'assets/images/IconHome_selected.png'
                  : 'assets/images/IconHome.png',
              width: 24,
              height: 24,
            ),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              _selectedIndex == 1
                  ? 'assets/images/IconSocial_selected.png'
                  : 'assets/images/IconSocial.png',
              width: 24,
              height: 24,
            ),
            label: 'Social',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              _selectedIndex == 2
                  ? 'assets/images/IconTasks_selected.png'
                  : 'assets/images/IconTasks.png',
              width: 24,
              height: 24,
            ),
            label: 'Tareas',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              _selectedIndex == 3
                  ? 'assets/images/IconWallet_selected.png'
                  : 'assets/images/IconWallet.png',
              width: 24,
              height: 24,
            ),
            label: 'Monedero',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              _selectedIndex == 4
                  ? 'assets/images/IconUser_selected.png'
                  : 'assets/images/IconUser.png',
              width: 24,
              height: 24,
            ),
            label: 'Perfil',
          ),
        ],
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold), // Estilo para el texto seleccionado
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal), // Estilo para el texto sin seleccionar
      ),
    );
  }
}