(() => {
  "use strict";

  const WEEK_LABELS = ["1ª Semana", "2ª Semana", "3ª Semana", "4ª Semana"];

  const state = {
    bundle: null,
    data: null, // semana ativa (payload com meta/storeMeta/phases)
    weekOrdem: 1,
    phaseKey: "departamentos",
    filter: "todos",
    search: "",
    sortKey: "deltaLucro",
    sortDir: "asc",
    storeBase: "mesma",
    metric: "venda", // 'venda' | 'lucro' | 'clientes'
    selectedNome: null,
  };

  const els = {
    phaseNav: document.getElementById("phaseNav"),
    phaseTitle: document.getElementById("phaseTitle"),
    phaseSubtitle: document.getElementById("phaseSubtitle"),
    execSummary: document.getElementById("execSummary"),
    bestList: document.getElementById("bestList"),
    bestTitle: document.getElementById("bestTitle"),
    bestHint: document.getElementById("bestHint"),
    aggressorList: document.getElementById("aggressorList"),
    aggressorTitle: document.getElementById("aggressorTitle"),
    aggressorHint: document.getElementById("aggressorHint"),
    tableHead: document.getElementById("tableHead"),
    tableBody: document.getElementById("tableBody"),
    tableTitle: document.getElementById("tableTitle"),
    searchInput: document.getElementById("searchInput"),
    detailPanel: document.getElementById("detailPanel"),
    tableExpandBtn: document.getElementById("tableExpandBtn"),
    storeBaseGroup: document.getElementById("storeBaseGroup"),
    storeBaseNote: document.getElementById("storeBaseNote"),
    metricGroup: document.getElementById("metricGroup"),
    salesChart: document.getElementById("salesChart"),
    chartTitle: document.getElementById("chartTitle"),
    chartSubtitle: document.getElementById("chartSubtitle"),
    trendGrid: document.getElementById("trendGrid"),
    trendScope: document.getElementById("trendScope"),
    trendClear: document.getElementById("trendClear"),
    weekGroup: document.getElementById("weekGroup"),
    weekBarHint: document.getElementById("weekBarHint"),
    emptyWeekPanel: document.getElementById("emptyWeekPanel"),
    emptyWeekTitle: document.getElementById("emptyWeekTitle"),
    emptyWeekMessage: document.getElementById("emptyWeekMessage"),
    analysisContent: document.getElementById("analysisContent"),
    periodTitle: document.getElementById("periodTitle"),
    periodDetail: document.getElementById("periodDetail"),
    footerMeta: document.getElementById("footerMeta"),
  };

  const icons = {
    cart: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 4h2l2.4 11.2a2 2 0 0 0 2 1.6h7.8a2 2 0 0 0 2-1.5L21 8H7"/><circle cx="10" cy="20" r="1.4"/><circle cx="18" cy="20" r="1.4"/></svg>`,
    checkout: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="6" width="18" height="10" rx="2"/><path d="M7 11h5M15 9.5h3v3h-3z"/><path d="M7 18v2M17 18v2"/></svg>`,
    offer: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="5" y="3" width="14" height="18" rx="2"/><path d="M8 8h8M8 12h8M8 16h5"/><path d="M12 3v2"/></svg>`,
    money: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="8"/><path d="M12 7v10M9.5 9.5c.6-1 1.5-1.5 2.5-1.5 1.7 0 3 1 3 2.5S13.7 13 12 13s-3 1-3 2.5 1.3 2.5 3 2.5c1 0 1.9-.5 2.5-1.5"/></svg>`,
    clients: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="9" cy="8" r="3"/><circle cx="17" cy="9" r="2.4"/><path d="M3.5 18c.8-2.8 3-4.5 5.5-4.5s4.7 1.7 5.5 4.5"/><path d="M14 18c.4-1.8 1.7-3 3.4-3 1.2 0 2.2.6 2.9 1.6"/></svg>`,
  };

  const brl = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL", maximumFractionDigits: 0 });
  const brlDec = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL", maximumFractionDigits: 2 });
  const num = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 0 });
  const numDec = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 1 });

  const GAUGE_LEN = 251.2; // approx pi * 80

  function fmtMoney(v, compact = true) {
    if (v == null || Number.isNaN(v)) return "—";
    return compact ? brl.format(v) : brlDec.format(v);
  }

  function fmtPct(v) {
    if (v == null || Number.isNaN(v)) return "—";
    const sign = v > 0 ? "+" : "";
    return `${sign}${(v * 100).toFixed(1)}%`;
  }

  function fmtPp(v) {
    if (v == null || Number.isNaN(v)) return "—";
    const sign = v > 0 ? "+" : "";
    return `${sign}${Number(v).toFixed(2)} p.p.`;
  }

  function deltaClass(v) {
    if (v == null || Number.isNaN(v) || Math.abs(v) < 1e-9) return "flat";
    return v > 0 ? "up" : "down";
  }

  function cleanName(name) {
    return String(name || "").replace(/\s*\(\d+\)\s*$/, "").trim();
  }

  function escAttr(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;")
      .replace(/</g, "&lt;");
  }

  const phaseLabels = {
    departamentos: "Departamentos",
    lojas: "Lojas",
    secao: "Mercadológico — Seção",
    grupos: "Mercadológico — Grupos",
  };

  function weekLabel(ordem) {
    return WEEK_LABELS[ordem - 1] || `${ordem}ª Semana`;
  }

  function emptyWeekSlot(ordem) {
    return {
      key: `semana-${ordem}`,
      label: weekLabel(ordem),
      ordem,
      hasData: false,
      meta: null,
      storeMeta: null,
      phases: null,
    };
  }

  /** Aceita formato antigo (meta/phases no root) ou bundle de 4 semanas. */
  function normalizeBundle(raw) {
    if (!raw) return null;

    if (Array.isArray(raw.weeks)) {
      const weeks = [];
      for (let i = 1; i <= 4; i++) {
        const found = raw.weeks.find((w) => Number(w.ordem) === i) || raw.weeks[i - 1];
        if (found && found.hasData && found.phases) {
          weeks.push({
            key: found.key || `semana-${i}`,
            label: found.label || weekLabel(i),
            ordem: i,
            hasData: true,
            meta: found.meta || null,
            storeMeta: found.storeMeta || null,
            phases: found.phases,
          });
        } else {
          weeks.push(emptyWeekSlot(i));
        }
      }
      return {
        maxWeeks: 4,
        selectedWeek: Number(raw.selectedWeek) || weeks.find((w) => w.hasData)?.ordem || 1,
        weeks,
      };
    }

    if (raw.phases) {
      return {
        maxWeeks: 4,
        selectedWeek: 1,
        weeks: [
          {
            key: "semana-1",
            label: weekLabel(1),
            ordem: 1,
            hasData: true,
            meta: raw.meta || null,
            storeMeta: raw.storeMeta || null,
            phases: raw.phases,
          },
          emptyWeekSlot(2),
          emptyWeekSlot(3),
          emptyWeekSlot(4),
        ],
      };
    }

    return null;
  }

  function currentWeek() {
    return state.bundle?.weeks?.find((w) => w.ordem === state.weekOrdem) || null;
  }

  function applyWeek(ordem) {
    state.weekOrdem = ordem;
    const week = currentWeek();
    state.data = week?.hasData
      ? { meta: week.meta, storeMeta: week.storeMeta, phases: week.phases }
      : null;
  }

  function shortPeriod(periodo) {
    if (!periodo) return "";
    // "17/07/2026 a 23/07/2026" → "17–23/07/2026"
    const m = String(periodo).match(/(\d{2})\/(\d{2})\/(\d{4})\s*a\s*(\d{2})\/(\d{2})\/(\d{4})/i);
    if (!m) return String(periodo);
    if (m[2] === m[5] && m[3] === m[6]) return `${m[1]}–${m[4]}/${m[2]}/${m[3]}`;
    return `${m[1]}/${m[2]}–${m[4]}/${m[5]}/${m[6]}`;
  }

  function updateWeekUi() {
    const weeks = state.bundle?.weeks || [];
    const filled = weeks.filter((w) => w.hasData).length;

    if (els.weekBarHint) {
      els.weekBarHint.textContent = `${filled} de 4 semanas com dados · Sex→Qui`;
    }

    if (els.weekGroup) {
      els.weekGroup.querySelectorAll("[data-week]").forEach((btn) => {
        const ordem = Number(btn.dataset.week);
        const week = weeks.find((w) => w.ordem === ordem) || emptyWeekSlot(ordem);
        const active = ordem === state.weekOrdem;
        btn.classList.toggle("active", active);
        btn.classList.toggle("empty-week", !week.hasData);
        btn.innerHTML = week.hasData
          ? `${week.label}`
          : `${week.label}<span class="week-status">sem dados</span>`;
        btn.title = week.hasData
          ? `${week.label} · ${week.meta?.periodo2026 || "com dados"}`
          : `${week.label} · Sem dados`;
      });
    }

    const week = currentWeek();
    const hasData = !!(week && week.hasData && state.data);

    if (els.emptyWeekPanel) els.emptyWeekPanel.classList.toggle("hidden", hasData);
    if (els.analysisContent) els.analysisContent.classList.toggle("hidden", !hasData);

    if (!hasData) {
      const label = week?.label || weekLabel(state.weekOrdem);
      if (els.emptyWeekTitle) els.emptyWeekTitle.textContent = label;
      if (els.emptyWeekMessage) els.emptyWeekMessage.textContent = "Sem dados";
      if (els.phaseTitle) els.phaseTitle.textContent = `${label} · Sem dados`;
      if (els.phaseSubtitle) {
        els.phaseSubtitle.textContent =
          "Esta semana ainda não possui análise carregada. Os dados das semanas preenchidas permanecem disponíveis no filtro.";
      }
      if (els.periodTitle) els.periodTitle.textContent = label;
      if (els.periodDetail) els.periodDetail.textContent = "Sem dados";
      if (els.storeBaseNote) els.storeBaseNote.textContent = "";
      if (els.footerMeta) els.footerMeta.textContent = `${label} · Sem dados`;
      return false;
    }

    const meta = week.meta || {};
    if (els.periodTitle) {
      els.periodTitle.textContent = `${meta.anoAtual || 2026} × ${meta.anoBase || 2025}`;
    }
    if (els.periodDetail) {
      const atual = shortPeriod(meta.periodo2026);
      const base = shortPeriod(meta.periodo2025);
      els.periodDetail.textContent =
        atual && base ? `${atual} vs ${base}` : meta.periodoLabel || "Comparativo semanal";
    }
    if (els.footerMeta) {
      els.footerMeta.textContent = `${week.label} · ${meta.periodo2026 || "YoY"} · Inteligência de negócio`;
    }
    return true;
  }

  function isNewStore(row) {
    return Boolean(row.nova) || (Number(row.venda2025) <= 0 && Number(row.venda2026) > 0);
  }

  function getStoreMeta() {
    const meta = state.data?.storeMeta;
    if (!meta) return null;
    return {
      allCount: meta.allCount,
      comparableCount: meta.comparableCount,
      novasCount: meta.novasCount,
      novasNames: (meta.novasNames || []).map(cleanName),
    };
  }

  function currentPhase() {
    if (!state.data?.phases) return null;
    const phase = state.data.phases.find((p) => p.key === state.phaseKey);
    if (!phase) return null;
    const baseKey = state.storeBase === "mesma" ? "mesma" : "todas";
    const base = phase.bases?.[baseKey];
    if (!base) return null;
    const suffix = baseKey === "mesma" ? "Mesma base" : "Todas as lojas";
    return {
      key: phase.key,
      label: `${phaseLabels[phase.key] || phase.label} · ${suffix}`,
      hasClients: !!phase.hasClients,
      rows: base.rows || [],
      totals: base.totals,
      melhores: base.melhores || [],
      agressores: base.agressores || [],
      baseMeta: getStoreMeta(),
    };
  }

  function updateStoreBaseUi(phase) {
    document.querySelectorAll("[data-store-base]").forEach((btn) => {
      btn.classList.toggle("active", btn.dataset.storeBase === state.storeBase);
    });

    const meta = phase?.baseMeta || getStoreMeta();
    if (!meta) {
      els.storeBaseNote.textContent = "";
      return;
    }

    const { comparableCount, novasCount, novasNames, allCount } = meta;
    const novasTxt = novasNames.length ? ` (${novasNames.join(", ")})` : "";
    const phaseName = phaseLabels[state.phaseKey] || "esta visão";

    if (state.storeBase === "mesma") {
      els.storeBaseNote.innerHTML = `<strong>Mesma base:</strong> cálculos de <em>${phaseName}</em> com ${comparableCount} lojas comparáveis. Excluídas ${novasCount} loja(s) sem venda em 2025${novasTxt}.`;
    } else {
      els.storeBaseNote.innerHTML = `<strong>Todas as lojas:</strong> cálculos de <em>${phaseName}</em> com ${allCount} lojas, incluindo ${novasCount} sem base no ano anterior${novasTxt ? ` — ${novasNames.join(", ")}` : ""}.`;
    }
  }

  function sameItem(a, b) {
    if (!a || !b) return false;
    return a === b || cleanName(a) === cleanName(b);
  }

  function shortWeekTick(periodo) {
    const m = String(periodo || "").match(/(\d{2})\/(\d{2})\/(\d{4})/);
    return m ? `${m[1]}/${m[2]}` : "—";
  }

  function weekBase(week) {
    if (!week?.hasData || !week.phases) return null;
    const phase = week.phases.find((p) => p.key === state.phaseKey);
    if (!phase) return null;
    const baseKey = state.storeBase === "mesma" ? "mesma" : "todas";
    return phase.bases?.[baseKey] || null;
  }

  function collectTrend() {
    const weeks = state.bundle?.weeks || [];
    return weeks.map((w) => {
      const base = weekBase(w);
      const tick = shortWeekTick(w.meta?.periodo2026);
      const empty = {
        ordem: w.ordem,
        tick,
        missing: true,
        venda: null,
        venda25: null,
        clientes: null,
        clientes25: null,
        margem: null,
        margem25: null,
        lucro: null,
        lucro25: null,
        hasClients: false,
      };
      if (!base) return empty;
      let src = base.totals;
      if (state.selectedNome) {
        const row = (base.rows || []).find((r) => sameItem(r.nome, state.selectedNome));
        if (!row) return empty;
        src = row;
      }
      return {
        ordem: w.ordem,
        tick,
        missing: false,
        venda: src.venda2026,
        venda25: src.venda2025,
        clientes: src.clientes2026,
        clientes25: src.clientes2025,
        margem: src.margem2026,
        margem25: src.margem2025,
        lucro: src.lucro2026,
        lucro25: src.lucro2025,
        varVendaPct: src.varVendaPct,
        varClientesPct: src.varClientesPct,
        varMargemPp: src.varMargemPp,
        varLucroPct: src.varLucroPct,
        hasClients: src.clientes2026 != null || src.clientes2025 != null,
      };
    });
  }

  function setGauge(arcEl, needleEl, ratio) {
    if (!arcEl || !needleEl) return;
    const r = Math.max(0, Math.min(1, ratio));
    arcEl.style.strokeDasharray = String(GAUGE_LEN);
    arcEl.style.strokeDashoffset = String(GAUGE_LEN * (1 - r));
    const angle = -90 + r * 180;
    needleEl.style.transform = `rotate(${angle}deg)`;
  }

  function sparkSvg(series26, series25, activeIdx) {
    const w = 220;
    const h = 52;
    const pad = 7;
    const nums = [...series26, ...(series25 || [])].filter((v) => v != null && !Number.isNaN(Number(v)));
    if (!nums.length) return `<div class="trend-empty">Sem série nas 4 semanas</div>`;
    const min = Math.min(...nums);
    const max = Math.max(...nums);
    const span = max - min || Math.abs(max) * 0.08 || 1;
    const lo = min - span * 0.14;
    const hi = max + span * 0.14;
    const n = series26.length;
    const xAt = (i) => pad + (i * (w - pad * 2)) / Math.max(n - 1, 1);
    const yAt = (v) => h - pad - ((Number(v) - lo) / (hi - lo)) * (h - pad * 2);
    const toPts = (arr) =>
      arr
        .map((v, i) => (v == null || Number.isNaN(Number(v)) ? null : `${xAt(i).toFixed(1)},${yAt(v).toFixed(1)}`))
        .filter(Boolean)
        .join(" ");
    const prev = series25 && series25.some((v) => v != null) ? `<polyline class="spark-line prev" points="${toPts(series25)}"></polyline>` : "";
    const dots = series26
      .map((v, i) => {
        if (v == null || Number.isNaN(Number(v))) return "";
        const active = i === activeIdx ? " active" : "";
        const r = i === activeIdx ? 4.2 : 2.6;
        return `<circle class="spark-dot${active}" cx="${xAt(i).toFixed(1)}" cy="${yAt(v).toFixed(1)}" r="${r}"></circle>`;
      })
      .join("");
    return `<svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" aria-hidden="true">${prev}<polyline class="spark-line" points="${toPts(series26)}"></polyline>${dots}</svg>`;
  }

  function miniGaugeMarkup(id, scale) {
    return `
      <div class="mini-gauge" aria-hidden="true">
        <svg viewBox="0 0 200 110">
          <path class="gauge-track" d="M20 100 A80 80 0 0 1 180 100"/>
          <path id="${id}Arc" class="gauge-fill" d="M20 100 A80 80 0 0 1 180 100"/>
          <line id="${id}Needle" class="gauge-needle" x1="100" y1="100" x2="100" y2="32"/>
          <circle cx="100" cy="100" r="4" class="gauge-hub"/>
        </svg>
        <div class="gauge-scale">${scale}</div>
      </div>`;
  }

  function renderTrend(phase) {
    if (!els.trendGrid) return;
    const series = collectTrend();
    const current = series.find((s) => s.ordem === state.weekOrdem) || series[series.length - 1] || {};
    const activeIdx = Math.max(0, series.findIndex((s) => s.ordem === state.weekOrdem));
    const baseTxt = state.storeBase === "mesma" ? "Mesma base" : "Todas as lojas";
    const visao = phaseLabels[state.phaseKey] || "Visão";

    if (els.trendScope) {
      els.trendScope.textContent = state.selectedNome
        ? `${cleanName(state.selectedNome)} · ${visao} · ${baseTxt}`
        : `Total da visão · ${visao} · ${baseTxt}`;
    }
    if (els.trendClear) els.trendClear.classList.toggle("hidden", !state.selectedNome);

    const useClientes = !!phase.hasClients;
    const cards = [
      {
        id: "trendVenda",
        label: "Venda",
        value: current.missing ? "—" : fmtMoney(current.venda),
        compare: current.missing ? "Sem dado nesta semana" : `2025: ${fmtMoney(current.venda25)}`,
        delta: current.varVendaPct,
        deltaPp: null,
        series26: series.map((s) => s.venda),
        series25: series.map((s) => s.venda25),
        ratio: current.venda25 > 0 ? Math.min(current.venda / (current.venda25 * 1.35), 1) : 0.5,
        scale: "<span>0</span><span>vs 25</span><span>+</span>",
      },
      {
        id: "trendMid",
        label: useClientes ? "Clientes" : "Lucro bruto",
        value: current.missing
          ? "—"
          : useClientes
            ? num.format(current.clientes || 0)
            : fmtMoney(current.lucro),
        compare: current.missing
          ? "Sem dado nesta semana"
          : useClientes
            ? `2025: ${num.format(current.clientes25 || 0)}`
            : `2025: ${fmtMoney(current.lucro25)}`,
        delta: useClientes ? current.varClientesPct : current.varLucroPct,
        deltaPp: null,
        series26: series.map((s) => (useClientes ? s.clientes : s.lucro)),
        series25: series.map((s) => (useClientes ? s.clientes25 : s.lucro25)),
        ratio: useClientes
          ? current.clientes25 > 0
            ? Math.min((current.clientes || 0) / (current.clientes25 * 1.35), 1)
            : 0.5
          : current.lucro25 > 0
            ? Math.min(current.lucro / (current.lucro25 * 1.35), 1)
            : 0.5,
        scale: "<span>0</span><span>vs 25</span><span>+</span>",
        note: useClientes ? "" : "Clientes só na visão Lojas",
      },
      {
        id: "trendMargem",
        label: "Margem",
        value: current.missing ? "—" : `${numDec.format(current.margem)}%`,
        compare: current.missing ? "Sem dado nesta semana" : `2025: ${numDec.format(current.margem25)}%`,
        delta: null,
        deltaPp: current.varMargemPp,
        series26: series.map((s) => s.margem),
        series25: series.map((s) => s.margem25),
        ratio: (Number(current.margem) || 0) / 50,
        scale: "<span>0%</span><span>25%</span><span>50%</span>",
      },
    ];

    els.trendGrid.innerHTML = cards
      .map((c) => {
        const d =
          c.deltaPp != null
            ? `<span class="delta ${deltaClass(c.deltaPp)}">${fmtPp(c.deltaPp)}</span>`
            : `<span class="delta ${deltaClass(c.delta)}">${fmtPct(c.delta)}</span>`;
        const ticks = series
          .map(
            (s, i) =>
              `<span class="trend-tick${i === activeIdx ? " is-active" : ""}">${s.tick}</span>`
          )
          .join("");
        return `
        <article class="trend-card">
          <div class="trend-card-top">
            <div>
              <small>${c.label}</small>
              <strong>${c.value}</strong>
              <p class="trend-compare">${c.compare}${c.note ? ` · ${c.note}` : ""}</p>
              <div style="margin-top:6px">${d}</div>
            </div>
            ${miniGaugeMarkup(c.id, c.scale)}
          </div>
          <div class="trend-spark">${sparkSvg(c.series26, c.series25, activeIdx)}</div>
          <div class="trend-ticks">${ticks}</div>
        </article>`;
      })
      .join("");

    cards.forEach((c) => {
      setGauge(document.getElementById(`${c.id}Arc`), document.getElementById(`${c.id}Needle`), current.missing ? 0 : c.ratio);
    });
  }

  function selectItem(nome) {
    const next = nome && sameItem(state.selectedNome, nome) ? null : nome || null;
    state.selectedNome = next;
    const phase = currentPhase();
    if (!phase) return;
    renderKpis(phase);
    renderTrend(phase);
    renderChart(phase);
    renderLists(phase);
    renderTable(phase);
  }

  function selectedRow(phase) {
    if (!state.selectedNome || !phase?.rows) return null;
    return phase.rows.find((r) => sameItem(r.nome, state.selectedNome)) || null;
  }

  function kpiSource(phase) {
    return selectedRow(phase) || phase.totals;
  }

  function metricKeys() {
    if (state.metric === "lucro") {
      return {
        key25: "lucro2025",
        key26: "lucro2026",
        delta: "deltaLucro",
        varPct: "varLucroPct",
        label: "lucro bruto",
        labelShort: "Lucro",
        isCount: false,
      };
    }
    if (state.metric === "clientes") {
      return {
        key25: "clientes2025",
        key26: "clientes2026",
        delta: "deltaClientes",
        varPct: "varClientesPct",
        label: "clientes",
        labelShort: "Clientes",
        isCount: true,
      };
    }
    return {
      key25: "venda2025",
      key26: "venda2026",
      delta: "deltaVenda",
      varPct: "varVendaPct",
      label: "venda",
      labelShort: "Venda",
      isCount: false,
    };
  }

  function rowDelta(r, m) {
    if (m.delta === "deltaClientes") {
      return (Number(r.clientes2026) || 0) - (Number(r.clientes2025) || 0);
    }
    return Number(r[m.delta]) || 0;
  }

  function fmtMetric(v, m) {
    if (m.isCount) return num.format(v || 0);
    return fmtMoney(v);
  }

  function fmtBar(v, m) {
    if (v == null || Number.isNaN(Number(v))) return "—";
    if (m.isCount) return num.format(v || 0);
    const n = Number(v) || 0;
    const abs = Math.abs(n);
    if (abs >= 1e6) return `${(n / 1e6).toFixed(1)} mi`;
    if (abs >= 1e3) return `${(n / 1e3).toFixed(0)} mil`;
    return fmtMoney(n);
  }

  function seriesValue(point, m) {
    if (m.key26 === "lucro2026") return { v26: point.lucro, v25: point.lucro25 };
    if (m.key26 === "clientes2026") return { v26: point.clientes, v25: point.clientes25 };
    return { v26: point.venda, v25: point.venda25 };
  }

  function buildMetricHighlights(rows) {
    const m = metricKeys();
    const enriched = rows.map((r) => ({ ...r, _delta: rowDelta(r, m) }));
    const sortedAsc = [...enriched].sort((a, b) => a._delta - b._delta);
    const melhores = [...enriched].sort((a, b) => b._delta - a._delta).slice(0, 3);
    const topNames = new Set(melhores.map((r) => r.nome));
    const neg = sortedAsc.filter((r) => r._delta < 0);
    const agressores =
      neg.length > 0
        ? neg.slice(0, 5)
        : sortedAsc.filter((r) => !topNames.has(r.nome)).slice(0, 5);
    return { melhores, agressores, m };
  }

  function updateMetricButtons(phase) {
    const clientesBtn = document.getElementById("metricClientes");
    const showClientes = !!phase.hasClients;
    if (clientesBtn) clientesBtn.classList.toggle("hidden", !showClientes);

    if (!showClientes && state.metric === "clientes") {
      state.metric = "venda";
    }

    document.querySelectorAll("[data-metric]").forEach((btn) => {
      btn.classList.toggle("active", btn.dataset.metric === state.metric);
    });
  }

  function renderChart(phase) {
    const m = metricKeys();
    updateMetricButtons(phase);

    if (state.selectedNome) {
      renderSelectedWeekChart(phase, m);
      return;
    }
    renderAllItemsChart(phase, m);
  }

  function renderSelectedWeekChart(phase, m) {
    const name = cleanName(state.selectedNome);
    const series = collectTrend();
    const row = selectedRow(phase);
    const totalKey = m.key26;
    const itemVal = row ? Number(row[totalKey]) || 0 : 0;
    const totalVal = Number(phase.totals?.[totalKey]) || 0;
    const share = totalVal > 0 && itemVal > 0 ? itemVal / totalVal : null;

    if (els.chartTitle) {
      els.chartTitle.textContent = `${name} · ${m.labelShort} nas 4 semanas`;
    }
    if (els.chartSubtitle) {
      const shareTxt = share != null ? ` Participação nesta semana: ${(share * 100).toFixed(1)}% do total da visão.` : "";
      els.chartSubtitle.textContent = `Métrica: ${m.label} só deste item, semana a semana. Azul = 2026. Cinza = o mesmo período de 2025. Não é o total da rede.${shareTxt}`;
    }
    els.salesChart.setAttribute("aria-label", `${name} · ${m.label} nas 4 semanas`);
    els.salesChart.classList.add("is-weeks");
    els.salesChart.style.setProperty("--cols", "4");
    els.salesChart.style.setProperty("--col-min", "150px");

    const pairs = series.map((s) => ({ ...s, ...seriesValue(s, m) }));
    const maxVal = Math.max(...pairs.flatMap((s) => [Number(s.v25) || 0, Number(s.v26) || 0]), 1);

    els.salesChart.innerHTML = pairs
      .map((s) => {
        const v25 = Number(s.v25) || 0;
        const v26 = Number(s.v26) || 0;
        const h25 = v25 > 0 ? Math.max(10, Math.round((v25 / maxVal) * 120)) : 4;
        const h26 = v26 > 0 ? Math.max(10, Math.round((v26 / maxVal) * 120)) : 4;
        const regressao = v26 < v25;
        const active = s.ordem === state.weekOrdem ? " is-active-week" : "";
        return `
          <div class="bar-group${regressao ? " regressao" : ""}${active}">
            <div class="bars tall">
              <div class="bar-col">
                <span class="bar-value">${s.missing ? "—" : fmtBar(v25, m)}</span>
                <div class="bar previous" style="height:${h25}px"></div>
                <span class="bar-year">2025</span>
              </div>
              <div class="bar-col">
                <span class="bar-value">${s.missing ? "—" : fmtBar(v26, m)}</span>
                <div class="bar current${regressao ? " regressao" : ""}" style="height:${h26}px"></div>
                <span class="bar-year">2026</span>
              </div>
            </div>
            <div class="bar-label">${s.tick}${s.ordem === state.weekOrdem ? " · semana aberta" : ""}</div>
          </div>`;
      })
      .join("");
  }

  function renderAllItemsChart(phase, m) {
    const itemWord =
      phase.key === "lojas" ? "loja" : phase.key === "secao" ? "seção" : phase.key === "grupos" ? "grupo" : "departamento";
    if (els.chartTitle) els.chartTitle.textContent = `${m.labelShort} de cada ${itemWord} · 2026 × 2025`;
    if (els.chartSubtitle) {
      els.chartSubtitle.textContent = `Métrica: ${m.label} daquele ${itemWord} sozinho. Cinza = 2025 dele. Azul = 2026 dele. O total da visão (${fmtMetric(phase.totals[m.key26], m)}) não entra nas barras.`;
    }
    els.salesChart.setAttribute("aria-label", `${m.label} por ${itemWord}, 2026 contra 2025`);
    els.salesChart.classList.remove("is-weeks");

    const items = [...phase.rows].sort((a, b) => (Number(b[m.key26]) || 0) - (Number(a[m.key26]) || 0));
    if (!items.length) {
      els.salesChart.style.removeProperty("--cols");
      els.salesChart.style.removeProperty("--col-min");
      els.salesChart.innerHTML = `<div class="empty">Sem dados para o gráfico.</div>`;
      return;
    }

    const colMin = phase.key === "grupos" ? 86 : phase.key === "secao" ? 100 : 108;
    els.salesChart.style.setProperty("--cols", String(items.length));
    els.salesChart.style.setProperty("--col-min", `${colMin}px`);

    const maxVal = Math.max(...items.flatMap((r) => [Number(r[m.key25]) || 0, Number(r[m.key26]) || 0]), 1);

    els.salesChart.innerHTML = items
      .map((r) => {
        const v25 = Number(r[m.key25]) || 0;
        const v26 = Number(r[m.key26]) || 0;
        const h25 = v25 > 0 ? Math.max(10, Math.round((v25 / maxVal) * 100)) : 4;
        const h26 = v26 > 0 ? Math.max(10, Math.round((v26 / maxVal) * 100)) : 4;
        const regressao = v26 < v25;
        return `
          <div class="bar-group${regressao ? " regressao" : ""}" data-nome="${escAttr(r.nome)}" title="${cleanName(r.nome)} · 2025 ${fmtMetric(v25, m)} · 2026 ${fmtMetric(v26, m)} · só este item, não o total da rede">
            <div class="bars">
              <div class="bar-col">
                <div class="bar previous" style="height:${h25}px"></div>
                <span class="bar-year">25</span>
              </div>
              <div class="bar-col">
                <div class="bar current${regressao ? " regressao" : ""}" style="height:${h26}px"></div>
                <span class="bar-year">26</span>
              </div>
            </div>
            <div class="bar-value-line">${fmtBar(v26, m)}</div>
            <div class="bar-label">${cleanName(r.nome)}</div>
          </div>`;
      })
      .join("");
  }

  function renderKpis(phase) {
    const t = kpiSource(phase);
    const scope = selectedRow(phase) ? cleanName(selectedRow(phase).nome) : "Total da visão";
    const cards = [
      {
        label: `Venda valor · ${scope}`,
        value: fmtMoney(t.venda2026),
        delta: t.varVendaPct,
        compare: `2025: ${fmtMoney(t.venda2025)}`,
        icon: icons.cart,
        iconClass: "cart",
        cls: "",
      },
      {
        label: "Venda quantidade",
        value: numDec.format(t.qtd2026),
        delta: t.varQtdPct,
        compare: `2025: ${numDec.format(t.qtd2025)}`,
        icon: icons.checkout,
        iconClass: "checkout",
        cls: "",
      },
      {
        label: "Margem %",
        value: `${numDec.format(t.margem2026)}%`,
        deltaPp: t.varMargemPp,
        compare: `2025: ${numDec.format(t.margem2025)}%`,
        icon: icons.offer,
        iconClass: "offer",
        cls: "margin-card",
      },
      {
        label: "Lucro bruto",
        value: fmtMoney(t.lucro2026),
        delta: t.varLucroPct,
        compare: `2025: ${fmtMoney(t.lucro2025)}`,
        icon: icons.money,
        iconClass: "money",
        cls: "",
      },
    ];

    if (phase.hasClients) {
      cards.splice(1, 0, {
        label: "Fluxo de clientes",
        value: num.format(t.clientes2026 || 0),
        delta: t.varClientesPct,
        compare: `2025: ${num.format(t.clientes2025 || 0)}`,
        icon: icons.clients,
        iconClass: "clients",
        cls: "",
      });
    }

    els.execSummary.classList.toggle("has-clients", !!phase.hasClients);
    els.execSummary.innerHTML = cards
      .map((c) => {
        const d =
          c.deltaPp != null
            ? `<span class="delta ${deltaClass(c.deltaPp)}">${fmtPp(c.deltaPp)}</span>`
            : `<span class="delta ${deltaClass(c.delta)}">${fmtPct(c.delta)}</span>`;
        return `
        <article class="kpi ${c.cls}">
          <div class="kpi-top">
            <p class="kpi-label">${c.label}</p>
            <div class="kpi-icon ${c.iconClass}">${c.icon}</div>
          </div>
          <p class="kpi-value">${c.value}</p>
          <div class="kpi-meta">${d}<p class="kpi-compare">${c.compare}</p></div>
        </article>`;
      })
      .join("");
  }

  function renderLists(phase) {
    const { melhores, agressores, m } = buildMetricHighlights(phase.rows);
    const isLucro = state.metric === "lucro";
    const isClientes = state.metric === "clientes";

    if (els.bestTitle) els.bestTitle.textContent = "Três melhores resultados";
    if (els.bestHint) {
      els.bestHint.textContent = isClientes
        ? "Maior contribuição ao fluxo de clientes YoY"
        : isLucro
          ? "Maior contribuição ao lucro bruto YoY"
          : "Maior contribuição à venda YoY";
    }

    els.bestList.innerHTML = melhores
      .map((r, i) => {
        const delta = r._delta;
        const sign = delta >= 0 ? "+" : "";
        const selected = state.selectedNome && sameItem(state.selectedNome, r.nome) ? " is-selected" : "";
        return `
        <li class="${selected.trim()}" data-nome="${escAttr(r.nome)}">
          <div class="rank-badge">${i + 1}</div>
          <div>
            <p class="rank-name">${cleanName(r.nome)}</p>
            <p class="rank-sub">${m.labelShort} ${fmtPct(r[m.varPct])} · Margem ${fmtPp(r.varMargemPp)}</p>
          </div>
          <div class="rank-metric">
            <strong class="num" style="color:var(--success)">${sign}${fmtMetric(delta, m)}</strong>
            <span>Δ ${m.label}</span>
          </div>
        </li>`;
      })
      .join("");

    const hasNeg = agressores.some((a) => a._delta < 0);
    els.aggressorTitle.textContent = hasNeg
      ? "Principais agressores"
      : agressores.length
        ? "Sob pressão no resultado"
        : "Agressores ao resultado";
    els.aggressorHint.textContent = hasNeg
      ? `Maior pressão negativa sobre ${isClientes ? "o fluxo de clientes" : isLucro ? "o lucro bruto" : "a venda"}`
      : agressores.length
        ? `Menor contribuição relativa ao avanço d${isClientes ? "os clientes" : isLucro ? "o lucro" : "a venda"}`
        : "Nenhum agressor neste recorte (Não Revenda, Inativos, Serviços e Recicláveis excluídos)";

    els.aggressorList.innerHTML = agressores.length
      ? agressores
          .slice(0, 5)
          .map((r, i) => {
            const delta = r._delta;
            const sign = delta >= 0 ? "+" : "";
            const selected = state.selectedNome && sameItem(state.selectedNome, r.nome) ? " is-selected" : "";
            return `
        <li class="${selected.trim()}" data-nome="${escAttr(r.nome)}">
          <div class="rank-badge">${i + 1}</div>
          <div>
            <p class="rank-name">${cleanName(r.nome)}</p>
            <p class="rank-sub">${m.labelShort} ${fmtPct(r[m.varPct])} · Lucro ${fmtPct(r.varLucroPct)}</p>
          </div>
          <div class="rank-metric">
            <strong class="num" style="color:${delta < 0 ? "var(--danger)" : "var(--ink-soft)"}">${sign}${fmtMetric(delta, m)}</strong>
            <span>Δ ${m.label}</span>
          </div>
        </li>`;
          })
          .join("")
      : `<li class="empty-rank"><div class="rank-badge">✓</div><div><p class="rank-name">Sem agressores</p><p class="rank-sub">Todos avançaram em ${m.label}</p></div><div class="rank-metric"><strong class="num" style="color:var(--success)">—</strong><span>Δ ${m.label}</span></div></li>`;
  }

  function columns(phase) {
    const cols = [
      { key: "nome", label: "Nome", align: "left" },
      { key: "venda2026", label: "Venda 2026", align: "right" },
      { key: "varVendaPct", label: "Δ Venda %", align: "right" },
      { key: "qtd2026", label: "Qtd 2026", align: "right" },
      { key: "varQtdPct", label: "Δ Qtd %", align: "right" },
    ];
    if (phase.hasClients) {
      cols.push(
        { key: "clientes2026", label: "Clientes 2026", align: "right" },
        { key: "varClientesPct", label: "Δ Clientes %", align: "right" }
      );
    }
    cols.push(
      { key: "margem2026", label: "Margem 2026", align: "right" },
      { key: "varMargemPp", label: "Δ Margem p.p.", align: "right" },
      { key: "lucro2026", label: "Lucro 2026", align: "right" },
      { key: "deltaLucro", label: "Δ Lucro R$", align: "right" },
      { key: "progresso", label: "Tendência", align: "left" }
    );
    return cols;
  }

  function filteredRows(phase) {
    let rows = [...phase.rows];
    if (state.filter !== "todos") rows = rows.filter((r) => r.progresso === state.filter);
    if (state.search) {
      const q = state.search.toLowerCase();
      rows = rows.filter((r) => cleanName(r.nome).toLowerCase().includes(q) || r.nome.toLowerCase().includes(q));
    }
    const key = state.sortKey;
    const dir = state.sortDir === "asc" ? 1 : -1;
    rows.sort((a, b) => {
      const av = a[key];
      const bv = b[key];
      if (typeof av === "string" || typeof bv === "string") {
        return String(av).localeCompare(String(bv), "pt-BR") * dir;
      }
      return ((av == null ? -Infinity : Number(av)) - (bv == null ? -Infinity : Number(bv))) * dir;
    });
    return rows;
  }

  function pill(v, isPp = false, isNova = false) {
    if (isNova) return `<span class="pill nova">Nova</span>`;
    return `<span class="pill ${deltaClass(v)}">${isPp ? fmtPp(v) : fmtPct(v)}</span>`;
  }

  function renderTable(phase) {
    const cols = columns(phase);
    els.tableTitle.textContent = `Detalhamento · ${phase.label}`;
    els.tableHead.innerHTML = `<tr>${cols
      .map(
        (c) =>
          `<th data-sort="${c.key}" class="${c.key === state.sortKey ? "sorted" : ""}" style="text-align:${c.align}">${c.label}${c.key === state.sortKey ? (state.sortDir === "asc" ? " ↑" : " ↓") : ""}</th>`
      )
      .join("")}</tr>`;

    const rows = filteredRows(phase);
    if (!rows.length) {
      els.tableBody.innerHTML = `<tr><td colspan="${cols.length}" class="empty">Nenhum item para os filtros selecionados.</td></tr>`;
      return;
    }

    els.tableBody.innerHTML = rows
      .map((r) => {
        const nova = phase.key === "lojas" && isNewStore(r);
        const trend =
          r.progresso === "progressao"
            ? `<span class="pill up"><span class="status-dot up"></span>Progressão</span>`
            : `<span class="pill down"><span class="status-dot down"></span>Regressão</span>`;

        const cells = [
          `<td class="cell-name">${cleanName(r.nome)}${nova ? '<span class="tag-nova">Nova</span>' : ""}</td>`,
          `<td class="num" style="text-align:right">${fmtMoney(r.venda2026)}</td>`,
          `<td style="text-align:right">${pill(r.varVendaPct, false, nova)}</td>`,
          `<td class="num" style="text-align:right">${numDec.format(r.qtd2026)}</td>`,
          `<td style="text-align:right">${pill(r.varQtdPct, false, nova)}</td>`,
        ];

        if (phase.hasClients) {
          cells.push(
            `<td class="num" style="text-align:right">${r.clientes2026 != null ? num.format(r.clientes2026) : "—"}</td>`,
            `<td style="text-align:right">${nova ? pill(null, false, true) : r.varClientesPct != null ? pill(r.varClientesPct) : "—"}</td>`
          );
        }

        cells.push(
          `<td class="num" style="text-align:right">${numDec.format(r.margem2026)}%</td>`,
          `<td style="text-align:right">${nova ? pill(null, false, true) : pill(r.varMargemPp, true)}</td>`,
          `<td class="num" style="text-align:right">${fmtMoney(r.lucro2026)}</td>`,
          `<td class="num" style="text-align:right;font-weight:700;color:${r.deltaLucro < 0 ? "var(--danger)" : "var(--success)"}">${r.deltaLucro >= 0 ? "+" : ""}${fmtMoney(r.deltaLucro)}</td>`,
          `<td>${trend}</td>`
        );

        const selected = state.selectedNome && sameItem(state.selectedNome, r.nome) ? " is-selected" : "";
        return `<tr class="${r.progresso}${selected}" data-nome="${escAttr(r.nome)}">${cells.join("")}</tr>`;
      })
      .join("");
  }

  function render() {
    const hasData = updateWeekUi();

    document.querySelectorAll(".nav-link").forEach((btn) => {
      btn.classList.toggle("active", btn.dataset.phase === state.phaseKey);
    });

    if (!hasData) return;

    const phase = currentPhase();
    if (!phase) return;

    const week = currentWeek();
    els.phaseTitle.textContent = `${week.label} · ${phase.label}`;
    els.phaseSubtitle.textContent = phase.hasClients
      ? "Monitoramento em tempo de performance · inclui fluxo de clientes, margem e lucro bruto."
      : "Monitoramento de performance comercial e análise ano contra ano.";

    updateStoreBaseUi(phase);
    renderKpis(phase);
    renderTrend(phase);
    renderChart(phase);
    renderLists(phase);
    renderTable(phase);
  }

  function bind() {
    if (els.weekGroup) {
      els.weekGroup.addEventListener("click", (e) => {
        const btn = e.target.closest("[data-week]");
        if (!btn) return;
        const ordem = Number(btn.dataset.week);
        if (!ordem || ordem === state.weekOrdem) return;
        applyWeek(ordem);
        state.search = "";
        if (els.searchInput) els.searchInput.value = "";
        render();
        window.scrollTo({ top: 0, behavior: "smooth" });
      });
    }

    els.phaseNav.addEventListener("click", (e) => {
      const btn = e.target.closest(".nav-link");
      if (!btn) return;
      state.phaseKey = btn.dataset.phase;
      state.selectedNome = null;
      state.search = "";
      els.searchInput.value = "";
      state.sortKey = "deltaLucro";
      state.sortDir = "asc";
      render();
      window.scrollTo({ top: 0, behavior: "smooth" });
    });

    if (els.trendClear) {
      els.trendClear.addEventListener("click", () => selectItem(null));
    }

    if (els.salesChart) {
      els.salesChart.addEventListener("click", (e) => {
        const group = e.target.closest("[data-nome]");
        if (!group) return;
        selectItem(group.dataset.nome);
      });
    }

    if (els.tableBody) {
      els.tableBody.addEventListener("click", (e) => {
        const row = e.target.closest("tr[data-nome]");
        if (!row) return;
        selectItem(row.dataset.nome);
      });
    }

    [els.bestList, els.aggressorList].forEach((list) => {
      if (!list) return;
      list.addEventListener("click", (e) => {
        const item = e.target.closest("[data-nome]");
        if (!item) return;
        selectItem(item.dataset.nome);
      });
    });

    els.storeBaseGroup.addEventListener("click", (e) => {
      const chip = e.target.closest("[data-store-base]");
      if (!chip) return;
      state.storeBase = chip.dataset.storeBase;
      render();
    });

    els.metricGroup.addEventListener("click", (e) => {
      const chip = e.target.closest("[data-metric]");
      if (!chip) return;
      state.metric = chip.dataset.metric;
      const phase = currentPhase();
      if (!phase) return;
      renderChart(phase);
      renderLists(phase);
    });

    document
      .querySelectorAll(".chip-group:not(.store-base-group):not(.metric-group):not(.week-group)")
      .forEach((group) => {
        group.addEventListener("click", (e) => {
          const chip = e.target.closest(".chip");
          if (!chip || !chip.dataset.filter) return;
          state.filter = chip.dataset.filter;
          group.querySelectorAll(".chip").forEach((c) => c.classList.toggle("active", c === chip));
          const phase = currentPhase();
          if (phase) renderTable(phase);
        });
      });

    els.searchInput.addEventListener("input", (e) => {
      state.search = e.target.value.trim();
      const phase = currentPhase();
      if (phase) renderTable(phase);
    });

    els.tableHead.addEventListener("click", (e) => {
      const th = e.target.closest("th[data-sort]");
      if (!th) return;
      const key = th.dataset.sort;
      if (state.sortKey === key) state.sortDir = state.sortDir === "asc" ? "desc" : "asc";
      else {
        state.sortKey = key;
        state.sortDir = key === "nome" ? "asc" : "desc";
      }
      const phase = currentPhase();
      if (phase) renderTable(phase);
    });

    // Tela cheia do detalhamento: Fullscreen API + fallback modo foco
    const syncExpandUi = () => {
      const fsEl = document.fullscreenElement || document.webkitFullscreenElement;
      const expanded = Boolean(fsEl === els.detailPanel || els.detailPanel?.classList.contains("is-expanded"));
      if (els.tableExpandBtn) {
        els.tableExpandBtn.setAttribute("aria-pressed", expanded ? "true" : "false");
        els.tableExpandBtn.title = expanded ? "Voltar ao dashboard" : "Abrir detalhamento em tela cheia";
      }
      document.body.classList.toggle("table-focus-open", expanded);
    };

    const enterTableExpand = async () => {
      if (!els.detailPanel) return;
      const req =
        els.detailPanel.requestFullscreen ||
        els.detailPanel.webkitRequestFullscreen ||
        els.detailPanel.msRequestFullscreen;
      if (typeof req === "function") {
        try {
          await req.call(els.detailPanel);
          syncExpandUi();
          return;
        } catch (_) {
          /* fallback abaixo */
        }
      }
      els.detailPanel.classList.add("is-expanded");
      syncExpandUi();
    };

    const exitTableExpand = async () => {
      const fsEl = document.fullscreenElement || document.webkitFullscreenElement;
      if (fsEl) {
        const exit = document.exitFullscreen || document.webkitExitFullscreen || document.msExitFullscreen;
        if (typeof exit === "function") {
          try {
            await exit.call(document);
          } catch (_) {}
        }
      }
      els.detailPanel?.classList.remove("is-expanded");
      syncExpandUi();
    };

    if (els.tableExpandBtn && els.detailPanel) {
      els.tableExpandBtn.addEventListener("click", () => {
        const fsEl = document.fullscreenElement || document.webkitFullscreenElement;
        const expanded = Boolean(fsEl === els.detailPanel || els.detailPanel.classList.contains("is-expanded"));
        if (expanded) exitTableExpand();
        else enterTableExpand();
      });
      document.addEventListener("fullscreenchange", syncExpandUi);
      document.addEventListener("webkitfullscreenchange", syncExpandUi);
      document.addEventListener("keydown", (e) => {
        if (e.key === "Escape" && els.detailPanel.classList.contains("is-expanded")) {
          exitTableExpand();
        }
      });
    }
  }

  async function loadData() {
    if (window.PERFORMANCE_DATA) return window.PERFORMANCE_DATA;
    const res = await fetch("data.json", { cache: "no-store" });
    if (!res.ok) throw new Error("Falha ao carregar data.json");
    return res.json();
  }

  async function init() {
    try {
      const raw = await loadData();
      state.bundle = normalizeBundle(raw);
      if (!state.bundle) throw new Error("Estrutura de dados inválida (esperado weeks[] ou phases[]).");
      applyWeek(state.bundle.selectedWeek || 1);
      bind();
      render();
    } catch (err) {
      if (els.emptyWeekPanel) els.emptyWeekPanel.classList.remove("hidden");
      if (els.analysisContent) els.analysisContent.classList.add("hidden");
      if (els.emptyWeekTitle) els.emptyWeekTitle.textContent = "Erro ao carregar";
      if (els.emptyWeekMessage) els.emptyWeekMessage.textContent = err.message || "Sem dados";
      console.error(err);
    }
  }

  init();
})();
