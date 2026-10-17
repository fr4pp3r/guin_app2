import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:guin_app/utils/constants.dart';

/// Read-only OpenStreetMap view pinned to an incident report's GPS spot.
///
/// Deliberately l10n-free: callers pass [emptyText] (e.g. `l10n.tdetNoMapPin`)
/// for the no-pin placeholder so the widget stays reusable across locales.
///
/// [latitude] / [longitude] are both nullable — `null` means the report has no
/// pin (legacy rows, or the reporter skipped the map) and a soft placeholder
/// fills the same [height] instead of a map.
class IncidentLocationMap extends StatefulWidget {
  const IncidentLocationMap({
    super.key,
    this.latitude,
    this.longitude,
    this.height = 220,
    this.emptyText,
  });

  /// GPS latitude of the pin, or null when the report has no pinned location.
  final double? latitude;

  /// GPS longitude of the pin, or null when the report has no pinned location.
  final double? longitude;

  /// Total height the map (or the empty placeholder) occupies.
  final double height;

  /// Copy shown in the placeholder when the pin is missing.
  final String? emptyText;

  @override
  State<IncidentLocationMap> createState() => _IncidentLocationMapState();
}

class _IncidentLocationMapState extends State<IncidentLocationMap> {
  // The widget owns the controller — FlutterMap never disposes a controller it
  // did not create internally, so this State must.
  late final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.latitude;
    final lng = widget.longitude;

    // ── No pin: soft placeholder filling the same height ──
    if (lat == null || lng == null) {
      return Container(
        height: widget.height,
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
        ),
        child: widget.emptyText == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 32,
                    color: Colors.grey.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.emptyText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
      );
    }

    // ── Pin exists: interactive map centered on it ──
    final pin = LatLng(lat, lng);
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: pin,
            initialZoom: 16.5,
            minZoom: 3,
            maxZoom: 19,
            keepAlive: true,
            // Pan + zoom only. No scrollWheelZoom (it would steal the page
            // scroll on web), no rotation, no two-finger pan.
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
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact `icon + label + lat,lng` line shown under [IncidentLocationMap]
/// when a pin exists — kept in this file so both the tanod detail screen and
/// the admin map sheet render coordinates identically.
class IncidentCoordinatesRow extends StatelessWidget {
  const IncidentCoordinatesRow({
    super.key,
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  /// Label beside the icon (e.g. `l10n.tdetCoordinates`) — caller owns l10n.
  final String label;

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.gps_fixed, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
