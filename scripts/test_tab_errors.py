import json
from playwright.sync_api import sync_playwright

errors = []
with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.on("pageerror", lambda e: errors.append(str(e)))
    page.goto("http://127.0.0.1:8000/Projects/NewsInHurry/index.html?t=4", wait_until="networkidle")
    ready = page.evaluate("() => !!window.__nhNavReady")
    page.click('.nh-desk-nav a[href="#features"]')
    page.wait_for_timeout(500)
    manual = page.evaluate(
        """() => {
      document.querySelectorAll('.nh-desk-nav a').forEach(function(l) {
        l.classList.toggle('is-active', l.getAttribute('href') === '#features');
      });
      return [...document.querySelectorAll('.nh-desk-nav a.is-active')].map(a => a.textContent.trim());
    }"""
    )
    browser.close()

print("ready:", ready)
print("errors:", errors)
print("manual active:", manual)
