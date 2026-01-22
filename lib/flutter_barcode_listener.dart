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
  final StringBuffer _buffer = StringBuffer();

  int? _lastCharTime;

  bool _shiftPressed = false;
  bool _handlerRegistered = false;
  bool _isCompletingScan = false;
  int _lastBarcodeHash = 0;
  int _lastBarcodeTimeMs = 0;

  static const int _sameBarcodeCooldownMs = 10;

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

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (_lastCharTime != null) {
      final timeDiff = nowMs - _lastCharTime!;
      if (timeDiff > widget.bufferDuration.inMilliseconds) {
        _buffer.clear();
      }
    }

    _lastCharTime = nowMs;

    String char = String.fromCharCode(keyId);
    if (_shiftPressed && widget.caseSensitive) {
      char = char.toUpperCase();
    }

    _shiftPressed = false;
    _buffer.write(char);

    return false;
  }

  void _completeScan() {
    if (_buffer.length == 0 || _isCompletingScan) return;

    _isCompletingScan = true;

    // Capture barcode and clear buffer immediately
    final barcode = _buffer.toString();
    _buffer.clear();
    _lastCharTime = null;

    // Fast duplicate check using hash and milliseconds
    final barcodeHash = barcode.hashCode;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (barcodeHash == _lastBarcodeHash &&
        (nowMs - _lastBarcodeTimeMs) < _sameBarcodeCooldownMs) {
      _isCompletingScan = false;
      return;
    }

    // Update tracking before callback
    _lastBarcodeHash = barcodeHash;
    _lastBarcodeTimeMs = nowMs;

    // Call callback immediately for fastest response
    widget.onBarcodeScanned(barcode);

    // Reset flag immediately
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
