import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('error_rate');
const latencyTrend = new Trend('latency_p99');
const requestCounter = new Counter('requests_total');

export const options = {
    stages: [
        { duration: '30s', target: 10 },  // Ramp-up
        { duration: '1m', target: 50 },   // Load test
        { duration: '30s', target: 100 }, // Peak
        { duration: '30s', target: 0 }    // Cooldown
    ],
    thresholds: {
        http_req_duration: ['p(95)<500', 'p(99)<1000'],
        http_req_failed: ['rate<0.05'],  // Error rate < 5%
        error_rate: ['rate<0.1'],
    },
    summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
    group('API Calls', () => {
        // Normal endpoint
        let res1 = http.get(`${BASE_URL}/api/data`);
        check(res1, {
            'data endpoint status 200': (r) => r.status === 200,
            'data endpoint response time < 1s': (r) => r.timings.duration < 1000,
        });
        
        errorRate.add(res1.status !== 200);
        latencyTrend.add(res1.timings.duration);
        requestCounter.add(1);
        
        sleep(0.5);
        
        // Slow endpoint for bottleneck detection
        let res2 = http.get(`${BASE_URL}/api/slow`);
        check(res2, {
            'slow endpoint handles load': (r) => r.status === 200,
        });
        
        sleep(1);
    });
}

export function handleSummary(data) {
    const dur = data.metrics.http_req_duration.values;
    console.log('===== LOAD TEST SUMMARY =====');
    console.log(`Total requests: ${data.metrics.http_reqs.values.count}`);
    console.log(`Error rate:     ${(data.metrics.http_req_failed.values.rate * 100).toFixed(2)}%`);
    console.log(`P95 latency:    ${dur['p(95)'] !== undefined ? dur['p(95)'].toFixed(1) : 'N/A'}ms`);
    console.log(`P99 latency:    ${dur['p(99)'] !== undefined ? dur['p(99)'].toFixed(1) : 'N/A'}ms`);
    console.log(`Avg latency:    ${dur['avg'] !== undefined ? dur['avg'].toFixed(1) : 'N/A'}ms`);
    return {
        'results/load-test-summary.json': JSON.stringify(data, null, 2),
    };
}