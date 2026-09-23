import re

with open('c:/website/flutter-project/lib/screens/booking_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# We want to insert the Open Play / Challenge UI right before "// Lock in Time UI"
target = '        // Lock in Time UI'

new_ui = '''        // Host Open Play / Challenge UI
        if (_selectedTimes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Open Play Toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: CheckboxListTile(
                    title: Text('Host an Open Play', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.richBlack)),
                    subtitle: Text('Allow others to join your court slot', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    value: _isOpenPlay,
                    activeColor: AppColors.primaryGreen,
                    onChanged: (val) {
                      setState(() {
                        _isOpenPlay = val ?? false;
                        if (_isOpenPlay) _isOpenChallenge = false;
                      });
                    },
                  ),
                ),
                if (_isOpenPlay)
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _openPlayType,
                          decoration: InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                          items: ['SINGLES', 'DOUBLES', 'MIXED'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (val) => setState(() => _openPlayType = val!),
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _openPlayMaxPlayersController,
                          decoration: InputDecoration(labelText: 'Max Players', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _openPlayPriceController,
                          decoration: InputDecoration(labelText: 'Price per player (?)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _openPlayInstructionsController,
                          decoration: InputDecoration(labelText: 'Instructions / Level', border: OutlineInputBorder()),
                          maxLines: 2,
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _openPlayPaymentDetailsController,
                          decoration: InputDecoration(labelText: 'Your GCash / Payment Info', border: OutlineInputBorder()),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 12),

                // Challenge Toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: CheckboxListTile(
                    title: Text('Post as a Challenge', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.richBlack)),
                    subtitle: Text('Challenge other players or tandems', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    value: _isOpenChallenge,
                    activeColor: AppColors.primaryGreen,
                    onChanged: (val) {
                      setState(() {
                        _isOpenChallenge = val ?? false;
                        if (_isOpenChallenge) _isOpenPlay = false;
                      });
                    },
                  ),
                ),
                if (_isOpenChallenge)
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _challengeType,
                          decoration: InputDecoration(labelText: 'Challenge Type', border: OutlineInputBorder()),
                          items: ['singles', 'doubles', 'mixed'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                          onChanged: (val) => setState(() => _challengeType = val!),
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _hostTandemNameController,
                          decoration: InputDecoration(labelText: 'Your Team / Player Name', border: OutlineInputBorder()),
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _challengeDescriptionController,
                          decoration: InputDecoration(labelText: 'Description / Stakes', border: OutlineInputBorder()),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

        // Lock in Time UI
'''

content = content.replace(target, new_ui)

with open('c:/website/flutter-project/lib/screens/booking_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
