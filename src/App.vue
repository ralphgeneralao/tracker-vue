<script setup>
import { computed, onMounted, ref, watch } from "vue";
import { starterHabits } from "./common/starterHabits.js";
import WelcomeRow from "./components/WelcomeRow.vue";

const STORAGE_KEY = "little-by-little-habits";
const today = new Date();
const todayKey = dateKey(today);
const habits = ref([]);
const newHabitName = ref("");
const editingHabitId = ref(null);
const editingHabitName = ref("");
const isReady = ref(false);

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
  try {
    const savedHabits = localStorage.getItem(STORAGE_KEY);
    habits.value = savedHabits ? JSON.parse(savedHabits) : starterHabits;
    if (!Array.isArray(habits.value)) habits.value = starterHabits;
  } catch {
    habits.value = starterHabits;
  }
  isReady.value = true;
});

watch(
  habits,
  (value) => {
    if (isReady.value) localStorage.setItem(STORAGE_KEY, JSON.stringify(value));
  },
  { deep: true }
);

function dateKey(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function toggleHabit(habit) {
  const index = habit.completions.indexOf(todayKey);
  if (index === -1) habit.completions.push(todayKey);
  else habit.completions.splice(index, 1);
}

function addHabit() {
  const name = newHabitName.value.trim();
  if (!name) return;

  const colors = ["blue", "orange", "green", "pink"];
  const icons = ["✳", "◌", "⌁", "✦"];
  const nextIndex = habits.value.length;
  habits.value.push({
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    name,
    icon: icons[nextIndex % icons.length],
    color: colors[nextIndex % colors.length],
    completions: [],
  });
  newHabitName.value = "";
}

function startEditing(habit) {
  editingHabitId.value = habit.id;
  editingHabitName.value = habit.name;
}

function cancelEditing() {
  editingHabitId.value = null;
  editingHabitName.value = "";
}

function saveHabitEdit(habit) {
  const name = editingHabitName.value.trim();
  if (!name) return;

  habit.name = name;
  cancelEditing();
}

function deleteHabit(id) {
  habits.value = habits.value.filter((habit) => habit.id !== id);
  if (editingHabitId.value === id) cancelEditing();
}
</script>

<template>
  <div class="app-shell">
    <header class="topbar">
      <!-- <a class="brand" href="#top" aria-label="Little by Little home">
        <span class="brand-mark" aria-hidden="true">l.</span>
        <span>little by little</span>
      </a> -->
      <div class="topbar-date"><span class="date-dot"></span>{{ dateLabel }}</div>
      <!-- <div class="avatar" aria-label="Your habit space">Y</div> -->
    </header>

    <main id="top" class="dashboard">
      <WelcomeRow
        :habits="habits"
        :completed-count="completedCount"
        :remaining-count="remainingCount"
        :progress="progress"
      />

      <section class="stats-row" aria-label="Your habit summary">
        <div class="stat-item">
          <span class="stat-icon streak-icon" aria-hidden="true">✳</span>
          <span class="stat-copy"
            ><strong>{{ streak }} days</strong><small>current streak</small></span
          >
        </div>
        <span class="stat-divider" aria-hidden="true"></span>
        <div class="stat-item">
          <span class="stat-icon week-icon" aria-hidden="true">↗</span>
          <span class="stat-copy"
            ><strong>{{ weekProgress }}%</strong><small>this week</small></span
          >
        </div>
        <span class="stats-message">Consistency over intensity</span>
      </section>

      <div class="content-grid">
        <section class="habits-section" aria-labelledby="habits-heading">
          <div class="section-heading">
            <div>
              <p class="eyebrow">SHOW UP FOR YOURSELF</p>
              <h2 id="habits-heading">
                Today's habits <span>{{ habits.length }}</span>
              </h2>
            </div>
            <!-- <span class="section-date">{{ dateLabel }}</span> -->
          </div>

          <div v-if="habits.length" class="habit-list">
            <article
              v-for="(habit, index) in habits"
              :key="habit.id"
              class="habit-row"
              :class="{ 'is-complete': habit.completions.includes(todayKey) }"
              :style="{ '--row-index': index }"
            >
              <span
                class="habit-icon"
                :class="`tone-${habit.color}`"
                aria-hidden="true"
                >{{ habit.icon }}</span
              >
              <div class="habit-info">
                <form
                  v-if="editingHabitId === habit.id"
                  class="edit-form"
                  @submit.prevent="saveHabitEdit(habit)"
                >
                  <label class="visually-hidden" :for="`edit-habit-${habit.id}`">
                    Edit {{ habit.name }}
                  </label>
                  <input
                    :id="`edit-habit-${habit.id}`"
                    v-model="editingHabitName"
                    class="edit-input"
                    maxlength="60"
                    required
                    autocomplete="off"
                    @keydown.esc.prevent="cancelEditing"
                  />
                  <button class="edit-action save-edit" type="submit">Save</button>
                  <button
                    class="edit-action cancel-edit"
                    type="button"
                    @click="cancelEditing"
                  >
                    Cancel
                  </button>
                </form>
                <template v-else>
                  <span class="habit-name">{{ habit.name }}</span>
                  <span class="habit-meta"
                    >{{ habit.completions.length }}
                    {{ habit.completions.length === 1 ? "day" : "days" }} practiced</span
                  >
                </template>
              </div>
              <button
                v-if="editingHabitId !== habit.id"
                class="edit-button"
                type="button"
                :aria-label="`Edit ${habit.name}`"
                @click="startEditing(habit)"
              >
                <svg viewBox="0 0 20 20" aria-hidden="true">
                  <path
                    d="m12.8 4.2 3 3M4 16l3.5-.8 8.8-8.8a1.4 1.4 0 0 0-2-2l-8.8 8.8L4 16Z"
                  />
                </svg>
              </button>
              <button
                class="check-button"
                :class="{ checked: habit.completions.includes(todayKey) }"
                type="button"
                :aria-label="`${
                  habit.completions.includes(todayKey) ? 'Mark' : 'Complete'
                } ${habit.name} ${
                  habit.completions.includes(todayKey) ? 'incomplete' : 'complete'
                }`"
                :aria-pressed="habit.completions.includes(todayKey)"
                :disabled="editingHabitId === habit.id"
                @click="toggleHabit(habit)"
              >
                <svg
                  v-if="habit.completions.includes(todayKey)"
                  viewBox="0 0 20 20"
                  aria-hidden="true"
                >
                  <path d="m5 10 3.2 3.2L15.5 6" />
                </svg>
                <span v-else class="check-label">Done</span>
              </button>
              <button
                class="delete-button"
                type="button"
                :aria-label="`Delete ${habit.name}`"
                @click="deleteHabit(habit.id)"
              >
                <svg viewBox="0 0 20 20" aria-hidden="true">
                  <path d="M4.5 6h11M8 6V4.5h4V6m2.5 0-.6 9.5H6.1L5.5 6m3 2.5v4m3-4v4" />
                </svg>
              </button>
            </article>
          </div>

          <div v-else class="empty-state">
            <span class="empty-spark" aria-hidden="true">✳</span>
            <h3>A fresh page.</h3>
            <p>Add one small thing you want to make part of your day.</p>
          </div>

          <p class="list-footnote">
            <span class="footnote-spark" aria-hidden="true">✳</span> Every check-in
            counts. Keep your promises small and kind.
          </p>
        </section>

        <aside class="side-column">
          <section class="add-card" aria-labelledby="add-heading">
            <div class="add-heading-row">
              <!-- <span class="add-mark" aria-hidden="true">+</span> -->
              <div>
                <p class="eyebrow">MAKE IT A RITUAL</p>
                <h2 id="add-heading">Add a habit</h2>
              </div>
            </div>
            <form class="add-form" @submit.prevent="addHabit">
              <label class="visually-hidden" for="habit-name">Habit name</label>
              <input
                id="habit-name"
                v-model="newHabitName"
                maxlength="60"
                placeholder="e.g. Stretch for 5 minutes"
                autocomplete="off"
              />
              <button
                type="submit"
                :disabled="!newHabitName.trim()"
                aria-label="Add habit"
              >
                <span>+</span>
              </button>
            </form>
            <p class="form-hint">Start small. You can always grow from here.</p>
          </section>

          <section class="note-card" aria-label="A gentle reminder">
            <span class="note-quote" aria-hidden="true">“</span>
            <p>Sic parvis magna</p>
            <span class="note-attribution">Sir Francis Drake</span>
          </section>
        </aside>
      </div>

      <footer class="page-footer">
        <span>GENWEB SOLUTIONS</span>
      </footer>
    </main>
  </div>
</template>
