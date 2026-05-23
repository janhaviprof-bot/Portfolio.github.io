import json
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.goto("http://127.0.0.1:8000/Projects/NewsInHurry/index.html?t=3", wait_until="networkidle")
    page.click('.nh-desk-nav a[href="#features"]')
    page.wait_for_timeout(2500)
    r = page.evaluate(
        """() => {
      const bar = document.querySelector('.nh-portfolio-bar').offsetHeight
        + document.querySelector('.nh-desk-nav-bar').offsetHeight;
      const trigger = bar + (window.innerHeight - bar) * 0.38;
      const ids = ['story','features','agents','process','architecture','systems'];
      const tops = {};
      let picked = 'story';
      for (let i = ids.length - 1; i >= 0; i--) {
        const el = document.getElementById(ids[i]);
        const h = el.querySelector('h2') || el;
        tops[ids[i]] = Math.round(h.getBoundingClientRect().top);
        if (h.getBoundingClientRect().top <= trigger) { picked = ids[i]; break; }
      }
      const links = [...document.querySelectorAll('.nh-desk-nav a')].map(a => ({
        text: a.textContent.trim(),
        href: a.getAttribute('href'),
        active: a.classList.contains('is-active')
      }));
      const errs = window.__navErr || null;
      return { trigger: Math.round(trigger), tops, picked, links, errs };
    }"""
    )
    print(json.dumps(r, indent=2))
    browser.close()
