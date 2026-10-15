<script setup>
import { computed } from "vue";

const props = defineProps({
  user: { type: Object, default: null },
  configured: { type: Boolean, required: true },
  configError: { type: String, default: "" },
  loading: { type: Boolean, default: false },
  syncing: { type: Boolean, default: false },
  authError: { type: String, default: "" },
  syncError: { type: String, default: "" },
});

const emit = defineEmits(["login", "logout", "retry"]);

const displayName = computed(
  () =>
    props.user?.user_metadata?.full_name ||
    props.user?.user_metadata?.name ||
    props.user?.email ||
    "Your profile"
);
const avatarUrl = computed(
  () => props.user?.user_metadata?.avatar_url || props.user?.user_metadata?.picture || ""
);
</script>

<template>
  <section class="profile-panel" aria-label="Account">
    <template v-if="user">
      <img
        v-if="avatarUrl"
        class="profile-avatar"
        :src="avatarUrl"
        alt=""
        referrerpolicy="no-referrer"
      />
      <span v-else class="profile-avatar profile-avatar-fallback" aria-hidden="true">
        {{ displayName.charAt(0).toUpperCase() }}
      </span>
      <div class="profile-details">
        <strong class="profile-name">{{ displayName }}</strong>
        <small v-if="syncError" class="profile-status profile-error" role="status">
          {{ syncError }}
        </small>
        <small v-else-if="authError" class="profile-status profile-error" role="status">
          {{ authError }}
        </small>
        <small v-else class="profile-status" role="status">
          {{ syncing ? "Syncing tracker..." : "Tracker synced" }}
        </small>
      </div>
      <button
        v-if="authError || syncError"
        class="profile-action"
        type="button"
        :disabled="loading"
        @click="emit('retry')"
      >
        Retry
      </button>
      <button
        class="profile-action"
        type="button"
        :disabled="loading"
        @click="emit('logout')"
      >
        {{ loading ? "Please wait..." : "Log out" }}
      </button>
    </template>
    <template v-else>
      <div class="profile-details">
        <strong class="profile-name">Keep your tracker</strong>
        <small v-if="configError" class="profile-status profile-error" role="status">
          {{ configError }}
        </small>
        <small v-else-if="!configured" class="profile-status">
          Supabase settings are needed to enable Google sign-in.
        </small>
        <small v-else-if="authError" class="profile-status profile-error" role="status">
          {{ authError }}
        </small>
        <small v-else class="profile-status">Sign in to sync across devices.</small>
      </div>
      <button
        class="google-button"
        type="button"
        :disabled="!configured || loading"
        @click="emit('login')"
      >
        {{ loading ? "Please wait..." : "Continue with Google" }}
      </button>
      <button
        v-if="authError && configured"
        class="profile-action"
        type="button"
        :disabled="loading"
        @click="emit('retry')"
      >
        Retry
      </button>
    </template>
  </section>
</template>
