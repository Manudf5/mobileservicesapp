import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io'; // Importar la clase 'File'
import '../intro_screen.dart'; // Importa intro_screen.dart
import 'package:image_picker/image_picker.dart'; // Importa image_picker
import 'package:url_launcher/url_launcher.dart'; // Importa url_launcher

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = '';
  String _userLastName = '';
  String _userBio = '';
  String _profileImageUrl = '';
  String _userAssessment = ''; // Variable para la calificación

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String combinedId = await _getCombinedIdFromFirestore(user.uid);

      DocumentSnapshot<Map<String, dynamic>> userDoc =
          await FirebaseFirestore.instance.collection('users').doc(combinedId).get();

      if (userDoc.exists) {
        setState(() {
          _userName = userDoc.data()!['name'];
          _userLastName = userDoc.data()!['lastName'];
          _userBio = userDoc.data()!['bio'] ?? '';
          _profileImageUrl = userDoc.data()!['profileImageUrl'] ?? '';
          _userAssessment = userDoc.data()!['assessment'] ?? ''; // Obtén la calificación
        });
      }
    }
  }

  Future _getCombinedIdFromFirestore(String uid) async {
    QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: uid)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }

    return '';
  }

  Future _updateProfileData({
    String? updatedUserName,
    String? updatedUserLastName,
    String? updatedUserBio,
    String? updatedProfileImageUrl,
  }) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String combinedId = await _getCombinedIdFromFirestore(user.uid);

      await FirebaseFirestore.instance.collection('users').doc(combinedId).update({
        'name': updatedUserName ?? _userName,
        'lastName': updatedUserLastName ?? _userLastName,
        'bio': updatedUserBio ?? _userBio,
        'profileImageUrl': updatedProfileImageUrl ?? _profileImageUrl,
      });
    }
  }

  Future _selectImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      _uploadImageToFirebase(image.path);
    }
  }

  Future _uploadImageToFirebase(String imagePath) async {
    // Sube la imagen a Firebase Storage
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    Reference storageReference =
        FirebaseStorage.instance.ref().child('profileImages/$fileName');

    try {
      UploadTask uploadTask = storageReference.putFile(File(imagePath));

      await uploadTask.whenComplete(() async {
        // Obtiene la URL de descarga de la imagen
        String downloadUrl = await storageReference.getDownloadURL();
        // Actualiza la URL de la imagen de perfil en Firestore
        setState(() {
          _profileImageUrl = downloadUrl;
        });
        _updateProfileData(updatedProfileImageUrl: downloadUrl);
      });
    } catch (e) {
      // Utiliza un logger en lugar de 'print'
      // print('Error al subir la imagen: $e');
      // Aquí debes agregar la lógica de manejo de errores,
      // como mostrar un mensaje al usuario
    }
  }

  void _showEditProfileScreen() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => _EditProfileScreen(
          userBio: _userBio,
          profileImageUrl: _profileImageUrl,
          onUpdateProfile: _updateProfileData,
          onSelectImage: _selectImageFromGallery,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  void _showSettingsScreen() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const _SettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  void _showHelpScreen() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const _HelpScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  void _showAdminTempScreen() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AdminTempScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      // ignore: use_build_context_synchronously
      context,
      MaterialPageRoute(builder: (context) => const IntroScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Perfil',
          style: TextStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true, // Centra el texto del AppBar
        actions: [
          IconButton(
            onPressed: _showHelpScreen,
            icon: Image.asset(
              'assets/images/IconHelp.png',
              height: 24,
              width: 24,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20.0),

                // Foto de perfil
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 100.0,
                      height: 100.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[300],
                        border: Border.all(
                          color: Colors.green,
                          width: 2.0,
                        ),
                      ),
                    ),
                    // Mostrar la imagen de perfil de Firebase si está disponible
                    _profileImageUrl.isNotEmpty
                        ? CircleAvatar(
                            radius: 45.0,
                            backgroundImage: NetworkImage(_profileImageUrl),
                          )
                        : const CircleAvatar(
                            radius: 45.0,
                            backgroundImage: AssetImage(
                                'assets/images/ProfilePhoto_predetermined.png'),
                          ),
                  ],
                ),

                const SizedBox(height: 16.0),

                // Nombre y Puntuación
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_userName $_userLastName',
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 5.0),
                      decoration: BoxDecoration(
                        color: Colors.blue[900],
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _userAssessment, // Mostrar la calificación real
                            style: const TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 5.0),
                          const Icon(
                            Icons.star,
                            size: 16.0,
                            color: Colors.amber,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16.0),

                // Descripción del usuario
                if (_userBio.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      _userBio,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16.0,
                        color: Colors.grey,
                      ),
                    ),
                  ),

                const SizedBox(height: 24.0),

                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Botón Editar Perfil
                    ElevatedButton(
                      onPressed: _showEditProfileScreen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200], // Formato diferente
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 8.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          Image.asset(
                            'assets/images/IconEditProfile.png',
                            height: 14,
                            width: 14,
                          ),
                          const SizedBox(width: 5.0), 
                          const Text(
                            'Editar Perfil',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    // Botón Configuración
                    ElevatedButton(
                      onPressed: _showSettingsScreen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200], // Formato diferente
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 8.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          Image.asset(
                            'assets/images/IconConfig.png',
                            height: 14,
                            width: 14,
                          ),
                          const SizedBox(width: 5.0), 
                          const Text(
                            'Configuración',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24.0),

                // Botón Administrador (Temporal)
                ElevatedButton(
                  onPressed: _showAdminTempScreen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200], // Formato diferente
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 16.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center, 
                    children: [
                      Image.asset(
                        'assets/images/IconAdmin.png',
                        height: 24,
                        width: 24,
                      ),
                      const SizedBox(width: 10.0), 
                      const Text(
                        'Administrador (Temporal)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32.0),

                // Botón Cerrar Sesión
                ElevatedButton(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[300],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40.0,
                      vertical: 16.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/IconLogout.png',
                        height: 24,
                        width: 24,
                      ),
                      const SizedBox(width: 10.0),
                      const Text(
                        'Cerrar Sesión',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
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

class _EditProfileScreen extends StatefulWidget {
  final String userBio;
  final String profileImageUrl;
  final Function onUpdateProfile;
  final Function onSelectImage;

  const _EditProfileScreen({
    required this.userBio,
    required this.profileImageUrl,
    required this.onUpdateProfile,
    required this.onSelectImage,
  });

  @override
  State<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.userBio);
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop(); // Regresa a la pantalla anterior
          },
        ),
        title: const Text(
          'Editar Perfil',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Foto de perfil
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 100.0,
                      height: 100.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[300],
                        border: Border.all(
                          color: Colors.green,
                          width: 2.0,
                        ),
                      ),
                    ),
                    widget.profileImageUrl.isNotEmpty
                        ? CircleAvatar(
                            radius: 45.0,
                            backgroundImage: NetworkImage(widget.profileImageUrl),
                          )
                        : const CircleAvatar(
                            radius: 45.0,
                            backgroundImage: AssetImage(
                                'assets/images/ProfilePhoto_predetermined.png'),
                          ),
                    Positioned(
                      top: 5.0,
                      right: 5.0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        child: IconButton(
                          onPressed: () {
                            widget.onSelectImage();
                          },
                          icon: const Icon(
                            Icons.edit,
                            size: 18.0,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20.0),
                // Biografía
                TextFormField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    labelText: 'Biografía',
                    hintText: 'Describete',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3, // Permite que el usuario ingrese múltiples líneas
                  maxLength: 100, // Establece un límite de 100 caracteres
                  validator: (value) {
                    if (value != null && value.length > 100) {
                      return 'La biografía debe tener un máximo de 100 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32.0),
                // Botón "Guardar" centrado al final
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          // Crea variables locales
                          String updatedUserBio = _bioController.text;

                          // Actualiza los datos del usuario (no se modifican las variables finales)
                          setState(() {
                            widget.onUpdateProfile(updatedUserBio: updatedUserBio);
                          });
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40.0,
                          vertical: 15.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, color: Colors.white),
                          SizedBox(width: 10.0),
                          Text(
                            'Guardar',
                            style: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _SettingsScreen extends StatefulWidget {
  // ignore: unused_element
  const _SettingsScreen({super.key});

  @override
  State<_SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<_SettingsScreen> {
  void _showChangePasswordScreen() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const _ChangePasswordScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop(); // Regresa a la pantalla anterior
          },
        ),
        title: const Text(
          'Configuración',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SizedBox(
          width: double.infinity, // Ocupa todo el ancho
          child: ElevatedButton(
            onPressed: _showChangePasswordScreen,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0, // Espacio extra para los iconos
                vertical: 16.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              // Alinear a los lados
              children: [
                // Icono de cambiar contraseña
                Icon(Icons.lock_reset, color: Colors.blue[900]),
                // Espacio entre los iconos
                const SizedBox(width: 16.0),
                // Texto del botón
                const Text(
                  'Cambiar Contraseña',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Espacio entre el texto y el ícono de flecha
                const SizedBox(width: 16.0),
                // Icono de flecha
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.green),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordScreen extends StatefulWidget {
  // ignore: unused_element
  const _ChangePasswordScreen({super.key});

  @override
  State<_ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<_ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  @override
  void initState() {
    super.initState();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future _updatePassword() async {
    if (_formKey.currentState!.validate()) {
      String currentPassword = _currentPasswordController.text.trim();
      String newPassword = _newPasswordController.text.trim();
      // ignore: unused_local_variable
      String confirmPassword = _confirmPasswordController.text.trim();

      // Verifica que la contraseña actual sea correcta
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Verifica la contraseña actual
          await user.reauthenticateWithCredential(
            EmailAuthProvider.credential(
              email: user.email!,
              password: currentPassword,
            ),
          );
        }

        // Actualiza la contraseña en Firebase Auth
        await user!.updatePassword(newPassword);

        // Actualiza la contraseña en Firestore
        String combinedId = await _getCombinedIdFromFirestore(user.uid);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(combinedId)
            .update({'password': newPassword});

        // La contraseña se actualizó correctamente
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña actualizada correctamente'),
          ),
        );

        // Limpia los campos de texto
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } on FirebaseAuthException {
        // La contraseña actual es incorrecta
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La contraseña actual es incorrecta'),
          ),
        );
      }
    }
  }

  // Función para obtener el ID combinado de Firestore
  Future _getCombinedIdFromFirestore(String uid) async {
    QuerySnapshot<Map<String, dynamic>> querySnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .where('uid', isEqualTo: uid)
            .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop(); // Regresa a la pantalla anterior
          },
        ),
        title: const Text(
          'Cambiar contraseña',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _currentPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Contraseña actual',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa tu contraseña actual';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa tu nueva contraseña';
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
                decoration: const InputDecoration(
                  labelText: 'Confirmación de contraseña',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, confirma tu nueva contraseña';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32.0),
              ElevatedButton(
                onPressed: _updatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 15.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.update, color: Colors.white),
                    SizedBox(width: 10.0),
                    Text(
                      'Actualizar contraseña',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpScreen extends StatelessWidget {
  // ignore: unused_element
  const _HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop(); // Regresa a la pantalla anterior
          },
        ),
        title: const Text(
          'Ayuda',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20.0),
            const Text(
              'Preguntas frecuentes',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20.0),
            Expanded(
              child: ListView.builder(
                itemCount: 10, // Reemplaza con la cantidad de preguntas frecuentes
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('Pregunta frecuente ${index + 1}'),
                    subtitle: const Text(
                        'Aquí iría la respuesta a la pregunta frecuente'),
                  );
                },
              ),
            ),
            // Botón "Contactar a soporte" en la parte inferior
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final Uri whatsappUrl = Uri.parse(
                        'https://wa.me/584245069119?text=Hola%20Soporte%2C%20necesito%20ayuda%20con...');
                    if (await canLaunchUrl(whatsappUrl)) {
                      await launchUrl(whatsappUrl);
                    } else {
                      // Mostrar un mensaje de error al usuario si no se puede abrir WhatsApp
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40.0,
                      vertical: 7.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6b/WhatsApp.svg/1200px-WhatsApp.svg.png',
                        height: 40.0,
                        width: 40.0,
                      ),
                      const SizedBox(width: 10.0),
                      const Text(
                        'Contactar a soporte',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN//ADMIN
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


class AdminTempScreen extends StatefulWidget {
  // ignore: unused_element
  const AdminTempScreen({super.key});

  @override
  State<AdminTempScreen> createState() => AdminTempScreenState();
}

class AdminTempScreenState extends State<AdminTempScreen> {

void _showSuppliersScreen() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SuppliersScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context); // Regresa a la pantalla anterior
          },
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: const Text(
          'Administrador (Temporal)',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Agrega un padding para espacio alrededor del botón
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Expandir el botón a lo ancho
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showSuppliersScreen();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 16.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      Icons.store_mall_directory_outlined, color: Colors.purple, // Icono para proveedores
                      size: 28,
                    ),
                    SizedBox(width: 16.0),
                    Text(
                      'Proveedores',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 16.0),
                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.green),
                  ],
                ),
              ),
            ),
            // Aquí puedes agregar más widgets debajo del botón
          ],
        ),
      ),
    );
  }
}

