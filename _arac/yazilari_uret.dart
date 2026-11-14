// Blog yazılarını üretir.
//
// Kullanım (site klasöründen):   dart run _arac/yazilari_uret.dart
//
// _kaynak/*.md dosyalarındaki yazıları okur ve şunları yazar:
//   yazilar/<slug>/index.html   her yazı için bir sayfa
//   yazilar/index.html          bütün yazıların listesi
//   yazilar/stil.css            yazı sayfalarının ortak görünümü
//   sitemap.xml, robots.txt
//
// Yeni yazı eklemek için _kaynak klasörüne aynı biçimde bir .md dosyası
// koyup bu aracı yeniden çalıştırmak yeterli. Yazıya "- tarih: 2026-12-01"
// satırı eklenirse o tarih kullanılır; yoksa aşağıdaki varsayılan tarih.

import 'dart:convert';
import 'dart:io';

const site = 'https://www.dostumingilizce.com';
const varsayilanTarih = '2026-11-14';
const playTaban =
    'https://play.google.com/store/apps/details?id=com.dostum.ingilizce';
const appStore = 'https://apps.apple.com/tr/app/id6828153724';

const aylar = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
];

class Yazi {
  String slug = '', baslik = '', aciklama = '', tarih = varsayilanTarih;
  String h1 = '', govde = '';
  String get adres => '$site/yazilar/$slug/';
  String get tarihYazi {
    final p = tarih.split('-').map(int.parse).toList();
    return '${p[2]} ${aylar[p[1] - 1]} ${p[0]}';
  }
}

