<script setup>
import ProfilePanel from "../ProfilePanel.vue";
import WelcomeRow from "../WelcomeRow.vue";

defineProps({
  user: { type: Object, required: true },
  syncing: { type: Boolean, default: false },
  authError: { type: String, default: "" },
  syncError: { type: String, default: "" },
  dateLabel: { type: String, required: true },
  debts: { type: Array, required: true },
  totalOwed: { type: Number, required: true },
  formatAmount: { type: Function, required: true },
  formatPaymentDate: { type: Function, required: true },
  isOverdue: { type: Function, required: true },
  canUseTracker: { type: Boolean, required: true },
  editingDebtId: { type: String, default: null },
  editingDebtorName: { type: String, default: "" },
  editingDebtAmount: { type: String, default: "" },
  editingPaymentDate: { type: String, default: "" },
  newDebtorName: { type: String, default: "" },
  newDebtAmount: { type: String, default: "" },
  newExpectedPaymentDate: { type: String, required: true },
});

const emit = defineEmits([
  "logout",
  "retry",
  "add-debt",
  "start-editing",
  "cancel-editing",
  "save-debt-edit",
  "delete-debt",
  "update-new-debtor-name",
  "update-new-debt-amount",
  "update-new-payment-date",
  "update-editing-debtor-name",
  "update-editing-debt-amount",
  "update-editing-payment-date",
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
      <WelcomeRow :debtor-count="debts.length" :total-owed="totalOwed" :format-amount="formatAmount" />

      <section class="stats-row debt-stats" aria-label="Debt summary">
        <div class="stat-item">
          <span class="stat-icon debt-count-icon" aria-hidden="true">$</span>
          <span class="stat-copy">
            <strong>{{ debts.length }}</strong>
            <small>{{ debts.length === 1 ? "person owing" : "people owing" }}</small>
          </span>
        </div>
        <span class="stat-divider" aria-hidden="true"></span>
        <div class="stat-item">
          <span class="stat-icon week-icon" aria-hidden="true">↗</span>
          <span class="stat-copy">
            <strong>{{ debts.filter((debt) => isOverdue(debt)).length }}</strong>
            <small>past expected date</small>
          </span>
        </div>
        <span class="stats-message">Keep every payment in view</span>
      </section>

      <div class="content-grid">
        <section class="debts-section" aria-labelledby="debts-heading">
          <div class="section-heading">
            <div>
              <p class="eyebrow">YOUR PERSONAL RECORD</p>
              <h2 id="debts-heading">Debts owed to you <span>{{ debts.length }}</span></h2>
            </div>
          </div>

          <div v-if="debts.length" class="debt-list">
            <article
              v-for="(debt, index) in debts"
              :key="debt.id"
              class="debt-row"
              :class="{ 'is-overdue': isOverdue(debt) }"
              :style="{ '--row-index': index }"
            >
              <span class="debt-icon" aria-hidden="true">$</span>
              <div class="debt-info">
                <form
                  v-if="editingDebtId === debt.id"
                  class="debt-edit-form"
                  @submit.prevent="emit('save-debt-edit', debt)"
                >
                  <label class="visually-hidden" :for="`edit-debtor-${debt.id}`">
                    Debtor name
                  </label>
                  <input
                    :id="`edit-debtor-${debt.id}`"
                    :value="editingDebtorName"
                    maxlength="100"
                    required
                    autocomplete="off"
                    :disabled="!canUseTracker || syncing"
                    @input="emit('update-editing-debtor-name', $event.target.value)"
                  />
                  <label class="visually-hidden" :for="`edit-amount-${debt.id}`">
                    Amount owed
                  </label>
                  <input
                    :id="`edit-amount-${debt.id}`"
                    :value="editingDebtAmount"
                    type="number"
                    min="0.01"
                    step="0.01"
                    required
                    :disabled="!canUseTracker || syncing"
                    @input="emit('update-editing-debt-amount', $event.target.value)"
                  />
                  <label class="visually-hidden" :for="`edit-date-${debt.id}`">
                    Expected payment date
                  </label>
                  <input
                    :id="`edit-date-${debt.id}`"
                    :value="editingPaymentDate"
                    type="date"
                    required
                    :disabled="!canUseTracker || syncing"
                    @input="emit('update-editing-payment-date', $event.target.value)"
                  />
                  <button class="edit-action save-edit" type="submit" :disabled="!canUseTracker || syncing">
                    Save
                  </button>
                  <button
                    class="edit-action cancel-edit"
                    type="button"
                    :disabled="syncing"
                    @click="emit('cancel-editing')"
                  >
                    Cancel
                  </button>
                </form>
                <template v-else>
                  <strong class="debt-name">{{ debt.debtorName }}</strong>
                  <span class="debt-meta">
                    Expected to pay by {{ formatPaymentDate(debt.expectedPaymentDate) }}
                    <span v-if="isOverdue(debt)" class="overdue-label">Overdue</span>
                  </span>
                </template>
              </div>
              <strong v-if="editingDebtId !== debt.id" class="debt-amount">
                {{ formatAmount(debt.amount) }}
              </strong>
              <template v-if="editingDebtId !== debt.id">
                <button
                  class="edit-button"
                  type="button"
                  :aria-label="`Edit debt from ${debt.debtorName}`"
                  :disabled="!canUseTracker || syncing"
                  @click="emit('start-editing', debt)"
                >
                  Edit
                </button>
                <button
                  class="delete-button"
                  type="button"
                  :aria-label="`Delete debt from ${debt.debtorName}`"
                  :disabled="!canUseTracker || syncing"
                  @click="emit('delete-debt', debt.id)"
                >
                  <svg viewBox="0 0 20 20" aria-hidden="true">
                    <path d="M4.5 6h11M8 6V4.5h4V6m2.5 0-.6 9.5H6.1L5.5 6m3 2.5v4m3-4v4" />
                  </svg>
                </button>
              </template>
            </article>
          </div>

          <div v-else class="empty-state">
            <span class="empty-spark" aria-hidden="true">$</span>
            <h3>No debts recorded yet.</h3>
            <p>Add a debtor to keep the amount and expected payment date handy.</p>
          </div>
          <p class="list-footnote">
            Amounts are shown without a currency symbol. Use the same currency for every record.
          </p>
        </section>

        <aside class="side-column">
          <section class="add-card" aria-labelledby="add-heading">
            <div class="add-heading-row">
              <div>
                <p class="eyebrow">RECORD A DEBT</p>
                <h2 id="add-heading">Add a debtor</h2>
              </div>
            </div>
            <form class="add-form debt-add-form" @submit.prevent="emit('add-debt')">
              <div class="add-fields">
                <label class="add-label" for="debtor-name">Who owes you?</label>
                <input
                  id="debtor-name"
                  :value="newDebtorName"
                  maxlength="100"
                  placeholder="Debtor's name"
                  autocomplete="name"
                  required
                  :disabled="!canUseTracker || syncing"
                  @input="emit('update-new-debtor-name', $event.target.value)"
                />
                <label class="add-label" for="debt-amount">How much is owed?</label>
                <input
                  id="debt-amount"
                  :value="newDebtAmount"
                  type="number"
                  min="0.01"
                  step="0.01"
                  placeholder="0.00"
                  required
                  :disabled="!canUseTracker || syncing"
                  @input="emit('update-new-debt-amount', $event.target.value)"
                />
                <label class="add-label" for="payment-date">Expected to pay</label>
                <input
                  id="payment-date"
                  :value="newExpectedPaymentDate"
                  type="date"
                  required
                  :disabled="!canUseTracker || syncing"
                  @input="emit('update-new-payment-date', $event.target.value)"
                />
              </div>
              <button
                type="submit"
                :disabled="!canUseTracker || syncing || !newDebtorName.trim() || !newDebtAmount"
                aria-label="Add debtor"
              >
                <span>+</span>
              </button>
            </form>
            <p class="form-hint">Enter all amounts using the same currency.</p>
          </section>

          <section class="note-card debt-total-card" aria-label="Total amount owed">
            <span class="note-quote" aria-hidden="true">$</span>
            <p>Total owed</p>
            <strong>{{ formatAmount(totalOwed) }}</strong>
            <span class="note-attribution">ACROSS {{ debts.length }} RECORD{{ debts.length === 1 ? "" : "S" }}</span>
          </section>
        </aside>
      </div>

      <footer class="page-footer"><span>GENWEB SOLUTIONS</span></footer>
    </main>
  </div>
</template>
