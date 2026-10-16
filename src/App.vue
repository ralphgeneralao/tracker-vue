<script setup>
import { computed, onMounted, onUnmounted, ref } from "vue";
import PersonalDashboard from "./components/dashboard/PersonalDashboard.vue";
import LandingPage from "./components/landing/LandingPage.vue";
import {
  supabase,
  supabaseConfigAvailable,
  supabaseConfigError,
} from "./lib/supabase.js";

const debts = ref([]);
const newDebtorName = ref("");
const newDebtAmount = ref("");
const newExpectedPaymentDate = ref(defaultPaymentDate());
const editingDebtId = ref(null);
const editingDebtorName = ref("");
const editingDebtAmount = ref("");
const editingPaymentDate = ref("");
const authUser = ref(null);
const authLoading = ref(true);
const authError = ref("");
const syncError = ref("");
const syncing = ref(false);
const activeUserId = ref(null);
const cloudReady = ref(false);
const canUseTracker = computed(() => Boolean(authUser.value && cloudReady.value));
const today = new Date();
const dateLabel = new Intl.DateTimeFormat("en", {
  weekday: "long",
  month: "long",
  day: "numeric",
}).format(today);
const totalOwed = computed(
  () =>
    debts.value.reduce(
      (totalCents, debt) => totalCents + Math.round(Number(debt.amount) * 100),
      0
    ) / 100
);

let authSubscription;

onMounted(() => {
  void initializeTracker();
});

onUnmounted(() => {
  authSubscription?.unsubscribe();
});

async function initializeTracker() {
  if (!supabase) {
    authLoading.value = false;
    return;
  }

  try {
    const { data, error } = await supabase.auth.getSession();
    if (error) throw error;

    await applySession(data.session);
    const { data: authState } = supabase.auth.onAuthStateChange((_event, session) => {
      queueMicrotask(() => void applySession(session));
    });
    authSubscription = authState.subscription;
  } catch (error) {
    authError.value = `Could not initialize Supabase: ${error.message}`;
    authLoading.value = false;
  }
}

async function applySession(session) {
  const user = session?.user || null;
  if (user?.id === activeUserId.value && cloudReady.value) {
    authUser.value = user;
    authLoading.value = false;
    return;
  }

  authLoading.value = true;
  authError.value = "";
  syncError.value = "";
  cloudReady.value = false;
  activeUserId.value = user?.id || null;
  authUser.value = user;
  debts.value = [];

  if (!user) {
    authLoading.value = false;
    return;
  }

  try {
    const { error: profileError } = await supabase.from("profiles").upsert(
      profileRecord(user),
      { onConflict: "id", ignoreDuplicates: true }
    );
    if (activeUserId.value !== user.id) return;
    if (profileError) throw profileError;

    const { data, error } = await supabase
      .from("debts")
      .select("id, debtor_name, amount, expected_payment_date")
      .eq("user_id", user.id)
      .order("expected_payment_date", { ascending: true });
    if (activeUserId.value !== user.id) return;
    if (error) throw error;

    debts.value = data.map(debtFromRow);
    cloudReady.value = true;
  } catch (error) {
    if (activeUserId.value !== user.id) return;
    authError.value = `Could not load your debts: ${error.message}`;
  } finally {
    if (activeUserId.value === user.id) authLoading.value = false;
  }
}

function profileRecord(user) {
  const metadata = user.user_metadata || {};
  return {
    id: user.id,
    display_name: metadata.full_name || metadata.name || user.email || null,
    avatar_url: metadata.avatar_url || metadata.picture || null,
    updated_at: new Date().toISOString(),
  };
}

function debtFromRow(row) {
  return {
    id: row.id,
    debtorName: row.debtor_name,
    amount: Number(row.amount),
    expectedPaymentDate: row.expected_payment_date,
  };
}

function debtToRow(userId, debt) {
  return {
    user_id: userId,
    id: debt.id,
    debtor_name: debt.debtorName,
    amount: debt.amount,
    expected_payment_date: debt.expectedPaymentDate,
    updated_at: new Date().toISOString(),
  };
}

async function signInWithGoogle() {
  if (!supabase) return;
  authLoading.value = true;
  authError.value = "";
  try {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: window.location.origin },
    });
    if (error) throw error;
  } catch (error) {
    authError.value = `Google sign-in failed: ${error.message}`;
    authLoading.value = false;
  }
}

async function signOut() {
  if (!supabase) return;
  authLoading.value = true;
  try {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  } catch (error) {
    authError.value = `Could not sign out: ${error.message}`;
    authLoading.value = false;
  }
}

async function retryProfileLoad() {
  if (!supabase) return;
  try {
    const { data, error } = await supabase.auth.getSession();
    if (error) throw error;
    await applySession(data.session);
  } catch (error) {
    authError.value = `Could not check your sign-in status: ${error.message}`;
  }
}

async function addDebt() {
  if (!canUseTracker.value) return;

  const debtorName = newDebtorName.value.trim();
  const amount = Number(newDebtAmount.value);
  const expectedPaymentDate = newExpectedPaymentDate.value;
  if (!debtorName || !Number.isFinite(amount) || amount <= 0 || !expectedPaymentDate) {
    syncError.value = "Enter a debtor name, a positive amount, and an expected payment date.";
    return;
  }

  const debt = {
    id: crypto.randomUUID(),
    debtorName,
    amount,
    expectedPaymentDate,
  };
  await persistDebt(debt, "Could not add debt");
  if (syncError.value) return;

  debts.value.push(debt);
  debts.value.sort((left, right) =>
    left.expectedPaymentDate.localeCompare(right.expectedPaymentDate)
  );
  newDebtorName.value = "";
  newDebtAmount.value = "";
  newExpectedPaymentDate.value = defaultPaymentDate();
}

