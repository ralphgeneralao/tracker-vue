<script setup>
import ProfilePanel from "../ProfilePanel.vue";
import WelcomeRow from "../WelcomeRow.vue";

defineProps({
  user: { type: Object, required: true },
  syncing: { type: Boolean, default: false },
  authError: { type: String, default: "" },
  syncError: { type: String, default: "" },
  dateLabel: { type: String, required: true },
  habits: { type: Array, required: true },
  completedCount: { type: Number, required: true },
  remainingCount: { type: Number, required: true },
  progress: { type: Number, required: true },
  streak: { type: Number, required: true },
  weekProgress: { type: Number, required: true },
  todayKey: { type: String, required: true },
  canUseTracker: { type: Boolean, required: true },
  isExpired: { type: Function, required: true },
  formatExpectedFinish: { type: Function, required: true },
  editingHabitId: { type: [String, Number], default: null },
  editingHabitName: { type: String, default: "" },
  extendingHabitId: { type: [String, Number], default: null },
  extendedDeadline: { type: String, default: "" },
  extendTimeError: { type: String, default: "" },
  minFinishAt: { type: String, required: true },
  maxFinishAt: { type: String, required: true },
  newHabitName: { type: String, default: "" },
  newHabitDeadline: { type: String, required: true },
  finishTimeError: { type: String, default: "" },
});

const emit = defineEmits([
  "logout",
  "retry",
  "toggle-habit",
  "add-habit",
  "start-editing",
  "cancel-editing",
  "save-habit-edit",
  "delete-habit",
  "start-extending",
  "cancel-extending",
  "save-extension",
  "refresh-finish-bounds",
  "clear-finish-time-error",
  "clear-extend-time-error",
  "update-new-habit-name",
  "update-new-habit-deadline",
  "update-editing-habit-name",
  "update-extended-deadline",
]);
</script>

