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

async function logout() {
  await supabase.auth.signOut();
  window.location.replace("./admin-login.html");
}

document.getElementById("logout").addEventListener("click", logout);
document.getElementById("back-login").addEventListener("click", () => {
  window.location.replace("./admin-login.html");
});

function activateSection(section) {
  const allowedLink = document.querySelector(`[data-section="${section}"]`);
  if (!allowedLink || allowedLink.hidden) section = "overview";
  document.querySelectorAll("[data-section]").forEach((link) => {
    link.classList.toggle("active", link.dataset.section === section);
  });
  document.getElementById("overview-section").hidden = section !== "overview";
  document.querySelectorAll(".section-placeholder").forEach((panel) => {
    panel.classList.toggle("visible", panel.id === `${section}-section`);
  });
  document.getElementById("crumb-title").textContent =
    document.querySelector(`[data-section="${section}"]`)?.textContent.trim() || "Dashboard";
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
    document.getElementById("today").textContent = new Intl.DateTimeFormat("id-ID", {
      weekday: "long", day: "numeric", month: "long", year: "numeric"
    }).format(new Date());

    document.querySelectorAll("[data-roles]").forEach((link) => {
      const roles = link.dataset.roles.split(",");
      link.hidden = !roles.includes(role);
    });

    loading.hidden = true;
    denied.hidden = true;
    app.hidden = false;
    const requested = window.location.hash.replace("#", "");
    activateSection(requested || "overview");
  } catch (error) {
    console.error("Dashboard initialization failed:", error);
    showDenied("Dashboard gagal dimuat. Periksa koneksi internet dan konfigurasi Supabase, lalu coba lagi.");
  }
}

initializeDashboard();
