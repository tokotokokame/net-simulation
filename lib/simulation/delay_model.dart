// lib/simulation/delay_model.dart
import 'dart:developer';
import '../models/packet.dart';
import '../models/link.dart';

/// Calculates total packet delivery delay based on link characteristics.
class DelayModel {
  const DelayModel._();

  /// Returns the total simulated delay for [packet] traversing [link]
  /// with [queueLength] packets ahead in the queue.
  ///
  /// - Transmission delay = packet_bits / bandwidth
  /// - Propagation delay  = link.latency (ms → s)
  /// - Queue delay        = queueLength × packet_bits / bandwidth
  static Duration calculate(Packet packet, Link link, int queueLength) {
    assert(link.bandwidth > 0, 'bandwidth must be > 0');
    final bits = packet.size * 8.0;
    final bw = link.bandwidth.toDouble();

    final txDelay = bits / bw; // seconds
    final propDelay = link.latency / 1000.0; // ms → s
    final qDelay = queueLength * bits / bw; // seconds

    final totalSec = txDelay + propDelay + qDelay;
    final totalUs = (totalSec * 1e6).round().clamp(0, 10000000); // max 10s

    log(
      'Delay: tx=${(txDelay * 1000).toStringAsFixed(3)}ms '
      'prop=${link.latency}ms '
      'q=${(qDelay * 1000).toStringAsFixed(3)}ms '
      'total=${(totalSec * 1000).toStringAsFixed(3)}ms',
      name: 'DelayModel',
    );

    return Duration(microseconds: totalUs);
  }
}
