import { LightningElement, wire } from 'lwc';
import getPortfolioSummary from '@salesforce/apex/PortfolioController.getPortfolioSummary';
import getAccountsByRisk from '@salesforce/apex/PortfolioController.getAccountsByRisk';

const PAGE_SIZE = 10;

const RISK_OPTIONS = [
    { label: 'High risk', value: 'High' },
    { label: 'Medium risk', value: 'Medium' },
    { label: 'Low risk', value: 'Low' }
];

const ACCOUNT_COLUMNS = [
    {
        label: 'Account',
        fieldName: 'accountUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'name' }, target: '_self' }
    },
    { label: 'Score', fieldName: 'healthScore', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Trend', fieldName: 'trend' },
    { label: 'NPS', fieldName: 'nps', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'CSM', fieldName: 'csmName' }
];

export default class CsPortfolioDashboard extends LightningElement {
    riskOptions = RISK_OPTIONS;
    accountColumns = ACCOUNT_COLUMNS;
    selectedRisk = 'High';
    accountRows = [];
    accountOffset = 0;
    hasMore = true;
    isLoadingAccounts = false;
    accountError;
    wiredSummary;

    @wire(getPortfolioSummary)
    handleSummary(result) {
        this.wiredSummary = result;
    }

    connectedCallback() {
        this.loadAccounts(true);
    }

    get summary() {
        return this.wiredSummary && this.wiredSummary.data;
    }

    get summaryError() {
        const error = this.wiredSummary && this.wiredSummary.error;
        if (!error) {
            return null;
        }
        return (error.body && error.body.message) || 'Unable to load the portfolio summary.';
    }

    get kpis() {
        if (!this.summary) {
            return [];
        }
        return [
            {
                key: 'customers',
                label: 'Scored customers',
                value: this.formatNumber(this.summary.scoredCustomerCount)
            },
            { key: 'arr', label: 'Active ARR', value: this.formatCurrency(this.summary.activeArr) },
            { key: 'atrisk', label: 'ARR at risk', value: this.formatCurrency(this.summary.arrAtRisk) },
            {
                key: 'renewals',
                label: `Renewals due ${this.summary.renewalHorizonDays}d`,
                value: `${this.formatNumber(this.summary.renewalsDueCount)} · ${this.formatCurrency(
                    this.summary.renewalsDueAmount
                )}`
            }
        ];
    }

    // Risk distribution as labeled horizontal bars. Identity is carried by the
    // text label and count on every row — color is reinforcement, never the
    // only signal.
    get riskBars() {
        if (!this.summary) {
            return [];
        }
        const bands = [
            {
                key: 'Low',
                label: 'Low risk',
                count: this.summary.lowRiskCount,
                cssClass: 'bar-fill bar-fill_low'
            },
            {
                key: 'Medium',
                label: 'Medium risk',
                count: this.summary.mediumRiskCount,
                cssClass: 'bar-fill bar-fill_medium'
            },
            {
                key: 'High',
                label: 'High risk',
                count: this.summary.highRiskCount,
                cssClass: 'bar-fill bar-fill_high'
            }
        ];
        const max = Math.max(1, ...bands.map((band) => band.count));
        return bands.map((band) => ({
            ...band,
            barStyle: `width: ${Math.round((band.count / max) * 100)}%`,
            title: `${band.label}: ${band.count} accounts`
        }));
    }

    get listTitle() {
        return `${this.selectedRisk} risk accounts`;
    }

    get isListEmpty() {
        return !this.isLoadingAccounts && this.accountRows.length === 0 && !this.accountError;
    }

    handleRiskChange(event) {
        this.selectedRisk = event.detail.value;
        this.loadAccounts(true);
    }

    handleLoadMore() {
        this.loadAccounts(false);
    }

    async loadAccounts(reset) {
        if (reset) {
            this.accountOffset = 0;
            this.accountRows = [];
            this.hasMore = true;
        }
        this.isLoadingAccounts = true;
        this.accountError = undefined;
        try {
            const rows = await getAccountsByRisk({
                churnRisk: this.selectedRisk,
                pageSize: PAGE_SIZE,
                offsetValue: this.accountOffset
            });
            this.accountRows = [
                ...this.accountRows,
                ...rows.map((row) => ({
                    ...row,
                    accountUrl: `/lightning/r/Account/${row.accountId}/view`
                }))
            ];
            this.accountOffset += rows.length;
            this.hasMore = rows.length === PAGE_SIZE;
        } catch (error) {
            this.accountError = (error.body && error.body.message) || 'Unable to load accounts.';
        } finally {
            this.isLoadingAccounts = false;
        }
    }

    formatCurrency(value) {
        return new Intl.NumberFormat(undefined, {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(value || 0);
    }

    formatNumber(value) {
        return new Intl.NumberFormat().format(value || 0);
    }
}
