<script setup>
import { computed, onMounted, onUnmounted, ref, watch } from "vue";
import { starterHabits } from "./common/starterHabits.js";
import PersonalDashboard from "./components/dashboard/PersonalDashboard.vue";
import LandingPage from "./components/landing/LandingPage.vue";
import {
  supabase,
  supabaseConfigAvailable,
  supabaseConfigError,
} from "./lib/supabase.js";

const STORAGE_KEY = "little-by-little-habits";
const MIN_FINISH_MINUTES = 1;
const MAX_FINISH_DAYS = 30;
const today = new Date();
const todayKey = dateKey(today);
const currentTime = ref(Date.now());
const habits = ref([]);
const newHabitName = ref("");
const newHabitDeadline = ref(
  toDateTimeLocal(new Date(Date.now() + 24 * 60 * 60 * 1000))
);
const minFinishAt = ref("");
const maxFinishAt = ref("");
const finishTimeError = ref("");
const extendingHabitId = ref(null);
const extendedDeadline = ref("");
const extendTimeError = ref("");
const editingHabitId = ref(null);
const editingHabitName = ref("");
const authUser = ref(null);
const authLoading = ref(true);
const authError = ref("");
const syncError = ref("");
const syncing = ref(false);
const activeUserId = ref(null);
const cloudReady = ref(false);
const canUseTracker = computed(() => !authUser.value || cloudReady.value);
const isReady = ref(false);
let authSubscription;
let saveQueue = Promise.resolve();
let clockInterval;

refreshFinishBounds();

const dateLabel = new Intl.DateTimeFormat("en", {
  weekday: "long",
  month: "long",
  day: "numeric",
}).format(today);

const completedCount = computed(
  () => habits.value.filter((habit) => habit.completions.includes(todayKey)).length
);
const progress = computed(() =>
  habits.value.length ? Math.round((completedCount.value / habits.value.length) * 100) : 0
);
const remainingCount = computed(() => habits.value.length - completedCount.value);

const streak = computed(() => {
  if (!habits.value.length) return 0;

  let count = 0;
  const cursor = new Date(today);
  while (habits.value.every((habit) => habit.completions.includes(dateKey(cursor)))) {
    count += 1;
    cursor.setDate(cursor.getDate() - 1);
  }
  return count;
});

const weekProgress = computed(() => {
  if (!habits.value.length) return 0;

  const dayOfWeek = (today.getDay() + 6) % 7;
  const weekStart = new Date(today);
  weekStart.setDate(today.getDate() - dayOfWeek);
  const possibleCheckIns = habits.value.length * (dayOfWeek + 1);
  let checkIns = 0;

  for (const habit of habits.value) {
    checkIns += habit.completions.filter((completion) => {
      const completedOn = new Date(`${completion}T00:00:00`);
      return completedOn >= weekStart && completedOn <= today;
    }).length;
  }

  return Math.round((checkIns / possibleCheckIns) * 100);
});

onMounted(() => {
  void initializeTracker();
  clockInterval = window.setInterval(() => {
    currentTime.value = Date.now();
    const editingHabit = habits.value.find((habit) => habit.id === editingHabitId.value);
    if (editingHabit && isExpired(editingHabit)) cancelEditing();
  }, 1000);
});

onUnmounted(() => {
  window.clearInterval(clockInterval);
  authSubscription?.unsubscribe();
});

watch(
  habits,
  (value) => {
    if (!isReady.value) return;

    const userId = activeUserId.value;
    try {
      localStorage.setItem(
        userId ? `${STORAGE_KEY}:${userId}` : STORAGE_KEY,
        JSON.stringify(value)
      );
    } catch (error) {
      syncError.value = `Could not save a local tracker copy: ${error.message}`;
    }

    if (userId && cloudReady.value && supabase) {
      queueCloudSync(JSON.parse(JSON.stringify(value)), userId);
    }
  },
  { deep: true }
);

