(() => {
  "use strict";

  const state = {
    data: null,
    phaseKey: "departamentos",
    filter: "todos",
    search: "",
    sortKey: "deltaLucro",
    sortDir: "asc",
    storeBase: "mesma",
    metric: "venda", // 'venda' | 'lucro'
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
    storeBaseGroup: document.getElementById("storeBaseGroup"),
    storeBaseNote: document.getElementById("storeBaseNote"),
    metricGroup: document.getElementById("metricGroup"),
    salesChart: document.getElementById("salesChart"),
    chartTitle: document.getElementById("chartTitle"),
    chartSubtitle: document.getElementById("chartSubtitle"),
    marginValue: document.getElementById("marginValue"),
    marginTarget: document.getElementById("marginTarget"),
    marginFoot: document.getElementById("marginFoot"),
    marginArc: document.getElementById("marginArc"),
    marginNeedle: document.getElementById("marginNeedle"),
    profitValue: document.getElementById("profitValue"),
    profitTarget: document.getElementById("profitTarget"),
    profitFoot: document.getElementById("profitFoot"),
    profitArc: document.getElementById("profitArc"),
    profitNeedle: document.getElementById("profitNeedle"),
    moneyRain: document.getElementById("moneyRain"),
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

  const phaseLabels = {
    departamentos: "Departamentos",
    lojas: "Lojas",
    secao: "Mercadológico — Seção",
    grupos: "Mercadológico — Grupos",
  };

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

  function setGauge(arcEl, needleEl, ratio) {
    const r = Math.max(0, Math.min(1, ratio));
    arcEl.style.strokeDasharray = String(GAUGE_LEN);
    arcEl.style.strokeDashoffset = String(GAUGE_LEN * (1 - r));
    const angle = -90 + r * 180;
    needleEl.style.transform = `rotate(${angle}deg)`;
  }

  function renderGauges(phase) {
    const t = phase.totals;
    els.marginValue.textContent = `${numDec.format(t.margem2026)}%`;
    els.marginTarget.textContent = `Ano anterior: ${numDec.format(t.margem2025)}%`;
    setGauge(els.marginArc, els.marginNeedle, t.margem2026 / 50); // scale 0-50%

    const marginUp = t.varMargemPp >= 0;
    els.marginFoot.className = `gauge-foot${marginUp ? "" : " warn"}`;
    els.marginFoot.textContent = marginUp
      ? `✓ Margem em evolução · ${fmtPp(t.varMargemPp)}`
      : `! Margem sob pressão · ${fmtPp(t.varMargemPp)}`;

    els.profitValue.textContent = fmtMoney(t.lucro2026);
    els.profitTarget.textContent = `Ano anterior: ${fmtMoney(t.lucro2025)}`;
    const profitRatio = t.lucro2025 > 0 ? Math.min(t.lucro2026 / (t.lucro2025 * 1.35), 1) : 0.5;
    setGauge(els.profitArc, els.profitNeedle, profitRatio);

    const profitUp = t.varLucroPct >= 0;
    els.profitFoot.className = `gauge-foot${profitUp ? "" : " warn"}`;
    els.profitFoot.textContent = profitUp
      ? `↑ Lucro acima do ano anterior · ${fmtPct(t.varLucroPct)}`
      : `↓ Lucro abaixo do ano anterior · ${fmtPct(t.varLucroPct)}`;

    // money rain
    const bits = [];
    for (let i = 0; i < 8; i++) {
      const left = 8 + i * 11 + (i % 2) * 3;
      bits.push(`<span style="left:${left}%;animation-delay:${(i * 0.35).toFixed(2)}s;animation-duration:${(2.8 + (i % 3) * 0.4).toFixed(1)}s">$</span>`);
    }
    els.moneyRain.innerHTML = bits.join("");
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

    const titles = {
      venda: "Comparativo de vendas",
      lucro: "Comparativo de lucro bruto",
      clientes: "Comparativo de fluxo de clientes",
    };
    if (els.chartTitle) els.chartTitle.textContent = titles[state.metric] || titles.venda;
    if (els.chartSubtitle) {
      els.chartSubtitle.textContent = "Período atual (2026) × período anterior (2025) · todos os itens";
    }
    els.salesChart.setAttribute("aria-label", titles[state.metric] || titles.venda);

    // Mostrar todos os itens (lojas, seções, grupos, departamentos)
    const items = [...phase.rows].sort((a, b) => (Number(b[m.key26]) || 0) - (Number(a[m.key26]) || 0));

    if (!items.length) {
      els.salesChart.style.removeProperty("--cols");
      els.salesChart.style.removeProperty("--col-min");
      els.salesChart.innerHTML = `<div class="empty">Sem dados para o gráfico.</div>`;
      return;
    }

    const colMin = phase.key === "grupos" ? 92 : phase.key === "secao" ? 108 : 120;
    els.salesChart.style.setProperty("--cols", String(items.length));
    els.salesChart.style.setProperty("--col-min", `${colMin}px`);

    const maxVal = Math.max(...items.flatMap((r) => [Number(r[m.key25]) || 0, Number(r[m.key26]) || 0]), 1);

    els.salesChart.innerHTML = items
      .map((r) => {
        const v25 = Number(r[m.key25]) || 0;
        const v26 = Number(r[m.key26]) || 0;
        const h25 = Math.max(10, Math.round((v25 / maxVal) * 160));
        const h26 = Math.max(10, Math.round((v26 / maxVal) * 160));
        const regressao = v26 < v25;
        return `
          <div class="bar-group${regressao ? " regressao" : ""}" title="${cleanName(r.nome)} · 2025 ${fmtMetric(v25, m)} · 2026 ${fmtMetric(v26, m)}${regressao ? " · regressão" : ""}">
            <div class="bars">
              <div class="bar previous" style="height:${h25}px"></div>
              <div class="bar current${regressao ? " regressao" : ""}" style="height:${h26}px"></div>
            </div>
            <div class="bar-label">${cleanName(r.nome)}</div>
          </div>`;
      })
      .join("");
  }

  function renderKpis(phase) {
    const t = phase.totals;
    const cards = [
      {
        label: "Venda valor",
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
        return `
        <li>
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
            return `
        <li>
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

        return `<tr class="${r.progresso}">${cells.join("")}</tr>`;
      })
      .join("");
  }

  function render() {
    const phase = currentPhase();
    if (!phase) return;

    els.phaseTitle.textContent = phase.label;
    els.phaseSubtitle.textContent = phase.hasClients
      ? "Monitoramento em tempo de performance · inclui fluxo de clientes, margem e lucro bruto."
      : "Monitoramento de performance comercial e análise ano contra ano.";

    document.querySelectorAll(".nav-link").forEach((btn) => {
      btn.classList.toggle("active", btn.dataset.phase === state.phaseKey);
    });

    updateStoreBaseUi(phase);
    renderKpis(phase);
    renderGauges(phase);
    renderChart(phase);
    renderLists(phase);
    renderTable(phase);
  }

  function bind() {
    els.phaseNav.addEventListener("click", (e) => {
      const btn = e.target.closest(".nav-link");
      if (!btn) return;
      state.phaseKey = btn.dataset.phase;
      state.search = "";
      els.searchInput.value = "";
      state.sortKey = "deltaLucro";
      state.sortDir = "asc";
      render();
      window.scrollTo({ top: 0, behavior: "smooth" });
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
      renderChart(currentPhase());
      renderLists(currentPhase());
    });

    document.querySelectorAll(".chip-group:not(.store-base-group):not(.metric-group)").forEach((group) => {
      group.addEventListener("click", (e) => {
        const chip = e.target.closest(".chip");
        if (!chip || !chip.dataset.filter) return;
        state.filter = chip.dataset.filter;
        group.querySelectorAll(".chip").forEach((c) => c.classList.toggle("active", c === chip));
        renderTable(currentPhase());
      });
    });

    els.searchInput.addEventListener("input", (e) => {
      state.search = e.target.value.trim();
      renderTable(currentPhase());
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
      renderTable(currentPhase());
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
      state.data = await loadData();
      bind();
      render();
    } catch (err) {
      els.execSummary.innerHTML = `<div class="panel"><p>Não foi possível carregar os dados da análise.</p><p class="muted">${err.message}</p></div>`;
      console.error(err);
    }
  }

  init();
})();
