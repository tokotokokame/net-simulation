// lib/storage/demo_topologies.dart
//
// Five built-in demo topologies.  Their IDs all start with "demo-" so the
// UI can detect them without an extra DB column.

import '../models/device.dart';
import '../models/link.dart';
import '../models/network_interface.dart';
import '../models/topology.dart';

// ── Helper constructors ────────────────────────────────────────────────────────

Device _dev(String id, DeviceType type, String name, double x, double y,
    List<NetworkInterface> ifaces) =>
    Device(id: id, type: type, name: name, x: x, y: y, interfaces: ifaces);

NetworkInterface _iface(String name, String ip) => NetworkInterface(
      name: name, ip: ip, subnet: 24, mac: '00:00:00:00:00:00');

Link _link(String id, String a, String b,
    {String ifA = 'eth0', String ifB = 'eth0', int bw = 100000000}) =>
    Link(
      id: id,
      deviceAId: a,
      deviceBId: b,
      interfaceAName: ifA,
      interfaceBName: ifB,
      bandwidth: bw,
      latency: 1.0,
      packetLoss: 0.0,
    );

Topology _topo(String id, String name, DateTime t,
    List<Device> devices, List<Link> links) =>
    Topology(id: id, name: name, devices: devices, links: links,
        createdAt: t, updatedAt: t);

// ── D1: 小規模 LAN ─────────────────────────────────────────────────────────────

Topology get demoD1 {
  final t = DateTime(2024, 1, 1);
  final inet    = _dev('demo-d1-inet',  DeviceType.internetCloud, 'Internet',  400, 120, [_iface('eth0', '203.0.113.1')]);
  final router  = _dev('demo-d1-rtr',   DeviceType.router,        'Router-1',  400, 300, [_iface('eth0', '203.0.113.2'), _iface('eth1', '192.168.1.1')]);
  final sw      = _dev('demo-d1-sw',    DeviceType.switch_,       'Switch-1',  400, 480, [_iface('eth0', '192.168.1.2')]);
  final pc1     = _dev('demo-d1-pc1',   DeviceType.pc,            'PC-1',      220, 660, [_iface('eth0', '192.168.1.10')]);
  final pc2     = _dev('demo-d1-pc2',   DeviceType.pc,            'PC-2',      400, 660, [_iface('eth0', '192.168.1.11')]);
  final pc3     = _dev('demo-d1-pc3',   DeviceType.pc,            'PC-3',      580, 660, [_iface('eth0', '192.168.1.12')]);

  return _topo('demo-d1', '[Demo] 小規模LAN', t, [inet, router, sw, pc1, pc2, pc3], [
    _link('demo-d1-l1', inet.id,   router.id),
    _link('demo-d1-l2', router.id, sw.id,  ifA: 'eth1'),
    _link('demo-d1-l3', sw.id,     pc1.id),
    _link('demo-d1-l4', sw.id,     pc2.id),
    _link('demo-d1-l5', sw.id,     pc3.id),
  ]);
}

// ── D2: サーバー・クライアント ──────────────────────────────────────────────────

Topology get demoD2 {
  final t = DateTime(2024, 1, 2);
  final srv     = _dev('demo-d2-srv',  DeviceType.server, 'Server-1',  400, 120, [_iface('eth0', '10.0.0.1')]);
  final sw      = _dev('demo-d2-sw',   DeviceType.switch_, 'Switch-1', 400, 300, [_iface('eth0', '10.0.0.254')]);
  final pc1     = _dev('demo-d2-pc1',  DeviceType.pc,     'PC-1',      160, 480, [_iface('eth0', '10.0.0.10')]);
  final pc2     = _dev('demo-d2-pc2',  DeviceType.pc,     'PC-2',      400, 480, [_iface('eth0', '10.0.0.11')]);
  final pc3     = _dev('demo-d2-pc3',  DeviceType.pc,     'PC-3',      640, 480, [_iface('eth0', '10.0.0.12')]);
  final laptop  = _dev('demo-d2-lap',  DeviceType.laptop, 'Laptop-1',  280, 660, [_iface('eth0', '10.0.0.20')]);

  return _topo('demo-d2', '[Demo] サーバー・クライアント', t,
      [srv, sw, pc1, pc2, pc3, laptop], [
    _link('demo-d2-l1', srv.id, sw.id),
    _link('demo-d2-l2', sw.id,  pc1.id),
    _link('demo-d2-l3', sw.id,  pc2.id),
    _link('demo-d2-l4', sw.id,  pc3.id),
    _link('demo-d2-l5', sw.id,  laptop.id),
  ]);
}

