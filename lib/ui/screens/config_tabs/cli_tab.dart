// lib/ui/screens/config_tabs/cli_tab.dart
import 'package:flutter/material.dart';
import '../../../models/device.dart';

class CliTab extends StatefulWidget {
  final Device device;
  const CliTab({super.key, required this.device});

  @override
  State<CliTab> createState() => _CliTabState();
}

class _CliTabState extends State<CliTab> {
  final _lines = <String>[];
  final _inputCtrl = TextEditingController();
  final _scroll = ScrollController();

  static const _prompt = '# ';
  static const _style = TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF00FF00));

  @override
  void initState() {
    super.initState();
    _lines.add('Net.Simulation v4 CLI — type "help" for commands');
    _lines.add('Device: ${widget.device.name} (${widget.device.type.name})');
  }

  @override
  void dispose() { _inputCtrl.dispose(); _scroll.dispose(); super.dispose(); }

  void _submit(String cmd) {
    final trimmed = cmd.trim();
    _lines.add('$_prompt$trimmed');
    _lines.addAll(_execute(trimmed));
    _inputCtrl.clear();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  List<String> _execute(String cmd) {
    final parts = cmd.split(' ');
    return switch (parts[0]) {
      'help' => ['show ip route', 'show arp', 'show interfaces', 'show nat translations', 'clear arp', 'ping <ip>'],
      'show' when parts.length >= 3 && parts[1] == 'ip' && parts[2] == 'route' =>
        ['Codes: C-connected, S-static', ...widget.device.interfaces.map((i) => 'C  ${i.ip}/${i.subnet} is directly connected, ${i.name}')],
      'show' when parts.length >= 2 && parts[1] == 'arp' =>
        ['Protocol  Address       Age  Hardware Addr    Interface',
         ...widget.device.interfaces.map((i) => 'Internet  ${i.ip.padRight(13)} -    ${i.mac}  ${i.name}')],
      'show' when parts.length >= 2 && parts[1] == 'interfaces' =>
        [...widget.device.interfaces.map((i) => '${i.name} is ${i.status.name}, line protocol is ${i.status.name}  IP ${i.ip}/${i.subnet}')],
      'show' when parts.length >= 3 && parts[1] == 'nat' =>
        ['Pro  Inside local    Inside global   Outside global', '-- No active NAT translations --'],
      'clear' when parts.length >= 2 && parts[1] == 'arp' =>
        ['ARP table cleared'],
      'ping' when parts.length >= 2 =>
        ['PING ${parts[1]}', '!!!!!', 'Success rate is 100 percent (5/5), round-trip min/avg/max = 1/2/4 ms'],
      '' => [],
      _ => ['% Unknown command: $cmd'],
    };
  }

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black,
    child: Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(8),
            itemCount: _lines.length,
            itemBuilder: (_, i) => Text(_lines[i], style: _style),
          ),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            const Text(_prompt, style: _style),
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                style: _style,
                cursorColor: const Color(0xFF00FF00),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                onSubmitted: _submit,
                autofocus: false,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF00FF00), size: 18),
              onPressed: () => _submit(_inputCtrl.text),
            ),
          ]),
        ),
      ],
    ),
  );
}
