import re

with open('c:/website/flutter-project/lib/screens/booking_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

start_idx = content.find('  Widget _buildPaymentSelection() {')
if start_idx == -1:
    print("Could not find _buildPaymentSelection")
    exit(1)

# Find the next method or the end of the file. The next method is usually `String _getPaymentDetail` or similar, but _buildPaymentSelection is the last widget method.
# Let's just find the end of the class. It ends with a single `}` after _buildPaymentSelection.
end_idx = content.find('\n}\n', start_idx)

if end_idx != -1:
    new_method = '''  Widget _buildPaymentSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Please scan the QR code below to pay. Your booking will only be confirmed once payment is verified.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
        SizedBox(height: 16),
        Center(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.softWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [BoxShadow(color: AppColors.richBlack.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/qr-code.jpg',
                    height: 200,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 24),
                InkWell(
                  onTap: () {
                    downloadImage('assets/qr-code.jpg');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Downloading QR Code...'), duration: Duration(seconds: 2))
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.primaryGreen),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download, color: AppColors.primaryGreen, size: 24),
                        SizedBox(height: 8),
                        Text('Download\nQR Code', textAlign: TextAlign.center, style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFDDF7E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 20),
                  SizedBox(width: 8),
                  Text('Payment Instructions', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 14)),
                ],
              ),
              SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: AppColors.primaryGreen, height: 1.5, fontSize: 13, fontFamily: 'Poppins'),
                  children: [
                    TextSpan(text: 'Court Fee: ${_getTotalAmount()}\n'),
                    TextSpan(text: 'Service Charge: PHP 15.00\n'),
                    TextSpan(text: 'Total Amount to Pay: '),
                    TextSpan(text: '${_getTotalDue()}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _referenceNumberController,
          decoration: InputDecoration(
            labelText: 'Reference Number',
            prefixIcon: Icon(Icons.numbers, color: Colors.grey.shade600),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }'''

    # Ensure no python interpolations messed up the flutter string interpolation
    new_method = new_method.replace('${_getTotalAmount()}', "'${_getTotalAmount()}'").replace("'${_getTotalAmount()}'", "${_getTotalAmount()}").replace('${_getTotalDue()}', "'${_getTotalDue()}'").replace("'${_getTotalDue()}'", "${_getTotalDue()}")

    content = content[:start_idx] + new_method + content[end_idx:]
    with open('c:/website/flutter-project/lib/screens/booking_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
else:
    print("Could not find end of method")
