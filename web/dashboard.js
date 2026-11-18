import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "./config.js";

const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
const allowedRoles = ["super_admin", "fundraising_admin", "fundraising_staff", "viewer"];
const loading = document.getElementById("loading");
const denied = document.getElementById("denied");
const app = document.getElementById("app");

function showDenied(message) {
  loading.hidden = true;
  app.hidden = true;
  denied.hidden = false;
  document.getElementById("denied-message").textContent = message;
}
function formatRupiah(value) {
  return new Intl.NumberFormat("id-ID", { style: "currency", currency: "IDR", maximumFractionDigits: 0 }).format(Number(value || 0));
}
function formatNumber(value) {
  return new Intl.NumberFormat("id-ID").format(Number(value || 0));
}
function formatDate(value) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return new Intl.DateTimeFormat("id-ID", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }).format(date);
}
function showDataError(message) {
  const notice = document.getElementById("data-notice");
  notice.hidden = false;
  notice.className = "notice error-notice";
  document.getElementById("data-notice-title").textContent = "Data belum dapat dimuat";
  document.getElementById("data-notice-message").textContent = message;
}
function setStat(id, value, note) {
  document.getElementById(id).textContent = value;
  document.getElementById(id + "-note").textContent = note;
}
function renderRecentDonations(items, role) {
  const body = document.getElementById("recent-donations-body");
  const empty = document.getElementById("recent-empty");
  body.replaceChildren();
  if (role === "viewer") {
    empty.textContent = "Akses Viewer menampilkan ringkasan statistik. Rincian transaksi tidak ditampilkan.";
    empty.hidden = false;
    return;
  }
  if (!Array.isArray(items) || items.length === 0) {
    empty.textContent = "Belum ada transaksi donasi yang tercatat.";
    empty.hidden = false;
    return;
  }
  empty.hidden = true;
  for (const item of items) {
    const row = document.createElement("tr");
    const values = [item.transaction_code || "—", item.campaign_name || "Tanpa campaign", formatRupiah(item.amount), String(item.payment_status || "unknown").replaceAll("_", " "), formatDate(item.created_at)];
    for (const value of values) {
      const cell = document.createElement("td");
      cell.textContent = value;
      row.appendChild(cell);
    }
    body.appendChild(row);
  }
}
async function loadDashboardSummary(role) {
  const { data, error } = await supabase.rpc("get_dashboard_summary");
  if (error) {
    console.error("Dashboard summary error:", error);
    showDataError(error.code === "42501"
      ? "Sesi staf tidak valid atau tidak aktif. Keluar lalu login kembali."
      : "Koneksi ringkasan gagal. Pastikan database/dashboard-summary.sql sudah diterapkan dan coba muat ulang.");
    return;
  }
  setStat("total-amount", formatRupiah(data.total_amount_recorded), "Akumulasi nominal semua transaksi tercatat");
  setStat("total-transactions", formatNumber(data.total_transactions), "Seluruh transaksi yang tercatat");
  setStat("active-campaigns", formatNumber(data.active_campaigns), "Campaign dengan status aktif");
  setStat("total-donors", formatNumber(data.total_donors), "Jumlah data donatur");
  renderRecentDonations(data.recent_donations, role);
  const notice = document.getElementById("data-notice");
  notice.hidden = false;
  notice.className = "notice success-notice";
  document.getElementById("data-notice-title").textContent = "Dashboard terhubung ke database";
  document.getElementById("data-notice-message").textContent = "Ringkasan dimuat dari Supabase. Data diperbarui saat halaman dashboard dibuka.";
  document.getElementById("data-updated").textContent = "Diperbarui " + formatDate(data.generated_at);
}
async function logout() {
  await supabase.auth.signOut();
  window.location.replace("./admin-login.html");
}
document.getElementById("logout").addEventListener("click", logout);
document.getElementById("back-login").addEventListener("click", () => window.location.replace("./admin-login.html"));

function activateSection(section) {
  const allowedLink = document.querySelector(`[data-section="${section}"]`);
  if (!allowedLink || allowedLink.hidden) section = "overview";
  document.querySelectorAll("[data-section]").forEach((link) => link.classList.toggle("active", link.dataset.section === section));
  document.getElementById("overview-section").hidden = section !== "overview";
  document.querySelectorAll(".section-placeholder").forEach((panel) => panel.classList.toggle("visible", panel.id === `${section}-section`));
  document.getElementById("crumb-title").textContent = document.querySelector(`[data-section="${section}"]`)?.textContent.trim() || "Dashboard";
}
document.getElementById("navigation").addEventListener("click", (event) => {
  const link = event.target.closest("a[data-section]");
  if (!link) return;
  event.preventDefault();
  activateSection(link.dataset.section);
  history.replaceState(null, "", `#${link.dataset.section}`);
});
async function initializeDashboard() {
  try {
    const { data, error } = await supabase.auth.getClaims();
    if (error || !data?.claims) {
      showDenied("Sesi login tidak ditemukan atau tidak valid. Silakan login kembali.");
      return;
    }
    const claims = data.claims;
    if (claims.staff_active !== true || !allowedRoles.includes(claims.app_role)) {
      await supabase.auth.signOut();
      showDenied("Akun tidak memiliki role staf aktif. Hubungi Super Admin.");
      return;
    }
    const role = claims.app_role;
    document.getElementById("user-email").textContent = claims.email || "Akun staf";
    document.getElementById("user-role").textContent = role.replaceAll("_", " ").toUpperCase();
    document.getElementById("avatar").textContent = (claims.email || "A").charAt(0).toUpperCase();
    document.getElementById("today").textContent = new Intl.DateTimeFormat("id-ID", { weekday: "long", day: "numeric", month: "long", year: "numeric" }).format(new Date());
    document.querySelectorAll("[data-roles]").forEach((link) => {
      link.hidden = !link.dataset.roles.split(",").includes(role);
    });
    loading.hidden = true;
    denied.hidden = true;
    app.hidden = false;
    activateSection(window.location.hash.replace("#", "") || "overview");
    await loadDashboardSummary(role);
  } catch (error) {
    console.error("Dashboard initialization failed:", error);
    showDenied("Dashboard gagal dimuat. Periksa koneksi internet dan konfigurasi Supabase, lalu coba lagi.");
  }
}
initializeDashboard();
