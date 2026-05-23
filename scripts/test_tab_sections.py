import json
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.goto("http://127.0.0.1:8000/Projects/NewsInHurry/index.html?t=5", wait_until="networkidle")
    r = page.evaluate(
        """() => {
      const links = [...document.querySelectorAll('.nh-desk-nav a')];
      const mapped = links.map(l => {
        const href = l.getAttribute('href');
        const id = href && href.charAt(0) === '#' ? href.slice(1) : null;
        return { href, id, found: id ? !!document.getElementById(id) : false };
      });
      return {
        ready: !!window.__nhNavReady,
        err: window.__nhNavError || null,
        linkCount: links.length,
        mapped
      };
    }"""
    )
    print(json.dumps(r, indent=2))
    browser.close()
