'use strict';

const CHUNK = 8 * 1024 * 1024;
const POLL_MS = 5000;

const ICONS = {
  download: '<svg viewBox="0 0 20 20" aria-hidden="true"><path d="M10 3v10m0 0-4-4m4 4 4-4M4 16h12" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  trash: '<svg viewBox="0 0 20 20" aria-hidden="true"><path d="M4 6h12M8 6V4h4v2m-6 0 .7 10h6.6L14 6M8.5 9v4m3-4v4" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>',
};

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

const ui = {
  state: null,
  filter: '',
  queue: [],
  uploading: false,
  reindexing: false,
  busyService: false,
  lastFetchError: 0,
  seq: 0,
};

/* ------------------------------------------------------------------ utils */
function fmt(bytes) {
  if (!Number.isFinite(bytes) || bytes < 0) return '–';
  if (bytes < 1024) return `${bytes} B`;
  const units = ['KiB', 'MiB', 'GiB', 'TiB'];
  let value = bytes;
  let unit = -1;
  do {
    value /= 1024;
    unit += 1;
  } while (value >= 1024 && unit < units.length - 1);
  const digits = value >= 100 || unit === 0 ? 0 : 1;
  return `${value.toFixed(digits)} ${units[unit]}`;
}

function relTime(seconds) {
  const delta = Date.now() / 1000 - seconds;
  if (delta < 60) return 'just now';
  const steps = [
    [31536000, 'y'],
    [2592000, 'mo'],
    [86400, 'd'],
    [3600, 'h'],
    [60, 'm'],
  ];
  for (const [size, label] of steps) {
    if (delta >= size) return `${Math.floor(delta / size)}${label} ago`;
  }
  return 'just now';
}

function absTime(seconds) {
  return new Date(seconds * 1000).toLocaleString();
}

function toast(message, kind = '') {
  const box = $('#toasts');
  const el = document.createElement('div');
  el.className = `toast ${kind}`;
  el.textContent = message;
  box.append(el);
  setTimeout(() => {
    el.style.transition = 'opacity .25s, transform .25s';
    el.style.opacity = '0';
    el.style.transform = 'translateY(4px)';
    setTimeout(() => el.remove(), 300);
  }, kind === 'bad' ? 8000 : 4500);
}

async function api(path, options = {}) {
  const opts = { ...options };
  const headers = new Headers(opts.headers || {});
  headers.set('X-Ktemata', '1');
  if (opts.json !== undefined) {
    headers.set('Content-Type', 'application/json');
    opts.body = JSON.stringify(opts.json);
    delete opts.json;
  }
  const res = await fetch(path, { ...opts, headers, credentials: 'same-origin' });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = null;
  }
  if (!res.ok) {
    const err = new Error((data && data.error) || `request failed (HTTP ${res.status})`);
    err.status = res.status;
    throw err;
  }
  return data;
}

function confirmAction({ title, text, ok = 'Delete', danger = true }) {
  return new Promise((resolve) => {
    const dialog = $('#confirm');
    $('#confirm-title').textContent = title;
    $('#confirm-text').textContent = text;
    const button = $('#confirm-ok');
    button.textContent = ok;
    button.className = danger ? 'danger' : 'primary';
    const done = () => {
      dialog.removeEventListener('close', done);
      resolve(dialog.returnValue === 'ok');
    };
    if (dialog.open) dialog.close('cancel');
    dialog.addEventListener('close', done);
    dialog.returnValue = '';
    dialog.showModal();
  });
}

/* ------------------------------------------------------------------ state */
async function refresh() {
  try {
    applyState(await api('/api/state'));
  } catch (err) {
    const now = Date.now();
    if (now - ui.lastFetchError > 60000) {
      ui.lastFetchError = now;
      toast(`Cannot reach the admin service: ${err.message}`, 'bad');
    }
  }
}

