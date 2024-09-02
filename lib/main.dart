import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobileservicesapp/screens/public/homepage.dart';
import 'screens/intro_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:one_context/one_context.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Añadido

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Obtener el token de registro FCM
  String? fcmToken = await FirebaseMessaging.instance.getToken();
  if (kDebugMode) {
    print('Token de registro FCM: $fcmToken');
  }

  // Actualizar el token FCM en Firestore
  await updateFCMToken(fcmToken);

  runApp(const MyApp());
}

Future<void> updateFCMToken(String? fcmToken) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && fcmToken != null) {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .get()
          .then((querySnapshot) {
        if (querySnapshot.docs.isNotEmpty) {
          querySnapshot.docs.first.reference.update({'tokenFCM': fcmToken});
        } else {
          // Si no existe el documento, lo creamos
          FirebaseFirestore.instance.collection('users').add({
            'uid': user.uid,
            'tokenFCM': fcmToken,
          });
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error al actualizar el token FCM: $e');
      }
    }
  }
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
          popupMenuTheme: const PopupMenuThemeData(
            color: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            textStyle: TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
        ),
        navigatorKey: OneContext().key,
        builder: OneContext().builder,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', ''), // Español
        ],
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
