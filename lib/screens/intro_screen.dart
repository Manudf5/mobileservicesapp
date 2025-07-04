import 'package:flutter/material.dart';
import 'login_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _IntroScreenState createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _introContent = [
    {
      'title': '¡Bienvenido a MSA!',
      'description': 'Tu aplicación personal que solucionará todas tus necesidades.',
      'image': 'assets/images/MSA_LogoTemporal.png',
    },
    {
      'title': 'Servicios para el Hogar',
      'description': 'Encuentra expertos en limpieza, reparaciones y más.',
      'image': 'assets/images/ServicioHogar.png',
    },
    {
      'title': 'Servicios Profesionales',
      'description': 'Conecta con consultores, diseñadores y otros profesionales.',
      'image': 'assets/images/ServicioProfesional.png',
    },
    {
      'title': 'Servicios Personales',
      'description': 'Desde cuidado personal hasta entrenamiento físico.',
      'image': 'assets/images/ServicioPersonal.png',
    },
    {
      'title': 'Entretenimiento',
      'description': 'Organiza eventos o contrata animadores para tus fiestas.',
      'image': 'assets/images/ServicioEntretenimiento.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _introContent.length,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (BuildContext context, int index) {
              return IntroPage(
                title: _introContent[index]['title'],
                description: _introContent[index]['description'],
                imagePath: _introContent[index]['image'],
              );
            },
          ),
          Positioned(
            bottom: 50.0,
            left: 0.0,
            right: 0.0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < _introContent.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        height: 8.0,
                        width: i == _currentPage ? 24.0 : 8.0,
                        decoration: BoxDecoration(
                          color: i == _currentPage ? const Color(0xFF08143c) : Colors.grey,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20.0),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF08143c),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Comenzar',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class IntroPage extends StatelessWidget {
  final String title;
  final String description;
  final String imagePath;

  const IntroPage({
    super.key,
    required this.title,
    required this.description,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFE0F2F1)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (imagePath.contains('MSA_LogoTemporal'))
            Image.asset(
              imagePath,
              height: 250,
            )
          else
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white.withOpacity(0)],
                    stops: const [0.7, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: Image.asset(
                  imagePath,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 40),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF08143c),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}