function applyState(data) {
  ui.state = data;
  $('#library-path').textContent = data.zim_dir;

  const link = $('#library-link');
  const host = window.location.hostname || '127.0.0.1';
  const base = host.includes(':') ? `[${host}]` : host;
  link.href = `${window.location.protocol}//${base}:${data.library_port}/`;
  link.title = `Kiwix library on port ${data.library_port}`;

  $('#foot-version').textContent = `ktemata-admin ${data.version}`;
  renderStorage(data.disk);
  renderCount(data.zims);
  renderService(data.service);
  renderIndex(data.index, data.zims);
  renderTable(data.zims);
  renderParts(data.parts);
}

function renderStorage(disk) {
  const percent = Math.max(0, Math.min(100, disk.percent || 0));
  $('#disk-value').textContent = `${percent.toFixed(percent < 10 ? 1 : 0)}%`;
  const bar = $('#disk-bar');
  bar.style.width = `${percent}%`;
  const wrap = $('#disk-progress');
  wrap.classList.toggle('hot', percent >= 80 && percent < 95);
  wrap.classList.toggle('full', percent >= 95);
  wrap.setAttribute('aria-valuenow', String(percent));
  wrap.setAttribute('aria-valuemin', '0');
  wrap.setAttribute('aria-valuemax', '100');
  $('#disk-detail').textContent =
    `${fmt(disk.zim_bytes)} in ZIM · ${fmt(disk.free)} free of ${fmt(disk.total)}`;
}

function renderCount(zims) {
  const bytes = zims.reduce((sum, z) => sum + z.size, 0);
  $('#count-value').textContent = String(zims.length);
  const parts = ui.state && ui.state.parts ? ui.state.parts.length : 0;
  let detail = zims.length
    ? `${fmt(bytes)} across ${zims.length === 1 ? 'one archive' : `${zims.length} archives`}`
    : 'no archives yet';
  if (parts) detail += ` · ${parts} interrupted`;
  $('#count-detail').textContent = detail;
}

const SERVICE_WORDS = {
  active: 'Running',
  inactive: 'Stopped',
  failed: 'Failed',
  activating: 'Starting',
  deactivating: 'Stopping',
  unknown: 'Unknown',
};

function renderService(service) {
  const pill = $('#svc-pill');
  const pillText = $('#svc-pill-text');
  pill.classList.remove('ok', 'warn', 'bad');

  let word = SERVICE_WORDS[service.active] || service.active || 'Unknown';
  let tone = '';
  if (!service.available) {
    word = 'Unavailable';
    tone = 'bad';
  } else if (service.load === 'not-found') {
    word = 'Not installed';
    tone = 'bad';
  } else if (service.active === 'active') {
    tone = 'ok';
  } else if (service.active === 'failed') {
    tone = 'bad';
  } else {
    tone = 'warn';
  }
  if (tone) pill.classList.add(tone);
  pillText.textContent = `Kiwix ${word.toLowerCase()}`;

  $('#service-value').textContent = word;
  let detail = `port ${service.port}`;
  if (service.active === 'active' && service.since) {
    detail = `since ${service.since.replace(/\s+\S+$/, '')} · port ${service.port}`;
  } else if (service.enabled) {
    detail = `${service.enabled} at boot · port ${service.port}`;
  }
  $('#service-detail').textContent = detail;

  const unavailable = !service.available || service.load === 'not-found';
  $$('#service-actions button').forEach((button) => {
    const action = button.dataset.service;
    let disabled = unavailable || ui.busyService;
    if (action === 'start' && service.active === 'active') disabled = true;
    if (action === 'stop' && service.active !== 'active' && service.active !== 'activating') disabled = true;
    button.disabled = disabled;
  });
}

