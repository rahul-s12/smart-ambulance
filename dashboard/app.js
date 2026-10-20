const $ = (selector) => document.querySelector(selector);
const state = { ambulanceId: null, readings: [], stream: null, polling: null };
const metric = (name, value, suffix = '') => { $(name).textContent = value == null ? '—' : `${value}${suffix}`; };
const dateTime = (value) => new Intl.DateTimeFormat(undefined, { hour: '2-digit', minute: '2-digit', second: '2-digit' }).format(new Date(value));

function setConnection(kind, message) {
  $('#statusDot').className = `status-dot ${kind}`;
  $('#connectionText').textContent = message;
}
function assessment(name, value, warning) { $(name).textContent = value == null ? 'Awaiting reading' : warning ? 'Review required' : 'Within test range'; }
function drawChart(readings) {
  const canvas = $('#trendChart'); const context = canvas.getContext('2d'); const ratio = devicePixelRatio || 1;
  const width = canvas.clientWidth; const height = canvas.clientHeight; canvas.width = width * ratio; canvas.height = height * ratio; context.scale(ratio, ratio); context.clearRect(0, 0, width, height);
  const ordered = [...readings].reverse(); const left = 42, right = 20, top = 20, bottom = 30;
  context.strokeStyle = 'rgba(214,232,255,.12)'; context.lineWidth = 1;
  for (let line = 0; line < 4; line += 1) { const y = top + (height - top - bottom) * line / 3; context.beginPath(); context.moveTo(left, y); context.lineTo(width - right, y); context.stroke(); }
  if (!ordered.length) { context.fillStyle = '#98a9cd'; context.font = '13px system-ui'; context.fillText('Awaiting telemetry from cloud…', left, height / 2); return; }
  const drawSeries = (key, color, min, max) => { context.strokeStyle = color; context.lineWidth = 2.5; context.lineJoin = 'round'; context.beginPath(); ordered.forEach((reading, index) => { const x = left + (width-left-right) * (ordered.length === 1 ? .5 : index/(ordered.length-1)); const value = reading.metrics[key]; const y = top + (height-top-bottom) * (1 - (value-min)/(max-min)); index ? context.lineTo(x,y) : context.moveTo(x,y); }); context.stroke(); };
  drawSeries('heartRateBpm', '#ff786b', 50, 120); drawSeries('spo2Percent', '#6bb6ff', 90, 100); drawSeries('temperatureC', '#ffd166', 35, 39);
}
function renderReadings(readings) {
  const body = $('#readingsBody'); body.replaceChildren();
  if (!readings.length) { body.innerHTML = '<tr><td colspan="5" class="empty">No readings found for this ambulance.</td></tr>'; drawChart([]); return; }
  const template = $('#rowTemplate');
  readings.slice(0, 8).forEach((reading) => { const fragment = template.content.cloneNode(true); fragment.querySelector('.reading-time').textContent = dateTime(reading.observedAt); fragment.querySelector('.reading-heart').textContent = `${reading.metrics.heartRateBpm} BPM`; fragment.querySelector('.reading-spo2').textContent = `${reading.metrics.spo2Percent}%`; fragment.querySelector('.reading-temperature').textContent = `${reading.metrics.temperatureC.toFixed(1)} °C`; fragment.querySelector('.reading-source').textContent = reading.source?.type ?? 'unknown'; body.append(fragment); });
  drawChart(readings); $('#trendWindow').textContent = `${readings.length} latest readings`;
}
function renderLatest(reading) {
  if (!reading) return;
  const { metrics } = reading; $('#unitName').textContent = reading.ambulanceId; $('#sourceLabel').textContent = reading.source?.label ?? reading.source?.type ?? 'Unknown';
  metric('#heartRate', metrics.heartRateBpm); metric('#spo2', metrics.spo2Percent); metric('#temperature', metrics.temperatureC?.toFixed(1));
  assessment('#heartStatus', metrics.heartRateBpm, metrics.heartRateBpm < 60 || metrics.heartRateBpm > 100); assessment('#spo2Status', metrics.spo2Percent, metrics.spo2Percent < 95); assessment('#temperatureStatus', metrics.temperatureC, metrics.temperatureC >= 38 || metrics.temperatureC < 36);
  $('#lastUpdated').textContent = `Received ${dateTime(reading.observedAt)}`;
}
async function request(path) { const response = await fetch(path); if (!response.ok) throw new Error(`Cloud request failed (${response.status})`); return response.json(); }
async function loadDashboard() {
  try {
    setConnection('', 'Connecting to cloud…'); const health = await request('/health'); $('#storageLabel').textContent = health.storage === 'mongodb' ? 'MongoDB cloud connected' : 'Memory fallback active';
    const units = await request('/api/ambulances'); const ambulances = units.ambulances ?? []; const select = $('#ambulanceSelect'); const previous = state.ambulanceId;
    select.replaceChildren(); ambulances.forEach(({ ambulanceId }) => { const option = new Option(ambulanceId, ambulanceId); if (ambulanceId === previous) option.selected = true; select.add(option); });
    state.ambulanceId = select.value || ambulances[0]?.ambulanceId || null; if (!state.ambulanceId) throw new Error('No ambulances are currently reporting telemetry.');
    const [latest, history] = await Promise.all([request(`/api/ambulances/${encodeURIComponent(state.ambulanceId)}/latest`), request(`/api/ambulances/${encodeURIComponent(state.ambulanceId)}/readings?limit=30`)]);
    state.readings = history.readings ?? []; renderLatest(latest.reading); renderReadings(state.readings); setConnection('online', health.storage === 'mongodb' ? 'Cloud connected' : 'Cloud connected — temporary storage'); connectStream();
  } catch (error) { setConnection('offline', 'Cloud backend unavailable'); $('#storageLabel').textContent = 'Connection unavailable'; $('#lastUpdated').textContent = error.message; renderReadings([]); }
}
function connectStream() {
  state.stream?.close(); if (!state.ambulanceId) return; state.stream = new EventSource('/api/stream');
  state.stream.addEventListener('telemetry', (event) => { const reading = JSON.parse(event.data); if (reading.ambulanceId !== state.ambulanceId) return; state.readings = [reading, ...state.readings.filter((item) => item.readingId !== reading.readingId)].slice(0,30); renderLatest(reading); renderReadings(state.readings); setConnection('online', 'Live cloud feed'); });
  state.stream.onerror = () => { setConnection('offline', 'Live feed interrupted — retrying'); };
}
$('#refreshButton').addEventListener('click', loadDashboard); $('#ambulanceSelect').addEventListener('change', (event) => { state.ambulanceId = event.target.value; loadDashboard(); }); window.addEventListener('resize', () => drawChart(state.readings));
loadDashboard(); state.polling = setInterval(loadDashboard, 30000);
