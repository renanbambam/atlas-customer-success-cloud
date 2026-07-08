import { createElement } from 'lwc';
import RenewalWorkspace from 'c/renewalWorkspace';
import getRenewals from '@salesforce/apex/RenewalWorkspaceController.getRenewals';

jest.mock('@salesforce/apex/RenewalWorkspaceController.getRenewals', () => ({ default: jest.fn() }), {
    virtual: true
});

const PAGE = Array.from({ length: 25 }, (unused, index) => ({
    opportunityId: `00600000000000${index}AAA`,
    name: `Renewal ${index}`,
    accountId: `00100000000000${index}AAA`,
    accountName: `Customer ${index}`,
    closeDate: '2026-08-15',
    amount: 50000 + index,
    stageName: 'Prospecting',
    daysToClose: 39
}));

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function buildComponent() {
    const element = createElement('c-renewal-workspace', { is: RenewalWorkspace });
    document.body.appendChild(element);
    return element;
}

describe('c-renewal-workspace', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('loads the default 90-day horizon on connect', async () => {
        getRenewals.mockResolvedValue(PAGE);
        const element = buildComponent();
        await flushPromises();

        expect(getRenewals).toHaveBeenCalledWith({ horizonDays: 90, pageSize: 25, offsetValue: 0 });
        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table.data).toHaveLength(25);
    });

    it('reloads when the horizon filter changes', async () => {
        getRenewals.mockResolvedValue([]);
        const element = buildComponent();
        await flushPromises();

        const combobox = element.shadowRoot.querySelector('lightning-combobox');
        combobox.dispatchEvent(new CustomEvent('change', { detail: { value: '30' } }));
        await flushPromises();

        expect(getRenewals).toHaveBeenLastCalledWith({ horizonDays: 30, pageSize: 25, offsetValue: 0 });
        expect(element.shadowRoot.textContent).toContain('No open renewals');
    });

    it('appends the next page when the table asks for more', async () => {
        getRenewals.mockResolvedValue(PAGE);
        const element = buildComponent();
        await flushPromises();

        getRenewals.mockResolvedValue(PAGE.slice(0, 5));
        const table = element.shadowRoot.querySelector('lightning-datatable');
        table.dispatchEvent(new CustomEvent('loadmore'));
        await flushPromises();

        expect(table.data).toHaveLength(30);
        expect(getRenewals).toHaveBeenLastCalledWith({ horizonDays: 90, pageSize: 25, offsetValue: 25 });
    });

    it('sorts loaded rows client-side', async () => {
        getRenewals.mockResolvedValue(PAGE.slice(0, 3));
        const element = buildComponent();
        await flushPromises();

        const table = element.shadowRoot.querySelector('lightning-datatable');
        table.dispatchEvent(
            new CustomEvent('sort', { detail: { fieldName: 'amount', sortDirection: 'desc' } })
        );
        await flushPromises();

        expect(table.data[0].amount).toBe(50002);
    });

    it('surfaces failures as an alert', async () => {
        getRenewals.mockRejectedValue({ body: { message: 'Denied' } });
        const element = buildComponent();
        await flushPromises();

        expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe('Denied');
    });
});