function renderIndex(index, zims) {
  let value = 'Up to date';
  let tone = 'ok';
  let detail = `${index.archives} ${index.archives === 1 ? 'archive' : 'archives'}`;
  if (index.error) {
    value = 'Unreadable';
    tone = 'bad';
    detail = index.error;
  } else if (!index.exists) {
    value = zims.length ? 'Not built' : 'Empty';
    tone = zims.length ? 'warn' : '';
    detail = zims.length ? 'kiwix-serve has no index to load' : 'add an archive to begin';
  } else {
    if (index.mtime) detail += ` · ${relTime(index.mtime)}`;
    if (index.stale) {
      value = 'Out of date';
      tone = 'warn';
      const bits = [];
      if (index.missing.length) bits.push(`${index.missing.length} new`);
      if (index.gone.length) bits.push(`${index.gone.length} removed`);
      detail = `${bits.join(' · ')} since the last build`;
    }
  }
  const el = $('#index-value');
  el.textContent = value;
  el.style.color = tone === 'warn' ? 'var(--warn)' : tone === 'bad' ? 'var(--bad)' : '';
  $('#index-detail').textContent = detail;
  $('#reindex').disabled = ui.reindexing;
  $('#reindex').textContent = ui.reindexing ? 'Rebuilding…' : 'Rebuild index';

  const banner = $('#banner');
  const showBanner = index.stale || (!index.exists && zims.length > 0);
  banner.hidden = !showBanner;
  if (showBanner) {
    if (!index.exists) {
      $('#banner-text').textContent =
        'The library index does not exist yet, so kiwix-serve has nothing to serve.';
    } else {
      const bits = [];
      if (index.missing.length) bits.push(`${index.missing.length} new`);
      if (index.gone.length) bits.push(`${index.gone.length} removed`);
      $('#banner-text').textContent = `The index is out of date (${bits.join(', ')}).`;
    }
    $('#banner-action').disabled = ui.reindexing;
  }
}

function renderTable(zims) {
  const rows = $('#rows');
  rows.replaceChildren();
  const empty = $('#zims-empty');
  empty.hidden = zims.length !== 0;
  $('#zim-table').hidden = zims.length === 0;

  for (const zim of zims) {
    const tr = document.createElement('tr');
    tr.dataset.name = zim.name.toLowerCase();

    const name = document.createElement('td');
    name.className = 'name';
    const nameSpan = document.createElement('span');
    nameSpan.className = 'name';
    nameSpan.textContent = zim.name;
    nameSpan.title = zim.name;
    name.append(nameSpan);

    const size = document.createElement('td');
    size.className = 'num';
    size.textContent = fmt(zim.size);

    const when = document.createElement('td');
    when.className = 'when';
    when.textContent = relTime(zim.mtime);
    when.title = absTime(zim.mtime);

    const index = document.createElement('td');
    const badge = document.createElement('span');
    badge.className = `badge ${zim.indexed ? 'ok' : 'stale'}`;
    badge.textContent = zim.indexed ? 'Indexed' : 'Not indexed';
    badge.title = zim.indexed
      ? 'Present in library.xml'
      : 'Not in library.xml yet — rebuild the index to publish it';
    index.append(badge);

    const act = document.createElement('td');
    act.className = 'act';

    const download = document.createElement('a');
    download.className = 'icon';
    download.href = `/api/download?name=${encodeURIComponent(zim.name)}`;
    download.setAttribute('download', zim.name);
    download.setAttribute('aria-label', `Download ${zim.name}`);
    download.title = 'Download';
    download.innerHTML = ICONS.download;

    const del = document.createElement('button');
    del.type = 'button';
    del.className = 'icon danger';
    del.setAttribute('aria-label', `Delete ${zim.name}`);
    del.title = 'Delete';
    del.innerHTML = ICONS.trash;
    del.addEventListener('click', () => deleteZim(zim.name));

    act.append(download, del);
    tr.append(name, size, when, index, act);
    rows.append(tr);
  }
  applyFilter();
}

