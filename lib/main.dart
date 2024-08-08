import 'package:flutter/material.dart';
import 'package:mobileservicesapp/screens/public/homepage.dart';
import 'screens/intro_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:one_context/one_context.dart';


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
    return OneNotification(
      builder: (_, __) => MaterialApp(
        title: 'Mobile App Services',
        theme: ThemeData(
          fontFamily: 'Georgia',
          primarySwatch: Colors.green,
        ),
        navigatorKey: OneContext().key,
        builder: OneContext().builder,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              // Usuario autenticado
              return const HomePage(selectedIndex: 0);
            } else {
              // Usuario no autenticado
              return const IntroScreen();
            }
          },
        ),
      ),
    );
  }
}

//#08143c Azul Oscuro Botones de navegacion
//#1ca424 Verde Botones de navegacion