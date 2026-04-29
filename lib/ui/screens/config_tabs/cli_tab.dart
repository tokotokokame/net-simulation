// lib/ui/screens/config_tabs/cli_tab.dart
//
// ⚠️ EDUCATIONAL PURPOSE ONLY
// This CLI operates ONLY within the virtual network topology.
// It has NO effect on real networks or systems.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/device.dart';
import '../topology_state.dart';

class CliTab extends ConsumerStatefulWidget {
  final Device device;
  const CliTab({super.key, required this.device});

  @override
  ConsumerState<CliTab> createState() => _CliTabState();
}

class _CliTabState extends ConsumerState<CliTab> {
  final List<String> _history    = [];
  final List<String> _cmdHistory = [];

  final ScrollController       _scroll = ScrollController();
  final TextEditingController  _input  = TextEditingController();
  final FocusNode              _focus  = FocusNode();

  String get _prompt {
    switch (widget.device.type) {
      case DeviceType.router:
      case DeviceType.l3Switch:
        return '${widget.device.name}#';
      case DeviceType.firewall:
        return '${widget.device.name}(fw)#';
      case DeviceType.switch_:
        return '${widget.device.name}>';
      default:
        return '${widget.device.name}\$';
    }
  }

  @override
  void initState() {
    super.initState();
    _history.addAll([
      'Net.Simulation CLI — type "help" for commands',
      'Device: ${widget.device.name} (${widget.device.type.name})',
      '',
    ]);
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Command execution ────────────────────────────────────
  void _execute(String raw) {
    final cmd = raw.trim();
    if (cmd.isEmpty) return;

    setState(() {
      _history.add('$_prompt $cmd');
      _cmdHistory.insert(0, cmd);
    });

    final parts = cmd.split(RegExp(r'\s+'));
    final verb  = parts[0].toLowerCase();
    final args  = parts.sublist(1);
    final output = _dispatch(verb, args);

    setState(() {
      _history.addAll(output);
      _history.add('');
    });

    _input.clear();
    _scrollToBottom();
  }

  // ── Dispatcher ───────────────────────────────────────────
  List<String> _dispatch(String verb, List<String> args) {
    switch (verb) {
      case 'help':
        return _helpText();

      case 'ping':
        if (args.isEmpty) return ['Usage: ping <IP or hostname>'];
        return _ping(args[0]);

      case 'traceroute':
      case 'tracert':
        if (args.isEmpty) return ['Usage: traceroute <IP or hostname>'];
        return _traceroute(args[0]);

      case 'ifconfig':
      case 'ipconfig':
        return _ifconfig();

      case 'show':
        if (args.isEmpty) {
          return ['Usage: show [ip route | arp | interfaces | version]'];
        }
        switch (args[0].toLowerCase()) {
          case 'ip':
            if (args.length > 1 && args[1] == 'route') return _showIpRoute();
            return ['Usage: show ip route'];
          case 'arp':        return _showArp();
          case 'interfaces': return _showInterfaces();
          case 'version':    return _showVersion();
          default:           return ['Unknown: show ${args[0]}'];
        }

      case 'arp':
        return _showArp();

      case 'nslookup':
        if (args.isEmpty) return ['Usage: nslookup <hostname>'];
        return _nslookup(args[0]);

      case 'clear':
      case 'cls':
        setState(() => _history.clear());
        return [];

      case 'exit':
      case 'quit':
        return ['Closing CLI session...'];

      case '':
        return [];

      default:
        return ['Command not found: $verb  (type "help" for list)'];
    }
  }

  // ── help ─────────────────────────────────────────────────
  List<String> _helpText() {
    final isRouter = widget.device.type == DeviceType.router ||
        widget.device.type == DeviceType.l3Switch;
    return [
      '┌─────────────────────────────────────────┐',
      '│  Net.Simulation CLI — Available Commands │',
      '├─────────────────────────────────────────┤',
      '│  ping <IP>          ICMP echo test       │',
      '│  traceroute <IP>    Hop-by-hop trace     │',
      '│  ifconfig           Show IP config       │',
      '│  arp                Show ARP table       │',
      '│  nslookup <host>    DNS lookup           │',
      if (isRouter) ...[
        '│  show ip route      Routing table        │',
        '│  show interfaces    Interface status     │',
      ],
      '│  show version       Software version     │',
      '│  clear              Clear screen         │',
      '│  help               This message         │',
      '└─────────────────────────────────────────┘',
    ];
  }

  // ── ping ─────────────────────────────────────────────────
  List<String> _ping(String target, {int count = 4}) {
    final topology = ref.read(topologyProvider);
    final targetDevice = topology.devices.where((d) =>
        d.interfaces.any((i) => i.ip == target) ||
        d.name.toLowerCase() == target.toLowerCase()).firstOrNull;

    final targetIp = targetDevice?.interfaces.firstOrNull?.ip ?? target;
    final reachable =
        targetDevice != null && targetDevice.id != widget.device.id;

    final result = <String>[
      'PING $targetIp: $count packets, 64 bytes each',
      '',
    ];

    if (!reachable) {
      for (int i = 1; i <= count; i++) {
        result.add('  Request timeout for icmp_seq $i');
      }
      result
        ..add('')
        ..add('--- $targetIp ping statistics ---')
        ..add('$count packets transmitted, 0 received, 100% packet loss');
      return result;
    }

    final rng = Random();
    int rxCount = 0;
    double totalMs = 0, minMs = double.infinity, maxMs = 0;

    for (int i = 1; i <= count; i++) {
      if (rng.nextDouble() < 0.02) {
        result.add('  Request timeout for icmp_seq $i');
        continue;
      }
      final ms = 1.0 + rng.nextDouble() * 19;
      result.add(
          '  64 bytes from $targetIp: icmp_seq=$i ttl=64 time=${ms.toStringAsFixed(2)} ms');
      rxCount++;
      totalMs += ms;
      if (ms < minMs) minMs = ms;
      if (ms > maxMs) maxMs = ms;
    }

    final loss = ((count - rxCount) / count * 100).toStringAsFixed(0);
    final avg  = rxCount > 0 ? (totalMs / rxCount).toStringAsFixed(2) : '-';
    result
      ..add('')
      ..add('--- $targetIp ping statistics ---')
      ..add('$count packets transmitted, $rxCount received, $loss% packet loss');
    if (rxCount > 0) {
      result.add('rtt min/avg/max = '
          '${minMs.toStringAsFixed(2)}/$avg/${maxMs.toStringAsFixed(2)} ms');
    }
    return result;
  }

  // ── traceroute ───────────────────────────────────────────
  List<String> _traceroute(String target) {
    final topology = ref.read(topologyProvider);
    final targetDevice = topology.devices.where((d) =>
        d.interfaces.any((i) => i.ip == target) ||
        d.name.toLowerCase() == target.toLowerCase()).firstOrNull;

    final targetIp = targetDevice?.interfaces.firstOrNull?.ip ?? target;

    if (targetDevice == null) {
      return [
        'traceroute to $target, 30 hops max',
        ' 1  * * *  Request timeout',
        '',
        'Destination unreachable.',
      ];
    }

    final path = _bfsPath(widget.device.id, targetDevice.id, topology);
    if (path.isEmpty) {
      return [
        'traceroute to $targetIp, 30 hops max',
        ' 1  * * *  No route to host',
      ];
    }

    final rng = Random();
    final result = <String>[
      'traceroute to $targetIp (${targetDevice.name}), 30 hops max',
      '',
    ];

    for (int i = 0; i < path.length; i++) {
      final hop     = topology.devices.where((d) => d.id == path[i]).firstOrNull;
      final hopIp   = hop?.interfaces.firstOrNull?.ip ?? '*';
      final hopName = hop?.name ?? '?';
      final base = 1.0 + rng.nextDouble() * 5 * (i + 1);
      final ms1 = base.toStringAsFixed(2);
      final ms2 = (base + rng.nextDouble()).toStringAsFixed(2);
      final ms3 = (base + rng.nextDouble()).toStringAsFixed(2);
      result.add(
          ' ${(i + 1).toString().padLeft(2)}  $hopIp ($hopName)  ${ms1}ms  ${ms2}ms  ${ms3}ms');
    }
    result..add('')..add('Trace complete.');
    return result;
  }

  List<String> _bfsPath(String src, String dst, dynamic topology) {
    if (src == dst) return [src];
    final adj = <String, List<String>>{};
    for (final link in topology.links) {
      adj.putIfAbsent(link.deviceAId, () => []).add(link.deviceBId);
      adj.putIfAbsent(link.deviceBId, () => []).add(link.deviceAId);
    }
    final visited = <String>{src};
    final queue   = <List<String>>[[src]];
    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final node = path.last;
      if (node == dst) return path;
      for (final next in adj[node] ?? []) {
        if (visited.add(next)) queue.add([...path, next]);
      }
    }
    return [];
  }

