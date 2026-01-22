// library flutter_barcode_listener;

// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// typedef BarcodeScannedCallback = void Function(String barcode);

// /// This widget will listen for raw PHYSICAL keyboard events
// /// even when other controls have primary focus.
// /// It will buffer all characters coming in specifed `bufferDuration` time frame
// /// that end with line feed character and call callback function with result.
// /// Keep in mind this widget will listen for events even when not visible.
// /// Windows seems to be using the [HardwareKeyboard.keyDown] instead of the
// /// [HardwareKeyboard.keyUp], this behaviour can be managed by setting [useKeyDownEvent].
// class BarcodeKeyboardListener extends StatefulWidget {
//   final Widget child;
//   final BarcodeScannedCallback _onBarcodeScanned;
//   final Duration _bufferDuration;
//   final bool useKeyDownEvent;

//   /// Make barcode scanner return case sensitive characters
//   ///
//   /// Default value is false, It will sent scanned barcode with case sensitive
//   /// characters. It listen to [LogicalKeyboardKey.shiftLeft]
//   /// Currently support for Android
//   final bool caseSensitive;

//   /// This widget will listen for raw PHYSICAL keyboard events
//   /// even when other controls have primary focus.
//   /// It will buffer all characters coming in specifed `bufferDuration` time frame
//   /// that end with line feed character and call callback function with result.
//   /// Keep in mind this widget will listen for events even when not visible.
//   BarcodeKeyboardListener({
//     Key? key,

//     /// Child widget to be displayed.
//     required this.child,

//     /// Callback to be called when barcode is scanned.
//     required Function(String) onBarcodeScanned,

//     /// When experiencing issueswith empty barcodes on Windows,
//     /// set this value to true. Default value is `false`.
//     this.useKeyDownEvent = false,

//     /// Maximum time between two key events.
//     /// If time between two key events is longer than this value
//     /// previous keys will be ignored.
//     Duration bufferDuration = hundredMs,
//     this.caseSensitive = false,
//   })  : _onBarcodeScanned = onBarcodeScanned,
//         _bufferDuration = bufferDuration,
//         super(key: key);

//   @override
//   _BarcodeKeyboardListenerState createState() => _BarcodeKeyboardListenerState(
//       _onBarcodeScanned, _bufferDuration, useKeyDownEvent, caseSensitive);
// }

// const Duration aSecond = Duration(seconds: 1);
// const Duration hundredMs = Duration(milliseconds: 100);
// const String lineFeed = '\n';

// class _BarcodeKeyboardListenerState extends State<BarcodeKeyboardListener> {
//   List<String> _scannedChars = [];
//   DateTime? _lastScannedCharCodeTime;
//   late StreamSubscription<String?> _keyboardSubscription;

//   final BarcodeScannedCallback _onBarcodeScannedCallback;
//   final Duration _bufferDuration;

//   final _controller = StreamController<String?>();

//   final bool _useKeyDownEvent;

//   final bool _caseSensitive;

//   bool _isShiftPressed = false;

//   _BarcodeKeyboardListenerState(this._onBarcodeScannedCallback,
//       this._bufferDuration, this._useKeyDownEvent, this._caseSensitive) {
//     HardwareKeyboard.instance.addHandler(_keyBoardCallback);
//     _keyboardSubscription =
//         _controller.stream.where((char) => char != null).listen(onKeyEvent);
//   }

//   void onKeyEvent(String? char) {
//     //remove any pending characters older than bufferDuration value
//     checkPendingCharCodesToClear();
//     _lastScannedCharCodeTime = DateTime.now();
//     if (char == lineFeed) {
//       _onBarcodeScannedCallback.call(_scannedChars.join());
//       resetScannedCharCodes();
//     } else {
//       //add character to list of scanned characters;
//       _scannedChars.add(char!);
//     }
//   }

//   void checkPendingCharCodesToClear() {
//     if (_lastScannedCharCodeTime != null) {
//       if (_lastScannedCharCodeTime!
//           .isBefore(DateTime.now().subtract(_bufferDuration))) {
//         resetScannedCharCodes();
//       }
//     }
//   }