async function initializeTracker() {
  if (!supabase) {
    habits.value = readLocalHabits(STORAGE_KEY) || starterHabits;
    isReady.value = true;
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
    habits.value = readLocalHabits(STORAGE_KEY) || starterHabits;
    isReady.value = true;
    authLoading.value = false;
  }
}

function readLocalHabits(key) {
  try {
    const savedHabits = localStorage.getItem(key);
    if (!savedHabits) return null;
    const parsedHabits = JSON.parse(savedHabits);
    if (Array.isArray(parsedHabits)) return parsedHabits;
    console.warn(`Ignoring invalid saved tracker data in ${key}.`);
  } catch (error) {
    console.error(`Could not read saved tracker data in ${key}.`, error);
  }
  return null;
}

async function applySession(session, forceReload = false) {
  const user = session?.user || null;
  const userId = user?.id || null;
  if (!forceReload && userId === activeUserId.value && isReady.value) {
    authUser.value = user;
    return;
  }

  authLoading.value = true;
  authError.value = "";
  syncError.value = "";
  cloudReady.value = false;
  isReady.value = false;
  activeUserId.value = userId;
  authUser.value = user;
  habits.value = [];

  if (!user) {
    habits.value = readLocalHabits(STORAGE_KEY) || starterHabits;
    isReady.value = true;
    authLoading.value = false;
    return;
  }

  try {
    const { data: profile, error } = await supabase
      .from("profiles")
      .select("id")
      .eq("id", user.id)
      .maybeSingle();

    if (activeUserId.value !== user.id) return;
    if (error) throw error;

    if (!profile) {
      const { error: createError } = await supabase
        .from("profiles")
        .upsert(profileRecord(user), { onConflict: "id" });
      if (activeUserId.value !== user.id) return;
      if (createError) throw createError;
    }

    const { data: habitRows, error: habitsError } = await supabase
      .from("habits")
      .select("id, name, icon, color, completions, expected_finish_at")
      .eq("user_id", user.id)
      .order("created_at", { ascending: true });
    if (activeUserId.value !== user.id) return;
    if (habitsError) throw habitsError;

    if (habitRows.length) {
      habits.value = habitRows.map(habitFromRow);
    } else {
      const initialHabits = profile
        ? []
        : readLocalHabits(`${STORAGE_KEY}:${user.id}`) ||
          readLocalHabits(STORAGE_KEY) ||
          starterHabits;
      if (initialHabits.length) {
        const { error: seedError } = await supabase
          .from("habits")
          .insert(initialHabits.map((habit) => habitToRow(user.id, habit)));
        if (activeUserId.value !== user.id) return;
        if (seedError) throw seedError;
      }
      habits.value = initialHabits;
    }

    cloudReady.value = true;
    isReady.value = true;
    authLoading.value = false;
  } catch (error) {
    if (activeUserId.value !== user.id) return;
    habits.value = [];
    authError.value = `Could not load your profile: ${error.message}`;
    isReady.value = true;
    authLoading.value = false;
  }
}

function profileRecord(user) {
  const metadata = user?.user_metadata || {};
  return {
    id: user.id,
    display_name: metadata.full_name || metadata.name || user.email || null,
    avatar_url: metadata.avatar_url || metadata.picture || null,
    updated_at: new Date().toISOString(),
  };
}

function habitFromRow(row) {
  return {
    id: row.id,
    name: row.name,
    icon: row.icon,
    color: row.color,
    completions: row.completions || [],
    expectedFinishAt: row.expected_finish_at,
  };
}

function habitToRow(userId, habit) {
  return {
    user_id: userId,
    id: String(habit.id),
    name: habit.name,
    icon: habit.icon,
    color: habit.color,
    completions: habit.completions || [],
    expected_finish_at: habit.expectedFinishAt || null,
    updated_at: new Date().toISOString(),
  };
}

