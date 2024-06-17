import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'package:intl/intl.dart'; // Importa la biblioteca para formatear la fecha

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  bool _acceptTerms = false; // Variable para el checkbox
  late AnimationController _animationController;
  // ignore: unused_field
  late Animation<double> _animation;
  DateTime? _selectedDate; // Variable para guardar la fecha seleccionada
  String? _selectedGender; // Variable para guardar el género seleccionado

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _idLetterController = TextEditingController(); // Letra de identificación
  final _idNumberController = TextEditingController(); // Número de identificación
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneCountryCodeController =
      TextEditingController(); // Código de país del teléfono
  final _phoneNumberController = TextEditingController(); // Número de teléfono
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Future<void> _registerUser() async {
    try {
      // 1. Validación de la casilla de términos y condiciones
      if (!_acceptTerms) {
        // Mostrar un mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes aceptar los términos y condiciones'),
          ),
        );
        return;
      }

      // 2. Validación de la existencia del correo electrónico y número de identificación
      final emailExists = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .get()
          .then((value) => value.docs.isNotEmpty);

      final idExists = await FirebaseFirestore.instance
          .collection('users')
          .where('id', isEqualTo:
              '${_idLetterController.text.trim()}${_idNumberController.text.trim()}')
          .get()
          .then((value) => value.docs.isNotEmpty);

      final phoneExists = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo:
              '${_phoneCountryCodeController.text.trim()}${_phoneNumberController.text.trim()}')
          .get()
          .then((value) => value.docs.isNotEmpty);

      if (emailExists || idExists || phoneExists) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El correo electrónico, ID o número de teléfono ya está registrado'),
          ),
        );
        return;
      }

      // 3. Crea usuario con email y contraseña usando Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 4. Obtén el usuario que se acaba de registrar
      User? user = userCredential.user;

      // 5. Almacena los datos del usuario en Firestore
      if (user != null) {
        String combinedId =
            '${_idLetterController.text.trim()}${_idNumberController.text.trim()}';
        String combinedPhoneNumber =
            '${_phoneCountryCodeController.text.trim()}${_phoneNumberController.text.trim()}'; // Concatenar código y número de teléfono

        await FirebaseFirestore.instance
            .collection('users')
            .doc(combinedId) // Usa el ID combinado como el ID del documento
            .set({
          'name': _nameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'id': combinedId, // Almacena el ID combinado como referencia
          'birthDate': _selectedDate != null
              ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
              : '', // Almacena la fecha seleccionada en formato DD/MM/YYYY
          'email': _emailController.text.trim(),
          'phone': combinedPhoneNumber, // Almacena el número de teléfono combinado
          'uid': user.uid, // Almacena el UID del usuario para referencia futura
          'password': _passwordController.text.trim(), // Almacena la contraseña
          'gender': _selectedGender, // Almacena el género seleccionado
          'acceptTerms': _acceptTerms, // Almacena si el usuario aceptó los términos
          'permissions': 0 // Añade el campo de permisos con valor 0
        });

        // 6. Registro exitoso, navega a LoginScreen y muestra un mensaje
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Registro exitoso!')),
        );
        Navigator.pushReplacement(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        // ignore: avoid_print
        print('The password provided is too weak.');
        // Mostrar mensaje de error al usuario (por ejemplo, con un SnackBar)
      } else if (e.code == 'email-already-in-use') {
        // ignore: avoid_print
        print('The account already exists for that email.');
        // Mostrar mensaje de error al usuario
      }
    } catch (e) {
      // ignore: avoid_print
      print(e);
      // Mostrar mensaje de error genérico al usuario
    }
  }

  Future<void> _presentDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text =
            DateFormat('dd/MM/yyyy').format(_selectedDate!);
      });
    }
  }

  void _showTermsAndConditionsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Términos y Condiciones'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Aquí agrega el contenido de los términos y condiciones
                Text('Término 1: ...'),
                Text('Término 2: ...'),
                // ...
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Icon(
                Icons.close,
                color: Colors.red,
                size: 30.0,
              ), // Icono de cierre en rojo
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set the background color to white
      body: Center( // Centra el formulario vertical y horizontalmente
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 46.0),
                  const Text(
                    'Crea una cuenta',
                    style: TextStyle(
                      fontSize: 28.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Set the text color to black
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  // Nombre
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        labelStyle: const TextStyle(color: Colors.black), // Set the label text color to black
                        hintText: 'Ingresa tu primer nombre',
                        hintStyle: const TextStyle(color: Colors.grey), // Set the hint text color to grey
                        filled: true,
                        fillColor: Colors.transparent, // Set the fill color to transparent
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: const BorderSide(color: Colors.blue), // Set the border color to blue
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 16.0,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa tu nombre';
                        }
                        return null;
                      },
                    ),
                  ),
                  // Apellido
                  const SizedBox(height: 16.0),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Apellido',
                        labelStyle: const TextStyle(color: Colors.black), // Set the label text color to black
                        hintText: 'Ingresa tu primer apellido',
                        hintStyle: const TextStyle(color: Colors.grey), // Set the hint text color to grey
                        filled: true,
                        fillColor: Colors.transparent, // Set the fill color to transparent
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: const BorderSide(color: Colors.blue), // Set the border color to blue
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 16.0,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa tu apellido';
                        }
                        return null;
                      },
                    ),
                  ),
                  // Tipo de Identificación
                  const SizedBox(height: 16.0),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4, // Reducir el espacio para el DropdownButton
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Tipo',
                              labelStyle: TextStyle(color: Colors.black), // Set the label text color to black
                              hintText: 'Tipo',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 16.0),
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                            ),
                            value: _idLetterController.text.isEmpty
                                ? null
                                : _idLetterController.text,
                            onChanged: (value) {
                              setState(() {
                                _idLetterController.text = value!;
                              });
                            },
                            items: const [
                              DropdownMenuItem(
                                value: 'V',
                                child: Text('V'),
                              ),
                              DropdownMenuItem(
                                value: 'E',
                                child: Text('E'),
                              ),
                              DropdownMenuItem(
                                value: 'J',
                                child: Text('J'),
                              ),
                              DropdownMenuItem(
                                value: 'P',
                                child: Text('P'),
                              ),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, selecciona un tipo de identificación';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          flex: 6, // Ampliar el espacio para el TextFormField
                          child: TextFormField(
                            controller: _idNumberController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'ID',
                              labelStyle: const TextStyle(color: Colors.black), // Set the label text color to black
                              hintText: 'ID',
                              hintStyle: const TextStyle(color: Colors.grey), // Set the hint text color to grey
                              filled: true,
                              fillColor: Colors.transparent, // Set the fill color to transparent
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: const BorderSide(color: Colors.blue), // Set the border color to blue
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 16.0,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingresa tu número de identificación';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Fecha de nacimiento
                  const SizedBox(height: 16.0),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: TextFormField(
                      controller: _birthDateController,
                      readOnly: true,
                      onTap: _presentDatePicker,
                      decoration: InputDecoration(
                        labelText: 'Fecha de nacimiento',
                        labelStyle: const TextStyle(color: Colors.black), // Set the label text color to black
                        hintText: 'Selecciona tu fecha de nacimiento',
                        hintStyle: const TextStyle(color: Colors.grey), // Set the hint text color to grey
                        filled: true,
                        fillColor: Colors.transparent, // Set the fill color to transparent
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: const BorderSide(color: Colors.blue), // Set the border color to blue
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 16.0,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, selecciona tu fecha de nacimiento';
                        }
                        return null;
                      },
                    ),
                  ),
                  // Género
                  const SizedBox(height: 18.0),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Género',
                        labelStyle: TextStyle(color: Colors.black), // Set the label text color to black
                        hintText: 'Género',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 16.0),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                        ),
                      ),
                      value: _selectedGender,
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'Masculino',
                          child: Text('Masculino'),
                        ),
                        DropdownMenuItem(
                          value: 'Femenino',
                          child: Text('Femenino'),
                        ),
                        DropdownMenuItem(
                          value: 'Otro',
                          child: Text('Otro'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, selecciona un género';
                        }
                        return null;
                      },
                    ),
                  ),
                  // Correo electrónico
                  const SizedBox(height: 16.0),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico',
                        labelStyle: const TextStyle(color: Colors.black), // Set the label text color to black
                        hintText: 'Ingresa tu correo electrónico',
                        hintStyle: const TextStyle(color: Colors.grey), // Set the hint text color to grey
                        filled: true,
                        fillColor: Colors.transparent, // Set the fill color to transparent
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: const BorderSide(color: Colors.blue), // Set the border color to blue
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
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Por favor, ingresa un correo electrónico válido';
                        }
                        return null;
                      },
                    ),
                  ),
                  // Código de país
                  const SizedBox(height: 16.0),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4, // Reducir el espacio para el DropdownButton
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'País',
                              labelStyle: TextStyle(color: Colors.black), // Set the label text color to black
                              hintText: 'País',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 16.0),
                              border: InputBorder.none,
                            ),
                            value: _phoneCountryCodeController.text.isEmpty
                                ? '+58'
                                : _phoneCountryCodeController.text,
                            onChanged: (value) {
                              setState(() {
                                _phoneCountryCodeController.text = value!;
                              });
                            },
                            items: const [
                              DropdownMenuItem(
                                value: '+58',
                                child: Text('+58'),
                              ),
                              // Agrega más códigos de país aquí
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, selecciona un código de país';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          flex: 6, // Ampliar el espacio para el TextFormField
                          child: TextFormField(
                            controller: _phoneNumberController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'N° Teléfono',
                              labelStyle: const TextStyle(color: Colors.black), // Set the label text color to black
                              hintText: 'N° Teléfono',
                              hintStyle: const TextStyle(color: Colors.grey), // Set the hint text color to grey
                              filled: true,
                              fillColor: Colors.transparent, // Set the fill color to transparent
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: const BorderSide(color: Colors.blue), // Set the border color to blue
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 16.0,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingresa tu número de teléfono';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Contraseña
                  const SizedBox(height: 16.0),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        labelStyle: const TextStyle(color: Colors.black), // Set the label text color to black
                        hintText: 'Ingresa una contraseña mayor a 8 dígitos',
                        hintStyle: const TextStyle(color: Colors.grey), // Set the hint text color to grey
                        filled: true,
                        fillColor: Colors.transparent, // Set the fill color to transparent
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: const BorderSide(color: Colors.blue), // Set the border color to blue
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
                        if (value.length < 8) {
                          return 'La contraseña debe tener al menos 8 caracteres';
                        }
                        return null;
                      },
                    ),
                  ),
                  // Confirmar contraseña
                  const SizedBox(height: 16.0),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirmar contraseña',
                        labelStyle: const TextStyle(color: Colors.black), // Set the label text color to black
                        hintText: 'Repite tu contraseña ingresada',
                        hintStyle: const TextStyle(color: Colors.grey), // Set the hint text color to grey
                        filled: true,
                        fillColor: Colors.transparent, // Set the fill color to transparent
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: const BorderSide(color: Colors.blue), // Set the border color to blue
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 16.0,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, confirma tu contraseña';
                        }
                        if (value != _passwordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  // Casilla de verificación centrada horizontalmente
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0), // Añade padding a la fila
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center, // Centrar horizontalmente
                      children: [
                        Checkbox(
                          value: _acceptTerms, // Se utiliza la variable para el checkbox
                          onChanged: (value) {
                            setState(() {
                              _acceptTerms = value!;
                            });
                          },
                        ),
                        const SizedBox(width: 4.0), // Espacio entre el checkbox y el texto
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.black, fontSize: 13.0 // Reduce el tamaño del texto
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Acepto los ',
                                ),
                                TextSpan(
                                  text: 'términos y condiciones',
                                  style: const TextStyle(
                                    color: Colors.blue, // Color azul para el enlace
                                    decoration: TextDecoration.underline, // Subrayado
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = _showTermsAndConditionsDialog,
                                ),
                                const TextSpan(
                                  text: ' de la empresa',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _registerUser();
                      }
                    },
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
                      'Registrarme',
                      style: TextStyle(fontSize: 18.0),
                    ),
                  ),
                  const SizedBox(height: 5.0),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      '¿Ya tengo cuenta?',
                      style: TextStyle(color: Colors.black), // Set the text color to black
                    ),
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