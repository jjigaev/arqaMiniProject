'use strict';
const names = {solar: 'A · Солнечная смена', lagoon: 'B · Лагуна', route: 'C · Маршрут'};
const frame = document.querySelector('#preview');
for (const button of document.querySelectorAll('[data-theme]')) {
  button.addEventListener('click', () => {
    const theme = button.dataset.theme;
    for (const peer of document.querySelectorAll('[data-theme]')) peer.setAttribute('aria-pressed', String(peer === button));
    frame.src = `preview.html?theme=${theme}`;
    frame.title = `Интерактивный макет: ${names[theme]}`;
    document.querySelector('#direction').textContent = names[theme];
    document.querySelector('#standalone').href = frame.src;
  });
}
for (const button of document.querySelectorAll('[data-device]')) {
  button.addEventListener('click', () => {
    for (const peer of document.querySelectorAll('[data-device]')) peer.setAttribute('aria-pressed', String(peer === button));
    document.querySelector('#stage').classList.toggle('mobile', button.dataset.device === 'mobile');
  });
}
