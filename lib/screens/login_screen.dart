import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register_screen.dart';
import 'public/homepage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); 

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future _signInWithEmailAndPassword() async {
    if (_formKey.currentState!.validate()) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .where('password', isEqualTo: passwordController.text.trim())
            .get();

        if (userDoc.docs.isNotEmpty) {
          // Usuario encontrado
          // ignore: unused_local_variable
          UserCredential userCredential = await FirebaseAuth.instance
              .signInWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );
          Navigator.pushReplacement(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(builder: (context) => const HomePage(selectedIndex: 0,)),
          );
        } else {
          // Usuario no encontrado
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Correo o contraseña incorrectos.',
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
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No se encontró ningun usuario con ese correo electrónico.',
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
        } else if (e.code == 'wrong-password') {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Contraseña incorrecta.',
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
        // ... other error codes ...
      } catch (e) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Error al iniciar sesión.',
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
  }

  Future _resetPassword(String email) async {
    if (email.isNotEmpty) {
      try {

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .get();

        if (userDoc.docs.isNotEmpty) {
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
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
              'El correo electrónico no esta asociado a una cuenta.',
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
        // ignore: avoid_print
        print('Error sending password reset email: ${e.toString()}');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(35.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24.0),
                  const Text(
                    'Inicia sesión',
                    style: TextStyle(
                      fontSize: 40.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24.0),
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
                    obscureText: true,
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 16.0,
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
                          final emailController = TextEditingController();
                          return AlertDialog(
                            title: const Text('Recuperar Contraseña'),
                            content: TextField(
                              controller: emailController,
                              decoration: const InputDecoration(
                                hintText: 'Ingresa tu correo electrónico',
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
                                  _resetPassword(emailController.text.trim());
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
                    onPressed: _signInWithEmailAndPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 10.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
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
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(43, 61, 79, 1),
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
          ),
        ),
      ),
    );
  }
}