String kacis(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String nitelik(String s) => kacis(s).replaceAll('"', '&quot;');

String satirIci(String s) => kacis(s).replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*'), (m) => '<strong>${m[1]}</strong>');

List<String> hucreler(String satir) {
  var s = satir.trim();
  if (s.startsWith('|')) s = s.substring(1);
  if (s.endsWith('|')) s = s.substring(0, s.length - 1);
  return s.split('|').map((h) => h.trim()).toList();
}

/// Yazı metnini (basit Markdown) HTML'e çevirir. İlk "# " satırı h1 olarak
/// ayrı döner.
(String, String) cevir(List<String> satirlar) {
  final b = StringBuffer();
  var h1 = '';
  var i = 0;
  while (i < satirlar.length) {
    final s = satirlar[i].trimRight();
    if (s.trim().isEmpty) {
      i++;
    } else if (s.startsWith('### ')) {
      b.writeln('<h3>${satirIci(s.substring(4))}</h3>');
      i++;
    } else if (s.startsWith('## ')) {
      b.writeln('<h2>${satirIci(s.substring(3))}</h2>');
      i++;
    } else if (s.startsWith('# ')) {
      h1 = s.substring(2).trim();
      i++;
    } else if (s.startsWith('|')) {
      final basliklar = hucreler(s);
      i += 2; // başlık + ayraç satırı
      b.writeln('<div class="tablo-sar"><table>');
      b.writeln(
          '<thead><tr>${basliklar.map((h) => '<th>${satirIci(h)}</th>').join()}</tr></thead>');
      b.writeln('<tbody>');
      while (i < satirlar.length && satirlar[i].trim().startsWith('|')) {
        final h = hucreler(satirlar[i]);
        b.writeln('<tr>${h.map((x) => '<td>${satirIci(x)}</td>').join()}</tr>');
        i++;
      }
      b.writeln('</tbody></table></div>');
    } else if (s.startsWith('- ')) {
      b.writeln('<ul>');
      while (i < satirlar.length && satirlar[i].startsWith('- ')) {
        b.writeln('<li>${satirIci(satirlar[i].substring(2).trim())}</li>');
        i++;
      }
      b.writeln('</ul>');
    } else {
      final p = <String>[];
      while (i < satirlar.length &&
          satirlar[i].trim().isNotEmpty &&
          !RegExp(r'^(#{1,3} |- |\|)').hasMatch(satirlar[i])) {
        p.add(satirlar[i].trim());
        i++;
      }
      b.writeln('<p>${satirIci(p.join(' '))}</p>');
    }
  }
  return (h1, b.toString());
}

List<Yazi> oku(File f) {
  final sonuc = <Yazi>[];
  final parcalar = f.readAsStringSync().replaceAll('\r\n', '\n').split(
      RegExp(r'^={10,}\s*$', multiLine: true));
  for (final parca in parcalar) {
    final satirlar = parca.split('\n');
    final ic = satirlar.indexWhere((s) => s.trim() == 'İÇERİK');
    if (ic < 0) continue;
    final y = Yazi();
    for (final s in satirlar.sublist(0, ic)) {
      final m = RegExp(r'^- ([^:]+):\s*(.+)$').firstMatch(s.trim());
      if (m == null) continue;
      final deger = m[2]!.trim();
      switch (m[1]!.trim()) {
        case 'slug':
          y.slug = deger;
        case 'başlık':
          y.baslik = deger;
        case 'meta açıklama':
          y.aciklama = deger;
        case 'tarih':
          y.tarih = deger;
      }
    }
    if (y.slug.isEmpty || y.baslik.isEmpty || y.aciklama.isEmpty) {
      stderr.writeln('UYARI: ${f.path} içinde eksik bilgili yazı atlandı.');
      continue;
    }
    final (h1, govde) = cevir(satirlar.sublist(ic + 1));
    y.h1 = h1.isEmpty ? y.baslik : h1;
    y.govde = govde;
    sonuc.add(y);
  }
  return sonuc;
}

const playSvg =
    '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="#34A853" d="M3.6 1.8 13.4 12l-9.8 10.2c-.4-.2-.6-.7-.6-1.2V3c0-.5.2-.9.6-1.2z"/><path fill="#FBBC04" d="m17 8.4-3.6 3.6L17 15.6l4.1-2.3c1.2-.7 1.2-1.9 0-2.6z"/><path fill="#4285F4" d="M3.6 22.2c.3.2.8.2 1.3-.1L17 15.6 13.4 12z"/><path fill="#EA4335" d="M3.6 1.8 13.4 12 17 8.4 4.9 1.9c-.5-.3-1-.3-1.3-.1z"/></svg>';
const appleSvg =
    '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="#fff" d="M16.4 12.6c0-2.6 2.1-3.8 2.2-3.9-1.2-1.8-3.1-2-3.7-2-1.6-.2-3.1.9-3.9.9-.8 0-2-.9-3.4-.9-1.7 0-3.3 1-4.2 2.6-1.8 3.1-.5 7.7 1.3 10.2.9 1.2 1.9 2.6 3.2 2.6 1.3-.1 1.8-.8 3.3-.8 1.6 0 2 .8 3.4.8 1.4 0 2.3-1.3 3.1-2.5 1-1.4 1.4-2.8 1.4-2.9 0 0-2.7-1-2.7-4.1zM13.9 4.9c.7-.9 1.2-2 1-3.2-1 0-2.3.7-3 1.6-.7.8-1.2 2-1.1 3.1 1.2.1 2.3-.6 3.1-1.5z"/></svg>';

/// Mağaza düğmeleri. [olay] GoatCounter olay adının son parçası,
/// [kampanya] Play bağlantısındaki utm_campaign değeri.
String dugmeler(String olay, String olayBasligi, String kampanya) => '''
<div class="dugmeler">
  <a class="magaza android" data-goatcounter-click="play-$olay" data-goatcounter-title="Google Play düğmesi ($olayBasligi)" href="$playTaban&amp;utm_source=dostumingilizce.com&amp;utm_campaign=$kampanya" rel="noopener">
    $playSvg
    <span><small>Şimdi indirin</small><b>Google Play</b></span>
  </a>
  <a class="magaza ios" data-goatcounter-click="appstore-$olay" data-goatcounter-title="App Store düğmesi ($olayBasligi)" href="$appStore" rel="noopener">
    $appleSvg
    <span><small>Şimdi indirin</small><b>App Store</b></span>
  </a>
</div>
<script>
/* Telefonda yalnızca o cihazın mağazasını göster; bilgisayarda ikisi de kalır. */
(function(){
  var u=navigator.userAgent||'';
  var android=/Android/i.test(u);
  var ios=/iPhone|iPad|iPod/i.test(u)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
  if(!android&&!ios)return;
  var gizle=document.querySelectorAll(android?'.magaza.ios':'.magaza.android');
  for(var i=0;i<gizle.length;i++)gizle[i].style.display='none';
})();
</script>''';

String bas(
        {required String baslik,
        required String aciklama,
        required String adres,
        required String ogTur,
        required List<Map<String, dynamic>> veri}) =>
    '''
<!doctype html>
<html lang="tr">
<head>
<script async src="https://www.googletagmanager.com/gtm.js?id=GTM-NDPLSR63"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
</script>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${kacis(baslik)}</title>
<meta name="description" content="${nitelik(aciklama)}">
<link rel="canonical" href="$adres">
<link rel="icon" type="image/png" href="/favicon.png">
<link rel="apple-touch-icon" href="/img/ikon.png">
<meta property="og:type" content="$ogTur">
<meta property="og:site_name" content="Dostum İngilizce">
<meta property="og:locale" content="tr_TR">
<meta property="og:title" content="${nitelik(baslik)}">
<meta property="og:description" content="${nitelik(aciklama)}">
<meta property="og:image" content="$site/img/paylasim.png">
<meta property="og:url" content="$adres">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#7c3aed">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@500;700;800;900&amp;display=swap" rel="stylesheet">
<link rel="stylesheet" href="/yazilar/stil.css">
${veri.map((v) => '<script type="application/ld+json">${jsonEncode(v).replaceAll('</', '<\\/')}</script>').join('\n')}
</head>
<body>

<header class="ust">
  <div class="kap">
    <a class="marka" href="/"><img src="/img/ikon.png" alt="" width="36" height="36">Dostum İngilizce</a>
    <nav>
      <a href="/yazilar/">Yazılar</a>
      <a class="genis" href="/">Uygulama</a>
    </nav>
  </div>
</header>
''';

const son = '''
<footer>
  <div class="kap">
    <div>© 2026 Dostum İngilizce</div>
    <div class="linkler">
      <a href="/">Ana sayfa</a>
      <a href="/yazilar/">Yazılar</a>
      <a href="/gizlilik.html">Gizlilik Politikası</a>
      <a href="mailto:dostumingilizce@dostumingilizce.com">dostumingilizce@dostumingilizce.com</a>
    </div>
  </div>
</footer>

<script data-goatcounter="https://dostumingilizce.goatcounter.com/count" async src="//gc.zgo.at/count.js"></script>
</body>
</html>
''';

const yayinci = {
  '@type': 'Organization',
  'name': 'Dostum İngilizce',
  'url': '$site/',
  'logo': {'@type': 'ImageObject', 'url': '$site/img/ikon.png'}
};

String yaziSayfasi(Yazi y, List<Yazi> digerleri) {
  final veri = [
    {
      '@context': 'https://schema.org',
      '@type': 'BlogPosting',
      'headline': y.baslik,
      'description': y.aciklama,
      'inLanguage': 'tr',
      'datePublished': y.tarih,
      'dateModified': y.tarih,
      'mainEntityOfPage': y.adres,
      'image': '$site/img/paylasim.png',
      'author': yayinci,
      'publisher': yayinci,
    },
    {
      '@context': 'https://schema.org',
      '@type': 'BreadcrumbList',
      'itemListElement': [
        {'@type': 'ListItem', 'position': 1, 'name': 'Ana sayfa', 'item': '$site/'},
        {'@type': 'ListItem', 'position': 2, 'name': 'Yazılar', 'item': '$site/yazilar/'},
        {'@type': 'ListItem', 'position': 3, 'name': y.h1, 'item': y.adres},
      ]
    }
  ];
  return '''
${bas(baslik: y.baslik, aciklama: y.aciklama, adres: y.adres, ogTur: 'article', veri: veri)}
<main class="kap dar">
  <nav class="iz" aria-label="Neredesiniz"><a href="/">Ana sayfa</a> › <a href="/yazilar/">Yazılar</a></nav>
  <article class="yazi">
    <h1>${satirIci(y.h1)}</h1>
    <p class="tarih"><time datetime="${y.tarih}">${y.tarihYazi}</time> · Dostum İngilizce</p>
${y.govde}
  </article>

  <aside class="indir">
    <img src="/img/ikon.png" alt="Dostum İngilizce simgesi" width="72" height="72" loading="lazy">
    <h2>Dostum İngilizce'yi ücretsiz indirin</h2>
    <p>Kelimeleri sesli dinleyin, oyunlarla ve hikâyelerle pekiştirin.</p>
${dugmeler('yazi-${y.slug}', 'yazı: ${y.slug}', 'yazi_${y.slug}')}
  </aside>

  <section class="diger">
    <h2>Diğer yazılar</h2>
    <ul>
${digerleri.map((d) => '      <li><a href="/yazilar/${d.slug}/">${kacis(d.baslik)}</a></li>').join('\n')}
    </ul>
    <p><a class="hepsi" href="/yazilar/">Bütün yazılar →</a></p>
  </section>
</main>

$son''';
}

String listeSayfasi(List<Yazi> yazilar) {
  const baslik = 'Yazılar: Çocuğa İngilizce Öğretme Rehberi — Dostum İngilizce';
  const aciklama =
      'Çocuğunuza evde İngilizce öğretmek için kelime listeleri, okunuşlar, oyunlar ve velilere pratik öneriler.';
  final veri = [
    {
      '@context': 'https://schema.org',
      '@type': 'Blog',
      'name': 'Dostum İngilizce Yazılar',
      'description': aciklama,
      'inLanguage': 'tr',
      'url': '$site/yazilar/',
      'publisher': yayinci,
      'blogPost': [
        for (final y in yazilar)
          {
            '@type': 'BlogPosting',
            'headline': y.baslik,
            'url': y.adres,
            'datePublished': y.tarih
          }
      ]
    }
  ];
  return '''
${bas(baslik: baslik, aciklama: aciklama, adres: '$site/yazilar/', ogTur: 'website', veri: veri)}
<main class="kap dar">
  <div class="liste-bas">
    <div class="etiket">Veliler için</div>
    <h1>Yazılar</h1>
    <p>Çocuğunuza evde İngilizce öğretirken işinize yarayacak kelime listeleri, oyunlar ve öneriler.</p>
  </div>
  <div class="kartlar">
${yazilar.map((y) => '''
    <a class="kart" href="/yazilar/${y.slug}/">
      <h2>${kacis(y.baslik)}</h2>
      <p>${kacis(y.aciklama)}</p>
      <span>Yazıyı oku →</span>
    </a>''').join('\n')}
  </div>

  <aside class="indir">
    <img src="/img/ikon.png" alt="Dostum İngilizce simgesi" width="72" height="72" loading="lazy">
    <h2>Dostum İngilizce'yi ücretsiz indirin</h2>
    <p>Kelimeleri sesli dinleyin, oyunlarla ve hikâyelerle pekiştirin.</p>
${dugmeler('yazilar-liste', 'yazılar listesi', 'yazilar_liste')}
  </aside>
</main>

$son''';
}

const stil = '''
:root{
  --mor:#7c3aed; --mor-koyu:#5b21b6; --mor-acik:#f3eefe;
  --turuncu:#f59e0b; --turuncu-koyu:#d97706; --krem:#fde68a;
  --yazi:#1f1633; --soluk:#5d5672; --cizgi:#e7e2f3; --zemin:#ffffff; --zemin2:#faf8ff;
}
*{box-sizing:border-box}
body{margin:0;background:var(--zemin);color:var(--yazi);font:18px/1.7 Nunito,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;-webkit-font-smoothing:antialiased;overflow-wrap:break-word}
img{max-width:100%;display:block}
a{color:var(--mor)}
.kap{max-width:1080px;margin:0 auto;padding:0 20px}
.kap.dar{max-width:760px}

/* Üst şerit */
.ust{position:sticky;top:0;z-index:10;background:rgba(255,255,255,.92);backdrop-filter:blur(8px);border-bottom:1px solid var(--cizgi)}
.ust .kap{display:flex;align-items:center;justify-content:space-between;gap:12px;height:64px}
.marka{display:flex;align-items:center;gap:10px;font-weight:900;font-size:19px;color:var(--yazi);text-decoration:none;white-space:nowrap}
.marka img{width:36px;height:36px;border-radius:10px}
.ust nav{display:flex;gap:20px}
.ust nav a{color:var(--soluk);text-decoration:none;font-weight:700;font-size:15px}
.ust nav a:hover{color:var(--mor)}
@media (max-width:420px){.marka{font-size:17px}.ust nav .genis{display:none}}

/* Yazı */
main{padding-top:28px;padding-bottom:64px}
.iz{font-size:14.5px;color:var(--soluk);font-weight:700;margin-bottom:18px}
.iz a{color:var(--soluk);text-decoration:none}
.iz a:hover{color:var(--mor)}
.yazi h1{font-size:clamp(30px,6vw,42px);line-height:1.15;font-weight:900;letter-spacing:-.3px;margin:0 0 10px}
.tarih{color:var(--soluk);font-size:15px;font-weight:700;margin:0 0 26px}
.yazi h2{font-size:clamp(23px,4.4vw,28px);line-height:1.25;font-weight:900;margin:42px 0 12px}
.yazi h3{font-size:clamp(19px,3.8vw,21px);line-height:1.3;font-weight:900;margin:30px 0 8px;color:var(--mor-koyu)}
.yazi p{margin:0 0 18px}
.yazi ul{margin:0 0 20px;padding-left:24px}
.yazi li{margin:8px 0}
.yazi li::marker{color:var(--mor)}
.yazi strong{font-weight:800}

/* Tablolar */
.tablo-sar{overflow-x:auto;margin:0 0 24px;border:2px solid var(--cizgi);border-radius:18px}
table{border-collapse:collapse;width:100%;font-size:17px}
th,td{text-align:left;padding:11px 16px;border-bottom:1px solid var(--cizgi)}
th{background:var(--mor-acik);color:var(--mor-koyu);font-weight:800;font-size:14px;letter-spacing:.4px;text-transform:uppercase}
tbody tr:last-child td{border-bottom:0}
tbody tr:nth-child(even){background:var(--zemin2)}
td:first-child{font-weight:800}
@media (max-width:480px){table{font-size:16px}th,td{padding:10px 12px}}

/* İndirme kutusu */
.indir{margin:48px 0 0;background:linear-gradient(150deg,#8b5cf6,#5b21b6);color:#fff;border-radius:26px;padding:34px 24px;text-align:center}
.indir img{width:72px;height:72px;border-radius:18px;margin:0 auto 14px;box-shadow:0 10px 26px rgba(30,0,70,.35)}
.indir h2{font-size:clamp(22px,4.6vw,28px);line-height:1.2;font-weight:900;margin:0 0 8px}
.indir p{margin:0 0 22px;opacity:.92}
.dugmeler{display:flex;flex-wrap:wrap;gap:12px;justify-content:center}
.magaza{display:inline-flex;align-items:center;gap:12px;background:#111;color:#fff;text-decoration:none;border-radius:14px;padding:11px 20px 11px 16px;min-width:190px;text-align:left;transition:transform .15s}
.magaza:hover{transform:translateY(-2px)}
.magaza svg{width:28px;height:28px;flex:none}
.magaza small{display:block;font-size:11.5px;opacity:.8;line-height:1.1}
.magaza b{display:block;font-size:18px;line-height:1.2}

/* Diğer yazılar */
.diger{margin-top:48px}
.diger h2{font-size:22px;font-weight:900;margin:0 0 6px}
.diger ul{list-style:none;margin:0;padding:0}
.diger li{border-bottom:1px solid var(--cizgi)}
.diger li a{display:block;padding:14px 0;font-weight:800;text-decoration:none;color:var(--yazi)}
.diger li a:hover{color:var(--mor)}
.hepsi{font-weight:800;text-decoration:none}

/* Liste sayfası */
.etiket{display:inline-block;background:var(--mor-acik);color:var(--mor);font-weight:800;font-size:13px;letter-spacing:.6px;text-transform:uppercase;padding:5px 12px;border-radius:99px;margin-bottom:14px}
.liste-bas{margin:10px 0 30px}
.liste-bas h1{font-size:clamp(32px,6vw,44px);line-height:1.1;font-weight:900;margin:0 0 10px}
.liste-bas p{color:var(--soluk);margin:0}
.kartlar{display:grid;gap:16px}
.kart{display:block;border:2px solid var(--cizgi);border-radius:22px;padding:22px 22px 20px;text-decoration:none;color:var(--yazi);transition:border-color .15s,transform .15s}
.kart:hover{border-color:var(--mor);transform:translateY(-2px)}
.kart h2{font-size:clamp(19px,4vw,22px);line-height:1.25;font-weight:900;margin:0 0 8px}
.kart p{color:var(--soluk);font-size:16px;line-height:1.55;margin:0 0 12px}
.kart span{color:var(--mor);font-weight:800;font-size:15px}

footer{background:#1b1030;color:#cfc7e3;padding:40px 0;font-size:15px}
footer .kap{display:flex;flex-wrap:wrap;gap:16px 28px;justify-content:space-between;align-items:center}
footer a{color:#fff;text-decoration:none;font-weight:700}
footer a:hover{text-decoration:underline}
footer .linkler{display:flex;flex-wrap:wrap;gap:10px 22px}
''';

void yaz(String yol, String icerik) {
  final f = File(yol);
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(icerik.replaceAll('\r\n', '\n'));
}

void main() {
  if (!File('index.html').existsSync() || !Directory('_kaynak').existsSync()) {
    stderr.writeln('Bu araç site klasöründen çalıştırılmalı.');
    exit(1);
  }
  final dosyalar = Directory('_kaynak')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.md'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final yazilar = <Yazi>[for (final f in dosyalar) ...oku(f)];
  final sluglar = <String>{};
  for (final y in yazilar) {
    if (!sluglar.add(y.slug)) {
      stderr.writeln('HATA: aynı slug iki kez var: ${y.slug}');
      exit(1);
    }
  }

  for (var i = 0; i < yazilar.length; i++) {
    final digerleri = [
      for (var k = 1; k <= 3 && k < yazilar.length; k++)
        yazilar[(i + k) % yazilar.length]
    ];
    yaz('yazilar/${yazilar[i].slug}/index.html',
        yaziSayfasi(yazilar[i], digerleri));
  }
  yaz('yazilar/index.html', listeSayfasi(yazilar));
  yaz('yazilar/stil.css', stil.trimLeft());

  final enYeni = yazilar.map((y) => y.tarih).reduce((a, b) => a.compareTo(b) > 0 ? a : b);
  final harita = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
    ..writeln('  <url><loc>$site/</loc><lastmod>$enYeni</lastmod></url>')
    ..writeln('  <url><loc>$site/yazilar/</loc><lastmod>$enYeni</lastmod></url>');
  for (final y in yazilar) {
    harita.writeln('  <url><loc>${y.adres}</loc><lastmod>${y.tarih}</lastmod></url>');
  }
  harita
    ..writeln('  <url><loc>$site/gizlilik.html</loc></url>')
    ..writeln('</urlset>');
  yaz('sitemap.xml', harita.toString());
  yaz('robots.txt', 'User-agent: *\nAllow: /\n\nSitemap: $site/sitemap.xml\n');

  stdout.writeln('${yazilar.length} yazı üretildi.');
}
