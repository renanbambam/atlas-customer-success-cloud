import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { subscribe, MessageContext } from 'lightning/messageService';
import HEALTH_REFRESH_CHANNEL from '@salesforce/messageChannel/HealthScoreRefresh__c';
import getSubscriptions from '@salesforce/apex/SubscriptionController.getSubscriptions';

const COLUMNS = [
    { label: 'Subscription', fieldName: 'Name', sortable: true },
    { label: 'Status', fieldName: 'Status__c', sortable: true },
    {
        label: 'Total ARR',
        fieldName: 'Total_ARR__c',
        type: 'currency',
        sortable: true,
        cellAttributes: { alignment: 'right' }
    },
    { label: 'Renewal Date', fieldName: 'Renewal_Date__c', type: 'date-local', sortable: true },
    { label: 'Days To Renewal', fieldName: 'Days_To_Renewal__c', type: 'number', sortable: true },
    { label: 'Auto Renew', fieldName: 'Auto_Renew__c', type: 'boolean' }
];

export default class SubscriptionList extends LightningElement {
    @api recordId;

    columns = COLUMNS;
    sortedBy = 'Renewal_Date__c';
    sortedDirection = 'asc';
    rows = [];
    subscription = null;
    wiredRows;

    @wire(MessageContext)
    messageContext;

    @wire(getSubscriptions, { accountId: '$recordId' })
    handleRows(result) {
        this.wiredRows = result;
        if (result.data) {
            this.rows = this.sort(result.data, this.sortedBy, this.sortedDirection);
        }
    }

    connectedCallback() {
        // A recalculation can change what matters here (ARR, renewal dates
        // edited before the refresh); stay in sync with the health panel.
        this.subscription = subscribe(this.messageContext, HEALTH_REFRESH_CHANNEL, (message) => {
            if (message.accountId === this.recordId) {
                refreshApex(this.wiredRows);
            }
        });
    }

    get errorMessage() {
        const error = this.wiredRows && this.wiredRows.error;
        if (!error) {
            return null;
        }
        return (error.body && error.body.message) || 'Unable to load subscriptions.';
    }

    get isEmpty() {
        return this.wiredRows && this.wiredRows.data && this.rows.length === 0;
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        this.rows = this.sort(this.rows, fieldName, sortDirection);
    }

    sort(data, fieldName, direction) {
        const modifier = direction === 'asc' ? 1 : -1;
        return [...data].sort((a, b) => {
            const left = a[fieldName] ?? '';
            const right = b[fieldName] ?? '';
            if (left === right) {
                return 0;
            }
            return left > right ? modifier : -modifier;
        });
    }
}
