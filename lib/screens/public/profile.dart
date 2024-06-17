import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io'; // Importar la clase 'File'
import '../intro_screen.dart'; // Importa intro_screen.dart
import 'package:image_picker/image_picker.dart'; // Importa image_picker
import 'package:url_launcher/url_launcher.dart'; // Importa url_launcher

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PerfilScreenState createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  String _userName = '';
  String _userLastName = '';
  String _userBio = '';
  String _profileImageUrl = '';

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
                // AppBar personalizado
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: const Text(
                    'Perfil',
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),

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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '4.7/5',
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 5.0),
                          Icon(
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
                Column(
                  children: [
                    // Botón Editar Perfil
                    _buildCustomButton(
                      onPressed: _showEditProfileScreen,
                      icon: 'assets/images/IconEditProfile.png',
                      text: 'Editar Perfil',
                    ),
                    const SizedBox(height: 10.0),
                    // Botón Configuración
                    _buildCustomButton(
                      onPressed: _showSettingsScreen,
                      icon: 'assets/images/IconConfig.png',
                      text: 'Configuración',
                    ),
                    const SizedBox(height: 10.0),
                    // Botón Ayuda
                    _buildCustomButton(
                      onPressed: _showHelpScreen,
                      icon: 'assets/images/IconHelp.png',
                      text: 'Ayuda',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Función para crear un botón personalizado con icono y flecha
  Widget _buildCustomButton({
    required VoidCallback onPressed,
    required String icon,
    required String text,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icono de cambiar contraseña
            Image.asset(
              icon,
              height: 24,
              width: 24,
            ),
            // Espacio entre los iconos
            const SizedBox(width: 16.0),
            // Texto del botón
            Text(
              text,
              style: const TextStyle(
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