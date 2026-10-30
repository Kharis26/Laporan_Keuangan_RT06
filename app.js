
(() => {
  "use strict";

  const cfg = window.SUPABASE_CONFIG || {};

  const state = {
    supabase: null,
    user: null,
    sessionVersion: 0,
    profile: null,
    cash: [],
    settings: {
      nama_bendahara: "",
      nama_ketua_rt: ""
    },
    categories: [],
    phase: "signed-out"
  };

  const $ = (id) => document.getElementById(id);

  const show = (id, visible) =>
    $(id)?.classList.toggle("hidden", !visible);

  const rupiah = (value) =>
    new Intl.NumberFormat("id-ID", {
      style: "currency",
      currency: "IDR",
      maximumFractionDigits: 0
    }).format(Number(value) || 0);

  const dateText = (value) =>
    value
      ? new Intl.DateTimeFormat("id-ID", {
          day: "2-digit",
          month: "short",
          year: "numeric"
        }).format(new Date(value))
      : "—";

  const escapeHtml = (value) =>
    String(value ?? "").replace(/[&<>"']/g, (c) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;"
    }[c]));

  const today = new Date();
  const monthNow = today.toISOString().slice(0, 7);
  const yearNow = String(today.getFullYear());

  function profileRoles() {
    const value = state.profile?.roles;

    if (Array.isArray(value)) {
      return value
        .map((role) => String(role).trim().toLowerCase())
        .filter(Boolean);
    }

    if (typeof value === "string") {
      return value
        .replace(/[{}"']/g, "")
        .split(",")
        .map((role) => role.trim().toLowerCase())
        .filter(Boolean);
    }

    return [];
  }

  const isAdmin = () =>
    profileRoles().includes("admin");

  const isTreasurer = () =>
    profileRoles().includes("bendahara");

  // Admin dan Bendahara boleh mengelola transaksi kas.
  const canEditCash = () =>
    isAdmin() || isTreasurer();

  const isConfigured = () =>
    typeof cfg.url === "string" &&
    /^https:\/\/[^\s/]+/.test(cfg.url) &&
    typeof cfg.anonKey === "string" &&
    cfg.anonKey.length > 20 &&
    !/service_role|secret|ISI_/i.test(cfg.anonKey);

  function setNotice(title, detail, visible = true) {
    show("sessionNotice", visible);

    if ($("sessionNoticeTitle")) {
      $("sessionNoticeTitle").textContent = title || "";
    }

    if ($("sessionNoticeText")) {
      $("sessionNoticeText").textContent = detail || "";
    }
  }

  function setMessage(id, text, type = "") {
    if (!$(id)) return;

    $(id).textContent = text || "";
    $(id).className = `message ${type}`.trim();
  }

  function directionLabel(value) {
    return value === "masuk"
      ? "Pemasukan"
      : value === "keluar"
        ? "Pengeluaran"
        : value || "—";
  }

  function directionClass(value) {
    return value === "masuk" ? "in" : "out";
  }

  function isOpening(item) {
    return Boolean(item?.is_saldo_awal) ||
      String(item?.kategori || "")
        .trim()
        .toLocaleLowerCase("id-ID") === "saldo awal";
  }

  function sumOpening(items) {
    return items
      .filter((item) =>
        isOpening(item) && item.status === "sah"
      )
      .reduce(
        (sum, item) => sum + Number(item.nominal || 0),
        0
      );
  }

  function sumCash(items, direction) {
    return items
      .filter((item) =>
        !isOpening(item) &&
        item.arah === direction &&
        item.status === "sah"
      )
      .reduce(
        (sum, item) => sum + Number(item.nominal || 0),
        0
      );
  }

  function balance(items) {
    return sumOpening(items) +
      sumCash(items, "masuk") -
      sumCash(items, "keluar");
  }

  function view(name) {
    document.querySelectorAll(".view").forEach((node) => {
      node.classList.toggle(
        "hidden",
        node.id !== `view-${name}`
      );
    });

    document.querySelectorAll(".navbtn").forEach((node) => {
      node.classList.toggle(
        "active",
        node.dataset.view === name
      );
    });

    if (window.location.hash !== `#${name}`) {
      window.history.replaceState(null, "", `#${name}`);
    }

    if (name === "monthly") renderMonthly();
    if (name === "yearly") renderYearly();
    if (name === "settings") renderSettings();
  }

  // Pengaturan hak akses tampilan.
  function renderMode() {
    const admin = isAdmin();
    const finance = canEditCash();

    show("cashAdminBox", finance);

    if ($("cashMode")) {
      $("cashMode").textContent = admin
        ? "Mode Admin"
        : finance
          ? "Mode Bendahara"
          : "Baca saja";

      $("cashMode").className =
        `read-only-badge ${finance ? "admin-badge" : ""}`;
    }

    if ($("modeNote")) {
      $("modeNote").textContent = finance
        ? "Anda dapat mencatat dan mengoreksi transaksi kas. Semua koreksi wajib memiliki alasan."
        : "Mode baca aktif. Anda dapat melihat arus kas dan LPJ tanpa mengubah data.";
    }

    // Menu pengaturan tetap khusus Admin.
    show("settingsAdminOnly", admin);
    show("settingsReadOnly", !admin);

    if ($("settingsMode")) {
      $("settingsMode").textContent =
        admin ? "Mode Admin" : "Baca saja";

      $("settingsMode").className =
        `read-only-badge ${admin ? "admin-badge" : ""}`;
    }
  }

  function renderStats() {
    const income = sumCash(state.cash, "masuk");
    const expense = sumCash(state.cash, "keluar");

    if ($("statBalance")) {
      $("statBalance").textContent =
        rupiah(balance(state.cash));
    }

    if ($("statIncome")) {
      $("statIncome").textContent = rupiah(income);
    }

    if ($("statExpense")) {
      $("statExpense").textContent = rupiah(expense);
    }

    if ($("statCount")) {
      $("statCount").textContent =
        state.cash.length.toLocaleString("id-ID");
    }
  }

  function filteredCash() {
    const term = (
      $("cashSearch")?.value || ""
    ).trim().toLocaleLowerCase("id-ID");

    const month = $("cashMonth")?.value || "";
    const filter = $("cashFilter")?.value || "";
    const start = $("cashStartDate")?.value || "";
    const end = $("cashEndDate")?.value || "";

    return state.cash.filter((item) => {
      const hay = `${item.kategori || ""} ${
        item.keterangan || ""
      }`.toLocaleLowerCase("id-ID");

      const date = String(item.tanggal || "");

      return (
        (!term || hay.includes(term)) &&
        (!month || date.startsWith(month)) &&
        (!filter || item.arah === filter) &&
        (!start || date >= start) &&
        (!end || date <= end)
      );
    });
  }

  function renderCash() {
    renderStats();

    const rows = filteredCash();

    if ($("cashRows")) {
      $("cashRows").innerHTML = rows.length
        ? rows.map((item) => {
            const editable =
              canEditCash() &&
              item.status === "sah" &&
              !isOpening(item) &&
              !item.pembayaran_id;

            const action = editable
              ? `<button
                    type="button"
                    class="button button-secondary cash-edit-button"
                    data-edit-cash="${escapeHtml(item.id)}"
                 >Edit</button>`
              : `<span class="hint">${
                  item.pembayaran_id
                    ? "Terhubung ke iuran"
                    : isOpening(item)
                      ? "Saldo awal"
                      : "—"
                }</span>`;

            return `
              <tr>
                <td>${escapeHtml(dateText(item.tanggal))}</td>
                <td>
                  <span class="direction direction-${escapeHtml(item.arah)}">
                    ${escapeHtml(
                      isOpening(item)
                        ? "Saldo awal"
                        : directionLabel(item.arah)
                    )}
                  </span>
                </td>
                <td><strong>${escapeHtml(item.kategori)}</strong></td>
                <td>${escapeHtml(rupiah(item.nominal))}</td>
                <td>${escapeHtml(item.keterangan || "—")}</td>
                <td>${action}</td>
              </tr>
            `;
          }).join("")
        : `<tr>
             <td colspan="6" class="empty-cell">
               Belum ada transaksi pada pilihan ini.
             </td>
           </tr>`;
    }

    if ($("cashState")) {
      $("cashState").textContent = state.cash.length
        ? `${rows.length} transaksi ditampilkan.`
        : "Belum ada transaksi kas.";
    }

    const start = $("cashStartDate")?.value || "";
    const end = $("cashEndDate")?.value || "";
    const month = $("cashMonth")?.value || "";

    if ($("cashPrintPeriod")) {
      $("cashPrintPeriod").textContent =
        start || end
          ? `Periode cetak: ${
              start ? dateText(start) : "awal"
            } s.d. ${
              end ? dateText(end) : "akhir"
            }`
          : month
            ? `Periode tampilan: ${month}`
            : "Periode cetak: semua tanggal";
    }
  }

  function validTransactions(items) {
    return items.filter((item) => item.status === "sah");
  }

  function movementTotals(items) {
    const valid = validTransactions(items);

    return {
      income: sumCash(valid, "masuk"),
      expense: sumCash(valid, "keluar")
    };
  }

  function balanceThrough(dateExclusive) {
    const eligible = state.cash.filter((item) =>
      item.status === "sah" &&
      (
        !dateExclusive ||
        String(item.tanggal || "") < dateExclusive
      )
    );

    return balance(eligible);
  }

  function balanceAtPeriodStart(periodStart) {
    const eligible = state.cash.filter((item) => {
      if (item.status !== "sah") return false;

      const date = String(item.tanggal || "");

      // Saldo pembukaan berlaku pada tanggal yang dipilih.
      // Transaksi biasa baru dihitung mulai setelah tanggal awal periode.
      return isOpening(item)
        ? date <= periodStart
        : date < periodStart;
    });

    return balance(eligible);
  }

  function reportTotals(items, periodStart) {
    const opening = balanceAtPeriodStart(periodStart);
    const movements = movementTotals(items);

    return {
      opening,
      income: movements.income,
      expense: movements.expense,
      balance: opening +
        movements.income -
        movements.expense
    };
  }

  function categoryRows(items, direction) {
    const map = new Map();

    items
      .filter((x) =>
        !isOpening(x) &&
        x.arah === direction &&
        x.status === "sah"
      )
      .forEach((x) => {
        map.set(
          x.kategori,
          (map.get(x.kategori) || 0) +
            Number(x.nominal || 0)
        );
      });

    return [...map.entries()]
      .sort((a, b) => b[1] - a[1])
      .map(([name, total]) => `
        <tr>
          <td>${escapeHtml(name)}</td>
          <td>${escapeHtml(rupiah(total))}</td>
        </tr>
      `)
      .join("") ||
      `<tr>
        <td colspan="2" class="empty-cell">
          Belum ada data
        </td>
      </tr>`;
  }

  function reportHead(title, period, totals) {
    const treasurer =
      state.settings.nama_bendahara || "Belum diatur";

    const chair =
      state.settings.nama_ketua_rt || "Belum diatur";

    return `
      <div class="report-title">
        <p class="eyebrow">
          LAPORAN KEUANGAN DIGITAL RT 06 RW 08
        </p>
        <h2>${title}</h2>
        <p>
          Periode: <strong>${escapeHtml(period)}</strong>
        </p>
        <p class="report-signers">
          Bendahara: ${escapeHtml(treasurer)}
          &nbsp; • &nbsp;
          Ketua RT: ${escapeHtml(chair)}
        </p>
      </div>

      <div class="report-stats">
        <div>
          <span>Saldo awal</span>
          <strong>${rupiah(totals.opening)}</strong>
        </div>
        <div>
          <span>Pemasukan</span>
          <strong>${rupiah(totals.income)}</strong>
        </div>
        <div>
          <span>Pengeluaran</span>
          <strong>${rupiah(totals.expense)}</strong>
        </div>
        <div>
          <span>Saldo akhir</span>
          <strong>${rupiah(totals.balance)}</strong>
        </div>
      </div>
    `;
  }

  function renderMonthly() {
    const period =
      $("monthlyPeriod")?.value || monthNow;

    const periodStart = `${period}-01`;

    const items = validTransactions(
      state.cash.filter((x) =>
        String(x.tanggal || "").startsWith(period)
      )
    );

    const totals = reportTotals(items, periodStart);

    if (!$("monthlyReport")) return;

    $("monthlyReport").innerHTML =
      reportHead("LPJ Bulanan", period, totals) +

      `<div class="report-columns">
        <div>
          <h3>Pemasukan per akun</h3>
          <table>
            <thead>
              <tr><th>Akun</th><th>Jumlah</th></tr>
            </thead>
            <tbody>
              ${categoryRows(items, "masuk")}
            </tbody>
          </table>
        </div>

        <div>
          <h3>Pengeluaran per akun</h3>
          <table>
            <thead>
              <tr><th>Akun</th><th>Jumlah</th></tr>
            </thead>
            <tbody>
              ${categoryRows(items, "keluar")}
            </tbody>
          </table>
        </div>
      </div>

      <h3>Daftar transaksi</h3>

      <table>
        <thead>
          <tr>
            <th>Tanggal</th>
            <th>Jenis</th>
            <th>Kategori</th>
            <th>Nominal</th>
            <th>Keterangan</th>
          </tr>
        </thead>
        <tbody>
          ${
            items.length
              ? items.map((x) => `
                  <tr>
                    <td>${escapeHtml(dateText(x.tanggal))}</td>
                    <td>${escapeHtml(directionLabel(x.arah))}</td>
                    <td>${escapeHtml(x.kategori)}</td>
                    <td>${escapeHtml(rupiah(x.nominal))}</td>
                    <td>${escapeHtml(x.keterangan || "—")}</td>
                  </tr>
                `).join("")
              : `<tr>
                  <td colspan="5" class="empty-cell">
                    Belum ada transaksi pada bulan ini.
                  </td>
                </tr>`
          }
        </tbody>
      </table>

      <p class="report-footnote">
        Saldo awal bukan pemasukan; saldo awal hanya menjadi
        dasar saldo kas. Iuran yang belum dibayar tidak dihitung
        sebagai pemasukan.
      </p>`;
  }

  function renderYearly() {
    const year =
      $("yearlyPeriod")?.value || yearNow;

    const yearStart = `${year}-01-01`;

    const items = validTransactions(
      state.cash.filter((x) =>
        String(x.tanggal || "").startsWith(String(year))
      )
    );

    const totals = reportTotals(items, yearStart);

    const months = Array.from(
      { length: 12 },
      (_, i) =>
        `${year}-${String(i + 1).padStart(2, "0")}`
    );

    const rows = months.map((month) => {
      const periodStart = `${month}-01`;

      const nextMonth = new Date(
        Number(month.slice(0, 4)),
        Number(month.slice(5, 7)),
        1
      );

      const periodEnd =
        `${nextMonth.getFullYear()}-${
          String(nextMonth.getMonth() + 1).padStart(2, "0")
        }-01`;

      const subset = items.filter((x) =>
        String(x.tanggal || "").startsWith(month)
      );

      const t = reportTotals(subset, periodStart);
      const closing = balanceThrough(periodEnd);

      return `
        <tr>
          <td>${escapeHtml(month)}</td>
          <td>${escapeHtml(rupiah(t.income))}</td>
          <td>${escapeHtml(rupiah(t.expense))}</td>
          <td>${escapeHtml(rupiah(closing))}</td>
        </tr>
      `;
    }).join("");

    if (!$("yearlyReport")) return;

    $("yearlyReport").innerHTML =
      reportHead("LPJ Tahunan", String(year), totals) +

      `<h3>Ringkasan per bulan</h3>

      <table>
        <thead>
          <tr>
            <th>Bulan</th>
            <th>Pemasukan</th>
            <th>Pengeluaran</th>
            <th>Selisih</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>

      <div class="report-columns">
        <div>
          <h3>Pemasukan per akun</h3>
          <table>
            <thead>
              <tr><th>Akun</th><th>Jumlah</th></tr>
            </thead>
            <tbody>
              ${categoryRows(items, "masuk")}
            </tbody>
          </table>
        </div>

        <div>
          <h3>Pengeluaran per akun</h3>
          <table>
            <thead>
              <tr><th>Akun</th><th>Jumlah</th></tr>
            </thead>
            <tbody>
              ${categoryRows(items, "keluar")}
            </tbody>
          </table>
        </div>
      </div>

      <p class="report-footnote">
        LPJ tahunan dihitung dari transaksi kas sah
        pada tahun buku yang dipilih.
      </p>`;
  }

  // Fungsi untuk membuat ulang pilihan kategori kas.
  function renderCategories() {
    const select = $("cashCategory");

    if (!select) return;

    const previous = select.value;

    select.innerHTML =
      `<option value="">Pilih akun/kategori</option>` +

      state.categories.map((item) => `
        <option value="${escapeHtml(item.nama)}">
          ${escapeHtml(item.nama)}
          · ${escapeHtml(directionLabel(item.arah))}
        </option>
      `).join("");

    if (
      [...select.options].some(
        (option) => option.value === previous
      )
    ) {
      select.value = previous;
    }
  }

  function renderSettings() {
    if ($("settingsTreasurer")) {
      $("settingsTreasurer").value =
        state.settings.nama_bendahara || "";
    }

    if ($("settingsChair")) {
      $("settingsChair").value =
        state.settings.nama_ketua_rt || "";
    }

    renderCategories();

    if ($("cashCategoryStatus")) {
      $("cashCategoryStatus").textContent =
        state.categories.length
          ? `${state.categories.length} akun tersedia.`
          : "Belum ada akun. Tambahkan kategori di Pengaturan terlebih dahulu.";
    }

    if ($("categoryList")) {
      $("categoryList").innerHTML =
        state.categories.length
          ? state.categories.map((item) => `
              <span class="category-chip">
                ${escapeHtml(item.nama)}
                · ${escapeHtml(directionLabel(item.arah))}
              </span>
            `).join("")
          : "Belum ada kategori.";
    }
  }

  async function loadAllCashTransactions() {
    const pageSize = 1000;
    const all = [];

    for (
      let offset = 0;
      ;
      offset += pageSize
    ) {
      const result = await state.supabase
        .from("transaksi_kas")
        .select(
          "id,tanggal,arah,kategori,nominal,status,keterangan,created_at,is_saldo_awal,pembayaran_id"
        )
        .order("tanggal", { ascending: false })
        .order("id", { ascending: false })
        .range(offset, offset + pageSize - 1);

      if (result.error) {
        return {
          data: null,
          error: result.error
        };
      }

      const page = result.data || [];

      all.push(...page);

      if (page.length < pageSize) break;
    }

    return {
      data: all,
      error: null
    };
  }

  async function loadData(version) {
    if (!state.supabase || !state.user) return;

    if ($("cashState")) {
      $("cashState").textContent = "Memuat arus kas…";
    }

    const [
      cashResult,
      settingsResult,
      categoriesResult
    ] = await Promise.all([
      loadAllCashTransactions(),

      state.supabase
        .from("pengaturan_rt")
        .select("nama_bendahara,nama_ketua_rt")
        .eq("id", true)
        .maybeSingle(),

      state.supabase
        .from("kategori_kas")
        .select("id,nama,arah,aktif")
        .eq("aktif", true)
        .order("nama")
    ]);

    if (
      version !== state.sessionVersion ||
      !state.user
    ) {
      return;
    }

    if (cashResult.error) {
      state.cash = [];

      if ($("cashState")) {
        $("cashState").textContent =
          `Data belum dapat dimuat: ${cashResult.error.message}`;
      }

      return;
    }

    state.cash = cashResult.data || [];

    if (!settingsResult.error && settingsResult.data) {
      state.settings = settingsResult.data;
    }

    if (!categoriesResult.error) {
      state.categories = categoriesResult.data || [];
    } else if ($("cashCategoryStatus")) {
      $("cashCategoryStatus").textContent =
        "Daftar akun belum tersedia. Jalankan migration setup_settings.sql di Supabase.";
    }

    renderCash();
    renderSettings();
    renderMonthly();
    renderYearly();
  }

  async function profileAndLoad(session) {
    state.user = session?.user || null;
    state.sessionVersion += 1;

    const version = state.sessionVersion;

    if (!state.user) {
      state.profile = null;
      state.phase = "signed-out";
      state.cash = [];

      show("loginPanel", true);
      show("appPanel", false);
      show("logoutBtn", false);
      show("roleLabel", false);

      if ($("activeEmail")) {
        $("activeEmail").textContent = "";
      }

      return;
    }

    state.phase = "checking";

    show("loginPanel", false);
    show("logoutBtn", true);
    show("roleLabel", true);

    if ($("roleLabel")) {
      $("roleLabel").textContent = "Memeriksa akses…";
    }

    const {
      data,
      error
    } = await state.supabase.rpc("profil_saya");

    if (version !== state.sessionVersion) return;

    if (
      error ||
      !data ||
      data.aktif === false
    ) {
      state.phase = "inactive";
      state.profile = data || null;

      setNotice(
        "Akun belum siap",
        error?.message ||
          "Profil pengguna belum tersedia atau belum aktif."
      );

      show("appPanel", false);

      return;
    }

    state.profile = data;
    state.phase = "ready";

    setNotice("", "", false);

    if ($("userLabel")) {
      $("userLabel").textContent =
        data.nama || state.user.email || "Pengguna";
    }

    if ($("activeEmail")) {
      $("activeEmail").textContent =
        state.user.email
          ? `Akun aktif: ${state.user.email}`
          : "";
    }

    if ($("roleLabel")) {
      $("roleLabel").textContent =
        profileRoles().join(" · ") || "Warga";
    }

    if ($("sessionState")) {
      $("sessionState").textContent = "Sesi aktif";
      $("sessionState").className =
        "status-chip status-success";
    }

    show("appPanel", true);

    renderMode();

    await loadData(version);
  }

  function startEditCash(id) {
    if (!canEditCash()) return;

    const item = state.cash.find(
      (row) => row.id === id
    );

    if (
      !item ||
      item.status !== "sah" ||
      isOpening(item) ||
      item.pembayaran_id
    ) {
      setMessage(
        "cashFormMessage",
        "Transaksi ini tidak dapat diedit di sini. Transaksi iuran dan saldo awal harus dikoreksi melalui proses khusus.",
        "error"
      );

      return;
    }

    $("cashEditId").value = item.id;
    $("cashDate").value = item.tanggal || "";
    $("cashDirection").value = item.arah;

    renderCategories();

    // Pertahankan kategori lama jika sudah tidak aktif.
    if (
      ![...$("cashCategory").options].some(
        (option) => option.value === item.kategori
      )
    ) {
      const option = document.createElement("option");

      option.value = item.kategori;
      option.textContent =
        `${item.kategori} · kategori lama`;

      $("cashCategory").appendChild(option);
    }

    $("cashCategory").value = item.kategori;
    $("cashAmount").value = String(item.nominal);
    $("cashNote").value = item.keterangan || "";

    show("cashCorrectionReasonWrap", true);
    show("cashCancelEdit", true);

    $("cashFormTitle").textContent =
      "Edit transaksi arus kas";

    $("cashSubmitButton").textContent =
      "Simpan koreksi";

    setMessage(
      "cashFormMessage",
      "Periksa data dan isi alasan koreksi sebelum menyimpan."
    );

    $("cashFormTitle").scrollIntoView({
      behavior: "smooth",
      block: "center"
    });
  }

  function cancelEditCash() {
    if (!$("cashEditId")) return;

    $("cashEditId").value = "";

    if ($("cashCorrectionReason")) {
      $("cashCorrectionReason").value = "";
    }

    show("cashCorrectionReasonWrap", false);
    show("cashCancelEdit", false);

    if ($("cashFormTitle")) {
      $("cashFormTitle").textContent =
        "Catat transaksi";
    }

    if ($("cashSubmitButton")) {
      $("cashSubmitButton").textContent =
        "Simpan transaksi";
    }

    $("cashForm")?.reset();

    if ($("cashDate")) {
      $("cashDate").value =
        new Date().toISOString().slice(0, 10);
    }

    setMessage("cashFormMessage", "");
  }

  async function submitCash(event) {
    event.preventDefault();

    // Admin dan Bendahara boleh mencatat atau mengoreksi kas.
    if (!canEditCash()) return;

    const editId = $("cashEditId").value;

    const payload = {
      p_tanggal: $("cashDate").value,
      p_arah: $("cashDirection").value,
      p_kategori: $("cashCategory").value.trim(),
      p_nominal: Number($("cashAmount").value),
      p_keterangan:
        $("cashNote").value.trim() || null,
      p_bukti_path: null
    };

    if (
      !payload.p_tanggal ||
      !payload.p_kategori ||
      !Number.isSafeInteger(payload.p_nominal) ||
      payload.p_nominal <= 0
    ) {
      setMessage(
        "cashFormMessage",
        "Lengkapi tanggal, kategori, dan nominal yang benar.",
        "error"
      );

      return;
    }

    if (editId) {
      const reason =
        $("cashCorrectionReason").value.trim();

      if (reason.length < 5) {
        setMessage(
          "cashFormMessage",
          "Alasan koreksi wajib diisi minimal 5 karakter.",
          "error"
        );

        return;
      }

      Object.assign(payload, {
        p_id: editId,
        p_alasan_koreksi: reason
      });
    }

    const confirmation = editId
      ? `Simpan koreksi transaksi menjadi ${rupiah(payload.p_nominal)}? Riwayat perubahan akan dicatat.`
      : `Simpan ${
          payload.p_arah === "masuk"
            ? "pemasukan"
            : "pengeluaran"
        } ${rupiah(payload.p_nominal)}?`;

    if (!window.confirm(confirmation)) return;

    const button = $("cashSubmitButton");

    button.disabled = true;

    setMessage(
      "cashFormMessage",
      editId
        ? "Menyimpan koreksi…"
        : "Menyimpan transaksi…"
    );

    const {
      error
    } = editId
      ? await state.supabase.rpc(
          "admin_koreksi_transaksi_kas",
          payload
        )
      : await state.supabase.rpc(
          "catat_transaksi_kas",
          payload
        );

    button.disabled = false;

    if (error) {
      setMessage(
        "cashFormMessage",
        error.message || "Transaksi gagal disimpan.",
        "error"
      );

      return;
    }

    cancelEditCash();

    setMessage(
      "cashFormMessage",
      editId
        ? "Koreksi berhasil disimpan dan dicatat dalam riwayat."
        : "Transaksi berhasil disimpan.",
      "success"
    );

    await loadData(state.sessionVersion);
  }

  async function submitSettings(event) {
    event.preventDefault();

    if (!isAdmin()) return;

    const payload = {
      p_nama_bendahara:
        $("settingsTreasurer").value.trim(),

      p_nama_ketua_rt:
        $("settingsChair").value.trim()
    };

    const button =
      event.currentTarget.querySelector("button");

    button.disabled = true;

    setMessage(
      "settingsFormMessage",
      "Menyimpan…"
    );

    const {
      data,
      error
    } = await state.supabase.rpc(
      "admin_simpan_pengaturan",
      payload
    );

    button.disabled = false;

    if (error) {
      setMessage(
        "settingsFormMessage",
        error.message,
        "error"
      );

      return;
    }

    state.settings = data || payload;

    setMessage(
      "settingsFormMessage",
      "Identitas LPJ berhasil disimpan.",
      "success"
    );

    renderMonthly();
    renderYearly();
  }

  async function submitOpening(event) {
    event.preventDefault();

    if (!isAdmin()) return;

    const payload = {
      p_tanggal: $("openingDate").value,
      p_nominal: Number($("openingAmount").value),
      p_keterangan:
        $("openingNote").value.trim() || null
    };

    if (
      !payload.p_tanggal ||
      payload.p_nominal <= 0
    ) {
      setMessage(
        "openingFormMessage",
        "Tanggal dan nominal saldo awal wajib diisi.",
        "error"
      );

      return;
    }

    if (
      !window.confirm(
        `Tetapkan saldo awal ${rupiah(payload.p_nominal)}? Saldo awal hanya boleh satu kali.`
      )
    ) {
      return;
    }

    const button =
      event.currentTarget.querySelector("button");

    button.disabled = true;

    setMessage(
      "openingFormMessage",
      "Menyimpan…"
    );

    const {
      error
    } = await state.supabase.rpc(
      "admin_set_saldo_awal",
      payload
    );

    button.disabled = false;

    if (error) {
      setMessage(
        "openingFormMessage",
        error.message,
        "error"
      );

      return;
    }

    setMessage(
      "openingFormMessage",
      "Saldo awal berhasil ditetapkan.",
      "success"
    );

    event.currentTarget.reset();

    await loadData(state.sessionVersion);
  }

  async function submitCategory(event) {
    event.preventDefault();

    if (!isAdmin()) return;

    const payload = {
      p_nama: $("categoryName").value.trim(),
      p_arah: $("categoryDirection").value
    };

    const button =
      event.currentTarget.querySelector("button");

    button.disabled = true;

    setMessage(
      "categoryFormMessage",
      "Menyimpan…"
    );

    const {
      error
    } = await state.supabase.rpc(
      "admin_tambah_kategori",
      payload
    );

    button.disabled = false;

    if (error) {
      setMessage(
        "categoryFormMessage",
        error.message,
        "error"
      );

      return;
    }

    setMessage(
      "categoryFormMessage",
      "Kategori berhasil ditambahkan.",
      "success"
    );

    event.currentTarget.reset();

    await loadData(state.sessionVersion);
  }

  async function submitReset(event) {
    event.preventDefault();

    if (!isAdmin()) return;

    const confirmation =
      $("resetConfirmation").value.trim();

    if (confirmation !== "RESET RT06") {
      setMessage(
        "resetFormMessage",
        "Ketik RESET RT06 persis seperti contoh.",
        "error"
      );

      return;
    }

    if (
      !window.confirm(
        "PERINGATAN: seluruh data uji coba akan dihapus dan tidak dapat dipulihkan. Lanjutkan?"
      )
    ) {
      return;
    }

    const button =
      event.currentTarget.querySelector("button");

    button.disabled = true;

    setMessage(
      "resetFormMessage",
      "Menghapus data uji coba…"
    );

    const {
      data,
      error
    } = await state.supabase.rpc(
      "admin_reset_data_uji",
      {
        p_konfirmasi: confirmation
      }
    );

    button.disabled = false;

    if (error) {
      setMessage(
        "resetFormMessage",
        error.message,
        "error"
      );

      return;
    }

    setMessage(
      "resetFormMessage",
      `Reset selesai. ${
        Number(data?.transaksi_kas_dihapus || 0)
      } transaksi kas dihapus.`,
      "success"
    );

    event.currentTarget.reset();

    await loadData(state.sessionVersion);
  }

  function printCash() {
    const start =
      $("cashStartDate")?.value || "";

    const end =
      $("cashEndDate")?.value || "";

    if (start && end && start > end) {
      setMessage(
        "cashState",
        "Tanggal mulai tidak boleh setelah tanggal akhir.",
        "error"
      );

      return;
    }

    view("cash");

    window.print();
  }

  function printReport() {
    window.print();
  }

  function bindEvents() {
    $("loginForm")?.addEventListener(
      "submit",
      async (event) => {
        event.preventDefault();

        const email = $("email").value.trim();
        const password = $("password").value;

        if (!email || !password) {
          setMessage(
            "loginMessage",
            "Email dan kata sandi wajib diisi.",
            "error"
          );

          return;
        }

        const button = $("loginButton");

        if (button) {
          button.disabled = true;
          button.textContent = "Memeriksa…";
        }

        setMessage(
          "loginMessage",
          "Memeriksa akun…"
        );

        const {
          error
        } = await state.supabase.auth.signInWithPassword({
          email,
          password
        });

        if (button) {
          button.disabled = false;
          button.textContent = "Masuk";
        }

        if (error) {
          const raw =
            String(error.message || "").toLowerCase();

          const message =
            raw.includes("email not confirmed")
              ? "Email belum dikonfirmasi di Supabase Authentication."
              : raw.includes("invalid login credentials")
                ? "Email atau kata sandi tidak cocok. Periksa kembali akun di Supabase Authentication."
                : raw.includes("too many requests")
                  ? "Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi."
                  : `Login gagal: ${
                      error.message ||
                      "periksa email dan kata sandi."
                    }`;

          setMessage(
            "loginMessage",
            message,
            "error"
          );
        }
      }
    );

    $("logoutBtn")?.addEventListener(
      "click",
      () => state.supabase.auth.signOut()
    );

    document.querySelectorAll(".navbtn").forEach(
      (button) => {
        button.addEventListener(
          "click",
          () => view(button.dataset.view)
        );
      }
    );

    [
      "cashSearch",
      "cashMonth",
      "cashFilter",
      "cashStartDate",
      "cashEndDate"
    ].forEach((id) => {
      $(id)?.addEventListener("input", renderCash);
      $(id)?.addEventListener("change", renderCash);
    });

    $("cashRows")?.addEventListener(
      "click",
      (event) => {
        const button =
          event.target.closest("[data-edit-cash]");

        if (button) {
          startEditCash(button.dataset.editCash);
        }
      }
    );

    $("cashCancelEdit")?.addEventListener(
      "click",
      cancelEditCash
    );

    $("monthlyPeriod")?.addEventListener(
      "input",
      renderMonthly
    );

    $("printCash")?.addEventListener(
      "click",
      printCash
    );

    $("yearlyPeriod")?.addEventListener(
      "input",
      renderYearly
    );

    $("printMonthly")?.addEventListener(
      "click",
      printReport
    );

    $("printYearly")?.addEventListener(
      "click",
      printReport
    );

    $("cashForm")?.addEventListener(
      "submit",
      submitCash
    );

    $("settingsForm")?.addEventListener(
      "submit",
      submitSettings
    );

    $("openingForm")?.addEventListener(
      "submit",
      submitOpening
    );

    $("categoryForm")?.addEventListener(
      "submit",
      submitCategory
    );

    $("resetForm")?.addEventListener(
      "submit",
      submitReset
    );

    if ($("cashDate")) {
      $("cashDate").value =
        new Date().toISOString().slice(0, 10);
    }

    if ($("monthlyPeriod")) {
      $("monthlyPeriod").value = monthNow;
    }

    if ($("yearlyPeriod")) {
      $("yearlyPeriod").value = yearNow;
    }

    window.addEventListener(
      "hashchange",
      () => {
        const name =
          window.location.hash.slice(1);

        if (
          ["cash", "monthly", "yearly", "settings"]
            .includes(name)
        ) {
          view(name);
        }
      }
    );
  }

  async function init() {
    bindEvents();

    if (
      !isConfigured() ||
      !window.supabase?.createClient
    ) {
      show("setupNotice", true);

      if ($("connectionState")) {
        $("connectionState").textContent =
          "Konfigurasi belum siap";
      }

      return;
    }

    state.supabase = window.supabase.createClient(
      cfg.url,
      cfg.anonKey
    );

    if ($("connectionState")) {
      $("connectionState").textContent =
        "Supabase siap";
    }

    state.supabase.auth.onAuthStateChange(
      (_event, session) => {
        window.setTimeout(
          () => profileAndLoad(session),
          0
        );
      }
    );

    const {
      data: { session }
    } = await state.supabase.auth.getSession();

    await profileAndLoad(session);

    const initial =
      window.location.hash.slice(1);

    if (
      ["cash", "monthly", "yearly", "settings"]
        .includes(initial)
    ) {
      view(initial);
    }
  }

  init();
})();
