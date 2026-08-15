<script setup lang="ts">
import { computed } from 'vue';
import { buildUptimeSegments } from '../lib/uptimeSegments';
import { loginUptimeColors } from '../lib/uptimeColors';
import type { HistoryPayload } from '../types';

const props = withDefaults(
  defineProps<{
    history: HistoryPayload;
    segments: number;
    upColor?: string;
    downColor?: string;
    noDataColor?: string;
    testId?: string;
  }>(),
  {
    upColor: loginUptimeColors.up,
    downColor: loginUptimeColors.down,
    noDataColor: loginUptimeColors.noData,
    testId: 'uptime-bar',
  },
);

const cells = computed(() =>
  buildUptimeSegments(
    props.history.points,
    props.segments,
    props.upColor,
    props.downColor,
    props.noDataColor,
  ),
);
</script>

<template>
  <div class="flex h-8 w-full gap-px" :data-testid="testId">
    <div
      v-for="(cell, i) in cells"
      :key="i"
      class="min-w-0 flex-1"
      :style="{ background: cell.background }"
      :title="cell.title"
    ></div>
  </div>
</template>
