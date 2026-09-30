import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/model/payment.dart';
import '../core/net/api_exception.dart';
import '../core/providers.dart';
import '../l10n/strings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'confirm_pay_screen.dart';

/// Step 1 of paying: scan the merchant's QR and have the server check it.
///
/// Nothing read from the QR is shown or trusted beyond the code itself: the
/// code goes to the server, and the next screen shows who the SERVER says it
/// belongs to. A forged sticker therefore cannot display a trusted name.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _checking = false;
  String? _error;
  bool _torch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_checking) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    final code = parsePayQr(raw);
    if (code == null) {
      setState(() => _error = Strings.notDjassaQr);
      return;
    }
    await _check(code);
  }

  Future<void> _check(String code) async {
    setState(() {
      _checking = true;
      _error = null;
    });
    await _controller.stop();
    HapticFeedback.mediumImpact();
    try {
      final target = await ref.read(djassaApiProvider).checkPayCode(code);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ConfirmPayScreen(target: target)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = errorMessage(e);
      });
      await _controller.start();
    }
  }

  Future<void> _typeCode() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CodeSheet(),
    );
    if (code != null && mounted) await _check(code);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final window = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.7,
      height: size.width * 0.7,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // No scanWindow: a QR anywhere in the camera view is read. The frame
          // below is a guide only. Restricting detection to it failed on phones
          // whose camera preview is scaled differently from the screen.
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  // Say which problem it is: a refused permission is fixed in
                  // the settings, anything else by typing the code.
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? Strings.cameraDenied
                      : Strings.scannerUnavailable,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
          CustomPaint(painter: _ViewfinderPainter(window)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        tooltip: Strings.cancel,
                      ),
                      const Expanded(
                        child: Text(Strings.scanTitle,
                            textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                      IconButton(
                        onPressed: () {
                          _controller.toggleTorch();
                          setState(() => _torch = !_torch);
                        },
                        icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
                        tooltip: Strings.torch,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: window.bottom - MediaQuery.paddingOf(context).top - 20),
                if (_checking)
                  const _Pill(icon: null, text: Strings.checking, busy: true)
                else if (_error != null)
                  _Pill(icon: Icons.error_outline_rounded, text: _error!, color: const Color(0xFFFFD4C7))
                else
                  const _Pill(icon: Icons.center_focus_strong_rounded, text: Strings.scanHint),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54, width: 1.5),
                    ),
                    onPressed: _checking ? null : _typeCode,
                    icon: const Icon(Icons.keyboard_rounded),
                    label: const Text(Strings.typeCode),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, this.busy = false, this.color = Colors.white});

  final IconData? icon;
  final String text;
  final bool busy;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(DjassaRadius.md)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
          else if (icon != null)
            Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Flexible(child: Text(text, style: TextStyle(color: color, fontSize: 14.5, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

/// Dims everything but the scan window and draws orange corner brackets.
class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter(this.window);

  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(window, const Radius.circular(24));
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(rrect)),
      Paint()..color = Colors.black.withOpacity(0.58),
    );
    final paint = Paint()
      ..color = DjassaColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const len = 34.0;
    const r = 24.0;
    final l = window.left, t = window.top, rt = window.right, b = window.bottom;
    for (final path in [
      Path()
        ..moveTo(l, t + len)
        ..lineTo(l, t + r)
        ..arcToPoint(Offset(l + r, t), radius: const Radius.circular(r))
        ..lineTo(l + len, t),
      Path()
        ..moveTo(rt - len, t)
        ..lineTo(rt - r, t)
        ..arcToPoint(Offset(rt, t + r), radius: const Radius.circular(r))
        ..lineTo(rt, t + len),
      Path()
        ..moveTo(rt, b - len)
        ..lineTo(rt, b - r)
        ..arcToPoint(Offset(rt - r, b), radius: const Radius.circular(r))
        ..lineTo(rt - len, b),
      Path()
        ..moveTo(l + len, b)
        ..lineTo(l + r, b)
        ..arcToPoint(Offset(l, b - r), radius: const Radius.circular(r))
        ..lineTo(l, b - len),
    ]) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) => old.window != window;
}

/// Manual entry for a damaged sticker or a phone whose camera is refused.
class _CodeSheet extends StatefulWidget {
  const _CodeSheet();

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = RegExp(r'^[A-Z0-9]{6,16}$').hasMatch(_code.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(Strings.typeCode, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              TextInputFormatter.withFunction((_, v) => v.copyWith(text: v.text.toUpperCase())),
              LengthLimitingTextInputFormatter(16),
            ],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 4),
            decoration: const InputDecoration(hintText: Strings.typeCodeHint, prefixIcon: Icon(Icons.qr_code_2_rounded)),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: valid ? () => Navigator.of(context).pop(_code.text) : null, child: const Text(Strings.validate)),
        ],
      ),
    );
  }
}
