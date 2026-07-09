import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/providers/language_provider.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguage = 'en';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    final provider = Provider.of<LanguageProvider>(context, listen: false);
    setState(() {
      _selectedLanguage = provider.locale.languageCode;
    });
  }

  Future<void> _changeLanguage(String languageCode, String languageName) async {
    setState(() => _isLoading = true);
    
    final provider = Provider.of<LanguageProvider>(context, listen: false);
    await provider.setLanguage(languageCode, context);
    
    setState(() => _isLoading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('language_changed_to'.tr(args: [languageName])),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 1),
        ),
      );
      
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('select_language'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildLanguageOption(
                    languageCode: 'en',
                    languageName: 'English',
                    flagIcon: '🇬🇧',
                    isSelected: _selectedLanguage == 'en',
                    onTap: () => _changeLanguage('en', 'English'),
                  ),
                  const SizedBox(height: 12),
                  _buildLanguageOption(
                    languageCode: 'si',
                    languageName: 'සිංහල',
                    flagIcon: '🇱🇰',
                    isSelected: _selectedLanguage == 'si',
                    onTap: () => _changeLanguage('si', 'සිංහල'),
                  ),
                  const SizedBox(height: 12),
                  _buildLanguageOption(
                    languageCode: 'ta',
                    languageName: 'தமிழ்',
                    flagIcon: '🇱🇰',
                    isSelected: _selectedLanguage == 'ta',
                    onTap: () => _changeLanguage('ta', 'தமிழ்'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLanguageOption({
    required String languageCode,
    required String languageName,
    required String flagIcon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lightBlue : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.greyLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flagIcon, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                languageName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primaryBlue),
          ],
        ),
      ),
    );
  }
}