  // ── ifconfig ─────────────────────────────────────────────
  List<String> _ifconfig() {
    if (widget.device.interfaces.isEmpty) return ['No interfaces configured.'];
    final result = <String>[];
    for (final iface in widget.device.interfaces) {
      result.addAll([
        '${iface.name}:',
        '  inet ${iface.ip}  prefix /${iface.subnet}',
        '  ether ${iface.mac}',
        '  MTU ${iface.mtu}',
        '',
      ]);
    }
    return result;
  }

  // ── show ip route ────────────────────────────────────────
  List<String> _showIpRoute() {
    final topology = ref.read(topologyProvider);
    final result   = <String>[
      'Codes: C - connected, S - static',
      '',
    ];
    for (final iface in widget.device.interfaces) {
      if (iface.ip.isNotEmpty && iface.ip != '0.0.0.0') {
        result.add(
            'C    ${iface.ip}/${iface.subnet} is directly connected, ${iface.name}');
      }
    }
    final myLinks = topology.links.where((l) =>
        l.deviceAId == widget.device.id || l.deviceBId == widget.device.id);
    for (final link in myLinks) {
      final neighborId = link.deviceAId == widget.device.id
          ? link.deviceBId
          : link.deviceAId;
      final neighbor =
          topology.devices.where((d) => d.id == neighborId).firstOrNull;
      if (neighbor == null) continue;
      for (final iface in neighbor.interfaces) {
        if (iface.ip.isNotEmpty && iface.ip != '0.0.0.0') {
          final via = widget.device.interfaces.firstOrNull?.name ?? 'eth0';
          result.add(
              'S    ${iface.ip}/${iface.subnet} [1/0] via ${neighbor.name}, $via');
        }
      }
    }
    if (result.length <= 2) result.add('  (no routes)');
    return result;
  }

