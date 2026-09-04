<script setup lang="ts">
import { computed, ref } from 'vue';
import { buildHourCells, buildUptimeSegments } from '../lib/uptimeSegments';
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
    perPoint?: boolean;
    rounded?: boolean;
  }>(),
  {
    upColor: loginUptimeColors.up,
    downColor: loginUptimeColors.down,
    noDataColor: loginUptimeColors.noData,
    testId: 'uptime-bar',
    perPoint: false,
    rounded: false,
  },
);

const hover = ref<number | null>(null);

const cells = computed(() =>
  props.perPoint
    ? buildHourCells(
        props.history.points,
        props.upColor,
        props.downColor,
        props.noDataColor,
        props.segments,
      )
    : buildUptimeSegments(
        props.history.points,
        props.segments,
        props.upColor,
        props.downColor,
        props.noDataColor,
      ),
);

const tooltip = computed(() => {
  if (hover.value == null) return null;
  const cell = cells.value[hover.value];
  if (!cell) return null;
  const n = cells.value.length;
  const pct = Math.min(92, Math.max(8, ((hover.value + 0.5) / n) * 100));
  return { lines: cell.lines, pct };
});

function show(index: number) {
  hover.value = index;
}

function hide(index: number) {
  if (hover.value === index) hover.value = null;
}
</script>

<template>
  <div
    class="relative flex h-8 w-full overflow-visible"
    :class="rounded ? 'gap-0.5' : 'gap-px'"
    :data-testid="testId"
  >
    <div
      v-for="(cell, i) in cells"
      :key="i"
      class="min-h-full min-w-0 flex-1 outline-none"
      :class="rounded ? 'rounded-sm' : ''"
      :style="{ background: cell.background }"
      data-testid="uptime-cell"
      :aria-label="cell.title"
      tabindex="0"
      @mouseenter="show(i)"
      @mouseleave="hide(i)"
      @focus="show(i)"
      @blur="hide(i)"
    ></div>
    <div
      v-if="tooltip"
      class="pointer-events-none absolute bottom-full z-10 mb-1 -translate-x-1/2 whitespace-nowrap rounded bg-[#111827] px-2 py-1 text-xs text-[#f9fafb] shadow"
      :style="{ left: `${tooltip.pct}%` }"
      data-testid="uptime-bar-tooltip"
      role="tooltip"
    >
      <p v-for="(line, i) in tooltip.lines" :key="i" :class="i === 0 ? '' : 'mt-0.5'">
        {{ line }}
      </p>
    </div>
  </div>
</template>
