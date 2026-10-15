// frozen_string_literal: false
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "trendChart",
    "categoryChart",
    "dowChart",
    "todChart",
    "ratingChart"
  ]

  static values = {
    trendLabels: Array,
    trendData: Array,
    categoryLabels: Array,
    categoryData: Array,
    dowLabels: Array,
    dowData: Array,
    todLabels: Array,
    todData: Array,
    ratingLabels: Array,
    ratingData: Array
  }

  connect() {
    this.chartInstances = []
    this.waitForChartAndInit()
  }

  disconnect() {
    this.destroyCharts()
  }

  destroyCharts() {
    if (this.chartInstances) {
      this.chartInstances.forEach(chart => {
        try {
          chart.destroy()
        } catch (e) {
          console.error("Error destroying chart instance", e)
        }
      })
      this.chartInstances = []
    }
  }

  waitForChartAndInit() {
    if (typeof window.Chart !== "undefined") {
      this.initAllCharts()
    } else {
      let attempts = 0
      const interval = setInterval(() => {
        attempts += 1
        if (typeof window.Chart !== "undefined") {
          clearInterval(interval)
          this.initAllCharts()
        } else if (attempts > 20) {
          clearInterval(interval)
          console.warn("Chart.js failed to load within timeout")
        }
      }, 100)
    }
  }

  initAllCharts() {
    this.destroyCharts()

    if (this.hasTrendChartTarget && this.trendLabelsValue.length > 0) {
      this.initTrendChart()
    }
    if (this.hasCategoryChartTarget && this.categoryLabelsValue.length > 0) {
      this.initCategoryChart()
    }
    if (this.hasDowChartTarget && this.dowLabelsValue.length > 0) {
      this.initDowChart()
    }
    if (this.hasTodChartTarget && this.todLabelsValue.length > 0) {
      this.initTodChart()
    }
    if (this.hasRatingChartTarget && this.ratingLabelsValue.length > 0) {
      this.initRatingChart()
    }
  }

  initTrendChart() {
    const ctx = this.trendChartTarget.getContext("2d")
    const gradient = ctx.createLinearGradient(0, 0, 0, 240)
    gradient.addColorStop(0, "rgba(99, 102, 241, 0.28)")
    gradient.addColorStop(1, "rgba(99, 102, 241, 0.01)")

    const chart = new window.Chart(this.trendChartTarget, {
      type: "line",
      data: {
        labels: this.trendLabelsValue,
        datasets: [{
          label: "Questions Answered",
          data: this.trendDataValue,
          borderColor: "#6366f1",
          backgroundColor: gradient,
          fill: true,
          tension: 0.35,
          borderWidth: 2.5,
          pointBackgroundColor: "#4f46e5",
          pointBorderColor: "#ffffff",
          pointBorderWidth: 2,
          pointRadius: 4,
          pointHoverRadius: 6
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "#0f172a",
            titleFont: { size: 12, weight: "bold" },
            bodyFont: { size: 12 },
            padding: 10,
            cornerRadius: 8
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: { color: "#f1f5f9" },
            ticks: { precision: 0, font: { size: 11 } }
          },
          x: {
            grid: { display: false },
            ticks: { font: { size: 11 }, maxRotation: 45 }
          }
        }
      }
    })
    this.chartInstances.push(chart)
  }

  initCategoryChart() {
    const palette = ["#6366f1", "#10b981", "#0ea5e9", "#f59e0b", "#ec4899", "#8b5cf6", "#14b8a6"]
    const backgroundColors = this.categoryLabelsValue.map((_, i) => palette[i % palette.length])

    const chart = new window.Chart(this.categoryChartTarget, {
      type: "bar",
      data: {
        labels: this.categoryLabelsValue,
        datasets: [{
          label: "Responses",
          data: this.categoryDataValue,
          backgroundColor: backgroundColors,
          borderRadius: 8,
          borderSkipped: false
        }]
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "#0f172a",
            padding: 10,
            cornerRadius: 8
          }
        },
        scales: {
          x: {
            beginAtZero: true,
            grid: { color: "#f1f5f9" },
            ticks: { precision: 0, font: { size: 11 } }
          },
          y: {
            grid: { display: false },
            ticks: { font: { size: 11 } }
          }
        }
      }
    })
    this.chartInstances.push(chart)
  }

  initDowChart() {
    const chart = new window.Chart(this.dowChartTarget, {
      type: "bar",
      data: {
        labels: this.dowLabelsValue,
        datasets: [{
          label: "Submissions",
          data: this.dowDataValue,
          backgroundColor: "rgba(245, 158, 11, 0.85)",
          hoverBackgroundColor: "#f59e0b",
          borderRadius: 8,
          borderSkipped: false
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "#0f172a",
            padding: 10,
            cornerRadius: 8
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: { color: "#f1f5f9" },
            ticks: { precision: 0, font: { size: 11 } }
          },
          x: {
            grid: { display: false },
            ticks: { font: { size: 11 } }
          }
        }
      }
    })
    this.chartInstances.push(chart)
  }

  initTodChart() {
    const chart = new window.Chart(this.todChartTarget, {
      type: "doughnut",
      data: {
        labels: this.todLabelsValue,
        datasets: [{
          data: this.todDataValue,
          backgroundColor: ["#0284c7", "#f59e0b", "#6366f1", "#1e293b"],
          borderWidth: 2,
          borderColor: "#ffffff"
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom",
            labels: { boxWidth: 12, padding: 10, font: { size: 11 } }
          },
          tooltip: {
            backgroundColor: "#0f172a",
            padding: 10,
            cornerRadius: 8
          }
        },
        cutout: "65%"
      }
    })
    this.chartInstances.push(chart)
  }

  initRatingChart() {
    const ctx = this.ratingChartTarget.getContext("2d")
    const gradient = ctx.createLinearGradient(0, 0, 0, 200)
    gradient.addColorStop(0, "rgba(239, 68, 68, 0.25)")
    gradient.addColorStop(1, "rgba(239, 68, 68, 0.01)")

    const chart = new window.Chart(this.ratingChartTarget, {
      type: "line",
      data: {
        labels: this.ratingLabelsValue,
        datasets: [{
          label: "Avg Rating (1-5★)",
          data: this.ratingDataValue,
          borderColor: "#ef4444",
          backgroundColor: gradient,
          fill: true,
          tension: 0.3,
          borderWidth: 2,
          pointBackgroundColor: "#dc2626",
          pointRadius: 4,
          pointHoverRadius: 6
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "#0f172a",
            padding: 10,
            cornerRadius: 8
          }
        },
        scales: {
          y: {
            min: 0,
            max: 5,
            grid: { color: "#f1f5f9" },
            ticks: { stepSize: 1, font: { size: 11 } }
          },
          x: {
            grid: { display: false },
            ticks: { font: { size: 11 } }
          }
        }
      }
    })
    this.chartInstances.push(chart)
  }
}
