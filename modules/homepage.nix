# Builds the homepage: one self-contained HTML file, with no fonts, icons or
# scripts fetched from the internet. Called from web.nix; not a NixOS module.
{
  config,
  lib,
  pkgs,
}:
let
  cfg = config.nixcentre;
  inherit (cfg.lan) address;
  hostName = config.networking.hostName;
  esc = lib.escapeXML;
  apps = lib.sortOn (app: app.order) (lib.attrValues cfg.apps);

  appCard = app: ''
    <a class="app" href="http://${address}:${toString app.port}/" data-port="${toString app.port}" data-sub="${esc app.subdomain}">
      <span class="icon" aria-hidden="true">${app.icon}</span>
      <h2>${esc app.title}</h2>
      <p>${esc app.description}</p>
      <span class="addr">App address: ${address}:${toString app.port}</span>
    </a>
  '';
in
pkgs.writeTextDir "index.html" ''
  <!doctype html>
  <html lang="en">
  <head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${esc hostName}</title>
  <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🏠</text></svg>">
  <style>
    :root {
      --bg: #f5f4ef; --card: #ffffff; --text: #1d1d1f; --muted: #66666d;
      --accent: #2f6fdb; --border: #e2e0d8;
      color-scheme: light dark;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #131315; --card: #1e1e22; --text: #ececf0; --muted: #a2a2aa;
        --accent: #7ea8ff; --border: #2e2e35;
      }
    }
    * { box-sizing: border-box; }
    body {
      margin: 0; background: var(--bg); color: var(--text); line-height: 1.5;
      font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    }
    main { max-width: 960px; margin: 0 auto; padding: 40px 16px 56px; }
    h1 { font-size: 2rem; margin: 0; letter-spacing: -0.02em; }
    .tagline { color: var(--muted); margin: 4px 0 28px; }
    .apps {
      display: grid; gap: 14px;
      grid-template-columns: repeat(auto-fill, minmax(min(210px, 100%), 1fr));
    }
    .app {
      display: flex; flex-direction: column; gap: 4px; padding: 18px;
      background: var(--card); border: 1px solid var(--border); border-radius: 14px;
      color: inherit; text-decoration: none;
      transition: transform .12s ease, border-color .12s ease;
    }
    .app:hover, .app:focus-visible { border-color: var(--accent); transform: translateY(-2px); outline: none; }
    .icon { font-size: 2rem; line-height: 1; }
    .app h2 { font-size: 1.15rem; margin: 8px 0 0; }
    .app p { margin: 0 0 8px; color: var(--muted); font-size: .95rem; flex: 1; }
    .addr, code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
    .addr { font-size: .8rem; color: var(--muted); }
    h3 { font-size: 1.05rem; margin: 40px 0 8px; }
    section p, li { color: var(--muted); }
    code {
      color: var(--text); font-size: .9em; background: var(--card);
      border: 1px solid var(--border); border-radius: 6px; padding: 1px 6px;
      overflow-wrap: anywhere;
    }
    ul { padding-left: 20px; margin: 8px 0; }
    li { margin: 4px 0; }
    footer { margin-top: 40px; font-size: .9rem; color: var(--muted); }
  </style>
  </head>
  <body>
  <main>
    <h1>${esc hostName}</h1>
    <p class="tagline">Your home library. No internet needed.</p>

    <nav class="apps">
  ${lib.concatMapStrings appCard apps}
    </nav>

    <section>
      <h3>Adding files</h3>
      <p>
        Open the shared folder <code>\\${esc hostName}\media</code> in Windows Explorer
        or <code>smb://${esc hostName}.local/media</code> in the macOS Finder
        (Go &rarr; Connect to Server), and log in with your server username and Samba password.
        Drop files into the matching folder:
      </p>
      <ul>
        <li><code>movies</code>: one folder per film, like <code>Arrival (2016)/Arrival (2016).mkv</code></li>
        <li><code>shows</code>: <code>Show Name/Season 01/Show Name S01E01.mkv</code></li>
        <li><code>books</code>: ebooks and comics, one folder per series or author</li>
        <li><code>audiobooks</code>: <code>Author/Book Title/</code> with the audio files inside</li>
        <li><code>wikipedia</code>: <code>.zim</code> files from library.kiwix.org</li>
      </ul>
    </section>

    <footer>
      Bookmark <code>http://${address}</code>. It works even when names like
      <code>${esc hostName}.${esc cfg.domain}</code> don't.
    </footer>
  </main>
  <script>
    // On the home domain, link apps by name (tv.home.arpa); on an IP address or
    // nixcentre.local, link them by port, which needs no DNS at all.
    (function () {
      var domain = "${cfg.domain}";
      var host = location.hostname;
      var byName = host === domain || host.slice(-(domain.length + 1)) === "." + domain;
      document.querySelectorAll("a[data-port]").forEach(function (a) {
        a.href = byName
          ? "http://" + a.dataset.sub + "." + domain + "/"
          : "http://" + host + ":" + a.dataset.port + "/";
      });
    })();
  </script>
  </body>
  </html>
''
