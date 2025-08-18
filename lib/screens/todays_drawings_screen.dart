import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:convert';
import '../widgets/vietnamese_tiled_background.dart';
import 'province_results_screen.dart';

class TodaysDrawingsScreen extends StatefulWidget {
  const TodaysDrawingsScreen({Key? key}) : super(key: key);

  @override
  State<TodaysDrawingsScreen> createState() => _TodaysDrawingsScreenState();
}

class _TodaysDrawingsScreenState extends State<TodaysDrawingsScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  Map<String, List<String>> _provinceSchedule = {};
  List<String> _selectedDayProvinces = [];

  @override
  void initState() {
    super.initState();
    _loadProvinceSchedule();
  }

  Future<void> _loadProvinceSchedule() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/province_schedule.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      setState(() {
        _provinceSchedule = data.map((key, value) => MapEntry(key, List<String>.from(value)));
        _updateSelectedDayProvinces();
      });
    } catch (e) {
      print('Error loading province schedule: $e');
    }
  }

  void _updateSelectedDayProvinces() {
    final dayName = _getDayName(_selectedDate.weekday);
    final provinces = <String>[];
    
    _provinceSchedule.forEach((province, days) {
      if (days.contains(dayName)) {
        provinces.add(province);
      }
    });
    
    setState(() {
      _selectedDayProvinces = provinces..sort();
    });
  }

  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Let content go under AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparent AppBar
        elevation: 0, // No shadow
        title: Text(AppLocalizations.of(context)!.todaysDrawingsTitle, style: TextStyle(color: Color(0xFFFFD966))),
        iconTheme: IconThemeData(color: Color(0xFFFFD966)), // Gold back button
      ),
      body: VietnameseTiledBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
            children: [
              // Calendar with responsive margins
              Container(
                margin: EdgeInsets.all(
                  MediaQuery.of(context).size.width * 0.04, // 4% of screen width
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(0xFFFFD966), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildCalendarHeader(),
                    _buildCalendarGrid(),
                  ],
                ),
              ),
              // Selected day provinces
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(0xFFFFD966), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height * 0.3, // 30% of screen height
                  maxHeight: MediaQuery.of(context).size.height * 0.6, // Maximum height
                ),
                child: _buildProvincesList(),
              ),
              SizedBox(height: 16),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFFFFD966).withOpacity(0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: Color(0xFFFFD966)),
            onPressed: () {
              setState(() {
                _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1);
              });
            },
          ),
          Text(
            '${_getMonthName(_focusedDate.month)} ${_focusedDate.year}',
            style: TextStyle(
              color: Color(0xFFFFD966),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: Color(0xFFFFD966)),
            onPressed: () {
              setState(() {
                _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final lastDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD966).withOpacity(0.8),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          SizedBox(height: 8),
          // Calendar grid
          ...List.generate((daysInMonth + firstDayWeekday - 1) ~/ 7 + 1, (weekIndex) {
            return Row(
              children: List.generate(7, (dayIndex) {
                final dayNumber = weekIndex * 7 + dayIndex - firstDayWeekday + 2;
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return Expanded(child: SizedBox(height: 40));
                }

                final date = DateTime(_focusedDate.year, _focusedDate.month, dayNumber);
                final isSelected = _isSameDay(date, _selectedDate);
                final isToday = _isSameDay(date, DateTime.now());

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                        _updateSelectedDayProvinces();
                      });
                    },
                    child: Container(
                      height: 40,
                      margin: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Color(0xFFFFD966)
                            : isToday
                                ? Color(0xFFFFD966).withOpacity(0.2)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday && !isSelected
                            ? Border.all(color: Color(0xFFFFD966), width: 2)
                            : null,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              dayNumber.toString(),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.black87
                                    : Colors.white,
                                fontWeight: isSelected || isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          // Yellow star for today
                          if (isToday && !isSelected)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Icon(
                                Icons.star,
                                color: Colors.yellow[600],
                                size: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProvincesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${AppLocalizations.of(context)!.provincesWithDrawings} ${_formatSelectedDate()}:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFD966),
          ),
        ),
        SizedBox(height: 12),
        Expanded(
          child: _selectedDayProvinces.isEmpty
              ? Center(
                  child: Text(
                    AppLocalizations.of(context)!.noDrawingsScheduled,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _selectedDayProvinces.length,
                  itemBuilder: (context, index) {
                    final province = _selectedDayProvinces[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProvinceResultsScreen(
                              province: province,
                              date: _selectedDate,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFFFFD966).withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Color(0xFFFFD966),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getDisplayProvinceName(province),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Color(0xFFFFD966).withOpacity(0.6),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _formatSelectedDate() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getDisplayProvinceName(String province) {
    // Map province names to proper Vietnamese with accents
    // This mapping should be used for both English and Vietnamese display
    const provinceMap = {
      'An Giang': 'An Giang',
      'Bac Lieu': 'Bạc Liêu',
      'Bac Ninh': 'Bắc Ninh',
      'Ben Tre': 'Bến Tre',
      'Binh Dinh': 'Bình Định',
      'Binh Duong': 'Bình Dương',
      'Binh Phuoc': 'Bình Phước',
      'Binh Thuan': 'Bình Thuận',
      'Ca Mau': 'Cà Mau',
      'Can Tho': 'Cần Thơ',
      'Da Lat': 'Đà Lạt',
      'Da Nang': 'Đà Nẵng',
      'Dak Lak': 'Đắk Lắk',
      'Dak Nong': 'Đắk Nông',
      'Dong Nai': 'Đồng Nai',
      'Dong Thap': 'Đồng Tháp',
      'Gia Lai': 'Gia Lai',
      'Hai Phong': 'Hải Phòng',
      'Hanoi': 'Hà Nội',
      'Hau Giang': 'Hậu Giang',
      'Ho Chi Minh': 'Hồ Chí Minh',
      'Hue': 'Huế',
      'Khanh Hoa': 'Khánh Hòa',
      'Kien Giang': 'Kiên Giang',
      'Kon Tum': 'Kon Tum',
      'Long An': 'Long An',
      'Nam Dinh': 'Nam Định',
      'Ninh Thuan': 'Ninh Thuận',
      'Phu Yen': 'Phú Yên',
      'Quang Binh': 'Quảng Bình',
      'Quang Nam': 'Quảng Nam',
      'Quang Ngai': 'Quảng Ngãi',
      'Quang Ninh': 'Quảng Ninh',
      'Quang Tri': 'Quảng Trị',
      'Soc Trang': 'Sóc Trăng',
      'Tay Ninh': 'Tây Ninh',
      'Thai Binh': 'Thái Bình',
      'Tien Giang': 'Tiền Giang',
      'Tra Vinh': 'Trà Vinh',
      'Vinh Long': 'Vĩnh Long',
      'Vung Tau': 'Vũng Tàu',
    };
    
    return provinceMap[province] ?? province;
  }
}
