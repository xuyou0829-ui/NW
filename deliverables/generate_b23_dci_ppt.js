const PptxGenJS = require('pptxgenjs');

const pptx = new PptxGenJS();
pptx.layout = 'LAYOUT_WIDE';
pptx.author = 'SiowAI';
pptx.company = 'OpenClaw';
pptx.subject = 'B23.1机房专线接入与互联架构';
pptx.title = 'B23.1机房专线接入与互联架构建议';
pptx.lang = 'zh-CN';
pptx.theme = {
  headFontFace: 'Microsoft YaHei',
  bodyFontFace: 'Microsoft YaHei',
  lang: 'zh-CN'
};

const C = {
  navy: '0F2747',
  blue: '1F5AA6',
  lightBlue: 'DCEBFF',
  teal: 'DDEFEF',
  green: 'DFF2E1',
  orange: 'FFE8CC',
  red: 'FBE4E6',
  gray: '667085',
  dark: '101828',
  line: '98A2B3',
  white: 'FFFFFF',
  yellow: 'FFF7D6'
};

function addHeader(slide, title, subtitle='') {
  slide.addText(title, {
    x: 0.45, y: 0.22, w: 12.0, h: 0.45,
    fontFace: 'Microsoft YaHei', fontSize: 24, bold: true, color: C.navy
  });
  if (subtitle) {
    slide.addText(subtitle, {
      x: 0.48, y: 0.66, w: 12.0, h: 0.25,
      fontFace: 'Microsoft YaHei', fontSize: 9, color: C.gray
    });
  }
  slide.addShape(pptx.ShapeType.line, {
    x: 0.45, y: 0.98, w: 12.35, h: 0,
    line: { color: C.blue, pt: 1.5 }
  });
}

function addFooter(slide, txt='SiowAI 草案') {
  slide.addText(txt, {
    x: 0.45, y: 7.0, w: 3.5, h: 0.2,
    fontSize: 8, color: C.gray, italic: true
  });
}

function addBullets(slide, items, opts={}) {
  const x = opts.x ?? 0.75;
  const y = opts.y ?? 1.35;
  const w = opts.w ?? 5.4;
  const h = opts.h ?? 4.8;
  const fontSize = opts.fontSize ?? 17;
  const runs = [];
  items.forEach((item) => {
    runs.push({
      text: item,
      options: {
        bullet: { indent: 16 },
        breakLine: true,
        hanging: 3,
      }
    });
  });
  slide.addText(runs, {
    x, y, w, h,
    fontFace: 'Microsoft YaHei', fontSize,
    color: C.dark,
    paraSpaceAfterPt: 12,
    valign: 'top',
    margin: 2
  });
}

function addBox(slide, x, y, w, h, title, fill, lines=[], opts={}) {
  slide.addShape(pptx.ShapeType.roundRect, {
    x, y, w, h,
    rectRadius: 0.08,
    fill: { color: fill },
    line: { color: opts.lineColor || C.line, pt: 1.2 }
  });
  slide.addText(title, {
    x: x + 0.08, y: y + 0.06, w: w - 0.16, h: 0.28,
    fontFace: 'Microsoft YaHei', fontSize: opts.titleSize || 14, bold: true, color: C.navy,
    align: 'center'
  });
  if (lines.length) {
    slide.addText(lines.map((t) => ({ text: t, options: { breakLine: true } })), {
      x: x + 0.12, y: y + 0.38, w: w - 0.24, h: h - 0.44,
      fontFace: 'Microsoft YaHei', fontSize: opts.bodySize || 9, color: C.dark,
      align: 'center', valign: 'mid', margin: 2
    });
  }
}

function connect(slide, x1, y1, x2, y2, color=C.blue, dash='solid') {
  slide.addShape(pptx.ShapeType.line, {
    x: x1, y: y1, w: x2 - x1, h: y2 - y1,
    line: { color, pt: 1.8, beginArrowType: 'none', endArrowType: 'triangle', dash }
  });
}

function connectPlain(slide, x1, y1, x2, y2, color=C.line, dash='solid') {
  slide.addShape(pptx.ShapeType.line, {
    x: x1, y: y1, w: x2 - x1, h: y2 - y1,
    line: { color, pt: 1.3, dash }
  });
}

