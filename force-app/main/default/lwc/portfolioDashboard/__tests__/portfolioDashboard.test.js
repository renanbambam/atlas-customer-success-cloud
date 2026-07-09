import { createElement } from '@lwc/engine-dom';
import PortfolioDashboard from 'c/portfolioDashboard';
import getPortfolioSummary from '@salesforce/apex/PortfolioController.getPortfolioSummary';
import getAccountsByRisk from '@salesforce/apex/PortfolioController.getAccountsByRisk';

jest.mock('@salesforce/i18n/currency', () => ({ default: 'USD' }), { virtual: true });
jest.mock('@salesforce/i18n/locale', () => ({ default: 'en-US' }), { virtual: true });

jest.mock(
    '@salesforce/apex/PortfolioController.getPortfolioSummary',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

jest.mock('@salesforce/apex/PortfolioController.getAccountsByRisk', () => ({ default: jest.fn() }), {
    virtual: true
});

const SUMMARY = {
    scoredCustomerCount: 120,
    lowRiskCount: 80,
    mediumRiskCount: 30,
    highRiskCount: 10,
    activeArr: 12000000,
    arrAtRisk: 900000,
    renewalsDueCount: 14,
    renewalsDueAmount: 2100000,
    renewalHorizonDays: 90
};

const PAGE = Array.from({ length: 10 }, (unused, index) => ({
    accountId: `00100000000000${index}AAA`,
    name: `Account ${index}`,
    healthScore: 30 + index,
    churnRisk: 'High',
    trend: 'Declining',
    nps: -20,
    csmName: 'Jordan CSM'
}));

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function buildComponent() {
    const element = createElement('c-portfolio-dashboard', { is: PortfolioDashboard });
    document.body.appendChild(element);
    return element;
}

describe('c-portfolio-dashboard', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders KPI tiles and labeled risk bars from the summary', async () => {
        getAccountsByRisk.mockResolvedValue(PAGE);
        const element = buildComponent();
        getPortfolioSummary.emit(SUMMARY);
        await flushPromises();

        const tiles = element.shadowRoot.querySelectorAll('.kpi-tile');
        expect(tiles.length).toBe(4);

        const riskRows = element.shadowRoot.querySelectorAll('.risk-row');
        expect(riskRows.length).toBe(3);
        expect(riskRows[2].textContent).toContain('High risk');
        expect(riskRows[2].textContent).toContain('10');
    });

    it('loads the first page of at-risk accounts on connect', async () => {
        getAccountsByRisk.mockResolvedValue(PAGE);
        const element = buildComponent();
        getPortfolioSummary.emit(SUMMARY);
        await flushPromises();

        expect(getAccountsByRisk).toHaveBeenCalledWith({ churnRisk: 'High', pageSize: 10, offsetValue: 0 });
        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table.data).toHaveLength(10);
        expect(table.data[0].accountUrl).toContain('/lightning/r/Account/');
    });

    it('appends the next page on Load more', async () => {
        getAccountsByRisk.mockResolvedValue(PAGE);
        const element = buildComponent();
        getPortfolioSummary.emit(SUMMARY);
        await flushPromises();

        getAccountsByRisk.mockResolvedValue(PAGE.slice(0, 3));
        const loadMore = element.shadowRoot.querySelector('lightning-button');
        loadMore.click();
        await flushPromises();

        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table.data).toHaveLength(13);
        expect(getAccountsByRisk).toHaveBeenLastCalledWith({
            churnRisk: 'High',
            pageSize: 10,
            offsetValue: 10
        });
    });

    it('resets the list when the risk filter changes', async () => {
        getAccountsByRisk.mockResolvedValue(PAGE);
        const element = buildComponent();
        getPortfolioSummary.emit(SUMMARY);
        await flushPromises();

        getAccountsByRisk.mockResolvedValue([]);
        const combobox = element.shadowRoot.querySelector('lightning-combobox');
        combobox.dispatchEvent(new CustomEvent('change', { detail: { value: 'Medium' } }));
        await flushPromises();

        expect(getAccountsByRisk).toHaveBeenLastCalledWith({
            churnRisk: 'Medium',
            pageSize: 10,
            offsetValue: 0
        });
        expect(element.shadowRoot.textContent).toContain('No accounts in this risk band');
    });

    it('surfaces load failures as an alert', async () => {
        getAccountsByRisk.mockRejectedValue({ body: { message: 'No access' } });
        const element = buildComponent();
        getPortfolioSummary.emit(SUMMARY);
        await flushPromises();

        expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe('No access');
    });
});
