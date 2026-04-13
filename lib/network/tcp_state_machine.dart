// lib/network/tcp_state_machine.dart
import 'dart:developer';
import '../models/packet.dart';

enum TcpState {
  closed,
  synSent,
  synReceived,
  established,
  finWait1,
  finWait2,
  closeWait,
  lastAck,
  timeWait,
}

class TcpStateMachine {
  TcpState currentState;

  TcpStateMachine({this.currentState = TcpState.closed});

  /// Processes [packet] and transitions state based on TCP flags.
  /// Returns the new [TcpState].
  TcpState processPacket(Packet packet) {
    if (packet.protocol != ProtocolType.tcp) return currentState;

    final flags = packet.tcpFlags ?? const TcpFlags();

    // RST resets to closed from any state.
    if (flags.rst) {
      _transition(TcpState.closed, reason: 'RST');
      return currentState;
    }

    switch (currentState) {
      case TcpState.closed:
        if (flags.syn && !flags.ack) _transition(TcpState.synSent);

      case TcpState.synSent:
        if (flags.syn && flags.ack) {
          _transition(TcpState.established, reason: 'SYN-ACK');
        } else if (flags.syn) {
          _transition(TcpState.synReceived, reason: 'simultaneous open');
        }

      case TcpState.synReceived:
        if (flags.ack && !flags.syn) _transition(TcpState.established);

      case TcpState.established:
        if (flags.fin) _transition(TcpState.finWait1);

      case TcpState.finWait1:
        if (flags.fin && flags.ack) {
          _transition(TcpState.timeWait, reason: 'FIN+ACK');
        } else if (flags.ack) {
          _transition(TcpState.finWait2);
        } else if (flags.fin) {
          _transition(TcpState.closeWait, reason: 'simultaneous close');
        }

      case TcpState.finWait2:
        if (flags.fin) _transition(TcpState.timeWait);

      case TcpState.closeWait:
        if (flags.fin) _transition(TcpState.lastAck);

      case TcpState.lastAck:
        if (flags.ack) _transition(TcpState.closed);

      case TcpState.timeWait:
        // In a real stack TIME_WAIT lasts 2*MSL; here we close immediately.
        _transition(TcpState.closed, reason: 'TIME_WAIT expired');
    }

    return currentState;
  }

  void reset() {
    log('TCP reset → closed', name: 'TCPStateMachine');
    currentState = TcpState.closed;
  }

  void _transition(TcpState next, {String? reason}) {
    if (next == currentState) return;
    final msg = reason != null
        ? 'TCP: $currentState → $next ($reason)'
        : 'TCP: $currentState → $next';
    log(msg, name: 'TCPStateMachine');
    currentState = next;
  }
}
