import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:mobileservicesapp/screens/public/profile.dart';
import 'login_screen.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sms_autofill/sms_autofill.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Páginas del formulario
  final List<Widget> _pages = [];

  // Controlador de la página actual
  final _pageController = PageController();

  // GlobalKey para el formulario
  final _formKey = GlobalKey<FormState>();

  // Variables para los datos del usuario
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedGender;
  String? _selectedIdType = 'V';
  final _idNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneCountryCodeController = TextEditingController(text: '+58');
  final _phoneNumberController = TextEditingController();
  final _smsCodeController = TextEditingController();

  // Variable para la imagen del documento
  File? _image;

  // Variables para la verificación por SMS
  String _verificationId = '';
  bool _codeSent = false;
  Timer? _timer;
  int _start = 60;

  bool _pageViewBuilt = false;

  // Variable para los términos y condiciones
  bool _acceptTerms = false;

  @override
  void initState() {
    super.initState();
    // Inicializa las páginas del formulario
    _pages.addAll([
      _buildPersonalInfoPage(),
      _buildDocumentInfoPage(),
      _buildAccountInfoPage(),
      _buildPhoneVerificationPage(),
    ]);
  }

  @override
  void dispose() {
    // Libera los controladores al destruir el widget
    _nameController.dispose();
    _lastNameController.dispose();
    _idNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneCountryCodeController.dispose();
    _phoneNumberController.dispose();
    _smsCodeController.dispose();
    _timer?.cancel(); // Asegúrate de cancelar el temporizador
    super.dispose();
  }

  // Función para tomar una foto
  Future<void> _takePicture() async {
    final pickedImage =
        await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedImage != null) {
      setState(() {
        _image = File(pickedImage.path);
      });
    }
  }

  // Función para seleccionar una imagen de la galería
  Future<void> _selectPicture() async {
    final pickedImage =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _image = File(pickedImage.path);
      });
    }
  }

  // Función para mostrar el calendario
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
      });
    }
  }

  // Función para enviar el código de verificación por SMS
  Future<void> _verifyPhoneNumber() async {
    // Inicia el temporizador
    _startTimer();

    final phone =
        '+${_phoneCountryCodeController.text.trim()}${_phoneNumberController.text.trim()}';

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-retrieval of OTP in some cases
      },
      verificationFailed: (FirebaseAuthException e) {
        if (e.code == 'invalid-phone-number') {
          // ignore: avoid_print
          print('The provided phone number is not valid.');
          // Show error message to user
        }
        // Handle other errors
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
        });
        // Navigate to OTP input page
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // Función para registrar al usuario
  Future<void> _registerUser() async {
    try {
      // Validar si el código SMS es correcto
      if (_verificationId.isNotEmpty && _smsCodeController.text.isNotEmpty) {
        // Crea la credencial con el código SMS
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
            verificationId: _verificationId,
            smsCode: _smsCodeController.text.trim());

        // Inicia sesión con la credencial del teléfono
        await FirebaseAuth.instance.signInWithCredential(credential);
      } else {
        // Manejar el caso en el que no se requiere verificación por SMS
        // ...
      }

      // Crea usuario con email y contraseña usando Firebase Authentication
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Obtén el usuario que se acaba de registrar
      User? user = userCredential.user;

      if (user != null) {
        // Subir la imagen del documento a Firebase Storage
        final ref = FirebaseStorage.instance
            .ref('identity_documents/${user.uid}.jpg');
        await ref.putFile(_image!);
        final photoUrl = await ref.getDownloadURL();

        String walletBalanceDefault = '0.00';

        // Crea el documento del usuario en Firestore
        String combinedId =
            '$_selectedIdType${_idNumberController.text.trim()}';

        await FirebaseFirestore.instance
            .collection('users')
            .doc(combinedId)
            .set({
          'name': _nameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'id': combinedId,
          'birthDate': _selectedDate != null
              ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
              : '',
          'email': _emailController.text.trim(),
          'phone':
              '+${_phoneCountryCodeController.text.trim()}${_phoneNumberController.text.trim()}',
          'uid': user.uid,
          'password': _passwordController.text.trim(),
          'gender': _selectedGender,
          'photoIdentityDocument': photoUrl,
          'acceptTerms': _acceptTerms,
          'role': 0,
          'status': 0,
          'registrationDate': DateTime.now(),
        });

        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(combinedId) // Usa el ID combinado como el ID del documento
            .set({
          'walletBalance': walletBalanceDefault,
        });

        // Registro exitoso, navega a LoginScreen y muestra un mensaje
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '¡Registro exitoso! Inicie sesión.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
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
        // Mostrar mensaje de error al usuario
      } else if (e.code == 'email-already-in-use') {
        // ignore: avoid_print
        print('The account already exists for that email.');
        // Mostrar mensaje de error al usuario
      } else if (e.code == 'invalid-credential') {
        // ignore: avoid_print
        print('Invalid SMS code provided');
        // Show error message to user
      }
    } catch (e) {
      // ignore: avoid_print
      print(e);
      // Mostrar mensaje de error genérico al usuario
    }
  }

  // Función para iniciar el temporizador
  void _startTimer() {
    _start = 60;
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) {
        if (_start == 0) {
          setState(() {
            timer.cancel();
            _codeSent = false;
          });
        } else {
          setState(() {
            _start--;
          });
        }
      },
    );
  }

  // Función para construir la página de información personal
  Widget _buildPersonalInfoPage() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nombre'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, ingresa tu nombre';
            }
            return null;
          },
        ),
        const SizedBox(height: 16.0),
        TextFormField(
          controller: _lastNameController,
          decoration: const InputDecoration(labelText: 'Apellido'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, ingresa tu apellido';
            }
            return null;
          },
        ),
        const SizedBox(height: 24.0),
        Row(
          children: [
            Checkbox(
              value: _acceptTerms,
              onChanged: (value) {
                setState(() {
                  _acceptTerms = value!;
                });
              },
            ),
            const SizedBox(width: 4.0),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black, fontSize: 13.0),
                  children: [
                    const TextSpan(
                      text: 'Acepto los ',
                    ),
                    TextSpan(
                      text: 'términos y condiciones',
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const TermsAndConditionsScreen(),
                            ),
                          );
                        },
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
      ],
    );
  }

  // Función para construir la página de información del documento
  Widget _buildDocumentInfoPage() {
    return Column(
      children: [
        // Campo para la fecha de nacimiento
        TextFormField(
          readOnly: true,
          onTap: _presentDatePicker,
          decoration: const InputDecoration(
            labelText: 'Fecha de nacimiento',
            hintText: 'Selecciona tu fecha de nacimiento',
          ),
          validator: (value) {
            if (_selectedDate == null) {
              return 'Por favor, selecciona tu fecha de nacimiento';
            }
            return null;
          },
        ),
        const SizedBox(height: 16.0),

        // Menú desplegable para el género
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Género',
            hintText: 'Selecciona tu género',
          ),
          value: _selectedGender,
          onChanged: (value) {
            setState(() {
              _selectedGender = value;
            });
          },
          items: const [
            DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
            DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
            DropdownMenuItem(value: 'Otro', child: Text('Otro')),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, selecciona tu género';
            }
            return null;
          },
        ),
        const SizedBox(height: 16.0),

        // Fila para el tipo y número de identificación
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Tipo ID',
                  hintText: 'Selecciona el tipo de ID',
                ),
                value: _selectedIdType,
                onChanged: (value) {
                  setState(() {
                    _selectedIdType = value;
                  });
                },
                items: const [
                  DropdownMenuItem(value: 'V', child: Text('V')),
                  DropdownMenuItem(value: 'E', child: Text('E')),
                  DropdownMenuItem(value: 'J', child: Text('J')),
                  DropdownMenuItem(value: 'P', child: Text('P')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, selecciona el tipo de ID';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _idNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Número de ID',
                  hintText: 'Ingresa tu número de ID',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa tu número de ID';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16.0),

        // Vista previa de la imagen del documento
        if (_image != null)
          Image.file(
            _image!,
            height: 200,
            width: 200,
          )
        else
          const Placeholder(
            fallbackHeight: 200,
            fallbackWidth: 200,
          ),

        // Botones para tomar o seleccionar una foto
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: _takePicture,
              child: const Text('Tomar foto'),
            ),
            ElevatedButton(
              onPressed: _selectPicture,
              child: const Text('Seleccionar foto'),
            ),
          ],
        ),
      ],
    );
  }

  // Función para construir la página de información de la cuenta
  Widget _buildAccountInfoPage() {
    return Column(
      children: [
        // Campo para el correo electrónico
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo electrónico',
            hintText: 'Ingresa tu correo electrónico',
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
        const SizedBox(height: 16.0),
        // Campo para la contraseña
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Contraseña',
            hintText: 'Ingresa una contraseña',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, ingresa una contraseña';
            }
            if (value.length < 6) {
              return 'La contraseña debe tener al menos 6 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 16.0),

        // Campo para confirmar la contraseña
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirmar contraseña',
            hintText: 'Repite tu contraseña',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, repite tu contraseña';
            }
            if (value != _passwordController.text) {
              return 'Las contraseñas no coinciden';
            }
            return null;
          },
        ),
      ],
    );
  }

  // Función para construir la página de verificación telefónica
  Widget _buildPhoneVerificationPage() {
    return Column(
      children: [
        // Fila para el código del país y el número de teléfono
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Código del país',
                  hintText: 'Selecciona tu código de país',
                ),
                value: _phoneCountryCodeController.text,
                onChanged: (value) {
                  setState(() {
                    _phoneCountryCodeController.text = value!;
                  });
                },
                items: const [
                  DropdownMenuItem(value: '+58', child: Text('+58')),
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
              flex: 3,
              child: TextFormField(
                controller: _phoneNumberController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Número de teléfono',
                  hintText: 'Ingresa tu número de teléfono',
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
        const SizedBox(height: 16.0),

        // Botón para recibir el código
        ElevatedButton(
          onPressed: _codeSent
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    await _verifyPhoneNumber();
                  }
                },
          child: Text(_codeSent
              ? 'Código enviado ($_start)'
              : 'Recibir código'),
        ),

        // Campo para ingresar el código SMS
        if (_codeSent)
          TextFormField(
            controller: _smsCodeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Código de verificación',
              hintText: 'Ingresa el código',
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                SizedBox(
                  height: 400, // Ajusta la altura según sea necesario
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _pages,
                  ),
                ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      if (_pageViewBuilt &&
                          _pageController.page == _pages.length - 1) {
                        // Registra al usuario solo si PageView está construido
                        _registerUser();
                      } else {
                        // Navega a la siguiente página
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );

                        // Marca PageView como construido después de la primera navegación
                        _pageViewBuilt = true;
                      }
                    }
                  },
                  child: Text(
                    (_pageViewBuilt &&
                            _pageController.page == _pages.length - 1)
                        ? 'Registrarme'
                        : 'Siguiente',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}