// ── D3: セキュリティ構成 ────────────────────────────────────────────────────────

Topology get demoD3 {
  final t = DateTime(2024, 1, 3);
  final inet = _dev('demo-d3-inet', DeviceType.internetCloud, 'Internet',  400, 100, [_iface('eth0', '203.0.113.1')]);
  final fw   = _dev('demo-d3-fw',   DeviceType.firewall,      'Firewall',  300, 280, [_iface('eth0', '203.0.113.2'), _iface('eth1', '172.16.0.1')]);
  final ids  = _dev('demo-d3-ids',  DeviceType.ids,           'IDS',       560, 280, [_iface('eth0', '172.16.0.10')]);
  final rtr  = _dev('demo-d3-rtr',  DeviceType.router,        'Router-1',  300, 460, [_iface('eth0', '172.16.0.2'), _iface('eth1', '192.168.1.1')]);
  final sw   = _dev('demo-d3-sw',   DeviceType.switch_,       'Switch-1',  300, 640, [_iface('eth0', '192.168.1.254')]);
  final pc1  = _dev('demo-d3-pc1',  DeviceType.pc,            'PC-1',      160, 820, [_iface('eth0', '192.168.1.10')]);
  final pc2  = _dev('demo-d3-pc2',  DeviceType.pc,            'PC-2',      440, 820, [_iface('eth0', '192.168.1.11')]);

  return _topo('demo-d3', '[Demo] セキュリティ構成', t,
      [inet, fw, ids, rtr, sw, pc1, pc2], [
    _link('demo-d3-l1', inet.id, fw.id),
    _link('demo-d3-l2', fw.id,  ids.id, ifA: 'eth1'),
    _link('demo-d3-l3', fw.id,  rtr.id, ifA: 'eth1'),
    _link('demo-d3-l4', rtr.id, sw.id,  ifA: 'eth1'),
    _link('demo-d3-l5', sw.id,  pc1.id),
    _link('demo-d3-l6', sw.id,  pc2.id),
  ]);
}

// ── D4: 無線 LAN オフィス ───────────────────────────────────────────────────────

Topology get demoD4 {
  final t = DateTime(2024, 1, 4);
  final inet = _dev('demo-d4-inet', DeviceType.internetCloud, 'Internet',  400, 100, [_iface('eth0', '203.0.113.1')]);
  final rtr  = _dev('demo-d4-rtr',  DeviceType.router,        'Router-1',  400, 280, [_iface('eth0', '203.0.113.2'), _iface('eth1', '192.168.10.1')]);
  final sw   = _dev('demo-d4-sw',   DeviceType.switch_,       'Switch-1',  600, 460, [_iface('eth0', '192.168.10.254')]);
  final ap   = _dev('demo-d4-ap',   DeviceType.wirelessAP,    'AP-1',      200, 460, [_iface('eth0', '192.168.10.2')]);
  final srv  = _dev('demo-d4-srv',  DeviceType.server,        'FileServer',700, 640, [_iface('eth0', '192.168.10.100')]);
  final lap1 = _dev('demo-d4-l1',   DeviceType.laptop,        'Laptop-1',   80, 660, [_iface('eth0', '192.168.10.30')]);
  final lap2 = _dev('demo-d4-l2',   DeviceType.laptop,        'Laptop-2',  260, 660, [_iface('eth0', '192.168.10.31')]);
  final iot  = _dev('demo-d4-iot',  DeviceType.iotDevice,     'IoT-1',     440, 660, [_iface('eth0', '192.168.10.50')]);

  return _topo('demo-d4', '[Demo] 無線LANオフィス', t,
      [inet, rtr, sw, ap, srv, lap1, lap2, iot], [
    _link('demo-d4-l1', inet.id, rtr.id),
    _link('demo-d4-l2', rtr.id, sw.id,  ifA: 'eth1'),
    _link('demo-d4-l3', rtr.id, ap.id,  ifA: 'eth1'),
    _link('demo-d4-l4', sw.id,  srv.id),
    _link('demo-d4-l5', ap.id,  lap1.id),
    _link('demo-d4-l6', ap.id,  lap2.id),
    _link('demo-d4-l7', ap.id,  iot.id),
  ]);
}

// ── D5: SDN ネットワーク ────────────────────────────────────────────────────────