//   void resetScannedCharCodes() {
//     _lastScannedCharCodeTime = null;
//     _scannedChars = [];
//   }

//   void addScannedCharCode(String charCode) {
//     _scannedChars.add(charCode);
//   }

//   bool _keyBoardCallback(KeyEvent keyEvent) {
//     if ((!_useKeyDownEvent && keyEvent is KeyUpEvent) ||
//         (_useKeyDownEvent && keyEvent is KeyDownEvent)) {
//       if (keyEvent.logicalKey == LogicalKeyboardKey.shiftLeft) {
//         _isShiftPressed = true;
//       } else if (keyEvent.logicalKey == LogicalKeyboardKey.enter) {
//         _controller.sink.add(lineFeed);
//       } else if (keyEvent.logicalKey.keyId >= 0x20 &&
//           keyEvent.logicalKey.keyId <= 0x7A) {
//         var char = String.fromCharCode(keyEvent.logicalKey.keyId);
//         if (_isShiftPressed && _caseSensitive) {
//           _isShiftPressed = false;
//           char = char.toUpperCase();
//         }
//         _controller.sink.add(char);
//       }
//     }
//     return false;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return widget.child;
//   }

//   @override
//   void dispose() {
//     _keyboardSubscription.cancel();
//     _controller.close();
//     HardwareKeyboard.instance.removeHandler(_keyBoardCallback);
//     super.dispose();
//   }
// }

library flutter_barcode_listener;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef BarcodeScannedCallback = void Function(String barcode);

/// Listens to PHYSICAL keyboard events (barcode scanners)
/// Buffers characters arriving in quick succession
/// Ends scan on ENTER key
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
    this.bufferDuration = hundredMs,
    this.caseSensitive = false,
  }) : super(key: key);

  @override
  State<BarcodeKeyboardListener> createState() =>
      _BarcodeKeyboardListenerState();
}

const Duration hundredMs = Duration(milliseconds: 100);
const String lineFeed = '\n';

class _BarcodeKeyboardListenerState extends State<BarcodeKeyboardListener> {
  final List<String> _scannedChars = [];
  final StreamController<String?> _controller = StreamController<String?>();

  late final StreamSubscription<String?> _keyboardSubscription;

  DateTime? _lastScannedCharTime;
  bool _isShiftPressed = false;
  bool _enterHandled = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _keyboardSubscription =
        _controller.stream.where((c) => c != null).listen(_onChar);
  }

  /// Process buffered characters
  void _onChar(String? char) {
    _clearIfExpired();
    _lastScannedCharTime = DateTime.now();

    if (char == lineFeed) {
      if (_scannedChars.isNotEmpty) {
        widget.onBarcodeScanned(_scannedChars.join());
      }
      _reset();
    } else {
      _scannedChars.add(char!);
    }
  }

  /// Clear buffer if typing is too slow (human input)
  void _clearIfExpired() {
    if (_lastScannedCharTime == null) return;
    if (DateTime.now().difference(_lastScannedCharTime!) >
        widget.bufferDuration) {
      _reset();
    }
  }

  void _reset() {
    _scannedChars.clear();
    _lastScannedCharTime = null;
    _enterHandled = false;
  }

  /// Hardware keyboard handler
  bool _handleKeyEvent(KeyEvent event) {
    final isCorrectEvent =
        widget.useKeyDownEvent ? event is KeyDownEvent : event is KeyUpEvent;

    if (!isCorrectEvent) return false;

    // ENTER — handled once per scan
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_enterHandled) return false;
      _enterHandled = true;
      _controller.sink.add(lineFeed);
      return false;
    }

    // SHIFT
    if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight) {
      _isShiftPressed = true;
      return false;
    }

    // Printable ASCII characters only
    final int keyId = event.logicalKey.keyId;
    if (keyId < 0x20 || keyId > 0x7E) return false;

    String char = String.fromCharCode(keyId);

    if (_isShiftPressed && widget.caseSensitive) {
      char = char.toUpperCase();
    }

    _isShiftPressed = false;
    _controller.sink.add(char);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    _keyboardSubscription.cancel();
    _controller.close();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }
}
