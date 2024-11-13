import 'package:cloud_firestore/cloud_firestore.dart';

//Creamos un objeto de la bd
FirebaseFirestore db = FirebaseFirestore.instance;

//Funcion para leer la información
Future<List> getUsuarios() async {
  List usuarios = [];

  CollectionReference collectionReferenceUsuarios = db.collection('usuarios');

  QuerySnapshot queryUsuarios = await collectionReferenceUsuarios.get();

  queryUsuarios.docs.forEach((documento) {
    usuarios.add(documento.data());
  });

  return usuarios;
}
