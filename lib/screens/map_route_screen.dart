import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class MapRouteScreen extends StatefulWidget {
  final LatLng startLocation;
  final LatLng endLocation;
  final String destinationName;

  const MapRouteScreen({
    Key? key,
    required this.startLocation,
    required this.endLocation,
    required this.destinationName,
  }) : super(key: key);

  @override
  _MapRouteScreenState createState() => _MapRouteScreenState();
}

class _MapRouteScreenState extends State<MapRouteScreen> {
  List<LatLng> _routePoints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    final startLon = widget.startLocation.longitude;
    final startLat = widget.startLocation.latitude;
    final endLon = widget.endLocation.longitude;
    final endLat = widget.endLocation.latitude;

    final url = 'http://router.project-osrm.org/route/v1/driving/$startLon,$startLat;$endLon,$endLat?geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;
          setState(() {
            _routePoints = coordinates.map((c) => LatLng(c[1], c[0])).toList();
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching route: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bounds = LatLngBounds.fromPoints([
      widget.startLocation,
      widget.endLocation,
      ..._routePoints,
    ]);

    return Scaffold(
      appBar: AppBar(
        title: Text('Route to ${widget.destinationName}', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: EdgeInsets.all(50.0),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.northomes.picklesystem',
                  tileProvider: CancellableNetworkTileProvider(),
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: Colors.blueAccent,
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.startLocation,
                      width: 40,
                      height: 40,
                      child: Icon(Icons.my_location, color: Colors.blue, size: 30),
                    ),
                    Marker(
                      point: widget.endLocation,
                      width: 40,
                      height: 40,
                      child: Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