// Slide 1
{
  const slide = pptx.addSlide();
  slide.background = { color: 'F8FAFC' };
  slide.addShape(pptx.ShapeType.rect, { x:0, y:0, w:13.333, h:7.5, fill:{color:'F8FAFC'}, line:{color:'F8FAFC'} });
  slide.addText('B23.1机房专线接入与互联架构建议', {
    x:0.65, y:0.9, w:12, h:0.7,
    fontFace:'Microsoft YaHei', fontSize:26, bold:true, color:C.navy, align:'center'
  });
  slide.addText('面向客户数据中心双 100G 专线接入的拓扑、冗余、安全与设备建议', {
    x:1.0, y:1.7, w:11.3, h:0.3,
    fontFace:'Microsoft YaHei', fontSize:12, color:C.gray, align:'center'
  });
  addBox(slide, 1.1, 2.55, 2.65, 1.15, '项目输入', C.lightBlue, [
    '机房：B23.1', '客户数据中心互联', '2 条 100G 专线'
  ]);
  addBox(slide, 5.32, 2.55, 2.65, 1.15, '核心目标', C.green, [
    '拓扑清晰', '安全可控', '自动切换'
  ]);
  addBox(slide, 9.55, 2.55, 2.65, 1.15, '推荐方向', C.orange, [
    'L3 互联', '双边界 + 双核心', '主备优先'
  ]);
  connect(slide, 3.8, 3.12, 5.3, 3.12);
  connect(slide, 7.98, 3.12, 9.52, 3.12);
  addBullets(slide, [
    '两条专线必须尽量做到物理路径隔离',
    '不建议大范围 L2 拉通，优先 L3 + BGP/BFD',
    '边界控制与核心业务网络分层，避免直接打入生产核心'
  ], { x: 1.05, y: 4.45, w: 11.2, h: 2.0, fontSize: 16 });
  addFooter(slide, 'SiowAI 方案草案 · 2026-04-18');
}

// Slide 2 Physical topology
{
  const slide = pptx.addSlide();
  slide.background = { color: 'FFFFFF' };
  addHeader(slide, '1. 物理拓扑建议', '客户数据中心 -> MMR -> B23.1 -> 边界/核心');
  addBox(slide, 0.7, 2.3, 2.2, 1.1, '客户数据中心', C.lightBlue, ['对端业务网络', '双 100G 出口']);
  addBox(slide, 3.55, 1.45, 2.0, 0.95, 'MMR-A', C.teal, ['专线 A 落地']);
  addBox(slide, 3.55, 3.4, 2.0, 0.95, 'MMR-B', C.teal, ['专线 B 落地']);
  addBox(slide, 6.25, 1.45, 2.0, 0.95, 'Edge-1', C.orange, ['边界设备 1', '100G']);
  addBox(slide, 6.25, 3.4, 2.0, 0.95, 'Edge-2', C.orange, ['边界设备 2', '100G']);
  addBox(slide, 9.2, 1.45, 1.75, 0.95, 'Core-1', C.green, ['核心/汇聚 1']);
  addBox(slide, 9.2, 3.4, 1.75, 0.95, 'Core-2', C.green, ['核心/汇聚 2']);
  addBox(slide, 11.45, 2.25, 1.15, 1.3, '业务区', C.yellow, ['服务器', '存储', '安全域']);
  connect(slide, 2.9, 2.75, 3.55, 1.92);
  connect(slide, 2.9, 2.95, 3.55, 3.87);
  connect(slide, 5.55, 1.92, 6.25, 1.92);
  connect(slide, 5.55, 3.87, 6.25, 3.87);
  connectPlain(slide, 7.25, 2.4, 7.25, 3.4, C.line, 'dash');
  connect(slide, 8.25, 1.92, 9.2, 1.92);
  connect(slide, 8.25, 1.92, 9.2, 3.87);
  connect(slide, 8.25, 3.87, 9.2, 1.92);
  connect(slide, 8.25, 3.87, 9.2, 3.87);
  connect(slide, 10.95, 1.92, 11.45, 2.65);
  connect(slide, 10.95, 3.87, 11.45, 3.15);
  slide.addText('建议两条专线从客户侧到 MMR 再到 B23.1 全程尽量做到物理隔离。', {
    x:0.75, y:5.45, w:12.0, h:0.3, fontFace:'Microsoft YaHei', fontSize:14, bold:true, color:C.navy
  });
  addBullets(slide, [
    'MMR 到 B23.1 最好继续使用两条独立光纤路径/桥架',
    'Edge-1 / Edge-2 分别接入双核心，避免单点',
    '边界设备建议与核心设备分角色部署，不直接把专线打到核心里'
  ], { x:0.8, y:5.8, w:12, h:1.1, fontSize:13 });
  addFooter(slide);
}

