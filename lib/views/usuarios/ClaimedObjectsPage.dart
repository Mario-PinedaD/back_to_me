import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../services/usuarioRegistrado.dart';
import '../administradorBD/objetosPerdidosBD.dart';
import '../administradorBD/usuariosBD.dart';

class ClaimedObjectsPage extends StatefulWidget {
  @override
  _ClaimedObjectsPageState createState() => _ClaimedObjectsPageState();
}

class _ClaimedObjectsPageState extends State<ClaimedObjectsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<LostObject> _claimedObjects = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  final Color _primaryColor = Color(0xFF1B396A);
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _loadClaimedObjects();
  }

  Future<void> _loadClaimedObjects() async {
    final authState = Provider.of<AuthState>(context, listen: false);
    final Usuario? currentUser = authState.user;
    print('Usuario actual: ${currentUser?.id}');

    if (_isLoading || !_hasMore || currentUser == null) return;

    setState(() => _isLoading = true);

    Query query = _firestore
        .collection('objetos_perdidos')
        .where('reclamacionesUids', arrayContains: currentUser.id)
        .orderBy('timestamp', descending: true)
        .limit(_limit);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    try {
      QuerySnapshot querySnapshot = await query.get();

      if (querySnapshot.docs.isNotEmpty) {
        List<LostObject> fetchedObjects = querySnapshot.docs.map((doc) {
          return LostObject.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();

        setState(() {
          _lastDocument = querySnapshot.docs.last;
          _claimedObjects.addAll(fetchedObjects);
          print('Objetos reclamados: ${_claimedObjects.length}');
          _hasMore = querySnapshot.docs.length == _limit;
        });
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      print('Error al cargar objetos reclamados: $e');
      // Manejar el error según sea necesario
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Objetos Reclamados'),
        backgroundColor: _primaryColor,
      ),
      backgroundColor: Colors.white,
      body: _claimedObjects.isEmpty && !_isLoading
          ? Center(child: Text('No has reclamado ningún objeto.'))
          : ListView.builder(
        itemCount: _claimedObjects.length + 1,
        itemBuilder: (context, index) {
          if (index == _claimedObjects.length) {
            return _hasMore
                ? Center(child: CircularProgressIndicator())
                : Center(child: Text('No hay más objetos reclamados.'));
          }
          final claimedObject = _claimedObjects[index];
          return Card(
            margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            elevation: 4.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    claimedObject.imagenUrl.isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
                      child: CachedNetworkImage(
                        imageUrl: claimedObject.imagenUrl,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: double.infinity,
                          height: 200,
                          color: Colors.grey[300],
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: double.infinity,
                          height: 200,
                          color: Colors.grey[300],
                          child: Icon(Icons.error, color: Colors.red, size: 40),
                        ),
                      ),
                    )
                        : Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey[300],
                      child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey[700]),
                    ),
                    if (claimedObject.estadoReclamacion == 'Pendiente')
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: Colors.yellow,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12.0),
                              bottomRight: Radius.circular(8.0),
                            ),
                          ),
                          child: Text(
                            'En proceso de reclamación',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        claimedObject.tipoObjeto,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Descripción: ${claimedObject.descripcion}',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Encontrado en: ${claimedObject.lugarEncontrado}',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Fecha: ${_formatDateTime(claimedObject.timestamp)}',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _hasMore && !_isLoading
          ? FloatingActionButton(
        backgroundColor: _primaryColor,
        onPressed: _loadClaimedObjects,
        child: Icon(Icons.refresh),
      )
          : null,
    );
  }
}
