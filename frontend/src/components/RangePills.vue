<script setup lang="ts">
import type { HistoryWindow } from '../types';

defineProps<{
  windows: HistoryWindow[];
  labels: Record<HistoryWindow, string>;
  range: HistoryWindow;
  buttonClass: string;
  activeClass: string;
}>();

const emit = defineEmits<{
  select: [window: HistoryWindow];
}>();
</script>

<template>
  <div
    class="flex max-w-full flex-wrap gap-1.5 overflow-x-auto sm:justify-end"
    role="tablist"
  >
    <button
      v-for="id in windows"
      :key="id"
      :data-testid="`range-${id}`"
      type="button"
      :class="[buttonClass, range === id ? activeClass : '']"
      @click="emit('select', id)"
    >
      {{ labels[id] }}
    </button>
  </div>
</template>
