<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { api } from '../api';
import OfficialServiceHeading from './OfficialServiceHeading.vue';
import OfficialNotice from './OfficialNotice.vue';
import { presentOfficialService } from '../lib/officialPresentation';
import type { OfficialPayload } from '../types';

const data = ref<OfficialPayload | null>(null);
const services = computed(() => {
  const priority = (service: OfficialPayload['services'][number]) =>
    service.status === 'restricted' ? 0 : service.maintenance ? 1 : service.status === 'unknown' ? 2 : 3;
  return [...(data.value?.services ?? [])].sort((a, b) => priority(a) - priority(b));
});
const notices = computed(() => services.value.map(presentOfficialService));
const failed = ref(false);
const loading = ref(true);
let timer: ReturnType<typeof setInterval> | undefined;
let pending = false;

async function refresh() {
  if (pending) return;
  pending = true;
  try {
    data.value = await api.official();
    failed.value = false;
  } catch {
    failed.value = true;
  } finally {
    loading.value = false;
    pending = false;
  }
}

function fetchedAt(timestamp: number) {
  return new Date(timestamp * 1000).toLocaleString('de-DE', { timeZone: 'Europe/Berlin' });
}

onMounted(() => {
  void refresh();
  timer = setInterval(() => void refresh(), 60_000);
});
onUnmounted(() => clearInterval(timer));
</script>

<template>
  <section class="p-4" aria-label="Offizielle Meldungen" data-testid="official-status">
    <p v-if="loading" class="text-sm" role="status">Lade offizielle Meldungen…</p>
    <div v-else-if="failed || !data?.services.length || data.stale" class="mb-4 border border-amber-400 bg-amber-50 p-3 text-sm" role="status">
      <p v-if="data?.services.length">Aktualisierung fehlgeschlagen. Letzter gespeicherter Stand.</p>
      <p v-else>Offizielle Meldungen sind derzeit nicht verfügbar.</p>
      <button class="mt-2 underline" type="button" @click="refresh">Erneut versuchen</button>
    </div>
    <ul v-if="notices.length" class="divide-y divide-[#d0d7de]">
      <li v-for="service in notices" :key="service.id" class="min-w-0 py-4 first:pt-0 last:pb-0" data-testid="official-service">
        <OfficialServiceHeading :service="service" />
        <OfficialNotice :service="service" />
      </li>
    </ul>
    <p class="mt-4 text-xs text-[#6b7280]">
      <a href="https://status.schulportal.hessen.de/" target="_blank" rel="noopener noreferrer" class="underline">Quelle</a>
      <span v-if="data?.fetchedAt"> · Stand: {{ fetchedAt(data.fetchedAt) }}</span>
    </p>
  </section>
</template>
