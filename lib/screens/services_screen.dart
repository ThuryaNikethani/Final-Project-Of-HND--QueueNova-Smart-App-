import 'package:flutter/material.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/screens/book_appointment_screen.dart';

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
      'category': 'Passport',
      'icon': Icons.airplane_ticket,
      'time': '30 min',
      'fee': 'Rs. 5,000',
      'description': 'Renew your existing passport',
      'requirements': 'Old passport, NIC, Photos',
      'popular': true,
    },
    {
      'name': 'New Passport Application',
      'category': 'Passport',
      'icon': Icons.airplane_ticket,
      'time': '45 min',
      'fee': 'Rs. 8,000',
      'description': 'Apply for a new passport',
      'requirements': 'NIC, Birth certificate, Photos',
      'popular': false,
    },
    {
      'name': 'National ID Card',
      'category': 'NIC',
      'icon': Icons.badge,
      'time': '20 min',
      'fee': 'Rs. 500',
      'description': 'Apply for new NIC',
      'requirements': 'Birth certificate, Application form',
      'popular': true,
    },
    {
      'name': 'NIC Replacement',
      'category': 'NIC',
      'icon': Icons.badge,
      'time': '15 min',
      'fee': 'Rs. 1,000',
      'description': 'Replace lost or damaged NIC',
      'requirements': 'Police report, Application form',
      'popular': false,
    },
    {
      'name': 'Driving License',
      'category': 'License',
      'icon': Icons.directions_car,
      'time': '60 min',
      'fee': 'Rs. 3,000',
      'description': 'Apply for driving license',
      'requirements': 'NIC, Medical report, Test',
      'popular': true,
    },
    {
      'name': 'License Renewal',
      'category': 'License',
      'icon': Icons.directions_car,
      'time': '25 min',
      'fee': 'Rs. 1,500',
      'description': 'Renew your driving license',
      'requirements': 'Old license, NIC',
      'popular': false,
    },
    {
      'name': 'Birth Certificate',
      'category': 'Certificate',
      'icon': Icons.celebration,
      'time': '10 min',
      'fee': 'Rs. 200',
      'description': 'Get birth certificate copy',
      'requirements': 'NIC, Hospital records',
      'popular': true,
    },
    {
      'name': 'Marriage Certificate',
      'category': 'Certificate',
      'icon': Icons.favorite,
      'time': '15 min',
      'fee': 'Rs. 300',
      'description': 'Get marriage certificate',
      'requirements': 'NIC, Wedding photos',
      'popular': false,
    },
    {
      'name': 'Death Certificate',
      'category': 'Certificate',
      'icon': Icons.sentiment_dissatisfied,
      'time': '10 min',
      'fee': 'Rs. 200',
      'description': 'Get death certificate',
      'requirements': 'Medical certificate, NIC of deceased',
      'popular': false,
    },
    {
      'name': 'Police Clearance',
      'category': 'Other',
      'icon': Icons.gavel,
      'time': '40 min',
      'fee': 'Rs. 1,000',
      'description': 'Police clearance certificate',
      'requirements': 'NIC, Fingerprints',
      'popular': true,
    },
    {
      'name': 'Visa Services',
      'category': 'Other',
      'icon': Icons.flight,
      'time': '50 min',
      'fee': 'Rs. 4,000',
      'description': 'Visa application services',
      'requirements': 'Passport, Photos, Application',
      'popular': false,
    },
    {
      'name': 'Land Registration',
      'category': 'Other',
      'icon': Icons.description,
      'time': '90 min',
      'fee': 'Rs. 5,000',
      'description': 'Register land documents',
      'requirements': 'Deed, Survey plan, NIC',
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
        title: const Text('All Services'),
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
                hintText: 'Search services...',
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
                  label: Text(category),
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
                  '${filteredList.length} services found',
                  style: TextStyle(fontSize: 12, color: AppColors.grey),
                ),
                if (selectedCategory != 'All')
                  TextButton(
                    onPressed: () => setState(() => selectedCategory = 'All'),
                    child: const Text('Clear Filter'),
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
                          'No services found',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different search term',
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
                                                    service['name'],
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
                                                    child: const Text(
                                                      'Popular',
                                                      style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              service['description'],
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
                                      _buildInfoChip(Icons.timer, service['time'], AppColors.info),
                                      const SizedBox(width: 10),
                                      _buildInfoChip(Icons.currency_rupee, service['fee'], AppColors.success),
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
                                        child: const Text('Book Now', style: TextStyle(fontSize: 13)),
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
                                          'Required: ${service['requirements']}',
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