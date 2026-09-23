import re

with open('c:/website/flutter-project/lib/screens/booking_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the steps construction
old_steps = '''    if (!skipChooseService) {
      steps.add(
        Step(
          title: Text('Choose Service', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
          subtitle: _currentStep == 0 
              ? Text('Select the court you want to book')
              : Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: _buildServiceSelection(),
                ),
          content: _currentStep == 0 ? _buildServiceSelection() : SizedBox.shrink(),
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        ),
      );
    }

    steps.addAll([
      Step(
        title: Text('Date & Time', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
        content: _buildDateTimeSelection(),
        isActive: _currentStep >= (skipChooseService ? 0 : 1),
        state: _currentStep > (skipChooseService ? 0 : 1) ? StepState.complete : StepState.indexed,
      ),'''

new_steps = '''    if (!skipChooseService) {
      steps.add(
        Step(
          title: Text('Courts & Times', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
          content: _buildSelectCourtsAndTimes(),
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        ),
      );
    } else {
      steps.add(
        Step(
          title: Text('Date & Time', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
          content: _buildSelectCourtsAndTimes(),
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        ),
      );
    }

    steps.addAll(['''

content = content.replace(old_steps, new_steps)

# Replace Step labels
old_labels = '''    // Step labels
    final List<String> stepLabels = skipChooseService
        ? ['Date & Time', 'Your Details', 'Payment', 'Confirm']
        : ['Court', 'Date & Time', 'Your Details', 'Payment', 'Confirm'];'''

new_labels = '''    // Step labels
    final List<String> stepLabels = skipChooseService
        ? ['Date & Time', 'Your Details', 'Payment', 'Confirm']
        : ['Courts & Times', 'Your Details', 'Payment', 'Confirm'];'''
content = content.replace(old_labels, new_labels)

# We also need to fix _handleStepContinue logic.
old_continue = '''  void _handleStepContinue(bool skipChooseService) {
    if (!skipChooseService) {
      if (_currentStep == 0 && _selectedService == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select a service to continue')));
        return;
      }
      if (_currentStep == 1 && (_selectedDate == null || _selectedTimes.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select date and at least one time')));
        return;
      }
      if (_currentStep == 1 && _holdToken == null) {'''

new_continue = '''  void _handleStepContinue(bool skipChooseService) {
    if (!skipChooseService) {
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
    } else {
      if (_currentStep == 0 && (_selectedDate == null || _selectedTimes.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select date and at least one time')));
        return;
      }
      if (_currentStep == 0 && _holdToken == null) {'''

# Actually, the entire _handleStepContinue needs rewriting because steps max is now 3 not 4 for skipChooseService=false!
# Wait, maxStep was: inal int maxStep = skipChooseService ? 3 : 4;
# Now it should be 3 in both cases!
old_maxstep = '''final int maxStep = skipChooseService ? 3 : 4;'''
new_maxstep = '''final int maxStep = 3;'''
content = content.replace(old_maxstep, new_maxstep)

with open('c:/website/flutter-project/lib/screens/booking_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
