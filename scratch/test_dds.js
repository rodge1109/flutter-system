const http = require('http');

const urls = [
  'http://127.0.0.1:50665/p_KjycqY3eo=/getVM',
  'http://127.0.0.1:50664/p_KjycqY3eo=/getVM',
  'http://127.0.0.1:50664/34Ul73gyUXc=/getVM',
  'http://127.0.0.1:44456/34Ul73gyUXc=/getVM'
];

urls.forEach(url => {
  http.get(url, res => {
    let d = '';
    res.on('data', c => d += c);
    res.on('end', () => console.log('GET', url, '-> Status:', res.statusCode, d.substring(0, 100)));
  }).on('error', err => console.log('GET', url, '-> Error:', err.message));
});
