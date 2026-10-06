'use strict';
const theme = new URLSearchParams(location.search).get('theme');
const chosen = ['solar', 'lagoon', 'route'].includes(theme) ? theme : 'solar';
document.title = `${{solar:'Солнечная смена',lagoon:'Лагуна',route:'Маршрут'}[chosen]} · Дневник смен (демо)`;
document.body.dataset.theme = chosen;
document.querySelector('#app').classList.add(chosen);
document.querySelector('.brand').href = `preview.html?theme=${chosen}`;
const money = value => new Intl.NumberFormat('ru-RU', {minimumFractionDigits:value % 100 ? 2 : 0,maximumFractionDigits:2}).format(value / 100);
function minor(value) {
  const match = /^(\d{1,10})(?:[.,](\d{1,2}))?$/.exec(String(value));
  if (!match || match[0].length !== String(value).length) throw new Error('Введите сумму: цифры и до двух знаков после запятой.');
  return Number(match[1]) * 100 + Number((match[2] || '').padEnd(2, '0'));
}
let trips = window.demoTrips.map(trip => ({...trip, amount:minor(trip.amount),commission:minor(trip.commission)}));
let day = '2026-10-02';
const picker = document.querySelector('#day-picker');
const dialog = document.querySelector('#trip-dialog');
const discardDialog = document.querySelector('#discard-dialog');
const form = document.querySelector('#trip-form');
for(const input of form.querySelectorAll('input:not([type=radio])')) input.setAttribute('aria-describedby','form-error');
for(const input of form.querySelectorAll('input[type=date]')) { input.min='2000-01-01'; input.max='2100-12-31'; }
let dirty = false;
let toastTimer;
const wallDate = value => new Date(`${value}T12:00:00Z`);
const dateLabel = value => value.split('-').reverse().join('/');
const clock = instant => new Intl.DateTimeFormat('ru-RU',{timeZone:'Asia/Qyzylorda',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).format(new Date(instant));
function render() {
  picker.value = day;
  const date = wallDate(day);
  document.querySelector('#weekday').textContent = new Intl.DateTimeFormat('ru-RU',{weekday:'long',timeZone:'UTC'}).format(date);
  const label = new Intl.DateTimeFormat('ru-RU',{day:'numeric',month:'long',timeZone:'UTC'}).format(date);
  document.querySelector('#day-title').replaceChildren(document.createTextNode(label));
  const year = document.createElement('span'); year.textContent = ` ${date.getUTCFullYear()}`;
  document.querySelector('#day-title').append(year);
  document.querySelector('#date-label').textContent = dateLabel(day);
  document.querySelector('#prev').disabled = day <= '2000-01-01';
  document.querySelector('#next').disabled = day >= '2100-12-31';
  const selected = trips.filter(trip=>trip.start.slice(0,10)===day).sort((a,b)=>Date.parse(a.start)-Date.parse(b.start));
  const total = selected.reduce((sum,trip)=>({revenue:sum.revenue+trip.amount,commission:sum.commission+trip.commission,cash:sum.cash+(trip.payment==='cash'?trip.amount:0),card:sum.card+(trip.payment==='card'?trip.amount:0)}),{revenue:0,commission:0,cash:0,card:0});
  document.querySelector('#count-badge').textContent = selected.length;
  const latest = selected.length ? selected.reduce((last,trip)=>Date.parse(trip.end)>Date.parse(last)?trip.end:last,selected[0].end) : null;
  const nextDays = latest ? Math.round((wallDate(latest.slice(0,10))-wallDate(day))/86400000) : 0;
  const range = selected.length ? `${clock(selected[0].start)} — ${clock(latest)}${nextDays ? ` (+${nextDays} д.)` : ''}` : 'День свободен';
  document.querySelector('#range').textContent = range;
  const cashPercent = total.revenue ? total.cash/total.revenue*100 : 0;
  document.querySelector('#summary').innerHTML = `<div class="income"><span class="eyebrow">На руки за день</span><div class="net">${money(total.revenue-total.commission)}<span class="unit">₸</span></div><p class="income-note">Ваш доход после комиссии</p><div class="income-footer"><span>${selected.length} ${plural(selected.length)} за день</span><span class="income-arrow" aria-hidden="true">↗</span></div></div><div class="breakdown"><div class="calculation"><div><span class="metric-label">Выручка</span><strong class="metric-value">${money(total.revenue)} ₸</strong></div><div><span class="metric-label">Комиссия</span><strong class="metric-value">${money(total.commission)} ₸</strong></div></div><div class="payment-breakdown"><div class="pay-labels"><div><span class="payment-dot cash" aria-hidden="true"></span><span>Наличные</span><strong>${money(total.cash)} ₸</strong></div><div><span class="payment-dot" aria-hidden="true"></span><span>Карта</span><strong>${money(total.card)} ₸</strong></div></div><div class="paybar" role="img" aria-label="Выручка наличными ${money(total.cash)} тенге, картой ${money(total.card)} тенге"><span style="width:${cashPercent}%"></span><span style="width:${total.revenue?100-cashPercent:0}%"></span></div></div></div>`;
  if (!selected.length) {
    document.querySelector('#trips').innerHTML = '<div class="empty"><span class="empty-symbol" aria-hidden="true">＋</span><h3>Пока без поездок</h3><p>Добавьте первую — здесь появятся детали дня.</p><button class="primary" id="empty-add">Добавить поездку</button></div>';
    document.querySelector('#empty-add').addEventListener('click',openForm);
    return;
  }
  document.querySelector('#trips').innerHTML = `<table><thead><tr><th scope="col">Время поездки</th><th scope="col">Оплата</th><th scope="col" class="money">Сумма</th><th scope="col" class="money">Комиссия</th><th scope="col" class="money">На руки</th></tr></thead><tbody>${selected.map(trip=>{
    const overnight = trip.end.slice(0,10) !== trip.start.slice(0,10) ? ` · до ${dateLabel(trip.end.slice(0,10))}` : '';
    return `<tr><td><span class="time-main">${clock(trip.start)}<span class="time-dash">—</span>${clock(trip.end)}</span><span class="time-sub">${Math.round((Date.parse(trip.end)-Date.parse(trip.start))/60000)} мин${overnight}<span class="compact-commission"> · Комиссия ${money(trip.commission)} ₸</span></span></td><td><span class="method ${trip.payment}">${trip.payment==='cash'?'Наличные':'Карта'}</span></td><td class="money">${money(trip.amount)} ₸</td><td class="money">${money(trip.commission)} ₸</td><td class="money net-cell">${money(trip.amount-trip.commission)} ₸</td></tr>`;
  }).join('')}</tbody></table>`;
}
function plural(count) {return count%10===1&&count%100!==11?'поездка':count%10>=2&&count%10<=4&&(count%100<12||count%100>14)?'поездки':'поездок';}
function moveDay(delta) {
  const date = wallDate(day); date.setUTCDate(date.getUTCDate()+delta);
  day = date.toISOString().slice(0,10); render();
}
picker.addEventListener('change',()=>{if(picker.value && picker.validity.valid){day=picker.value;render();}});
picker.addEventListener('click',()=>{if(typeof picker.showPicker==='function') picker.showPicker();});
document.querySelector('#prev').addEventListener('click',()=>moveDay(-1));
document.querySelector('#next').addEventListener('click',()=>moveDay(1));
function openForm() {
  form.reset(); dirty=false; document.querySelector('#form-error').textContent='';
  for (const name of ['start-date','end-date']) form.elements.namedItem(name).value=day;
  for(const input of form.querySelectorAll('[inputmode=decimal]')) input.dataset.previous='';
  dialog.showModal();
  form.elements.namedItem('start-date').focus();
}
for(const id of ['add-top','add-mobile']) document.getElementById(id).addEventListener('click',openForm);
function closeForm(){if(dirty){discardDialog.showModal();document.querySelector('#keep-editing').focus();}else{dialog.close();}}
for(const button of document.querySelectorAll('.close-form')) button.addEventListener('click',closeForm);
dialog.addEventListener('cancel',event=>{event.preventDefault();closeForm();});
document.querySelector('#keep-editing').addEventListener('click',()=>discardDialog.close());
document.querySelector('#discard').addEventListener('click',()=>{discardDialog.close();dialog.close();dirty=false;});
for (const input of form.querySelectorAll('[inputmode=decimal]')) {
  input.addEventListener('input',()=>{
    const valid = /^[0-9]{0,10}([.,][0-9]{0,2})?$/.exec(input.value);
    if(valid && valid[0].length===input.value.length) input.dataset.previous=input.value;
    else input.value=input.dataset.previous||'';
  });
}
form.addEventListener('input',()=>{dirty=true;document.querySelector('#form-error').textContent='';for(const input of form.querySelectorAll('[aria-invalid]')) input.removeAttribute('aria-invalid');});
form.addEventListener('submit',event=>{
  event.preventDefault(); const fields=new FormData(form);
  try {
    if(!form.checkValidity()) {
      const invalid=form.querySelector(':invalid'); invalid?.setAttribute('aria-invalid','true'); invalid?.focus();
      throw new Error('Заполните даты, время, сумму и комиссию.');
    }
    const start=`${fields.get('start-date')}T${fields.get('start-time')}:00+05:00`;
    const end=`${fields.get('end-date')}T${fields.get('end-time')}:00+05:00`;
    if(!Number.isFinite(Date.parse(start))||!Number.isFinite(Date.parse(end))) throw new Error('Выберите дату и время поездки.');
    if(Date.parse(end)<=Date.parse(start)) throw new Error('Окончание должно быть позже начала.');
    const amount=minor(fields.get('amount')),commission=minor(fields.get('commission'));
    if(amount<=0) throw new Error('Сумма должна быть больше нуля.');
    if(commission>amount) throw new Error('Комиссия не может превышать сумму.');
    trips.push({id:crypto.randomUUID(),start,end,amount,commission,payment:fields.get('payment')});
    day=String(fields.get('start-date')); render(); dialog.close(); dirty=false;
    const toast=document.querySelector('#toast');clearTimeout(toastTimer);toast.hidden=false;
    toastTimer=setTimeout(()=>toast.hidden=true,4000);
  } catch(error) {document.querySelector('#form-error').textContent=error.message;}
});
render();
