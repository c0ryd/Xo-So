import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';
import '../widgets/vietnamese_tiled_background.dart';
import '../services/image_storage_service.dart';
import '../config/app_config.dart';

class UserTicketsSummaryScreen extends StatefulWidget {
  const UserTicketsSummaryScreen({Key? key}) : super(key: key);

  @override
  State<UserTicketsSummaryScreen> createState() => _UserTicketsSummaryScreenState();
}

class _UserTicketsSummaryScreenState extends State<UserTicketsSummaryScreen> {
  bool _isLoading = true;
  Map<String, Map<String, List<Map<String, dynamic>>>> _ticketsByDateAndProvince = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserTickets();
  }

  Future<void> _fetchUserTickets() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Make direct API call (no authentication needed for API Gateway)
      final apiPath = AppConfig.isProduction ? '/prod/getUserTickets/${user.id}' : '/dev/getUserTickets/${user.id}';
      final apiUrl = '${AppConfig.apiGatewayBaseUrl}$apiPath';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final tickets = (responseData['tickets'] as List).cast<Map<String, dynamic>>();
        

        // Filter tickets to last 30 days based on draw date
        final now = DateTime.now();
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        
        final recentTickets = tickets.where((ticket) {
          final drawDate = ticket['drawDate'] as String?;
          if (drawDate != null) {
            try {
              final drawDateTime = DateTime.parse(drawDate);
              return drawDateTime.isAfter(thirtyDaysAgo);
            } catch (e) {
              print('Error parsing draw date: $drawDate');
              return false;
            }
          }
          return false;
        }).toList();
        

        
        // Group tickets: Date -> Province -> Tickets
        final Map<String, Map<String, List<Map<String, dynamic>>>> groupedTickets = {};
        
        for (final ticket in recentTickets) {
          final drawDate = ticket['drawDate'] as String? ?? '';
          final province = ticket['province'] as String? ?? '';
          
          // Initialize date group if not exists
          if (!groupedTickets.containsKey(drawDate)) {
            groupedTickets[drawDate] = {};
          }
          
          // Initialize province group within date if not exists
          if (!groupedTickets[drawDate]!.containsKey(province)) {
            groupedTickets[drawDate]![province] = [];
          }
          
          groupedTickets[drawDate]![province]!.add(ticket);
        }

        // Sort tickets within each province by winner status (winners first) then by ticket number
        for (final dateTickets in groupedTickets.values) {
          for (final provinceTickets in dateTickets.values) {
            provinceTickets.sort((a, b) {
              // First sort by win status (winners first)
              final aIsWinner = (a['isWinner'] as bool?) ?? false;
              final bIsWinner = (b['isWinner'] as bool?) ?? false;
              if (aIsWinner != bIsWinner) {
                return bIsWinner ? 1 : -1; // Winners first
              }
              
              // Then sort by ticket number
              final aTicketNumber = a['ticketNumber'] as String? ?? '';
              final bTicketNumber = b['ticketNumber'] as String? ?? '';
              return aTicketNumber.compareTo(bTicketNumber);
            });
          }
        }

        setState(() {
          _ticketsByDateAndProvince = groupedTickets;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch tickets: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching tickets: $e';
        _isLoading = false;
      });
    }
  }

  // Authentication no longer needed - using direct API calls

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Let content go under AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparent AppBar
        elevation: 0, // No shadow
        title: Text(AppLocalizations.of(context)!.myTicketsTitle, style: TextStyle(color: Color(0xFFFFD966))),
        iconTheme: IconThemeData(color: Color(0xFFFFD966)), // Gold back button and refresh icon
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Color(0xFFFFD966), // Gold refresh icon
            onPressed: _fetchUserTickets,
          ),
        ],
      ),
      body: VietnameseTiledBackground(
        child: SafeArea(
          child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchUserTickets,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _ticketsByDateAndProvince.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No tickets found'),
                          SizedBox(height: 8),
                          Text('Scan some lottery tickets to see them here!'),
                          SizedBox(height: 8),
                          Text('(Showing last 30 days only)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchUserTickets,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _ticketsByDateAndProvince.length,
                        itemBuilder: (context, index) {
                          final sortedDates = _ticketsByDateAndProvince.keys.toList()
                            ..sort((a, b) => b.compareTo(a)); // Sort dates newest first
                          final date = sortedDates[index];
                          final provinceTickets = _ticketsByDateAndProvince[date]!;
                          return _buildDateSection(date, provinceTickets);
                        },
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildDateSection(String date, Map<String, List<Map<String, dynamic>>> provinceTickets) {
    final totalTickets = provinceTickets.values.fold<int>(0, (sum, tickets) => sum + tickets.length);
    final totalWinnings = provinceTickets.values
        .expand((tickets) => tickets)
        .where((ticket) => (ticket['isWinner'] as bool?) ?? false)
        .fold<int>(0, (sum, ticket) {
          final winAmount = ticket['winAmount'];
          if (winAmount is num) {
            return sum + winAmount.toInt();
          }
          return sum;
        });

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Row(
              children: [
                Icon(Icons.calendar_today, color: Color(0xFFFFD966), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDateDisplay(date),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD966),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFE8BE).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalTickets ${totalTickets != 1 ? AppLocalizations.of(context)!.tickets : AppLocalizations.of(context)!.ticket}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFFD966),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            if (totalWinnings > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFFFFE8BE).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Color(0xFFFFE8BE), size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Total Winnings: ${totalWinnings.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} VND',
                        style: TextStyle(
                          color: Color(0xFFFFD966),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Province sections
            ...provinceTickets.entries.map((entry) {
              final province = entry.key;
              final tickets = entry.value;
              return _buildProvinceSection(province, tickets);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProvinceSection(String province, List<Map<String, dynamic>> tickets) {
    final winningTickets = tickets.where((ticket) => (ticket['isWinner'] as bool?) ?? false).toList();
    final totalWinnings = winningTickets.fold<int>(0, (sum, ticket) {
      final winAmount = ticket['winAmount'];
      if (winAmount is num) {
        return sum + winAmount.toInt();
      }
      return sum;
    });
    
    // Check if any tickets are pending (not checked yet)
    // Pending = no isWinner yet (backend sets isWinner true/false after check)
    final hasPendingTickets = tickets.any((ticket) => ticket['isWinner'] == null);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFFFD966).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Province header with pending status
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: province,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFD966),
                        ),
                      ),
                      if (hasPendingTickets) ...[
                        TextSpan(text: ' - '),
                        TextSpan(
                          text: Localizations.localeOf(context).languageCode == 'vi' ? 'Chờ kết quả' : 'Pending',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade300,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          if (totalWinnings > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  const Icon(Icons.celebration, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Total: ${totalWinnings.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} VND',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 8),
          
          // Tickets list (deduplicated)
          ..._buildDeduplicatedTickets(tickets),
        ],
      ),
    );
  }

  List<Widget> _buildDeduplicatedTickets(List<Map<String, dynamic>> tickets) {
    // Group tickets by ticket number, date, and province
    final Map<String, List<Map<String, dynamic>>> groupedTickets = {};
    
    for (final ticket in tickets) {
      final ticketNumber = ticket['ticketNumber'] as String? ?? '';
      final drawDate = ticket['drawDate'] as String? ?? '';
      final province = ticket['province'] as String? ?? '';
      
      final key = '${ticketNumber}_${drawDate}_$province';
      
      if (!groupedTickets.containsKey(key)) {
        groupedTickets[key] = [];
      }
      groupedTickets[key]!.add(ticket);
    }
    
    // Build cards with counts
    final List<Widget> cards = [];
    for (final entry in groupedTickets.entries) {
      final ticketGroup = entry.value;
      final count = ticketGroup.length;
      
      // Use the first ticket as the representative
      final representativeTicket = ticketGroup.first;
      
      // If there are multiple tickets, sum the win amounts
      int totalWinAmount = 0;
      for (final ticket in ticketGroup) {
        if (ticket['winAmount'] is num) {
          totalWinAmount += (ticket['winAmount'] as num).toInt();
        }
      }
      
      // Update the representative ticket with total win amount if needed
      if (totalWinAmount > 0) {
        representativeTicket['winAmount'] = totalWinAmount;
      }
      
      cards.add(_buildTicketCard(representativeTicket, count: count));
    }
    
    return cards;
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket, {int count = 1}) {
    final isWinner = (ticket['isWinner'] as bool?) ?? false;
    // Consider ticket "checked" if backend has set isWinner or a checkedAt exists
    final hasBeenChecked = ticket['isWinner'] != null || ticket['checkedAt'] != null;
    final drawDate = ticket['drawDate'] as String? ?? '';
    final ticketNumber = ticket['ticketNumber'] as String? ?? '';
    final winAmount = (ticket['winAmount'] is num) ? (ticket['winAmount'] as num).toInt() : 0;
    final matchedTiers = ticket['matchedTiers'] as List? ?? [];
    final prizeCategory = ticket['prizeCategory'] as String? ?? '';
    final imagePath = ticket['imagePath'] as String? ?? '';
    
    // Determine border color, pill color, and text color based on status
    Color borderColor;
    Color pillBackgroundColor;
    Color pillTextColor;
    double borderWidth = 2.0;
    
    if (!hasBeenChecked) {
      borderColor = Colors.orange; // Pending
      pillBackgroundColor = Colors.orange; // Solid orange pill for pending
      pillTextColor = Colors.white; // White text for visibility
    } else if (isWinner) {
      borderColor = Colors.green; // Winner
      pillBackgroundColor = Colors.green; // Solid green pill for winner
      pillTextColor = Colors.white; // White text for visibility
    } else {
      borderColor = Colors.red; // Not a winner
      pillBackgroundColor = Colors.red.shade400; // Solid red pill for not winner
      pillTextColor = Colors.white; // White text for visibility
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      child: (hasBeenChecked && isWinner) 
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "WINNER" centered at the top (translated)
              Center(
                child: Text(
                  Localizations.localeOf(context).languageCode == 'vi' ? 'TRÚNG GIẢI' : 'WINNER',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Prize tier display
              if (prizeCategory.isNotEmpty) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFD966).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getPrizeDisplayName(prizeCategory),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFD966),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Amount and pill on the same row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Amount on the left
                  if (winAmount > 0)
                    Expanded(
                      child: Text(
                        '${winAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} VND',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Pill on the right
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: pillBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count ${count > 1 ? AppLocalizations.of(context)!.tickets : AppLocalizations.of(context)!.ticket}',
                      style: TextStyle(
                        color: pillTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Image and ticket number row (conditionally show image based on storage setting)
              FutureBuilder<bool>(
                future: ImageStorageService.isImageStorageEnabled(),
                builder: (context, storageSnapshot) {
                  final isStorageEnabled = storageSnapshot.data ?? true;
                  
                  return Row(
                    children: [
                      // Ticket image (only show if storage is enabled)
                      if (isStorageEnabled) ...[
                        Container(
                          width: 90,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FutureBuilder<File?>(
                              future: ImageStorageService.getTicketImage(imagePath.isNotEmpty ? imagePath : null),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                    ),
                                  );
                                }
                                
                                if (snapshot.hasData && snapshot.data != null) {
                                  return Image.file(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildPlaceholderIcon();
                                    },
                                  );
                                } else {
                                  return _buildPlaceholderIcon();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      // Ticket number (highlighted for winners)
                      Expanded(
                        child: _buildHighlightedTicketNumber(ticketNumber, prizeCategory),
                      ),
                    ],
                  );
                },
              ),
            ],
          )
        : FutureBuilder<bool>(
            future: ImageStorageService.isImageStorageEnabled(),
            builder: (context, storageSnapshot) {
              final isStorageEnabled = storageSnapshot.data ?? true;
              
              return Row(
                children: [
                  // Ticket image (only show if storage is enabled)
                  if (isStorageEnabled) ...[
                    Container(
                      width: 90,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FutureBuilder<File?>(
                          future: ImageStorageService.getTicketImage(imagePath.isNotEmpty ? imagePath : null),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                ),
                              );
                            }
                            
                            if (snapshot.hasData && snapshot.data != null) {
                              return Image.file(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildPlaceholderIcon();
                                },
                              );
                            } else {
                              return _buildPlaceholderIcon();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  // Ticket info (horizontal layout)
                  Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Spacer(), // Pushes pill to the right
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: pillBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$count ${count > 1 ? AppLocalizations.of(context)!.tickets : AppLocalizations.of(context)!.ticket}',
                            style: TextStyle(
                              color: pillTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Always show ticket number for pending/not-winner (highlighted if applicable)
                    _buildHighlightedTicketNumber(ticketNumber, prizeCategory),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Function to get the number of digits to highlight based on prize category
  int _getHighlightDigits(String prizeCategory) {
    if (prizeCategory.isEmpty) return 0;
    
    // Map prize categories to number of digits they match (from the end)
    switch (prizeCategory.toUpperCase()) {
      case 'DB':
      case 'ĐB':
        return 6; // Full number match for Special Prize
      case 'G1':
      case 'G2':
      case 'G3':
      case 'G4':
        return 5; // Last 5 digits
      case 'G5':
      case 'G6':
        return 4; // Last 4 digits
      case 'G7':
        return 3; // Last 3 digits
      case 'G8':
        return 2; // Last 2 digits
      case 'PHU_DB':
        return 5; // Last 5 digits match (special bonus)
      case 'KK':
        return 6; // All digits but one different (Hamming distance 1)
      default:
        return 0;
    }
  }

  // Function to build highlighted ticket number
  Widget _buildHighlightedTicketNumber(String ticketNumber, String prizeCategory) {
    final highlightDigits = _getHighlightDigits(prizeCategory);
    
    if (highlightDigits == 0 || prizeCategory.isEmpty) {
      // No highlighting needed - use white text for all tickets
      return Text(
        '#$ticketNumber',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
    }
    
    // Split the ticket number for highlighting
    final totalLength = ticketNumber.length;
    final normalPart = totalLength > highlightDigits 
        ? ticketNumber.substring(0, totalLength - highlightDigits)
        : '';
    final highlightPart = totalLength > highlightDigits
        ? ticketNumber.substring(totalLength - highlightDigits)
        : ticketNumber;
    
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '#$normalPart',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(
            text: highlightPart,
            style: TextStyle(
              color: Color(0xFFFFD966), // Gold for matching digits
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            color: Colors.grey[500],
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            'No Image',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Get localized prize display name from prize category
  String _getPrizeDisplayName(String prizeCategory) {
    if (prizeCategory.isEmpty) return '';
    
    final isVietnamese = Localizations.localeOf(context).languageCode == 'vi';
    return isVietnamese 
        ? _getPrizeDisplayNameVietnamese(prizeCategory)
        : _getPrizeDisplayNameEnglish(prizeCategory);
  }

  String _getPrizeDisplayNameEnglish(String prizeCategory) {
    switch (prizeCategory.toUpperCase()) {
      case 'DB':
      case 'ĐB':
        return 'Special Prize';
      case 'G1':
        return 'First Prize';
      case 'G2':
        return 'Second Prize';
      case 'G3':
        return 'Third Prize';
      case 'G4':
        return 'Fourth Prize';
      case 'G5':
        return 'Fifth Prize';
      case 'G6':
        return 'Sixth Prize';
      case 'G7':
        return 'Seventh Prize';
      case 'G8':
        return 'Eighth Prize';
      case 'PHU_DB':
        return 'Special Bonus';
      case 'KK':
        return 'Consolation Prize';
      default:
        return prizeCategory;
    }
  }

  String _getPrizeDisplayNameVietnamese(String prizeCategory) {
    switch (prizeCategory.toUpperCase()) {
      case 'DB':
      case 'ĐB':
        return 'Giải Đặc Biệt';
      case 'G1':
        return 'Giải Nhất';
      case 'G2':
        return 'Giải Nhì';
      case 'G3':
        return 'Giải Ba';
      case 'G4':
        return 'Giải Tư';
      case 'G5':
        return 'Giải Năm';
      case 'G6':
        return 'Giải Sáu';
      case 'G7':
        return 'Giải Bảy';
      case 'G8':
        return 'Giải Tám';
      case 'PHU_DB':
        return 'Phụ Đặc Biệt';
      case 'KK':
        return 'Khuyến Khích';
      default:
        return prizeCategory;
    }
  }

  String _formatDateDisplay(String dateString) {
    try {
      // Parse the date string (assuming it's in YYYY-MM-DD format)
      final parts = dateString.split('-');
      if (parts.length == 3) {
        final day = parts[2].padLeft(2, '0');
        final month = parts[1].padLeft(2, '0');
        final year = parts[0];
        return '$day-$month-$year';
      }
    } catch (e) {
      print('Error formatting date: $dateString');
    }
    // Return original string if parsing fails
    return dateString;
  }
}
