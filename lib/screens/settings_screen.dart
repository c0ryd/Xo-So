import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.language,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Consumer<LanguageService>(
                    builder: (context, languageService, child) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                AppLocalizations.of(context)!.english,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: languageService.isEnglish 
                                      ? Colors.blue 
                                      : Colors.grey,
                                ),
                              ),
                              Expanded(
                                child: Switch(
                                  value: languageService.isVietnamese,
                                  onChanged: (value) {
                                    languageService.toggleLanguage();
                                  },
                                  activeColor: Colors.blue,
                                ),
                              ),
                              Text(
                                AppLocalizations.of(context)!.vietnamese,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: languageService.isVietnamese 
                                      ? Colors.blue 
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            languageService.isEnglish 
                                ? 'Switch to Vietnamese' 
                                : 'Chuyển sang Tiếng Anh',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('App Version'),
              subtitle: Text('1.0.0'),
            ),
          ),
        ],
      ),
    );
  }
}
