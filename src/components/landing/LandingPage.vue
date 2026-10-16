<script setup>
defineProps({
  configured: { type: Boolean, required: true },
  configError: { type: String, default: "" },
  authError: { type: String, default: "" },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(["login", "retry"]);
</script>

<template>
  <div class="landing-shell">
    <header class="landing-header">
      <a class="landing-brand" href="#home" aria-label="Debt Tracker home">
        <span class="landing-brand-mark" aria-hidden="true">DT</span>
        <span>debt tracker</span>
      </a>
      <button class="google-button landing-header-login" type="button" :disabled="!configured || loading"
        @click="emit('login')">
        {{ loading ? "Please wait..." : "Log in" }}
      </button>
    </header>

    <main id="home" class="landing-main">
      <section class="landing-hero" aria-labelledby="landing-title">
        <div class="landing-copy">
          <p class="eyebrow">SMALL DEBTS, REAL MONEY</p>
          <h1 id="landing-title">A simple debt tracking solution, <em>big or small.</em></h1>
          <p class="landing-intro">
            Keep a clear, private record of who owes you, how much they owe, and
            when they expect to pay.
          </p>
          <button class="google-button landing-cta" type="button" :disabled="!configured || loading"
            @click="emit('login')">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path fill="#4285f4"
                d="M21.6 12.2c0-.7-.1-1.4-.2-2H12v3.8h5.4a4.6 4.6 0 0 1-2 3v2.5h3.2c1.9-1.8 3-4.3 3-7.3Z" />
              <path fill="#34a853"
                d="M12 22c2.7 0 5-.9 6.7-2.5l-3.2-2.5c-.9.6-2 1-3.5 1-2.7 0-5-1.8-5.8-4.3H3v2.6A10 10 0 0 0 12 22Z" />
              <path fill="#fbbc05" d="M6.2 13.7a6 6 0 0 1 0-3.4V7.7H3a10 10 0 0 0 0 8.6l3.2-2.6Z" />
              <path fill="#ea4335"
                d="M12 6c1.5 0 2.8.5 3.8 1.5l2.9-2.9A9.7 9.7 0 0 0 12 2a10 10 0 0 0-9 5.7l3.2 2.6C7 7.8 9.3 6 12 6Z" />
            </svg>
            {{ loading ? "Connecting..." : "Continue with Google" }}
          </button>
          <p class="landing-signin-note">Your tracker is private to your account.</p>
          <div v-if="configError || authError" class="landing-error" role="alert">
            <p>{{ configError || authError }}</p>
            <button v-if="authError && configured" class="profile-action" type="button" :disabled="loading"
              @click="emit('retry')">
              Try again
            </button>
          </div>
          <p v-else-if="!configured" class="landing-setup-note">
            Add your Supabase project URL and public key to enable sign-in.
          </p>
        </div>
        <div class="landing-art" aria-hidden="true">
          <div class="landing-sun"></div>
          <div class="landing-orbit landing-orbit-one"></div>
          <div class="landing-orbit landing-orbit-two"></div>
          <div class="landing-art-card">
            <span class="landing-art-kicker">YOUR DEBT OVERVIEW</span>
            <span class="landing-art-title">Every detail, in view.</span>
            <span class="landing-art-progress"><span></span></span>
            <span class="landing-art-caption">Names, amounts, expected dates</span>
            <span class="landing-art-spark">✳</span>
          </div>
          <span class="landing-floating-note">your records, kept private</span>
        </div>
      </section>

      <section class="landing-features" aria-label="About the debt tracker">
        <article class="landing-feature">
          <span class="landing-feature-number">01</span>
          <h2>Keep it simple</h2>
          <p>Record who owes you and how much is owed.</p>
        </article>
        <article class="landing-feature">
          <span class="landing-feature-number">02</span>
          <h2>Know what is due</h2>
          <p>Keep expected payment dates visible and spot overdue records.</p>
        </article>
        <article class="landing-feature">
          <span class="landing-feature-number">03</span>
          <h2>Own your progress</h2>
          <p>Your personal debt records are saved securely to your account.</p>
        </article>
      </section>

      <footer class="landing-footer">
        <span>GENWEB SOLUTIONS</span>
        <span>Clear records. Less guesswork.</span>
      </footer>
    </main>
  </div>
</template>
