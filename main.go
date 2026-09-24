package main

import (
	"io"
	"log"
	"net/http"
	"time"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Метрики приложения
var (
	httpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"path", "method"},
	)
	httpRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request latency in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"path", "method"},
	)
)

// instrumentation: оборачиваем handler, считаем запросы и время
func instrument(path string, h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		h(w, r)
		httpRequestsTotal.WithLabelValues(path, r.Method).Inc()
		httpRequestDuration.WithLabelValues(path, r.Method).Observe(time.Since(start).Seconds())
	}
}

func handler(w http.ResponseWriter, r *http.Request) {
	if _, err := io.WriteString(w, "Финальный Проект отработал. Если ты это видишь у тебя получилось. Поздравляю! \n"); err != nil {
		http.Error(w, "failed to write response", http.StatusInternalServerError)
	}
}

// Route declaration
func router() *mux.Router {
	r := mux.NewRouter()
	r.HandleFunc("/", instrument("/", handler))
	r.Handle("/metrics", promhttp.Handler()) // endpoint для Prometheus
	return r
}

// Initiate web server
func main() {
	router := router()
	srv := &http.Server{
		Handler:      router,
		Addr:         ":8080",
		WriteTimeout: 15 * time.Second,
		ReadTimeout:  15 * time.Second,
	}

	log.Fatal(srv.ListenAndServe())
}