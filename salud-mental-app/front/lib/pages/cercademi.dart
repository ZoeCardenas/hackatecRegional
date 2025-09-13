// lib/pages/cercademi.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../components/navbar.dart';

class CercaDeMiPage extends StatefulWidget {
  const CercaDeMiPage({Key? key}) : super(key: key);

  @override
  State<CercaDeMiPage> createState() => _CercaDeMiPageState();
}

class _CercaDeMiPageState extends State<CercaDeMiPage> {
  // Controladores (uno por cada tarjeta)
  final MapController _mapPsico = MapController();
  final MapController _mapPsiq = MapController();
  final MapController _mapAyuda = MapController();

  // Centro por defecto (CDMX)
  LatLng _center = const LatLng(19.4326, -99.1332);
  double _zoom = 12;

  // Marcadores de ejemplo
  final List<Marker> _markersPsico = [
    Marker(
      width: 36,
      height: 36,
      point: const LatLng(19.428, -99.135),
      child: const _Pin(color: Colors.indigo, tooltip: 'Psicólogo A'),
    ),
    Marker(
      width: 36,
      height: 36,
      point: const LatLng(19.44, -99.14),
      child: const _Pin(color: Colors.indigo, tooltip: 'Psicóloga B'),
    ),
  ];

  final List<Marker> _markersPsiq = [
    Marker(
      width: 36,
      height: 36,
      point: const LatLng(19.442, -99.12),
      child: const _Pin(color: Colors.red, tooltip: 'Hospital psiquiátrico X'),
    ),
  ];

  final List<Marker> _markersAyuda = [
    Marker(
      width: 36,
      height: 36,
      point: const LatLng(19.425, -99.15),
      child: const _Pin(color: Colors.green, tooltip: 'Centro de ayuda 24/7'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _locateMe(); // intenta centrar en la ubicación del usuario
  }

  Future<void> _locateMe() async {
    try {
      // En Web solo funciona en HTTPS o localhost.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _center = LatLng(pos.latitude, pos.longitude);
        _zoom = 14;
      });

      // move() en flutter_map 6.x NO devuelve Future.
      _mapPsico.move(_center, _zoom);
      _mapPsiq.move(_center, _zoom);
      _mapAyuda.move(_center, _zoom);
    } catch (_) {
      // Si falla, nos quedamos con el centro por defecto
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      drawer: const CustomNavBar(),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 187, 196, 189),
        title: const Text('CERCA DE MÍ',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            _mapBox(
              title: 'Psicólogas/os',
              controller: _mapPsico,
              markers: _markersPsico,
            ),
            const SizedBox(width: 16),
            _mapBox(
              title: 'Hospitales psiquiátricos',
              controller: _mapPsiq,
              markers: _markersPsiq,
            ),
            const SizedBox(width: 16),
            _mapBox(
              title: 'Centros de ayuda',
              controller: _mapAyuda,
              markers: _markersAyuda,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _locateMe,
        icon: const Icon(Icons.my_location),
        label: const Text('Mi ubicación'),
      ),
    );
  }

  Widget _mapBox({
    required String title,
    required MapController controller,
    required List<Marker> markers,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: _zoom,
                  interactionOptions: const InteractionOptions(
                    flags: ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.auxilia_app',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final Color color;
  final String tooltip;
  const _Pin({required this.color, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Icon(Icons.place, color: color, size: 30),
    );
  }
}
