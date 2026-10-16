<script setup>
defineProps({
  debtorCount: { type: Number, required: true },
  totalOwed: { type: Number, required: true },
  formatAmount: { type: Function, required: true },
});
</script>

<template>
  <section class="welcome-row debt-welcome" aria-labelledby="page-title">
    <div class="welcome-copy">
      <p class="eyebrow">YOUR PRIVATE ACCOUNT OVERVIEW</p>
      <h1 id="page-title">Personal Debt<br /><em>Tracker</em></h1>
      <p class="welcome-note">Keep track of who owes you, how much, and when they expect to pay.</p>
    </div>

    <div class="progress-card debt-overview-card" aria-label="Outstanding debt overview">
      <div class="progress-copy">
        <span class="card-kicker">TOTAL OUTSTANDING</span>
        <strong>{{ formatAmount(totalOwed) }}</strong>
        <span class="progress-caption">
          {{ debtorCount }} {{ debtorCount === 1 ? "debt record" : "debt records" }}
        </span>
      </div>
      <div class="debt-overview-mark" aria-hidden="true">$</div>
    </div>
  </section>
</template>
