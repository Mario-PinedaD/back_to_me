import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_backtome/services/usuarioRegistrado.dart';
import 'package:flutter_backtome/views/administradorBD/usuariosBD.dart';
import 'package:flutter_backtome/views/administradores/AdminHomePage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'views/pageLogin.dart';
import 'views/usuarios/pageAppGeneral.dart'; // Pantalla principal para usuarios normales


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // verificar y asegurar que firebase se inicialice una sola vez
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }


  final AuthState authState = AuthState();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? userRole = prefs.getString('userRole'); // "user" o "admin"
  final String? usuarioJson = prefs.getString('userData');
  print(usuarioJson);
  if (usuarioJson != null) {
    final Map<String, dynamic> usuarioMap = json.decode(usuarioJson);
    if (usuarioMap.containsKey('id')) {

      final String id = usuarioMap['id'] as String; // Asegúrate de que 'id' exista y sea un String
      final usuario1 = Usuario.fromMap(usuarioMap, id);

      authState.setUser(usuario1);
    }
  }

  runApp(MyApp(authState: authState, userRole: userRole));

}
class MyApp extends StatelessWidget {
  final String? userRole;
  final AuthState authState;

  const MyApp({Key? key, required this.authState, required this.userRole}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    Widget homeScreen = _selectHomeScreen();

    final Color _backgroundAppColor = Color(0xFFE1EDFF);
    final Color _institutionalColor = Color(0xFF1B396A);

    return MultiProvider(
        providers: [
    ChangeNotifierProvider<AuthState>(create: (context) => AuthState()),
    ChangeNotifierProvider<AuthState>(create: (context) => authState),
    ],
    child:MaterialApp(
      title: 'Back To Me',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: _institutionalColor,
        scaffoldBackgroundColor: _backgroundAppColor,
      ),
      debugShowCheckedModeBanner: false,
      home: homeScreen,
    ),
    );
  }

  Widget _selectHomeScreen() {

      switch (userRole) {
        case 'admin':
          return  PageAppGeneralAdmin();
        case 'user':
          return PageAppGeneral();
        default:
          return PageLogin();
      }

  }


}