// Slide 3 logical architecture
{
  const slide = pptx.addSlide();
  slide.background = { color: 'FFFFFF' };
  addHeader(slide, '2. 推荐逻辑架构', '优先采用 L3 互联，边界与核心分层');
  addBox(slide, 0.8, 1.5, 2.3, 1.1, '客户 DC', C.lightBlue, ['L3 交付优先', '建议双 BGP 邻居']);
  addBox(slide, 3.6, 1.25, 2.2, 1.45, '边界接入层', C.orange, ['Edge-1 / Edge-2', 'BGP / BFD', 'VRF / ACL', '链路健康探测']);
  addBox(slide, 6.4, 1.25, 2.2, 1.45, '核心/汇聚层', C.green, ['Core-1 / Core-2', '承接业务网段', '路由汇聚', '策略下发']);
  addBox(slide, 9.25, 1.25, 2.6, 1.45, '安全与业务承载', C.yellow, ['客户互联 VRF', '关键流量进防火墙', '非关键流量走 ACL 边界控制']);
  connect(slide, 3.1, 2.0, 3.6, 2.0);
  connect(slide, 5.8, 2.0, 6.4, 2.0);
  connect(slide, 8.6, 2.0, 9.25, 2.0);
  addBox(slide, 1.2, 3.5, 3.25, 1.2, '推荐技术选型', C.teal, [
    '专线交付尽量采用 L3，而非大二层透传',
    '边界与核心之间可用动态路由或清晰静态路由',
    '客户互联业务建议单独 VRF / VLAN'
  ], { titleSize: 15, bodySize: 10 });
  addBox(slide, 4.95, 3.5, 3.25, 1.2, '为什么不优先大二层', C.red, [
    '广播域拉长，故障面扩大',
    '跨机房二层更难排障',
    '切换和安全边界更复杂'
  ], { titleSize: 15, bodySize: 10 });
  addBox(slide, 8.7, 3.5, 3.6, 1.2, '推荐第一期形态', C.green, [
    '双边界 + 双核心 + L3/BGP/BFD',
    '专线主备优先，后续再评估双活',
    '安全控制与转发性能分层处理'
  ], { titleSize: 15, bodySize: 10 });
  addFooter(slide);
}

// Slide 4 security
{
  const slide = pptx.addSlide();
  slide.background = { color: 'FFFFFF' };
  addHeader(slide, '3. 安全设计建议', '既要隔离，也要避免 100G 成为安全瓶颈');
  addBullets(slide, [
    '客户专线互联流量建议放入独立 VRF / 安全域，不直接混入生产核心网络。',
    '基础边界控制建议优先用路由策略 + ACL + 白名单，限制可达网段和端口。',
    '关键业务流量再进入防火墙或安全设备，不建议一开始就把全部 200G 流量做重型深度检查。',
    '管理面与业务面必须隔离，边界设备、核心设备、运维跳板机分权管理。',
    '如有更高安全要求，可评估 MACsec、流量镜像审计、IDS/IPS，但需核算吞吐瓶颈。'
  ], { x: 0.8, y: 1.45, w: 7.0, h: 4.9, fontSize: 16 });
  addBox(slide, 8.4, 1.55, 3.9, 1.0, '最低安全基线', C.green, [
    '专线独立 VRF', 'ACL 白名单', '管理面隔离'
  ], { titleSize: 16, bodySize: 11 });
  addBox(slide, 8.4, 2.85, 3.9, 1.0, '增强项', C.orange, [
    '关键业务流量进入防火墙', '流量审计 / 镜像', '异常检测'
  ], { titleSize: 16, bodySize: 11 });
  addBox(slide, 8.4, 4.15, 3.9, 1.05, '重点提醒', C.red, [
    '“全流量深度安全” 很可能拖垮 100G/200G 吞吐', '安全策略要和性能目标一起设计'
  ], { titleSize: 16, bodySize: 10 });
  addFooter(slide);
}

