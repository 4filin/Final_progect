package main

import (
	"context"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

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

func healthz(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) }
func readyz(w http.ResponseWriter, _ *http.Request)  { w.WriteHeader(http.StatusOK) }

func router() *mux.Router {
	r := mux.NewRouter()
	r.HandleFunc("/", instrument("/", handler))
	r.HandleFunc("/healthz", healthz)
	r.HandleFunc("/readyz", readyz)
	r.Handle("/metrics", promhttp.Handler())
	return r
}

func main() {
	srv := &http.Server{
		Handler:      router(),
		Addr:         ":8080",
		WriteTimeout: 15 * time.Second,
		ReadTimeout:  15 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	go func() {
		log.Println("starting server on :8080")
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server error: %v", err)
		}
	}()

	<-ctx.Done()
	log.Println("shutting down...")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdownCtx)
}