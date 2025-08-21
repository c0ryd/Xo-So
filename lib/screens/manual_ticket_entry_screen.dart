import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/vietnamese_tiled_background.dart';
import '../services/ticket_storage_service.dart';
import 'camera_screen_clean.dart';
import 'dart:convert';

class ManualTicketEntryScreen extends StatefulWidget {
  const ManualTicketEntryScreen({Key? key}) : super(key: key);

  @override
  State<ManualTicketEntryScreen> createState() => _ManualTicketEntryScreenState();
}

class _ManualTicketEntryScreenState extends State<ManualTicketEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ticketNumberController = TextEditingController();
  final _dateController = TextEditingController();
  
  String? _selectedProvince;
  List<String> _provinces = [];
  List<String> _filteredProvinces = [];
  Map<String, List<String>> _provinceSchedule = {};
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
    _loadProvinceSchedule();
    _setDefaultDate();
  }

  @override
  void dispose() {
    _ticketNumberController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    try {
      setState(() => _isLoading = true);
      
      // Load cities data to get provinces
      final String citiesJson = await rootBundle.loadString('assets/cities.json');
      final Map<String, dynamic> citiesData = json.decode(citiesJson);
      
      // Extract unique provinces from the regions array
      final Set<String> provinceSet = {};
      if (citiesData['regions'] is List) {
        for (final region in citiesData['regions']) {
          if (region is Map<String, dynamic> && region['cities'] is List) {
            for (final city in region['cities']) {
              if (city is String) {
                provinceSet.add(city);
              }
            }
          }
        }
      }
      
      setState(() {
        _provinces = provinceSet.toList()..sort();
        _updateFilteredProvinces();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading provinces: $e');
      setState(() => _isLoading = false);
      
      // Fallback to schedule keys (provinces that have lottery drawings)
      _provinces = _provinceSchedule.keys.toList()..sort();
      _updateFilteredProvinces();
    }
  }

  Future<void> _loadProvinceSchedule() async {
    try {
      final String scheduleJson = await rootBundle.loadString('assets/province_schedule.json');
      final Map<String, dynamic> scheduleData = json.decode(scheduleJson);
      setState(() {
        _provinceSchedule = scheduleData.map(
          (key, value) => MapEntry(key, List<String>.from(value))
        );
        _updateFilteredProvinces();
      });
    } catch (e) {
      print('Error loading province schedule: $e');
      // Fallback to all provinces if schedule fails to load
      setState(() {
        _filteredProvinces = _provinces;
      });
    }
  }

  void _updateFilteredProvinces() {
    if (_dateController.text.isEmpty || _provinceSchedule.isEmpty) {
      setState(() {
        _filteredProvinces = _provinces;
      });
      return;
    }

    try {
      // Parse the date to get day of week
      final parts = _dateController.text.split('-');
      if (parts.length != 3) return;
      
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final selectedDate = DateTime(year, month, day);
      final dayOfWeek = _getDayOfWeek(selectedDate.weekday);
      
      print('🔍 Manual Mode: Filtering provinces for $dayOfWeek');
      
      // Filter provinces that have drawings on this day
      final validProvinces = <String>[];
      _provinceSchedule.forEach((province, days) {
        if (days.contains(dayOfWeek)) {
          // Convert province names to match cities.json format
          final convertedProvince = _convertProvinceNames(province);
          if (_provinces.contains(convertedProvince)) {
            validProvinces.add(convertedProvince);
          }
        }
      });
      
      print('✅ Valid provinces for $dayOfWeek: $validProvinces');
      
      setState(() {
        _filteredProvinces = validProvinces..sort();
        // Reset selected province if it's not valid for this day
        if (_selectedProvince != null && !_filteredProvinces.contains(_selectedProvince)) {
          _selectedProvince = null;
        }
      });
    } catch (e) {
      print('Error filtering provinces: $e');
      setState(() {
        _filteredProvinces = _provinces;
      });
    }
  }

  String _getDayOfWeek(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  String _convertProvinceNames(String scheduleName) {
    // Convert province schedule names to match cities.json names
    const nameMapping = {
      'Hanoi': 'Hà Nội',
      'Ho Chi Minh': 'TP. Hồ Chí Minh',
      'Da Nang': 'Đà Nẵng',
      'Can Tho': 'Cần Thơ',
      'Hai Phong': 'Hải Phòng',
      'Tien Giang': 'Tiền Giang',
      'Vinh Long': 'Vĩnh Long',
      'Tra Vinh': 'Trà Vinh',
      'Bac Lieu': 'Bạc Liêu',
      'Kien Giang': 'Kiên Giang',
      'Dong Thap': 'Đồng Tháp',
      'Tay Ninh': 'Tây Ninh',
      'Soc Trang': 'Sóc Trăng',
      'Long An': 'Long An',
      'Hue': 'Thừa Thiên Huế',
      'Binh Thuan': 'Bình Thuận',
      'Binh Duong': 'Bình Dương',
      'Binh Dinh': 'Bình Định',
      'Phu Yen': 'Phú Yên',
      'Dak Lak': 'Đắk Lắk',
      'Hau Giang': 'Hậu Giang',
      'Vung Tau': 'Bà Rịa - Vũng Tàu',
      'Binh Phuoc': 'Bình Phước',
      'Dong Nai': 'Đồng Nai',
      'Quang Binh': 'Quảng Bình',
      'Quang Nam': 'Quảng Nam',
      'Dak Nong': 'Đắk Nông',
      'Quang Ngai': 'Quảng Ngãi',
      'Quang Ninh': 'Quảng Ninh',
      'Quang Tri': 'Quảng Trị',
      'Gia Lai': 'Gia Lai',
      'Ca Mau': 'Cà Mau',
      'Bac Ninh': 'Bắc Ninh',
      'Ben Tre': 'Bến Tre',
      'Nam Dinh': 'Nam Định',
      'An Giang': 'An Giang',
      'Khanh Hoa': 'Khánh Hòa',
      'Thai Binh': 'Thái Bình',
      'Ninh Thuan': 'Ninh Thuận',
      'Kon Tum': 'Kon Tum',
      'Da Lat': 'Lâm Đồng',
    };
    return nameMapping[scheduleName] ?? scheduleName;
  }

  String _getSelectedDayName() {
    if (_dateController.text.isEmpty) return 'today';
    
    try {
      final parts = _dateController.text.split('-');
      if (parts.length != 3) return 'selected day';
      
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final selectedDate = DateTime(year, month, day);
      return _getDayOfWeek(selectedDate.weekday);
    } catch (e) {
      return 'selected day';
    }
  }

  void _setDefaultDate() {
    // Set default to today's date in DD-MM-YYYY format
    final now = DateTime.now();
    _dateController.text = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    _updateFilteredProvinces();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFFA5362D), // Red primary color
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateController.text = '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
      });
      _updateFilteredProvinces();
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate() || _selectedProvince == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Navigate to camera screen with manual data
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(
            manualCity: _selectedProvince!,
            manualDate: _dateController.text,
            manualTicketNumber: _ticketNumberController.text.trim(),
            isManualEntry: true,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Manual Ticket Entry',
          style: TextStyle(color: Color(0xFFFFD966)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFFFD966)),
      ),
      body: VietnameseTiledBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        // Instructions
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFFD966).withOpacity(0.3),
                            ),
                          ),
                          child: const Text(
                            '🎯 Manual Mode: Enter ticket details manually for testing',
                            style: TextStyle(
                              color: Color(0xFFFFD966),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Date picker
                        TextFormField(
                          controller: _dateController,
                          decoration: InputDecoration(
                            labelText: 'Draw Date',
                            labelStyle: const TextStyle(color: Color(0xFFFFD966)),
                            hintText: 'DD-MM-YYYY',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today, color: Color(0xFFFFD966)),
                              onPressed: _selectDate,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFFFFD966)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFFFFD966), width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.red),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.red, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          readOnly: true,
                          onTap: _selectDate,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a date';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Province dropdown
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Show filtered count
                            if (_filteredProvinces.isNotEmpty && _filteredProvinces.length < _provinces.length)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  '📍 ${_filteredProvinces.length} provinces have drawings on ${_getSelectedDayName()}',
                                  style: TextStyle(
                                    color: Color(0xFFFFD966).withOpacity(0.8),
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            DropdownButtonFormField<String>(
                          value: _selectedProvince,
                          decoration: InputDecoration(
                            labelText: 'Province',
                            labelStyle: const TextStyle(color: Color(0xFFFFD966)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFFFFD966)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFFFFD966), width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.red),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.red, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          dropdownColor: const Color(0xFF2C1810),
                          style: const TextStyle(color: Colors.white),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFD966)),
                          items: _filteredProvinces.map((String province) {
                            return DropdownMenuItem<String>(
                              value: province,
                              child: Text(
                                province,
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            setState(() {
                              _selectedProvince = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a province';
                            }
                            return null;
                          },
                        ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Ticket number input
                        TextFormField(
                          controller: _ticketNumberController,
                          decoration: InputDecoration(
                            labelText: 'Ticket Number',
                            labelStyle: const TextStyle(color: Color(0xFFFFD966)),
                            hintText: 'Enter 6-digit ticket number',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFFFFD966)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFFFFD966), width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.red),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.red, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a ticket number';
                            }
                            if (value.length != 6) {
                              return 'Ticket number must be 6 digits';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Submit button
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitTicket,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA5362D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSubmitting
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Submitting...'),
                                  ],
                                )
                              : const Text(
                                  'Submit Ticket',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
