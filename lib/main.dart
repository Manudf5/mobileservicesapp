import 'package:flutter/material.dart';
import 'package:mobileservicesapp/screens/public/homepage.dart';
import 'screens/intro_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile App Services',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // Usuario autenticado
            return const HomePage();
          } else {
            // Usuario no autenticado
            return const IntroScreen();
          }
        },
      ),
    );
  }
}

//#08143c Azul Oscuro Botones de navegacion
//#1ca424 Verde Botones de navegacion