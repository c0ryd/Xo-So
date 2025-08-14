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
      appBar: AppBar(
        title: const Text('Results'),
      ),
      body: VietnameseTiledBackground(
        child: Column(
          children: [
            // Calendar
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFFFE8BE),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
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
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFFE8BE),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildProvincesList(),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFA5362D),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: Color(0xFFFFE8BE)),
            onPressed: () {
              setState(() {
                _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1);
              });
            },
          ),
          Text(
            '${_getMonthName(_focusedDate.month)} ${_focusedDate.year}',
            style: TextStyle(
              color: Color(0xFFFFE8BE),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: Color(0xFFFFE8BE)),
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
                            color: Colors.grey[600],
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
                            ? Color(0xFFA5362D)
                            : isToday
                                ? Colors.orange.withOpacity(0.3)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday && !isSelected
                            ? Border.all(color: Colors.orange, width: 2)
                            : null,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              dayNumber.toString(),
                              style: TextStyle(
                                color: isSelected
                                    ? Color(0xFFFFE8BE)
                                    : Colors.black87,
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
          'Provinces with drawings on ${_formatSelectedDate()}:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFFA5362D),
          ),
        ),
        SizedBox(height: 12),
        Expanded(
          child: _selectedDayProvinces.isEmpty
              ? Center(
                  child: Text(
                    'No drawings scheduled for this day',
                    style: TextStyle(
                      color: Colors.grey[600],
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Color(0xFFA5362D),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                province,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey[400],
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
}
