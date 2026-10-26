import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Interactive map for dropping an optional pin at the incident location.
///
/// The pin is purely informational — the parent form stays valid without it.
/// Tap the map to drop a pin; the parent is notified through [onPinChanged]
/// on every drop, move, or clear.
class LocationPinPicker extends StatefulWidget {
  const LocationPinPicker({
    super.key,
    required this.onPinChanged,
    this.initial,
  });

  /// Called with the new pin whenever it is dropped, moved, or cleared.
  final void Function(LatLng? latLng)? onPinChanged;

  /// Optional pre-selected pin (e.g. a restored draft).
  final LatLng? initial;

  @override
  State<LocationPinPicker> createState() => LocationPinPickerState();
}

class LocationPinPickerState extends State<LocationPinPicker> {
  final _controller = MapController();
  LatLng? _pin;

  @override
  void initState() {
    super.initState();
    _pin = widget.initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Drops (or moves) the pin at [point] and centers the map on it.
  /// Used by the parent's "use my current location" flow.
  void setPin(LatLng point) {
    if (!mounted) return;
    setState(() => _pin = point);
    _controller.move(point, 17);
    widget.onPinChanged?.call(point);
  }

  /// Removes the current pin, if any.
  void clearPin() {
    if (!mounted || _pin == null) return;
    setState(() => _pin = null);
    widget.onPinChanged?.call(null);
  }

  void _dropPin(TapPosition _, LatLng point) {
    setState(() => _pin = point);
    widget.onPinChanged?.call(point);
  }

  @override
  Widget build(BuildContext context) {
    final pin = _pin;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.initial ?? const LatLng(10.3167, 123.8854),
        initialZoom: 15.5,
        minZoom: 3,
        maxZoom: 19,
        keepAlive: true,
        onTap: _dropPin,
        // No scrollWheelZoom (would trap the page scroll on web), no
        // rotate/pinchMove (accidental gestures while dropping a pin).
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.drag |
              InteractiveFlag.flingAnimation |
              InteractiveFlag.pinchZoom |
              InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'citeease.barangay.edoc',
          maxNativeZoom: 19,
        ),
        MarkerLayer(
          markers: [
            if (pin != null)
              Marker(
                point: pin,
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: const Icon(
                  Icons.location_pin,
                  size: 44,
                  color: Color(0xFFD32F2F),
                ),
              ),
          ],
        ),
        // No onTap: the attribution stays plain text so the map never leaves
        // the app when the reporter taps the credits.
        RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}
