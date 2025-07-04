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
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configuración de Firestore con persistencia
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Solo inicializar Firebase Messaging si no estamos en la web
  if (!kIsWeb) {
    await initializeFirebaseMessaging();
  }

  runApp(const MyApp());
}

Future<void> initializeFirebaseMessaging() async {
  try {
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (kDebugMode) {
      print('Token de registro FCM: $fcmToken');
    }
    await updateFCMToken(fcmToken);
  } catch (e) {
    if (kDebugMode) {
      print('Error al inicializar Firebase Messaging: $e');
    }
  }
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
              return const HomePage(selectedIndex: 0);
            } else {
              return const IntroScreen();
            }
          },
        ),
      ),
    );
  }
}