function renderParts(parts) {
  const block = $('#parts-block');
  const list = $('#parts');
  block.hidden = !parts.length;
  list.replaceChildren();
  for (const part of parts) {
    const li = document.createElement('li');
    const name = document.createElement('span');
    name.className = 'pname';
    name.textContent = part.name;
    name.title = part.name;
    const meta = document.createElement('span');
    meta.textContent = `${fmt(part.size)} · ${relTime(part.mtime)}`;
    const discard = document.createElement('button');
    discard.type = 'button';
    discard.className = 'mini';
    discard.textContent = 'Discard';
    discard.addEventListener('click', () => discardPart(part.name, part.size));
    li.append(name, meta, discard);
    list.append(li);
  }
}

function applyFilter() {
  const needle = ui.filter.trim().toLowerCase();
  $$('#rows tr').forEach((row) => {
    row.classList.toggle('hidden', Boolean(needle) && !row.dataset.name.includes(needle));
  });
}

/* ------------------------------------------------------------------ actions */
async function deleteZim(name) {
  const ok = await confirmAction({
    title: 'Delete archive?',
    text: `${name}\n\nThe file is removed from the library. Rebuild the index afterwards so kiwix-serve stops advertising it.`,
    ok: 'Delete',
  });
  if (!ok) return;
  try {
    await api(`/api/zim?name=${encodeURIComponent(name)}`, { method: 'DELETE' });
    toast(`Deleted ${name}`, 'good');
    await refresh();
  } catch (err) {
    toast(`Delete failed: ${err.message}`, 'bad');
  }
}

async function discardPart(name, size) {
  const ok = await confirmAction({
    title: 'Discard interrupted upload?',
    text: `${name}\n\n${fmt(size)} already uploaded will be thrown away.`,
    ok: 'Discard',
  });
  if (!ok) return;
  try {
    await api(`/api/upload?name=${encodeURIComponent(name)}`, { method: 'DELETE' });
    toast(`Discarded ${name}`, 'good');
    await refresh();
  } catch (err) {
    toast(`Discard failed: ${err.message}`, 'bad');
  }
}

async function serviceAction(action) {
  if (action === 'stop') {
    const ok = await confirmAction({
      title: 'Stop kiwix-serve?',
      text: 'Readers on the device and on the network lose the library until it is started again.',
      ok: 'Stop service',
      danger: true,
    });
    if (!ok) return;
  }
  ui.busyService = true;
  if (ui.state) renderService(ui.state.service);
  try {
    const result = await api('/api/service', { method: 'POST', json: { action } });
    const words = { start: 'started', stop: 'stopped', restart: 'restarted' };
    toast(`Kiwix ${words[action]}${result.output ? ` — ${result.output}` : ''}`, 'good');
    if (ui.state) ui.state.service = result.service;
    renderService(result.service);
  } catch (err) {
    toast(`Kiwix ${action} failed: ${err.message}`, 'bad');
  } finally {
    ui.busyService = false;
    await refresh();
  }
}

async function reindex() {
  if (ui.reindexing) return;
  ui.reindexing = true;
  if (ui.state) renderIndex(ui.state.index, ui.state.zims);
  try {
    const result = await api('/api/reindex', { method: 'POST', json: { restart: true } });
    const line = (result.output || '')
      .split('\n')
      .map((s) => s.trim())
      .filter(Boolean)
      .pop();
    toast(line || 'Index rebuilt', 'good');
    if (result.restart) {
      toast(result.restart.split('\n').filter(Boolean).pop() || 'Kiwix restarted', 'good');
    }
    if (result.state) applyState(result.state);
  } catch (err) {
    toast(`Index rebuild failed: ${err.message}`, 'bad');
  } finally {
    ui.reindexing = false;
    await refresh();
  }
}

/* ------------------------------------------------------------------ uploads */
function enqueueFiles(files) {
  let added = 0;
  for (const file of files) {
    if (!file.name.endsWith('.zim')) {
      toast(`${file.name}: only .zim archives can be uploaded`, 'bad');
      continue;
    }
    addQueueItem(file);
    added += 1;
  }
  if (added) {
    $('#queue-panel').hidden = false;
    pump();
  }
}

