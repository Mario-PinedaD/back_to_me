import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import '../views/administradorBD/usuariosBD.dart';

class AuthState extends ChangeNotifier {

  Usuario? _user;

  Usuario? get user => _user;

  void setUser(Usuario user) {
    _user = user;
    print("usuarioactualizado: ${_user?.nombre}");
    notifyListeners();
  }

  void logout() {
    _user = null;
    print(_user?.nombre);
    notifyListeners();
  }

  void updateUser(Usuario newUser) {
    _user = newUser;
    print("usuarioactualizado: ${_user?.nombre}");
    notifyListeners();
  }

  void suscribirACambiosDeCamiTrabajador() {
    if (_user != null) {
      print("updateUsernill: ${_user?.nombre}");
      final usuarioId = _user?.id;
      final userRef = FirebaseFirestore.instance.collection('usuario').doc(usuarioId);

      userRef.snapshots().listen((event) {
        if (event.exists) {
          print("updateUser1234: ${_user?.nombre}");
          final data = event.data() as Map<String, dynamic>;
          final nuevoUrlimagen = data['urlimagen'] as String;
          final nuevoNombre = data['nombre'] as String;

          if (_user != null && _user?.urlimagen != nuevoUrlimagen || _user?.nombre != nuevoNombre) {
            _user?.nombre = (nuevoNombre);
            _user?.urlimagen = nuevoUrlimagen;
            print("updateUseverdaderor: ${_user?.nombre}");
            notifyListeners();
          }
        }
      });
    }
  }


}
