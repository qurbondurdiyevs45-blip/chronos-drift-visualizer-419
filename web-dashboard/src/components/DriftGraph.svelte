<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import Chart from 'chart.js/auto';
  import 'chartjs-adapter-date-fns';

  export let nodeName: string = "Global Fleet";
  export let driftData: { timestamp: number; drift: number }[] = [];
  export let limit: number = 100;

  let canvas: HTMLCanvasElement;
  let chart: Chart;

  $: if (chart && driftData) {
    updateChart();
  }

  function updateChart() {
    const sortedData = [...driftData]
      .sort((a, b) => a.timestamp - b.timestamp)
      .slice(-limit);

    chart.data.labels = sortedData.map(d => d.timestamp);
    chart.data.datasets[0].data = sortedData.map(d => d.drift);
    
    // Smooth transition for real-time feel
    chart.update('none');
  }

  onMount(() => {
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: [],
        datasets: [{
          label: `Clock Drift (ms) - ${nodeName}`,
          data: [],
          borderColor: '#00ff9d',
          backgroundColor: 'rgba(0, 255, 157, 0.1)',
          borderWidth: 2,
          pointRadius: 0,
          tension: 0.4,
          fill: true
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        scales: {
          x: {
            type: 'time',
            time: {
              unit: 'second',
              displayFormats: {
                second: 'HH:mm:ss'
              }
            },
            grid: {
              color: 'rgba(255, 255, 255, 0.05)'
            },
            ticks: {
              color: '#888',
              maxRotation: 0
            }
          },
          y: {
            grid: {
              color: 'rgba(255, 255, 255, 0.1)'
            },
            ticks: {
              color: '#888',
              callback: (value) => `${value}ms`
            },
            suggestedMin: -1,
            suggestedMax: 1
          }
        },
        plugins: {
          legend: {
            display: true,
            labels: {
              color: '#fff',
              font: {
                family: 'monospace'
              }
            }
          },
          tooltip: {
            enabled: true,
            mode: 'index',
            intersect: false
          }
        }
      }
    });
  });

  onDestroy(() => {
    if (chart) chart.destroy();
  });
</script>

<div class="chart-container">
  <div class="chart-header">
    <span class="status-indicator"></span>
    <h3>Node: {nodeName}</h3>
  </div>
  <div class="canvas-wrapper">
    <canvas bind:this={canvas}></canvas>
  </div>
</div>

<style>
  .chart-container {
    background: #1a1a1a;
    border: 1px solid #333;
    border-radius: 8px;
    padding: 1rem;
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  .chart-header {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    margin-bottom: 1rem;
  }

  .chart-header h3 {
    margin: 0;
    font-size: 0.9rem;
    color: #efefef;
    text-transform: uppercase;
    letter-spacing: 0.05rem;
    font-family: 'JetBrains Mono', monospace;
  }

  .status-indicator {
    width: 8px;
    height: 8px;
    background: #00ff9d;
    border-radius: 50%;
    box-shadow: 0 0 8px #00ff9d;
  }

  .canvas-wrapper {
    flex-grow: 1;
    position: relative;
    min-height: 200px;
  }

  canvas {
    width: 100% !important;
    height: 100% !important;
  }
</style>