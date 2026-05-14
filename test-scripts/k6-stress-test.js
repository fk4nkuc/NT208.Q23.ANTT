import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    stages: [
        { duration: '1m', target: 50 },   // 50 users
        { duration: '1m', target: 100 },  // 100 users
        { duration: '1m', target: 200 },  // 200 users
        { duration: '1m', target: 500 },  // 500 users
        { duration: '1m', target: 0 },    // Cooldown
    ],
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
    const res = http.get(`${BASE_URL}/api/data`);
    check(res, {
        'status is 200': (r) => r.status === 200,
    });
    sleep(0.1);
}