import re
import subprocess

out = subprocess.check_output(['git', 'show', 'HEAD^^:lib/screens/booking_screen.dart']).decode('utf-8')
start = out.find('  Widget _buildDateTimeSelection() {')
end = out.find('  Widget _buildVenueInformationSection() {')
if start != -1 and end != -1:
    with open('c:/website/flutter-project/scratch_old_ui.dart', 'w', encoding='utf-8') as f:
        f.write(out[start:end])
