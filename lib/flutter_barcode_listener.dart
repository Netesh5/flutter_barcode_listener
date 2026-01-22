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
  DateTime? _lastEnterKeyTime;

  static const Duration _sameBarcodeCooldown = Duration(milliseconds: 100);
  static const Duration _enterKeyDebounce = Duration(milliseconds: 100);

  // Global tracking to prevent duplicate scans across all instances
  static String? _globalLastBarcode;
  static DateTime? _globalLastBarcodeTime;
  static bool _globalIsScanning = false;

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
      final now = DateTime.now();
      // Debounce Enter key to prevent duplicate processing
      if (_lastEnterKeyTime != null &&
          now.difference(_lastEnterKeyTime!) < _enterKeyDebounce) {
        return false;
      }
      _lastEnterKeyTime = now;
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
    // Early return if already processing or buffer is empty
    if (_isCompletingScan || _buffer.isEmpty) return;

    // Global check - prevent any instance from scanning if another is already scanning
    if (_globalIsScanning) return;

    // Set flags immediately to prevent concurrent execution
    _isCompletingScan = true;
    _globalIsScanning = true;

    // Capture barcode and clear buffer immediately to prevent re-processing
    final barcode = _buffer.join();
    _buffer.clear();
    _lastCharTime = null;

    final now = DateTime.now();

    // 🔒 FINAL GUARANTEE - Prevent duplicate scans of the same barcode (instance-level)
    if (_lastBarcode == barcode &&
        _lastBarcodeTime != null &&
        now.difference(_lastBarcodeTime!) < _sameBarcodeCooldown) {
      _isCompletingScan = false;
      _globalIsScanning = false;
      return;
    }

    // 🔒 GLOBAL GUARANTEE - Prevent duplicate scans across all instances
    if (_globalLastBarcode == barcode &&
        _globalLastBarcodeTime != null &&
        now.difference(_globalLastBarcodeTime!) < _sameBarcodeCooldown) {
      _isCompletingScan = false;
      _globalIsScanning = false;
      return;
    }

    // Update tracking before callback to prevent race conditions
    _lastBarcode = barcode;
    _lastBarcodeTime = now;
    _globalLastBarcode = barcode;
    _globalLastBarcodeTime = now;

    // Call the callback
    widget.onBarcodeScanned(barcode);

    // Reset flags after callback completes
    _isCompletingScan = false;
    _globalIsScanning = false;
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
