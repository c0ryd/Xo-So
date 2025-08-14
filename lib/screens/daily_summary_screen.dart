import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../widgets/vietnamese_tiled_background.dart';

class DailySummaryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> winningTickets;
  final List<Map<String, dynamic>> losingTickets;
  final String date;

  const DailySummaryScreen({
    Key? key,
    required this.winningTickets,
    required this.losingTickets,
    required this.date,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalTickets = winningTickets.length + losingTickets.length;
    final totalWinnings = winningTickets.fold<int>(
      0, 
      (sum, ticket) => sum + (ticket['winAmount'] as int? ?? 0)
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Summary - $date'),
      ),
      body: VietnameseTiledBackground(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: winningTickets.isNotEmpty ? Colors.green[50] : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: winningTickets.isNotEmpty ? Colors.green : Colors.grey,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    winningTickets.isNotEmpty ? Icons.celebration : Icons.sentiment_neutral,
                    size: 48,
                    color: winningTickets.isNotEmpty ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    winningTickets.isNotEmpty 
                      ? '🎉 Congratulations! You Won!' 
                      : 'No Winning Tickets Today',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: winningTickets.isNotEmpty ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Checked $totalTickets ticket${totalTickets != 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (totalWinnings > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Total Winnings: ${totalWinnings.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} VND',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Tickets list
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (winningTickets.isNotEmpty) ...[
                    Text(
                      '🏆 Winning Tickets (${winningTickets.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...winningTickets.map((ticket) => _buildTicketCard(ticket, true)),
                    const SizedBox(height: 16),
                  ],
                  
                  if (losingTickets.isNotEmpty) ...[
                    Text(
                      '📄 Other Tickets (${losingTickets.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700]!,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: losingTickets.length,
                        itemBuilder: (context, index) => _buildTicketCard(losingTickets[index], false),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket, bool isWinner) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFFFE8BE), // Original cream for ticket cards
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWinner ? Colors.green : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isWinner ? Icons.star : Icons.receipt,
            color: isWinner ? Colors.green : Colors.grey[600]!,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ticket #${ticket['ticketNumber']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                                  Text(
                    '${ticket['province']} • $date',
                    style: TextStyle(
                      color: Colors.grey[600]!,
                      fontSize: 14,
                    ),
                  ),
                if (isWinner && ticket['matchedTiers'] != null) ...[
                  Text(
                    'Tiers: ${(ticket['matchedTiers'] as List).join(', ')}',
                    style: TextStyle(
                      color: Colors.green[700]!,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isWinner && ticket['winAmount'] != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(ticket['winAmount'] as int).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} VND',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
