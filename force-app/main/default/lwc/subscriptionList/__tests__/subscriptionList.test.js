import { createElement } from 'lwc';
import SubscriptionList from 'c/subscriptionList';
import getSubscriptions from '@salesforce/apex/SubscriptionController.getSubscriptions';

jest.mock(
    '@salesforce/apex/SubscriptionController.getSubscriptions',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

jest.mock('@salesforce/messageChannel/HealthScoreRefresh__c', () => ({ default: 'HEALTH_REFRESH_CHANNEL' }), {
    virtual: true
});

const ROWS = [
    {
        Id: 'a01000000000001AAA',
        Name: 'SUB-00001',
        Status__c: 'Active',
        Total_ARR__c: 120000,
        Renewal_Date__c: '2026-12-31',
        Days_To_Renewal__c: 177,
        Auto_Renew__c: true
    },
    {
        Id: 'a01000000000002AAA',
        Name: 'SUB-00002',
        Status__c: 'Active',
        Total_ARR__c: 30000,
        Renewal_Date__c: '2026-09-30',
        Days_To_Renewal__c: 85,
        Auto_Renew__c: false
    }
];

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function buildComponent() {
    const element = createElement('c-subscription-list', { is: SubscriptionList });
    element.recordId = '001000000000001AAA';
    document.body.appendChild(element);
    return element;
}

describe('c-subscription-list', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders rows sorted by renewal date ascending by default', async () => {
        const element = buildComponent();
        getSubscriptions.emit(ROWS);
        await flushPromises();

        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table.data).toHaveLength(2);
        expect(table.data[0].Name).toBe('SUB-00002');
    });

    it('re-sorts when the user clicks a column header', async () => {
        const element = buildComponent();
        getSubscriptions.emit(ROWS);
        await flushPromises();

        const table = element.shadowRoot.querySelector('lightning-datatable');
        table.dispatchEvent(
            new CustomEvent('sort', {
                detail: { fieldName: 'Total_ARR__c', sortDirection: 'desc' }
            })
        );
        await flushPromises();

        expect(table.data[0].Total_ARR__c).toBe(120000);
    });

    it('shows the empty state when the account has no subscriptions', async () => {
        const element = buildComponent();
        getSubscriptions.emit([]);
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain('No subscriptions');
    });

    it('shows the error state when the wire fails', async () => {
        const element = buildComponent();
        getSubscriptions.error({ message: 'No access' });
        await flushPromises();

        expect(element.shadowRoot.querySelector('[role="alert"]')).not.toBeNull();
    });
});
