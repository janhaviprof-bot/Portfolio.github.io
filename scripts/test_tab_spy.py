"""Headless test for NewsInHurry desk nav tab highlighting."""
import json
from playwright.sync_api import sync_playwright

URL = "http://127.0.0.1:8000/Projects/NewsInHurry/index.html"
LOG_PATH = "debug-d7592d.log"


def active_labels(page):
    return page.evaluate(
        """() => [...document.querySelectorAll('.nh-desk-nav a.is-active')].map(a => a.textContent.trim())"""
    )


def spy_state(page):
    return page.evaluate(
        """() => {
            const header = document.querySelector('.nh-portfolio-bar').offsetHeight
                + document.querySelector('.nh-desk-nav-bar').offsetHeight;
            const ids = ['story','features','agents','process','architecture','systems'];
            const headings = {};
            ids.forEach(id => {
                const el = document.getElementById(id);
                const h = el.querySelector('h2') || el;
                const r = h.getBoundingClientRect();
                headings[id] = { top: Math.round(r.top), bottom: Math.round(r.bottom) };
            });
            return {
                scrollY: Math.round(window.pageYOffset),
                header,
                active: [...document.querySelectorAll('.nh-desk-nav a.is-active')].map(a => a.textContent.trim()),
                headings,
                lockedId: window.__lockedId || null,
            };
        }"""
    )


def main():
    results = []
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        page.goto(URL, wait_until="networkidle")
        page.evaluate("localStorage.removeItem('debug-d7592d')")

        # Expose lockedId if script sets it - inject hook after load
        page.add_init_script(
            """
            window.__lockedId = null;
            const _orig = Object.getOwnPropertyDescriptor;
            """
        )

        results.append({"step": "initial", **spy_state(page)})

        for tab in ["Features", "Signal Studio", "Pipeline", "Systems view"]:
            page.click(f'.nh-desk-nav a:has-text("{tab}")')
            page.wait_for_timeout(2000)
            state = spy_state(page)
            state["step"] = f"after_click_{tab.replace(' ', '_')}"
            state["expected"] = tab
            state["pass"] = tab in state["active"]
            results.append(state)

        page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
        page.wait_for_timeout(800)
        state = spy_state(page)
        state["step"] = "bottom"
        state["pass"] = "Systems view" in state["active"]
        results.append(state)

        logs = page.evaluate("() => JSON.parse(localStorage.getItem('debug-d7592d') || '[]')")
        browser.close()

    with open(LOG_PATH, "w", encoding="utf-8") as f:
        for entry in results:
            f.write(json.dumps({"sessionId": "d7592d", "source": "playwright", **entry}) + "\n")
        for entry in logs[-20:]:
            f.write(json.dumps(entry) + "\n")

    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
