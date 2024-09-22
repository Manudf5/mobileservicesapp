import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobileservicesapp/screens/public/profile.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'register_screen.dart';
import 'public/homepage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureText = true;
  bool _isLoading = false; // Variable de estado para el indicador de carga

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future _signInWithEmailAndPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final emailLowerCase = emailController.text.trim().toLowerCase();

        // Verificar si el usuario existe en Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: emailLowerCase)
            .get();

        if (userDoc.docs.isEmpty) {
          _showErrorSnackBar('No se encontró ningún usuario con ese correo electrónico.');
          return;
        }

        final userData = userDoc.docs.first.data();
        final userStatus = userData['status'] as int;

        if (userStatus == 1 || userStatus == 2) {
          _showStatusDialog(
              userStatus == 1
                  ? 'Usuario suspendido temporalmente'
                  : 'Usuario suspendido permanentemente',
              'Su cuenta ha sido suspendida. Por favor, contacte a soporte para más información.');
          return;
        }

        // Intentar iniciar sesión
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: emailLowerCase, password: passwordController.text.trim());

        Navigator.pushReplacement(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(builder: (context) => const HomePage(selectedIndex: 0)),
        );
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        if (e.code == 'user-not-found') {
          errorMessage = 'No se encontró ningún usuario con ese correo electrónico.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Contraseña incorrecta.';
        } else if (e.code == 'invalid-credential') {
          errorMessage =
              'Las credenciales proporcionadas son inválidas o han expirado.';
        } else if (e.code == 'too-many-requests') {
          errorMessage =
              'Demasiados intentos fallidos. Esta cuenta ha sido temporalmente suspendida. '
              'Puede restaurarla inmediatamente restableciendo su contraseña o intentarlo más tarde.';
        } else {
          errorMessage = 'Error al iniciar sesión: ${e.message}';
        }
        _showErrorSnackBar(errorMessage);
      } catch (e) {
        if (e.toString().contains(
            'We have blocked all requests from this device due to unusual activity')) {
          _showErrorSnackBar(
              'Se han bloqueado las solicitudes de este dispositivo debido a actividad inusual. '
              'Intente nuevamente más tarde o restablezca su contraseña.');
        } else {
          _showErrorSnackBar('Error inesperado al iniciar sesión.');
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    // Verifica si el contexto está montado y si el ScaffoldMessenger está disponible
    if (_scaffoldMessengerKey.currentState != null) {
      _scaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showStatusDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Entendido',
                  style: TextStyle(color: Color(0xFF08143c))),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future _resetPassword(String email) async {
    if (email.isNotEmpty) {
      try {
        // Convertir el email a minúsculas
        final emailLowerCase = email.toLowerCase();

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: emailLowerCase)
            .get();

        if (userDoc.docs.isNotEmpty) {
          await FirebaseAuth.instance.sendPasswordResetEmail(
              email: emailLowerCase);
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Email de recuperación enviado.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'El correo electrónico no está asociado a una cuenta.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error sending password reset email: ${e.toString()}');
        }
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Por favor, ingrese un correo electrónico.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showHelpBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.question_answer),
                title: const Text('Preguntas frecuentes'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FrequentQuestionsScreen(),
                    ),
                  );
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0, top: 25.0),
                child: Text(
                  'Soporte al usuario',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Correo electrónico'),
                onTap: () async {
                  final Uri emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path: 'msasupport@gmail.com',
                    query: encodeQueryParameters({
                      'subject': 'Soporte de MSA',
                      'body': 'Hola Soporte, necesito ayuda con...'
                    }),
                  );

                  if (await canLaunchUrl(emailLaunchUri)) {
                    await launchUrl(emailLaunchUri);
                  } else {
                    await Clipboard.setData(
                        const ClipboardData(text: 'msasupport@gmail.com'));
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Dirección de correo copiada al portapapeles'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading:
                    Image.asset('assets/images/WhatsApp_Logo.png', height: 24),
                title: const Text('Vía WhatsApp'),
                onTap: () async {
                  final Uri whatsappUrl = Uri.parse(
                      'https://wa.me/584245069119?text=Hola%20Soporte%2C%20necesito%20ayuda%20con...');
                  if (await canLaunchUrl(whatsappUrl)) {
                    await launchUrl(whatsappUrl);
                  } else {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo abrir WhatsApp'),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.black),
              onPressed: _showHelpBottomSheet,
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFE0F2F1)],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(35.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Agrega el logo aquí
                    Image.asset('assets/images/MSA_LogoTemporal.png',
                        height: 100),
                    const SizedBox(height: 35.0),
                    const Text(
                      'Inicia sesión',
                      style: TextStyle(
                        fontSize: 40.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: emailController,
                            decoration: InputDecoration(
                              labelText: 'Correo electrónico',
                              labelStyle: const TextStyle(color: Colors.black),
                              hintText: 'Ingresa tu correo electrónico',
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.transparent,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: const BorderSide(color: Colors.blue),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                    color: Color(0xFF08143c)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 16.0,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingresa tu correo electrónico';
                              }
                              if (!value.contains('@')) {
                                return 'Por favor, ingresa un correo electrónico válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16.0),
                          TextFormField(
                            controller: passwordController,
                            obscureText: _obscureText,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              labelStyle: const TextStyle(color: Colors.black),
                              hintText: 'Ingresa tu contraseña',
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.transparent,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: const BorderSide(color: Colors.blue),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                    color: Color(0xFF08143c)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 16.0,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureText = !_obscureText;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingresa tu contraseña';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 5.0),
                          TextButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  final emailController =
                                      TextEditingController();
                                  return AlertDialog(
                                    title: const Text('Recuperar Contraseña'),
                                    content: TextField(
                                      controller: emailController,
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Ingresa tu correo electrónico',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          _resetPassword(
                                              emailController.text.trim());
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Recibir Código'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: const Text(
                              '¿Olvidé mi contraseña?',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          const SizedBox(height: 18.0),
                          ElevatedButton(
                            onPressed:
                                _isLoading ? null : _signInWithEmailAndPassword,
                            // Deshabilitar el botón mientras se carga
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0, vertical: 10.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: _isLoading
                                ? const CupertinoActivityIndicator(
                                    color: Colors.green) // Mostrar indicador de carga
                                : const Text(
                                    'Ingresar',
                                    style: TextStyle(fontSize: 18.0),
                                  ),
                          ),
                          const SizedBox(height: 50.0),
                          const Text(
                            'O crea una nueva cuenta:',
                            style: TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromRGBO(
                                      43, 61, 79, 1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0, vertical: 10.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                child: const Text(
                                  'Crear cuenta',
                                  style: TextStyle(fontSize: 15.0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}