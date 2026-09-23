import re

with open('c:/website/flutter-project/lib/screens/booking_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _handleStepContinue logic
old_handle = '''  void _handleStepContinue(bool skipChooseService) {
    if (!skipChooseService) {
      if (_currentStep == 0 && _selectedService == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select a service to continue')));
        return;
      }
      if (_currentStep == 1 && (_selectedDate == null || _selectedTimes.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select date and at least one time')));
        return;
      }
      if (_currentStep == 1 && _holdToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please click "Lock in this time" below the time slots before proceeding.')));
        return;
      }
      if (_currentStep == 2 && (_nameController.text.isEmpty || _phoneController.text.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill your details')));
        return;
      }
      if (_currentStep == 3 && _referenceNumberController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter your reference number to continue')));
        return;
      }

      if (_currentStep < 4) {
        setState(() => _currentStep += 1);
      } else {
        _submitBooking();
      }
    } else {
      if (_currentStep == 0 && (_selectedDate == null || _selectedTimes.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select date and at least one time')));
        return;
      }
      if (_currentStep == 0 && _holdToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please click "Lock in this time" below the time slots before proceeding.')));
        return;
      }
      if (_currentStep == 1 && (_nameController.text.isEmpty || _phoneController.text.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill your details')));
        return;
      }
      if (_currentStep == 2 && _referenceNumberController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter your reference number to continue')));
        return;
      }

      if (_currentStep < 3) {
        setState(() => _currentStep += 1);
      } else {
        _submitBooking();
      }
    }
  }'''

new_handle = '''  void _handleStepContinue(bool skipChooseService) {
    if (_currentStep == 0 && (_selectedDate == null || _selectedTimes.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select at least one time slot')));
      return;
    }
    if (_currentStep == 0 && _holdToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please click "Lock in this time" before proceeding.')));
      return;
    }
    if (_currentStep == 1 && (_nameController.text.isEmpty || _phoneController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill your details')));
      return;
    }
    if (_currentStep == 2 && _referenceNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter your reference number to continue')));
      return;
    }

    if (_currentStep < 3) {
      setState(() => _currentStep += 1);
    } else {
      _submitBooking();
    }
  }'''

if old_handle in content:
    content = content.replace(old_handle, new_handle)

with open('c:/website/flutter-project/lib/screens/booking_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
