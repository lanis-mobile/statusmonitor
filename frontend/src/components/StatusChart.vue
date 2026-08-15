<script setup lang="ts">
import { computed } from 'vue';
import { use } from 'echarts/core';
import { CanvasRenderer } from 'echarts/renderers';
import { BarChart, LineChart } from 'echarts/charts';
import {
  DataZoomComponent,
  GridComponent,
  MarkAreaComponent,
  MarkLineComponent,
  TooltipComponent,
} from 'echarts/components';
import VChart from 'vue-echarts';
import {
  axisBounds,
  buildChartBands,
  chartAriaLabel,
  computeLatencyStats,
  formatAxisTime,
  formatTooltipTime,
  measuredPoints,
  overlayAt,
  useLongRangeTools,
  useSampling,
  useSmoothLine,
} from '../lib/chartData';
import { windowLabels } from '../lib/windows';
import type { HistoryPayload, HolidayPeriod } from '../types';

use([
  CanvasRenderer,
  LineChart,
  BarChart,
  GridComponent,
  TooltipComponent,
  MarkAreaComponent,
  MarkLineComponent,
  DataZoomComponent,
]);

export interface ChartTheme {
  line: string;
  area: string;
  holiday: string;
  down: string;
  noData: string;
  axis: string;
  grid: string;
  tooltipBg: string;
  tooltipText: string;
  up: string;
}

const props = defineProps<{
  history: HistoryPayload;
  holidays: HolidayPeriod[];
  theme: ChartTheme;
  highlightRange?: { start: number; end: number } | null;
}>();

const emit = defineEmits<{
  incidentSelect: [range: { start: number; end: number }];
}>();

const bands = computed(() =>
  buildChartBands(
    props.history,
    props.holidays.map((h) => ({ start: h.start, end: h.end, label: h.label })),
  ),
);

const stats = computed(() => computeLatencyStats(props.history.points));
const measured = computed(() => measuredPoints(props.history.points));
const bounds = computed(() => axisBounds(props.history));
const longRange = computed(() => useLongRangeTools(props.history.window));

const ariaLabel = computed(() =>
  chartAriaLabel(props.history, stats.value, windowLabels),
);

const dataZoomRange = computed(() => {
  if (!props.highlightRange) return null;
  const { from, to } = props.history;
  const span = (to - from) * 1000;
  if (span <= 0) return null;
  const pad = Math.max(span * 0.08, props.history.bucketSeconds * 1000 * 4);
  const start = Math.max(from * 1000, props.highlightRange.start * 1000 - pad);
  const end = Math.min(to * 1000, props.highlightRange.end * 1000 + pad);
  return {
    start: ((start - from * 1000) / span) * 100,
    end: ((end - from * 1000) / span) * 100,
  };
});

function markAreas(
  ranges: Array<{ start: number; end: number; label?: string }>,
  color: string,
) {
  return ranges.map((r) => [
    {
      name: r.label,
      xAxis: r.start * 1000,
      itemStyle: { color },
      label: { show: false },
    },
    { xAxis: r.end * 1000 },
  ]);
}