function addQueueItem(file) {
  const item = {
    id: ++ui.seq,
    file,
    name: file.name,
    total: file.size,
    received: 0,
    state: 'queued',
    message: '',
    controller: new AbortController(),
    speed: 0,
  };
  const li = document.createElement('li');
  li.className = 'qitem';
  const name = document.createElement('span');
  name.className = 'qname';
  name.textContent = file.name;
  name.title = file.name;
  const meta = document.createElement('span');
  meta.className = 'qmeta';
  const actions = document.createElement('span');
  actions.className = 'qactions';
  const cancel = document.createElement('button');
  cancel.type = 'button';
  cancel.textContent = 'Cancel';
  cancel.addEventListener('click', () => cancelUpload(item));
  actions.append(cancel);
  const bar = document.createElement('span');
  bar.className = 'qbar';
  const fill = document.createElement('span');
  bar.append(fill);
  const msg = document.createElement('span');
  msg.className = 'qmsg';
  li.append(name, meta, actions, bar, msg);
  $('#queue').append(li);

  Object.assign(item, { el: li, bar: fill, meta, msg, cancel });
  item.bar.style.width = '0%';
  item.meta.textContent = `queued · ${fmt(item.total)}`;
  ui.queue.push(item);
}

function setQueueState(item, state, message = '') {
  item.state = state;
  item.el.classList.remove('queued', 'uploading', 'done', 'error', 'cancelled');
  item.el.classList.add(state);
  item.message = message;
  item.msg.textContent = message;
  item.msg.classList.toggle('err', state === 'error');
  item.cancel.hidden = state !== 'queued' && state !== 'uploading';
  if (state === 'done') {
    item.bar.style.width = '100%';
  }
}

function updateProgress(item) {
  const pct = item.total ? Math.min(100, (item.received / item.total) * 100) : 0;
  item.bar.style.width = `${pct.toFixed(2)}%`;
  item.meta.textContent =
    `${fmt(item.received)} / ${fmt(item.total)}` + (item.speed ? ` · ${fmt(item.speed)}/s` : '');
}

function cancelUpload(item) {
  if (item.state === 'uploading') {
    item.cancel.hidden = true;
    item.controller.abort();
  } else if (item.state === 'queued') {
    setQueueState(item, 'cancelled', 'cancelled');
  }
}

async function pump() {
  if (ui.uploading) return;
  const item = ui.queue.find((entry) => entry.state === 'queued');
  if (!item) return;
  ui.uploading = true;
  try {
    await runUpload(item);
  } catch (err) {
    if (err.name === 'AbortError') {
      setQueueState(item, 'cancelled', 'cancelled — drop the same file to resume');
    } else {
      setQueueState(item, 'error', err.message);
      toast(`${item.name}: ${err.message}`, 'bad');
    }
  } finally {
    ui.uploading = false;
    await refresh();
    pump();
  }
}

