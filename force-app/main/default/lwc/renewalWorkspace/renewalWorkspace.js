import { LightningElement } from 'lwc';
import getRenewals from '@salesforce/apex/RenewalWorkspaceController.getRenewals';

const PAGE_SIZE = 25;

const HORIZON_OPTIONS = [
    { label: 'Next 30 days', value: '30' },
    { label: 'Next 60 days', value: '60' },
    { label: 'Next 90 days', value: '90' },
    { label: 'Next 180 days', value: '180' }
];

const COLUMNS = [
    {
        label: 'Renewal',
        fieldName: 'opportunityUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'name' }, target: '_self' },
        sortable: true
    },
    {
        label: 'Account',
        fieldName: 'accountUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'accountName' }, target: '_self' },
        sortable: true
    },
    { label: 'Close Date', fieldName: 'closeDate', type: 'date-local', sortable: true },
    {
        label: 'Days Left',
        fieldName: 'daysToClose',
        type: 'number',
        sortable: true,
        cellAttributes: { alignment: 'left' }
    },
    {
        label: 'Amount',
        fieldName: 'amount',
        type: 'currency',
        sortable: true,
        cellAttributes: { alignment: 'right' }
    },
    { label: 'Stage', fieldName: 'stageName', sortable: true }
];

export default class RenewalWorkspace extends LightningElement {
    horizonOptions = HORIZON_OPTIONS;
    columns = COLUMNS;
    selectedHorizon = '90';
    rows = [];
    offset = 0;
    hasMore = true;
    isLoading = false;
    errorMessage;
    sortedBy = 'closeDate';
    sortedDirection = 'asc';

    connectedCallback() {
        this.loadPage(true);
    }

    get isEmpty() {
        return !this.isLoading && this.rows.length === 0 && !this.errorMessage;
    }

    handleHorizonChange(event) {
        this.selectedHorizon = event.detail.value;
        this.loadPage(true);
    }

    // lightning-datatable lazy loading: fires as the user scrolls near the end.
    handleLoadMore(event) {
        const table = event.target;
        if (!this.hasMore || this.isLoading) {
            table.isLoading = false;
            return;
        }
        table.isLoading = true;
        this.loadPage(false).finally(() => {
            table.isLoading = false;
            table.enableInfiniteLoading = this.hasMore;
        });
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        const modifier = sortDirection === 'asc' ? 1 : -1;
        this.rows = [...this.rows].sort((a, b) => {
            const left = a[fieldName] ?? '';
            const right = b[fieldName] ?? '';
            if (left === right) {
                return 0;
            }
            return left > right ? modifier : -modifier;
        });
    }

    async loadPage(reset) {
        if (reset) {
            this.offset = 0;
            this.rows = [];
            this.hasMore = true;
        }
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            const page = await getRenewals({
                horizonDays: parseInt(this.selectedHorizon, 10),
                pageSize: PAGE_SIZE,
                offsetValue: this.offset
            });
            this.rows = [
                ...this.rows,
                ...page.map((row) => ({
                    ...row,
                    opportunityUrl: `/lightning/r/Opportunity/${row.opportunityId}/view`,
                    accountUrl: `/lightning/r/Account/${row.accountId}/view`
                }))
            ];
            this.offset += page.length;
            this.hasMore = page.length === PAGE_SIZE;
        } catch (error) {
            this.errorMessage = (error.body && error.body.message) || 'Unable to load renewals.';
        } finally {
            this.isLoading = false;
        }
    }
}