// Slide 5 redundancy
{
  const slide = pptx.addSlide();
  slide.background = { color: 'FFFFFF' };
  addHeader(slide, '4. 冗余与切换建议', '第一期建议主备优先，后续再评估双活');
  addBox(slide, 0.8, 1.55, 3.8, 1.7, '方案 A：双活', C.lightBlue, [
    '两条链路同时承载',
    '依靠 ECMP / BGP 策略分担流量',
    '优点：带宽利用率高',
    '缺点：设计与排障复杂度更高'
  ], { titleSize: 16, bodySize: 10 });
  addBox(slide, 4.8, 1.55, 3.8, 1.7, '方案 B：主备（第一期推荐）', C.green, [
    '专线 A 主用，专线 B 备份',
    '通过 LocalPref / AS Path / MED 控制优先级',
    '优点：更稳，更容易运维',
    '缺点：备链带宽平时闲置'
  ], { titleSize: 16, bodySize: 10 });
  addBox(slide, 8.8, 1.55, 3.8, 1.7, '故障探测与收敛', C.orange, [
    '建议 BGP + BFD',
    '边界与核心都要有明确的故障切换逻辑',
    '避免把“人工切换”作为唯一手段'
  ], { titleSize: 16, bodySize: 10 });
  addBullets(slide, [
    '如果客户侧网络能力成熟、双方运维也足够强，再考虑双活。',
    '如果这是第一期上线，主备模式通常更容易交付，也更适合安全与运维收口。',
    '无论双活还是主备，物理链路隔离和双设备承接都是前提。'
  ], { x: 0.9, y: 3.9, w: 11.8, h: 2.0, fontSize: 15 });
  addFooter(slide);
}

// Slide 6 devices and next steps
{
  const slide = pptx.addSlide();
  slide.background = { color: 'FFFFFF' };
  addHeader(slide, '5. 设备建议与下一步', '先锁架构，再锁型号');
  addBox(slide, 0.8, 1.35, 3.7, 1.4, '边界设备建议', C.orange, [
    '支持原生 100G',
    '支持 BGP / BFD / VRF / ACL',
    '建议采用两台独立设备承接专线'
  ], { titleSize: 16, bodySize: 11 });
  addBox(slide, 4.8, 1.35, 3.7, 1.4, '核心/汇聚建议', C.green, [
    '双核心或双汇聚',
    '具备高密 100G/40G/25G 承接能力',
    '与边界设备分角色部署'
  ], { titleSize: 16, bodySize: 11 });
  addBox(slide, 8.8, 1.35, 3.7, 1.4, '厂商建议', C.lightBlue, [
    '优先沿用现网主平台',
    'Cisco / Arista / Juniper / H3C / Huawei 均有可选型',
    '先按能力和运维体系筛选'
  ], { titleSize: 16, bodySize: 10 });
  addBullets(slide, [
    '推荐第一期：双 100G 专线 + 双边界 + 双核心 + L3/BGP/BFD + 主备切换。',
    '后续待确认：客户侧 L2/L3 交付方式、是否要求双活、是否必须链路加密、是否需防火墙全流量串接。',
    '实施顺序建议：先确认交付边界和安全要求，再做设备选型和详细低层设计。'
  ], { x: 0.85, y: 3.35, w: 11.9, h: 2.1, fontSize: 15 });
  addBox(slide, 0.95, 5.8, 11.8, 0.78, '一句话结论：第一期建议采用“L3 主备 + 双边界 + 双核心 + 专线独立安全域”的稳妥方案。', C.yellow, [], { titleSize: 18 });
  addFooter(slide);
}

pptx.writeFile({ fileName: '/home/ccpilot/.openclaw/workspace/deliverables/B23.1-机房专线接入与互联架构建议.pptx' });