  // ── show arp ─────────────────────────────────────────────
  List<String> _showArp() {
    final topology = ref.read(topologyProvider);
    final result   = <String>[
      'Protocol  Address          Age  Hardware Addr       Type',
    ];
    final myLinks = topology.links.where((l) =>
        l.deviceAId == widget.device.id || l.deviceBId == widget.device.id);
    for (final link in myLinks) {
      final neighborId = link.deviceAId == widget.device.id
          ? link.deviceBId
          : link.deviceAId;
      final neighbor =
          topology.devices.where((d) => d.id == neighborId).firstOrNull;
      if (neighbor == null) continue;
      for (final iface in neighbor.interfaces) {
        if (iface.ip.isNotEmpty && iface.mac.isNotEmpty) {
          result.add(
              'Internet  ${iface.ip.padRight(16)} -    ${iface.mac}  ARPA');
        }
      }
    }
    if (result.length == 1) result.add('  (empty)');
    return result;
  }

  // ── show interfaces ──────────────────────────────────────
  List<String> _showInterfaces() {
    if (widget.device.interfaces.isEmpty) return ['No interfaces.'];
    final result = <String>[];
    for (final iface in widget.device.interfaces) {
      result.addAll([
        '${iface.name} is ${iface.status.name}, line protocol is ${iface.status.name}',
        '  Internet address is ${iface.ip}/${iface.subnet}',
        '  Hardware is EthernetSIM, address is ${iface.mac}',
        '  MTU ${iface.mtu} bytes, BW ${(iface.bandwidth / 1000).toStringAsFixed(0)} Kbit/sec',
        '',
      ]);
    }
    return result;
  }

  // ── show version ─────────────────────────────────────────
  List<String> _showVersion() {
    return [
      'Net.Simulation — Educational Network Simulator',
      'Device: ${widget.device.name} (${widget.device.type.name})',
      'Platform: Flutter/Dart — Virtual Environment',
      '',
      '⚠ EDUCATIONAL PURPOSE ONLY',
      '  All simulation is contained within the virtual topology.',
    ];
  }

  // ── nslookup ─────────────────────────────────────────────
  List<String> _nslookup(String host) {
    final topology = ref.read(topologyProvider);
    final found = topology.devices
        .where((d) =>
            d.name.toLowerCase() == host.toLowerCase() ||
            d.name.toLowerCase().replaceAll(' ', '-') == host.toLowerCase())
        .firstOrNull;

    if (found == null) {
      return [
        'Server:  sim.dns.local',
        'Address: 127.0.0.53',
        '',
        "** server can't find $host: NXDOMAIN",
      ];
    }
    final ip = found.interfaces.firstOrNull?.ip ?? 'N/A';
    return [
      'Server:  sim.dns.local',
      'Address: 127.0.0.53',
      '',
      'Name:    ${found.name}.local',
      'Address: $ip',
    ];
  }

  // ── Scroll ───────────────────────────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom  = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // ── Output area ─────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _history.length,
              itemBuilder: (_, i) => Text(
                _history[i],
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFF00FF41),
                  height: 1.4,
                ),
              ),
            ),
          ),

          // ── Input area ──────────────────────────────────
          Container(
            color: const Color(0xFF0A0A0A),
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: 6,
              bottom: bottomInset > 0 ? 6 : safeBottom + 6,
            ),
            child: Row(
              children: [
                Text(
                  _prompt,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFF00FF41),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode:  _focus,
                    autofocus:  true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Color(0xFF00FF41),
                    ),
                    cursorColor: const Color(0xFF00FF41),
                    decoration: const InputDecoration(
                      border:         InputBorder.none,
                      isDense:        true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                    textInputAction: TextInputAction.send,
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\t')),
                    ],
                    onSubmitted: (v) {
                      _execute(v);
                      _focus.requestFocus();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, size: 18),
                  color: const Color(0xFF00FF41),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _execute(_input.text);
                    _focus.requestFocus();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