function startEditing(debt) {
  if (!canUseTracker.value) return;
  editingDebtId.value = debt.id;
  editingDebtorName.value = debt.debtorName;
  editingDebtAmount.value = String(debt.amount);
  editingPaymentDate.value = debt.expectedPaymentDate;
  syncError.value = "";
}

function cancelEditing() {
  editingDebtId.value = null;
  editingDebtorName.value = "";
  editingDebtAmount.value = "";
  editingPaymentDate.value = "";
}

async function saveDebtEdit(debt) {
  if (!canUseTracker.value) return;
  const debtorName = editingDebtorName.value.trim();
  const amount = Number(editingDebtAmount.value);
  if (
    !debtorName ||
    !Number.isFinite(amount) ||
    amount <= 0 ||
    !editingPaymentDate.value
  ) {
    syncError.value = "Enter a debtor name, a positive amount, and an expected payment date.";
    return;
  }

  const updatedDebt = {
    ...debt,
    debtorName,
    amount,
    expectedPaymentDate: editingPaymentDate.value,
  };
  await persistDebt(updatedDebt, "Could not update debt");
  if (syncError.value) return;

  const index = debts.value.findIndex((item) => item.id === debt.id);
  if (index !== -1) debts.value[index] = updatedDebt;
  debts.value.sort((left, right) =>
    left.expectedPaymentDate.localeCompare(right.expectedPaymentDate)
  );
  cancelEditing();
}

async function persistDebt(debt, action) {
  const userId = activeUserId.value;
  if (!userId || !supabase) return;

  syncing.value = true;
  syncError.value = "";
  try {
    const { error } = await supabase
      .from("debts")
      .upsert(debtToRow(userId, debt), { onConflict: "user_id,id" });
    if (error) throw error;
  } catch (error) {
    syncError.value = `${action}: ${error.message}`;
  } finally {
    syncing.value = false;
  }
}

async function deleteDebt(id) {
  const userId = activeUserId.value;
  if (!canUseTracker.value || !supabase || !userId) return;

  syncing.value = true;
  syncError.value = "";
  try {
    const { error } = await supabase
      .from("debts")
      .delete()
      .eq("user_id", userId)
      .eq("id", id);
    if (error) throw error;

    debts.value = debts.value.filter((debt) => debt.id !== id);
    if (editingDebtId.value === id) cancelEditing();
  } catch (error) {
    syncError.value = `Could not delete debt: ${error.message}`;
  } finally {
    syncing.value = false;
  }
}

function defaultPaymentDate() {
  const date = new Date();
  date.setDate(date.getDate() + 7);
  return localDateKey(date);
}

function formatAmount(amount) {
  return new Intl.NumberFormat(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
}

function formatPaymentDate(value) {
  return new Intl.DateTimeFormat(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
    timeZone: "UTC",
  }).format(new Date(`${value}T00:00:00Z`));
}

function isOverdue(debt) {
  return debt.expectedPaymentDate < localDateKey(new Date());
}

function localDateKey(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}
</script>

<template>
  <div v-if="authLoading && !authUser" class="auth-loading" role="status">
    <span class="auth-loading-mark" aria-hidden="true">l.</span>
    <span>Preparing your debt tracker...</span>
  </div>
  <LandingPage
    v-else-if="!authUser"
    :configured="supabaseConfigAvailable"
    :config-error="supabaseConfigError"
    :auth-error="authError"
    :loading="authLoading"
    @login="signInWithGoogle"
    @retry="retryProfileLoad"
  />
  <PersonalDashboard
    v-else
    :user="authUser"
    :syncing="syncing"
    :auth-error="authError"
    :sync-error="syncError"
    :date-label="dateLabel"
    :debts="debts"
    :total-owed="totalOwed"
    :format-amount="formatAmount"
    :format-payment-date="formatPaymentDate"
    :is-overdue="isOverdue"
    :can-use-tracker="canUseTracker"
    :editing-debt-id="editingDebtId"
    :editing-debtor-name="editingDebtorName"
    :editing-debt-amount="editingDebtAmount"
    :editing-payment-date="editingPaymentDate"
    :new-debtor-name="newDebtorName"
    :new-debt-amount="newDebtAmount"
    :new-expected-payment-date="newExpectedPaymentDate"
    @logout="signOut"
    @retry="retryProfileLoad"
    @add-debt="addDebt"
    @start-editing="startEditing"
    @cancel-editing="cancelEditing"
    @save-debt-edit="saveDebtEdit"
    @delete-debt="deleteDebt"
    @update-new-debtor-name="newDebtorName = $event"
    @update-new-debt-amount="newDebtAmount = $event"
    @update-new-payment-date="newExpectedPaymentDate = $event"
    @update-editing-debtor-name="editingDebtorName = $event"
    @update-editing-debt-amount="editingDebtAmount = $event"
    @update-editing-payment-date="editingPaymentDate = $event"
  />
</template>
