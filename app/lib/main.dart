import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const platform = MethodChannel('com.asomoza.flash_orders/qr_scanner');

  String _scanStatus = 'Aún no has escaneado.';

  Future<void> _startScan() async {
    String status;
    try {
      final productId = await platform.invokeMethod<int>('startScan');
      status = 'Producto escaneado: $productId';
    } on PlatformException catch (e) {
      status = switch(e.code){

        'permissionDenied'  => 'Error: No tiene Permisos',
        'cameraUnavailable' => 'Error: camara no disponible',
        'invalidQr'         => 'Error: QR invalido',
        'cancelled'         => 'Escaneo cancelado',
        'scanInProgress'    => 'Ya hay un escaneo en progreso',
        _                   => 'Error desconocido',
      };
    }

    setState(() {
      _scanStatus = status;
    });
  }

  Future<void>  _scanAndCancelLater() async {
    Future.delayed(const Duration(seconds: 5), () {
      platform.invokeListMethod("cancelScan");
    });
    await _startScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escaner QR')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: _startScan,
              child: const Text('Escanear QR'),
            ),
            ElevatedButton(
              onPressed: _scanAndCancelLater,
              child: const Text('Escanear y cancelar en 5 s'),
            ),
            Text(_scanStatus),
          ],
        ),
      ),
    );
  }
}
