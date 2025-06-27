import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/cupertino.dart';
import 'package:mobileservicesapp/screens/public/homepage.dart';
import 'package:mobileservicesapp/screens/public/profile.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'login_screen.dart';

// Importa la biblioteca para formatear la fecha

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _bioController = TextEditingController(); // Controlador para la biografía
  String? _idLetterController = 'V';
  String? _phoneCountryCodeController = '+58';

  DateTime? _selectedDate;
  String? _selectedGender;
  bool _acceptTerms = false;
  File? _idImage;
  bool _isTimerRunning = false;
  int _timerSeconds = 60;
  bool _isLoading = false; // Variable de estado para el indicador de carga
  // ignore: unused_field
  final bool _isEmailVerified = false;
  int _currentPage = 0; // Índice de la página actual

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Parámetros de la contraseña
  bool _hasUpperCase = false;
  bool _hasLowerCase = false;
  bool _hasDigits = false;
  bool _hasSpecialCharacters = false;
  bool _hasMinLength = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _lastNameController.dispose();
    _idNumberController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _bioController
        .dispose(); // No olvides hacer dispose del controlador de biografía
    super.dispose();
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

  Future<void> _takeIdPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _idImage = File(image.path);
      });
    }
  }

  void _startTimer() {
    setState(() {
      _isTimerRunning = true;
      _timerSeconds = 60;
    });
    _runTimer();
  }

  void _runTimer() {
    if (_timerSeconds > 0) {
      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          _timerSeconds--;
        });
        _runTimer();
      });
    } else {
      setState(() {
        _isTimerRunning = false;
      });
    }
  }

  Future<void> _sendEmailVerification() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Por favor, ingresa tu correo electrónico.')));
      return;
    }

    try {
      // Convertir el correo a minúsculas
      String emailLowerCase = _emailController.text.trim().toLowerCase();

      // Crear un usuario temporal
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailLowerCase,
        password: _passwordController.text.trim(),
      );

      // Enviar el correo de verificación
      await userCredential.user!.sendEmailVerification();

      // Iniciar el temporizador
      _startTimer();

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Se ha enviado un correo de verificación. Por favor, revisa tu bandeja de entrada.')));
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al enviar el correo de verificación: $e')));
    }
  }

  Future<void> _registerUser() async {
    // Validar el formulario actual antes de avanzar
    if (_formKey.currentState!.validate()) {
      // Mostrar el indicador de carga
      setState(() {
        _isLoading = true;
      });

      if (!_formKey.currentState!.validate() || !_acceptTerms) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Por favor, completa todos los campos y acepta los términos.')));
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (_currentPage < 3) {
        // Si no estamos en la última página, avanzar a la siguiente
        _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Verificar si el correo electrónico ha sido verificado
      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        User? user = userCredential.user;
        await user?.reload();
        if (user != null && !user.emailVerified) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Por favor, verifica tu correo electrónico antes de registrarte.')));
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error al iniciar sesión: $e");
        }
        // Manejar el error según sea necesario
      }

      try {
        // Convertir el correo a minúsculas
        String emailLowerCase = _emailController.text.trim().toLowerCase();

        // Verificar si el correo electrónico ya está en uso
        final list = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: emailLowerCase)
            .get();
        if (list.docs.isNotEmpty) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('El correo electrónico ya está en uso.')));
          setState(() {
            _isLoading =
                false; // Ocultar el indicador de carga si hay un error
          });
          return;
        }

        // Crea el documento del usuario en Firestore
        String combinedPhone =
            '$_phoneCountryCodeController${_phoneNumberController.text.trim()}';

        // Verificar si el número de teléfono ya está en uso
        final phoneList = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: combinedPhone)
            .get();
        if (phoneList.docs.isNotEmpty) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('El número de teléfono ya está en uso.')));
          setState(() {
            _isLoading =
                false; // Ocultar el indicador de carga si hay un error
          });
          return;
        }

        // Crea el documento del usuario en Firestore
        String combinedId =
            '$_idLetterController${_idNumberController.text.trim()}';

        // Verificar si el número de teléfono ya está en uso
        final iDList = await FirebaseFirestore.instance
            .collection('users')
            .where('id', isEqualTo: combinedId)
            .get();
        if (iDList.docs.isNotEmpty) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('El ID ya está en uso.')));
          setState(() {
            _isLoading =
                false; // Ocultar el indicador de carga si hay un error
          });
          return;
        }

        // El usuario puede que ya esté creado si se verificó el correo
        // Intenta iniciar sesión con las credenciales proporcionadas
        UserCredential? userCredential;
        try {
          userCredential =
              await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: emailLowerCase,
            password: _passwordController.text.trim(),
          );
        } catch (e) {
          // Manejar el error si el usuario no existe o las credenciales son incorrectas
          if (kDebugMode) {
            print('Error al iniciar sesión: $e');
          }
          setState(() {
            _isLoading =
                false; // Ocultar el indicador de carga si hay un error
          });
          // Mostrar un mensaje al usuario o realizar alguna acción apropiada
          return;
        }

        User? user = userCredential.user;

        // Upload ID image to Firebase Storage
        String? photoUrl;
        if (_idImage != null) {
          Reference ref =
              FirebaseStorage.instance.ref().child('id_images/${user!.uid}');
          UploadTask uploadTask = ref.putFile(_idImage!);
          TaskSnapshot snapshot = await uploadTask;
          photoUrl = await snapshot.ref.getDownloadURL();
        }

        double walletBalanceDefault = 0.00;

        // Store user data in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(combinedId)
            .set({
          'name': _nameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'uid': user!.uid,
          'id': combinedId,
          'birthDate': _selectedDate, // Guardar como Timestamp
          'email': emailLowerCase,
          'phone': combinedPhone,
          'gender': _selectedGender,
          'photoIdentityDocument': photoUrl,
          'acceptTerms': _acceptTerms,
          'role': 0,
          'status': 0,
          'registrationDate': DateTime.now(),
          'verified': false,
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(combinedId) // Usa el ID combinado como el ID del documento
            .set({
          'walletBalance': walletBalanceDefault,
        });

        // Recarga la información del usuario para obtener el estado actualizado del correo electrónico
        await user.reload();

        // Navega a la pantalla de personalización del perfil
        // ignore: use_build_context_synchronously
        Navigator.pushReplacement(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(
            builder: (context) => ProfileCustomizationScreen(
              userName: _nameController.text.trim(),
              combinedId: combinedId,
            ),
          ),
        );
      } catch (e) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al registrar usuario: $e')));
      }
      setState(() {
        _isLoading = false; // Ocultar el indicador de carga al finalizar
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildFirstPage(),
      _buildSecondPage(),
      _buildThirdPage(),
      _buildFourthPage(),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: _currentPage > 0
          ? AppBar(
              backgroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
              elevation: 0,
            )
          : null,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFE0F2F1)],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    // Deshabilitar el deslizamiento manual
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: pages,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          height: 8.0,
                          width: i == _currentPage ? 24.0 : 8.0,
                          decoration: BoxDecoration(
                            color: i == _currentPage
                                ? const Color(0xFF08143c)
                                : Colors.grey,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 30.0),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _currentPage < 3
          ? FloatingActionButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  if (_currentPage == 0 && !_acceptTerms) {
                    // Mostrar un mensaje si no se aceptan los términos
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('Debes aceptar los términos y condiciones.')));
                    return;
                  }
                  if (_currentPage == 2 &&
                      !_hasMinLength &&
                      !_hasUpperCase &&
                      !_hasLowerCase &&
                      !_hasDigits &&
                      !_hasSpecialCharacters) {
                    // Mostrar un mensaje si no se cumplen los requisitos de la contraseña
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'La contraseña debe cumplir con todos los requisitos.')));
                    return;
                  }
                  _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                }
              },
              backgroundColor: Colors.green,
              child: const Icon(Icons.arrow_forward, color: Colors.white),
            )
          : _currentPage == 3
              ? FloatingActionButton.extended(
                  onPressed: _isLoading
                      ? null
                      : _registerUser, // Deshabilitar el botón mientras se carga
                  backgroundColor: Colors.green,
                  label: _isLoading
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text('Registrarme',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                  icon: _isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.check, color: Colors.white),
                )
              : const SizedBox.shrink(),
    );
  }

  Widget _buildFirstPage() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFE0F2F1)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/MSA_LogoTemporal.png',
              height: 100,
            ),
            const SizedBox(height: 35.0),
            const Text(
              '¡Bienvenido!',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const Text(
              'Cuéntanos un poco sobre ti',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.normal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30.0),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '¿Cuál es tu nombre?',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16.0)),
              ),
              validator: (value) =>
                  value!.isEmpty ? 'Por favor, ingresa tu nombre' : null,
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: '¿Y tu apellido?',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16.0)),
              ),
              validator: (value) =>
                  value!.isEmpty ? 'Por favor, ingresa tu apellido' : null,
            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Checkbox(
                  value: _acceptTerms,
                  onChanged: (value) {
                    setState(() {
                      _acceptTerms = value!;
                    });
                  },
                  checkColor: Colors.white, // Color del check
                  activeColor: const Color(
                      0xFF08143c), // Color del check cuando está activo
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black),
                      children: [
                        const TextSpan(text: 'Acepto los '),
                        TextSpan(
                          text: 'términos y condiciones',
                          style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const TermsAndConditionsScreen()),
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60.0),
            const Text(
              '¿Ya tienes una cuenta?',
              style: TextStyle(fontWeight: FontWeight.normal),
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Inicia Sesión',
                  style: TextStyle(color: Colors.green, fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondPage() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFE0F2F1)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Cuéntanos más sobre ti',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24.0),
              TextFormField(
                controller: _birthDateController,
                readOnly: true,
                onTap: _presentDatePicker,
                decoration: InputDecoration(
                  labelText: '¿Cuándo naciste?',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0)),
                ),
                validator: (value) => value!.isEmpty
                    ? 'Por favor, selecciona tu fecha de nacimiento'
                    : null,
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: InputDecoration(
                  labelText: '¿Cuál es tu género?',
                  labelStyle: const TextStyle(color: Colors.black),
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
                items: const [
                  DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                  DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
                  DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedGender = newValue!;
                  });
                },
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
              ),
              const SizedBox(height: 16.0),
              const Text(
                '¿Cuál es tu número de identificación?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _idLetterController,
                      decoration: InputDecoration(
                        labelText: 'Tipo',
                        labelStyle: const TextStyle(color: Colors.black),
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
                      items: const [
                        DropdownMenuItem(value: 'V', child: Text('V')),
                        DropdownMenuItem(value: 'E', child: Text('E')),
                        DropdownMenuItem(value: 'J', child: Text('J')),
                        DropdownMenuItem(value: 'P', child: Text('P')),
                      ],
                      onChanged: (String? value) {
                        setState(() {
                          _idLetterController = value;
                        });
                      },
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _idNumberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Número',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.0)),
                      ),
                      validator: (value) => value!.isEmpty
                          ? 'Por favor, ingresa tu número de identificación'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _takeIdPhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF08143c),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                ),
                child: Text(_idImage == null
                    ? 'Tomar foto del documento'
                    : 'Cambiar foto del documento'),
              ),
              if (_idImage != null) const SizedBox(height: 8.0),
              if (_idImage != null) Image.file(_idImage!, height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThirdPage() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFE0F2F1)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Asegura tu cuenta',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24.0),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                onChanged: (value) {
                  _checkPasswordStrength(value);
                },
                decoration: InputDecoration(
                  labelText: 'Crea una contraseña segura',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Por favor, ingresa tu contraseña';
                  }
                  if (value.length < 8) {
                    return 'La contraseña debe tener al menos 8 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirma tu contraseña',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Por favor, confirma tu contraseña';
                  }
                  if (value != _passwordController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              // Mostrar los requisitos de la contraseña
              const Text(
                'Le recomendamos que contenga:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
                textAlign: TextAlign.center,
              ),
              Column(
                children: [
                  _buildPasswordRequirement('Mínimo 8 caracteres', _hasMinLength),
                  _buildPasswordRequirement('Una letra mayúscula', _hasUpperCase),
                  _buildPasswordRequirement('Una letra minúscula', _hasLowerCase),
                  _buildPasswordRequirement('Un número', _hasDigits),
                  _buildPasswordRequirement(
                      'Un carácter especial', _hasSpecialCharacters),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFourthPage() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFE0F2F1)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Último paso: tus datos de contacto',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24.0),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _phoneCountryCodeController,
                      decoration: InputDecoration(
                        labelText: 'Código',
                        labelStyle: const TextStyle(color: Colors.black),
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
                      items: const [
                        DropdownMenuItem(value: '+58', child: Text('+58')),
                        // Add more country codes as needed
                      ],
                      onChanged: (String? value) {
                        setState(() {
                          _phoneCountryCodeController = value;
                        });
                      },
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    flex: 7,
                    child: TextFormField(
                      controller: _phoneNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: '¿Cuál es tu número de teléfono?',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.0)),
                      ),
                      validator: (value) => value!.isEmpty
                          ? 'Por favor, ingresa tu número de teléfono'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (value) {
                  // Convertir a minúsculas mientras el usuario escribe
                  _emailController.text = value.toLowerCase();
                  _emailController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _emailController.text.length),
                  );
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: '¿Cuál es tu correo electrónico?',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0)),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Por favor, ingresa tu correo electrónico';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Por favor, ingresa un correo electrónico válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _emailController.text.isEmpty || _isTimerRunning
                    ? null
                    : _sendEmailVerification, // Deshabilita el botón si el campo de correo electrónico está vacío o el temporizador se está ejecutando
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF08143c),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                ),
                child: Text(_isTimerRunning
                    ? 'Reenviar código en $_timerSeconds s'
                    : 'Enviar correo de verificación'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Función para verificar la fuerza de la contraseña
  void _checkPasswordStrength(String password) {
    setState(() {
      _hasUpperCase = password.contains(RegExp(r'[A-Z]'));
      _hasLowerCase = password.contains(RegExp(r'[a-z]'));
      _hasDigits = password.contains(RegExp(r'[0-9]'));
      _hasSpecialCharacters =
          password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      _hasMinLength = password.length >= 8;
    });
  }

  // Función para construir la fila de requisitos de contraseña
  Widget _buildPasswordRequirement(String text, bool isChecked) {
    return Row(
      children: [
        Icon(
          isChecked ? Icons.check_circle : Icons.circle_outlined,
          color: isChecked ? Colors.green : Colors.grey,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: isChecked ? Colors.green : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class ProfileCustomizationScreen extends StatefulWidget {
  final String userName;
  final String combinedId;

  const ProfileCustomizationScreen(
      {super.key, required this.userName, required this.combinedId});

  @override
  State<ProfileCustomizationScreen> createState() =>
      _ProfileCustomizationScreenState();
}

class _ProfileCustomizationScreenState
    extends State<ProfileCustomizationScreen> {
  final _bioController = TextEditingController();
  File? _selectedImage;
  String? _uploadedFileURL;

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _cropImage(pickedFile.path);
    }
  }

  Future<void> _cropImage(String imagePath) async {
    CroppedFile? croppedImage = await ImageCropper().cropImage(
      sourcePath: imagePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar Imagen',
          toolbarColor: Colors.white,
          toolbarWidgetColor: Colors.black,
          backgroundColor: Colors.white,
          statusBarColor: Colors.white,
          activeControlsWidgetColor: Colors.green,
          cropFrameColor: Colors.green,
          cropGridColor: Colors.grey[300],
          hideBottomControls: false,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Recortar Imagen',
        ),
      ],
    );
    if (croppedImage != null) {
      setState(() {
        _selectedImage = File(croppedImage.path);
      });
    }
  }

  Future<void> _uploadImageToFirebaseStorage() async {
    if (_selectedImage == null) {
      return;
    }

    try {
      // Sube la imagen a Firebase Storage
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('profileimages/${widget.combinedId}');
      UploadTask uploadTask = ref.putFile(_selectedImage!);
      TaskSnapshot snapshot = await uploadTask;
      _uploadedFileURL = await snapshot.ref.getDownloadURL();

      // Actualiza el documento del usuario con la URL de la imagen en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.combinedId)
          .update({'profileImageUrl': _uploadedFileURL});
    } catch (e) {
      if (kDebugMode) {
        print('Error al subir la imagen: $e');
      }
    }
  }

  Future<void> _uploadUserDataToFirestore() async {
    try {
      // Actualiza el documento del usuario con la biografía en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.combinedId)
          .update({'bio': _bioController.text});
    } catch (e) {
      if (kDebugMode) {
        print('Error al subir la biografía: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '¡Hola ${widget.userName}!',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const Text(
              'Personaliza tu perfil',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.normal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 64,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : const AssetImage(
                                'assets/images/ProfilePhoto_predetermined.png')
                            as ImageProvider,
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                  child: IconButton(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.edit, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: TextFormField(
                controller: _bioController, // Controlador para la biografía
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Escribe una biografía...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFF08143c)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                // Sube la biografía
                await _uploadUserDataToFirestore();

                // Sube la imagen
                await _uploadImageToFirebaseStorage();

                // Navega a HomePage con índice 0
                Navigator.pushReplacement(
                  // ignore: use_build_context_synchronously
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomePage(selectedIndex: 0),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Empezar',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
