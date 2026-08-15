<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { api } from './api';
import { applyDownDemo, isDownDemo } from './lib/demoDown';
import { windowLabels, windows } from './lib/windows';
import StatusPage from './StatusPage.vue';
import type {
  HistoryPayload,
  HistoryWindow,
  HolidayPeriod,
  HolidaysPayload,
  SummaryPayload,
} from './types';

const summary = ref<SummaryPayload | null>(null);
const history = ref<HistoryPayload | null>(null);
const history24h = ref<HistoryPayload | null>(null);
const history30d = ref<HistoryPayload | null>(null);
const holidays = ref<HolidaysPayload | null>(null);
const range = ref<HistoryWindow>('24h');
const error = ref<string | null>(null);
const loading = ref(true);

const visibleHolidays = computed<HolidayPeriod[]>(() => {
  if (!history.value || !holidays.value) return [];
  const from = history.value.from;
  const to = history.value.to;
  return holidays.value.periods.filter((p) => p.end >= from && p.start <= to);
});

async function load(next: HistoryWindow = range.value) {
  error.value = null;
  const [summaryData, historyData, holidayData, dayHistory, monthHistory] =
    await Promise.all([
      api.summary(),
      api.history(next),
      api.holidays(),
      next === '24h' ? Promise.resolve(null) : api.history('24h'),
      next === '30d' ? Promise.resolve(null) : api.history('30d'),
    ]);
  let nextSummary = summaryData;
  let nextHistory = historyData;
  let next24h = next === '24h' ? historyData : dayHistory;
  let next30d = next === '30d' ? historyData : monthHistory;
  if (isDownDemo() && next24h && next30d) {
    const demo = applyDownDemo(nextSummary, [nextHistory, next24h, next30d]);
    nextSummary = demo.summary;
    [nextHistory, next24h, next30d] = demo.histories;
  }
  summary.value = nextSummary;
  history.value = nextHistory;
  history24h.value = next24h;
  history30d.value = next30d;
  holidays.value = holidayData;
  range.value = next;
}

onMounted(async () => {
  try {
    await load('24h');
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Laden fehlgeschlagen';
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <p v-if="loading" class="p-6 text-sm text-neutral-500">Lade Status…</p>
  <p v-else-if="error" class="p-6 text-sm text-red-600">{{ error }}</p>
  <StatusPage
    v-else-if="summary && history && history24h && history30d"
    :summary="summary"
    :history="history"
    :history24h="history24h"
    :history30d="history30d"
    :holidays="visibleHolidays"
    :range="range"
    :windows="windows"
    :labels="windowLabels"
    :load="load"
  />
</template>
