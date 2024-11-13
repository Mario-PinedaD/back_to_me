// user_account_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../services/usuarioRegistrado.dart';
import '../administradorBD/usuariosBD.dart';
import '../pageLogin.dart'; // Import the login page
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth

class UserAccountPage extends StatefulWidget {
  @override
  _UserAccountPageState createState() => _UserAccountPageState();
}

class _UserAccountPageState extends State<UserAccountPage> {
  final _formKey = GlobalKey<FormState>();
  String? _nombre;
  String? _apellido;
  String? _password;
  bool _isEditingName = false;
  bool _isEditingApellido = false;
  bool _isEditingPassword = false;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _changeProfilePicture(Usuario currentUser) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _isLoading = true;
      });

      File imageFile = File(pickedFile.path);
      String fileName = 'profile_pictures/${currentUser.id}.png';

      try {
        // Subir la imagen a Firebase Storage
        UploadTask uploadTask =
        FirebaseStorage.instance.ref().child(fileName).putFile(imageFile);

        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // Actualizar la URL de la imagen en Firebase Firestore o Realtime Database
        currentUser.urlimagen = downloadUrl;
        await Usuario.updateUser(currentUser); // Implementa esta función

        // Actualizar el estado del usuario en la aplicación
        Provider.of<AuthState>(context, listen: false).updateUser(currentUser);
      } catch (e) {
        print('Error al subir la imagen: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir la imagen')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _changePassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Se ha enviado un enlace para restablecer la contraseña a tu correo.')),
      );
    } catch (e) {
      print('Error al enviar el email de restablecimiento de contraseña: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar el email de restablecimiento')),
      );
    }
  }

  // Función para mostrar el diálogo de restablecimiento de contraseña
  Future<void> _showPasswordResetDialog(String email) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reautenticación Necesaria'),
          content: Text(
              'Para cambiar tu contraseña, necesitas reautenticarse. ¿Deseas recibir un correo para restablecer tu contraseña?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo
              },
              child: Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo
                _changePassword(email); // Enviar el correo de restablecimiento
              },
              child: Text('Enviar Correo'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context);
    final Usuario? currentUser = authState.user;

    final String userName = currentUser?.nombre ?? 'Usuario';
    final String userApellido = currentUser?.apellido ?? 'Apellido';
    final String userEmail = currentUser?.correo ?? 'correo@ejemplo.com';
    final String userPhotoUrl =
        currentUser?.urlimagen ?? 'https://via.placeholder.com/150';

    final Color primaryColor = Color(0xFF1B396A);

    return Scaffold(
      appBar: AppBar(
        title: Text('Cuenta'),
        backgroundColor: primaryColor,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 20),
              Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage(userPhotoUrl),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        if (currentUser != null) {
                          _changeProfilePicture(currentUser);
                        }
                      },
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: primaryColor,
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Nombre
                    TextFormField(
                      initialValue: userName,
                      readOnly: !_isEditingName, // Usar readOnly
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isEditingName
                                ? Icons.check
                                : Icons.edit,
                            color: _isEditingName
                                ? Colors.green
                                : Colors.blue,
                          ),
                          onPressed: () {
                            if (_isEditingName) {
                              if (_formKey.currentState!.validate()) {
                                _formKey.currentState!.save();
                                currentUser?.nombre =
                                    _nombre ?? currentUser.nombre;
                                Usuario.updateUser(currentUser!);
                                authState.updateUser(currentUser);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Nombre actualizado exitosamente'),
                                  ),
                                );
                              }
                              setState(() {
                                _isEditingName = false;
                              });
                            } else {
                              setState(() {
                                _isEditingName = true;
                              });
                            }
                          },
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _isEditingName
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa tu nombre';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _nombre = value;
                      },
                    ),
                    SizedBox(height: 20),
                    // Apellido
                    TextFormField(
                      initialValue: userApellido,
                      readOnly: !_isEditingApellido, // Usar readOnly
                      decoration: InputDecoration(
                        labelText: 'Apellido',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isEditingApellido
                                ? Icons.check
                                : Icons.edit,
                            color: _isEditingApellido
                                ? Colors.green
                                : Colors.blue,
                          ),
                          onPressed: () {
                            if (_isEditingApellido) {
                              if (_formKey.currentState!.validate()) {
                                _formKey.currentState!.save();
                                currentUser?.apellido =
                                    _apellido ?? currentUser.apellido;
                                Usuario.updateUser(currentUser!);
                                authState.updateUser(currentUser);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Apellido actualizado exitosamente'),
                                  ),
                                );
                              }
                              setState(() {
                                _isEditingApellido = false;
                              });
                            } else {
                              setState(() {
                                _isEditingApellido = true;
                              });
                            }
                          },
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _isEditingApellido
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa tu apellido';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _apellido = value;
                      },
                    ),
                    SizedBox(height: 20),
                    // Contraseña
                    TextFormField(
                      obscureText: true,
                      readOnly: !_isEditingPassword, // Usar readOnly
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        hintText: '********',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isEditingPassword
                                ? Icons.check
                                : Icons.edit,
                            color: _isEditingPassword
                                ? Colors.green
                                : Colors.blue,
                          ),
                          onPressed: () async {
                            if (_isEditingPassword) {
                              if (_formKey.currentState!.validate()) {
                                _formKey.currentState!.save();
                                if (_password != null &&
                                    _password!.length >= 6) {
                                  try {
                                    await FirebaseAuth.instance
                                        .currentUser
                                        ?.updatePassword(_password!);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Contraseña actualizada exitosamente'),
                                      ),
                                    );
                                  } on FirebaseAuthException catch (e) {
                                    if (e.code ==
                                        'requires-recent-login') {
                                      // Mostrar SnackBar y diálogo
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Necesitas reautenticarse para cambiar la contraseña.'),
                                        ),
                                      );
                                      _showPasswordResetDialog(userEmail);
                                    } else {
                                      // Otros errores
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Error al actualizar la contraseña: ${e.message}'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    // Manejo de otros errores
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Error al actualizar la contraseña'),
                                      ),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'La contraseña debe tener al menos 6 caracteres'),
                                    ),
                                  );
                                }
                              }
                              setState(() {
                                _isEditingPassword = false;
                              });
                            } else {
                              setState(() {
                                _isEditingPassword = true;
                              });
                            }
                          },
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _isEditingPassword
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (_isEditingPassword) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, ingresa una nueva contraseña';
                          }
                          if (value.length < 6) {
                            return 'La contraseña debe tener al menos 6 caracteres';
                          }
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _password = value;
                      },
                    ),
                    SizedBox(height: 20),
                    // Eliminar el botón de "Cambiar contraseña vía email"
                    // ElevatedButton(
                    //   onPressed: () {
                    //     _changePassword(userEmail);
                    //   },
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: Colors.grey,
                    //   ),
                    //   child: Text('Cambiar contraseña vía email'),
                    // ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  authState.logout();
                  SharedPreferences prefs =
                  await SharedPreferences.getInstance();
                  prefs.remove('userRole');

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => PageLogin()),
                        (Route<dynamic> route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding:
                  EdgeInsets.symmetric(horizontal: 100, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Cerrar Sesión',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
