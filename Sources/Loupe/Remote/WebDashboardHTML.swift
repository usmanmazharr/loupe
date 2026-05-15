import Foundation

enum WebDashboardHTML {
    static let page = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Loupe</title>
<style>
:root {
  --bg: #0E0F13; --card: #16181D; --surface: #1B1E24; --hairline: #22252B;
  --ink: #F4F5F7; --fog: #9099A8; --mist: #666D78;
  --accent: #1B4DFF; --accent-soft: rgba(94,123,255,0.18);
  --success: #4FBE7A; --warning: #E0AC4A; --danger: #E07070; --critical: #C95757;
  --font: -apple-system, BlinkMacSystemFont, 'SF Pro', 'Segoe UI', Roboto, sans-serif;
  --mono: 'SF Mono', 'Fira Code', 'Cascadia Code', Menlo, Consolas, monospace;
}
* { margin:0; padding:0; box-sizing:border-box; }
body { background:var(--bg); color:var(--ink); font-family:var(--font); font-size:13px; overflow:hidden; height:100vh; display:flex; flex-direction:column; }
a { color:var(--accent); text-decoration:none; }
::-webkit-scrollbar { width:6px; }
::-webkit-scrollbar-track { background:transparent; }
::-webkit-scrollbar-thumb { background:var(--hairline); border-radius:3px; }

/* Header */
.header { display:flex; align-items:center; gap:12px; padding:12px 20px; border-bottom:1px solid var(--hairline); background:var(--card); flex-shrink:0; }
.logo { font-size:16px; font-weight:700; letter-spacing:-0.3px; }
.logo span { color:var(--accent); }
.conn-dot { width:8px; height:8px; border-radius:50%; background:var(--danger); flex-shrink:0; }
.conn-dot.on { background:var(--success); }
.conn-label { font-size:11px; color:var(--fog); }
.header-spacer { flex:1; }
.search-box { background:var(--surface); border:1px solid var(--hairline); border-radius:8px; padding:6px 10px; color:var(--ink); font-size:12px; width:260px; outline:none; font-family:var(--font); }
.search-box:focus { border-color:var(--accent); }

/* Tabs */
.tabs { display:flex; gap:0; border-bottom:1px solid var(--hairline); background:var(--card); flex-shrink:0; padding:0 16px; }
.tab { padding:10px 16px; font-size:12px; font-weight:600; color:var(--fog); cursor:pointer; border-bottom:2px solid transparent; transition:all .15s; letter-spacing:0.2px; }
.tab:hover { color:var(--ink); }
.tab.active { color:var(--accent); border-bottom-color:var(--accent); }
.tab .badge { display:inline-block; background:var(--accent-soft); color:var(--accent); font-size:10px; font-weight:700; padding:1px 6px; border-radius:10px; margin-left:6px; }

/* Panels */
.panels { flex:1; overflow:hidden; position:relative; }
.panel { display:none; height:100%; overflow-y:auto; }
.panel.active { display:flex; flex-direction:column; }

/* Network list */
.entry-list { flex:1; overflow-y:auto; }
.entry-row { display:flex; align-items:center; gap:10px; padding:10px 20px; border-bottom:1px solid var(--hairline); cursor:pointer; transition:background .1s; }
.entry-row:hover { background:var(--surface); }
.entry-row.selected { background:var(--accent-soft); }
.method-badge { font-family:var(--mono); font-size:10px; font-weight:700; letter-spacing:0.4px; padding:2px 6px; border-radius:6px; flex-shrink:0; min-width:48px; text-align:center; }
.status-badge { font-family:var(--mono); font-size:11px; font-weight:600; padding:2px 8px; border-radius:50px; flex-shrink:0; }
.entry-url { flex:1; font-family:var(--mono); font-size:11px; color:var(--ink); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.entry-host { color:var(--fog); }
.entry-duration { font-family:var(--mono); font-size:10px; color:var(--fog); flex-shrink:0; }
.entry-time { font-size:10px; color:var(--mist); flex-shrink:0; min-width:60px; text-align:right; }
.pin-icon { color:var(--warning); font-size:10px; flex-shrink:0; }

/* Detail panel */
.detail-overlay { display:none; position:absolute; top:0; right:0; bottom:0; width:55%; background:var(--card); border-left:1px solid var(--hairline); z-index:10; flex-direction:column; overflow:hidden; }
.detail-overlay.open { display:flex; }
.detail-header { display:flex; align-items:center; gap:10px; padding:12px 16px; border-bottom:1px solid var(--hairline); flex-shrink:0; }
.detail-close { background:none; border:none; color:var(--fog); cursor:pointer; font-size:18px; padding:2px 6px; }
.detail-close:hover { color:var(--ink); }
.detail-tabs { display:flex; gap:0; border-bottom:1px solid var(--hairline); padding:0 16px; flex-shrink:0; }
.detail-tab { padding:8px 12px; font-size:11px; font-weight:600; color:var(--fog); cursor:pointer; border-bottom:2px solid transparent; }
.detail-tab:hover { color:var(--ink); }
.detail-tab.active { color:var(--accent); border-bottom-color:var(--accent); }
.detail-body { flex:1; overflow-y:auto; padding:16px; }
.detail-section { margin-bottom:16px; }
.detail-section-title { font-size:10px; font-weight:700; color:var(--fog); letter-spacing:0.6px; text-transform:uppercase; margin-bottom:8px; }
.kv-table { width:100%; border-collapse:collapse; }
.kv-table td { padding:3px 0; font-family:var(--mono); font-size:11px; vertical-align:top; }
.kv-table td:first-child { color:var(--fog); width:35%; padding-right:12px; }
.kv-table td:last-child { color:var(--ink); word-break:break-all; }
pre.body-block { background:var(--surface); border-radius:8px; padding:12px; font-family:var(--mono); font-size:11px; color:var(--ink); overflow-x:auto; white-space:pre-wrap; word-break:break-all; max-height:400px; overflow-y:auto; }
.copy-btn { background:var(--surface); border:1px solid var(--hairline); color:var(--fog); font-size:10px; padding:3px 8px; border-radius:6px; cursor:pointer; font-family:var(--font); }
.copy-btn:hover { color:var(--ink); border-color:var(--fog); }

/* Detail search */
.detail-search { display:flex; align-items:center; gap:8px; padding:8px 16px; border-bottom:1px solid var(--hairline); flex-shrink:0; }
.detail-search input { background:var(--surface); border:1px solid var(--hairline); border-radius:6px; padding:5px 10px; color:var(--ink); font-size:11px; font-family:var(--mono); flex:1; outline:none; }
.detail-search input:focus { border-color:var(--accent); }
.match-badge { font-size:10px; font-weight:700; padding:2px 8px; border-radius:50px; flex-shrink:0; }

/* JSON tree */
.tree-section { margin-bottom:8px; background:var(--surface); border-radius:8px; overflow:hidden; }
.tree-section-header { display:flex; align-items:center; gap:8px; padding:8px 12px; cursor:pointer; user-select:none; }
.tree-section-header:hover { background:rgba(255,255,255,0.03); }
.tree-chevron { font-size:10px; color:var(--fog); width:12px; flex-shrink:0; transition:transform .15s; }
.tree-section-icon { font-size:12px; color:var(--accent); }
.tree-section-title { font-size:12px; font-weight:600; color:var(--ink); }
.tree-section-count { font-size:10px; color:var(--fog); }
.tree-section-match { font-size:9px; font-weight:700; color:#fff; background:var(--warning); padding:1px 6px; border-radius:50px; }
.tree-section-body { padding:4px 12px 8px 32px; }
.tree-kv { display:flex; gap:6px; padding:3px 0; font-family:var(--mono); font-size:11px; align-items:flex-start; border-bottom:1px solid var(--hairline); }
.tree-kv:last-child { border-bottom:none; }
.tree-kv-key { color:var(--accent); flex-shrink:0; }
.tree-kv-val { color:var(--fog); word-break:break-all; flex:1; }
.json-tree { font-family:var(--mono); font-size:11px; }
.json-node { padding:1px 0; }
.json-toggle { cursor:pointer; color:var(--fog); display:inline-block; width:14px; font-size:10px; user-select:none; }
.json-key { color:#C792EA; }
.json-str { color:#C3E88D; }
.json-num { color:#F78C6C; }
.json-bool { color:#FFCB6B; }
.json-null { color:#546E7A; }
.json-bracket { color:var(--fog); }
.json-match-badge { font-size:9px; font-weight:700; color:#fff; background:var(--warning); padding:0 5px; border-radius:50px; margin-left:4px; }
mark { background:#E0AC4A88; color:#fff; border-radius:2px; padding:0 1px; }

/* Console */
.log-row { display:flex; gap:8px; padding:6px 20px; border-bottom:1px solid var(--hairline); font-family:var(--mono); font-size:11px; align-items:flex-start; }
.log-level { font-size:9px; font-weight:700; padding:1px 6px; border-radius:4px; flex-shrink:0; text-transform:uppercase; min-width:50px; text-align:center; }
.log-time { color:var(--mist); font-size:10px; flex-shrink:0; min-width:70px; }
.log-msg { color:var(--ink); flex:1; white-space:pre-wrap; word-break:break-all; }
.log-sub { color:var(--mist); font-size:10px; flex-shrink:0; }
.level-pills { display:flex; gap:4px; padding:8px 20px; border-bottom:1px solid var(--hairline); flex-shrink:0; flex-wrap:wrap; }
.level-pill { font-size:10px; font-weight:600; padding:3px 10px; border-radius:50px; cursor:pointer; border:1px solid var(--hairline); color:var(--fog); background:transparent; font-family:var(--font); }
.level-pill.active { border-color:var(--accent); color:var(--accent); background:var(--accent-soft); }

/* Analytics */
.event-row { display:flex; gap:10px; padding:8px 20px; border-bottom:1px solid var(--hairline); align-items:flex-start; }
.event-provider { font-size:10px; font-weight:700; padding:2px 8px; border-radius:6px; flex-shrink:0; }
.event-name { font-weight:600; font-size:12px; color:var(--ink); }
.event-screen { font-size:10px; color:var(--mist); }
.event-props { font-family:var(--mono); font-size:10px; color:var(--fog); margin-top:2px; }
.event-time { font-size:10px; color:var(--mist); flex-shrink:0; min-width:70px; text-align:right; }

/* Insights */
.insights-grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(200px, 1fr)); gap:12px; padding:20px; }
.stat-tile { background:var(--card); border:1px solid var(--hairline); border-radius:10px; padding:16px; }
.stat-value { font-size:28px; font-weight:700; letter-spacing:-0.5px; }
.stat-label { font-size:11px; color:var(--fog); margin-top:4px; }
.insights-section { padding:0 20px 20px; }
.insights-section-title { font-size:11px; font-weight:700; color:var(--fog); letter-spacing:0.6px; text-transform:uppercase; margin-bottom:8px; }
.insights-list { background:var(--card); border:1px solid var(--hairline); border-radius:10px; overflow:hidden; }
.insights-item { display:flex; align-items:center; gap:10px; padding:8px 12px; border-bottom:1px solid var(--hairline); font-size:12px; }
.insights-item:last-child { border-bottom:none; }
.bar-bg { flex:1; height:6px; background:var(--surface); border-radius:3px; overflow:hidden; }
.bar-fill { height:100%; border-radius:3px; }

/* Empty state */
.empty { display:flex; align-items:center; justify-content:center; height:100%; color:var(--mist); font-size:14px; flex-direction:column; gap:8px; }
.empty-icon { font-size:32px; opacity:0.4; }

/* Status bar */
.status-bar { display:flex; align-items:center; gap:12px; padding:6px 20px; border-top:1px solid var(--hairline); background:var(--card); flex-shrink:0; font-size:10px; color:var(--mist); }
.status-bar .sep { color:var(--hairline); }

/* Filter bar */
.filter-bar { display:flex; gap:4px; padding:8px 20px; border-bottom:1px solid var(--hairline); flex-shrink:0; flex-wrap:wrap; align-items:center; }
.method-pill { font-size:10px; font-weight:600; padding:3px 10px; border-radius:50px; cursor:pointer; border:1px solid var(--hairline); color:var(--fog); background:transparent; font-family:var(--mono); }
.method-pill.active { border-color:var(--accent); color:var(--accent); background:var(--accent-soft); }
.filter-label { font-size:10px; color:var(--mist); font-weight:600; margin-right:4px; }

@media (max-width: 768px) {
  .detail-overlay { width:100%; }
  .search-box { width:140px; }
  .entry-host { display:none; }
}
</style>
</head>
<body>

<div class="header">
  <div class="logo">Lou<span>pe</span></div>
  <div class="conn-dot" id="connDot"></div>
  <div class="conn-label" id="connLabel">Connecting…</div>
  <div class="header-spacer"></div>
  <input type="text" class="search-box" id="searchBox" placeholder="Search requests, logs, events…">
</div>

<div class="tabs" id="tabBar">
  <div class="tab active" data-tab="network">NETWORK <span class="badge" id="networkCount">0</span></div>
  <div class="tab" data-tab="console">CONSOLE <span class="badge" id="consoleCount">0</span></div>
  <div class="tab" data-tab="analytics">ANALYTICS <span class="badge" id="analyticsCount">0</span></div>
  <div class="tab" data-tab="insights">INSIGHTS</div>
</div>

<!-- NETWORK PANEL -->
<div class="panels">
<div class="panel active" id="panelNetwork">
  <div class="filter-bar" id="methodFilter">
    <span class="filter-label">METHOD</span>
    <div class="method-pill active" data-method="ALL">ALL</div>
    <div class="method-pill" data-method="GET">GET</div>
    <div class="method-pill" data-method="POST">POST</div>
    <div class="method-pill" data-method="PUT">PUT</div>
    <div class="method-pill" data-method="PATCH">PATCH</div>
    <div class="method-pill" data-method="DELETE">DELETE</div>
  </div>
  <div class="entry-list" id="entryList"></div>
  <div class="detail-overlay" id="detailPanel">
    <div class="detail-header">
      <button class="detail-close" id="detailClose">&times;</button>
      <span class="method-badge" id="detailMethod"></span>
      <span class="status-badge" id="detailStatus"></span>
      <span style="flex:1;font-family:var(--mono);font-size:11px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" id="detailUrl"></span>
      <button class="copy-btn" id="copyCurlBtn">cURL</button>
    </div>
    <div class="detail-tabs" id="detailTabs">
      <div class="detail-tab active" data-dtab="overview">Overview</div>
      <div class="detail-tab" data-dtab="request">Request</div>
      <div class="detail-tab" data-dtab="response">Response</div>
    </div>
    <div class="detail-search" id="detailSearchBar" style="display:none">
      <span style="color:var(--fog);font-size:12px">&#128269;</span>
      <input type="text" id="detailSearchInput" placeholder="Search keys, values…">
      <span class="match-badge" id="detailMatchBadge" style="display:none"></span>
    </div>
    <div class="detail-body" id="detailBody"></div>
  </div>
</div>

<!-- CONSOLE PANEL -->
<div class="panel" id="panelConsole">
  <div class="level-pills" id="levelFilter"></div>
  <div class="entry-list" id="logList"></div>
</div>

<!-- ANALYTICS PANEL -->
<div class="panel" id="panelAnalytics">
  <div class="filter-bar" id="providerFilter">
    <span class="filter-label">PROVIDER</span>
    <div class="method-pill active" data-provider="ALL">ALL</div>
  </div>
  <div class="entry-list" id="eventList"></div>
</div>

<!-- INSIGHTS PANEL -->
<div class="panel" id="panelInsights">
  <div id="insightsContent" style="overflow-y:auto;flex:1"></div>
</div>
</div>

<div class="status-bar">
  <span id="statusEntries">0 requests</span>
  <span class="sep">|</span>
  <span id="statusLogs">0 logs</span>
  <span class="sep">|</span>
  <span id="statusEvents">0 events</span>
  <span class="sep">|</span>
  <span id="statusWs">disconnected</span>
</div>

<script>
// ── State ──
let entries = [];
let logs = [];
let events = [];
let selectedEntry = null;
let activeTab = 'network';
let activeDetailTab = 'overview';
let searchQuery = '';
let detailSearch = '';
let methodFilter = 'ALL';
let levelFilters = new Set();
let providerFilter = 'ALL';
let pollTimer = null;
let connected = false;
let collapsedSections = new Set();

// ── Polling ──
async function poll() {
  try {
    const [rEntries, rLogs, rEvents] = await Promise.all([
      fetch('/api/entries').then(r => r.json()),
      fetch('/api/logs').then(r => r.json()),
      fetch('/api/events').then(r => r.json())
    ]);
    rEntries.forEach(e => upsertEntry(e));
    rLogs.forEach(l => upsertLog(l));
    rEvents.forEach(ev => upsertEvent(ev));
    updateCounts();
    if (!connected) {
      connected = true;
      document.getElementById('connDot').classList.add('on');
      document.getElementById('connLabel').textContent = 'Connected';
      document.getElementById('statusWs').textContent = 'polling';
    }
  } catch {
    connected = false;
    document.getElementById('connDot').classList.remove('on');
    document.getElementById('connLabel').textContent = 'Reconnecting…';
    document.getElementById('statusWs').textContent = 'disconnected';
  }
}

function connect() {
  poll();
  pollTimer = setInterval(poll, 1500);
}

function upsertEntry(e) {
  const idx = entries.findIndex(x => x.id === e.id);
  if (idx >= 0) entries[idx] = e; else entries.unshift(e);
  if (selectedEntry && selectedEntry.id === e.id) {
    selectedEntry = e;
    renderDetail();
  }
  renderNetwork();
  renderInsights();
}

function upsertLog(l) {
  if (!logs.find(x => x.id === l.id)) { logs.unshift(l); renderConsole(); }
}

function upsertEvent(ev) {
  if (!events.find(x => x.id === ev.id)) { events.unshift(ev); renderAnalytics(); }
}

// ── Tabs ──
document.getElementById('tabBar').addEventListener('click', (e) => {
  const tab = e.target.closest('.tab');
  if (!tab) return;
  activeTab = tab.dataset.tab;
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  tab.classList.add('active');
  document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
  document.getElementById('panel' + activeTab.charAt(0).toUpperCase() + activeTab.slice(1)).classList.add('active');
});

// ── Search ──
document.getElementById('searchBox').addEventListener('input', (e) => {
  searchQuery = e.target.value.toLowerCase();
  renderNetwork(); renderConsole(); renderAnalytics();
});

// ── Method filter ──
document.getElementById('methodFilter').addEventListener('click', (e) => {
  const pill = e.target.closest('.method-pill');
  if (!pill) return;
  methodFilter = pill.dataset.method;
  document.querySelectorAll('#methodFilter .method-pill').forEach(p => p.classList.remove('active'));
  pill.classList.add('active');
  renderNetwork();
});

// ── Provider filter ──
document.getElementById('providerFilter').addEventListener('click', (e) => {
  const pill = e.target.closest('.method-pill');
  if (!pill) return;
  providerFilter = pill.dataset.provider;
  document.querySelectorAll('#providerFilter .method-pill').forEach(p => p.classList.remove('active'));
  pill.classList.add('active');
  renderAnalytics();
});

// ── Detail panel ──
document.getElementById('detailClose').addEventListener('click', () => {
  selectedEntry = null;
  document.getElementById('detailPanel').classList.remove('open');
  document.querySelectorAll('.entry-row').forEach(r => r.classList.remove('selected'));
});

document.getElementById('detailTabs').addEventListener('click', (e) => {
  const tab = e.target.closest('.detail-tab');
  if (!tab) return;
  activeDetailTab = tab.dataset.dtab;
  detailSearch = '';
  document.getElementById('detailSearchInput').value = '';
  collapsedSections.clear();
  document.querySelectorAll('.detail-tab').forEach(t => t.classList.remove('active'));
  tab.classList.add('active');
  const searchBar = document.getElementById('detailSearchBar');
  searchBar.style.display = (activeDetailTab === 'request' || activeDetailTab === 'response') ? 'flex' : 'none';
  renderDetail();
});

document.getElementById('detailSearchInput').addEventListener('input', (e) => {
  detailSearch = e.target.value.toLowerCase();
  renderDetail();
});

// ── Helpers ──
function methodColorCSS(m) {
  const map = {GET:'#1B4DFF',POST:'#4FBE7A',PUT:'#E0AC4A',PATCH:'#C97A00',DELETE:'#E07070',HEAD:'#5B4DBE',OPTIONS:'#7A5BBE'};
  return map[m] || '#9099A8';
}
function statusColorCSS(code) {
  if (!code) return '#9099A8';
  if (code >= 200 && code < 300) return '#4FBE7A';
  if (code >= 300 && code < 400) return '#E0AC4A';
  if (code >= 400 && code < 500) return '#E07070';
  if (code >= 500) return '#C95757';
  return '#9099A8';
}
function levelColorCSS(level) {
  const map = {trace:'#666D78',debug:'#9099A8',info:'#1B4DFF',notice:'#4FBE7A',warning:'#E0AC4A',error:'#E07070',fault:'#C95757'};
  return map[level] || '#9099A8';
}
function providerColor(p) {
  const map = {Mixpanel:'#7856FF',Firebase:'#FFA000',Adjust:'#008AFF',Insider:'#E91E63',Segment:'#52BD94',Custom:'#9099A8'};
  return map[p] || '#9099A8';
}
function fmtTime(iso) {
  try { const d = new Date(iso); return d.toLocaleTimeString([], {hour:'2-digit',minute:'2-digit',second:'2-digit'}); }
  catch { return ''; }
}
function fmtDuration(timing) {
  if (!timing) return '';
  const start = new Date(timing.startDate);
  const end = timing.endDate ? new Date(timing.endDate) : null;
  if (!end) return '…';
  const ms = end - start;
  return ms < 1000 ? ms + ' ms' : (ms/1000).toFixed(2) + ' s';
}
function fmtBytes(n) {
  if (!n || n === 0) return '0 B';
  if (n < 1024) return n + ' B';
  if (n < 1048576) return (n/1024).toFixed(1) + ' KB';
  return (n/1048576).toFixed(1) + ' MB';
}
function prettyJSON(data) {
  if (!data) return '';
  try {
    const bytes = atob(data);
    const str = new TextDecoder().decode(Uint8Array.from(bytes, c => c.charCodeAt(0)));
    const obj = JSON.parse(str);
    return JSON.stringify(obj, null, 2);
  } catch {
    try {
      const bytes = atob(data);
      return new TextDecoder().decode(Uint8Array.from(bytes, c => c.charCodeAt(0)));
    } catch { return data; }
  }
}
function escapeHTML(s) { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; }
function copyText(t) { navigator.clipboard.writeText(t).then(() => {}); }

// ── Render: Network ──
function renderNetwork() {
  const list = document.getElementById('entryList');
  let filtered = entries;
  if (methodFilter !== 'ALL') filtered = filtered.filter(e => e.method === methodFilter);
  if (searchQuery) filtered = filtered.filter(e =>
    (e.url||'').toLowerCase().includes(searchQuery) ||
    (e.method||'').toLowerCase().includes(searchQuery) ||
    String(e.statusCode||'').includes(searchQuery)
  );
  if (filtered.length === 0) {
    list.innerHTML = '<div class="empty"><div class="empty-icon">📡</div>No requests captured yet</div>';
    return;
  }
  list.innerHTML = filtered.map(e => {
    const mc = methodColorCSS(e.method);
    const sc = statusColorCSS(e.statusCode);
    const sel = selectedEntry && selectedEntry.id === e.id ? ' selected' : '';
    const pin = e.isPinned ? '<span class="pin-icon">★</span>' : '';
    let urlPath = '';
    try { const u = new URL(e.url); urlPath = '<span class="entry-host">' + escapeHTML(u.host) + '</span>' + escapeHTML(u.pathname + u.search); }
    catch { urlPath = escapeHTML(e.url || ''); }
    return '<div class="entry-row' + sel + '" data-id="' + e.id + '">' +
      pin +
      '<span class="method-badge" style="color:' + mc + ';background:' + mc + '20">' + escapeHTML(e.method) + '</span>' +
      (e.statusCode ? '<span class="status-badge" style="color:' + sc + ';background:' + sc + '1a">' + e.statusCode + '</span>' : '<span class="status-badge" style="color:#9099A8;background:#9099A81a">…</span>') +
      '<span class="entry-url">' + urlPath + '</span>' +
      '<span class="entry-duration">' + fmtDuration(e.timing) + '</span>' +
      '<span class="entry-time">' + fmtTime(e.timing?.startDate) + '</span>' +
    '</div>';
  }).join('');

  list.querySelectorAll('.entry-row').forEach(row => {
    row.addEventListener('click', () => {
      const id = row.dataset.id;
      selectedEntry = entries.find(e => e.id === id);
      document.querySelectorAll('.entry-row').forEach(r => r.classList.remove('selected'));
      row.classList.add('selected');
      renderDetail();
      document.getElementById('detailPanel').classList.add('open');
    });
  });
}

// ── Render: Detail ──
function renderDetail() {
  if (!selectedEntry) return;
  const e = selectedEntry;
  const mc = methodColorCSS(e.method);
  const sc = statusColorCSS(e.statusCode);
  document.getElementById('detailMethod').style.color = mc;
  document.getElementById('detailMethod').style.background = mc + '20';
  document.getElementById('detailMethod').textContent = e.method;
  document.getElementById('detailStatus').style.color = sc;
  document.getElementById('detailStatus').style.background = sc + '1a';
  document.getElementById('detailStatus').textContent = e.statusCode || '…';
  document.getElementById('detailUrl').textContent = e.url || '';

  const body = document.getElementById('detailBody');
  switch (activeDetailTab) {
    case 'overview': body.innerHTML = renderOverview(e); break;
    case 'request':  body.innerHTML = renderRequestTree(e); break;
    case 'response': body.innerHTML = renderResponseTree(e); break;
  }
  setupTreeToggles();
  setupCopyBtns();
  updateMatchBadge();
  const curlBtn = document.getElementById('copyCurlBtn');
  if (curlBtn) curlBtn.onclick = () => copyText(buildCurl(e));
}

function updateMatchBadge() {
  const badge = document.getElementById('detailMatchBadge');
  if (!detailSearch) { badge.style.display = 'none'; return; }
  const count = countAllMatches();
  badge.style.display = 'inline-block';
  badge.textContent = count + ' match' + (count === 1 ? '' : 'es');
  badge.style.background = count > 0 ? 'var(--warning)' : 'var(--mist)';
  badge.style.color = '#fff';
}

function countAllMatches() {
  if (!selectedEntry || !detailSearch) return 0;
  const e = selectedEntry;
  let c = 0;
  if (activeDetailTab === 'request') {
    c += countStr(e.url, detailSearch);
    c += countStr(e.method, detailSearch);
    c += countKV(e.requestHeaders, detailSearch);
    c += countKV(e.queryParameters, detailSearch);
    c += countBodyMatches(e.requestBody, detailSearch);
  } else {
    c += countStr(e.url, detailSearch);
    if (e.statusCode) c += countStr(String(e.statusCode), detailSearch);
    c += countKV(e.responseHeaders, detailSearch);
    c += countBodyMatches(e.responseBody, detailSearch);
  }
  return c;
}

function countStr(s, term) { if (!s) return 0; let c=0,i=s.toLowerCase().indexOf(term); while(i>=0){c++;i=s.toLowerCase().indexOf(term,i+1);} return c; }
function countKV(obj, term) { if (!obj) return 0; let c=0; for (const [k,v] of Object.entries(obj)){c+=countStr(k,term);c+=countStr(v,term);} return c; }
function countBodyMatches(data, term) {
  const text = prettyJSON(data);
  if (!text) return 0;
  return countStr(text, term);
}

function highlightText(s) {
  if (!detailSearch || !s) return escapeHTML(s||'');
  const esc = escapeHTML(s);
  const lower = esc.toLowerCase();
  const term = escapeHTML(detailSearch);
  let result = '', i = 0;
  while (i < esc.length) {
    const idx = lower.indexOf(term, i);
    if (idx < 0) { result += esc.slice(i); break; }
    result += esc.slice(i, idx) + '<mark>' + esc.slice(idx, idx + term.length) + '</mark>';
    i = idx + term.length;
  }
  return result;
}

function buildCurl(e) {
  let cmd = "curl -X " + e.method;
  if (e.requestHeaders) { for (const [k,v] of Object.entries(e.requestHeaders)) { cmd += " -H '" + k + ": " + v + "'"; } }
  if (e.requestBody) { try { const b = atob(e.requestBody); cmd += " -d '" + b + "'"; } catch {} }
  cmd += " '" + e.url + "'";
  return cmd;
}

// ── Tree sections ──
function treeSection(id, icon, title, count, matchCount, bodyHTML) {
  const collapsed = collapsedSections.has(id);
  const chevron = collapsed ? '&#9654;' : '&#9660;';
  let header = '<div class="tree-section"><div class="tree-section-header" data-section="' + id + '">' +
    '<span class="tree-chevron">' + chevron + '</span>' +
    '<span class="tree-section-icon">' + icon + '</span>' +
    '<span class="tree-section-title">' + escapeHTML(title) + '</span>';
  if (count !== null) header += '<span class="tree-section-count">(' + count + ')</span>';
  if (matchCount > 0) header += '<span class="tree-section-match">' + matchCount + '</span>';
  header += '</div>';
  if (!collapsed) header += '<div class="tree-section-body">' + bodyHTML + '</div>';
  header += '</div>';
  return header;
}

function kvTreeHTML(obj) {
  if (!obj || Object.keys(obj).length === 0) return '<span style="color:var(--mist);font-size:11px">(empty)</span>';
  return Object.entries(obj).sort((a,b)=>a[0].localeCompare(b[0])).map(([k,v]) =>
    '<div class="tree-kv"><span class="tree-kv-key">' + highlightText(k) + ':</span><span class="tree-kv-val">' + highlightText(v) + '</span></div>'
  ).join('');
}

function bodyTreeHTML(data) {
  const text = prettyJSON(data);
  if (!text) return '<span style="color:var(--mist);font-size:11px">(empty)</span>';
  try {
    const obj = JSON.parse(text);
    return '<div class="json-tree">' + jsonNodeHTML(obj, null, true) + '</div>';
  } catch {
    return '<pre class="body-block">' + highlightText(text) + '</pre>';
  }
}

function jsonNodeHTML(val, key, expanded) {
  const keyStr = key !== null ? '<span class="json-key">' + highlightText('"'+key+'"') + '</span>: ' : '';
  if (val === null) return '<div class="json-node">' + keyStr + '<span class="json-null">null</span></div>';
  if (typeof val === 'boolean') return '<div class="json-node">' + keyStr + '<span class="json-bool">' + val + '</span></div>';
  if (typeof val === 'number') return '<div class="json-node">' + keyStr + '<span class="json-num">' + highlightText(String(val)) + '</span></div>';
  if (typeof val === 'string') return '<div class="json-node">' + keyStr + '<span class="json-str">' + highlightText('"'+val.substring(0,200)+(val.length>200?'…':'')+'"') + '</span></div>';
  if (Array.isArray(val)) {
    const id = 'jtree_' + Math.random().toString(36).substr(2,8);
    const mc = detailSearch ? countJSONMatches(val) : 0;
    const badge = mc > 0 ? '<span class="json-match-badge">' + mc + '</span>' : '';
    const shouldExpand = expanded || (detailSearch && mc > 0);
    let html = '<div class="json-node">' + '<span class="json-toggle" data-tree="' + id + '">' + (shouldExpand?'&#9660;':'&#9654;') + '</span>' + keyStr + '<span class="json-bracket">[</span> <span style="color:var(--fog);font-size:10px">' + val.length + ' items</span>' + badge;
    html += '<div id="' + id + '" style="padding-left:16px;' + (shouldExpand?'':'display:none') + '">';
    val.forEach((item, i) => { html += jsonNodeHTML(item, '[' + i + ']', false); });
    html += '</div><span class="json-bracket">]</span></div>';
    return html;
  }
  if (typeof val === 'object') {
    const id = 'jtree_' + Math.random().toString(36).substr(2,8);
    const keys = Object.keys(val);
    const mc = detailSearch ? countJSONMatches(val) : 0;
    const badge = mc > 0 ? '<span class="json-match-badge">' + mc + '</span>' : '';
    const shouldExpand = expanded || (detailSearch && mc > 0);
    let html = '<div class="json-node">' + '<span class="json-toggle" data-tree="' + id + '">' + (shouldExpand?'&#9660;':'&#9654;') + '</span>' + keyStr + '<span class="json-bracket">{</span> <span style="color:var(--fog);font-size:10px">' + keys.length + ' fields</span>' + badge;
    html += '<div id="' + id + '" style="padding-left:16px;' + (shouldExpand?'':'display:none') + '">';
    keys.sort().forEach(k => { html += jsonNodeHTML(val[k], k, false); });
    html += '</div><span class="json-bracket">}</span></div>';
    return html;
  }
  return '<div class="json-node">' + keyStr + escapeHTML(String(val)) + '</div>';
}

function countJSONMatches(val) {
  if (!detailSearch) return 0;
  const str = JSON.stringify(val);
  return countStr(str, detailSearch);
}

function setupTreeToggles() {
  document.querySelectorAll('.tree-section-header').forEach(h => {
    h.addEventListener('click', () => {
      const sid = h.dataset.section;
      if (collapsedSections.has(sid)) collapsedSections.delete(sid); else collapsedSections.add(sid);
      renderDetail();
    });
  });
  document.querySelectorAll('.json-toggle').forEach(t => {
    t.addEventListener('click', (ev) => {
      ev.stopPropagation();
      const target = document.getElementById(t.dataset.tree);
      if (!target) return;
      const visible = target.style.display !== 'none';
      target.style.display = visible ? 'none' : 'block';
      t.innerHTML = visible ? '&#9654;' : '&#9660;';
    });
  });
}

function setupCopyBtns() {
  document.querySelectorAll('[data-copy]').forEach(btn => {
    btn.addEventListener('click', () => copyText(btn.dataset.copy));
  });
}

// ── Render: Request tree ──
function renderRequestTree(e) {
  let html = '';
  html += treeSection('url', '&#128279;', 'URL', null, detailSearch ? countStr(e.url,detailSearch) : 0,
    '<div style="font-family:var(--mono);font-size:11px;word-break:break-all">' + highlightText(e.url) + '</div>');
  html += treeSection('method', '&#8593;', 'Method', null, detailSearch ? countStr(e.method,detailSearch) : 0,
    '<div style="font-family:var(--mono);font-size:11px">' + highlightText(e.method) + '</div>');
  const reqH = e.requestHeaders || {};
  html += treeSection('headers', '&#9776;', 'Headers', Object.keys(reqH).length, detailSearch ? countKV(reqH,detailSearch) : 0, kvTreeHTML(reqH));
  const qp = e.queryParameters || {};
  if (Object.keys(qp).length > 0) {
    html += treeSection('query', '?', 'Query Parameters', Object.keys(qp).length, detailSearch ? countKV(qp,detailSearch) : 0, kvTreeHTML(qp));
  }
  html += treeSection('body', '&#123;&#125;', 'Body', null, detailSearch ? countBodyMatches(e.requestBody,detailSearch) : 0, bodyTreeHTML(e.requestBody));
  return html;
}

// ── Render: Response tree ──
function renderResponseTree(e) {
  let html = '';
  html += treeSection('url', '&#128279;', 'URL', null, detailSearch ? countStr(e.url,detailSearch) : 0,
    '<div style="font-family:var(--mono);font-size:11px;word-break:break-all">' + highlightText(e.url) + '</div>');
  if (e.statusCode) {
    const sc = statusColorCSS(e.statusCode);
    html += treeSection('status', '#', 'Status', null, detailSearch ? countStr(String(e.statusCode),detailSearch) : 0,
      '<span style="color:'+sc+';font-family:var(--mono);font-weight:600">' + highlightText(String(e.statusCode)) + '</span> ' + highlightText(httpStatusText(e.statusCode)));
  }
  const resH = e.responseHeaders || {};
  html += treeSection('headers', '&#9776;', 'Headers', Object.keys(resH).length, detailSearch ? countKV(resH,detailSearch) : 0, kvTreeHTML(resH));
  html += treeSection('body', '&#123;&#125;', 'Body', null, detailSearch ? countBodyMatches(e.responseBody,detailSearch) : 0, bodyTreeHTML(e.responseBody));
  return html;
}

function httpStatusText(code) {
  const map = {200:'OK',201:'Created',204:'No Content',301:'Moved',302:'Found',304:'Not Modified',400:'Bad Request',401:'Unauthorized',403:'Forbidden',404:'Not Found',405:'Method Not Allowed',408:'Timeout',422:'Unprocessable',429:'Too Many Requests',500:'Internal Server Error',502:'Bad Gateway',503:'Service Unavailable',504:'Gateway Timeout'};
  return map[code] || '';
}

// ── Overview ──
function renderOverview(e) {
  let html = '<div class="detail-section"><div class="detail-section-title">General</div><table class="kv-table">';
  html += kvRow('URL', e.url);
  html += kvRow('Method', e.method);
  html += kvRow('Status', e.statusCode ? String(e.statusCode) : 'Pending');
  html += kvRow('Duration', fmtDuration(e.timing));
  html += kvRow('Response Size', fmtBytes(e.responseSize));
  if (e.error) html += kvRow('Error', e.error.localizedDescription);
  html += '</table></div>';
  if (e.timing) {
    html += '<div class="detail-section"><div class="detail-section-title">Timing</div><table class="kv-table">';
    html += kvRow('Started', fmtTime(e.timing.startDate));
    if (e.timing.endDate) html += kvRow('Completed', fmtTime(e.timing.endDate));
    html += '</table></div>';
  }
  if (Object.keys(e.queryParameters || {}).length > 0) {
    html += '<div class="detail-section"><div class="detail-section-title">Query Parameters</div><table class="kv-table">';
    for (const [k, v] of Object.entries(e.queryParameters)) { html += kvRow(k, v); }
    html += '</table></div>';
  }
  return html;
}

function kvRow(k, v) {
  return '<tr><td>' + escapeHTML(k) + '</td><td>' + escapeHTML(v || '') + '</td></tr>';
}

// ── Render: Console ──
function renderConsole() {
  const levels = ['trace','debug','info','notice','warning','error','fault'];
  const filterDiv = document.getElementById('levelFilter');
  if (filterDiv.children.length === 0) {
    filterDiv.innerHTML = levels.map(l => {
      const c = levelColorCSS(l);
      return '<div class="level-pill" data-level="' + l + '" style="--lc:' + c + '">' + l.toUpperCase() + '</div>';
    }).join('');
    filterDiv.addEventListener('click', (e) => {
      const pill = e.target.closest('.level-pill');
      if (!pill) return;
      const lv = pill.dataset.level;
      if (levelFilters.has(lv)) { levelFilters.delete(lv); pill.classList.remove('active'); }
      else { levelFilters.add(lv); pill.classList.add('active'); }
      renderConsole();
    });
  }

  const list = document.getElementById('logList');
  let filtered = logs;
  if (levelFilters.size > 0) filtered = filtered.filter(l => levelFilters.has(l.level));
  if (searchQuery) filtered = filtered.filter(l => l.message.toLowerCase().includes(searchQuery) || l.subsystem.toLowerCase().includes(searchQuery));

  if (filtered.length === 0) {
    list.innerHTML = '<div class="empty"><div class="empty-icon">🖥️</div>No console logs yet</div>';
    return;
  }
  list.innerHTML = filtered.map(l => {
    const c = levelColorCSS(l.level);
    return '<div class="log-row">' +
      '<span class="log-time">' + fmtTime(l.timestamp) + '</span>' +
      '<span class="log-level" style="color:' + c + ';background:' + c + '1a">' + l.level + '</span>' +
      (l.subsystem ? '<span class="log-sub">' + escapeHTML(l.subsystem) + '</span>' : '') +
      '<span class="log-msg">' + escapeHTML(l.message) + '</span>' +
    '</div>';
  }).join('');
}

// ── Render: Analytics ──
function renderAnalytics() {
  const providers = [...new Set(events.map(e => e.provider))];
  const filterDiv = document.getElementById('providerFilter');
  const existing = new Set([...filterDiv.querySelectorAll('.method-pill')].map(p => p.dataset.provider));
  providers.forEach(p => {
    if (!existing.has(p)) {
      const pill = document.createElement('div');
      pill.className = 'method-pill';
      pill.dataset.provider = p;
      pill.textContent = p;
      filterDiv.appendChild(pill);
    }
  });

  const list = document.getElementById('eventList');
  let filtered = events;
  if (providerFilter !== 'ALL') filtered = filtered.filter(e => e.provider === providerFilter);
  if (searchQuery) filtered = filtered.filter(e => e.name.toLowerCase().includes(searchQuery) || (e.screen||'').toLowerCase().includes(searchQuery) || e.provider.toLowerCase().includes(searchQuery));

  if (filtered.length === 0) {
    list.innerHTML = '<div class="empty"><div class="empty-icon">📊</div>No analytics events yet</div>';
    return;
  }
  list.innerHTML = filtered.map(ev => {
    const pc = providerColor(ev.provider);
    return '<div class="event-row">' +
      '<span class="event-time">' + fmtTime(ev.timestamp) + '</span>' +
      '<span class="event-provider" style="color:' + pc + ';background:' + pc + '1a">' + escapeHTML(ev.provider) + '</span>' +
      '<div style="flex:1"><div class="event-name">' + escapeHTML(ev.name) + '</div>' +
      (ev.screen ? '<div class="event-screen">' + escapeHTML(ev.screen) + '</div>' : '') +
      (ev.properties && Object.keys(ev.properties).length > 0 ? '<div class="event-props">' + escapeHTML(Object.entries(ev.properties).map(([k,v])=>k+'='+v).join(' · ')) + '</div>' : '') +
      '</div></div>';
  }).join('');
}

// ── Render: Insights ──
function renderInsights() {
  const content = document.getElementById('insightsContent');
  const total = entries.length;
  const completed = entries.filter(e => e.status === 'completed');
  const failed = entries.filter(e => e.status === 'failed' || (e.statusCode && e.statusCode >= 400));
  const avgDuration = completed.length > 0 ? completed.reduce((s,e) => {
    if (!e.timing?.endDate || !e.timing?.startDate) return s;
    return s + (new Date(e.timing.endDate) - new Date(e.timing.startDate));
  }, 0) / completed.length : 0;
  const totalSize = entries.reduce((s,e) => s + (e.responseSize || 0), 0);

  let html = '<div class="insights-grid">';
  html += statTile(total, 'Total Requests', 'var(--accent)');
  html += statTile(completed.length, 'Completed', 'var(--success)');
  html += statTile(failed.length, 'Failed / 4xx+', 'var(--danger)');
  html += statTile(avgDuration < 1000 ? Math.round(avgDuration) + ' ms' : (avgDuration/1000).toFixed(1) + ' s', 'Avg Duration', 'var(--warning)');
  html += statTile(fmtBytes(totalSize), 'Total Downloaded', 'var(--fog)');
  html += statTile(logs.length, 'Console Logs', 'var(--accent)');
  html += statTile(events.length, 'Analytics Events', 'var(--success)');
  html += '</div>';

  // Top hosts
  const hostMap = {};
  entries.forEach(e => { try { const h = new URL(e.url).host; hostMap[h] = (hostMap[h]||0) + 1; } catch {} });
  const topHosts = Object.entries(hostMap).sort((a,b) => b[1]-a[1]).slice(0,8);
  if (topHosts.length > 0) {
    const maxCount = topHosts[0][1];
    html += '<div class="insights-section"><div class="insights-section-title">Top Hosts</div><div class="insights-list">';
    topHosts.forEach(([host, count]) => {
      html += '<div class="insights-item"><span style="flex-shrink:0;font-family:var(--mono);font-size:11px;color:var(--ink);min-width:140px">' + escapeHTML(host) + '</span>' +
        '<div class="bar-bg"><div class="bar-fill" style="width:' + (count/maxCount*100) + '%;background:var(--accent)"></div></div>' +
        '<span style="font-family:var(--mono);font-size:10px;color:var(--fog);min-width:30px;text-align:right">' + count + '</span></div>';
    });
    html += '</div></div>';
  }

  // Slowest requests
  const slowest = [...completed].filter(e => e.timing?.endDate && e.timing?.startDate)
    .sort((a,b) => {
      const da = new Date(a.timing.endDate) - new Date(a.timing.startDate);
      const db = new Date(b.timing.endDate) - new Date(b.timing.startDate);
      return db - da;
    }).slice(0,5);
  if (slowest.length > 0) {
    html += '<div class="insights-section"><div class="insights-section-title">Slowest Requests</div><div class="insights-list">';
    slowest.forEach(e => {
      let path = '';
      try { path = new URL(e.url).pathname; } catch { path = e.url; }
      html += '<div class="insights-item"><span class="method-badge" style="color:' + methodColorCSS(e.method) + ';background:' + methodColorCSS(e.method) + '20;font-size:9px">' + e.method + '</span>' +
        '<span style="flex:1;font-family:var(--mono);font-size:11px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + escapeHTML(path) + '</span>' +
        '<span style="font-family:var(--mono);font-size:10px;color:var(--warning)">' + fmtDuration(e.timing) + '</span></div>';
    });
    html += '</div></div>';
  }

  // Status distribution
  const statusMap = {};
  entries.forEach(e => {
    if (e.statusCode) {
      const bucket = Math.floor(e.statusCode / 100) + 'xx';
      statusMap[bucket] = (statusMap[bucket] || 0) + 1;
    }
  });
  const statusBuckets = Object.entries(statusMap).sort();
  if (statusBuckets.length > 0) {
    const maxS = Math.max(...statusBuckets.map(s => s[1]));
    html += '<div class="insights-section"><div class="insights-section-title">Status Distribution</div><div class="insights-list">';
    const bucketColors = {'2xx':'var(--success)','3xx':'var(--warning)','4xx':'var(--danger)','5xx':'var(--critical)'};
    statusBuckets.forEach(([bucket, count]) => {
      html += '<div class="insights-item"><span style="font-weight:700;font-family:var(--mono);font-size:12px;color:' + (bucketColors[bucket]||'var(--fog)') + ';min-width:40px">' + bucket + '</span>' +
        '<div class="bar-bg"><div class="bar-fill" style="width:' + (count/maxS*100) + '%;background:' + (bucketColors[bucket]||'var(--fog)') + '"></div></div>' +
        '<span style="font-family:var(--mono);font-size:10px;color:var(--fog);min-width:30px;text-align:right">' + count + '</span></div>';
    });
    html += '</div></div>';
  }

  content.innerHTML = html;
}

function statTile(value, label, color) {
  return '<div class="stat-tile"><div class="stat-value" style="color:' + color + '">' + value + '</div><div class="stat-label">' + label + '</div></div>';
}

// ── Counts ──
function updateCounts() {
  document.getElementById('networkCount').textContent = entries.length;
  document.getElementById('consoleCount').textContent = logs.length;
  document.getElementById('analyticsCount').textContent = events.length;
  document.getElementById('statusEntries').textContent = entries.length + ' requests';
  document.getElementById('statusLogs').textContent = logs.length + ' logs';
  document.getElementById('statusEvents').textContent = events.length + ' events';
}

// ── Init ──
connect();
</script>
</body>
</html>
"""
}