Topology get demoD5 {
  final t = DateTime(2024, 1, 5);
  final ctrl  = _dev('demo-d5-ctrl', DeviceType.sdnController,  'SDN-Controller', 400, 100, [_iface('eth0', '10.255.0.1')]);
  final ofs1  = _dev('demo-d5-ofs1', DeviceType.openFlowSwitch, 'OFSwitch-1',     220, 300, [_iface('eth0', '10.255.0.10')]);
  final ofs2  = _dev('demo-d5-ofs2', DeviceType.openFlowSwitch, 'OFSwitch-2',     580, 300, [_iface('eth0', '10.255.0.11')]);
  final srv1  = _dev('demo-d5-sv1',  DeviceType.server,         'Server-1',       120, 500, [_iface('eth0', '10.0.1.1')]);
  final srv2  = _dev('demo-d5-sv2',  DeviceType.server,         'Server-2',       320, 500, [_iface('eth0', '10.0.1.2')]);
  final srv3  = _dev('demo-d5-sv3',  DeviceType.server,         'Server-3',       480, 500, [_iface('eth0', '10.0.2.1')]);
  final srv4  = _dev('demo-d5-sv4',  DeviceType.server,         'Server-4',       680, 500, [_iface('eth0', '10.0.2.2')]);

  return _topo('demo-d5', '[Demo] SDNネットワーク', t,
      [ctrl, ofs1, ofs2, srv1, srv2, srv3, srv4], [
    _link('demo-d5-l1', ctrl.id, ofs1.id),
    _link('demo-d5-l2', ctrl.id, ofs2.id),
    _link('demo-d5-l3', ofs1.id, ofs2.id),
    _link('demo-d5-l4', ofs1.id, srv1.id),
    _link('demo-d5-l5', ofs1.id, srv2.id),
    _link('demo-d5-l6', ofs2.id, srv3.id),
    _link('demo-d5-l7', ofs2.id, srv4.id),
  ]);
}

// ── D6: 通信キャリア網（Telecommunications Network Architecture） ──────────────

