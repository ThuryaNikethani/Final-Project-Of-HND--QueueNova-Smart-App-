import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/screens/book_appointment_screen.dart';

const Map<String, String> _kCategoryKeys = {
  'All': 'filter_all',
  'Passport': 'passport',
  'NIC': 'nic_category',
  'License': 'category_license',
  'Certificate': 'category_certificate',
  'Other': 'category_other',
};

class ServicesScreen extends StatefulWidget {
  final String initialFilter;
  
  const ServicesScreen({super.key, this.initialFilter = 'All'});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String searchQuery = '';
  String selectedCategory = 'All';

  final List<String> categories = ['All', 'Passport', 'NIC', 'License', 'Certificate', 'Other'];

  final List<Map<String, dynamic>> allServices = [
    {
      'name': 'Passport Renewal',
      'nameKey': 'svc_passport_renewal_name',
      'descKey': 'svc_passport_renewal_desc',
      'reqKey': 'svc_passport_renewal_req',
      'category': 'Passport',
      'icon': Icons.airplane_ticket,
      'time': 30,
      'fee': '5,000',
      'popular': true,
    },
    {
      'name': 'New Passport Application',
      'nameKey': 'svc_new_passport_name',
      'descKey': 'svc_new_passport_desc',
      'reqKey': 'svc_new_passport_req',
      'category': 'Passport',
      'icon': Icons.airplane_ticket,
      'time': 45,
      'fee': '8,000',
      'popular': false,
    },
    {
      'name': 'National ID Card',
      'nameKey': 'svc_national_id_name',
      'descKey': 'svc_national_id_desc',
      'reqKey': 'svc_national_id_req',
      'category': 'NIC',
      'icon': Icons.badge,
      'time': 20,
      'fee': '500',
      'popular': true,
    },
    {
      'name': 'NIC Replacement',
      'nameKey': 'svc_nic_replacement_name',
      'descKey': 'svc_nic_replacement_desc',
      'reqKey': 'svc_nic_replacement_req',
      'category': 'NIC',
      'icon': Icons.badge,
      'time': 15,
      'fee': '1,000',
      'popular': false,
    },
    {
      'name': 'Driving License',
      'nameKey': 'svc_driving_license_name',
      'descKey': 'svc_driving_license_desc',
      'reqKey': 'svc_driving_license_req',
      'category': 'License',
      'icon': Icons.directions_car,
      'time': 60,
      'fee': '3,000',
      'popular': true,
    },
    {
      'name': 'License Renewal',
      'nameKey': 'svc_license_renewal_name',
      'descKey': 'svc_license_renewal_desc',
      'reqKey': 'svc_license_renewal_req',
      'category': 'License',
      'icon': Icons.directions_car,
      'time': 25,
      'fee': '1,500',
      'popular': false,
    },
    {
      'name': 'Birth Certificate',
      'nameKey': 'svc_birth_certificate_name',
      'descKey': 'svc_birth_certificate_desc',
      'reqKey': 'svc_birth_certificate_req',
      'category': 'Certificate',
      'icon': Icons.celebration,
      'time': 10,
      'fee': '200',
      'popular': true,
    },
    {
      'name': 'Marriage Certificate',
      'nameKey': 'svc_marriage_certificate_name',
      'descKey': 'svc_marriage_certificate_desc',
      'reqKey': 'svc_marriage_certificate_req',
      'category': 'Certificate',
      'icon': Icons.favorite,
      'time': 15,
      'fee': '300',
      'popular': false,
    },
    {
      'name': 'Death Certificate',
      'nameKey': 'svc_death_certificate_name',
      'descKey': 'svc_death_certificate_desc',
      'reqKey': 'svc_death_certificate_req',
      'category': 'Certificate',
      'icon': Icons.sentiment_dissatisfied,
      'time': 10,
      'fee': '200',
      'popular': false,
    },
    {
      'name': 'Police Clearance',
      'nameKey': 'svc_police_clearance_name',
      'descKey': 'svc_police_clearance_desc',
      'reqKey': 'svc_police_clearance_req',
      'category': 'Other',
      'icon': Icons.gavel,
      'time': 40,
      'fee': '1,000',
      'popular': true,
    },
    {
      'name': 'Visa Services',
      'nameKey': 'svc_visa_services_name',
      'descKey': 'svc_visa_services_desc',
      'reqKey': 'svc_visa_services_req',
      'category': 'Other',
      'icon': Icons.flight,
      'time': 50,
      'fee': '4,000',
      'popular': false,
    },
    {
      'name': 'Land Registration',
      'nameKey': 'svc_land_registration_name',
      'descKey': 'svc_land_registration_desc',
      'reqKey': 'svc_land_registration_req',
      'category': 'Other',
      'icon': Icons.description,
      'time': 90,
      'fee': '5,000',
      'popular': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != 'All') {
      selectedCategory = widget.initialFilter;
    }
  }

  List<Map<String, dynamic>> get filteredServices {
    return allServices.where((service) {
      final matchesCategory = selectedCategory == 'All' || service['category'] == selectedCategory;
      final matchesSearch = searchQuery.isEmpty || service['name'].toLowerCase().contains(searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = filteredServices;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('all_services'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'search_services_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.offWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Categories Filter
          Container(
            height: 45,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = selectedCategory == category;
                return FilterChip(
                  label: Text(_kCategoryKeys[category]!.tr()),
                  selected: isSelected,
                  onSelected: (_) => setState(() => selectedCategory = category),
                  selectedColor: AppColors.primaryBlue,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  backgroundColor: AppColors.offWhite,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Results Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'services_found_count'.tr(args: ['${filteredList.length}']),
                  style: TextStyle(fontSize: 12, color: AppColors.grey),
                ),
                if (selectedCategory != 'All')
                  TextButton(
                    onPressed: () => setState(() => selectedCategory = 'All'),
                    child: Text('clear_filter'.tr()),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Services List
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 80, color: AppColors.grey.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'no_services_found'.tr(),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'try_different_search'.tr(),
                          style: TextStyle(fontSize: 14, color: AppColors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final service = filteredList[index];
                      final isPopular = service['popular'] == true;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.lightBlue,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Icon(service['icon'], color: AppColors.primaryBlue, size: 26),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    (service['nameKey'] as String).tr(),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Color(0xFF1F2937),
                                                    ),
                                                  ),
                                                ),
                                                if (isPopular)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.warning.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      'popular_badge'.tr(),
                                                      style: const TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              (service['descKey'] as String).tr(),
                                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      _buildInfoChip(Icons.timer, 'minutes_suffix'.tr(args: ['${service['time']}']), AppColors.info),
                                      const SizedBox(width: 10),
                                      _buildInfoChip(Icons.currency_rupee, 'rupee_amount'.tr(args: [service['fee']]), AppColors.success),
                                      const Spacer(),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => const BookAppointmentScreen()),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryBlue,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                        ),
                                        child: Text('book_now'.tr(), style: const TextStyle(fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.offWhite,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.description_outlined, size: 14, color: AppColors.grey),
                                        const SizedBox(width: 6),
                                        Text(
                                          'required_label'.tr(args: [(service['reqKey'] as String).tr()]),
                                          style: TextStyle(fontSize: 11, color: AppColors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}