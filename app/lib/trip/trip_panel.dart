import 'package:flutter/material.dart';

import 'trip_controller.dart';

class TripPanel extends StatefulWidget {
  const TripPanel({
    super.key,
    required this.activeTrip,
    required this.status,
    required this.onStart,
    required this.onEnd,
  });

  final ActiveTrip? activeTrip;
  final String status;
  final Future<void> Function(TripConfiguration) onStart;
  final Future<void> Function() onEnd;

  @override
  State<TripPanel> createState() => _TripPanelState();
}

class _TripPanelState extends State<TripPanel> {
  final _ambulanceId = TextEditingController(text: 'SIM-AMB-001');
  HospitalDestination? _destination;

  @override
  void dispose() {
    _ambulanceId.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    await widget.onStart(
      TripConfiguration(
        ambulanceId: _ambulanceId.text,
        destination: _destination,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.activeTrip;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xff121e2e),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xff344c6d)),
      ),
      child: trip == null ? _configurationForm(context) : _activeTrip(trip),
    );
  }

  Widget _configurationForm(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.route_rounded, color: Color(0xff8abaff)),
          SizedBox(width: 10),
          Text(
            'Trip setup',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        widget.status,
        style: const TextStyle(
          color: Color(0xff9caec5),
          fontSize: 12,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 18),
      _field(
        label: 'Ambulance ID',
        child: TextField(
          controller: _ambulanceId,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'e.g. AMB-001'),
        ),
      ),
      const SizedBox(height: 12),
      _field(
        label: 'Assigned hospital',
        child: DropdownButtonFormField<HospitalDestination>(
          initialValue: _destination,
          isExpanded: true,
          hint: const Text('Select assigned hospital'),
          decoration: const InputDecoration(),
          items: [
            for (final destination in demoHospitalDestinations)
              DropdownMenuItem(
                value: destination,
                child: Text(destination.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (destination) {
            setState(() => _destination = destination);
          },
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'The hospital entrance is configured automatically for routing.',
        style: TextStyle(color: Color(0xff9caec5), fontSize: 12, height: 1.5),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: _start,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start trip'),
      ),
    ],
  );

  Widget _field({required String label, required Widget child}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Color(0xff9caec5))),
      const SizedBox(height: 4),
      child,
    ],
  );

  Widget _activeTrip(ActiveTrip trip) {
    final destination = trip.configuration;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.navigation_rounded, color: Color(0xff8cd9b7)),
            SizedBox(width: 10),
            Text(
              'Trip active',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.status,
          style: const TextStyle(
            color: Color(0xff9caec5),
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          destination.hospitalName.trim(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '${destination.ambulanceId.trim()} · Ambulance entrance configured',
          style: const TextStyle(color: Color(0xff9caec5), fontSize: 12),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => widget.onEnd(),
          icon: const Icon(Icons.stop_rounded),
          label: const Text('End trip'),
        ),
      ],
    );
  }
}
