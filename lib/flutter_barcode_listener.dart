library flutter_barcode_listener;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef BarcodeScannedCallback = void Function(String barcode);

class BarcodeKeyboardListener extends StatefulWidget {
  final Widget child;
  final BarcodeScannedCallback onBarcodeScanned;
  final Duration bufferDuration;
  final bool useKeyDownEvent;
  final bool caseSensitive;

  const BarcodeKeyboardListener({
    Key? key,
    required this.child,
    required this.onBarcodeScanned,
    this.bufferDuration = const Duration(milliseconds: 100),
    this.useKeyDownEvent = false,
    this.caseSensitive = false,
  });

  @override
  State<BarcodeKeyboardListener> createState() =>
      _BarcodeKeyboardListenerState();
}

class _BarcodeKeyboardListenerState extends State<BarcodeKeyboardListener> {
  final List<String> _buffer = [];

  DateTime? _lastCharTime;
  String? _lastBarcode;
  DateTime? _lastBarcodeTime;

  bool _shiftPressed = false;
  bool _handlerRegistered = false;
  bool _isCompletingScan = false;

  static const Duration _sameBarcodeCooldown = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    if (!_handlerRegistered) {
      HardwareKeyboard.instance.addHandler(_handleKey);
      _handlerRegistered = true;
    }
  }

  bool _handleKey(KeyEvent event) {
    final validEvent =
        widget.useKeyDownEvent ? event is KeyDownEvent : event is KeyUpEvent;

    if (!validEvent) return false;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _completeScan();
      return false;
    }

    if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight) {
      _shiftPressed = true;
      return false;
    }

    final keyId = event.logicalKey.keyId;
    if (keyId < 0x20 || keyId > 0x7E) return false;

    final now = DateTime.now();

    if (_lastCharTime != null &&
        now.difference(_lastCharTime!) > widget.bufferDuration) {
      _buffer.clear();
    }

    _lastCharTime = now;

    String char = String.fromCharCode(keyId);
    if (_shiftPressed && widget.caseSensitive) {
      char = char.toUpperCase();
    }

    _shiftPressed = false;
    _buffer.add(char);

    return false;
  }

  void _completeScan() {
    if (_buffer.isEmpty || _isCompletingScan) return;

    _isCompletingScan = true;

    final barcode = _buffer.join();
    final now = DateTime.now();

    // 🔒 FINAL GUARANTEE
    if (_lastBarcode == barcode &&
        _lastBarcodeTime != null &&
        now.difference(_lastBarcodeTime!) < _sameBarcodeCooldown) {
      _buffer.clear();
      _lastCharTime = null;
      _isCompletingScan = false;
      return;
    }

    _lastBarcode = barcode;
    _lastBarcodeTime = now;

    widget.onBarcodeScanned(barcode);

    _buffer.clear();
    _lastCharTime = null;
    _isCompletingScan = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    if (_handlerRegistered) {
      HardwareKeyboard.instance.removeHandler(_handleKey);
      _handlerRegistered = false;
    }
    super.dispose();
  }
}
