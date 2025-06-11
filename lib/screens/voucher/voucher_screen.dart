import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/00_base/screen_base.dart';
import '../../utils/consts/theme_consts.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

class VoucherScreen extends BaseScreen {
  const VoucherScreen({Key? key}) : super(key: key);

  @override
  BaseScreenState<VoucherScreen> createState() => _VoucherScreenState();

  @override
  String computeTitle(BuildContext context) => 'Create Voucher';
}

class _VoucherScreenState extends BaseScreenState<VoucherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final GlobalKey _voucherKey = GlobalKey();
  int _descriptionSize = 3; // Default size

  double _getDescriptionFontSize() {
    switch (_descriptionSize) {
      case 1:
        return 6.0;
      case 2:
        return 7.0;
      case 3:
        return 8.0;
      case 4:
        return 9.0;
      case 5:
        return 10.0;
      default:
        return 8.0;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _createAndShareVoucher() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final amount = _amountController.text;
      final description = _descriptionController.text;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Creating voucher...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Load images as bytes from assets
      final giftImageBytes = await rootBundle.load('assets/images/gift-v-01.png');
      final bottomImageBytes = await rootBundle.load('assets/images/bottom-01.png');

      // Create PDF document
      final pdf = pw.Document();

      // Add a page to the PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Voucher Number
                pw.Container(
                  width: double.infinity,
                  child: pw.Text(
                    'No: $amount',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColor.fromHex('#34495e'),
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.SizedBox(height: 48),
                // Gift Image (left-aligned)
                pw.Image(
                  pw.MemoryImage(giftImageBytes.buffer.asUint8List()),
                  width: 200,
                  alignment: pw.Alignment.centerLeft,
                ),
                pw.SizedBox(height: 48),
                // Description
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(40),
                  child: pw.Text(
                    description,
                    style: pw.TextStyle(
                      fontSize: _getDescriptionFontSize() * 2,
                      color: PdfColor.fromHex('#34495e'),
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 48),
                // Bottom Image (centered, width 1200)
                pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(bottomImageBytes.buffer.asUint8List()),
                    width: 500,
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Save the PDF
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/voucher.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Your Voucher for €$amount',
        text: 'Please find your voucher attached.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating voucher: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      int sdkInt = 0;
      try {
        sdkInt = (await File('/system/build.prop').readAsLines()).where((line) => line.startsWith('ro.build.version.sdk=')).map((line) => int.tryParse(line.split('=')[1]) ?? 0).first;
      } catch (_) {}
      if (sdkInt >= 33) {
        // Android 13+ (Tiramisu): request media images permission
        var status = await Permission.photos.request();
        return status.isGranted;
      } else if (sdkInt >= 30) {
        // Android 11+ (R): request manage external storage
        var status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      } else {
        var status = await Permission.storage.request();
        return status.isGranted;
      }
    } else {
      var status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  Future<void> _saveVoucherToDownloads() async {
    try {
      bool granted = await requestStoragePermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to save the voucher'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final RenderRepaintBoundary boundary = _voucherKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      // Convert PNG bytes to JPEG with white background
      final pngBytes = byteData.buffer.asUint8List();
      final decodedImage = img.decodeImage(pngBytes);
      if (decodedImage == null) throw Exception('Failed to decode image');

      final whiteBackground = img.Image(width: decodedImage.width, height: decodedImage.height);
      img.fill(whiteBackground, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(whiteBackground, decodedImage);

      final jpegBytes = img.encodeJpg(whiteBackground);

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      final filePath = '${directory.path}/voucher_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(filePath);
      await file.writeAsBytes(jpegBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voucher saved to ${Platform.isIOS ? 'Documents' : 'Downloads'} folder'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving voucher: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Voucher Preview
                RepaintBoundary(
                  key: _voucherKey,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 595), // A4 width in logical pixels
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.all(20),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Voucher Number at the top
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0), // minimal top padding
                              child: SizedBox(
                                width: double.infinity,
                                child: Text(
                                  'No: ${_amountController.text}',
                                  style: const TextStyle(
                                    fontSize: 6.0,
                                    color: Color(0xFF34495e),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Gift Image
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Image.asset(
                                'assets/images/gift-v-01.png',
                                width: MediaQuery.of(context).size.width * 0.1875, // 25% smaller than 0.25
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Description
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                _descriptionController.text,
                                style: TextStyle(
                                  fontSize: _getDescriptionFontSize(),
                                  color: const Color(0xFF34495e),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Bottom Image
                            Image.asset(
                              'assets/images/bottom-01.png',
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Form Fields
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.primaryColor),
                  decoration: InputDecoration(
                    labelText: 'Number',
                    labelStyle: const TextStyle(color: AppColors.primaryColor),
                    prefixStyle: const TextStyle(color: AppColors.primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accentColor),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accentColor),
                    ),
                    floatingLabelStyle: const TextStyle(color: AppColors.accentColor),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Description Size Dropdown
                DropdownButtonFormField<int>(
                  value: _descriptionSize,
                  style: const TextStyle(color: AppColors.primaryColor),
                  dropdownColor: AppColors.accentColor,
                  decoration: InputDecoration(
                    labelText: 'Text Size',
                    labelStyle: const TextStyle(color: AppColors.primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accentColor),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accentColor),
                    ),
                    floatingLabelStyle: const TextStyle(color: AppColors.accentColor),
                  ),
                  items: List.generate(5, (index) => index + 1).map((size) {
                    return DropdownMenuItem<int>(
                      value: size,
                      child: Text(
                        'Size $size',
                        style: const TextStyle(color: AppColors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _descriptionSize = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.primaryColor),
                  decoration: InputDecoration(
                    labelText: 'Content',
                    hintText: 'Content',
                    labelStyle: const TextStyle(color: AppColors.primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accentColor),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accentColor),
                    ),
                    floatingLabelStyle: const TextStyle(color: AppColors.accentColor),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _createAndShareVoucher,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Create',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveVoucherToDownloads,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save to Downloads',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
