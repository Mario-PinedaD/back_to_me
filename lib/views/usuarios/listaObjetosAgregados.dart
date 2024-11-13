import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../services/usuarioRegistrado.dart';
import '../administradorBD/objetosPerdidosBD.dart';
import '../administradorBD/usuariosBD.dart';

class LostObjectsPage extends StatefulWidget {
  @override
  _LostObjectsPageState createState() => _LostObjectsPageState();
}

class _LostObjectsPageState extends State<LostObjectsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<LostObject> _lostObjects = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  final Color _primaryColor = Color(0xFF1B396A);

  @override
  void initState() {
    super.initState();
    _loadLostObjects();
  }

  Future<void> _loadLostObjects() async {

    final authState = Provider.of<AuthState>(context, listen: false);
    final Usuario? currentUser = authState.user;
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    Query query = _firestore
        .collection('objetos_perdidos')
        .where('uidEncontrado', isEqualTo: currentUser?.id)
        .orderBy('timestamp', descending: true)
        .limit(10);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    QuerySnapshot querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      setState(() {
        _lastDocument = querySnapshot.docs.last;
        _lostObjects.addAll(querySnapshot.docs.map((doc) =>
            LostObject.fromMap(doc.data() as Map<String, dynamic>, doc.id)));
        _hasMore = querySnapshot.docs.length == 10;
      });
    } else {
      setState(() => _hasMore = false);
    }

    setState(() => _isLoading = false);
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: Text('Objetos Perdidos Agregados'),
      ),
      backgroundColor: Colors.white,
      body: ListView.builder(
        itemCount: _lostObjects.length + 1,
        itemBuilder: (context, index) {
          if (index == _lostObjects.length) {
            return _hasMore
                ? Center(child: CircularProgressIndicator())
                : Center(child: Text('No hay más objetos.'));
          }
          final lostObject = _lostObjects[index];
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
                    lostObject.imagenUrl.isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
                      child: CachedNetworkImage(
                        imageUrl: lostObject.imagenUrl,
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
                    if (lostObject.estadoReclamacion == 'Pendiente')
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
                        lostObject.tipoObjeto,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Descripción: ${lostObject.descripcion}',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Encontrado en: ${lostObject.lugarEncontrado}',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Fecha: ${_formatDateTime(lostObject.timestamp)}',
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
        onPressed: _loadLostObjects,
        child: Icon(Icons.add),
      )
          : null,
    );
  }
}
