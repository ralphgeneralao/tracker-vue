<script setup>
const { habits, completedCount, remainingCount, progress } = defineProps({
  habits: {
    type: Array,
    required: true,
  },
  completedCount: {
    type: Number,
    required: true,
  },
  remainingCount: {
    type: Number,
    required: true,
  },
  progress: {
    type: Number,
    required: true,
  },
});
</script>

<template>
  <section class="welcome-row" aria-labelledby="page-title">
    <div class="welcome-copy">
      <p class="eyebrow">YOUR DAILY PRACTICE <span>·</span></p>
      <h1 id="page-title">Personal Habit<br /><em>Tracker</em></h1>
      <!-- <p class="welcome-note">Small things, done often, make a life.</p> -->
    </div>

    <div class="progress-card" aria-label="Today's progress">
      <div class="progress-copy">
        <span class="card-kicker">TODAY'S PROGRESS</span>
        <strong>{{ completedCount }} <span>of</span> {{ habits.length }}</strong>
        <span class="progress-caption">
          {{
            remainingCount === 0 && habits.length
              ? "You showed up for yourself."
              : `${remainingCount} ${
                  remainingCount === 1 ? "habit" : "habits"
                } left today`
          }}
        </span>
      </div>
      <div
        class="progress-ring"
        :style="{ '--progress': `${progress * 3.6}deg` }"
        role="img"
        :aria-label="`${progress}% complete`"
      >
        <div class="progress-ring-inner">
          <span>{{ progress }}<small>%</small></span>
        </div>
      </div>
    </div>
  </section>
</template>