Topology get demoD6 {
  final t = DateTime(2024, 1, 6);

  // ── バックボーン ─────────────────────────────────────────────────────────────
  final mpls   = _dev('demo-d6-mpls',   DeviceType.mplsCloud,            'MegaPath骨格網',    530,  80, [_iface('eth0', '10.0.0.1')]);
  final inet   = _dev('demo-d6-inet',   DeviceType.internetCloud,        'Internet',           530, 200, [_iface('eth0', '10.0.0.2')]);
  final popA   = _dev('demo-d6-popa',   DeviceType.router,               'Level3-Pops-A',      180, 120, [_iface('eth0', '10.0.0.3')]);
  final popB   = _dev('demo-d6-popb',   DeviceType.router,               'Level3-Pops-B',      880, 120, [_iface('eth0', '10.0.0.4')]);

  // ── 西拠点 ───────────────────────────────────────────────────────────────────
  final rA     = _dev('demo-d6-ra',     DeviceType.router,               'Router-A',           180, 260, [_iface('eth0', '10.1.0.1')]);
  final fwA    = _dev('demo-d6-fwa',    DeviceType.firewall,             'FW-A(西拠点)',        180, 380, [_iface('eth0', '10.1.0.2')]);
  final media  = _dev('demo-d6-media',  DeviceType.server,               'メディアSV',          80, 500, [_iface('eth0', '10.1.1.10')]);
  final backup = _dev('demo-d6-bk',     DeviceType.server,               'バックアップSV',      280, 500, [_iface('eth0', '10.1.1.11')]);
  final swW    = _dev('demo-d6-sww',    DeviceType.switch_,              'SW-West',            180, 620, [_iface('eth0', '10.1.1.254')]);
  final ctl    = _dev('demo-d6-ctl',    DeviceType.server,               'CTL-SV',              30, 760, [_iface('eth0', '10.1.2.10')]);
  final mail   = _dev('demo-d6-mail',   DeviceType.server,               'メール-SV',           130, 760, [_iface('eth0', '10.1.2.11')]);
  final video  = _dev('demo-d6-video',  DeviceType.server,               'ビデオ会議SV',        230, 760, [_iface('eth0', '10.1.2.12')]);
  final ad     = _dev('demo-d6-ad',     DeviceType.activeDirectoryServer,'AD-SV',              330, 760, [_iface('eth0', '10.1.2.13')]);

  // ── 東拠点 ───────────────────────────────────────────────────────────────────
  final rB     = _dev('demo-d6-rb',     DeviceType.router,               'Router-B',           880, 260, [_iface('eth0', '10.2.0.1')]);
  final fwB    = _dev('demo-d6-fwb',    DeviceType.firewall,             'FW-B(東拠点)',        880, 380, [_iface('eth0', '10.2.0.2')]);
  final pr1    = _dev('demo-d6-pr1',    DeviceType.lteNetwork,           'PR1回線(WAN)',       1050, 380, [_iface('eth0', '10.2.0.10')]);
  final rIsp   = _dev('demo-d6-risp',   DeviceType.router,               'Router-ISP',         880, 500, [_iface('eth0', '10.2.1.1')]);
  final phone1 = _dev('demo-d6-ph1',    DeviceType.iotDevice,            'IP電話-1',            700, 640, [_iface('eth0', '10.2.2.10')]);
  final phone2 = _dev('demo-d6-ph2',    DeviceType.iotDevice,            'IP電話-2',            800, 640, [_iface('eth0', '10.2.2.11')]);
  final phone3 = _dev('demo-d6-ph3',    DeviceType.iotDevice,            'IP電話-3',            900, 640, [_iface('eth0', '10.2.2.12')]);
  final softR  = _dev('demo-d6-soft',   DeviceType.server,               'Softswitch-R',      1000, 640, [_iface('eth0', '10.2.2.20')]);
  final pstn   = _dev('demo-d6-pstn',   DeviceType.internetCloud,        'PSTN',               880, 760, [_iface('eth0', '10.2.3.1')]);
  final co1    = _dev('demo-d6-co1',    DeviceType.switch_,              'CO-Switch-1',        700, 760, [_iface('eth0', '10.2.3.10')]);
  final co2    = _dev('demo-d6-co2',    DeviceType.switch_,              'CO-Switch-2',       1000, 760, [_iface('eth0', '10.2.3.11')]);

  // ── 拠点間VPN ─────────────────────────────────────────────────────────────────
  final vpn    = _dev('demo-d6-vpn',    DeviceType.vpnGateway,           'VPN-GW',             530, 400, [_iface('eth0', '10.10.0.1')]);

  return _topo('demo-d6', '[Demo] 通信キャリア網構成', t, [
    mpls, inet, popA, popB,
    rA, fwA, media, backup, swW, ctl, mail, video, ad,
    rB, fwB, pr1, rIsp, phone1, phone2, phone3, softR, pstn, co1, co2,
    vpn,
  ], [
    // ── バックボーン ──────────────────────────────────
    _link('demo-d6-l01', popA.id,  mpls.id,  bw: 10000000000),
    _link('demo-d6-l02', popB.id,  mpls.id,  bw: 10000000000),
    _link('demo-d6-l03', mpls.id,  inet.id,  bw: 10000000000),
    _link('demo-d6-l04', popA.id,  inet.id,  bw: 1000000000),
    _link('demo-d6-l05', popB.id,  inet.id,  bw: 1000000000),

    // ── 西拠点 ────────────────────────────────────────
    _link('demo-d6-l06', popA.id,  rA.id,    bw: 1000000000),
    _link('demo-d6-l07', rA.id,    fwA.id),
    _link('demo-d6-l08', fwA.id,   media.id),
    _link('demo-d6-l09', fwA.id,   backup.id),
    _link('demo-d6-l10', fwA.id,   swW.id),
    _link('demo-d6-l11', media.id, backup.id),
    _link('demo-d6-l12', swW.id,   ctl.id),
    _link('demo-d6-l13', swW.id,   mail.id),
    _link('demo-d6-l14', swW.id,   video.id),
    _link('demo-d6-l15', swW.id,   ad.id),

    // ── 東拠点 ────────────────────────────────────────
    _link('demo-d6-l16', popB.id,  rB.id,    bw: 1000000000),
    _link('demo-d6-l17', rB.id,    fwB.id),
    _link('demo-d6-l18', fwB.id,   pr1.id),
    _link('demo-d6-l19', fwB.id,   rIsp.id),
    _link('demo-d6-l20', rIsp.id,  phone1.id),
    _link('demo-d6-l21', rIsp.id,  phone2.id),
    _link('demo-d6-l22', rIsp.id,  phone3.id),
    _link('demo-d6-l23', rIsp.id,  softR.id),
    _link('demo-d6-l24', rIsp.id,  pstn.id),
    _link('demo-d6-l25', pstn.id,  co1.id),
    _link('demo-d6-l26', pstn.id,  co2.id),

    // ── 拠点間VPN（西FW ↔ VPN-GW ↔ 東FW） ────────────
    _link('demo-d6-l27', fwA.id,   vpn.id),
    _link('demo-d6-l28', vpn.id,   fwB.id),
  ]);
}

/// All demo topologies in display order.
List<Topology> get allDemoTopologies => [demoD1, demoD2, demoD3, demoD4, demoD5, demoD6];
