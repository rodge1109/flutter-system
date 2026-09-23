import re

with open('c:/website/flutter-project/lib/screens/booking_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _bookedSlots with Map<String, List<String>> _courtBookedSlots = {};
content = content.replace('List<String> _bookedSlots = [];', 'List<String> _bookedSlots = [];\n  Map<String, List<String>> _courtBookedSlots = {};')

# Replace _fetchSlots logic
old_fetch = '''  Future<void> _fetchSlots() async {
    if (_selectedDate == null || _services.isEmpty) return;
    setState(() => _isLoadingSlots = true);
    
    final dateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
    
    List<String> allBooked = [];
    final activeServices = _services.where((s) => _selectedServiceIds.contains(s.id)).toList();
    final fetchTargetServices = activeServices.isNotEmpty ? activeServices : [_services.first];

    for (var service in fetchTargetServices) {
      final result = await _apiService.fetchAvailableSlots(dateStr, service.name);
      final List<String> booked = (result['bookedSlots'] ?? []).map<String>((s) => s.toString()).toList();
      final List<String> blocked = (result['blockedSlots'] ?? []).map<String>((s) => s.toString()).toList();
      allBooked.addAll(booked);
      allBooked.addAll(blocked);
    }
    
    setState(() {
      _bookedSlots = allBooked.toSet().toList();
      // Remove selected times if booked
      _selectedTimes.removeWhere((rawTime) {
        final cleanTime = rawTime.contains(': ') ? rawTime.split(': ')[1] : rawTime;
        return _bookedSlots.contains(cleanTime);
      });
      _isLoadingSlots = false;
    });
  }'''

new_fetch = '''  Future<void> _fetchSlots() async {
    if (_selectedDate == null || _services.isEmpty) return;
    setState(() => _isLoadingSlots = true);
    
    final dateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
    
    Map<String, List<String>> courtBookings = {};
    
    for (var service in _services) {
      final result = await _apiService.fetchAvailableSlots(dateStr, service.name);
      final List<String> booked = (result['bookedSlots'] ?? []).map<String>((s) => s.toString()).toList();
      final List<String> blocked = (result['blockedSlots'] ?? []).map<String>((s) => s.toString()).toList();
      courtBookings[service.name] = [...booked, ...blocked];
    }
    
    setState(() {
      _courtBookedSlots = courtBookings;
      
      // We still update a unified _bookedSlots for legacy compatibility if needed
      List<String> allBooked = [];
      for (var list in courtBookings.values) {
        allBooked.addAll(list);
      }
      _bookedSlots = allBooked.toSet().toList();
      
      // Remove selected times if booked for that specific court
      _selectedTimes.removeWhere((rawTime) {
        if (rawTime.contains(': ')) {
          final parts = rawTime.split(': ');
          final courtName = parts[0];
          final cleanTime = parts[1];
          return _courtBookedSlots[courtName]?.contains(cleanTime) ?? false;
        } else if (_selectedService != null) {
           return _courtBookedSlots[_selectedService!.name]?.contains(rawTime) ?? false;
        }
        return false;
      });
      _isLoadingSlots = false;
    });
  }'''

content = content.replace(old_fetch, new_fetch)

# Update the isBooked check in the grid builder
old_check = '''final isBooked = _bookedSlots.contains(time);'''
new_check = '''final isBooked = _courtBookedSlots[court.name]?.contains(time) ?? false;'''
content = content.replace(old_check, new_check)

with open('c:/website/flutter-project/lib/screens/booking_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
