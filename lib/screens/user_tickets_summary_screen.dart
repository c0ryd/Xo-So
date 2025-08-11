import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';

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

      // Get AWS credentials
      final credentials = await _getAwsCredentials();
      if (credentials == null) {
        throw Exception('Failed to get AWS credentials');
      }

      // Create signed request
      final apiUrl = 'https://u9maewv4ch.execute-api.ap-southeast-1.amazonaws.com/dev/getUserTickets';
      final requestBody = jsonEncode({'userId': user.id});

      final awsSigV4Client = AwsSigV4Client(
        credentials.accessKeyId!,
        credentials.secretAccessKey!,
        apiUrl,
        sessionToken: credentials.sessionToken!,
        region: 'ap-southeast-1',
      );
      
      // Create signed request using the AWS SDK (designed for API Gateway)
      final signedRequest = SigV4Request(
        awsSigV4Client,
        method: 'POST',
        path: '/getUserTickets',
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      final response = await http.post(
        Uri.parse('${apiUrl}'),
        headers: Map<String, String>.from(signedRequest.headers ?? {}),
        body: signedRequest.body,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final tickets = (responseData['tickets'] as List).cast<Map<String, dynamic>>();
        
        // Filter tickets to last 30 days
        final now = DateTime.now();
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        
        final recentTickets = tickets.where((ticket) {
          final scannedAt = ticket['scannedAt'] as String?;
          if (scannedAt != null) {
            try {
              final scannedDate = DateTime.parse(scannedAt);
              return scannedDate.isAfter(thirtyDaysAgo);
            } catch (e) {
              print('Error parsing date: $scannedAt');
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

  // Use the same AWS credentials approach as the main app
  Future<CognitoCredentials?> _getAwsCredentials() async {
    try {
      // Use the same approach as main.dart - this is working
      final identityPoolId = 'ap-southeast-1:9728af83-62a8-410f-a585-53de188a5079';
      // Create a dummy user pool for unauthenticated access
      final userPool = CognitoUserPool(
        'ap-southeast-1_dummy12345', // Dummy user pool ID
        'dummy1234567890abcdef1234567890' // Dummy client ID
      );
      
      // Create Cognito credentials for unauthenticated access using Identity Pool
      final credentials = CognitoCredentials(identityPoolId, userPool);
      
      // Get AWS credentials for unauthenticated access (pass null for unauthenticated)
      await credentials.getAwsCredentials(null);
      
      print('✅ AWS credentials obtained successfully');
      return credentials;
    } catch (e) {
      print('❌ Error getting AWS credentials: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tickets'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUserTickets,
          ),
        ],
      ),
      body: _isLoading
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

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalTickets ticket${totalTickets != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[800],
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
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.green[700], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Total Winnings: ${totalWinnings.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} VND',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Province header
          Row(
            children: [
              Expanded(
                child: Text(
                  province,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tickets.length} ticket${tickets.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
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
          
          // Tickets list
          for (final ticket in tickets) _buildTicketCard(ticket),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final isWinner = (ticket['isWinner'] as bool?) ?? false;
    final hasBeenChecked = (ticket['hasBeenChecked'] as bool?) ?? false;
    final drawDate = ticket['drawDate'] as String? ?? '';
    final ticketNumber = ticket['ticketNumber'] as String? ?? '';
    final winAmount = (ticket['winAmount'] is num) ? (ticket['winAmount'] as num).toInt() : 0;
    final matchedTiers = ticket['matchedTiers'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: !hasBeenChecked 
          ? Colors.orange[50] 
          : isWinner 
            ? Colors.green[50] 
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: !hasBeenChecked 
            ? Colors.orange 
            : isWinner 
              ? Colors.green 
              : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWinner ? Icons.star : hasBeenChecked ? Icons.check_circle_outline : Icons.pending,
                color: isWinner ? Colors.green : hasBeenChecked ? Colors.blue : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ticket #$ticketNumber',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      !hasBeenChecked 
                        ? 'Pending Results' 
                        : isWinner 
                          ? 'WINNER! ${winAmount > 0 ? "${winAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} VND" : "Check prize amount"}' 
                          : 'Not a winner',
                      style: TextStyle(
                        color: !hasBeenChecked 
                          ? Colors.orange 
                          : isWinner 
                            ? Colors.green 
                            : Colors.grey[600],
                        fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (isWinner && winAmount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🎉 WIN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ] else if (!hasBeenChecked) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Draw Date: $drawDate',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          if (isWinner && matchedTiers.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Winning Tiers: ${matchedTiers.join(', ')}',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (!hasBeenChecked) ...[
            const SizedBox(height: 4),
            Text(
              'Status: Pending results',
              style: TextStyle(
                color: Colors.orange[700],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
