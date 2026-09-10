import http from 'k6/http';
import { check } from 'k6';

const host = __ENV.LOAD_HOST;
const rate = Number(__ENV.LOAD_RATE);
const paths = (__ENV.LOAD_PATHS || '/').split(',').filter(Boolean);

export const options = {
    insecureSkipTLSVerify: true,
    discardResponseBodies: true,
    scenarios: {
        traffic: {
            executor: 'ramping-arrival-rate',
            startRate: Math.ceil(rate / 10),
            timeUnit: '1s',
            preAllocatedVUs: Number(__ENV.LOAD_VUS),
            maxVUs: Number(__ENV.LOAD_VUS) * 4,
            stages: [
                { duration: __ENV.LOAD_RAMP, target: rate },
                { duration: __ENV.LOAD_DURATION, target: rate },
            ],
        },
    },
    thresholds: {
        http_req_failed: ['rate<0.01'],
        http_req_duration: ['p(95)<1000'],
    },
};

export default function () {

    const path = paths[Math.floor(Math.random() * paths.length)];
    const res = http.get(`${host}${path}`);

    check(res, { 'answered': (r) => r.status < 500 });

}
