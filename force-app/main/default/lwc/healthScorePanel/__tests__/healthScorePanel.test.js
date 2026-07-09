import { createElement } from '@lwc/engine-dom';
import { subscribe, unsubscribe } from 'lightning/messageService';
import HealthScorePanel from 'c/healthScorePanel';
import getHealthSummary from '@salesforce/apex/HealthScoreController.getHealthSummary';

jest.mock(
    '@salesforce/apex/HealthScoreController.getHealthSummary',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/HealthScoreController.recalculate',
    () => ({ default: jest.fn().mockResolvedValue() }),
    { virtual: true }
);

jest.mock('@salesforce/messageChannel/HealthScoreRefresh__c', () => ({ default: 'HEALTH_REFRESH_CHANNEL' }), {
    virtual: true
});

const SUMMARY = {
    score: 82,
    churnRisk: 'Low',
    trend: 'Improving',
    nps: 40,
    updatedAt: '2026-07-01T03:00:00.000Z',
    adoptionScore: 80,
    supportScore: 100,
    engagementScore: 70,
    financialScore: 65,
    history: [
        { scoredOn: '2026-06-29', score: 78 },
        { scoredOn: '2026-06-30', score: 80 },
        { scoredOn: '2026-07-01', score: 82 }
    ]
};

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function buildComponent() {
    const element = createElement('c-health-score-panel', { is: HealthScorePanel });
    element.recordId = '001000000000001AAA';
    document.body.appendChild(element);
    return element;
}

describe('c-health-score-panel', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders score, risk badge and dimension bars from the wire', async () => {
        const element = buildComponent();
        getHealthSummary.emit(SUMMARY);
        await flushPromises();

        const score = element.shadowRoot.querySelector('.score');
        expect(score.textContent).toBe('82');

        const badge = element.shadowRoot.querySelector('.slds-badge');
        expect(badge.textContent).toContain('Low');

        const bars = element.shadowRoot.querySelectorAll('.bar-fill');
        expect(bars.length).toBe(4);
    });

    it('renders the trend sparkline when history has multiple points', async () => {
        const element = buildComponent();
        getHealthSummary.emit(SUMMARY);
        await flushPromises();

        const polyline = element.shadowRoot.querySelector('polyline');
        expect(polyline).not.toBeNull();
        expect(polyline.getAttribute('points').split(' ')).toHaveLength(3);
    });

    it('shows the error state when the wire fails', async () => {
        const element = buildComponent();
        getHealthSummary.error({ message: 'No access' });
        await flushPromises();

        const alert = element.shadowRoot.querySelector('[role="alert"]');
        expect(alert).not.toBeNull();
    });

    it('shows the empty state for an unscored account', async () => {
        const element = buildComponent();
        getHealthSummary.emit({ ...SUMMARY, score: null, history: [] });
        await flushPromises();

        expect(element.shadowRoot.querySelector('.score')).toBeNull();
        expect(element.shadowRoot.textContent).toContain('has not been scored yet');
    });

    it('unsubscribes from the message channel when removed from the DOM', () => {
        const token = Symbol('subscription');
        subscribe.mockReturnValue(token);

        const element = buildComponent();
        expect(subscribe).toHaveBeenCalledTimes(1);

        document.body.removeChild(element);
        expect(unsubscribe).toHaveBeenCalledWith(token);
    });
});
