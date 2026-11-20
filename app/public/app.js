'use strict';

const tbody = document.getElementById('events');
const empty = document.getElementById('empty');
const refresh = document.getElementById('refresh');
const serviceDot = document.getElementById('service-dot');
const serviceLabel = document.getElementById('service-label');

function formatDate(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  return date.toLocaleString('es', { dateStyle: 'medium', timeStyle: 'short' });
}

async function checkService() {
  try {
    const res = await fetch('/health', { cache: 'no-store' });
    if (res.ok) {
      serviceDot.className = 'dot ok';
      serviceLabel.textContent = 'Operativo';
    } else {
      serviceDot.className = 'dot bad';
      serviceLabel.textContent = 'Servicio no disponible';
    }
  } catch {
    serviceDot.className = 'dot bad';
    serviceLabel.textContent = 'Sin conexión';
  }
}

async function loadEvents() {
  try {
    const res = await fetch('/events', { cache: 'no-store' });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);

    tbody.textContent = '';
    empty.className = 'empty';
    if (!Array.isArray(data) || !data.length) {
      empty.textContent = 'No hay eventos registrados.';
      empty.hidden = false;
      return;
    }
    empty.hidden = true;

    for (const row of data) {
      const tr = document.createElement('tr');

      const action = document.createElement('td');
      action.className = 'action';
      action.textContent = row.action;

      const actor = document.createElement('td');
      actor.textContent = row.actor;

      const date = document.createElement('td');
      date.className = 'muted';
      date.textContent = formatDate(row.created_at);

      tr.append(action, actor, date);
      tbody.append(tr);
    }
  } catch (err) {
    tbody.textContent = '';
    empty.className = 'empty bad';
    empty.textContent = `No se pudieron cargar los eventos: ${err.message}`;
    empty.hidden = false;
  }
}

refresh.addEventListener('click', () => {
  loadEvents();
  checkService();
});

checkService();
loadEvents();