class SuppliersScreen extends StatefulWidget {
  // ignore: unused_element
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => SuppliersScreenState();
}

class SuppliersScreenState extends State<SuppliersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;

  void _showSuppliersManagementScreen() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SuppliersManagementScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _fetchUsers() async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      _users = querySnapshot.docs
          .where((doc) => doc.data()['permissions'] == 1)
          .map((doc) => doc.data())
          .toList();
      _filteredUsers = _users;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error al obtener usuarios: $e');
      // Manejar el error, mostrar un mensaje al usuario, etc.
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredUsers = _users.where((user) =>
              user['id'].toString().toLowerCase().contains(query.toLowerCase()) ||
              (user['name'] + ' ' + user['lastName'])
                  .toLowerCase()
                  .contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context); // Regresa a la pantalla anterior
          },
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: const Text(
          'Proveedores',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey[200],
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 16.0),
                        child: Icon(
                          Icons.search,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: "Buscar usuario por ID o nombre",
                            border: InputBorder.none,
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25.0),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredUsers.isEmpty
                          ? const Center(
                              child: Text('No se encontraron usuarios'),
                            )
                          : ListView.builder(
                              itemCount: _filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = _filteredUsers[index];
                                return _buildUserTile(user);
                              },
                            ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30.0, // Distancia desde la parte inferior
            right: 30.0, // Distancia desde el lado derecho
            child: FloatingActionButton(
              onPressed: () {
                _showSuppliersManagementScreen();
              },
              backgroundColor: Colors.green,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10.0),
                  topRight: Radius.circular(10.0),
                  bottomRight: Radius.circular(10.0),
                  bottomLeft: Radius.circular(10.0),
                ),
              ),
              child: const Icon(Icons.edit, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF08143C),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: user['profileImageUrl'] != null
                ? NetworkImage(user['profileImageUrl'])
                : const AssetImage('assets/images/ProfilePhoto_predetermined.png'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user['name']} ${user['lastName']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('ID: ${user['id']}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SuppliersManagementScreen extends StatefulWidget {
  // ignore: unused_element
  const SuppliersManagementScreen({super.key});

  @override
  State createState() => SuppliersManagementScreenState();
}

class SuppliersManagementScreenState extends State<SuppliersManagementScreen> {
  String? _selectedStatus;
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic>? _selectedUser;
  DocumentSnapshot? _supplierData; // Almacena los datos del proveedor

  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  // Lista para almacenar los servicios añadidos
  final List<Map<String, dynamic>> _addedServices = [];

  // Función para obtener los servicios de Firestore
  Future<List<Map<String, dynamic>>> _fetchServices() async {
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('services')
        .get();

    List<Map<String, dynamic>> services = [];
    for (var doc in snapshot.docs) {
      services.add(doc.data() as Map<String, dynamic>);
    }
    return services;
  }

  Future<void> _fetchUser(BuildContext context) async {
    // Aquí puedes usar la función para obtener datos del usuario,
    // por ejemplo, obtener los datos de Firestore o desde una API.
    // Puedes usar la función _fetchUser para eso
  }

  Future<void> _loadSupplierData(String userId) async {
    _supplierData = await FirebaseFirestore.instance
        .collection('suppliers')
        .doc(userId)
        .get();

    if (_supplierData != null && _supplierData!.exists) {
      // Verifica si 'services' es una lista
      if (_supplierData!['services'] is List) {
        // Convierte 'services' a una lista de mapas
        List<Map<String, dynamic>> servicesList =
            _supplierData!['services'].cast<Map<String, dynamic>>();
        // Actualiza _addedServices con los servicios del proveedor
        setState(() {
          _addedServices.clear();
          _addedServices.addAll(servicesList);
        });
      }
    } else {
      // Limpia _addedServices si no hay datos de proveedor
      setState(() {
        _addedServices.clear();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUser(context); // Llama a la función para obtener datos del usuario
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: const Text(
          'Editar Proveedores',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Campo ID
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _idController, // Usa el TextEditingController
                        decoration: InputDecoration(
                          labelText: 'ID',
                          labelStyle: const TextStyle(color: Colors.black),
                          hintText: 'ID del usuario',
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
                        enabled: false,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const SearchUsersForSuppliersScreen(),
                          ),
                        ).then((value) {
                          if (value != null) {
                            setState(() {
                              _selectedUser = value;
                              _idController.text =
                                  _selectedUser!['id'].toString(); // Actualiza el controlador
                              _nameController.text =
                                  '${_selectedUser!['name']} ${_selectedUser!['lastName']}'; // Actualiza el controlador
                              _selectedStatus = _selectedUser!['permissions'] == 1
                                  ? 'SI'
                                  : 'NO'; // Actualiza el status
                              _loadSupplierData(_selectedUser!['id'].toString()); // Carga los datos del proveedor si existen
                            });
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF08143C),
                        padding: const EdgeInsets.all(10.0),
                        shape: const CircleBorder(),
                      ),
                      child: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 24.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                // Campo Nombre y apellido
                TextFormField(
                  controller: _nameController, // Usa el TextEditingController
                  decoration: InputDecoration(
                    labelText: 'Nombre y apellido',
                    labelStyle: const TextStyle(color: Colors.black),
                    hintText: 'Nombre y apellido del usuario',
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
                  enabled: false,
                ),
                const SizedBox(height: 16.0),
                // Lista desplegable "Activo"
                DropdownButtonFormField(
                  decoration: InputDecoration(
                    labelText: 'Activo',
                    labelStyle: const TextStyle(color: Colors.black),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 16.0,
                    ),
                  ),
                  value: _selectedStatus,
                  hint: const Text('Seleccione'),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'SI',
                      child: Text('SI'),
                    ),
                    DropdownMenuItem(
                      value: 'NO',
                      child: Text('NO'),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),

                // Muestra los servicios del proveedor si existen
                if (_supplierData != null && _supplierData!.exists)
                  const Text(
                    'Servicios actuales:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ..._addedServices.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> serviceData = entry.value;

                  return Column(
                    children: [
                      // Contenedor del servicio
                      Container(
                        margin: const EdgeInsets.only(top: 16.0),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF08143C),
                          ),
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Lista desplegable de servicios
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: _fetchServices(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  List<Map<String, dynamic>> services =
                                      snapshot.data!;

                                  return DropdownButtonFormField<String>(
                                    value: serviceData['service'],
                                    hint: const Text('Seleccione un servicio'),
                                    onChanged: (newValue) {
                                      setState(() {
                                        serviceData['service'] = newValue;
                                      });
                                    },
                                    items: services.map((service) {
                                      return DropdownMenuItem<String>(
                                        value: service['id'].toString(),
                                        // Utiliza el ID como value
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(7), // Agrega redondeo a los bordes
                                       ),
                                        padding: const EdgeInsets.all(0.4), // Agrega padding
                                        child: SizedBox(
                                          width:
                                              320, // Ajusta el ancho según sea necesario
                                          child: Text(
                                            '${service['id']} - ${service['serviceName']}',
                                          ),
                                        ),
                                      ),
                                      );
                                    }).toList(),
                                  );
                                } else if (snapshot.hasError) {
                                  return const Text(
                                      'Error al cargar los servicios');
                                } else {
                                  return const CircularProgressIndicator();
                                }
                              },
                            ),

                            const SizedBox(height: 16.0),

                            // Campo de texto para la ganancia por hora
                            TextFormField(
                              initialValue:
                                  serviceData['hourlyRate']?.toString(),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Ganancia por hora',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                              ),
                              onChanged: (newValue) {
                                setState(() {
                                  serviceData['hourlyRate'] =
                                      double.tryParse(newValue);
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      // Botón para eliminar el servicio
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _addedServices.removeAt(index);
                          });
                        },
                        icon: const Icon(Icons.delete),
                      ),
                    ],
                  );
                // ignore: unnecessary_to_list_in_spreads
                }).toList(),

                const SizedBox(height: 16.0),
                // Botón "Añadir servicio"
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      // Agrega un nuevo servicio a la lista
                      setState(() {
                        _addedServices.add({
                          'service': null, // Inicializa el servicio a null
                          'hourlyRate': null, // Inicializa la ganancia a null
                        });
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF08143C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 12.0,
                      ),
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                      ),
                    ),
                    child: const Text('Añadir servicio'),
                  ),
                ),
                const SizedBox(height: 16.0),
                // Botón "Guardar"
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Aquí debes agregar la lógica para guardar los datos
                      // en Firestore
                      if (_formKey.currentState!.validate()) {
                        
                        // ignore: avoid_print
                        print('Form is valid!');

                        // Obtén el ID del usuario desde el controlador
                        String userId = _idController.text;

                        // Crea un mapa con los datos del usuario
                        Map<String, dynamic> userData = {
                          'name': _nameController.text,
                          'services': _addedServices,
                          'permissions':
                              _selectedStatus == 'SI' ? 1 : 0, // Agrega permissions
                        };

                        // Guarda los datos del usuario en una nueva colección
                        await FirebaseFirestore.instance
                            .collection('suppliers')
                            .doc(userId)
                            .set(userData);

                        // Actualiza el estado de "Activo" en la colección "users"
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .update({'permissions': _selectedStatus == 'SI' ? 1 : 0});

                        // Navega a la pantalla anterior o muestra un mensaje de éxito
                        // ignore: use_build_context_synchronously
                        Navigator.pop(context);
                        // Muestra un mensaje de éxito
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Proveedor guardado correctamente'),
                          ),
                        );
                      } else {
                        // ignore: avoid_print
                        print('Form is not valid');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1CA424),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 12.0,
                      ),
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                      ),
                    ),
                    child: const Text('Guardar'),
                  ),
                ),
                const SizedBox(height: 16.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class SearchUsersForSuppliersScreen extends StatefulWidget {
  const SearchUsersForSuppliersScreen({super.key});

  @override
  State<SearchUsersForSuppliersScreen> createState() =>
      _SearchUsersForSuppliersScreenState();
}

class _SearchUsersForSuppliersScreenState
    extends State<SearchUsersForSuppliersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _fetchUsers() async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      _users = querySnapshot.docs.map((doc) => doc.data()).toList();
      _filteredUsers = _users;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error al obtener usuarios: $e');
      // Manejar el error, mostrar un mensaje al usuario, etc.
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredUsers = _users.where((user) =>
              user['id'].toString().toLowerCase().contains(query.toLowerCase()) ||
              user['email'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Buscar usuarios'),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[200],
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 16.0),
                    child: Icon(
                      Icons.search,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: "Buscar usuario por ID o email",
                        border: InputBorder.none,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25.0),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUsers.isEmpty
                      ? const Center(
                          child: Text('No se encontraron usuarios'),
                        )
                      : GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 16 / 14,
                          children: _filteredUsers.map((user) {
                            return _buildUserButton(user);
                          }).toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserButton(Map<String, dynamic> user) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop(user); // Corrección aquí
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF08143C),
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: user['profileImageUrl'] != null
                  ? NetworkImage(user['profileImageUrl'])
                  : const AssetImage('assets/images/ProfilePhoto_predetermined.png'),
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${user['id']}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Nombre: ${user['name']} ${user['lastName']}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Permisos: ${user['permissions']}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Correo: ${user['email']}',
              style: const TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}