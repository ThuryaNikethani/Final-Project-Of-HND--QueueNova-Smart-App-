import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:queuenova_mobile/config/app_colors.dart';
import 'package:queuenova_mobile/services/payment_service.dart';
import 'package:queuenova_mobile/screens/payment_success_screen.dart';

const Map<String, String> _kPaymentMethodKeys = {
  'Credit Card': 'pm_credit_card',
  'Debit Card': 'pm_debit_card',
  'Mobile Banking': 'pm_mobile_banking',
  'Online Banking': 'pm_online_banking',
};

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String appointmentId;
  final String serviceName;
  final String officeName;

  const PaymentScreen({
    super.key,
    required this.amount,
    required this.appointmentId,
    required this.serviceName,
    required this.officeName,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String selectedPaymentMethod = 'Credit Card';
  bool isProcessing = false;
  bool isCardSaved = false;
  
  // Card details
  final TextEditingController cardNumberController = TextEditingController();
  final TextEditingController expiryController = TextEditingController();
  final TextEditingController cvvController = TextEditingController();
  final TextEditingController cardHolderController = TextEditingController();
  
  final List<String> paymentMethods = [
    'Credit Card',
    'Debit Card',
    'Mobile Banking',
    'Online Banking',
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _processPayment() async {
    // Validate card details for card payments
    if (selectedPaymentMethod == 'Credit Card' || selectedPaymentMethod == 'Debit Card') {
      if (cardNumberController.text.replaceAll(' ', '').length < 16) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('invalid_card_number'.tr()), backgroundColor: AppColors.error),
        );
        return;
      }
      if (expiryController.text.length < 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('invalid_expiry_date'.tr()), backgroundColor: AppColors.error),
        );
        return;
      }
      if (cvvController.text.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('invalid_cvv'.tr()), backgroundColor: AppColors.error),
        );
        return;
      }
    }
    
    setState(() => isProcessing = true);

    try {
      // For card payments, use Stripe
      if (selectedPaymentMethod == 'Credit Card' || selectedPaymentMethod == 'Debit Card') {
        await _processStripePayment();
      } else {
        // For other payment methods, use the existing PaymentService
        final result = await PaymentService.processPayment(
          amount: widget.amount,
          appointmentId: widget.appointmentId,
          paymentMethod: selectedPaymentMethod,
        );
        
        setState(() => isProcessing = false);
        
        if (result['success']) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentSuccessScreen(
                transactionId: result['transactionId'],
                amount: widget.amount,
                appointmentId: widget.appointmentId,
                serviceName: widget.serviceName,
                officeName: widget.officeName,
              ),
            ),
          );
        } else {
          _showPaymentFailedDialog(result['message']);
        }
      }
    } catch (e) {
      setState(() => isProcessing = false);
      _showPaymentFailedDialog('payment_failed_error'.tr(args: ['$e']));
    }
  }

  Future<void> _processStripePayment() async {
    try {
      // Step 1: Try to create payment intent on backend
      final paymentIntentData = await PaymentService.createPaymentIntent(
        amount: widget.amount,
        appointmentId: widget.appointmentId,
        currency: 'lkr',
      );

      // No backend available – use simulation so the demo is functional
      if (paymentIntentData['clientSecret'] == null) {
        await Future.delayed(const Duration(seconds: 2));
        setState(() => isProcessing = false);

        if (isCardSaved && cardNumberController.text.replaceAll(' ', '').length >= 4) {
          await PaymentService.saveCard(
            appointmentId: widget.appointmentId,
            last4: cardNumberController.text.replaceAll(' ', '').substring(
              cardNumberController.text.replaceAll(' ', '').length - 4,
            ),
          );
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentSuccessScreen(
                transactionId: paymentIntentData['transactionId'] ?? 'TXN-${DateTime.now().millisecondsSinceEpoch}',
                amount: widget.amount,
                appointmentId: widget.appointmentId,
                serviceName: widget.serviceName,
                officeName: widget.officeName,
              ),
            ),
          );
        }
        return;
      }

      // Step 2: Backend available – use Stripe payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['clientSecret'],
          merchantDisplayName: 'QueueNova',
          style: ThemeMode.light,
          customerId: paymentIntentData['customer'],
          customerEphemeralKeySecret: paymentIntentData['ephemeralKey'],
        ),
      );

      // Step 3: Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Step 4: Payment successful
      setState(() => isProcessing = false);

      if (isCardSaved) {
        await PaymentService.saveCard(
          appointmentId: widget.appointmentId,
          last4: cardNumberController.text.replaceAll(' ', '').substring(
            cardNumberController.text.replaceAll(' ', '').length - 4,
          ),
        );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              transactionId: paymentIntentData['transactionId'] ?? 'TXN-${DateTime.now().millisecondsSinceEpoch}',
              amount: widget.amount,
              appointmentId: widget.appointmentId,
              serviceName: widget.serviceName,
              officeName: widget.officeName,
            ),
          ),
        );
      }

    } on StripeException catch (e) {
      setState(() => isProcessing = false);

      if (!mounted) return;
      if (e.error.code == FailureCode.Canceled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('payment_cancelled'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        _showPaymentFailedDialog(e.error.message ?? 'payment_failed_default'.tr());
      }
    } catch (e) {
      setState(() => isProcessing = false);
      if (!mounted) return;
      _showPaymentFailedDialog('unexpected_error'.tr(args: ['$e']));
    }
  }

  void _showPaymentFailedDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error, color: AppColors.error),
            const SizedBox(width: 10),
            Text('payment_failed_title'.tr()),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('try_again'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('pay_at_counter'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('secure_payment_title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    'total_amount_to_pay'.tr(),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'rupee_amount'.tr(args: [widget.amount.toStringAsFixed(0)]),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.serviceName,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Payment Method Selection
            Text('select_payment_method'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(15),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedPaymentMethod,
                  isExpanded: true,
                  items: paymentMethods.map((method) {
                    return DropdownMenuItem(value: method, child: Text(_kPaymentMethodKeys[method]!.tr()));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedPaymentMethod = value!),
                ),
              ),
            ),
            
            // Card Details (for Card payments)
            if (selectedPaymentMethod == 'Credit Card' || selectedPaymentMethod == 'Debit Card') ...[
              const SizedBox(height: 20),
              Text('card_details'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: cardHolderController,
                decoration: InputDecoration(
                  labelText: 'cardholder_name_label'.tr(),
                  hintText: 'cardholder_name_hint'.tr(),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cardNumberController,
                keyboardType: TextInputType.number,
                maxLength: 19,
                decoration: InputDecoration(
                  labelText: 'card_number_label'.tr(),
                  hintText: '1234 5678 9012 3456',
                  prefixIcon: Icon(Icons.credit_card),
                  counterText: '',
                ),
                onChanged: (value) {
                  // Auto-format card number
                  String formatted = value.replaceAll(' ', '');
                  String newText = '';
                  for (int i = 0; i < formatted.length; i++) {
                    if (i > 0 && i % 4 == 0) {
                      newText += ' ';
                    }
                    newText += formatted[i];
                  }
                  if (newText != value) {
                    cardNumberController.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(offset: newText.length),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: expiryController,
                      keyboardType: TextInputType.datetime,
                      maxLength: 5,
                      decoration: InputDecoration(
                        labelText: 'expiry_date_label'.tr(),
                        hintText: 'MM/YY',
                        counterText: '',
                      ),
                      onChanged: (value) {
                        // Auto-format expiry
                        String formatted = value.replaceAll('/', '');
                        if (formatted.length >= 2 && value.length == 2) {
                          expiryController.value = TextEditingValue(
                            text: '$value/',
                            selection: TextSelection.collapsed(offset: 3),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: cvvController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'cvv_label'.tr(),
                        hintText: '123',
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Save Card Option
              Row(
                children: [
                  Checkbox(
                    value: isCardSaved,
                    onChanged: (value) {
                      setState(() => isCardSaved = value!);
                    },
                    activeColor: AppColors.primaryBlue,
                  ),
                  Text(
                    'save_card_future_payments'.tr(),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ],
            
            // Mobile Banking / Online Banking (Demo)
            if (selectedPaymentMethod == 'Mobile Banking') ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'pm_mobile_banking'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'redirect_mobile_banking_note'.tr(),
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        // Process mobile banking payment
                        setState(() => isProcessing = true);
                        final result = await PaymentService.processPayment(
                          amount: widget.amount,
                          appointmentId: widget.appointmentId,
                          paymentMethod: 'Mobile Banking',
                        );
                        setState(() => isProcessing = false);
                        if (!mounted) return;

                        if (result['success'] == true) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PaymentSuccessScreen(
                                transactionId: result['transactionId'],
                                amount: widget.amount,
                                appointmentId: widget.appointmentId,
                                serviceName: widget.serviceName,
                                officeName: widget.officeName,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: Text('proceed_to_mobile_banking'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (selectedPaymentMethod == 'Online Banking') ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'pm_online_banking'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'select_bank_note'.tr(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'select_bank_label'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Commercial Bank', child: Text('Commercial Bank')),
                        DropdownMenuItem(value: 'HNB', child: Text('HNB')),
                        DropdownMenuItem(value: 'Sampath Bank', child: Text('Sampath Bank')),
                        DropdownMenuItem(value: 'NDB', child: Text('NDB')),
                        DropdownMenuItem(value: 'People\'s Bank', child: Text('People\'s Bank')),
                      ],
                      onChanged: (value) {},
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        setState(() => isProcessing = true);
                        final result = await PaymentService.processPayment(
                          amount: widget.amount,
                          appointmentId: widget.appointmentId,
                          paymentMethod: 'Online Banking',
                        );
                        setState(() => isProcessing = false);
                        if (!context.mounted) return;

                        if (result['success'] == true) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PaymentSuccessScreen(
                                transactionId: result['transactionId'],
                                amount: widget.amount,
                                appointmentId: widget.appointmentId,
                                serviceName: widget.serviceName,
                                officeName: widget.officeName,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: Text('proceed_to_online_banking'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 30),
            
            // Pay Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: isProcessing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('processing_label'.tr(), style: const TextStyle(color: Colors.white)),
                        ],
                      )
                    : Text('pay_now_button'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Secure Payment Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, size: 16, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'secure_payment_note'.tr(),
                      style: TextStyle(fontSize: 11, color: AppColors.primaryBlue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}