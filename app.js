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
    itemFilter: {
      departamentos: null,
      lojas: null,
      secao: null,
      grupos: null,
    },
    filterPopPhase: null,
  };

  const els = {
    phaseNav: document.getElementById("phaseNav"),
    phaseFilterPop: document.getElementById("phaseFilterPop"),
    phaseFilterTitle: document.getElementById("phaseFilterTitle"),
    phaseFilterMeta: document.getElementById("phaseFilterMeta"),
    phaseFilterSearch: document.getElementById("phaseFilterSearch"),
    phaseFilterList: document.getElementById("phaseFilterList"),
    phaseFilterAll: document.getElementById("phaseFilterAll"),
    phaseFilterNone: document.getElementById("phaseFilterNone"),
    phaseFilterClear: document.getElementById("phaseFilterClear"),
    itemFilterNote: document.getElementById("itemFilterNote"),
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
    chartPanel: document.getElementById("chartPanel"),
    chartExpandBtn: document.getElementById("chartExpandBtn"),
    chartBackBtn: document.getElementById("chartBackBtn"),
    salesChart: document.getElementById("salesChart"),
    salesMix: document.getElementById("salesMix"),
    salesMixLabel: document.getElementById("salesMixLabel"),
    chartLegend: document.getElementById("chartLegend"),
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
    const rows = filterRows(base.rows || [], phase.key);
    const filtered = phaseFilterSet(phase.key) != null;
    const totals = filtered ? sumRows(rows, !!phase.hasClients) : base.totals;
    return {
      key: phase.key,
      label: `${phaseLabels[phase.key] || phase.label} · ${suffix}`,
      hasClients: !!phase.hasClients,
      rows,
      totals,
      melhores: base.melhores || [],
      agressores: base.agressores || [],
      baseMeta: getStoreMeta(),
      filtered,
      filterCount: rows.length,
      sourceCount: (base.rows || []).length,
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

  function phaseFilterSet(phaseKey) {
    const list = state.itemFilter[phaseKey];
    return Array.isArray(list) ? list : null;
  }

  function rawPhaseRows(phaseKey, baseKey) {
    const phase = state.data?.phases?.find((p) => p.key === phaseKey);
    const key = baseKey || (state.storeBase === "mesma" ? "mesma" : "todas");
    return phase?.bases?.[key]?.rows || [];
  }

  function filterRows(rows, phaseKey) {
    const sel = phaseFilterSet(phaseKey);
    if (!sel) return rows || [];
    return (rows || []).filter((r) => sel.some((n) => sameItem(r.nome, n)));
  }

  function sumRows(rows, hasClients) {
    const acc = {
      venda2025: 0,
      venda2026: 0,
      qtd2025: 0,
      qtd2026: 0,
      lucro2025: 0,
      lucro2026: 0,
      clientes2025: null,
      clientes2026: null,
      varClientesPct: null,
    };
    let c25 = 0;
    let c26 = 0;
    let hasC = false;
    for (const r of rows || []) {
      acc.venda2025 += Number(r.venda2025) || 0;
      acc.venda2026 += Number(r.venda2026) || 0;
      acc.qtd2025 += Number(r.qtd2025) || 0;
      acc.qtd2026 += Number(r.qtd2026) || 0;
      acc.lucro2025 += Number(r.lucro2025) || 0;
      acc.lucro2026 += Number(r.lucro2026) || 0;
      if (r.clientes2025 != null || r.clientes2026 != null) {
        hasC = true;
        c25 += Number(r.clientes2025) || 0;
        c26 += Number(r.clientes2026) || 0;
      }
    }
    const ratio = (a, b) => (a ? (b - a) / a : b ? 1 : 0);
    acc.deltaVenda = acc.venda2026 - acc.venda2025;
    acc.deltaLucro = acc.lucro2026 - acc.lucro2025;
    acc.deltaQtd = acc.qtd2026 - acc.qtd2025;
    acc.varVendaPct = ratio(acc.venda2025, acc.venda2026);
    acc.varQtdPct = ratio(acc.qtd2025, acc.qtd2026);
    acc.varLucroPct = ratio(acc.lucro2025, acc.lucro2026);
    acc.margem2025 = acc.venda2025 ? (acc.lucro2025 / acc.venda2025) * 100 : 0;
    acc.margem2026 = acc.venda2026 ? (acc.lucro2026 / acc.venda2026) * 100 : 0;
    acc.varMargemPp = acc.margem2026 - acc.margem2025;
    if (hasClients && hasC) {
      acc.clientes2025 = c25;
      acc.clientes2026 = c26;
      acc.varClientesPct = ratio(c25, c26);
    }
    return acc;
  }

  function applyPhaseFilter(phaseKey, names) {
    if (names == null) state.itemFilter[phaseKey] = null;
    else state.itemFilter[phaseKey] = [...new Set((names || []).filter(Boolean))];
    const visible = filterRows(rawPhaseRows(phaseKey), phaseKey);
    if (state.selectedNome && !visible.some((r) => sameItem(r.nome, state.selectedNome))) {
      state.selectedNome = null;
    }
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
    const base = phase.bases?.[baseKey];
    if (!base) return null;
    const rows = filterRows(base.rows || [], state.phaseKey);
    if (phaseFilterSet(state.phaseKey) == null) return base;
    return {
      ...base,
      rows,
      totals: sumRows(rows, !!phase.hasClients),
    };
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

  function setChartLegend(mode) {
    if (!els.chartLegend) return;
    if (mode === "weeks") {
      els.chartLegend.innerHTML = `
        <span><i class="dot current"></i> 2026 deste item</span>
        <span><i class="dot previous"></i> 2025 deste item</span>
        <span><i class="dot regressao"></i> 2026 abaixo de 2025</span>`;
      return;
    }
    els.chartLegend.innerHTML = `
      <span><i class="dot current"></i> Crescimento YoY</span>
      <span><i class="dot regressao"></i> Regressão YoY</span>
      <span><i class="dot mix"></i> Participação 2026</span>`;
  }

  function toneFromPct(pct) {
    if (pct == null || Number.isNaN(pct) || Math.abs(pct) < 5e-4) return "flat";
    return pct > 0 ? "up" : "down";
  }

  function tubeFillPct(pct) {
    const mag = Math.abs(Number(pct) || 0);
    if (mag < 5e-4) return 5;
    return Math.round(6 + Math.tanh(mag / 0.2) * 94);
  }

  function placeDeltaTip(tube) {
    if (!tube || !tube.classList.contains("delta-tube")) return;
    const tip = tube.querySelector(".delta-tip");
    if (!tip) return;
    tube.classList.remove("is-tip-below", "is-tip-start", "is-tip-end");
    const clip = tube.closest(".chart-scroll") || tube.closest(".chart-panel");
    if (!clip) return;
    const clipRect = clip.getBoundingClientRect();
    const tubeRect = tube.getBoundingClientRect();
    const tipH = Math.max(tip.offsetHeight || 0, 72);
    const tipW = Math.max(tip.offsetWidth || 0, 168);
    if (tubeRect.top - clipRect.top < tipH + 8) tube.classList.add("is-tip-below");
    const center = tubeRect.left + tubeRect.width / 2;
    if (center - tipW / 2 < clipRect.left + 8) tube.classList.add("is-tip-start");
    else if (center + tipW / 2 > clipRect.right - 8) tube.classList.add("is-tip-end");
  }

  function cssEscape(value) {
    if (window.CSS && typeof window.CSS.escape === "function") return window.CSS.escape(value);
    return String(value).replace(/"/g, '\\"');
  }

  function rankingBackLabel(phase) {
    const key = phase?.key;
    if (key === "lojas") return "Todas as lojas";
    if (key === "secao") return "Todas as seções";
    if (key === "grupos") return "Todos os grupos";
    return "Todos os departamentos";
  }

  function syncChartBack(phase) {
    if (!els.chartBackBtn) return;
    const open = Boolean(state.selectedNome);
    els.chartBackBtn.classList.toggle("hidden", !open);
    els.chartBackBtn.textContent = rankingBackLabel(phase);
    els.chartBackBtn.title = `Voltar ao ranking de ${rankingBackLabel(phase).toLowerCase()} sem sair da tela cheia`;
  }

  function renderChart(phase) {
    const m = metricKeys();
    updateMetricButtons(phase);
    syncChartBack(phase);

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
      els.chartSubtitle.textContent = `Um clique no tubo abriu este detalhe. Azul = 2026 · cinza = 2025. Não é o total da rede.${shareTxt} Use “${rankingBackLabel(phase)}” ou Esc para voltar ao ranking (a tela cheia permanece).`;
    }
    els.salesChart.setAttribute("aria-label", `${name} · ${m.label} nas 4 semanas`);
    els.salesChart.classList.add("is-weeks");
    els.salesChart.classList.remove("is-delta", "is-fit", "is-dense");
    els.salesChart.style.setProperty("--cols", "4");
    els.salesChart.style.setProperty("--col-min", "150px");
    setChartLegend("weeks");
    if (els.salesMix) {
      els.salesMix.hidden = true;
      els.salesMix.innerHTML = "";
    }
    if (els.salesMixLabel) els.salesMixLabel.hidden = true;

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
    if (els.chartTitle) els.chartTitle.textContent = `Variação YoY de cada ${itemWord}`;
    if (els.chartSubtitle) {
      els.chartSubtitle.textContent = `Só a diferença YoY em ${m.label}. 1ª linha = melhores resultados. Um clique no tubo abre as 4 semanas desse item. Tela cheia para Grupos.`;
    }
    els.salesChart.setAttribute("aria-label", `Variação percentual YoY de ${m.label} por ${itemWord}`);
    els.salesChart.classList.remove("is-weeks", "is-fit");
    els.salesChart.classList.add("is-delta");
    setChartLegend("delta");

    const items = [...phase.rows].sort((a, b) => (Number(b[m.varPct]) || 0) - (Number(a[m.varPct]) || 0));
    if (!items.length) {
      els.salesChart.style.removeProperty("--cols");
      els.salesChart.style.removeProperty("--col-min");
      els.salesChart.innerHTML = `<div class="empty">Sem dados para o gráfico.</div>`;
      if (els.salesMix) {
        els.salesMix.hidden = true;
        els.salesMix.innerHTML = "";
      }
      if (els.salesMixLabel) els.salesMixLabel.hidden = true;
      return;
    }

    els.salesChart.classList.toggle("is-dense", items.length > 16);
    els.salesChart.style.removeProperty("--cols");
    els.salesChart.style.removeProperty("--col-min");

    const tot26 = items.reduce((s, r) => s + Math.max(0, Number(r[m.key26]) || 0), 0) || 1;

    els.salesChart.innerHTML = items
      .map((r, i) => {
        const v26 = Number(r[m.key26]) || 0;
        const pct = Number(r[m.varPct]);
        const delta = rowDelta(r, m);
        const tone = toneFromPct(pct);
        const fill = tubeFillPct(pct);
        const selected = state.selectedNome && sameItem(state.selectedNome, r.nome) ? " is-selected" : "";
        const delay = Math.min(i * 28, 360);
        return `
          <button type="button" class="delta-tube is-${tone}${selected}" data-nome="${escAttr(r.nome)}" style="animation-delay:${delay}ms">
            <span class="delta-tip">
              <strong>${cleanName(r.nome)}</strong>
              <em>${fmtPct(pct)}</em>
              <small>Δ ${fmtBar(delta, m)} · 2026 ${fmtMetric(v26, m)}</small>
            </span>
            <span class="delta-glass" aria-hidden="true">
              <span class="delta-fill" style="--fill:${fill}%; animation-delay:${delay}ms"></span>
            </span>
            <span class="delta-pct">${fmtPct(pct)}</span>
            <span class="delta-delta">${delta >= 0 ? "+" : ""}${fmtBar(delta, m)}</span>
            <span class="bar-label">${cleanName(r.nome)}</span>
          </button>`;
      })
      .join("");

    if (els.salesMix) {
      const mixItems = [...phase.rows].sort((a, b) => (Number(b[m.key26]) || 0) - (Number(a[m.key26]) || 0));
      els.salesMix.hidden = false;
      els.salesMix.innerHTML = mixItems
        .map((r) => {
          const v26 = Math.max(0, Number(r[m.key26]) || 0);
          const share = (v26 / tot26) * 100;
          const tone = toneFromPct(Number(r[m.varPct]));
          return `<span class="delta-mix-seg is-${tone}" data-nome="${escAttr(r.nome)}" style="flex:${Math.max(share, 0.35)} 1 0" title="${cleanName(r.nome)} · ${share.toFixed(1)}% da visão"></span>`;
        })
        .join("");
    }
    if (els.salesMixLabel) {
      els.salesMixLabel.hidden = false;
      els.salesMixLabel.textContent = `Participação de cada ${itemWord} no total 2026 · passe o cursor para destacar`;
    }
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
    const filterBit = phase.filtered ? ` · ${phase.filterCount} de ${phase.sourceCount}` : "";
    els.phaseTitle.textContent = `${week.label} · ${phase.label}${filterBit}`;
    els.phaseSubtitle.textContent = phase.hasClients
      ? "Monitoramento em tempo de performance · inclui fluxo de clientes, margem e lucro bruto."
      : "Monitoramento de performance comercial e análise ano contra ano.";

    updateStoreBaseUi(phase);
    updateFilterBadges();
    renderItemFilterNote(phase);
    renderKpis(phase);
    renderTrend(phase);
    renderChart(phase);
    renderLists(phase);
    renderTable(phase);
  }

  function updateFilterBadges() {
    document.querySelectorAll("[data-filter-phase]").forEach((btn) => {
      const key = btn.dataset.filterPhase;
      const sel = phaseFilterSet(key);
      const countEl = btn.querySelector(".nav-filter-count");
      const on = sel != null;
      btn.classList.toggle("is-filtered", on);
      if (countEl) {
        countEl.textContent = on ? String(sel.length) : "";
        countEl.classList.toggle("hidden", !on);
      }
      btn.setAttribute("aria-expanded", state.filterPopPhase === key ? "true" : "false");
      btn.closest(".nav-phase")?.classList.toggle("is-open", state.filterPopPhase === key);
    });
  }

  function renderItemFilterNote(phase) {
    if (!els.itemFilterNote) return;
    if (!phase?.filtered) {
      els.itemFilterNote.classList.add("hidden");
      els.itemFilterNote.textContent = "";
      return;
    }
    const names = phaseFilterSet(phase.key) || [];
    const shown = names.slice(0, 4).map(cleanName).join(" · ");
    const extra = names.length > 4 ? ` +${names.length - 4}` : "";
    const word =
      phase.key === "lojas" ? "lojas" : phase.key === "secao" ? "seções" : phase.key === "grupos" ? "grupos" : "departamentos";
    els.itemFilterNote.classList.remove("hidden");
    els.itemFilterNote.innerHTML = `<strong>Filtro ativo:</strong> ${phase.filterCount} de ${phase.sourceCount} ${word} (${shown}${extra}). KPIs, gráfico e tabela usam só essa seleção. <button type="button" class="note-clear" id="itemFilterNoteClear">Limpar</button>`;
    const clear = document.getElementById("itemFilterNoteClear");
    if (clear) clear.addEventListener("click", () => {
      applyPhaseFilter(phase.key, []);
      render();
      if (state.filterPopPhase === phase.key) fillPhaseFilterList();
    });
  }

  function closePhaseFilterPop() {
    state.filterPopPhase = null;
    if (!els.phaseFilterPop) return;
    els.phaseFilterPop.classList.add("hidden");
    els.phaseFilterPop.hidden = true;
    updateFilterBadges();
  }

  function positionPhaseFilterPop(anchor) {
    const pop = els.phaseFilterPop;
    if (!pop || !anchor) return;
    const rect = anchor.getBoundingClientRect();
    const width = Math.min(340, window.innerWidth - 16);
    let left = rect.left;
    if (left + width > window.innerWidth - 8) left = window.innerWidth - width - 8;
    if (left < 8) left = 8;
    pop.style.left = `${left}px`;
    pop.style.top = `${rect.bottom + 8}px`;
    pop.style.width = `${width}px`;
  }

  function fillPhaseFilterList() {
    const key = state.filterPopPhase;
    if (!key || !els.phaseFilterList) return;
    const rows = [...rawPhaseRows(key)].sort((a, b) => cleanName(a.nome).localeCompare(cleanName(b.nome), "pt-BR"));
    const rawSel = phaseFilterSet(key);
    const allOn = rawSel == null;
    const sel = new Set(allOn ? rows.map((r) => r.nome) : rawSel);
    const q = (els.phaseFilterSearch?.value || "").trim().toLowerCase();
    const labels = {
      departamentos: "departamentos",
      lojas: "lojas",
      secao: "seções",
      grupos: "grupos",
    };
    if (els.phaseFilterTitle) els.phaseFilterTitle.textContent = `Selecionar ${labels[key] || "itens"}`;
    if (els.phaseFilterMeta) els.phaseFilterMeta.textContent = `${sel.size} de ${rows.length}`;
    els.phaseFilterList.innerHTML = rows
      .filter((r) => !q || cleanName(r.nome).toLowerCase().includes(q))
      .map((r) => {
        const checked = [...sel].some((n) => sameItem(n, r.nome)) ? " checked" : "";
        return `<label class="phase-filter-item"><input type="checkbox" value="${escAttr(r.nome)}"${checked}><span>${cleanName(r.nome)}</span></label>`;
      })
      .join("") || `<p class="phase-filter-empty">Nenhum item com esse nome.</p>`;
  }

  function togglePhaseFilterPop(phaseKey, anchor) {
    if (state.filterPopPhase === phaseKey && els.phaseFilterPop && !els.phaseFilterPop.hidden) {
      closePhaseFilterPop();
      return;
    }
    state.filterPopPhase = phaseKey;
    if (els.phaseFilterSearch) els.phaseFilterSearch.value = "";
    els.phaseFilterPop.hidden = false;
    els.phaseFilterPop.classList.remove("hidden");
    fillPhaseFilterList();
    positionPhaseFilterPop(anchor.closest(".nav-phase") || anchor);
    updateFilterBadges();
    els.phaseFilterSearch?.focus();
  }

  function readPopSelection() {
    if (!els.phaseFilterList) return [];
    return [...els.phaseFilterList.querySelectorAll("input[type=checkbox]:checked")].map((el) => el.value);
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
      const filterBtn = e.target.closest("[data-filter-phase]");
      if (filterBtn) {
        const key = filterBtn.dataset.filterPhase;
        if (state.phaseKey !== key) {
          state.phaseKey = key;
          state.selectedNome = null;
          state.search = "";
          if (els.searchInput) els.searchInput.value = "";
          state.sortKey = "deltaLucro";
          state.sortDir = "asc";
          render();
        }
        togglePhaseFilterPop(key, filterBtn);
        return;
      }
      const btn = e.target.closest(".nav-link");
      if (!btn) return;
      closePhaseFilterPop();
      state.phaseKey = btn.dataset.phase;
      state.selectedNome = null;
      state.search = "";
      els.searchInput.value = "";
      state.sortKey = "deltaLucro";
      state.sortDir = "asc";
      render();
      window.scrollTo({ top: 0, behavior: "smooth" });
    });

    if (els.phaseFilterList) {
      els.phaseFilterList.addEventListener("change", (e) => {
        const input = e.target.closest("input[type=checkbox]");
        const key = state.filterPopPhase;
        if (!input || !key) return;
        const all = rawPhaseRows(key).map((r) => r.nome);
        const cur = phaseFilterSet(key);
        const set = new Set(cur == null ? all : cur);
        if (input.checked) set.add(input.value);
        else set.delete(input.value);
        applyPhaseFilter(key, set.size === all.length ? null : [...set]);
        render();
        fillPhaseFilterList();
      });
    }
    if (els.phaseFilterSearch) {
      els.phaseFilterSearch.addEventListener("input", () => fillPhaseFilterList());
    }
    if (els.phaseFilterAll) {
      els.phaseFilterAll.addEventListener("click", () => {
        if (!state.filterPopPhase) return;
        applyPhaseFilter(state.filterPopPhase, null);
        render();
        fillPhaseFilterList();
      });
    }
    if (els.phaseFilterNone) {
      els.phaseFilterNone.addEventListener("click", () => {
        if (!state.filterPopPhase) return;
        applyPhaseFilter(state.filterPopPhase, []);
        render();
        fillPhaseFilterList();
      });
    }
    if (els.phaseFilterClear) {
      els.phaseFilterClear.addEventListener("click", () => {
        if (!state.filterPopPhase) return;
        applyPhaseFilter(state.filterPopPhase, null);
        render();
        closePhaseFilterPop();
      });
    }
    document.addEventListener("click", (e) => {
      if (!state.filterPopPhase) return;
      if (e.target.closest("#phaseFilterPop") || e.target.closest("[data-filter-phase]")) return;
      closePhaseFilterPop();
    });
    window.addEventListener("resize", () => {
      if (!state.filterPopPhase) return;
      const btn = document.querySelector(`[data-filter-phase="${state.filterPopPhase}"]`);
      if (btn) positionPhaseFilterPop(btn.closest(".nav-phase") || btn);
    });
    document.addEventListener(
      "keydown",
      (e) => {
        if (e.key === "Escape" && state.filterPopPhase) {
          closePhaseFilterPop();
          e.preventDefault();
          e.stopPropagation();
        }
      },
      true
    );

    if (els.trendClear) {
      els.trendClear.addEventListener("click", () => selectItem(null));
    }
    if (els.chartBackBtn) {
      els.chartBackBtn.addEventListener("click", () => selectItem(null));
    }

    if (els.salesChart) {
      els.salesChart.addEventListener("click", (e) => {
        const group = e.target.closest("[data-nome]");
        if (group) {
          selectItem(group.dataset.nome);
          return;
        }
        if (state.selectedNome && els.salesChart.classList.contains("is-weeks")) {
          selectItem(null);
        }
      });
    }

    if (els.salesMix) {
      els.salesMix.addEventListener("click", (e) => {
        const seg = e.target.closest("[data-nome]");
        if (!seg) return;
        selectItem(seg.dataset.nome);
      });
    }

    const chartPanel = els.salesChart && els.salesChart.closest(".chart-panel");
    if (chartPanel && !chartPanel.dataset.deltaHover) {
      chartPanel.dataset.deltaHover = "1";
      const clearHot = () =>
        chartPanel.querySelectorAll(".is-hot").forEach((el) => {
          el.classList.remove("is-hot", "is-tip-below", "is-tip-start", "is-tip-end");
        });
      chartPanel.addEventListener("pointerover", (e) => {
        const item = e.target.closest("[data-nome]");
        clearHot();
        if (!item || !item.dataset.nome) return;
        chartPanel.querySelectorAll(`[data-nome="${cssEscape(item.dataset.nome)}"]`).forEach((el) => {
          el.classList.add("is-hot");
          placeDeltaTip(el);
        });
      });
      chartPanel.addEventListener("pointerleave", clearHot);
      chartPanel.addEventListener("focusin", (e) => {
        const tube = e.target.closest(".delta-tube");
        if (tube) placeDeltaTip(tube);
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

    // Tela cheia: detalhamento e gráfico YoY
    const bindPanelExpand = (panel, btn, opts = {}) => {
      if (!panel || !btn) return;
      let leaveIntentional = false;
      const isThisExpanded = () => {
        const fsEl = document.fullscreenElement || document.webkitFullscreenElement;
        return Boolean(fsEl === panel || panel.classList.contains("is-expanded"));
      };
      const sync = () => {
        const expanded = isThisExpanded();
        btn.setAttribute("aria-pressed", expanded ? "true" : "false");
        btn.title = expanded ? "Voltar ao dashboard" : "Abrir em tela cheia";
        const anyOpen = Boolean(
          document.fullscreenElement ||
          document.webkitFullscreenElement ||
          document.querySelector(".table-panel.is-expanded, .chart-panel.is-expanded")
        );
        document.body.classList.toggle("table-focus-open", anyOpen);
        document.body.classList.toggle("panel-focus-open", anyOpen);
      };
      const enter = async () => {
        const req = panel.requestFullscreen || panel.webkitRequestFullscreen || panel.msRequestFullscreen;
        if (typeof req === "function") {
          try {
            await req.call(panel);
            sync();
            return;
          } catch (_) {}
        }
        panel.classList.add("is-expanded");
        sync();
      };
      const exit = async () => {
        leaveIntentional = true;
        const fsEl = document.fullscreenElement || document.webkitFullscreenElement;
        if (fsEl) {
          const leave = document.exitFullscreen || document.webkitExitFullscreen || document.msExitFullscreen;
          if (typeof leave === "function") {
            try {
              await leave.call(document);
            } catch (_) {}
          }
        }
        panel.classList.remove("is-expanded");
        sync();
        leaveIntentional = false;
      };
      btn.addEventListener("click", () => {
        if (isThisExpanded()) exit();
        else enter();
      });
      const afterFullscreenChange = () => {
        const stillOpen = isThisExpanded();
        sync();
        if (leaveIntentional || stillOpen) return;
        if (typeof opts.onNativeExit === "function") opts.onNativeExit();
      };
      document.addEventListener("fullscreenchange", afterFullscreenChange);
      document.addEventListener("webkitfullscreenchange", afterFullscreenChange);
      document.addEventListener("keydown", (e) => {
        if (e.key !== "Escape" || !isThisExpanded()) return;
        if (typeof opts.onEscape === "function" && opts.onEscape()) {
          e.preventDefault();
          return;
        }
        if (panel.classList.contains("is-expanded")) exit();
      });
    };

    bindPanelExpand(els.detailPanel, els.tableExpandBtn);
    bindPanelExpand(els.chartPanel, els.chartExpandBtn, {
      onEscape: () => {
        if (!state.selectedNome) return false;
        selectItem(null);
        return true;
      },
      onNativeExit: () => {
        if (!state.selectedNome) return;
        selectItem(null);
        els.chartPanel.classList.add("is-expanded");
        document.body.classList.add("panel-focus-open", "table-focus-open");
        if (els.chartExpandBtn) {
          els.chartExpandBtn.setAttribute("aria-pressed", "true");
          els.chartExpandBtn.title = "Voltar ao dashboard";
        }
      },
    });
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
