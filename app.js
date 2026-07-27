(() => {
  "use strict";

  const state = {
    data: null,
    phaseKey: "departamentos",
    filter: "todos",
    search: "",
    sortKey: "deltaLucro",
    sortDir: "asc",
    storeBase: "mesma", // 'todas' | 'mesma'
  };

  const els = {
    phaseNav: document.getElementById("phaseNav"),
    phaseTitle: document.getElementById("phaseTitle"),
    phaseSubtitle: document.getElementById("phaseSubtitle"),
    execSummary: document.getElementById("execSummary"),
    bestList: document.getElementById("bestList"),
    aggressorList: document.getElementById("aggressorList"),
    aggressorTitle: document.getElementById("aggressorTitle"),
    aggressorHint: document.getElementById("aggressorHint"),
    tableHead: document.getElementById("tableHead"),
    tableBody: document.getElementById("tableBody"),
    tableTitle: document.getElementById("tableTitle"),
    searchInput: document.getElementById("searchInput"),
    storeBaseGroup: document.getElementById("storeBaseGroup"),
    storeBaseNote: document.getElementById("storeBaseNote"),
  };

  const icons = {
    cart: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 4h2l2.4 11.2a2 2 0 0 0 2 1.6h7.8a2 2 0 0 0 2-1.5L21 8H7"/><circle cx="10" cy="20" r="1.4"/><circle cx="18" cy="20" r="1.4"/></svg>`,
    checkout: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="6" width="18" height="10" rx="2"/><path d="M7 11h5M15 9.5h3v3h-3z"/><path d="M7 18v2M17 18v2"/></svg>`,
    offer: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="5" y="3" width="14" height="18" rx="2"/><path d="M8 8h8M8 12h8M8 16h5"/><path d="M12 3v2"/></svg>`,
    money: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="8"/><path d="M12 7v10M9.5 9.5c.6-1 1.5-1.5 2.5-1.5 1.7 0 3 1 3 2.5S13.7 13 12 13s-3 1-3 2.5 1.3 2.5 3 2.5c1 0 1.9-.5 2.5-1.5"/></svg>`,
    clients: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="9" cy="8" r="3"/><circle cx="17" cy="9" r="2.4"/><path d="M3.5 18c.8-2.8 3-4.5 5.5-4.5s4.7 1.7 5.5 4.5"/><path d="M14 18c.4-1.8 1.7-3 3.4-3 1.2 0 2.2.6 2.9 1.6"/></svg>`,
  };

  const brl = new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
    maximumFractionDigits: 0,
  });

  const brlDec = new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
    maximumFractionDigits: 2,
  });

  const num = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 0 });
  const numDec = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 1 });

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
    const label = `${phaseLabels[phase.key] || phase.label} · ${suffix}`;

    return {
      key: phase.key,
      label,
      hasClients: !!phase.hasClients,
      rows: base.rows || [],
      totals: base.totals,
      melhores: base.melhores || [],
      agressores: base.agressores || [],
      baseMeta: getStoreMeta(),
    };
  }

  function updateStoreBaseUi(phase) {
    els.storeBaseGroup.classList.remove("hidden");
    els.storeBaseNote.classList.remove("hidden");

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
      els.storeBaseNote.innerHTML = `<strong>Mesma base:</strong> cálculos de <em>${phaseName}</em> com ${comparableCount} lojas comparáveis (venda nos dois anos). Excluídas ${novasCount} loja(s) sem venda em 2025${novasTxt}.`;
    } else {
      els.storeBaseNote.innerHTML = `<strong>Todas as lojas:</strong> cálculos de <em>${phaseName}</em> com ${allCount} lojas, incluindo ${novasCount} sem base no ano anterior${novasTxt ? ` — ${novasNames.join(", ")}` : ""}.`;
    }
  }

  function moneyRainHtml() {
    const bits = [];
    for (let i = 0; i < 8; i++) {
      const left = 8 + i * 11 + (i % 2) * 3;
      const delay = (i * 0.35).toFixed(2);
      const dur = (2.8 + (i % 3) * 0.4).toFixed(1);
      bits.push(
        `<span style="left:${left}%;animation-delay:${delay}s;animation-duration:${dur}s">$</span>`
      );
    }
    return `<div class="money-rain" aria-hidden="true">${bits.join("")}</div>`;
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
        cls: "money-card",
        rain: true,
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
          ${c.rain ? moneyRainHtml() : ""}
          <div class="kpi-top">
            <p class="kpi-label">${c.label}</p>
            <div class="kpi-icon ${c.iconClass}">${c.icon}</div>
          </div>
          <p class="kpi-value">${c.value}</p>
          <div class="kpi-meta">
            ${d}
            <p class="kpi-compare">${c.compare}</p>
          </div>
        </article>`;
      })
      .join("");
  }

  function renderLists(phase) {
    els.bestList.innerHTML = phase.melhores
      .map((r, i) => {
        return `
        <li>
          <div class="rank-badge">${i + 1}</div>
          <div>
            <p class="rank-name">${cleanName(r.nome)}</p>
            <p class="rank-sub">Venda ${fmtPct(r.varVendaPct)} · Margem ${fmtPp(r.varMargemPp)}</p>
          </div>
          <div class="rank-metric">
            <strong class="num" style="color:var(--green-800)">+${fmtMoney(r.deltaLucro)}</strong>
            <span>Δ lucro bruto</span>
          </div>
        </li>`;
      })
      .join("");

    const agressores = (phase.agressores || []).filter(Boolean);
    const hasNeg = agressores.some((a) => a.deltaLucro < 0);
    els.aggressorTitle.textContent = hasNeg
      ? "Principais agressores"
      : agressores.length
        ? "Sob pressão no resultado"
        : "Agressores ao resultado";
    els.aggressorHint.textContent = hasNeg
      ? "Maior pressão negativa sobre o lucro bruto"
      : agressores.length
        ? "Menor contribuição relativa ao avanço do lucro"
        : "Nenhum agressor neste recorte (Não Revenda e Inativos excluídos)";

    els.aggressorList.innerHTML = agressores.length
      ? agressores
          .slice(0, 5)
          .map((r, i) => {
            const sign = r.deltaLucro >= 0 ? "+" : "";
            return `
        <li>
          <div class="rank-badge">${i + 1}</div>
          <div>
            <p class="rank-name">${cleanName(r.nome)}</p>
            <p class="rank-sub">Venda ${fmtPct(r.varVendaPct)} · Lucro ${fmtPct(r.varLucroPct)}</p>
          </div>
          <div class="rank-metric">
            <strong class="num" style="color:${r.deltaLucro < 0 ? "var(--danger)" : "var(--ink-soft)"}">${sign}${fmtMoney(r.deltaLucro)}</strong>
            <span>Δ lucro bruto</span>
          </div>
        </li>`;
          })
          .join("")
      : `<li class="empty-rank"><div class="rank-badge">✓</div><div><p class="rank-name">Sem agressores</p><p class="rank-sub">Todos os departamentos avançaram no lucro bruto</p></div><div class="rank-metric"><strong class="num" style="color:var(--green-800)">—</strong><span>Δ lucro bruto</span></div></li>`;
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
    if (state.filter !== "todos") {
      rows = rows.filter((r) => r.progresso === state.filter);
    }
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
      const an = av == null ? -Infinity : Number(av);
      const bn = bv == null ? -Infinity : Number(bv);
      return (an - bn) * dir;
    });
    return rows;
  }

  function pill(v, isPp = false, isNova = false) {
    if (isNova) return `<span class="pill nova">Nova</span>`;
    const cls = deltaClass(v);
    const txt = isPp ? fmtPp(v) : fmtPct(v);
    return `<span class="pill ${cls}">${txt}</span>`;
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
          `<td class="num" style="text-align:right;font-weight:700;color:${r.deltaLucro < 0 ? "var(--danger)" : "var(--green-800)"}">${r.deltaLucro >= 0 ? "+" : ""}${fmtMoney(r.deltaLucro)}</td>`,
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
      ? "Inclui fluxo de clientes, venda, quantidade, margem (p.p.), lucro bruto e progressão/regressão"
      : "Venda valor e quantidade, margem % (variação em p.p.), lucro bruto e progressão/regressão";

    document.querySelectorAll(".phase-btn").forEach((btn) => {
      btn.classList.toggle("active", btn.dataset.phase === state.phaseKey);
    });

    updateStoreBaseUi(phase);
    renderKpis(phase);
    renderLists(phase);
    renderTable(phase);
  }

  function bind() {
    els.phaseNav.addEventListener("click", (e) => {
      const btn = e.target.closest(".phase-btn");
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

    document.querySelectorAll(".chip-group:not(.store-base-group)").forEach((group) => {
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
      if (state.sortKey === key) {
        state.sortDir = state.sortDir === "asc" ? "desc" : "asc";
      } else {
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
