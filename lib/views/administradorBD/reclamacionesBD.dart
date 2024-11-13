import 'package:cloud_firestore/cloud_firestore.dart';

class Reclamacion {
  final String uidReclamante;
  final String fotoReclamante;
  final String nombreReclamante;
  final String apellidoReclamante;
  String estadoReclamacion;
  final String textoReclamacion;
  final String? imagenReclamacionUrl;
  final DateTime? horaReclamacion;

  Reclamacion({
    required this.uidReclamante,
    required this.fotoReclamante,
    required this.nombreReclamante,
    required this.apellidoReclamante,
    required this.estadoReclamacion,
    required this.textoReclamacion,
    this.imagenReclamacionUrl,
    required this.horaReclamacion,
  });

  factory Reclamacion.fromMap(Map<String, dynamic> data) {
    return Reclamacion(
      uidReclamante: data['uidReclamante'],
      fotoReclamante: data['fotoReclamante'],
      nombreReclamante: data['nombreReclamante'],
      apellidoReclamante: data['apellidoReclamante'],
      estadoReclamacion: data['estadoReclamacion'],
      textoReclamacion: data['textoReclamacion'],
      imagenReclamacionUrl: data['imagenReclamacionUrl'],
      horaReclamacion: data['horaReclamacion'] != null ? (data['horaReclamacion'] as Timestamp).toDate() : null,

    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uidReclamante': uidReclamante,
      'fotoReclamante': fotoReclamante,
      'nombreReclamante': nombreReclamante,
      'apellidoReclamante': apellidoReclamante,
      'estadoReclamacion': estadoReclamacion,
      'textoReclamacion': textoReclamacion,
      'imagenReclamacionUrl': imagenReclamacionUrl,
      'horaReclamacion': horaReclamacion != null ? Timestamp.fromDate(horaReclamacion!) : null,
    };
  }
}