<template>
  <div class="app-shell">
    <header class="topbar">
      <div class="topbar-date"><span class="date-dot"></span>{{ dateLabel }}</div>
      <ProfilePanel
        :user="user"
        :configured="true"
        :loading="!canUseTracker"
        :syncing="syncing"
        :auth-error="authError"
        :sync-error="syncError"
        @logout="emit('logout')"
        @retry="emit('retry')"
      />
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
          <span class="stat-copy">
            <strong>{{ streak }} days</strong><small>current streak</small>
          </span>
        </div>
        <span class="stat-divider" aria-hidden="true"></span>
        <div class="stat-item">
          <span class="stat-icon week-icon" aria-hidden="true">↗</span>
          <span class="stat-copy">
            <strong>{{ weekProgress }}%</strong><small>this week</small>
          </span>
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
          </div>

          <div v-if="habits.length" class="habit-list">
            <article
              v-for="(habit, index) in habits"
              :key="habit.id"
              class="habit-row"
              :class="{
                'is-complete': habit.completions.includes(todayKey),
                'is-expired': isExpired(habit),
              }"
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
                  v-if="editingHabitId === habit.id && !isExpired(habit)"
                  class="edit-form"
                  @submit.prevent="emit('save-habit-edit', habit)"
                >
                  <label class="visually-hidden" :for="`edit-habit-${habit.id}`">
                    Edit {{ habit.name }}
                  </label>
                  <input
                    :id="`edit-habit-${habit.id}`"
                    :value="editingHabitName"
                    class="edit-input"
                    maxlength="60"
                    required
                    autocomplete="off"
                    :disabled="!canUseTracker"
                    @input="emit('update-editing-habit-name', $event.target.value)"
                    @keydown.esc.prevent="emit('cancel-editing')"
                  />
                  <button class="edit-action save-edit" type="submit" :disabled="!canUseTracker">
                    Save
                  </button>
                  <button
                    class="edit-action cancel-edit"
                    type="button"
                    :disabled="!canUseTracker"
                    @click="emit('cancel-editing')"
                  >
                    Cancel
                  </button>
                </form>
                <template v-else>
                  <span class="habit-name">{{ habit.name }}</span>
                  <span class="habit-meta">
                    {{ habit.completions.length }}
                    {{ habit.completions.length === 1 ? "day" : "days" }} practiced
                  </span>
                  <span v-if="habit.expectedFinishAt" class="habit-deadline">
                    <template v-if="isExpired(habit)">Deadline passed</template>
                    <template v-else>
                      Expected by {{ formatExpectedFinish(habit.expectedFinishAt) }}
                    </template>
                  </span>
                  <form
                    v-if="extendingHabitId === habit.id"
                    class="extend-form"
                    @submit.prevent="emit('save-extension', habit)"
                  >
                    <label class="visually-hidden" :for="`extend-deadline-${habit.id}`">
                      New expected finish time for {{ habit.name }}
                    </label>
                    <input
                      :id="`extend-deadline-${habit.id}`"
                      :value="extendedDeadline"
                      type="datetime-local"
                      :min="minFinishAt"
                      :max="maxFinishAt"
                      required
                      :disabled="!canUseTracker"
                      :aria-describedby="
                        extendTimeError ? `extend-error-${habit.id}` : undefined
                      "
                      @focus="emit('refresh-finish-bounds')"
                      @input="
                        emit('update-extended-deadline', $event.target.value);
                        emit('clear-extend-time-error')
                      "
                    />
                    <button class="edit-action save-edit" type="submit" :disabled="!canUseTracker">
                      Save extension
                    </button>
                    <button
                      class="edit-action cancel-edit"
                      type="button"
                      :disabled="!canUseTracker"
                      @click="emit('cancel-extending')"
                    >
                      Cancel
                    </button>
                    <span
                      v-if="extendTimeError"
                      :id="`extend-error-${habit.id}`"
                      class="form-hint form-error"
                      role="alert"
                    >
                      {{ extendTimeError }}
                    </span>
                  </form>
                </template>
              </div>
              <button
                v-if="isExpired(habit) && extendingHabitId !== habit.id"
                class="extend-button"
                type="button"
                :aria-label="`Extend time for ${habit.name}`"
                :disabled="!canUseTracker"
                @click="emit('start-extending', habit)"
              >
                Extend time
              </button>
              <button
                v-if="editingHabitId !== habit.id && !isExpired(habit)"
                class="edit-button"
                type="button"
                :aria-label="`Edit ${habit.name}`"
                :disabled="!canUseTracker || isExpired(habit)"
                @click="emit('start-editing', habit)"
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
                :disabled="
                  !canUseTracker || isExpired(habit) || editingHabitId === habit.id
                "
                @click="emit('toggle-habit', habit)"
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
                :disabled="!canUseTracker || isExpired(habit)"
                @click="emit('delete-habit', habit.id)"
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
            <span class="footnote-spark" aria-hidden="true">✳</span>
            Every check-in counts. Keep your promises small and kind.
          </p>
        </section>

        <aside class="side-column">
          <section class="add-card" aria-labelledby="add-heading">
            <div class="add-heading-row">
              <div>
                <p class="eyebrow">MAKE IT A RITUAL</p>
                <h2 id="add-heading">Add a habit</h2>
              </div>
            </div>
            <form class="add-form" @submit.prevent="emit('add-habit')">
              <div class="add-fields">
                <label class="add-label" for="habit-name">Habit name</label>
                <input
                  id="habit-name"
                  :value="newHabitName"
                  maxlength="60"
                  placeholder="e.g. Stretch for 5 minutes"
                  autocomplete="off"
                  :disabled="!canUseTracker"
                  @input="emit('update-new-habit-name', $event.target.value)"
                />
                <label class="add-label" for="habit-deadline">Expected to finish by</label>
                <input
                  id="habit-deadline"
                  :value="newHabitDeadline"
                  type="datetime-local"
                  :min="minFinishAt"
                  :max="maxFinishAt"
                  required
                  :disabled="!canUseTracker"
                  :aria-describedby="finishTimeError ? 'finish-time-error' : undefined"
                  @focus="emit('refresh-finish-bounds')"
                  @input="
                    emit('update-new-habit-deadline', $event.target.value);
                    emit('clear-finish-time-error')
                  "
                />
              </div>
              <button
                type="submit"
                :disabled="!canUseTracker || !newHabitName.trim()"
                aria-label="Add habit"
              >
                <span>+</span>
              </button>
            </form>
            <p
              v-if="finishTimeError"
              id="finish-time-error"
              class="form-hint form-error"
              role="alert"
            >
              {{ finishTimeError }}
            </p>
            <p v-else class="form-hint">
              Choose a finish time between 1 minute and 30 days from now.
            </p>
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
