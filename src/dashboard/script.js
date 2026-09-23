const REPORT_URL = "data/latest.json";

async function loadReport() {
  try {
    const response = await fetch(REPORT_URL, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`Report fetch failed: ${response.status}`);
    }
    const report = await response.json();
    renderReport(report);
  } catch (err) {
    document.getElementById("generated-at").textContent =
      "Could not load the latest report. The collector Lambda may not have run yet.";
    console.error(err);
  }
}

function renderReport(report) {
  document.getElementById("generated-at").textContent =
    `Last updated: ${report.generated_at}`;

  const forecast = report.forecast || {};
  document.getElementById("forecast-amount").textContent =
    forecast.forecasted_amount != null ? `$${forecast.forecasted_amount.toFixed(2)}` : "N/A";

  document.getElementById("co-status").textContent =
    report.compute_optimizer_enrollment || "Unknown";

  const allSavings = [
    ...(report.rightsizing_recommendations || []),
    ...(report.graviton_candidates || []),
  ].reduce((sum, item) => sum + (item.estimated_monthly_savings || 0), 0);
  document.getElementById("total-savings").textContent = `$${allSavings.toFixed(2)}`;

  renderDailyCostChart(report.cost?.daily_totals || []);
  renderTopServicesChart(report.cost?.top_services || []);
  renderTable("rightsizing-table", "rightsizing-empty", report.rightsizing_recommendations || [],
    r => [r.instance_id, r.current_type, r.recommended_type, `$${r.estimated_monthly_savings.toFixed(2)}`, r.finding]);
  renderTable("graviton-table", "graviton-empty", report.graviton_candidates || [],
    r => [r.instance_arn, r.current_type, r.recommended_type, r.finding, `$${r.estimated_monthly_savings.toFixed(2)}`]);
  renderTable("lambda-table", "lambda-empty", report.idle_lambda_functions || [],
    r => [r.function_arn, r.current_memory_mb, r.finding]);
}

function renderDailyCostChart(dailyTotals) {
  const ctx = document.getElementById("dailyCostChart");
  new Chart(ctx, {
    type: "line",
    data: {
      labels: dailyTotals.map(d => d.date),
      datasets: [{
        label: "Daily cost (USD)",
        data: dailyTotals.map(d => d.amount),
        borderColor: "#38bdf8",
        backgroundColor: "rgba(56, 189, 248, 0.15)",
        fill: true,
        tension: 0.25,
      }],
    },
    options: {
      responsive: true,
      plugins: { legend: { labels: { color: "#e2e8f0" } } },
      scales: {
        x: { ticks: { color: "#94a3b8" }, grid: { color: "#334155" } },
        y: { ticks: { color: "#94a3b8" }, grid: { color: "#334155" } },
      },
    },
  });
}

function renderTopServicesChart(topServices) {
  const ctx = document.getElementById("topServicesChart");
  new Chart(ctx, {
    type: "bar",
    data: {
      labels: topServices.map(s => s.service),
      datasets: [{
        label: "Cost (USD, last 30 days)",
        data: topServices.map(s => s.amount),
        backgroundColor: "#a855f7",
      }],
    },
    options: {
      indexAxis: "y",
      responsive: true,
      plugins: { legend: { display: false } },
      scales: {
        x: { ticks: { color: "#94a3b8" }, grid: { color: "#334155" } },
        y: { ticks: { color: "#94a3b8" }, grid: { color: "#334155" } },
      },
    },
  });
}

function renderTable(tableId, emptyId, items, rowMapper) {
  const table = document.getElementById(tableId);
  const emptyState = document.getElementById(emptyId);
  const tbody = table.querySelector("tbody");
  tbody.innerHTML = "";

  if (!items.length) {
    table.hidden = true;
    emptyState.hidden = false;
    return;
  }

  table.hidden = false;
  emptyState.hidden = true;

  for (const item of items) {
    const row = document.createElement("tr");
    for (const cell of rowMapper(item)) {
      const td = document.createElement("td");
      td.textContent = cell;
      row.appendChild(td);
    }
    tbody.appendChild(row);
  }
}

loadReport();
