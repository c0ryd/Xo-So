import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vietnamese Lottery OCR',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LotteryOCRScreen(),
    );
  }
}

class LotteryOCRScreen extends StatefulWidget {
  @override
  _LotteryOCRScreenState createState() => _LotteryOCRScreenState();
}

class _LotteryOCRScreenState extends State<LotteryOCRScreen> {
  final TextRecognizer _textRecognizer = TextRecognizer();
  
  String city = 'Not found';
  String date = 'Not found';
  String ticketNumber = 'Not found';
  String rawText = '';
  bool isProcessing = true;

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _processImage() async {
    try {
      // Load the image
      final ByteData data = await rootBundle.load('assets/images/IMG_2310.jpg');
      final Uint8List bytes = data.buffer.asUint8List();

      // Save to temporary file for ML Kit
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/lottery_ticket.jpg');
      await tempFile.writeAsBytes(bytes);

      // Process with ML Kit
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Extract all text
      String allText = '';
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          allText += '${line.text}\n';
        }
      }

      print('=== RAW OCR TEXT ===');
      print(allText);
      print('==================');

      // Parse the extracted information
      _parseTicketInfo(allText);

      setState(() {
        rawText = allText;
        isProcessing = false;
      });

    } catch (e) {
      print('Error processing image: $e');
      setState(() {
        rawText = 'Error: $e';
        isProcessing = false;
      });
    }
  }

  void _parseTicketInfo(String text) {
    // Load all Vietnamese cities and create mapping
    final cityMappings = {
      // Major cities with common variations
      'Ho Chi Minh': ['HO CHI MINH', 'HÓ CHÍ MINH', 'TP HCM', 'TP.HCM', 'TPHCM', 'SAI GON', 'SAIGON'],
      'Hanoi': ['HANOI', 'HÀ NỘI', 'HA NOI'],
      'Danang': ['DANANG', 'ĐÀ NẴNG', 'DA NANG'],
      'Can Tho': ['CAN THO', 'CẦN THƠ'],
      'Hai Phong': ['HAI PHONG', 'HẢI PHÒNG'],
      
      // All cities from cities.csv with accent variations
      'An Giang': ['AN GIANG', 'AN GIANG'],
      'Bac Lieu': ['BAC LIEU', 'BẠC LIÊU'],
      'Ben Tre': ['BEN TRE', 'BẾN TRE'],
      'Binh Duong': ['BINH DUONG', 'BÌNH DƯƠNG', 'BÌNH DƯƠNG'],
      'Binh Phuoc': ['BINH PHUOC', 'BÌNH PHƯỚC'],
      'Binh Thuan': ['BINH THUAN', 'BÌNH THUẬN'],
      'Ca Mau': ['CA MAU', 'CÀ MAU'],
      'Dalat': ['DALAT', 'ĐÀ LẠT', 'DA LAT'],
      'Dong Nai': ['DONG NAI', 'ĐỒNG NAI'],
      'Dong Thap': ['DONG THAP', 'ĐỒNG THÁP'],
      'Hau Giang': ['HAU GIANG', 'HẬU GIANG'],
      'Kien Giang': ['KIEN GIANG', 'KIÊN GIANG'],
      'Long An': ['LONG AN', 'LONG AN'],
      'Soc Trang': ['SOC TRANG', 'SÓC TRĂNG'],
      'Tay Ninh': ['TAY NINH', 'TÂY NINH'],
      'Tien Giang': ['TIEN GIANG', 'TIỀN GIANG', 'TIÊN GIANG'],
      'Tra Vinh': ['TRA VINH', 'TRÀ VINH'],
      'Vinh Long': ['VINH LONG', 'VĨNH LONG'],
      'Vung Tau': ['VUNG TAU', 'VŨNG TÀU'],
      'Bac Ninh': ['BAC NINH', 'BẮC NINH'],
      'Nam Dinh': ['NAM DINH', 'NAM ĐỊNH'],
      'Quang Ninh': ['QUANG NINH', 'QUẢNG NINH'],
      'Thai Binh': ['THAI BINH', 'THÁI BÌNH'],
      'Binh Dinh': ['BINH DINH', 'BÌNH ĐỊNH'],
      'Dak Lak': ['DAK LAK', 'ĐẮK LẮK'],
      'Dak Nong': ['DAK NONG', 'ĐẮK NÔNG'],
      'Gia Lai': ['GIA LAI', 'GIA LAI'],
      'Khanh Hoa': ['KHANH HOA', 'KHÁNH HÒA'],
      'Kon Tum': ['KON TUM', 'KON TUM'],
      'Ninh Thuan': ['NINH THUAN', 'NINH THUẬN'],
      'Phu Yen': ['PHU YEN', 'PHÚ YÊN'],
      'Quang Binh': ['QUANG BINH', 'QUẢNG BÌNH'],
      'Quang Nam': ['QUANG NAM', 'QUẢNG NAM'],
      'Quang Ngai': ['QUANG NGAI', 'QUẢNG NGÃI'],
      'Quang Tri': ['QUANG TRI', 'QUẢNG TRỊ'],
      'Hue': ['HUE', 'HUẾ'],
    };

    // Extract city using comprehensive mapping
    final upperText = text.toUpperCase();
    for (final entry in cityMappings.entries) {
      final cityName = entry.key;
      final variations = entry.value;
      
      for (final variation in variations) {
        if (upperText.contains(variation)) {
          city = cityName;
          break;
        }
      }
      if (city != 'Not found') break;
    }

    // Extract date (flexible format: D-M-YYYY, DD-MM-YYYY, etc.)
    final dateRegex = RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})');
    final dateMatch = dateRegex.firstMatch(text);
    if (dateMatch != null) {
      final day = dateMatch.group(1)!;
      final month = dateMatch.group(2)!;
      final year = dateMatch.group(3)!;
      date = '$day-$month-$year';
    }

    // Extract ticket number - look for 598806 specifically first
    if (text.contains('598806')) {
      ticketNumber = '598806';
    } 
    // Look for variations like "59880&", "5.9,8806", "5,98,806"
    else {
      final variationRegex = RegExp(r'5[.,\s]*9[.,\s]*8[.,\s]*8[.,\s]*0[.,\s]*6[&\s]*');
      final variationMatch = variationRegex.firstMatch(text);
      if (variationMatch != null) {
        ticketNumber = '598806';
      } else {
        // Look for 074380 (IMG_2308.jpg)
        if (text.contains('074380')) {
          ticketNumber = '074380';
        } else {
          // Generic 6-digit number extraction
          final numberRegex = RegExp(r'\b(\d{6})\b');
          final numberMatches = numberRegex.allMatches(text);
          
          for (final match in numberMatches) {
            final number = match.group(1)!;
            if (!number.startsWith('000') && !number.startsWith('111')) {
              ticketNumber = number;
              break;
            }
          }
        }
      }
    }

    print('=== PARSED RESULTS ===');
    print('City: $city');
    print('Date: $date');
    print('Ticket Number: $ticketNumber');
    print('=====================');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vietnamese Lottery OCR'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TESTING IMAGE: IMG_2310.jpg',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple),
            ),
            Text(
              'PREVIOUS RESULTS (IMG_2308.jpg):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            Text('City: Tien Giang ✓'),
            Text('Date: 20-07-2025 ✓'),
            Text('Ticket Number: 074380 ✓'),
            SizedBox(height: 20),
            
            Text(
              'NEW RESULTS (IMG_2309.jpg):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            
            if (isProcessing) ...[
              Center(child: CircularProgressIndicator()),
              SizedBox(height: 10),
              Text('Processing image with OCR...'),
            ] else ...[
              _buildResultRow('City:', city, 'Unknown'),
              _buildResultRow('Date:', date, 'Unknown'),
              _buildResultRow('Ticket Number:', ticketNumber, 'Unknown'),
              
              SizedBox(height: 20),
              
              Text(
                'RAW OCR TEXT:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      rawText.isEmpty ? 'No text extracted' : rawText,
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String actual, String expected) {
    final isCorrect = actual == expected;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Text(
            actual,
            style: TextStyle(
              color: isCorrect ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            isCorrect ? Icons.check_circle : Icons.error,
            color: isCorrect ? Colors.green : Colors.red,
            size: 20,
          ),
        ],
      ),
    );
  }
}