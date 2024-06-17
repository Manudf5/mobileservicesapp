import 'package:flutter/material.dart';
import 'login_screen.dart';
// Importamos el archivo login_screen.dart

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _IntroScreenState createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Widget> _introPages = [
  // Aquí agregaremos los widgets para cada página de la introducción
  Container(
    decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(112, 139, 169, 1),
              Color.fromRGBO(210, 215, 223, 1),
              Color.fromRGBO(210, 215, 223, 1),
            ],
          ),
        ),
    child: const Center(
      child: Text(
        'Página 1',
        style: TextStyle(fontSize: 24.0, color: Color.fromRGBO(43, 61, 79, 1),),
      ),
    ),
  ),
  Container(
    decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(112, 139, 169, 1),
              Color.fromRGBO(210, 215, 223, 1),
              Color.fromRGBO(210, 215, 223, 1),
            ],
          ),
        ),
    child: const Center(
      child: Text(
        'Página 2',
        style: TextStyle(fontSize: 24.0, color: Color.fromRGBO(43, 61, 79, 1),),
      ),
    ),
  ),
  Container(
    decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(112, 139, 169, 1),
              Color.fromRGBO(210, 215, 223, 1),
              Color.fromRGBO(210, 215, 223, 1),
            ],
          ),
        ),
    child: const Center(
      child: Text(
        'Página 3',
        style: TextStyle(fontSize: 24.0, color: Color.fromRGBO(43, 61, 79, 1),),
      ),
    ),
  ),
  Container(
    decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(112, 139, 169, 1),
              Color.fromRGBO(210, 215, 223, 1),
              Color.fromRGBO(210, 215, 223, 1),
            ],
          ),
        ),
    child: const Center(
      child: Text(
        'Página 4',
        style: TextStyle(fontSize: 24.0, color: Color.fromRGBO(43, 61, 79, 1),),
      ),
    ),
  ),
];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _introPages.length,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (BuildContext context, int index) {
              return _introPages[index];
            },
          ),
          Positioned(
            bottom: 20.0,
            left: 0.0,
            right: 0.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _introPages.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: CircleAvatar(
                      radius: 4.0,
                      backgroundColor:
                          i == _currentPage ? const Color.fromRGBO(43, 61, 79, 1) : const Color.fromRGBO(112, 139, 169, 1),
                    ),
                  ),
                const SizedBox(width: 16.0),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color.fromRGBO(43, 61, 79, 1),),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                   );
                  },
                  child:  const Text('Acceder',style: TextStyle(color: Colors.white),),
               ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}