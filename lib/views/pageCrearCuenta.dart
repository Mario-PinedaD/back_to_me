import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_backtome/views/usuarios/pageAppGeneral.dart';
// Importar librerías para autenticación y Firestore
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/usuarioRegistrado.dart';
import 'administradorBD/usuariosBD.dart'; // Importa la clase Usuario
import 'pageLogin.dart'; // Asegúrate de tener esta importación para navegar al login

class PageCrearCuenta extends StatefulWidget {
  final Color background;

  // Constructor
  PageCrearCuenta({required this.background});

  @override
  _PageCrearCuentaState createState() => _PageCrearCuentaState();
}

class _PageCrearCuentaState extends State<PageCrearCuenta> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; // Firebase Storage

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidosController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _imageFile;

  bool _isLoading = false; // Estado de carga

  // Variables para mensajes de error en caso de que alguno esté mal
  String? _nombreError;
  String? _apellidosError;
  String? _correoError;
  String? _passwordError;
  String? _confirmPasswordError;

  // Método para mostrar SnackBar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Método para seleccionar y comprimir la imagen
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // Convertir XFile a File
      final File file = File(pickedFile.path);

      // Obtener el tamaño del archivo antes de la compresión y convertirlo a MB
      final originalSizeBytes = await file.length();
      final originalSizeMB = originalSizeBytes / 1048576;
      print("Tamaño original: ${originalSizeMB.toStringAsFixed(2)} MB");

      // Comprimir la imagen
      final compressedFile = await _compressFile(file);

      if (compressedFile != null) {
        setState(() {
          _imageFile = compressedFile;
        });
      }
    }
  }

  // Método para comprimir la imagen
  Future<File?> _compressFile(File file) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
    final splitted = filePath.substring(0, lastIndex);
    final outPath = "${splitted}_compressed.jpg";

    try {
      var compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        minWidth: 1280,
        minHeight: 720,
        quality: 30,
      );

      if (compressedFile != null) {
        File resultFile = File(compressedFile.path);

        final compressedSizeBytes = resultFile.lengthSync();
        final compressedSizeMB = compressedSizeBytes / 1048576;
        print("Tamaño después de la compresión: ${compressedSizeMB.toStringAsFixed(2)} MB");

        final originalSizeBytes = file.lengthSync();
        final reductionPercentage = (1 - compressedSizeBytes / originalSizeBytes) * 100;
        print("Reducción del tamaño: ${reductionPercentage.toStringAsFixed(2)}%");

        return resultFile;
      }
    } catch (e) {
      print("Error al comprimir imagen: $e");
    }

    return null;
  }

  // Método para subir la imagen a Firebase Storage y obtener la URL
  Future<String?> _uploadImage(File imageFile, String uid) async {
    try {
      Reference storageRef = _storage.ref().child('user_images').child('$uid.jpg');
      UploadTask uploadTask = storageRef.putFile(imageFile);

      // Monitorear el estado de la subida
      await uploadTask.whenComplete(() => null);

      // Obtener la URL de descarga
      String downloadURL = await storageRef.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print("Error al subir imagen: $e");
      return null;
    }
  }

  // Función de registro actualizada con verificación de correo electrónico
  Future<void> _signUp() async {
    // Obtener y limpiar los textos de los campos
    String nombre = _nombreController.text.trim();
    String apellidos = _apellidosController.text.trim();
    String correo = _correoController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();

    // Inicialmente, asumimos que no hay errores
    bool hasError = false;

    setState(() {
      _nombreError = null;
      _apellidosError = null;
      _correoError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });

    // Validar que los campos no estén vacíos
    if (nombre.isEmpty) {
      setState(() {
        _nombreError = 'El nombre es obligatorio';
      });
      hasError = true;
    }

    if (apellidos.isEmpty) {
      setState(() {
        _apellidosError = 'Los apellidos son obligatorios';
      });
      hasError = true;
    }

    if (correo.isEmpty) {
      setState(() {
        _correoError = 'El correo es obligatorio';
      });
      hasError = true;
    }

    if (password.isEmpty) {
      setState(() {
        _passwordError = 'La contraseña es obligatoria';
      });
      hasError = true;
    }

    if (confirmPassword.isEmpty) {
      setState(() {
        _confirmPasswordError = 'La confirmación de contraseña es obligatoria';
      });
      hasError = true;
    }

    // Validar que las contraseñas coincidan
    if (password.isNotEmpty && confirmPassword.isNotEmpty && password != confirmPassword) {
      setState(() {
        _confirmPasswordError = 'Las contraseñas no coinciden';
      });
      hasError = true;
    }

    if (hasError) {
      return; // No proceder si hay errores
    }

    // Mostrar la pantalla de carga
    setState(() {
      _isLoading = true;
    });

    try {
      // Crear la cuenta en Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: correo,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        // Enviar correo de verificación
        await user.sendEmailVerification();

        String uid = user.uid;

        String imageUrl = '';
        if (_imageFile != null) {
          // Subir la imagen y obtener la URL
          String? uploadedUrl = await _uploadImage(_imageFile!, uid);
          if (uploadedUrl != null) {
            imageUrl = uploadedUrl;
          }
        }

        // Crear una instancia de Usuario con los datos ingresados
        Usuario newUser = Usuario(
          id: uid,
          nombre: nombre,
          apellido: apellidos,
          correo: correo,
          urlimagen: imageUrl, // URL de la imagen subida
          tipoUsuario: 'user',
        );

        // Guardar los datos del usuario en Firestore
        await _firestore.collection('usuarios').doc(uid).set(newUser.toMap());

        // Cerrar sesión del usuario
        await _auth.signOut();

        // Mostrar un diálogo informando al usuario
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Verifica tu correo electrónico'),
            content: Text(
                'Se ha enviado un correo de verificación a $correo. Por favor, verifica tu correo electrónico para activar tu cuenta.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navegar a la página de inicio de sesión
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PageLogin()), // Asegúrate de tener esta página
                        (route) => false,
                  );
                },
                child: Text('Aceptar'),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Manejo de errores específicos de FirebaseAuth
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = "El correo electrónico ya está en uso.";
          break;
        case 'invalid-email':
          errorMessage = "Correo inválido. Por favor, verifica el formato.";
          break;
        case 'weak-password':
          errorMessage = "La contraseña es demasiado débil.";
          break;
        default:
          errorMessage = "Error al crear la cuenta. Por favor, intenta de nuevo.";
      }
      _showSnackBar(errorMessage);
      print("Error de FirebaseAuth: $e");
    } catch (e) {
      // Manejo de otros errores
      _showSnackBar("Ocurrió un error inesperado. Por favor, intenta de nuevo.");
      print("Error inesperado: $e");
    } finally {
      // Ocultar la pantalla de carga
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: widget.background,
          resizeToAvoidBottomInset: true,
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                Text(
                  'CREA TU CUENTA',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Y comencemos a ayudar',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 20),
                // Botón para seleccionar la imagen
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage:
                    _imageFile != null ? FileImage(_imageFile!) : null,
                    child: _imageFile == null
                        ? Icon(
                      Icons.camera_alt,
                      size: 50,
                      color: Colors.white,
                    )
                        : null,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Selecciona una foto tuya o de tu credencial de estudiante',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 20),
                // Campo Nombre
                TextFormField(
                  controller: _nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    errorText: _nombreError,
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    if (_nombreError != null && value.trim().isNotEmpty) {
                      setState(() {
                        _nombreError = null;
                      });
                    }
                  },
                ),
                SizedBox(height: 15),
                // Campo Apellidos
                TextFormField(
                  controller: _apellidosController,
                  decoration: InputDecoration(
                    labelText: 'Apellidos',
                    errorText: _apellidosError,
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    if (_apellidosError != null && value.trim().isNotEmpty) {
                      setState(() {
                        _apellidosError = null;
                      });
                    }
                  },
                ),
                SizedBox(height: 15),
                // Campo Correo Electrónico
                TextFormField(
                  controller: _correoController,
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    helperText: 'Ingresa un correo electrónico válido',
                    errorText: _correoError,
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) {
                    if (_correoError != null && value.trim().isNotEmpty) {
                      setState(() {
                        _correoError = null;
                      });
                    }
                  },
                ),
                SizedBox(height: 15),
                // Campo Contraseña
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    errorText: _passwordError,
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  obscureText: true,
                  onChanged: (value) {
                    if (_passwordError != null && value.trim().isNotEmpty) {
                      setState(() {
                        _passwordError = null;
                      });
                    }
                  },
                ),
                SizedBox(height: 15),
                // Campo Confirmación de contraseña
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirmación de contraseña',
                    errorText: _confirmPasswordError,
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  obscureText: true,
                  onChanged: (value) {
                    if (_confirmPasswordError != null &&
                        value.trim().isNotEmpty) {
                      setState(() {
                        _confirmPasswordError = null;
                      });
                    }
                  },
                ),
                SizedBox(height: 15),
                SizedBox(height: 30),
                // Botón Crear cuenta
                ElevatedButton(
                  onPressed: _signUp,
                  style: ElevatedButton.styleFrom(
                    padding:
                    EdgeInsets.symmetric(vertical: 15, horizontal: 100),
                    backgroundColor: Colors.blue[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Crear cuenta',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                SizedBox(height: 30),
              ],
            ),
          ),
        ),
        // Pantalla de carga
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Creando cuenta...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
