// lib/ui/screens/packet_inspector_screen.dart
import 'package:flutter/material.dart';

class PacketInspectorSheet extends StatelessWidget {
  final String       srcIp;
  final String       dstIp;
  final String       protocol;
  final int          ttl;
  final int          size;
  final String       status;
  final List<String> hopNames;

  const PacketInspectorSheet({
    super.key,
    required this.srcIp,
    required this.dstIp,
    required this.protocol,
    required this.ttl,
    required this.size,
    required this.status,
    required this.hopNames,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.search, color: Color(0xFF64B5F6), size: 18),
            SizedBox(width: 8),
            Text('パケット詳細',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          _SectionTitle('IP ヘッダ'),
          _InfoRow('送信元 IP',  srcIp),
          _InfoRow('宛先 IP',    dstIp),
          _InfoRow('プロトコル', protocol),
          _InfoRow('TTL',        '$ttl（ホップするたびに -1）'),
          _InfoRow('サイズ',     '$size bytes'),
          _InfoRow('ステータス', status),
          const SizedBox(height: 12),
          _SectionTitle('経路（ホップバイホップ）'),
          _HopPath(hopNames: hopNames),
          const SizedBox(height: 12),
          _SectionTitle('OSI参照モデル上の位置'),
          _OsiHighlight(protocol: protocol),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF64B5F6),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0)),
      );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
                width: 110,
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'monospace'))),
          ],
        ),
      );
}

class _HopPath extends StatelessWidget {
  final List<String> hopNames;
  const _HopPath({required this.hopNames});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: hopNames.asMap().entries.map((e) {
          final isLast = e.key == hopNames.length - 1;
          return Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLast
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                    : const Color(0xFF2196F3).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: isLast
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF2196F3),
                    width: 0.5),
              ),
              child: Text(e.value,
                  style: TextStyle(
                      color: isLast
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF2196F3),
                      fontSize: 11)),
            ),
            if (!isLast)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward,
                    color: Colors.white24, size: 14)),
          ]);
        }).toList(),
      ),
    );
  }
}

class _OsiHighlight extends StatelessWidget {
  final String protocol;
  const _OsiHighlight({required this.protocol});

  @override
  Widget build(BuildContext context) {
    final highlight = switch (protocol.toUpperCase()) {
      'HTTP' || 'DNS' || 'FTP' || 'SSH' => 7,
      'TCP'  || 'UDP'                   => 4,
      'IP'   || 'ICMP' || 'OSPF'       => 3,
      'ARP'  || 'VLAN'                  => 2,
      _                                 => 3,
    };

    const layers = [
      (7, 'アプリケーション層', 'HTTP / DNS / FTP'),
      (4, 'トランスポート層',   'TCP / UDP'),
      (3, 'ネットワーク層',     'IP / ICMP / OSPF'),
      (2, 'データリンク層',     'ARP / VLAN / MAC'),
      (1, '物理層',             'ケーブル / 電気信号'),
    ];

    return Column(
      children: layers.map((l) {
        final isHighlight = l.$1 == highlight;
        return Container(
          margin: const EdgeInsets.only(bottom: 3),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isHighlight
                ? const Color(0xFFFFC107).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: isHighlight
                    ? const Color(0xFFFFC107)
                    : Colors.white12,
                width: isHighlight ? 1.0 : 0.5),
          ),
          child: Row(
            children: [
              Text('L${l.$1}',
                  style: TextStyle(
                      color: isHighlight
                          ? const Color(0xFFFFC107)
                          : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
              const SizedBox(width: 10),
              Text(l.$2,
                  style: TextStyle(
                      color:
                          isHighlight ? Colors.white : Colors.white54,
                      fontSize: 11,
                      fontWeight: isHighlight
                          ? FontWeight.bold
                          : FontWeight.normal)),
              const Spacer(),
              Text(l.$3,
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 10)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