async function runUpload(item) {
  setQueueState(item, 'uploading', '');
  item.received = 0;
  updateProgress(item);

  let status = { received: 0, complete: false };
  try {
    status = await api(`/api/upload?name=${encodeURIComponent(item.name)}`);
  } catch (err) {
    throw new Error(`cannot check upload state: ${err.message}`);
  }

  let overwrite = false;
  if (status.complete) {
    overwrite = await confirmAction({
      title: 'Replace archive?',
      text: `${item.name} is already in the library. The uploaded copy replaces it once the transfer finishes.`,
      ok: 'Replace',
      danger: false,
    });
    if (!overwrite) {
      setQueueState(item, 'cancelled', 'already in the library');
      return;
    }
    await api(`/api/upload?name=${encodeURIComponent(item.name)}`, { method: 'DELETE' }).catch(() => {});
    status.received = 0;
  } else if (ui.state && ui.state.zims.some((z) => z.name === item.name)) {
    overwrite = await confirmAction({
      title: 'Replace archive?',
      text: `${item.name} is already in the library. The uploaded copy replaces it once the transfer finishes.`,
      ok: 'Replace',
      danger: false,
    });
    if (!overwrite) {
      setQueueState(item, 'cancelled', 'already in the library');
      return;
    }
  }

  let offset = status.received;
  if (offset > item.total || offset === item.total) {
    await api(`/api/upload?name=${encodeURIComponent(item.name)}`, { method: 'DELETE' }).catch(() => {});
    offset = 0;
  }
  if (offset > 0) {
    item.received = offset;
    updateProgress(item);
    toast(`${item.name}: resuming at ${fmt(offset)}`, '');
  }

  let reset = false;
  let lastTime = performance.now();
  let lastBytes = offset;
  let restarted = false;

  while (offset < item.total) {
    const end = Math.min(offset + CHUNK, item.total);
    const headers = new Headers({
      'X-Ktemata': '1',
      'X-Zim-Offset': String(offset),
      'X-Zim-Total': String(item.total),
      'X-Zim-Mtime': String(item.file.lastModified),
    });
    if (overwrite) headers.set('X-Zim-Overwrite', '1');
    if (reset) headers.set('X-Zim-Reset', '1');

    const res = await fetch(`/api/upload?name=${encodeURIComponent(item.name)}`, {
      method: 'POST',
      headers,
      body: item.file.slice(offset, end),
      credentials: 'same-origin',
      signal: item.controller.signal,
    });
    const data = await res.json().catch(() => null);

    if (!res.ok) {
      const message = (data && data.error) || `HTTP ${res.status}`;
      if (res.status === 409 && /expected offset|different copy/.test(message) && !restarted) {
        // A partial chunk from an earlier run, or another writer: discard and start clean.
        restarted = true;
        setQueueState(item, 'uploading', 'restarting from the beginning');
        await api(`/api/upload?name=${encodeURIComponent(item.name)}`, { method: 'DELETE' }).catch(() => {});
        offset = 0;
        reset = true;
        continue;
      }
      if (res.status === 409 && /already exists/.test(message) && !overwrite) {
        overwrite = await confirmAction({
          title: 'Replace archive?',
          text: `${item.name} appeared in the library during the upload. Replace it with this copy?`,
          ok: 'Replace',
          danger: false,
        });
        if (!overwrite) throw new Error('already in the library');
        continue;
      }
      throw new Error(message);
    }

    reset = false;
    offset = data.done ? item.total : data.received;
    item.received = offset;
    const now = performance.now();
    if (now - lastTime > 400) {
      const rate = ((offset - lastBytes) * 1000) / (now - lastTime);
      item.speed = item.speed ? item.speed * 0.6 + rate * 0.4 : rate;
      lastTime = now;
      lastBytes = offset;
    }
    updateProgress(item);
  }

  setQueueState(item, 'done', '');
  item.meta.textContent = `done · ${fmt(item.total)}`;
  toast(`Uploaded ${item.name} — rebuild the index to publish it`, 'good');
}

/* ------------------------------------------------------------------ offline AI */
async function refreshAiStatus() {
  const label = $('#ai-status');
  const input = $('#ai-question');
  const button = $('#ai-ask');
  try {
    const state = await api('/api/ai/status');
    if (!state || state.installed === false) {
      label.textContent = 'offline AI is not installed — run post-install-ai.sh';
      input.disabled = true;
      button.disabled = true;
      return;
    }
    if (state.error) {
      label.textContent = `offline AI · ${state.error}`;
      input.disabled = true;
      button.disabled = true;
      return;
    }
    if (!state.chunks) {
      label.textContent = 'offline AI · no documents indexed yet — run sudo ktemata-ai ingest';
      input.disabled = true;
      button.disabled = true;
      return;
    }
    if (!state.ollama) {
      label.textContent = 'offline AI · Ollama is not running';
      input.disabled = true;
      button.disabled = true;
      return;
    }
    const models = state.ollama_models || [];
    const hasModel = (wanted) =>
      models.some((name) => name === wanted || name.startsWith(`${wanted}:`));
    if (!hasModel(state.model) || !hasModel(state.embed_model)) {
      label.textContent = 'offline AI · model not pulled — see docs/OFFLINE_AI.md';
      input.disabled = true;
      button.disabled = true;
      return;
    }
    input.disabled = false;
    button.disabled = false;
    const when = state.last_ingest ? relTime(state.last_ingest) : 'never';
    label.textContent =
      `offline AI · ${state.docs} documents · ${state.chunks} chunks · ` +
      `${state.model} · indexed ${when}`;
  } catch (err) {
    label.textContent = `offline AI · ${err.message}`;
    input.disabled = true;
    button.disabled = true;
  }
}

