

import 'package:cloud_firestore/cloud_firestore.dart';

class Usuario {
  String id;
  String nombre;
  String apellido;
  String correo;
  String urlimagen='';
  String tipoUsuario;



  Usuario({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.urlimagen,
    required this.tipoUsuario,


  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'correo': correo,
      'urlimagen': urlimagen,
      'tipoUsuario': tipoUsuario,


    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map, String id) {
    return Usuario(
      id: id,
      nombre: map['nombre'] ?? '',
      apellido: map['apellido'] ?? '',
      correo: map['correo'] ?? '',
      urlimagen: map['urlimagen'] ?? '',
      tipoUsuario: map['tipoUsuario'] ?? '',
    );
  }

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  static Future<void> updateUser(Usuario user) async {
    try {
      await _firestore.collection('usuarios').doc(user.id).update(user.toMap());
    } catch (e) {
      print('Error al actualizar el usuario: $e');
      throw e;
    }
  }


}
