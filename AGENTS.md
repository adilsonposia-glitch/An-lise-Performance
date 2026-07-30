# AGENTS.md

## Cursor Cloud specific instructions

This repository is a **fully static, single-page dashboard** ("Performance Comercial · Sexta a Quinta · Ano × Ano"), written in vanilla HTML/CSS/JS. There is **no package manager, build step, bundler, test suite, or linter** — the files in the repo root are served as-is.

### Structure
- `index.html` — page shell; loads `data.js` then `app.js` via `<script>` tags.
- `app.js` — all dashboard logic (phase navigation, filtering, sorting, rendering). Wrapped in an IIFE, reads `window.PERFORMANCE_DATA`.
- `data.js` — sets `window.PERFORMANCE_DATA` (pre-processed from the `*.xlsx` files). `data.json` is a standalone copy of the same data (not loaded by the page).
- `styles.css`, `LogoABB.jpeg`, `*.xlsx`, `referencia dash semanal.jpg` — assets/source data.

### Run (development)
Serve the repo root over HTTP and open `index.html`:
```
python3 -m http.server 8000
# then open http://localhost:8000/index.html
```
Opening via `file://` also works since the page only uses relative `<script>`/asset paths (no `fetch`), but serving over HTTP is the standard dev workflow.

### Lint / test / build
None exist. There is nothing to lint, test, or build. Verification is done by loading the page in a browser and exercising the UI (search box, `Progressão`/`Regressão` chips, `Todas as lojas`/`Mesma base` toggle, and the sidebar phase buttons: Departamentos, Lojas, Seção, Grupos).

### Data notes
- `data.js` is large (~1.1 MB) and is committed directly; it is the source of truth the page reads.
- The dashboard is Portuguese (`pt-BR`); expect Portuguese labels/messages (e.g. empty filter shows "Nenhum item…").
