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
    this.useKeyDownEvent = false,
    this.bufferDuration = const Duration(milliseconds: 100),
    this.caseSensitive = false,
  }) : super(key: key);

  @override
  State<BarcodeKeyboardListener> createState() =>
      _BarcodeKeyboardListenerState();
}

class _BarcodeKeyboardListenerState extends State<BarcodeKeyboardListener> {
  final List<String> _buffer = [];
  DateTime? _lastCharTime;
  DateTime? _lastScanTime;

  bool _shiftPressed = false;

  static const Duration _scanDebounce = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  bool _handleKey(KeyEvent event) {
    final isValidEvent =
        widget.useKeyDownEvent ? event is KeyDownEvent : event is KeyUpEvent;

    if (!isValidEvent) return false;

    // 🔒 SCAN COMPLETE (ENTER)
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _completeScan();
      return false;
    }

    // SHIFT
    if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight) {
      _shiftPressed = true;
      return false;
    }

    final int keyId = event.logicalKey.keyId;

    // Printable ASCII only
    if (keyId < 0x20 || keyId > 0x7E) return false;

    final now = DateTime.now();

    // Reset buffer if typing too slow (human input)
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
    final now = DateTime.now();

    if (_lastScanTime != null &&
        now.difference(_lastScanTime!) < _scanDebounce) {
      return;
    }

    if (_buffer.isNotEmpty) {
      widget.onBarcodeScanned(_buffer.join());
      _lastScanTime = now;
    }

    _buffer.clear();
    _lastCharTime = null;
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }
}
