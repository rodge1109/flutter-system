import re

with open('c:/website/flutter-project/lib/screens/booking_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

start_idx = content.find('  Widget _buildServiceSelection() {')
end_idx = content.find('  Widget _buildVenueInformationSection() {')

if start_idx != -1 and end_idx != -1:
    new_method = '''  Widget _buildSelectCourtsAndTimes() {
    final List<String> fullMonths = [
      'January', 'February', 'March', 'April', 'May', 'June', 
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    String displayDate = '';
    if (_selectedDate != null) {
      displayDate = ',  , ';
    }

    // Get unique categories from services
    final categories = ['All'];
    for (var s in _services) {
      if (s.category.isNotEmpty && !categories.contains(s.category)) {
        categories.add(s.category);
      }
    }

    final filteredServices = _selectedCategory == 'All' 
        ? _services 
        : _services.where((s) => s.category == _selectedCategory).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Selector Header
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(Duration(days: 90)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: AppColors.primaryGreen,
                      onPrimary: Colors.white,
                      onSurface: AppColors.richBlack,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                _selectedDate = picked;
                _selectedTimes.clear();
              });
              _fetchSlots();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Text(
                  displayDate,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),

        // Category Filter
        Row(
          children: [
            Text('Sport', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    IconData? catIcon;
                    if (cat.toLowerCase().contains('pickle')) catIcon = Icons.sports_tennis;
                    if (cat.toLowerCase().contains('basket')) catIcon = Icons.sports_basketball;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Row(
                          children: [
                            if (catIcon != null) ...[
                              Icon(catIcon, size: 14, color: isSelected ? Colors.white : Colors.grey.shade800),
                              SizedBox(width: 4),
                            ],
                            Text(
                              cat,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? Colors.white : Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedCategory = cat);
                          }
                        },
                        selectedColor: AppColors.primaryGreen,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),

        // Courts List
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: filteredServices.length,
          itemBuilder: (context, index) {
            final court = filteredServices[index];
            final isExpanded = _expandedCourtIds.contains(court.id);
            
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: ExpansionTile(
                initiallyExpanded: isExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    if (expanded) {
                      _expandedCourtIds.add(court.id);
                      // Auto-select this court if expanding
                      _selectedServiceIds.add(court.id);
                      _selectedService = court;
                      if (_selectedTimes.isEmpty) _fetchSlots();
                    } else {
                      _expandedCourtIds.remove(court.id);
                    }
                  });
                },
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court.name,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.richBlack),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          court.price,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.camera_alt_outlined, size: 14, color: Colors.grey.shade500),
                        SizedBox(width: 4),
                        Text(
                          '3 photos', // Mock for now as per plan
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _isLoadingSlots 
                      ? Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 2.0,
                          ),
                          itemCount: _getDisplayTimeSlots().length,
                          itemBuilder: (context, idx) {
                            final time = _getDisplayTimeSlots()[idx];
                            final slotKey = ': ';
                            final isSelected = _selectedTimes.contains(slotKey) || (_selectedServiceIds.length == 1 && _selectedTimes.contains(time));
                            final isBooked = _bookedSlots.contains(time);

                            bool isPast = false;
                            bool isOutsideHours = false;

                            int slotHour = 0;
                            if (time.contains(':')) {
                              final parts = time.split(RegExp(r'[:\s]'));
                              if (parts.length >= 3) {
                                slotHour = int.tryParse(parts[0]) ?? 0;
                                if (parts[2].toUpperCase() == 'PM' && slotHour < 12) slotHour += 12;
                                if (parts[2].toUpperCase() == 'AM' && slotHour == 12) slotHour = 0;
                              }
                            } else {
                              slotHour = _allTimeSlots.indexOf(time);
                            }

                            if (_selectedDate != null) {
                              final now = DateTime.now();
                              if (_selectedDate!.year == now.year &&
                                  _selectedDate!.month == now.month &&
                                  _selectedDate!.day == now.day) {
                                if (slotHour < now.hour) {
                                  isPast = true;
                                } else if (slotHour == now.hour && now.minute > 0) {
                                  isPast = true;
                                }
                              }
                            }

                            if (court.openTime != null && court.openTime!.contains(':')) {
                              int openHour = int.tryParse(court.openTime!.split(':')[0]) ?? 0;
                              if (slotHour < openHour) isOutsideHours = true;
                            }
                            if (court.closeTime != null && court.closeTime!.contains(':')) {
                              int closeHour = int.tryParse(court.closeTime!.split(':')[0]) ?? 24;
                              if (slotHour >= closeHour) isOutsideHours = true;
                            }

                            final bool isDisabled = isBooked || isPast || isOutsideHours;

                            String getEndStr(String t) {
                              final parts = t.split(RegExp(r'[:\s]'));
                              if (parts.length >= 3) {
                                int h = int.tryParse(parts[0]) ?? 0;
                                String ampm = parts[2].toUpperCase();
                                int endH = h + 1;
                                if (endH == 12) ampm = ampm == 'AM' ? 'PM' : 'AM';
                                if (endH > 12) endH -= 12;
                                return '';
                              }
                              return t;
                            }

                            final String startStr = time.replaceFirst(':00', '').replaceAll(' ', '').replaceFirst(RegExp(r'^0'), '');
                            final String displayTime = '-';

                            return InkWell(
                              onTap: isDisabled ? null : () {
                                setState(() {
                                  // Ensure court is selected
                                  _selectedServiceIds.add(court.id);
                                  _selectedService = court;

                                  if (isSelected) {
                                    _selectedTimes.remove(slotKey);
                                    _selectedTimes.remove(time);
                                  } else {
                                    _selectedTimes.add(slotKey);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isDisabled 
                                          ? Colors.grey.shade200 
                                          : (isSelected ? AppColors.accentLime : AppColors.softWhite),
                                      border: isSelected ? null : Border.all(
                                        width: 1,
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              time.toUpperCase().contains('AM') ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                                              size: 12,
                                              color: isSelected ? AppColors.softWhite : (isDisabled ? Colors.grey.shade400 : AppColors.deepTeal),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              displayTime,
                                              style: TextStyle(
                                                color: isSelected ? AppColors.softWhite : (isDisabled ? Colors.grey.shade400 : AppColors.richBlack),
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isOutsideHours ? 'CLOSED' : (isPast ? 'PASSED' : (isBooked ? 'Booked' : _getPriceForTime(time, service: court))),
                                          style: TextStyle(
                                            color: isSelected ? AppColors.softWhite.withOpacity(0.90) : (isDisabled ? Colors.grey.shade500 : AppColors.richBlack),
                                            fontWeight: FontWeight.bold,
                                            fontSize: (isBooked || isOutsideHours) ? 9 : 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: -5,
                                      right: -5,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: AppColors.softWhite,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppColors.accentLime, width: 1.5),
                                        ),
                                        child: Icon(Icons.check, size: 9, color: AppColors.accentLime),
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
          },
        ),

        // Lock in Time UI
        if (_selectedTimes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
              children: [
                if (_holdToken == null)
                  ElevatedButton.icon(
                    icon: Icon(Icons.lock_clock, color: Colors.white),
                    label: Text('Lock in this time (5:00)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _holdSelectedSlots,
                  ),
                if (_holdToken != null)
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer, color: Colors.orange.shade800),
                        SizedBox(width: 8),
                        Text(
                          'Time remaining to pay: :',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

'''
    content = content[:start_idx] + new_method + content[end_idx:]
    with open('c:/website/flutter-project/lib/screens/booking_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
