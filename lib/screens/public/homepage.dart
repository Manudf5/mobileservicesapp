import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile.dart';
import 'tasks.dart';
import 'home.dart';
import 'social.dart';
import 'wallet.dart';

class HomePage extends StatefulWidget {
  final int selectedIndex;
  const HomePage({super.key, required this.selectedIndex});

  @override
  // ignore: library_private_types_in_public_api
  _HomePageState createState() => _HomePageState(); 
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  DateTime? _lastPressedAt;
  int _unreadChatsCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
    _fetchUnreadChatsCount(); 
  }

  Future<void> _fetchUnreadChatsCount() async {
    String combinedId = await _getCombinedIdFromFirestore(
        FirebaseAuth.instance.currentUser!.uid);

    FirebaseFirestore.instance
        .collection('chats')
        .where('clientID', isEqualTo: combinedId)
        .where('unreadCountClient', isGreaterThan: 0) 
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _unreadChatsCount = snapshot.docs.length;
      });
    });
  }

  Future<String> _getCombinedIdFromFirestore(String uid) async {
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

  final List<Widget> _screens = [
    const HomeScreen(),
    const SocialScreen(),
    const TasksScreen(),
    const WalletScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) {
          return;
        }
        final now = DateTime.now();
        if (_lastPressedAt == null || 
            now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Presiona de nuevo para salir'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: _screens[_selectedIndex],
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
              icon: Stack(
                alignment: Alignment.topRight,
                children: [
                  Image.asset(
                    _selectedIndex == 1
                        ? 'assets/images/IconSocial_selected.png'
                        : 'assets/images/IconSocial.png',
                    width: 24,
                    height: 24,
                  ),
                  if (_unreadChatsCount > 0)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      child: Text(
                        '$_unreadChatsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 6,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
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
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        ),
      ),
    );
  }
}