const option = computed(() => {
  const { points, bucketSeconds, window } = props.history;
  const b = bands.value;
  const s = stats.value;
  const { min, max } = bounds.value;
  const latencies = points
    .filter(([, ms, ok]) => ok === 1 && ms != null)
    .map(([, ms]) => Number(ms));
  const yMax =
    latencies.length === 0
      ? 400
      : Math.ceil(Math.max(...latencies) * 1.12 / 50) * 50;

  const lineData = points.map(([ts, ms, ok]) => [
    ts * 1000,
    ok === 1 && ms != null ? ms : null,
  ]);

  const downBarData = points.map(([ts, , ok]) => [
    ts * 1000,
    ok === 0 ? 1 : 0,
  ]);

  const markLines = [];
  if (s.avg != null) {
    markLines.push({
      name: 'Ø',
      yAxis: s.avg,
      lineStyle: { type: 'dashed', color: props.theme.axis, width: 1 },
      label: { formatter: `Ø ${s.avg} ms`, color: props.theme.axis, fontSize: 10 },
    });
  }
  if (s.p95 != null && s.p95 !== s.avg) {
    markLines.push({
      name: 'p95',
      yAxis: s.p95,
      lineStyle: { type: 'dotted', color: props.theme.axis, width: 1 },
      label: { formatter: `p95 ${s.p95} ms`, color: props.theme.axis, fontSize: 10 },
    });
  }

  const dataZoom = longRange.value
    ? [
        { type: 'inside', xAxisIndex: 0, filterMode: 'none' },
        {
          type: 'slider',
          xAxisIndex: 0,
          height: 18,
          bottom: 6,
          borderColor: props.theme.grid,
          fillerColor: 'rgba(37, 99, 235, 0.12)',
          handleSize: 12,
          textStyle: { color: props.theme.axis, fontSize: 10 },
          ...(dataZoomRange.value ?? {}),
        },
      ]
    : dataZoomRange.value
      ? [{ type: 'inside', xAxisIndex: 0, ...dataZoomRange.value }]
      : [];

  return {
    animation: false,
    grid: {
      left: 12,
      right: 12,
      top: 28,
      bottom: longRange.value ? 44 : 12,
      containLabel: true,
    },
    tooltip: {
      trigger: 'axis',
      confine: true,
      backgroundColor: props.theme.tooltipBg,
      borderWidth: 0,
      textStyle: { color: props.theme.tooltipText, fontSize: 12 },
      axisPointer: { type: 'cross', label: { backgroundColor: props.theme.tooltipBg } },
      formatter(params: unknown) {
        const items = Array.isArray(params) ? params : [params];
        const line = items.find(
          (p) => typeof p === 'object' && p != null && (p as { seriesName?: string }).seriesName === 'Antwortzeit',
        ) as { value?: [number, number | null] } | undefined;
        const ts = line?.value?.[0] ?? (items[0] as { value?: [number] })?.value?.[0];
        if (ts == null) return '';
        const ms = line?.value?.[1];
        const overlays = overlayAt(ts, b, bucketSeconds);
        const lines = [formatTooltipTime(ts)];
        if (ms == null) lines.push('Ausfall');
        else lines.push(`${Math.round(ms)} ms`);
        if (overlays.length > 0) lines.push(overlays.join(' · '));
        return lines.join('<br/>');
      },
    },
    xAxis: {
      type: 'time',
      min,
      max,
      axisLine: { lineStyle: { color: props.theme.axis } },
      axisTick: { show: false },
      axisLabel: {
        color: props.theme.axis,
        hideOverlap: true,
        fontSize: 11,
        formatter: (value: number) => formatAxisTime(value, window),
      },
      splitLine: { show: false },
    },
    yAxis: [
      {
        type: 'value',
        min: 0,
        max: yMax,
        name: 'ms',
        nameTextStyle: { color: props.theme.axis, fontSize: 10 },
        axisLine: { show: false },
        axisLabel: { color: props.theme.axis, fontSize: 11 },
        splitLine: { lineStyle: { color: props.theme.grid } },
      },
      {
        type: 'value',
        min: 0,
        max: 1,
        show: false,
      },
    ],
    dataZoom,
    series: [
      {
        name: 'Schulferien',
        type: 'line',
        data: [],
        silent: true,
        symbol: 'none',
        lineStyle: { width: 0 },
        markArea: {
          silent: true,
          data: markAreas(b.holidays, props.theme.holiday),
          z: 1,
        },
        z: 1,
      },
      {
        name: 'Keine Daten',
        type: 'line',
        data: [],
        silent: true,
        symbol: 'none',
        lineStyle: { width: 0 },
        markArea: {
          silent: true,
          data: markAreas(b.noData, props.theme.noData),
          z: 2,
        },
        z: 2,
      },
      {
        name: 'Ausfall',
        type: 'line',
        data: [],
        symbol: 'none',
        lineStyle: { width: 0 },
        markArea: {
          silent: false,
          data: markAreas(b.downs, props.theme.down),
          z: 3,
        },
        z: 3,
      },
      {
        name: 'Ausfallbalken',
        type: 'bar',
        yAxisIndex: 1,
        data: downBarData,
        barMaxWidth: 3,
        itemStyle: { color: props.theme.down, opacity: 0.85 },
        z: 4,
      },
      {
        name: 'Antwortzeit',
        type: 'line',
        showSymbol: false,
        smooth: useSmoothLine(window) ? 0.2 : false,
        connectNulls: false,
        sampling: useSampling(window) ? 'lttb' : undefined,
        lineStyle: { width: 1.5, color: props.theme.line },
        areaStyle: { color: props.theme.area },
        data: lineData,
        markLine: markLines.length > 0 ? { symbol: 'none', data: markLines } : undefined,
        z: 5,
      },
    ],
  };
});

function onChartClick(params: unknown) {
  const p = params as {
    componentType?: string;
    name?: string;
    data?: { xAxis?: number; coord?: number[] };
  };
  if (p.componentType !== 'markArea') return;
  const ts = p.data?.xAxis ?? p.data?.coord?.[0];
  if (ts == null) return;
  const start = Math.floor(ts / 1000);
  const down = bands.value.downs.find(
    (r) => r.start * 1000 <= ts && r.end * 1000 > ts,
  );
  if (down) {
    emit('incidentSelect', { start: down.start, end: down.end });
    return;
  }
  emit('incidentSelect', {
    start,
    end: start + props.history.bucketSeconds,
  });
}

</script>

<template>
  <div
    class="chart-frame"
    data-testid="chart"
    role="img"
    :aria-label="ariaLabel"
  >
    <p v-if="measured.length === 0" class="chart-empty" data-testid="chart-empty">
      Noch keine Messdaten für diesen Zeitraum.
    </p>
    <VChart
      v-else
      :key="`${history.from}-${history.to}-${highlightRange?.start ?? 0}`"
      class="status-chart"
      :option="option"
      autoresize
      @click="onChartClick"
    />
    <p class="sr-only">{{ ariaLabel }}</p>
  </div>
</template>

<style scoped>
.chart-frame,
.status-chart {
  display: block;
  width: 100%;
  height: 240px;
}

@media (min-width: 640px) {
  .chart-frame,
  .status-chart {
    height: 320px;
  }
}

.chart-empty {
  display: flex;
  height: 240px;
  align-items: center;
  justify-content: center;
  margin: 0;
  padding: 0 1rem;
  text-align: center;
  font-size: 0.875rem;
  color: #6b7280;
}

@media (min-width: 640px) {
  .chart-empty {
    height: 320px;
  }
}

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}
</style>