function queueCloudSync(habitsSnapshot, userId) {
  saveQueue = saveQueue.then(async () => {
    if (
      activeUserId.value !== userId ||
      !cloudReady.value ||
      !supabase ||
      habitsSnapshot.length === 0
    ) {
      return;
    }
    syncing.value = true;
    try {
      const { error } = await supabase
        .from("habits")
        .upsert(habitsSnapshot.map((habit) => habitToRow(userId, habit)), {
          onConflict: "user_id,id",
        });
      if (activeUserId.value === userId) {
        syncError.value = error ? `Could not sync tracker: ${error.message}` : "";
      }
    } catch (error) {
      if (activeUserId.value === userId) {
        syncError.value = `Could not sync tracker: ${error.message}`;
      }
    } finally {
      syncing.value = false;
    }
  });
  return saveQueue;
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
  await saveQueue;
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
  if (activeUserId.value && authUser.value) {
    await applySession({ user: authUser.value }, true);
  } else {
    try {
      const { data, error } = await supabase.auth.getSession();
      if (error) throw error;
      await applySession(data.session, true);
    } catch (error) {
      authError.value = `Could not check your sign-in status: ${error.message}`;
    }
  }
}

function dateKey(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function toDateTimeLocal(date) {
  const localDate = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return localDate.toISOString().slice(0, 16);
}

function refreshFinishBounds() {
  const now = Date.now();
  const earliestMinute =
    Math.ceil((now + MIN_FINISH_MINUTES * 60_000) / 60_000) * 60_000;
  const latestMinute =
    Math.floor((now + MAX_FINISH_DAYS * 24 * 60 * 60_000) / 60_000) * 60_000;
  minFinishAt.value = toDateTimeLocal(new Date(earliestMinute));
  maxFinishAt.value = toDateTimeLocal(new Date(latestMinute));
}

function formatExpectedFinish(value) {
  return new Intl.DateTimeFormat("en", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(value));
}

function isExpired(habit) {
  const now = Math.max(currentTime.value, Date.now());
  return Boolean(habit.expectedFinishAt) && Date.parse(habit.expectedFinishAt) <= now;
}

function toggleHabit(habit) {
  if (!canUseTracker.value || isExpired(habit)) return;
  const index = habit.completions.indexOf(todayKey);
  if (index === -1) habit.completions.push(todayKey);
  else habit.completions.splice(index, 1);
}

function addHabit() {
  if (!canUseTracker.value) return;
  const name = newHabitName.value.trim();
  if (!name) return;

  const finishAt = new Date(newHabitDeadline.value).getTime();
  const now = Date.now();
  if (
    !Number.isFinite(finishAt) ||
    finishAt < now + MIN_FINISH_MINUTES * 60_000 ||
    finishAt > now + MAX_FINISH_DAYS * 24 * 60 * 60_000
  ) {
    finishTimeError.value = "Choose a finish time between 1 minute and 30 days from now.";
    refreshFinishBounds();
    return;
  }

  const colors = ["blue", "orange", "green", "pink"];
  const icons = ["✳", "◌", "⌁", "✦"];
  const nextIndex = habits.value.length;
  habits.value.push({
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    name,
    icon: icons[nextIndex % icons.length],
    color: colors[nextIndex % colors.length],
    completions: [],
    expectedFinishAt: new Date(finishAt).toISOString(),
  });
  newHabitName.value = "";
  finishTimeError.value = "";
  refreshFinishBounds();
  newHabitDeadline.value = toDateTimeLocal(new Date(Date.now() + 24 * 60 * 60 * 1000));
}

function startEditing(habit) {
  if (!canUseTracker.value || isExpired(habit)) return;
  editingHabitId.value = habit.id;
  editingHabitName.value = habit.name;
}

function cancelEditing() {
  editingHabitId.value = null;
  editingHabitName.value = "";
}

function saveHabitEdit(habit) {
  if (!canUseTracker.value || isExpired(habit)) return;
  const name = editingHabitName.value.trim();
  if (!name) return;

  habit.name = name;
  cancelEditing();
}

function startExtending(habit) {
  if (!canUseTracker.value || !isExpired(habit)) return;
  refreshFinishBounds();
  extendingHabitId.value = habit.id;
  extendedDeadline.value = minFinishAt.value;
  extendTimeError.value = "";
}

function cancelExtending() {
  extendingHabitId.value = null;
  extendedDeadline.value = "";
  extendTimeError.value = "";
}

function saveExtension(habit) {
  if (!canUseTracker.value || !isExpired(habit)) return;

  const finishAt = new Date(extendedDeadline.value).getTime();
  const now = Date.now();
  if (
    !Number.isFinite(finishAt) ||
    finishAt < now + MIN_FINISH_MINUTES * 60_000 ||
    finishAt > now + MAX_FINISH_DAYS * 24 * 60 * 60_000
  ) {
    extendTimeError.value = "Choose a finish time between 1 minute and 30 days from now.";
    refreshFinishBounds();
    return;
  }

  habit.expectedFinishAt = new Date(finishAt).toISOString();
  cancelExtending();
}

async function deleteHabit(id) {
  const habit = habits.value.find((item) => item.id === id);
  if (!canUseTracker.value || (habit && isExpired(habit))) return;

  const userId = activeUserId.value;
  if (userId && supabase) {
    await saveQueue;
    if (activeUserId.value !== userId) return;
    syncing.value = true;
    try {
      const { error } = await supabase
        .from("habits")
        .delete()
        .eq("user_id", userId)
        .eq("id", String(id));
      if (error) {
        syncError.value = `Could not delete habit: ${error.message}`;
        return;
      }
    } catch (error) {
      syncError.value = `Could not delete habit: ${error.message}`;
      return;
    } finally {
      syncing.value = false;
    }
  }

  habits.value = habits.value.filter((habit) => habit.id !== id);
  if (editingHabitId.value === id) cancelEditing();
}

function clearFinishTimeError() {
  finishTimeError.value = "";
}

function clearExtendTimeError() {
  extendTimeError.value = "";
}
</script>

<template>
  <div v-if="authLoading && !authUser" class="auth-loading" role="status">
    <span class="auth-loading-mark" aria-hidden="true">l.</span>
    <span>Preparing your habit space...</span>
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
    :habits="habits"
    :completed-count="completedCount"
    :remaining-count="remainingCount"
    :progress="progress"
    :streak="streak"
    :week-progress="weekProgress"
    :today-key="todayKey"
    :can-use-tracker="canUseTracker"
    :is-expired="isExpired"
    :format-expected-finish="formatExpectedFinish"
    :editing-habit-id="editingHabitId"
    :editing-habit-name="editingHabitName"
    :extending-habit-id="extendingHabitId"
    :extended-deadline="extendedDeadline"
    :extend-time-error="extendTimeError"
    :min-finish-at="minFinishAt"
    :max-finish-at="maxFinishAt"
    :new-habit-name="newHabitName"
    :new-habit-deadline="newHabitDeadline"
    :finish-time-error="finishTimeError"
    @logout="signOut"
    @retry="retryProfileLoad"
    @toggle-habit="toggleHabit"
    @add-habit="addHabit"
    @start-editing="startEditing"
    @cancel-editing="cancelEditing"
    @save-habit-edit="saveHabitEdit"
    @delete-habit="deleteHabit"
    @start-extending="startExtending"
    @cancel-extending="cancelExtending"
    @save-extension="saveExtension"
    @refresh-finish-bounds="refreshFinishBounds"
    @clear-finish-time-error="clearFinishTimeError"
    @clear-extend-time-error="clearExtendTimeError"
    @update-new-habit-name="newHabitName = $event"
    @update-new-habit-deadline="newHabitDeadline = $event"
    @update-editing-habit-name="editingHabitName = $event"
    @update-extended-deadline="extendedDeadline = $event"
  />
</template>