async function askAi(event) {
  event.preventDefault();
  const input = $('#ai-question');
  const button = $('#ai-ask');
  const box = $('#ai-answer');
  const text = $('#ai-text');
  const sources = $('#ai-sources');
  const question = input.value.trim();
  if (!question) return;

  button.disabled = true;
  button.textContent = 'Thinking…';
  box.hidden = true;
  try {
    const result = await api('/api/ai/ask', { method: 'POST', json: { question } });
    text.textContent = result.answer || '(the model returned an empty answer)';
    sources.replaceChildren();
    for (const [index, source] of (result.sources || []).entries()) {
      const item = document.createElement('li');
      const where = document.createElement('span');
      where.textContent = `[${index + 1}] ${source.path} · chunk ${source.ordinal}`;
      const score = document.createElement('span');
      score.className = 'score';
      score.textContent = Number(source.score).toFixed(3);
      item.append(where, score);
      sources.append(item);
    }
    box.hidden = false;
  } catch (err) {
    toast(err.message, 'bad');
  } finally {
    button.disabled = false;
    button.textContent = 'Ask';
  }
}

/* ------------------------------------------------------------------ wiring */
$('#pick').addEventListener('click', () => $('#file').click());
$('#file').addEventListener('change', (event) => {
  enqueueFiles(event.target.files);
  event.target.value = '';
});
$('#filter').addEventListener('input', (event) => {
  ui.filter = event.target.value;
  applyFilter();
});
$('#reindex').addEventListener('click', reindex);
$('#banner-action').addEventListener('click', reindex);
$$('#service-actions button').forEach((button) => {
  button.addEventListener('click', () => serviceAction(button.dataset.service));
});
$('#clear-done').addEventListener('click', () => {
  ui.queue = ui.queue.filter((item) => {
    if (item.state === 'done' || item.state === 'error' || item.state === 'cancelled') {
      item.el.remove();
      return false;
    }
    return true;
  });
  $('#queue-panel').hidden = ui.queue.length === 0;
});
$('#ai-form').addEventListener('submit', askAi);

// Drag and drop anywhere on the page.
let dragDepth = 0;
const hasFiles = (event) => Array.from(event.dataTransfer?.types || []).includes('Files');
window.addEventListener('dragenter', (event) => {
  if (!hasFiles(event)) return;
  event.preventDefault();
  dragDepth += 1;
  $('#drop').hidden = false;
});
window.addEventListener('dragover', (event) => {
  if (hasFiles(event)) event.preventDefault();
});
window.addEventListener('dragleave', (event) => {
  if (!hasFiles(event)) return;
  dragDepth = Math.max(0, dragDepth - 1);
  if (!dragDepth) $('#drop').hidden = true;
});
window.addEventListener('drop', (event) => {
  if (!hasFiles(event)) return;
  event.preventDefault();
  dragDepth = 0;
  $('#drop').hidden = true;
  enqueueFiles(event.dataTransfer.files);
});

window.addEventListener('beforeunload', (event) => {
  if (ui.uploading || ui.queue.some((item) => item.state === 'queued')) {
    event.preventDefault();
    event.returnValue = '';
  }
});

setInterval(() => {
  if (!document.hidden) refresh();
}, POLL_MS);
document.addEventListener('visibilitychange', () => {
  if (!document.hidden) refresh();
});

refresh();
refreshAiStatus();
